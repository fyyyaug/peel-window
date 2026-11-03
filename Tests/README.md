# Tests

Run `swift test` with the full Xcode toolchain. The fourteen Swift Testing cases
cover domain geometry, spring interaction, Metal mesh topology, preview aspect
mapping, size limits, and the stack-order rule at all four corners.

The stack-order tests use synthetic window metadata. Real ScreenCaptureKit
permission, snapshot capture, and user input are checked in the macOS app.

