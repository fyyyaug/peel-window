import CoreGraphics
import Testing
import PeelCore
@testable import PeelWindowing

@Test("Every application's exposed corner can be targeted without activation")
func cornersAcrossApplications() {
    let first = PeelDesktopTarget(id: 1, frame: CGRect(x: 0, y: 0, width: 300, height: 300), processID: 10)
    let second = PeelDesktopTarget(id: 2, frame: CGRect(x: 400, y: 100, width: 300, height: 300), processID: 20)
    let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
    for (pointer, expected) in [(CGPoint(x: 280, y: 20), first), (CGPoint(x: 680, y: 120), second)] {
        #expect(PeelDesktopTarget.atCorner(pointer: pointer, frontToBack: [first, second],
            enabledCorners: [.topRight], displayFrame: screen, ownProcessID: 99) == expected)
    }
}

@Test("An obscured window corner cannot capture pointer input through another window")
func coveredCorner() {
    let upper = PeelDesktopTarget(id: 1, frame: CGRect(x: 200, y: 0, width: 300, height: 300), processID: 10)
    let lower = PeelDesktopTarget(id: 2, frame: CGRect(x: 0, y: 0, width: 300, height: 300), processID: 20)
    #expect(PeelDesktopTarget.atCorner(pointer: CGPoint(x: 280, y: 20), frontToBack: [upper, lower],
        enabledCorners: [.topRight], displayFrame: CGRect(x: 0, y: 0, width: 1000, height: 800),
        ownProcessID: 99) == nil)
}

@Test("The app's settings and disabled corners stay usable")
func settingsAndDisabledCorners() {
    let window = PeelDesktopTarget(id: 1, frame: CGRect(x: 0, y: 0, width: 300, height: 300), processID: 99)
    let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
    #expect(PeelDesktopTarget.atCorner(pointer: CGPoint(x: 280, y: 20), frontToBack: [window],
        enabledCorners: [.topRight], displayFrame: screen, ownProcessID: 99) == nil)
    #expect(PeelDesktopTarget.atCorner(pointer: CGPoint(x: 280, y: 20), frontToBack: [window],
        enabledCorners: [.bottomLeft], displayFrame: screen, ownProcessID: 1) == nil)
}
