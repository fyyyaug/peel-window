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

The app links the repository's local Swift package. Open
`PeelWindow/PeelWindow.xcodeproj` to build and run it on My Mac. The Sample Pair
button demonstrates the front/underneath reveal without screen access. The
Find Windows button requests macOS Screen Recording access when needed; after
granting it in System Settings, restart PeelWindow and choose the windows to
capture. Return strength is adjustable in the top-right slider and saved for
the next launch.

