/// Namespace for the platform-light domain module.
public enum PeelCoreModule {}

public enum PeelCorner: String, CaseIterable, Hashable, Sendable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    public var unitPoint: PeelPoint {
        switch self {
        case .topLeft: PeelPoint(x: 0, y: 1)
        case .topRight: PeelPoint(x: 1, y: 1)
        case .bottomLeft: PeelPoint(x: 0, y: 0)
        case .bottomRight: PeelPoint(x: 1, y: 0)
        }
    }
}

public struct PeelPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = PeelPoint(x: 0, y: 0)

    public var length: Double {
        (x * x + y * y).squareRoot()
    }

    public func clampedLength(to maximum: Double) -> PeelPoint {
        guard maximum > 0, length > maximum else { return self }
        return self * (maximum / length)
    }

    public static func + (lhs: PeelPoint, rhs: PeelPoint) -> PeelPoint {
        PeelPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    public static func - (lhs: PeelPoint, rhs: PeelPoint) -> PeelPoint {
        PeelPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    public static func * (lhs: PeelPoint, rhs: Double) -> PeelPoint {
        PeelPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
}

public struct PeelPose: Equatable, Sendable {
    public var corner: PeelCorner
    public var pull: PeelPoint
    public var progress: Double
    public var lift: Double

    public init(
        corner: PeelCorner,
        pull: PeelPoint,
        progress: Double,
        lift: Double
    ) {
        self.corner = corner
        self.pull = pull
        self.progress = progress.clamped(to: 0...1)
        self.lift = lift.clamped(to: 0...1)
    }

    public static let flat = PeelPose(
        corner: .topRight,
        pull: .zero,
        progress: 0,
        lift: 0
    )

    public func scaled(by scale: Double) -> PeelPose {
        let safeScale = scale.clamped(to: 0...1)
        return PeelPose(
            corner: corner,
            pull: pull * safeScale,
            progress: progress * safeScale,
            lift: lift * safeScale
        )
    }
}

public extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

