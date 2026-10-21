import AppKit
import MetalKit
import PeelCore
import PeelInteraction
import PeelRenderer

@MainActor
public final class PeelDemoView: NSView {
    private let metalView: MTKView
    private let renderer: PeelMetalRenderer
    private let statusLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "Drag the highlighted top-right corner")

    private var gestureMachine = PeelGestureMachine()
    private var settlementTimer: Timer?
    private var dragPeakProgress = 0.0
    private var lastDragPeakProgress = 0.0

    public override init(frame frameRect: NSRect) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            preconditionFailure("Metal is required to run the Peel Window prototype")
        }

        let metalView = MTKView(frame: frameRect, device: device)
        guard let renderer = PeelMetalRenderer(view: metalView) else {
            preconditionFailure("Unable to create the Peel Window Metal renderer")
        }

        self.metalView = metalView
        self.renderer = renderer
        super.init(frame: frameRect)
        configureView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func configureView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        metalView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(metalView)

        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.font = .systemFont(ofSize: 15, weight: .medium)
        hintLabel.textColor = .white
        addSubview(hintLabel)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        statusLabel.textColor = NSColor.white.withAlphaComponent(0.72)
        addSubview(statusLabel)

        NSLayoutConstraint.activate([
            metalView.leadingAnchor.constraint(equalTo: leadingAnchor),
            metalView.trailingAnchor.constraint(equalTo: trailingAnchor),
            metalView.topAnchor.constraint(equalTo: topAnchor),
            metalView.bottomAnchor.constraint(equalTo: bottomAnchor),
            hintLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            hintLabel.topAnchor.constraint(equalTo: topAnchor, constant: 22),
            statusLabel.leadingAnchor.constraint(equalTo: hintLabel.leadingAnchor),
            statusLabel.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 7),
        ])

        let pan = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
        updatePresentation()
    }

    @objc private func handlePan(_ recognizer: NSPanGestureRecognizer) {
        let point = recognizer.location(in: self)
        let peelPoint = PeelPoint(x: point.x, y: point.y)
        let timestamp = ProcessInfo.processInfo.systemUptime

        switch recognizer.state {
        case .began:
            // The synthetic card occupies x: -0.88...0.88 and y: -0.72...0.72
            // in Metal clip space, so its visible top-right corner is inset.
            let translation = recognizer.translation(in: self)
            let startPoint = CGPoint(
                x: point.x - translation.x,
                y: point.y - translation.y
            )
            let cornerPoint = CGPoint(
                x: bounds.width * 0.94,
                y: bounds.height * 0.86
            )
            guard hypot(startPoint.x - cornerPoint.x, startPoint.y - cornerPoint.y) <= 110 else {
                recognizer.isEnabled = false
                recognizer.isEnabled = true
                return
            }
            stopSettlementTimer()
            gestureMachine.begin(
                corner: .topRight,
                at: PeelPoint(x: startPoint.x, y: startPoint.y),
                timestamp: timestamp
            )
            gestureMachine.update(to: peelPoint, timestamp: timestamp)
            dragPeakProgress = gestureMachine.pose.progress
        case .changed:
            gestureMachine.update(to: peelPoint, timestamp: timestamp)
            dragPeakProgress = max(dragPeakProgress, gestureMachine.pose.progress)
        case .ended:
            lastDragPeakProgress = dragPeakProgress
            gestureMachine.end()
            startSettlementTimerIfNeeded()
        case .cancelled, .failed:
            gestureMachine.cancel()
            stopSettlementTimer()
        default:
            break
        }

        updatePresentation()
    }

    private func startSettlementTimerIfNeeded() {
        guard gestureMachine.phase == .settling else { return }
        stopSettlementTimer()
        settlementTimer = Timer.scheduledTimer(
            timeInterval: 1.0 / 60.0,
            target: self,
            selector: #selector(advanceSettlement),
            userInfo: nil,
            repeats: true
        )
        if let settlementTimer {
            RunLoop.main.add(settlementTimer, forMode: .common)
        }
    }

    @objc private func advanceSettlement() {
        gestureMachine.advance(by: 1.0 / 60.0)
        updatePresentation()
        if gestureMachine.phase == .idle {
            stopSettlementTimer()
        }
    }

    private func stopSettlementTimer() {
        settlementTimer?.invalidate()
        settlementTimer = nil
    }

    private func updatePresentation() {
        renderer.pose = gestureMachine.pose
        metalView.draw()
        statusLabel.stringValue = String(
            format: "phase: %@   peel: %.2f   last drag: %.2f   frame: %.1f ms",
            String(describing: gestureMachine.phase),
            gestureMachine.pose.progress,
            lastDragPeakProgress,
            renderer.lastFrameDuration * 1_000
        )
    }
}

