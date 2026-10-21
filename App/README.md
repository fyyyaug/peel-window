# macOS app host

This directory contains the `PeelWindow.app` Xcode project in `PeelWindow/`.

The app target should remain thin. Its responsibilities are limited to:

- application lifecycle and menu-bar behavior;
- permission onboarding for Accessibility and Screen Recording;
- dependency composition across the package modules;
- entitlements, signing, assets, and release configuration;
- a small diagnostics/settings surface.

Window discovery, capture, interaction physics, rendering, and overlay behavior
belong in their corresponding Swift package modules.

The app links the repository's local Swift package and currently hosts the
synthetic Phase 1 Metal peel prototype. Open
`PeelWindow/PeelWindow.xcodeproj` to build and run it on My Mac.

