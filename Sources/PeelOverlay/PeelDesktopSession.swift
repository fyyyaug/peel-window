import AppKit
import CoreGraphics
import MetalKit
import PeelCore
import PeelInteraction
import PeelRenderer

public enum PeelDesktopError: LocalizedError {
    case noMainDisplay
    case unsupportedWindowPosition
    case rendererUnavailable
    case noLowerWindow

    public var errorDescription: String? {
        switch self {
        case .noMainDisplay: "No main display is available."
        case .unsupportedWindowPosition: "Desktop peel currently supports windows fully on the main display."
        case .rendererUnavailable: "The desktop renderer could not start."
        case .noLowerWindow: "No captured lower window is available at an enabled corner."
        }
    }
}

@MainActor
public final class PeelDesktopSession {
    public var onStop: ((String) -> Void)?

    private let sourceWindowID: CGWindowID
    private let initialSystemFrame: CGRect
    private let sourceProcessID: pid_t
    private let front: CGImage
    private let underlays: [PeelCorner: CGImage]
    private let overlay: NSPanel
    private let metalView: MTKView
    private let renderer: PeelMetalRenderer
    private var hotspots: [NSPanel] = []
    private var gestureMachine: PeelGestureMachine
    private var settlementTimer: Timer?
    private var safetyTimer: Timer?
    private var activationObserver: NSObjectProtocol?
    private var isStopped = false
    private var sourceWasActive = false
    private var activationDeadline = 0.0

    public init(
        sourceWindowID: CGWindowID,
        sourceFrame: CGRect,
        front: CGImage,
        underlays: [PeelCorner: CGImage],
        enabledCorners: [PeelCorner],
        maximumReach: Double,
        returnStrength: Double
    ) throws {
        guard let mainScreen = NSScreen.screens.first else { throw PeelDesktopError.noMainDisplay }
        let displayFrame = CGRect(origin: .zero, size: mainScreen.frame.size)
        guard displayFrame.contains(sourceFrame), sourceFrame.width >= 160,
              sourceFrame.height >= 120 else {
            throw PeelDesktopError.unsupportedWindowPosition
        }
        let activeCorners = enabledCorners.filter { underlays[$0] != nil }
        guard !activeCorners.isEmpty else { throw PeelDesktopError.noLowerWindow }

        let appKitFrame = CGRect(
            x: sourceFrame.minX,
            y: mainScreen.frame.maxY - sourceFrame.maxY,
            width: sourceFrame.width,
            height: sourceFrame.height
        )
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw PeelDesktopError.rendererUnavailable
        }
        let metalView = MTKView(frame: CGRect(origin: .zero, size: appKitFrame.size), device: device)
        guard let renderer = PeelMetalRenderer(view: metalView) else {
            throw PeelDesktopError.rendererUnavailable
        }
        renderer.maximumReach = maximumReach
        renderer.highlightedCorners = []
        try renderer.showSnapshots(front: front, underneath: underlays[activeCorners[0]])

        let overlay = NSPanel(
            contentRect: appKitFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        overlay.isOpaque = false
        overlay.backgroundColor = .clear
        overlay.hasShadow = false
        overlay.level = .floating
        overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        overlay.ignoresMouseEvents = true
        overlay.contentView = metalView

        self.sourceWindowID = sourceWindowID
        guard let sourceInfo = Self.currentWindowInfo(for: sourceWindowID) else {
            throw PeelDesktopError.unsupportedWindowPosition
        }
        self.initialSystemFrame = sourceInfo.frame
        self.sourceProcessID = sourceInfo.processID
        self.front = front
        self.underlays = underlays
        self.overlay = overlay
        self.metalView = metalView
        self.renderer = renderer
        self.gestureMachine = PeelGestureMachine(
            configuration: .reboundStrength(returnStrength)
        )

        for corner in activeCorners {
            let size: CGFloat = 64
            let position = corner.unitPoint
            let hotspotFrame = CGRect(
                x: position.x == 0 ? appKitFrame.minX : appKitFrame.maxX - size,
                y: position.y == 0 ? appKitFrame.minY : appKitFrame.maxY - size,
                width: size,
                height: size
            )
            let hotspot = NSPanel(
                contentRect: hotspotFrame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            hotspot.isOpaque = false
            hotspot.backgroundColor = .clear
            hotspot.hasShadow = false
            hotspot.level = .floating
            hotspot.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let view = PeelDesktopHotspotView(frame: CGRect(origin: .zero, size: hotspotFrame.size))
            view.onDown = { [weak self] location in self?.begin(at: location, corner: corner) }
            view.onDrag = { [weak self] location in self?.update(to: location) }
            view.onUp = { [weak self] in self?.end() }
            hotspot.contentView = view
            hotspots.append(hotspot)
        }
    }

    public func start() {
        guard !isStopped else { return }
        for hotspot in hotspots { hotspot.orderFrontRegardless() }
        activationDeadline = ProcessInfo.processInfo.systemUptime + 15
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let processID = (notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication)?.processIdentifier
            Task { @MainActor in
                if processID == self.sourceProcessID {
                    self.sourceWasActive = true
                } else if self.sourceWasActive {
                    self.stop(reason: "Desktop peel stopped because another app became active.")
                }
            }
        }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == sourceProcessID {
            sourceWasActive = true
        }
        NSRunningApplication(processIdentifier: sourceProcessID)?.activate()
        safetyTimer = Timer.scheduledTimer(
            timeInterval: 0.5,
            target: self,
            selector: #selector(checkSourceWindow),
            userInfo: nil,
            repeats: true
        )
    }

