# macOS app host

This directory will contain the `PeelWindow.app` Xcode project.

The app target should remain thin. Its responsibilities are limited to:

- application lifecycle and menu-bar behavior;
- permission onboarding for Accessibility and Screen Recording;
- dependency composition across the package modules;
- entitlements, signing, assets, and release configuration;
- a small diagnostics/settings surface.

Window discovery, capture, interaction physics, rendering, and overlay behavior
belong in their corresponding Swift package modules.

The project file is intentionally deferred until full Xcode is available so it
can be generated and validated by Xcode rather than hand-authored.

