# Peel Window

Peel Window is a native macOS interaction prototype for temporarily revealing
an obscured window by lifting a corner of the window above it.

The first milestone is intentionally narrow: make the peel gesture feel
immediate, physical, and visually convincing before integrating with arbitrary
macOS windows.

## Repository layout

```text
App/                         Thin macOS application host (created in Xcode)
Sources/
  PeelCore/                  Shared models and coordinate conventions
  PeelInteraction/           Gesture state machine and spring behavior
  PeelWindowing/             Window discovery and Accessibility integration
  PeelCapture/               ScreenCaptureKit capture pipeline
  PeelRenderer/              Metal mesh deformation and shaders
  PeelOverlay/               AppKit overlay panels and event routing
Tests/                       Fast package-level tests
Docs/                        Architecture and delivery decisions
Prototypes/                  Disposable experiments, kept out of production code
```

The reusable modules are a Swift package. The final application will be a thin
AppKit host that wires those modules together and owns entitlements,
permissions, and lifecycle.

## Current status

- Architecture scaffold created
- Module dependency graph builds with Swift Package Manager
- Product behavior is intentionally not implemented yet
- A full Xcode installation is required before the macOS app target is added

See [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md) and
[Docs/ROADMAP.md](Docs/ROADMAP.md) for the working plan.

