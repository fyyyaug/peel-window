# Roadmap

## M0 — Architecture scaffold

- [x] Define module boundaries and dependency direction.
- [x] Establish a Swift package with independently buildable modules.
- [x] Document the macOS visual-surrogate constraint.
- [x] Add the thin Xcode app host and connect the local package.

Exit condition met: the package and macOS app build from a clean checkout, and
the package test targets run with the full Xcode testing runtime.

## M1 — Synthetic peel prototype

- [x] Render a static sample window surface.
- [x] Detect a drag from the highlighted top-right corner.
- [x] Deform a small Metal mesh from flat to peeled.
- [x] Settle back with a tunable spring animation.
- [x] Display phase, peel progress, and frame time.
- [ ] Tune the deformation until the interaction reads as a paper-like curl.

Exit condition: a short screen recording makes the interaction immediately
understandable without explanation.

## M2 — Real window snapshot

- Enumerate visible windows and select a supported target.
- Guide the user through Screen Recording permission.
- Capture a still frame and align it with the source window.
- Handle moved, resized, closed, and protected windows safely.

Exit condition: the synthetic texture can be replaced with a real window image.

## M3 — Desktop overlay illusion

- Add the transparent borderless overlay.
- Route pointer input without trapping the user.
- Coordinate source-window visibility and overlay teardown.
- Add cancellation and recovery for focus or permission changes.

Exit condition: the user can peel and release a normal supported window without
leaving artifacts or losing control of the desktop.

## M4 — Portfolio-quality demo

- Tune edge curl, lighting, shadow, stiffness, and snap-back timing.
- Measure capture latency and frame rate on representative hardware.
- Add a safe demo mode and minimal settings.
- Record the hero video and document constraints and failed approaches.

Exit condition: a stable 10–20 second demonstration is ready for a portfolio.

## Explicitly deferred

- Multi-display and mixed-scale correctness
- Every corner and arbitrary peel directions
- Continuous live capture while peeling
- Distribution outside local development
- Windows or Linux implementations
- Productivity features unrelated to the core interaction

