import Foundation
import PeelCore

public enum PeelGesturePhase: Equatable, Sendable {
    case idle
    case dragging
    case settling
}

public struct PeelGestureConfiguration: Equatable, Sendable {
    public var maximumDragDistance: Double
    public var stiffness: Double
    public var damping: Double

    public init(
        maximumDragDistance: Double = 280,
        stiffness: Double = 190,
        damping: Double = 24
    ) {
        self.maximumDragDistance = maximumDragDistance
        self.stiffness = stiffness
        self.damping = damping
    }

    public static func reboundStrength(_ value: Double) -> Self {
        let strength = value.clamped(to: 0.25...2)
        return Self(
            stiffness: 190 * strength,
            damping: 24 * sqrt(strength)
        )
    }
}

public struct PeelGestureMachine: Sendable {
    public private(set) var phase: PeelGesturePhase = .idle
    public private(set) var pose: PeelPose = .flat
    public private(set) var pointerVelocity: PeelPoint = .zero

    private let configuration: PeelGestureConfiguration
    private var origin: PeelPoint = .zero
    private var previousPoint: PeelPoint = .zero
    private var previousTimestamp: TimeInterval = 0
    private var releasedPose: PeelPose = .flat
    private var settleScale = SpringValue(value: 0)

    public init(configuration: PeelGestureConfiguration = .init()) {
        self.configuration = configuration
    }

    public mutating func begin(
        corner: PeelCorner,
        at point: PeelPoint,
        timestamp: TimeInterval
    ) {
        phase = .dragging
        origin = point
        previousPoint = point
        previousTimestamp = timestamp
        pointerVelocity = .zero
        pose = PeelPose(corner: corner, pull: .zero, progress: 0, lift: 0)
    }

    public mutating func update(to point: PeelPoint, timestamp: TimeInterval) {
        guard phase == .dragging else { return }

        let elapsed = max(timestamp - previousTimestamp, 1.0 / 240.0)
        let instantaneousVelocity = (point - previousPoint) * (1 / elapsed)
        pointerVelocity = pointerVelocity * 0.72 + instantaneousVelocity * 0.28
        previousPoint = point
        previousTimestamp = timestamp

        let rawDisplacement = point - origin
        let inwardDisplacement = PeelPoint(
            x: pose.corner.unitPoint.x == 0
                ? max(rawDisplacement.x, 0) : min(rawDisplacement.x, 0),
            y: pose.corner.unitPoint.y == 0
                ? max(rawDisplacement.y, 0) : min(rawDisplacement.y, 0)
        )
        let maximum = max(configuration.maximumDragDistance, 1)
        let clampedDisplacement = inwardDisplacement.clampedLength(to: maximum)
        let progress = clampedDisplacement.length / maximum
        let easedLift = sin(progress * .pi / 2)

        pose = PeelPose(
            corner: pose.corner,
            pull: clampedDisplacement * (1 / maximum),
            progress: progress,
            lift: easedLift
        )
    }

    public mutating func end() {
        guard phase == .dragging else { return }
        guard pose.progress > 0.001 else {
            reset()
            return
        }

        releasedPose = pose
        let radialVelocity = pointerVelocity.length / max(configuration.maximumDragDistance, 1)
        settleScale = SpringValue(value: 1, velocity: min(radialVelocity, 3))
        phase = .settling
    }

    @discardableResult
    public mutating func advance(by deltaTime: TimeInterval) -> PeelPose {
        guard phase == .settling else { return pose }

        settleScale.step(
            toward: 0,
            deltaTime: deltaTime,
            stiffness: configuration.stiffness,
            damping: configuration.damping
        )

        if settleScale.isAtRest(target: 0) {
            reset()
        } else {
            pose = releasedPose.scaled(by: max(settleScale.value, 0))
        }

        return pose
    }

    public mutating func cancel() {
        reset()
    }

    private mutating func reset() {
        phase = .idle
        pose = .flat
        pointerVelocity = .zero
        releasedPose = .flat
        settleScale = SpringValue(value: 0)
    }
}

struct SpringValue: Sendable {
    var value: Double
    var velocity: Double

    init(value: Double, velocity: Double = 0) {
        self.value = value
        self.velocity = velocity
    }

    mutating func step(
        toward target: Double,
        deltaTime: TimeInterval,
        stiffness: Double,
        damping: Double
    ) {
        var remaining = max(deltaTime, 0)
        let maximumStep = 1.0 / 120.0

        while remaining > 0 {
            let step = min(remaining, maximumStep)
            let acceleration = stiffness * (target - value) - damping * velocity
            velocity += acceleration * step
            value += velocity * step
            remaining -= step
        }
    }

    func isAtRest(target: Double) -> Bool {
        abs(value - target) < 0.001 && abs(velocity) < 0.01
    }
}

