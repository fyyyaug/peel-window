import AppKit
import CoreGraphics
import MetalKit
import PeelCapture
import PeelCore
import PeelInteraction
import PeelRenderer

public enum PeelDesktopError: LocalizedError {
    case noMainDisplay
    case unsupportedWindowPosition
    case rendererUnavailable
    case noEnabledCorner

    public var errorDescription: String? {
        switch self {
        case .noMainDisplay: "No main display is available."
        case .unsupportedWindowPosition: "Desktop peel currently supports windows fully on the main display."
        case .rendererUnavailable: "The desktop renderer could not start."
        case .noEnabledCorner: "Enable at least one corner for desktop peeling."
        }
    }
}

@MainActor
public final class PeelDesktopSession {
    public var onStop: ((String) -> Void)?
    public var onReady: (() -> Void)?
    public var onWaitingForWindow: (() -> Void)?
    public var onRest: (() -> Void)?
    public var isInteracting: Bool { gestureMachine.phase != .idle }

    private let sourceWindowID: CGWindowID
    private var trackedSystemFrame: CGRect
    private let sourceProcessID: pid_t
    private let mainScreenFrame: CGRect
    private let activeCorners: [PeelCorner]
    private let front: CGImage
    private let snapshotter = PeelWindowSnapshotter()
    private let overlay: NSPanel
    private let metalView: MTKView
    private let renderer: PeelMetalRenderer
    private var hotspots: [NSPanel] = []
    private var gestureMachine: PeelGestureMachine
    private var settlementTimer: Timer?
    private var safetyTimer: Timer?
    private var activationObserver: NSObjectProtocol?
    private var isStopped = false
    private var isPreparingBackground = false
    private var isReady = false
    private var sourceWasActive = false
    private var activationDeadline = 0.0
    private var hoverStartedAt = 0.0
    private var activationDelay = 0.0

    public init(
        sourceWindowID: CGWindowID,
        front: CGImage,
        enabledCorners: [PeelCorner],
        maximumReach: Double,
        returnStrength: Double,
        showsMarkers: Bool = true
    ) throws {
        guard let mainScreen = NSScreen.main else { throw PeelDesktopError.noMainDisplay }
        guard let sourceInfo = Self.currentWindowInfo(for: sourceWindowID) else {
            throw PeelDesktopError.unsupportedWindowPosition
        }
        let actualFrame = sourceInfo.frame
        let displayFrame = CGRect(origin: .zero, size: mainScreen.frame.size)
        guard displayFrame.contains(actualFrame), actualFrame.width >= 160,
              actualFrame.height >= 120 else {
            throw PeelDesktopError.unsupportedWindowPosition
        }
        let activeCorners = enabledCorners
        guard !activeCorners.isEmpty else { throw PeelDesktopError.noEnabledCorner }

        let appKitFrame = CGRect(
            x: actualFrame.minX,
            y: mainScreen.frame.maxY - actualFrame.maxY,
            width: actualFrame.width,
            height: actualFrame.height
        )
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw PeelDesktopError.rendererUnavailable
        }
        let metalView = MTKView(frame: CGRect(origin: .zero, size: appKitFrame.size), device: device)
        guard let renderer = PeelMetalRenderer(view: metalView) else {
            throw PeelDesktopError.rendererUnavailable
        }
        renderer.fillsView = true
        renderer.maximumReach = maximumReach
        renderer.highlightedCorners = []
        try renderer.showSnapshots(front: front, underneath: nil)

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
        self.trackedSystemFrame = actualFrame
        self.sourceProcessID = sourceInfo.processID
        self.mainScreenFrame = mainScreen.frame
        self.activeCorners = activeCorners
        self.front = front
        self.overlay = overlay
        self.metalView = metalView
        self.renderer = renderer
        self.gestureMachine = PeelGestureMachine(
            configuration: .reboundStrength(returnStrength)
        )

        for corner in showsMarkers ? activeCorners : [] {
            let appearance = PeelMarkerSettings()
            let size = min(appearance.size, appKitFrame.width - 20, appKitFrame.height - 20)
            let inset: CGFloat = 10
            let position = corner.unitPoint
            let hotspotFrame = CGRect(
                x: position.x == 0 ? appKitFrame.minX + inset : appKitFrame.maxX - size - inset,
                y: position.y == 0 ? appKitFrame.minY + inset : appKitFrame.maxY - size - inset,
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
            hotspot.alphaValue = appearance.opacity
            hotspot.level = .screenSaver
            hotspot.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let view = PeelDesktopHotspotView(frame: CGRect(origin: .zero, size: hotspotFrame.size))
            view.onDown = { [weak self] location in self?.begin(at: location, corner: corner) }
            view.onDrag = { [weak self] location in self?.update(to: location) }
            view.onUp = { [weak self] in self?.end() }
            hotspot.contentView = view
            hotspots.append(hotspot)
        }
    }

