# Peel Window

Peel Window is a native macOS interaction prototype for temporarily revealing
an obscured window by lifting a corner of the window above it.

The intended interaction is temporary: while the user holds a lifted corner,
the window directly underneath becomes visible; releasing the pointer restores
the original view. The user can choose active corners, maximum peel size, and
return strength; these settings persist across launches.

The first milestone is intentionally narrow: make the corner-peel gesture feel
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
  PeelRenderer/              Core Image page curl and Metal presentation
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
- Captured and sample windows use Core Image's page-curl transition, including
  a curved fold, paper backside, and shadow; a deep drag carries the fold
  toward the other corner on the same side
- Four independently enabled corners and spring return are implemented in the
  preview; the switches choose where a drag can start, not where the fold ends
- Pointer distance controls how much page is revealed, while its direction
  steers the fold between a side peel and a top or bottom peel
- Twenty-four package tests cover geometry, interaction, page-curl orientation,
  aspect-preserving preview layout, and per-corner lower-window selection
- Maximum peel size (10–100% reach along the preview edges) and return
  strength (0.25–2×) can be adjusted and persist across launches; peel size
  does not change drag sensitivity
- ScreenCaptureKit window discovery and still-image capture are wired into the
  app through an explicit Find Windows action
- The app opens with a local sample pair and a 50% curl preview, or can display
  selected front/underneath window snapshots without stretching them
- A desktop beta places a temporary snapshot overlay over a selected window
  and accepts drags from its enabled corners; it currently supports a window
  fully on the main display and needs final real-window validation
- Real dual-window capture and the peel gesture have been checked on a Mac
- An opt-in Auto-detect choice probes each corner separately and selects its
  lower snapshot when that corner is dragged; live capture during a peel remains
  future work

See [Docs/INSTALL.md](Docs/INSTALL.md) for the locally signed beta install steps.

See [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md) and
[Docs/ROADMAP.md](Docs/ROADMAP.md) for the working plan.