    public func stop(reason: String = "Desktop peel stopped.") {
        guard !isStopped else { return }
        isStopped = true
        settlementTimer?.invalidate()
        safetyTimer?.invalidate()
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        overlay.orderOut(nil)
        for hotspot in hotspots { hotspot.orderOut(nil) }
        hotspots.removeAll()
        onStop?(reason)
    }

    private func begin(at location: CGPoint, corner: PeelCorner) {
        guard !isStopped, let lower = underlays[corner] else { return }
        settlementTimer?.invalidate()
        gestureMachine = PeelGestureMachine(configuration: .reboundStrength(
            UserDefaults.standard.double(forKey: "PeelReturnStrength")
        ))
        do {
            try renderer.showSnapshots(front: front, underneath: lower)
        } catch {
            stop(reason: "Desktop peel stopped because the captured image could not load.")
            return
        }
        gestureMachine.begin(
            corner: corner,
            at: PeelPoint(x: location.x, y: location.y),
            timestamp: ProcessInfo.processInfo.systemUptime
        )
        renderer.pose = gestureMachine.pose
        overlay.orderFrontRegardless()
        for hotspot in hotspots { hotspot.orderFrontRegardless() }
        metalView.draw()
    }

    private func update(to location: CGPoint) {
        guard !isStopped, gestureMachine.phase == .dragging else { return }
        gestureMachine.update(
            to: PeelPoint(x: location.x, y: location.y),
            timestamp: ProcessInfo.processInfo.systemUptime
        )
        renderer.pose = gestureMachine.pose
        metalView.draw()
    }

    private func end() {
        guard !isStopped, gestureMachine.phase == .dragging else { return }
        gestureMachine.end()
        if gestureMachine.phase == .idle {
            overlay.orderOut(nil)
            return
        }
        settlementTimer = Timer.scheduledTimer(
            timeInterval: 1.0 / 60.0,
            target: self,
            selector: #selector(advanceSettlement),
            userInfo: nil,
            repeats: true
        )
        if let settlementTimer { RunLoop.main.add(settlementTimer, forMode: .common) }
    }

    @objc private func advanceSettlement() {
        gestureMachine.advance(by: 1.0 / 60.0)
        renderer.pose = gestureMachine.pose
        metalView.draw()
        if gestureMachine.phase == .idle {
            settlementTimer?.invalidate()
            settlementTimer = nil
            overlay.orderOut(nil)
        }
    }

    @objc private func checkSourceWindow() {
        guard !isStopped else { return }
        if !sourceWasActive {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == sourceProcessID {
                sourceWasActive = true
            } else if ProcessInfo.processInfo.systemUptime >= activationDeadline {
                stop(reason: "Desktop peel timed out. Bring the selected window forward, then try again.")
                return
            }
        }
        guard let current = Self.currentWindowInfo(for: sourceWindowID)?.frame else {
            stop(reason: "Desktop peel stopped because the selected window is unavailable.")
            return
        }
        if abs(current.minX - initialSystemFrame.minX) > 2 ||
            abs(current.minY - initialSystemFrame.minY) > 2 ||
            abs(current.width - initialSystemFrame.width) > 2 ||
            abs(current.height - initialSystemFrame.height) > 2 {
            stop(reason: "Desktop peel stopped because the selected window moved or resized.")
        }
    }

    private static func currentWindowInfo(
        for windowID: CGWindowID
    ) -> (frame: CGRect, processID: pid_t)? {
        let options: CGWindowListOption = [.optionIncludingWindow]
        guard let item = (CGWindowListCopyWindowInfo(options, windowID)
            as? [[String: Any]])?.first,
              let bounds = item[kCGWindowBounds as String] as? [String: Any],
              let x = (bounds["X"] as? NSNumber)?.doubleValue,
              let y = (bounds["Y"] as? NSNumber)?.doubleValue,
              let width = (bounds["Width"] as? NSNumber)?.doubleValue,
              let height = (bounds["Height"] as? NSNumber)?.doubleValue,
              let processID = (item[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value
        else { return nil }
        return (CGRect(x: x, y: y, width: width, height: height), processID)
    }
}

@MainActor
private final class PeelDesktopHotspotView: NSView {
    var onDown: ((CGPoint) -> Void)?
    var onDrag: ((CGPoint) -> Void)?
    var onUp: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onDown?(NSEvent.mouseLocation) }
    override func mouseDragged(with event: NSEvent) { onDrag?(NSEvent.mouseLocation) }
    override func mouseUp(with event: NSEvent) { onUp?() }
}
