import AppKit
import PeelCore

/// Lightweight prompt: showing it never waits for ScreenCaptureKit or Metal.
@MainActor
final class PeelDesktopPrompt {
    var onDown: ((CGPoint, PeelCorner) -> Void)?
    var onDrag: ((CGPoint) -> Void)?
    var onUp: (() -> Void)?
    private(set) var isPressed = false
    private(set) var pressedCorner: PeelCorner = .topRight
    private(set) var downPoint = CGPoint.zero
    private(set) var currentPoint = CGPoint.zero
    private var panels: [NSPanel] = []
    var isVisible: Bool { !panels.isEmpty && panels.allSatisfy(\.isVisible) }

    init(frame: CGRect, screenHeight: CGFloat, corners: [PeelCorner]) {
        let appearance = PeelMarkerSettings()
        let size = min(appearance.size, frame.width - 20, frame.height - 20)
        let bottom = screenHeight - frame.maxY
        for corner in corners {
            let unit = corner.unitPoint
            let rect = CGRect(x: unit.x == 0 ? frame.minX + 10 : frame.maxX - size - 10,
                y: unit.y == 0 ? bottom + 10 : bottom + frame.height - size - 10,
                width: size, height: size)
            let panel = NSPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.level = .screenSaver
            panel.alphaValue = appearance.opacity
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let view = PromptView(frame: CGRect(origin: .zero, size: rect.size))
            view.onDown = { [weak self] in
                guard let self else { return }
                isPressed = true
                pressedCorner = corner
                downPoint = NSEvent.mouseLocation
                currentPoint = downPoint
                onDown?(downPoint, corner)
            }
            view.onDrag = { [weak self] in
                guard let self else { return }
                currentPoint = NSEvent.mouseLocation
                onDrag?(currentPoint)
            }
            view.onUp = { [weak self] in
                self?.isPressed = false
                self?.onUp?()
            }
            panel.contentView = view
            panels.append(panel)
        }
    }

    func show() { panels.forEach { $0.orderFrontRegardless() } }
    func hide() { panels.forEach { $0.orderOut(nil) } }
}

@MainActor
private final class PromptView: NSView {
    var onDown: (() -> Void)?
    var onDrag: (() -> Void)?
    var onUp: (() -> Void)?
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 3), xRadius: 14, yRadius: 14)
        PeelMarkerSettings().color.setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.9).setStroke()
        path.lineWidth = 2
        path.stroke()
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onDown?() }
    override func mouseDragged(with event: NSEvent) { onDrag?() }
    override func mouseUp(with event: NSEvent) { onUp?() }
}
