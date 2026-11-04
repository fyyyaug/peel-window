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
4. Select the front window and click **Capture**. The lower-window menu affects
   the in-app preview only; desktop mode captures the actual background behind
   the selected window when that window becomes active.
5. Click **Use on Desktop**, bring the selected window to the front if needed,
   wait for the teal corner markers, and drag a marker inward.
   The selected window must be brought forward within five minutes.
   The overlay stops if the source app changes or the window moves or closes.

If macOS keeps an older PeelWindow permission entry after an update, remove
that entry in the recording permissions list, add the installed app from
`/Applications/PeelWindow.app`, and enable it again.

The DMG is provided as a beta for users who are comfortable approving an
unnotarized app. A Developer ID and notarization are needed for a smoother
public download experience.

Project maintainers can rebuild the DMG with `Scripts/package-beta.sh` from
the repository root. It signs the app locally with an ad hoc signature; it
does not create an Apple Developer ID signature.
