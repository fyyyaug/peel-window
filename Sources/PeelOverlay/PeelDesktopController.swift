import AppKit
import Combine
import PeelCore
import PeelWindowing
import PeelCapture

/// The switch owns the lifetime. Individual window sessions are disposable.
@MainActor
public final class PeelDesktopController: ObservableObject {
    public static let shared = PeelDesktopController()
    @Published public private(set) var isEnabled: Bool
    public var onStatus: ((String) -> Void)?
    private var timer: Timer?
    private var session: PeelDesktopSession?
    private var target: PeelDesktopTarget?
    private var completedTarget: PeelDesktopTarget?
    private var generation = UUID()
    private let catalog = PeelWindowCatalog()
    private let snapshotter = PeelWindowSnapshotter()

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: "PeelDesktopEnabled")
        if isEnabled { startMonitoring() }
    }

    public func setEnabled(_ value: Bool) {
        isEnabled = value
        UserDefaults.standard.set(value, forKey: "PeelDesktopEnabled")
        if value {
            startMonitoring()
            onStatus?("Desktop mode on. Move to an enabled window corner and wait for its marker.")
        } else {
            timer?.invalidate()
            timer = nil
            clearSession()
            onStatus?("Desktop mode off.")
        }
    }

    public func settingsChanged() {
        completedTarget = nil
        clearSession()
    }

    private func startMonitoring() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    private func clearSession() {
        generation = UUID()
        session?.onStop = nil
        session?.onRest = nil
        session?.stop()
        session = nil
        target = nil
    }

    private func tick() {
        guard isEnabled, session?.isInteracting != true,
              CGPreflightScreenCaptureAccess(), let screen = NSScreen.screens.first else { return }
        let mouse = NSEvent.mouseLocation
        let pointer = CGPoint(x: mouse.x, y: screen.frame.maxY - mouse.y)
        let windows = (CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)
            as? [[String: Any]] ?? []).compactMap { info -> PeelDesktopTarget? in
            guard (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let id = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds) else { return nil }
            return PeelDesktopTarget(id: id, frame: frame, processID: pid)
        }
        let saved = UserDefaults.standard.stringArray(forKey: "PeelEnabledCorners")
            ?? [PeelCorner.topRight.rawValue]
        let next = PeelDesktopTarget.atCorner(pointer: pointer, frontToBack: windows,
            enabledCorners: saved.compactMap(PeelCorner.init(rawValue:)),
            displayFrame: CGRect(origin: .zero, size: screen.frame.size),
            ownProcessID: ProcessInfo.processInfo.processIdentifier)
        if next != completedTarget { completedTarget = nil }
        guard next != target else { return }
        clearSession()
        guard let next, next != completedTarget else { return }
        target = next
        let revision = generation
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                _ = try await catalog.refresh()
                guard generation == revision, isEnabled,
                      let window = catalog.window(withID: next.id) else { return }
                let front = try await snapshotter.capture(window)
                guard generation == revision, isEnabled else { return }
                let defaults = UserDefaults.standard
                let reach = defaults.object(forKey: "PeelMaximumReach") as? Double ?? 0.82
                let strength = defaults.object(forKey: "PeelReturnStrength") as? Double ?? 1
                let newSession = try PeelDesktopSession(sourceWindowID: next.id, front: front,
                    enabledCorners: saved.compactMap(PeelCorner.init(rawValue:)),
                    maximumReach: reach, returnStrength: strength)
                newSession.onReady = { [weak self] in self?.onStatus?("Desktop mode on. Drag the teal corner marker.") }
                newSession.onRest = { [weak self] in
                    self?.completedTarget = next
                    self?.clearSession()
                }
                newSession.onStop = { [weak self] _ in self?.clearSession() }
                session = newSession
                newSession.start(activateSource: false)
            } catch {
                guard generation == revision else { return }
                completedTarget = next
                clearSession()
                onStatus?("Desktop mode on; waiting for another supported window corner.")
            }
        }
    }
}
