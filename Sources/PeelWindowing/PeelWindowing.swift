import CoreGraphics
@preconcurrency import ScreenCaptureKit

public struct PeelWindowChoice: Identifiable, Equatable, Sendable {
    public let id: CGWindowID
    public let applicationName: String
    public let title: String
    public let frame: CGRect

    public var displayName: String {
        "\(applicationName) — \(title)"
    }
}

@MainActor
public final class PeelWindowCatalog {
    private var windowsByID: [CGWindowID: SCWindow] = [:]

    public init() {}

    public func refresh() async throws -> [PeelWindowChoice] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            true,
            onScreenWindowsOnly: false
        )
        let ownBundleID = Bundle.main.bundleIdentifier
        let candidates = content.windows.filter { window in
            window.windowLayer == 0 &&
            window.frame.width >= 160 &&
            window.frame.height >= 120 &&
            window.owningApplication?.bundleIdentifier != ownBundleID
        }

        windowsByID = Dictionary(
            candidates.map { ($0.windowID, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return candidates.map { window in
            PeelWindowChoice(
                id: window.windowID,
                applicationName: window.owningApplication?.applicationName ?? String(localized: "Unknown App"),
                title: window.title.flatMap { $0.isEmpty ? nil : $0 } ?? String(localized: "Untitled Window"),
                frame: window.frame
            )
        }
        .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    public func window(withID id: CGWindowID) -> SCWindow? {
        windowsByID[id]
    }
}

