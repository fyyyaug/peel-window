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
- [x] Let the user adjust and retain the return strength.
- [ ] Tune the deformation until the interaction reads as a paper-like curl.

Exit condition: a short screen recording makes the interaction immediately
understandable without explanation.

## M2 — Real window snapshot

- [x] Add user-initiated window discovery and front/underneath selection.
- [x] Guide the user through Screen Recording permission.
- [x] Implement single-frame ScreenCaptureKit capture and Metal textures.
- [x] Add a local sample pair to verify the reveal without screen access.
- [ ] Verify capture of selected real windows after permission is granted.
- [ ] Match the source window aspect and position without distortion.
- [ ] Handle moved, resized, closed, and protected windows safely.

Exit condition: the synthetic texture can be replaced with a real window image.
The selected lower image must be hidden while the upper image is flat and become
visible only in the peeled region. Real screen permission and window selection
still need an end-to-end run on the user's Mac.

## M3 — Desktop overlay illusion

- Add the transparent borderless overlay.
- Route pointer input without trapping the user.
- Coordinate source-window visibility and overlay teardown.
- Add cancellation and recovery for focus or permission changes.
- Identify the actual window below the source window and reveal it only while
  the user is peeling; fully restore the source view on release or cancellation.

Exit condition: the user can peel and release a normal supported window without
leaving artifacts or losing control of the desktop. The glimpse must show the
real window underneath, not a manually chosen preview image.

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

