# Tests

Run `swift test` with the full Xcode toolchain. The twenty-four Swift Testing cases
cover domain geometry, spring interaction, two-axis drag control, all four
starting corners, native page-curl orientation, preview aspect mapping, peel-size limits, and the
stack-order rule at all four corners.

The stack-order tests use synthetic window metadata. Real ScreenCaptureKit
permission, snapshot capture, and user input are checked in the macOS app.

