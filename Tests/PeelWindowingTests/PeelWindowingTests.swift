import CoreGraphics
import Testing
@testable import PeelWindowing

@Test("Automatic lower-window selection respects stacking and the curled corner")
func choosesFirstWindowCoveringCorner() {
    let source = CGRect(x: 100, y: 100, width: 600, height: 400)
    let windows = [
        PeelStackWindow(id: 11, frame: CGRect(x: 0, y: 0, width: 300, height: 300), layer: 0, alpha: 1, ownerPID: 2),
        PeelStackWindow(id: 12, frame: source, layer: 2, alpha: 1, ownerPID: 2),
        PeelStackWindow(id: 13, frame: source, layer: 0, alpha: 1, ownerPID: 99),
        PeelStackWindow(id: 14, frame: source, layer: 0, alpha: 0, ownerPID: 2),
        PeelStackWindow(id: 15, frame: CGRect(x: 400, y: 100, width: 400, height: 400), layer: 0, alpha: 1, ownerPID: 2),
        PeelStackWindow(id: 16, frame: source, layer: 0, alpha: 1, ownerPID: 2),
    ]

    #expect(PeelWindowStack.firstWindowBelow(
        sourceFrame: source,
        orderedWindows: windows,
        excludingPID: 99
    ) == 15)
}

@Test("Automatic lower-window selection returns nil for an uncovered corner")
func uncoveredCornerHasNoWindow() {
    let source = CGRect(x: 100, y: 100, width: 600, height: 400)
    let windows = [
        PeelStackWindow(id: 11, frame: CGRect(x: 100, y: 300, width: 200, height: 200), layer: 0, alpha: 1, ownerPID: 2)
    ]
    #expect(PeelWindowStack.firstWindowBelow(
        sourceFrame: source,
        orderedWindows: windows,
        excludingPID: 99
    ) == nil)
}
