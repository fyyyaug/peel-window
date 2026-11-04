import CoreGraphics
import PeelCore

public struct PeelDesktopTarget: Equatable, Sendable {
    public let id: CGWindowID
    public let frame: CGRect
    public let processID: Int32

    public init(id: CGWindowID, frame: CGRect, processID: Int32) {
        self.id = id
        self.frame = frame
        self.processID = processID
    }

    /// Input uses the Window Server's top-left screen coordinate system.
    public static func atCorner(
        pointer: CGPoint, frontToBack: [Self], enabledCorners: [PeelCorner],
        displayFrame: CGRect, ownProcessID: Int32
    ) -> Self? {
        guard let window = frontToBack.first(where: { $0.frame.contains(pointer) }),
              window.processID != ownProcessID,
              displayFrame.contains(window.frame), window.frame.width >= 160,
              window.frame.height >= 120 else { return nil }
        return enabledCorners.contains { corner in
            let point = corner.unitPoint
            let x = point.x == 0 ? window.frame.minX : window.frame.maxX
            let y = point.y == 0 ? window.frame.maxY : window.frame.minY
            return abs(pointer.x - x) <= 100 && abs(pointer.y - y) <= 100
        } ? window : nil
    }
}
