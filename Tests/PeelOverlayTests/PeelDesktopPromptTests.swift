import AppKit
import Testing
import PeelCore
@testable import PeelOverlay

@Test("The prompt can appear and disappear without capturing or creating a renderer")
@MainActor
func promptDoesNotWaitForCapture() {
    _ = NSApplication.shared
    let prompt = PeelDesktopPrompt(frame: CGRect(x: 100, y: 100, width: 400, height: 300),
        screenHeight: 900, corners: [.topRight])
    #expect(!prompt.isVisible)
    prompt.show()
    #expect(prompt.isVisible)
    #expect(!prompt.isPressed)
    prompt.hide()
    #expect(!prompt.isVisible)
}
