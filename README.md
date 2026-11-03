# Peel Window

Peel Window is a native macOS interaction prototype for temporarily revealing
an obscured window by lifting a corner of the window above it.

The intended interaction is temporary: while the user holds a peeled corner,
the window directly underneath becomes visible; releasing the pointer restores
the original view. The user can choose active corners, maximum peel size, and
return strength; these settings persist across launches.

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
- Native macOS Xcode app created in `App/PeelWindow`
- Local Swift package connected to the app target
- Synthetic Metal window mesh renders in the app
- Four independently enabled corners, normalized peel pose, and spring return
  are implemented in the preview
- Fourteen package tests cover geometry, interaction, mesh deformation,
  aspect-preserving preview layout, and per-corner lower-window selection
- Maximum peel size (10–100% reach along the preview edges) and return
  strength (0.25–2×) can be adjusted and persist across launches
- ScreenCaptureKit window discovery and still-image capture are wired into the
  app through an explicit Find Windows action
- The app can display a local sample pair or selected front/underneath window
  snapshots without stretching them; the true desktop overlay is a later
  milestone
- Real dual-window capture and the peel gesture have been checked on a Mac
- An opt-in Auto-detect choice probes each corner separately and selects its
  lower snapshot when that corner is dragged; the desktop overlay and live
  reveal remain future work

See [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md) and
[Docs/ROADMAP.md](Docs/ROADMAP.md) for the working plan.

