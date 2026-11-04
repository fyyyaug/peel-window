# Install Peel Window 0.1 beta

This beta is for Apple silicon Macs running macOS 14 or later. The first
desktop mode supports a window fully on the main display. It uses still window
snapshots while a page is curled, so changing content requires a new Capture.

## Install

1. Open the DMG and drag `PeelWindow.app` into `Applications`.
2. Open `PeelWindow.app`. This beta has a local ad hoc signature, not a
   Developer ID signature or Apple notarization. If macOS blocks the first
   launch, open **System Settings → Privacy & Security** and use **Open Anyway**
   for PeelWindow. Do not disable Gatekeeper globally.
3. In PeelWindow, click **Find Windows**. macOS will ask for **Screen & System
   Audio Recording** access. Allow PeelWindow and restart it if prompted.
4. Click **Enable Desktop**, or use **PeelWindow → Enable Desktop Peeling**.
   The switch is retained across launches. No manual window selection is needed.
5. Move the pointer near an enabled, exposed corner of any supported window.
   Wait for its teal marker, then drag inward. Release to restore the window.
   Move away and approach a corner again to prepare a fresh snapshot.
6. Application switches, window movement, and closing a window retire only that
   window's overlay. Desktop mode stays enabled and prepares the next corner.
   Turn it off using **Disable Desktop** or the application menu option.

The current desktop renderer supports windows fully on the main display.
Unsupported windows are skipped while desktop mode remains enabled.

If macOS keeps an older PeelWindow permission entry after an update, remove
that entry in the recording permissions list, add the installed app from
`/Applications/PeelWindow.app`, and enable it again.

The DMG is provided as a beta for users who are comfortable approving an
unnotarized app. A Developer ID and notarization are needed for a smoother
public download experience.

Project maintainers can rebuild the DMG with `Scripts/package-beta.sh` from
the repository root. It signs the app locally with an ad hoc signature; it
does not create an Apple Developer ID signature.

## Corner marker preferences

Open **PeelWindow → Settings…** (Command-comma) to adjust marker size (24–140
points), opacity (10–100%), color, hover activation delay (0–10 seconds), and visible
duration (0–30 seconds). Zero duration keeps the marker visible while hovering.
After a timed marker hides, leave and approach the corner to show it again.
Dragging is never interrupted by the visible-duration setting. Preferences are
saved automatically; the settings window includes a preview and reset button.

The main window has Desktop, Marker, and Preview tabs. Desktop includes the
persistent switch, four corner choices, maximum reach, spring strength, and hover
activation time. The Marker tab includes all appearance and timing preferences.

Hover delay can be typed directly with 0.001-second setting precision. The marker
becomes interactive once both the configured delay and image preparation finish.
This is a delay preference, not a guarantee of millisecond screen-capture latency.

Corner prompts now appear independently of screenshot preparation. Zero hover
delay shows the prompt on the next mouse check instead of waiting for capture.
Captures are prepared as the pointer approaches a corner. A press made while
preparation is still running is retained while held, and replayed with the latest
pointer position when ready; releasing early cancels it.
