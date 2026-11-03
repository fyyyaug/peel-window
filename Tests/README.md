# Tests

Run `swift test` with the full Xcode toolchain. The seventeen Swift Testing cases
cover domain geometry, inward-only spring interaction, full-page Metal turns,
preview aspect mapping, turn limits, and the stack-order rule at all four corners.

The stack-order tests use synthetic window metadata. Real ScreenCaptureKit
permission, snapshot capture, and user input are checked in the macOS app.

