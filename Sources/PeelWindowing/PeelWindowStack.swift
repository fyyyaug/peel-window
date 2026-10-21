import CoreGraphics
import Foundation

public struct PeelStackWindow: Equatable, Sendable {
    public let id: CGWindowID
    public let frame: CGRect
    public let layer: Int
    public let alpha: Double
    public let ownerPID: Int32

    public init(id: CGWindowID, frame: CGRect, layer: Int, alpha: Double, ownerPID: Int32) {
        self.id = id
        self.frame = frame
        self.layer = layer
        self.alpha = alpha
        self.ownerPID = ownerPID
    }
}

public enum PeelWindowStack {
    /// The ordered input is front-to-back; the first window covering the curl
    /// probe point is the window the user would actually see at that corner.
    public static func firstWindowBelow(
        sourceFrame: CGRect,
        orderedWindows: [PeelStackWindow],
        excludingPID: Int32
    ) -> CGWindowID? {
        guard sourceFrame.width > 0, sourceFrame.height > 0 else { return nil }
        let inset = min(80, max(24, min(sourceFrame.width, sourceFrame.height) * 0.1))
        // Core Graphics global window bounds use a top-left screen origin.
        let probe = CGPoint(x: sourceFrame.maxX - inset, y: sourceFrame.minY + inset)
        return orderedWindows.first { window in
            window.layer == 0 &&
                window.alpha > 0.01 &&
                window.ownerPID != excludingPID &&
                window.frame.contains(probe)
        }?.id
    }
}

@MainActor
public final class PeelWindowStackResolver {
    public init() {}

    public func windowBelow(sourceID: CGWindowID, sourceFrame: CGRect) -> CGWindowID? {
        let options: CGWindowListOption = [
            .optionOnScreenBelowWindow,
            .excludeDesktopElements,
        ]
        guard let dictionaries = CGWindowListCopyWindowInfo(options, sourceID) as? [[String: Any]] else {
            return nil
        }
        let windows = dictionaries.compactMap { dictionary -> PeelStackWindow? in
            guard
                let id = (dictionary[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                let bounds = dictionary[kCGWindowBounds as String] as? [String: Any],
                let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                let layer = (dictionary[kCGWindowLayer as String] as? NSNumber)?.intValue,
                let ownerPID = (dictionary[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value
            else {
                return nil
            }
            let alpha = (dictionary[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
            return PeelStackWindow(
                id: id,
                frame: frame,
                layer: layer,
                alpha: alpha,
                ownerPID: ownerPID
            )
        }
        return PeelWindowStack.firstWindowBelow(
            sourceFrame: sourceFrame,
            orderedWindows: windows,
            excludingPID: ProcessInfo.processInfo.processIdentifier
        )
    }
}
