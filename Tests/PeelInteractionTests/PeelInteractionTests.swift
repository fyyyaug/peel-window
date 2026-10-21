import Testing
import PeelCore
@testable import PeelInteraction

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
    machine.update(to: PeelPoint(x: 40, y: 20), timestamp: 0.1)

    #expect(machine.phase == .dragging)
    #expect(abs(machine.pose.progress - 1) < 0.000_001)
    #expect(machine.pose.pull.length <= 1.000_001)
    #expect(machine.pose.lift > 0.99)
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
