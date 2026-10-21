import AppKit
import CoreGraphics
import MetalKit
import PeelCapture
import PeelCore
import PeelInteraction
import PeelRenderer
import PeelWindowing

@MainActor
public final class PeelDemoView: NSView {
    private let metalView: MTKView
    private let renderer: PeelMetalRenderer
    private let statusLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "Drag the highlighted top-right corner")
    private let strengthLabel = NSTextField(labelWithString: "Return strength: 1.00x")
    private let strengthSlider = NSSlider(value: 1, minValue: 0.25, maxValue: 2, target: nil, action: nil)
    private let frontPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let underneathPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let refreshButton = NSButton(title: "Find Windows", target: nil, action: nil)
    private let captureButton = NSButton(title: "Capture", target: nil, action: nil)
    private let demoButton = NSButton(title: "Sample Pair", target: nil, action: nil)
    private let captureStatusLabel = NSTextField(labelWithString: "Choose Find Windows to load a real window snapshot")
    private let windowCatalog = PeelWindowCatalog()
    private let snapshotter = PeelWindowSnapshotter()

    private var gestureMachine = PeelGestureMachine()
    private var settlementTimer: Timer?
    private var dragPeakProgress = 0.0
    private var lastDragPeakProgress = 0.0
    private var showingSamplePair = false

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
        let savedStrength = UserDefaults.standard.object(forKey: "PeelReturnStrength") as? Double ?? 1
        strengthSlider.doubleValue = min(max(savedStrength, 0.25), 2)
        strengthLabel.stringValue = String(
            format: "Return strength: %.2fx",
            strengthSlider.doubleValue
        )
        gestureMachine = PeelGestureMachine(
            configuration: .reboundStrength(strengthSlider.doubleValue)
        )

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

        strengthLabel.translatesAutoresizingMaskIntoConstraints = false
        strengthLabel.font = .systemFont(ofSize: 12, weight: .medium)
        strengthLabel.textColor = .white
        addSubview(strengthLabel)

        strengthSlider.translatesAutoresizingMaskIntoConstraints = false
        strengthSlider.target = self
        strengthSlider.action = #selector(strengthChanged(_:))
        addSubview(strengthSlider)

        frontPopup.translatesAutoresizingMaskIntoConstraints = false
        underneathPopup.translatesAutoresizingMaskIntoConstraints = false
        frontPopup.appearance = NSAppearance(named: .darkAqua)
        underneathPopup.appearance = NSAppearance(named: .darkAqua)
        frontPopup.addItem(withTitle: "Front window")
        underneathPopup.addItem(withTitle: "Window underneath (optional)")
        addSubview(frontPopup)
        addSubview(underneathPopup)

        for button in [refreshButton, captureButton, demoButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.bezelStyle = .rounded
            button.appearance = NSAppearance(named: .darkAqua)
            addSubview(button)
        }
        refreshButton.target = self
        refreshButton.action = #selector(refreshWindows)
        captureButton.target = self
        captureButton.action = #selector(captureSelectedWindows)
        captureButton.isEnabled = false
        demoButton.target = self
        demoButton.action = #selector(showDemo)

        captureStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        captureStatusLabel.font = .systemFont(ofSize: 12)
        captureStatusLabel.textColor = NSColor.white.withAlphaComponent(0.8)
        addSubview(captureStatusLabel)

        NSLayoutConstraint.activate([
            metalView.leadingAnchor.constraint(equalTo: leadingAnchor),
            metalView.trailingAnchor.constraint(equalTo: trailingAnchor),
            metalView.topAnchor.constraint(equalTo: topAnchor),
            metalView.bottomAnchor.constraint(equalTo: bottomAnchor),
            hintLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            hintLabel.topAnchor.constraint(equalTo: topAnchor, constant: 22),
            statusLabel.leadingAnchor.constraint(equalTo: hintLabel.leadingAnchor),
            statusLabel.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 7),
            strengthLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            strengthLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            strengthSlider.trailingAnchor.constraint(equalTo: strengthLabel.trailingAnchor),
            strengthSlider.topAnchor.constraint(equalTo: strengthLabel.bottomAnchor, constant: 4),
            strengthSlider.widthAnchor.constraint(equalToConstant: 160),
            frontPopup.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            frontPopup.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),
            frontPopup.widthAnchor.constraint(equalToConstant: 240),
            underneathPopup.leadingAnchor.constraint(equalTo: frontPopup.trailingAnchor, constant: 12),
            underneathPopup.centerYAnchor.constraint(equalTo: frontPopup.centerYAnchor),
            underneathPopup.widthAnchor.constraint(equalToConstant: 240),
            refreshButton.leadingAnchor.constraint(equalTo: underneathPopup.trailingAnchor, constant: 12),
            refreshButton.centerYAnchor.constraint(equalTo: frontPopup.centerYAnchor),
            refreshButton.widthAnchor.constraint(equalToConstant: 120),
            captureButton.leadingAnchor.constraint(equalTo: refreshButton.trailingAnchor, constant: 12),
            captureButton.centerYAnchor.constraint(equalTo: frontPopup.centerYAnchor),
            captureButton.widthAnchor.constraint(equalToConstant: 100),
            demoButton.leadingAnchor.constraint(equalTo: captureButton.trailingAnchor, constant: 12),
            demoButton.centerYAnchor.constraint(equalTo: frontPopup.centerYAnchor),
            demoButton.widthAnchor.constraint(equalToConstant: 100),
            captureStatusLabel.leadingAnchor.constraint(equalTo: frontPopup.leadingAnchor),
            captureStatusLabel.bottomAnchor.constraint(equalTo: frontPopup.topAnchor, constant: -7),
        ])

        let pan = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
        updatePresentation()
    }

    @objc private func strengthChanged(_ sender: NSSlider) {
        strengthLabel.stringValue = String(format: "Return strength: %.2fx", sender.doubleValue)
        UserDefaults.standard.set(sender.doubleValue, forKey: "PeelReturnStrength")
        if gestureMachine.phase == .idle {
            gestureMachine = PeelGestureMachine(
                configuration: .reboundStrength(sender.doubleValue)
            )
        }
    }

    @objc private func refreshWindows() {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            captureStatusLabel.stringValue = "Allow Screen Recording in System Settings, then restart PeelWindow."
            return
        }

        refreshButton.isEnabled = false
        captureStatusLabel.stringValue = "Finding available windows…"
        Task { @MainActor in
            defer { refreshButton.isEnabled = true }
            do {
                let choices = try await windowCatalog.refresh()
                populateWindowMenus(with: choices)
                captureButton.isEnabled = !choices.isEmpty
                captureStatusLabel.stringValue = choices.isEmpty
                    ? "No supported windows are currently visible."
                    : "Select a front window and optionally a window underneath."
            } catch {
                captureStatusLabel.stringValue = "Window discovery failed: \(error.localizedDescription)"
            }
        }
    }

    private func populateWindowMenus(with choices: [PeelWindowChoice]) {
        frontPopup.removeAllItems()
        underneathPopup.removeAllItems()
        frontPopup.addItem(withTitle: "Front window")
        underneathPopup.addItem(withTitle: "Window underneath (optional)")
        for choice in choices {
            frontPopup.addItem(withTitle: choice.displayName)
            frontPopup.lastItem?.representedObject = NSNumber(value: choice.id)
            underneathPopup.addItem(withTitle: choice.displayName)
            underneathPopup.lastItem?.representedObject = NSNumber(value: choice.id)
        }
        frontPopup.selectItem(at: 0)
        underneathPopup.selectItem(at: 0)
    }

    @objc private func captureSelectedWindows() {
        guard let frontID = (frontPopup.selectedItem?.representedObject as? NSNumber)?.uint32Value else {
            captureStatusLabel.stringValue = "Select a front window first."
            return
        }
        let underneathID = (underneathPopup.selectedItem?.representedObject as? NSNumber)?.uint32Value
        if underneathID == frontID {
            captureStatusLabel.stringValue = "Choose a different window for underneath."
            return
        }

        captureButton.isEnabled = false
        captureStatusLabel.stringValue = "Capturing selected window snapshots…"
        Task { @MainActor in
            defer { captureButton.isEnabled = true }
            do {
                guard let frontWindow = windowCatalog.window(withID: frontID) else {
                    throw PeelCaptureError.windowUnavailable
                }
                let frontImage = try await snapshotter.capture(frontWindow)
                var underneathImage: CGImage?
                if let underneathID {
                    guard let underneathWindow = windowCatalog.window(withID: underneathID) else {
                        throw PeelCaptureError.windowUnavailable
                    }
                    underneathImage = try await snapshotter.capture(underneathWindow)
                }
                try renderer.showSnapshots(front: frontImage, underneath: underneathImage)
                showingSamplePair = false
                demoButton.title = "Sample Pair"
                metalView.draw()
                captureStatusLabel.stringValue = underneathImage == nil
                    ? "Front snapshot ready. Drag the highlighted corner."
                    : "Two snapshots ready. Drag to reveal the one underneath."
            } catch {
                captureStatusLabel.stringValue = "Capture failed: \(error.localizedDescription)"
            }
        }
    }

    @objc private func showDemo() {
        do {
            if showingSamplePair {
                try renderer.showSnapshots(front: nil, underneath: nil)
                demoButton.title = "Sample Pair"
                captureStatusLabel.stringValue = "Synthetic demo restored."
            } else {
                try renderer.showSnapshots(
                    front: makeSampleImage(underneath: false),
                    underneath: makeSampleImage(underneath: true)
                )
                demoButton.title = "Synthetic"
                captureStatusLabel.stringValue = "Sample pair ready. Drag to reveal the lower sample."
            }
            showingSamplePair.toggle()
            metalView.draw()
        } catch {
            captureStatusLabel.stringValue = "Unable to restore demo: \(error.localizedDescription)"
        }
    }

    private func makeSampleImage(underneath: Bool) -> CGImage? {
        let width = 800
        let height = 500
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        let background = underneath
            ? NSColor(red: 0.98, green: 0.68, blue: 0.43, alpha: 1)
            : NSColor(red: 0.47, green: 0.78, blue: 0.76, alpha: 1)
        context.setFillColor(background.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(NSColor(red: 0.15, green: 0.19, blue: 0.30, alpha: 1).cgColor)
        context.fill(CGRect(x: 0, y: height - 64, width: width, height: 64))

        let accent = underneath
            ? NSColor(red: 0.66, green: 0.25, blue: 0.37, alpha: 1)
            : NSColor(red: 0.20, green: 0.43, blue: 0.48, alpha: 1)
        context.setFillColor(accent.cgColor)
        context.fill(CGRect(x: 56, y: 90, width: 250, height: 260))
        context.fill(CGRect(x: 340, y: 240, width: 390, height: 110))
        context.fill(CGRect(x: 340, y: 90, width: 280, height: 110))
        return context.makeImage()
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
            gestureMachine = PeelGestureMachine(
                configuration: .reboundStrength(strengthSlider.doubleValue)
            )
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

