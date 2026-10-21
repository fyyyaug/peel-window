import Testing
@testable import PeelCore

@Test("A point is clamped without changing its direction")
func pointLengthClamping() {
    let point = PeelPoint(x: 3, y: 4).clampedLength(to: 2)

    #expect(abs(point.length - 2) < 0.000_001)
    #expect(abs(point.x / point.y - 0.75) < 0.000_001)
}

@Test("A peel pose clamps physical values to normalized bounds")
func poseClamping() {
    let pose = PeelPose(
        corner: .topRight,
        pull: PeelPoint(x: -0.5, y: -0.3),
        progress: 2,
        lift: -1
    )

    #expect(pose.progress == 1)
    #expect(pose.lift == 0)
}
