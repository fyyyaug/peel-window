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
    private let hintLabel = NSTextField(labelWithString: "Drag an enabled corner farther to lift more of that edge")
    private let topLeftButton = NSButton(checkboxWithTitle: "Top left", target: nil, action: nil)
    private let topRightButton = NSButton(checkboxWithTitle: "Top right", target: nil, action: nil)
    private let bottomLeftButton = NSButton(checkboxWithTitle: "Bottom left", target: nil, action: nil)
    private let bottomRightButton = NSButton(checkboxWithTitle: "Bottom right", target: nil, action: nil)
    private let strengthLabel = NSTextField(labelWithString: "Return strength: 1.00x")
    private let strengthSlider = NSSlider(value: 1, minValue: 0.25, maxValue: 2, target: nil, action: nil)
    private let reachLabel = NSTextField(labelWithString: "Maximum peel size: 82%")
    private let reachSlider = NSSlider(value: 0.82, minValue: 0.1, maxValue: 1, target: nil, action: nil)
    private let frontPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let underneathPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let refreshButton = NSButton(title: "Find Windows", target: nil, action: nil)
    private let captureButton = NSButton(title: "Capture", target: nil, action: nil)
    private let demoButton = NSButton(title: "Sample Pair", target: nil, action: nil)
    private let previewButton = NSButton(title: "Preview 50%", target: nil, action: nil)
    private let captureStatusLabel = NSTextField(labelWithString: "Choose Find Windows to load a real window snapshot")
    private let windowCatalog = PeelWindowCatalog()
    private let windowStackResolver = PeelWindowStackResolver()
    private let snapshotter = PeelWindowSnapshotter()

    private var gestureMachine = PeelGestureMachine()
    private var settlementTimer: Timer?
    private var dragPeakProgress = 0.0
    private var lastDragPeakProgress = 0.0
    private var previewingCurl = false
    private var capturedFrontImage: CGImage?
    private var automaticUnderlays: [PeelCorner: CGImage] = [:]
    private var usingAutomaticUnderlay = false

    private var cornerButtons: [(PeelCorner, NSButton)] {
        [(.topLeft, topLeftButton), (.topRight, topRightButton),
         (.bottomLeft, bottomLeftButton), (.bottomRight, bottomRightButton)]
    }

    private var enabledCorners: [PeelCorner] {
        cornerButtons.compactMap { $0.1.state == .on ? $0.0 : nil }
    }

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
        let savedReach = UserDefaults.standard.object(forKey: "PeelMaximumReach") as? Double
            ?? UserDefaults.standard.object(forKey: "PeelMaximumTurn") as? Double
            ?? 0.82
        reachSlider.doubleValue = min(max(savedReach, 0.1), 1)
        renderer.maximumReach = reachSlider.doubleValue
        reachLabel.stringValue = String(format: "Maximum peel size: %.0f%%", reachSlider.doubleValue * 100)
        strengthLabel.stringValue = String(
            format: "Return strength: %.2fx",
            strengthSlider.doubleValue
        )
        gestureMachine = PeelGestureMachine(configuration: gestureConfiguration())

        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        metalView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(metalView)

        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.font = .systemFont(ofSize: 15, weight: .medium)
        hintLabel.textColor = .white
        addSubview(hintLabel)

        let savedCorners = UserDefaults.standard.stringArray(forKey: "PeelEnabledCorners")
        let selectedCorners = Set((savedCorners ?? [PeelCorner.topRight.rawValue])
            .compactMap(PeelCorner.init(rawValue:)))
        for (corner, button) in cornerButtons {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.appearance = NSAppearance(named: .darkAqua)
            button.state = selectedCorners.contains(corner) ? .on : .off
            button.target = self
            button.action = #selector(cornersChanged(_:))
            addSubview(button)
        }
        if enabledCorners.isEmpty { topRightButton.state = .on }
        renderer.highlightedCorners = Set(enabledCorners)

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

        reachLabel.translatesAutoresizingMaskIntoConstraints = false
        reachLabel.font = .systemFont(ofSize: 12, weight: .medium)
        reachLabel.textColor = .white
        addSubview(reachLabel)
        reachSlider.translatesAutoresizingMaskIntoConstraints = false
        reachSlider.target = self
        reachSlider.action = #selector(reachChanged(_:))
        addSubview(reachSlider)

        frontPopup.translatesAutoresizingMaskIntoConstraints = false
        underneathPopup.translatesAutoresizingMaskIntoConstraints = false
        frontPopup.appearance = NSAppearance(named: .darkAqua)
        underneathPopup.appearance = NSAppearance(named: .darkAqua)
        frontPopup.addItem(withTitle: "Front window")
        underneathPopup.addItem(withTitle: "Window underneath (optional)")
        addSubview(frontPopup)
        addSubview(underneathPopup)

        for button in [refreshButton, captureButton, demoButton, previewButton] {
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
        previewButton.target = self
        previewButton.action = #selector(toggleCurlPreview)

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
            topLeftButton.leadingAnchor.constraint(equalTo: hintLabel.leadingAnchor),
            topLeftButton.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 6),
            topRightButton.leadingAnchor.constraint(equalTo: topLeftButton.trailingAnchor, constant: 12),
            topRightButton.centerYAnchor.constraint(equalTo: topLeftButton.centerYAnchor),
            bottomLeftButton.leadingAnchor.constraint(equalTo: topRightButton.trailingAnchor, constant: 12),
            bottomLeftButton.centerYAnchor.constraint(equalTo: topLeftButton.centerYAnchor),
            bottomRightButton.leadingAnchor.constraint(equalTo: bottomLeftButton.trailingAnchor, constant: 12),
            bottomRightButton.centerYAnchor.constraint(equalTo: topLeftButton.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: hintLabel.leadingAnchor),
            statusLabel.topAnchor.constraint(equalTo: topLeftButton.bottomAnchor, constant: 7),
            strengthLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            strengthLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            strengthSlider.trailingAnchor.constraint(equalTo: strengthLabel.trailingAnchor),
            strengthSlider.topAnchor.constraint(equalTo: strengthLabel.bottomAnchor, constant: 4),
            strengthSlider.widthAnchor.constraint(equalToConstant: 160),
            reachLabel.trailingAnchor.constraint(equalTo: strengthLabel.trailingAnchor),
            reachLabel.topAnchor.constraint(equalTo: strengthSlider.bottomAnchor, constant: 12),
            reachSlider.trailingAnchor.constraint(equalTo: strengthLabel.trailingAnchor),
            reachSlider.topAnchor.constraint(equalTo: reachLabel.bottomAnchor, constant: 4),
            reachSlider.widthAnchor.constraint(equalToConstant: 160),
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
            previewButton.trailingAnchor.constraint(equalTo: strengthLabel.trailingAnchor),
            previewButton.topAnchor.constraint(equalTo: reachSlider.bottomAnchor, constant: 10),
            previewButton.widthAnchor.constraint(equalToConstant: 120),
            captureStatusLabel.leadingAnchor.constraint(equalTo: frontPopup.leadingAnchor),
            captureStatusLabel.bottomAnchor.constraint(equalTo: frontPopup.topAnchor, constant: -7),
        ])

        let pan = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
        updatePresentation()
        showDemo()
    }

    @objc private func strengthChanged(_ sender: NSSlider) {
        strengthLabel.stringValue = String(format: "Return strength: %.2fx", sender.doubleValue)
        UserDefaults.standard.set(sender.doubleValue, forKey: "PeelReturnStrength")
        if gestureMachine.phase == .idle {
            gestureMachine = PeelGestureMachine(configuration: gestureConfiguration())
        }
    }

    @objc private func reachChanged(_ sender: NSSlider) {
        let reach = sender.doubleValue
        reachLabel.stringValue = String(format: "Maximum peel size: %.0f%%", reach * 100)
        UserDefaults.standard.set(reach, forKey: "PeelMaximumReach")
        renderer.maximumReach = reach
        if gestureMachine.phase == .idle {
            gestureMachine = PeelGestureMachine(configuration: gestureConfiguration())
        }
        metalView.draw()
    }

    @objc private func cornersChanged(_ sender: NSButton) {
        if enabledCorners.isEmpty {
            sender.state = .on
            captureStatusLabel.stringValue = "Keep at least one corner enabled."
            return
        }
        UserDefaults.standard.set(enabledCorners.map(\.rawValue), forKey: "PeelEnabledCorners")
        renderer.highlightedCorners = Set(enabledCorners)
        metalView.draw()
    }

    private func gestureConfiguration() -> PeelGestureConfiguration {
        PeelGestureConfiguration.reboundStrength(strengthSlider.doubleValue)
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
                    ? "No supported windows are available."
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
        underneathPopup.addItem(withTitle: "Auto-detect actual window below")
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
        stopCurlPreview()
        guard let frontID = (frontPopup.selectedItem?.representedObject as? NSNumber)?.uint32Value else {
            captureStatusLabel.stringValue = "Select a front window first."
            return
        }
        let autoDetectUnderneath = underneathPopup.indexOfSelectedItem == 1
        let selectedUnderneathID = (underneathPopup.selectedItem?.representedObject as? NSNumber)?.uint32Value
        if selectedUnderneathID == frontID {
            captureStatusLabel.stringValue = "Choose a different window for underneath."
            return
        }

        captureButton.isEnabled = false
        captureStatusLabel.stringValue = "Capturing selected window snapshots…"
        Task { @MainActor in
            defer { captureButton.isEnabled = true }
            do {
                _ = try await windowCatalog.refresh()
                guard let frontWindow = windowCatalog.window(withID: frontID) else {
                    throw PeelCaptureError.windowUnavailable
                }
                let frontImage = try await snapshotter.capture(frontWindow)
                var underneathImage: CGImage?
                var newAutomaticUnderlays: [PeelCorner: CGImage] = [:]
                if autoDetectUnderneath {
                    var capturedByID: [CGWindowID: CGImage] = [:]
                    for corner in PeelCorner.allCases {
                        guard let underneathID = windowStackResolver.windowBelow(
                            sourceID: frontID,
                            sourceFrame: frontWindow.frame,
                            corner: corner
                        ), let underneathWindow = windowCatalog.window(withID: underneathID) else {
                            continue
                        }
                        let image: CGImage?
                        if let cached = capturedByID[underneathID] {
                            image = cached
                        } else {
                            image = try? await snapshotter.capture(underneathWindow)
                        }
                        if let image {
                            capturedByID[underneathID] = image
                            newAutomaticUnderlays[corner] = image
                        }
                    }
                    underneathImage = newAutomaticUnderlays[enabledCorners.first ?? .topRight]
                } else if let selectedUnderneathID {
                    if let underneathWindow = windowCatalog.window(withID: selectedUnderneathID) {
                        underneathImage = try await snapshotter.capture(underneathWindow)
                    } else {
                        throw PeelCaptureError.windowUnavailable
                    }
                }
                try renderer.showSnapshots(front: frontImage, underneath: underneathImage)
                capturedFrontImage = frontImage
                automaticUnderlays = newAutomaticUnderlays
                usingAutomaticUnderlay = autoDetectUnderneath
                metalView.draw()
                captureStatusLabel.stringValue = autoDetectUnderneath
                    ? "Front captured. Drag an enabled corner to reveal its lower window."
                    : underneathImage != nil
                        ? "Two snapshots ready. Drag an enabled corner to reveal the lower one."
                        : "Front snapshot ready. Drag an enabled corner."
            } catch {
                captureStatusLabel.stringValue = "Capture failed: \(error.localizedDescription)"
            }
        }
    }

    @objc private func showDemo() {
        do {
            stopCurlPreview()
            capturedFrontImage = nil
            automaticUnderlays = [:]
            usingAutomaticUnderlay = false
            try renderer.showSnapshots(
                front: makeSampleImage(underneath: false),
                underneath: makeSampleImage(underneath: true)
            )
            captureStatusLabel.stringValue = "Sample pair ready. Drag a corner to reveal the lower sample."
            metalView.draw()
        } catch {
            captureStatusLabel.stringValue = "Unable to restore demo: \(error.localizedDescription)"
        }
    }

    @objc private func toggleCurlPreview() {
        if previewingCurl {
            stopCurlPreview()
            updatePresentation()
            return
        }
        stopSettlementTimer()
        gestureMachine = PeelGestureMachine(configuration: gestureConfiguration())
        let corner = enabledCorners.contains(.topRight) ? PeelCorner.topRight
            : enabledCorners.first ?? .topRight
        renderer.pose = PeelPose(
            corner: corner,
            pull: PeelPoint(
                x: corner.unitPoint.x == 0 ? 0.5 : -0.5,
                y: corner.unitPoint.y == 0 ? 0.5 : -0.5
            ),
            progress: 0.5,
            lift: sin(.pi / 4)
        )
        previewingCurl = true
        previewButton.title = "Resume"
        metalView.draw()
    }

    private func stopCurlPreview() {
        guard previewingCurl else { return }
        previewingCurl = false
        previewButton.title = "Preview 50%"
        renderer.pose = gestureMachine.pose
        metalView.draw()
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
            stopCurlPreview()
            let translation = recognizer.translation(in: self)
            let startPoint = CGPoint(
                x: point.x - translation.x,
                y: point.y - translation.y
            )
            let nearestCorner = enabledCorners.map { corner in
                let cornerPoint = renderer.corner(corner, in: bounds.size)
                return (corner, hypot(startPoint.x - cornerPoint.x, startPoint.y - cornerPoint.y))
            }.min { $0.1 < $1.1 }
            guard let (corner, distance) = nearestCorner, distance <= 110 else {
                recognizer.isEnabled = false
                recognizer.isEnabled = true
                return
            }
            if usingAutomaticUnderlay, let capturedFrontImage {
                do {
                    let underneath = automaticUnderlays[corner]
                    try renderer.showSnapshots(front: capturedFrontImage, underneath: underneath)
                    captureStatusLabel.stringValue = underneath == nil
                        ? "No actual lower window at this corner."
                        : "Actual lower window ready for this corner."
                } catch {
                    captureStatusLabel.stringValue = "Unable to show this corner: \(error.localizedDescription)"
                }
            }
            stopSettlementTimer()
            gestureMachine = PeelGestureMachine(configuration: gestureConfiguration())
            gestureMachine.begin(
                corner: corner,
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

