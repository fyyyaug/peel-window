# Tests

Run `swift test` with the full Xcode toolchain. The eleven Swift Testing cases
cover domain geometry, spring interaction, Metal mesh topology, preview aspect
mapping, and the stack-order rule for finding the window under a curled corner.

The stack-order tests use synthetic window metadata. Real ScreenCaptureKit
permission, snapshot capture, and user input are checked in the macOS app.

