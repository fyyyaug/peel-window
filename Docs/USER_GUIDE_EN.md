# Peel Window User Guide

[中文](USER_GUIDE_ZH.md) · [Download page](https://github.com/fyyyaug/peel-window/releases/tag/v0.1.0-beta.2)

Peel Window temporarily curls a window like a book page, revealing the view behind it. Release the mouse to let the window spring back.

## 1. Download and install

- Requires an Apple silicon Mac (M series) running macOS 14 or later.
- Download [PeelWindow-0.1.0-macos-arm64.dmg](https://github.com/fyyyaug/peel-window/releases/download/v0.1.0-beta.2/PeelWindow-0.1.0-macos-arm64.dmg). This is the only download required. You do not need Source code, Xcode, or additional dependencies.
- Open the DMG, drag `PeelWindow.app` into `Applications`, then launch it from Applications.

This beta is not notarized by Apple. If macOS blocks the first launch, first attempt to open it, then go to **System Settings → Privacy & Security** and choose **Open Anyway** for PeelWindow. Only approve an application whose source you trust.

Peel Window uses the first supported language in your macOS preferences and falls back to English when none matches. To choose a different language for Peel Window, open **System Settings → General → Language & Region → Applications** and reopen the app.

## 2. First launch: allow screen recording

1. On the Desktop page (`桌面翻页`), click Set Up Permission (`设置权限`).
2. Allow PeelWindow under **System Settings → Privacy & Security → Screen & System Audio Recording** (called Screen Recording on some versions).
3. Choose **Quit & Reopen** if macOS requests it.
4. Return to the app and check for Screen Recording Ready (`录屏权限已就绪`). Click Check Again (`重新检查`) if necessary.

Screen recording access is required to capture windows and the view behind them for desktop peeling.

## 3. Start peeling

1. Enable Continuous Desktop Peeling (`桌面持续翻页`).
2. In Word, Xcode, or another supported application, move the pointer to an enabled, exposed window corner.
3. After the configured hover time, a corner marker appears.
4. Press in the center of the marker and drag inward. Horizontal and vertical movement steer the curl and change the exposed area.
5. Release to restore the window. Move away from the corner, then approach it again for another peel.

Switching applications, moving a window, or closing a window does not turn off the main switch. You do not need to select and capture each application manually.

The marker can appear before the first image is ready. If you press and drag while preparation is running, the app continues your held gesture when the image is ready. Releasing early cancels that gesture.

## 4. Desktop page (`桌面翻页`)

| Setting | Purpose |
| --- | --- |
| Continuous Desktop Peeling (`桌面持续翻页`) | Turns desktop peeling on or off. The app menu also provides Enable Desktop Peeling. |
| Four corners | Independently enable the top left, top right, bottom left, and bottom right corners. Keep at least one enabled. These settings control where a drag may begin. |
| Maximum Peel Size (`最大翻开范围`) | 10–100%; limits the maximum exposed area. |
| Return Strength (`回弹力度`) | 0.25–2×; adjusts the spring return after release. |
| Hover Activation Time (`鼠标悬停生效时间`) | 0–10 seconds. Type three decimal places, such as `0.100`, `0.010`, or `0.001`. Set `0` to add no intentional delay. |

Zero delay does not mean zero physical latency: pointer detection, display refresh, and image preparation still take time. The app prepares images as the pointer approaches a corner. Displaying the marker no longer waits for screenshot completion.

## 5. Corner Marker page (`提示标记`)

You can also open marker preferences through **PeelWindow → Settings…** or `⌘,`.

| Setting | Range or behavior |
| --- | --- |
| Size (`大小`) | 24–140 points. Small windows automatically limit marker size to keep it inside the window. |
| Opacity (`不透明度`) | 10–100%; lower values are more transparent. |
| Color (`颜色`) | Choose a custom color using the color picker. |
| Hover Activation Time (`鼠标悬停生效时间`) | Shared with the Desktop page; controls how long to hover before the marker appears. |
| Visible duration (`显示时长`) | 0–30 seconds. `0` keeps the marker visible while hovering. |
| Restore Defaults (`恢复默认设置`) | Resets marker appearance and timing, without changing maximum peel size or return strength. |

A preview shows the marker appearance. After a timed marker hides, move away and approach the corner again to show it. The visible-duration setting never interrupts an active drag.

Preferences are saved automatically, including the desktop-mode switch, and restored when you relaunch the app. Launch the app manually; this version does not add a login item.

## 6. Peel Preview page (`翻页预览`)

- **Sample Pair** loads built-in sample images without capturing real windows.
- **Preview 50%** shows a still curl. Click Resume to return to interaction.
- **Find Windows → select windows → Capture** previews real window snapshots inside the app.
- **Auto-detect actual window below** chooses a lower window for the preview corner. A lower window can also be selected manually.

These manual capture controls are for the preview. Everyday desktop peeling only requires the main switch.

## 7. Pause or quit

Turn off Continuous Desktop Peeling on the Desktop page, or uncheck **Enable Desktop Peeling** in the app menu. Closing the main settings window does not quit the background application. To exit completely, use **PeelWindow → Quit PeelWindow**.

## 8. Troubleshooting and current limits

**No corner marker**

Check that desktop mode is enabled, screen recording access is ready, and the pointer is at an enabled, exposed corner. Check hover time and opacity, and wait for the configured delay. If the marker timed out, move away and approach again.

**Permission is enabled, but the app reports no access after an update**

Quit the app. Remove the old PeelWindow entry from the system screen-recording list, add `/Applications/PeelWindow.app`, and enable it again. Restart as requested by macOS. Updates to this locally signed beta may require refreshing that permission record.

**The revealed content is not live**

Peeling uses still screenshots rather than live video. Move away and begin a new peel to prepare a fresh image.

**Some windows cannot be peeled**

The current version supports ordinary windows of sufficient size that are fully inside the main display. Multiple displays, windows spanning displays, and all special system windows are not supported. Covered corners do not accept peel input. Protected content may not capture correctly. This beta does not guarantee compatibility with every application or bug-free operation.
