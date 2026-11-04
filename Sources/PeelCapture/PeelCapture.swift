import CoreGraphics
import CoreImage
@preconcurrency import ScreenCaptureKit

public enum PeelCaptureError: LocalizedError {
    case windowUnavailable
    case sourceNotOnScreen
    case desktopUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .windowUnavailable:
            "The selected window is no longer available. Refresh the window list."
        case .sourceNotOnScreen:
            "The selected window is not visible on the current desktop."
        case .desktopUnavailable(let detail):
            "The desktop behind the selected window could not be captured: \(detail)"
        }
    }
}

@MainActor
public final class PeelWindowSnapshotter {
    public init() {}

    public func capture(_ window: SCWindow) async throws -> CGImage {
        guard window.frame.width > 0, window.frame.height > 0 else {
            throw PeelCaptureError.windowUnavailable
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(filter.contentRect.width * CGFloat(filter.pointPixelScale)))
        configuration.height = max(1, Int(filter.contentRect.height * CGFloat(filter.pointPixelScale)))
        configuration.showsCursor = false

        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
    }

    public func captureDesktopBehind(
        windowID: CGWindowID,
        windowFrame: CGRect,
        outputSize: CGSize
    ) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: false
        )
        guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() })
        else { throw PeelCaptureError.desktopUnavailable("main display missing") }
        guard let source = content.windows.first(where: { $0.windowID == windowID })
        else { throw PeelCaptureError.desktopUnavailable("source window missing") }
        let visibleWindowIDs = (CGWindowListCopyWindowInfo(
            .optionOnScreenOnly,
            kCGNullWindowID
        ) as? [[String: Any]] ?? []).compactMap {
            ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value
        }
        guard visibleWindowIDs.contains(windowID) else {
            throw PeelCaptureError.sourceNotOnScreen
        }
        let ownBundleID = Bundle.main.bundleIdentifier
        let excluded = content.windows.filter { window in
            window.windowID == source.windowID ||
                (ownBundleID != nil && window.owningApplication?.bundleIdentifier == ownBundleID)
        }
        let filter = SCContentFilter(display: display, excludingWindows: excluded)
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(filter.contentRect.width * CGFloat(filter.pointPixelScale)))
        configuration.height = max(1, Int(filter.contentRect.height * CGFloat(filter.pointPixelScale)))
        configuration.showsCursor = false

        let screenshot = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        guard let cropped = PeelDesktopCrop.image(
            screenshot,
            displayFrame: display.frame,
            sourceFrame: windowFrame,
            outputSize: outputSize
        ) else {
            throw PeelCaptureError.desktopUnavailable(
                "crop outside display: display \(display.frame), window \(windowFrame), image \(screenshot.width)x\(screenshot.height)"
            )
        }
        return cropped
    }
}

public struct PeelDesktopCrop: Equatable, Sendable {
    public let pixelRect: CGRect

    public init(displayFrame: CGRect, sourceFrame: CGRect, displayPixels: CGSize) {
        let scaleX = displayPixels.width / max(displayFrame.width, 1)
        let scaleY = displayPixels.height / max(displayFrame.height, 1)
        pixelRect = CGRect(
            x: (sourceFrame.minX - displayFrame.minX) * scaleX,
            y: (displayFrame.maxY - sourceFrame.maxY) * scaleY,
            width: sourceFrame.width * scaleX,
            height: sourceFrame.height * scaleY
        )
    }

    public static func image(
        _ displayImage: CGImage,
        displayFrame: CGRect,
        sourceFrame: CGRect,
        outputSize: CGSize
    ) -> CGImage? {
        let source = CIImage(cgImage: displayImage)
        let crop = PeelDesktopCrop(
            displayFrame: displayFrame,
            sourceFrame: sourceFrame,
            displayPixels: source.extent.size
        ).pixelRect
        guard source.extent.contains(crop), crop.width > 0, crop.height > 0,
              outputSize.width > 0, outputSize.height > 0 else { return nil }
        let normalized = source.cropped(to: crop).transformed(by: CGAffineTransform(
            a: outputSize.width / crop.width,
            b: 0,
            c: 0,
            d: outputSize.height / crop.height,
            tx: -crop.minX * outputSize.width / crop.width,
            ty: -crop.minY * outputSize.height / crop.height
        ))
        return CIContext().createCGImage(
            normalized,
            from: CGRect(origin: .zero, size: outputSize)
        )
    }
}

