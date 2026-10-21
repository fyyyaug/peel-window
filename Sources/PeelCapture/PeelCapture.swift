import CoreGraphics
@preconcurrency import ScreenCaptureKit

public enum PeelCaptureError: LocalizedError {
    case windowUnavailable

    public var errorDescription: String? {
        switch self {
        case .windowUnavailable:
            "The selected window is no longer available. Refresh the window list."
        }
    }
}

@MainActor
public final class PeelWindowSnapshotter {
    public init() {}

    public func capture(_ window: SCWindow) async throws -> CGImage {
        guard window.isOnScreen, window.frame.width > 0, window.frame.height > 0 else {
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
}

