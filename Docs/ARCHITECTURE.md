# Architecture

## Product boundary

Peel Window does not attempt to deform another application's real window.
Instead, the MVP creates a short-lived visual surrogate:

1. Identify the foreground window and the corner being dragged.
2. Capture a current image of that window.
3. Place the image in a transparent, borderless overlay aligned to the source.
4. Curl the captured image with Core Image and present it through Metal while
   the source window is visually suppressed or covered.
5. Reveal the real desktop and windows underneath.
6. Animate the surrogate back, then restore the normal window presentation.

This boundary keeps the prototype compatible with public macOS APIs and makes
the illusion replaceable without coupling it to the interaction model.

The M2 app preview can use two manually selected still images to test the reveal.
The final interaction must determine the actual window immediately below the
source and show it only during the peel. A completed release or cancellation
must leave the desktop looking exactly as it did before the gesture. Return
strength is a user setting, stored locally and applied to the spring motion.

## Module responsibilities

### PeelCore

Platform-light domain types shared by every module: window identity, rectangles,
corners, normalized peel progress, timestamps, and errors. This module owns the
project's coordinate-space conventions.

### PeelInteraction

The input state machine: idle, armed, dragging, settling, cancelled. It will own
corner hit-testing, gesture thresholds, velocity estimation, spring targets,
and cancellation rules. It must not know how pixels are captured or rendered.

### PeelWindowing

macOS window discovery and control through Core Graphics and Accessibility APIs.
It will translate system window information into `PeelCore` models and contain
all coordinate conversion at the operating-system boundary.

### PeelCapture

ScreenCaptureKit integration and frame lifecycle. It will produce window images
or GPU-compatible surfaces for a selected window, while keeping capture latency
and stale-frame handling explicit.

### PeelRenderer

Core Image page-curl composition and Metal presentation. It receives
interaction state and captured pixels; it does not discover windows or own
permissions. The synthetic mesh remains a fallback when no image is loaded.

### PeelOverlay

Borderless AppKit panels, event routing, source-window alignment, and overlay
visibility. It composes the renderer with the interaction state machine but
does not implement capture or system window discovery.

### PeelWindow.app

The composition root. It requests permissions, creates concrete services,
manages lifecycle, and exposes diagnostics. Business and rendering behavior
should remain in package modules so they can be tested independently.

## Dependency direction

```text
                         PeelWindow.app
                        /      |       \
             PeelWindowing  PeelCapture  PeelOverlay
                    \         /          /       \
                     \       /  PeelInteraction  PeelRenderer
                      \     /          \          /
                       ----------- PeelCore -------
```

Dependencies point toward `PeelCore`. Platform services must not be imported
into interaction or domain code.

## Architectural rules

- Keep AppKit, Accessibility, ScreenCaptureKit, and Metal behind module
  boundaries.
- Use dependency injection at the app layer; avoid global singleton services.
- Represent gesture and peel progress deterministically so interaction tests do
  not require a real desktop.
- Treat capture frames as short-lived resources with explicit ownership.
- Keep prototypes disposable. Promote code only after its behavior is understood.
- Request system permissions only when the corresponding feature is first used.
- Optimize for a convincing single-display demo before multi-display support.

## Initial technical decisions

- Language: Swift 6
- Minimum deployment target: macOS 14
- UI shell: AppKit, with SwiftUI allowed for settings and onboarding
- Rendering: Metal
- Capture: ScreenCaptureKit
- Window metadata/control: Core Graphics and Accessibility APIs
- Build split: thin Xcode app plus local Swift package modules

These are working decisions, not permanent commitments. Record meaningful
changes in this document before reorganizing modules.

