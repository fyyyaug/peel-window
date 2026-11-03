import Testing
import PeelCore
@testable import PeelInteraction

@Test("Return strength adjusts the spring and stays within supported bounds")
func reboundStrengthConfiguration() {
    let gentle = PeelGestureConfiguration.reboundStrength(0.25)
    let firm = PeelGestureConfiguration.reboundStrength(2)

    #expect(gentle.stiffness < firm.stiffness)
    #expect(gentle.damping < firm.damping)
    #expect(PeelGestureConfiguration.reboundStrength(0).stiffness == gentle.stiffness)
    #expect(PeelGestureConfiguration.reboundStrength(3).stiffness == firm.stiffness)
}

@Test("Dragging produces a normalized peel pose")
func draggingProducesPose() {
    var machine = PeelGestureMachine(
        configuration: .init(maximumDragDistance: 100)
    )

    machine.begin(
        corner: .topRight,
        at: PeelPoint(x: 100, y: 100),
        timestamp: 0
    )
    machine.update(to: PeelPoint(x: 0, y: 20), timestamp: 0.1)

    #expect(machine.phase == .dragging)
    #expect(abs(machine.pose.progress - 1) < 0.000_001)
    #expect(machine.pose.pull.length <= 1.000_001)
    #expect(machine.pose.lift > 0.99)
}

@Test("Both bottom corners begin a diagonal peel toward the window center")
func bottomCornerGestures() {
    for (corner, targetX) in [(PeelCorner.bottomLeft, 150.0), (.bottomRight, 50.0)] {
        var machine = PeelGestureMachine(configuration: .init(maximumDragDistance: 100))
        machine.begin(corner: corner, at: PeelPoint(x: 100, y: 100), timestamp: 0)
        machine.update(to: PeelPoint(x: targetX, y: 150), timestamp: 0.1)
        #expect(machine.pose.corner == corner)
        #expect(machine.pose.progress > 0.6)
        #expect(machine.pose.progress < 0.65)
        #expect(machine.pose.lift > 0.8)
    }
}

@Test("Dragging a corner outward leaves the page flat")
func outwardCornerGestures() {
    for corner in PeelCorner.allCases {
        var machine = PeelGestureMachine(configuration: .init(maximumDragDistance: 100))
        machine.begin(corner: corner, at: PeelPoint(x: 100, y: 100), timestamp: 0)
        let outwardX = corner.unitPoint.x == 0 ? -50.0 : 50.0
        let outwardY = corner.unitPoint.y == 0 ? -50.0 : 50.0
        machine.update(
            to: PeelPoint(x: 100 + outwardX, y: 100 + outwardY),
            timestamp: 0.1
        )
        #expect(machine.pose.progress == 0)
        #expect(machine.pose.pull == .zero)
    }
}

@Test("Horizontal movement can open and close a curl during one drag")
func horizontalMovementControlsCurl() {
    var machine = PeelGestureMachine(configuration: .init(maximumDragDistance: 100))
    machine.begin(corner: .topRight, at: PeelPoint(x: 100, y: 100), timestamp: 0)
    machine.update(to: PeelPoint(x: 60, y: 20), timestamp: 0.1)
    let firstProgress = machine.pose.progress
    machine.update(to: PeelPoint(x: 20, y: 20), timestamp: 0.2)
    let deeperProgress = machine.pose.progress
    machine.update(to: PeelPoint(x: 80, y: 20), timestamp: 0.3)
    #expect(firstProgress > 0)
    #expect(deeperProgress > firstProgress)
    #expect(machine.pose.progress < firstProgress)

    var defaultMachine = PeelGestureMachine()
    defaultMachine.begin(corner: .topRight, at: PeelPoint(x: 700, y: 100), timestamp: 0)
    defaultMachine.update(to: PeelPoint(x: 620, y: 100), timestamp: 0.1)
    #expect(defaultMachine.pose.progress < 0.1)
}

@Test("Vertical travel opens more of the top edge at a fixed horizontal position")
func verticalTravelChangesExposure() {
    var machine = PeelGestureMachine(configuration: .init(maximumDragDistance: 100))
    machine.begin(corner: .topRight, at: PeelPoint(x: 100, y: 100), timestamp: 0)
    machine.update(to: PeelPoint(x: 60, y: 90), timestamp: 0.1)
    let shallowProgress = machine.pose.progress
    machine.update(to: PeelPoint(x: 60, y: 0), timestamp: 0.2)
    #expect(machine.pose.progress > shallowProgress)
    #expect(machine.pose.pull.y < 0)
}

@Test("Released peel settles back to the flat state")
func releaseSettlesToFlat() {
    var machine = PeelGestureMachine(
        configuration: .init(
            maximumDragDistance: 200,
            stiffness: 220,
            damping: 28
        )
    )

    machine.begin(
        corner: .topRight,
        at: PeelPoint(x: 200, y: 200),
        timestamp: 0
    )
    machine.update(to: PeelPoint(x: 80, y: 100), timestamp: 0.1)
    machine.end()

    #expect(machine.phase == .settling)

    for _ in 0..<360 {
        machine.advance(by: 1.0 / 120.0)
    }

    #expect(machine.phase == .idle)
    #expect(machine.pose == .flat)
}