    public func start(activateSource: Bool = true, hoverStartedAt: TimeInterval = 0,
                      activationDelay: TimeInterval = 0) {
        guard !isStopped else { return }
        self.hoverStartedAt = hoverStartedAt
        self.activationDelay = activationDelay
        if !activateSource {
            sourceWasActive = true
            prepareBackground()
            safetyTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self,
                selector: #selector(checkSourceWindow), userInfo: nil, repeats: true)
            return
        }
        activationDeadline = ProcessInfo.processInfo.systemUptime + 300
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
                    self.prepareBackground()
                } else if self.sourceWasActive &&
                    NSWorkspace.shared.frontmostApplication?.processIdentifier != self.sourceProcessID {
                    self.stop(reason: "Desktop peel stopped because another app became active.")
                }
            }
        }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == sourceProcessID {
            sourceWasActive = true
            prepareBackground()
        }
        NSRunningApplication(processIdentifier: sourceProcessID)?
            .activate(options: [.activateAllWindows])
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

    func begin(at location: CGPoint, corner: PeelCorner) {
        guard !isStopped, isReady else { return }
        settlementTimer?.invalidate()
        gestureMachine = PeelGestureMachine(configuration: .reboundStrength(
            UserDefaults.standard.double(forKey: "PeelReturnStrength")
        ))
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

    func update(to location: CGPoint) {
        guard !isStopped, gestureMachine.phase == .dragging else { return }
        gestureMachine.update(
            to: PeelPoint(x: location.x, y: location.y),
            timestamp: ProcessInfo.processInfo.systemUptime
        )
        renderer.pose = gestureMachine.pose
        metalView.draw()
    }

    func end() {
        guard !isStopped, gestureMachine.phase == .dragging else { return }
        gestureMachine.end()
        if gestureMachine.phase == .idle {
            overlay.orderOut(nil)
            onRest?()
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
            onRest?()
        }
    }

    @objc private func checkSourceWindow() {
        guard !isStopped else { return }
        if !sourceWasActive {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == sourceProcessID {
                sourceWasActive = true
                prepareBackground()
            } else if ProcessInfo.processInfo.systemUptime >= activationDeadline {
                stop(reason: "Desktop peel timed out. Bring the selected window forward, then try again.")
                return
            }
        }
        if sourceWasActive && !isReady && !isPreparingBackground {
            prepareBackground()
        }
        guard let current = Self.currentWindowInfo(for: sourceWindowID)?.frame else {
            stop(reason: "Desktop peel stopped because the selected window is unavailable.")
            return
        }
        if isReady && (abs(current.minX - trackedSystemFrame.minX) > 2 ||
            abs(current.minY - trackedSystemFrame.minY) > 2 ||
            abs(current.width - trackedSystemFrame.width) > 2 ||
            abs(current.height - trackedSystemFrame.height) > 2) {
            stop(reason: "Desktop peel stopped because the selected window moved or resized.")
        } else if !isReady && !isPreparingBackground {
            alignPanels(to: current)
        }
    }

    private func prepareBackground() {
        guard sourceWasActive, !isPreparingBackground, !isReady, !isStopped else { return }
        guard let current = Self.currentWindowInfo(for: sourceWindowID)?.frame else {
            stop(reason: "Desktop peel stopped because the selected window is unavailable.")
            return
        }
        alignPanels(to: current)
        isPreparingBackground = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let background = try await snapshotter.captureDesktopBehind(
                    windowID: sourceWindowID,
                    windowFrame: current,
                    outputSize: CGSize(width: front.width, height: front.height)
                )
                guard !isStopped else { return }
                guard let latest = Self.currentWindowInfo(for: sourceWindowID)?.frame else {
                    stop(reason: "Desktop peel stopped because the selected window is unavailable.")
                    return
                }
                if latest != current {
                    isPreparingBackground = false
                    alignPanels(to: latest)
                    prepareBackground()
                    return
                }
                try renderer.showSnapshots(front: front, underneath: background)
                let remaining = PeelHoverTiming.remaining(startedAt: hoverStartedAt,
                    delay: activationDelay, now: ProcessInfo.processInfo.systemUptime)
                if remaining > 0 {
                    try await Task.sleep(for: .seconds(remaining))
                }
                guard !isStopped else { return }
                guard Self.currentWindowInfo(for: sourceWindowID)?.frame == current else {
                    isPreparingBackground = false
                    prepareBackground()
                    return
                }
                isReady = true
                for hotspot in hotspots { hotspot.orderFrontRegardless() }
                onReady?()
            } catch PeelCaptureError.sourceNotOnScreen {
                isPreparingBackground = false
                onWaitingForWindow?()
            } catch {
                stop(reason: "Desktop peel stopped because the background capture failed: \(error.localizedDescription)")
            }
        }
    }

    private func alignPanels(to frame: CGRect) {
        trackedSystemFrame = frame
        let appKitFrame = CGRect(
            x: frame.minX,
            y: mainScreenFrame.maxY - frame.maxY,
            width: frame.width,
            height: frame.height
        )
        overlay.setFrame(appKitFrame, display: false)
        for (corner, hotspot) in zip(activeCorners, hotspots) {
            let size = min(PeelMarkerSettings().size, appKitFrame.width - 20, appKitFrame.height - 20)
            let inset: CGFloat = 10
            let point = corner.unitPoint
            hotspot.setFrame(CGRect(
                x: point.x == 0 ? appKitFrame.minX + inset : appKitFrame.maxX - size - inset,
                y: point.y == 0 ? appKitFrame.minY + inset : appKitFrame.maxY - size - inset,
                width: size,
                height: size
            ), display: false)
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

    override func draw(_ dirtyRect: NSRect) {
        let marker = bounds.insetBy(dx: 3, dy: 3)
        let path = NSBezierPath(roundedRect: marker, xRadius: 14, yRadius: 14)
        PeelMarkerSettings().color.setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.9).setStroke()
        path.lineWidth = 2
        path.stroke()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onDown?(NSEvent.mouseLocation) }
    override func mouseDragged(with event: NSEvent) { onDrag?(NSEvent.mouseLocation) }
    override func mouseUp(with event: NSEvent) { onUp?() }
}
