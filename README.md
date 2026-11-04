# Peel Window

[**下载 Peel Window 安装包（Apple 芯片 Mac）**](https://github.com/fyyyaug/peel-window/releases/download/v0.1.0-beta.1/PeelWindow-0.1.0-macos-arm64.dmg)

只需下载这一个 DMG：打开后将 `PeelWindow.app` 拖入 Applications，再启动应用。
无需下载源码、Xcode 或其他依赖。支持 Apple 芯片 Mac（M 系列）、macOS 14 及以上。

本测试版尚未通过 Apple 公证；首次打开若被 macOS 阻止，请在“系统设置 → 隐私与安全性”中选择针对 PeelWindow 的“仍要打开”。首次翻页需允许屏幕录制权限，并按系统提示重新启动。

[版本说明与下载页面](https://github.com/fyyyaug/peel-window/releases/tag/v0.1.0-beta.1)


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
- Thirty-six package tests cover geometry, interaction, page-curl orientation,
  preview and desktop layout, display cropping, and per-corner selection
- Maximum peel size (10–100% reach along the preview edges) and return
  strength (0.25–2×) can be adjusted and persist across launches; peel size
  does not change drag sensitivity
- ScreenCaptureKit window discovery and still-image capture are wired into the
  app through an explicit Find Windows action
- The app opens with a local sample pair and a 50% curl preview, or can display
  selected front/underneath window snapshots without stretching them
- A desktop beta captures the actual desktop behind the selected window when
  it becomes active, then accepts drags from visible inset corner markers. It
  currently supports a window fully on the main display and uses still snapshots
- Real dual-window capture and the peel gesture have been checked on a Mac
- An opt-in Auto-detect choice probes each corner separately and selects its
  lower snapshot when that corner is dragged; live capture during a peel remains
  future work

See [Docs/INSTALL.md](Docs/INSTALL.md) for the locally signed beta install steps.

See [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md) and
[Docs/ROADMAP.md](Docs/ROADMAP.md) for the working plan.


Desktop mode now stays enabled until its app option is switched off. It automatically
prepares exposed corners under the pointer across applications; manual Capture is
only needed for the in-app preview.

Corner marker size, opacity, color, appearance delay, and visible duration can be
changed in PeelWindow Settings, with a live preview and automatic saving.

Hover activation accepts seconds to three decimal places (for example 0.100,
0.010 or 0.001). Capture preparation runs concurrently with the hover timer;
actual activation still depends on system scheduling and capture readiness.

The lightweight corner prompt is independent of screenshot and renderer readiness;
zero delay no longer waits for capture before displaying the marker. Capture is
prewarmed near corners, with held pointer input replayed when images are ready.
