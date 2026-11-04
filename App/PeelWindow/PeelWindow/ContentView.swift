import SwiftUI
import PeelOverlay
import PeelCore

struct ContentView: View {
    var body: some View {
        TabView {
            DesktopPreferencesView()
                .tabItem { Label("桌面翻页", systemImage: "macwindow.on.rectangle") }
            MarkerSettingsView()
                .tabItem { Label("提示标记", systemImage: "cursorarrow.rays") }
            PeelDemoRepresentable()
                .tabItem { Label("翻页预览", systemImage: "play.rectangle") }
        }.tint(.teal)
    }
}

private struct DesktopPreferencesView: View {
    @ObservedObject private var desktop = PeelDesktopController.shared
    @AppStorage("PeelMaximumReach") private var reach = 0.82
    @AppStorage("PeelReturnStrength") private var strength = 1.0
    @AppStorage("PeelMarkerDelay") private var delay = 0.0
    @State private var corners = Set(UserDefaults.standard.stringArray(forKey: "PeelEnabledCorners")
        ?? [PeelCorner.topRight.rawValue])

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 18) {
                    Image(systemName: "rectangle.portrait.on.rectangle.portrait.angled.fill")
                        .font(.system(size: 38, weight: .light)).foregroundStyle(.white)
                        .frame(width: 80, height: 80)
                        .background(LinearGradient(colors: [.teal, .cyan.opacity(0.7)],
                            startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 22))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Peel Window").font(.system(size: 29, weight: .semibold, design: .rounded))
                        Text("轻轻翻开，看看窗口背后。")
                            .font(.title3).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label(desktop.isEnabled ? "桌面模式已开启" : "桌面模式已关闭",
                        systemImage: desktop.isEnabled ? "circle.fill" : "pause.circle")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(desktop.isEnabled ? Color.teal : Color.secondary)
                        .padding(10).background(.quaternary, in: Capsule())
                }
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: Binding(get: { desktop.isEnabled }, set: desktop.setEnabled)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("桌面持续翻页").font(.headline)
                            Text("开启一次，切换应用后仍可使用。")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.toggleStyle(.switch)
                    Divider()
                    HStack {
                        Label(desktop.hasScreenAccess ? "录屏权限已就绪" : "需要屏幕录制权限",
                            systemImage: desktop.hasScreenAccess ? "checkmark.shield" : "lock")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(desktop.hasScreenAccess ? "重新检查" : "设置权限") {
                            desktop.checkScreenAccess(request: true)
                        }
                    }
                }.padding(20).background(.background, in: RoundedRectangle(cornerRadius: 18))
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 15) {
                        Label("可以从哪些角落翻开", systemImage: "viewfinder").font(.headline)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            cornerToggle(.topLeft, "左上角", "arrow.up.left")
                            cornerToggle(.topRight, "右上角", "arrow.up.right")
                            cornerToggle(.bottomLeft, "左下角", "arrow.down.left")
                            cornerToggle(.bottomRight, "右下角", "arrow.down.right")
                        }
                        Text("至少保留一个角落。翻动方向会随鼠标移动而改变。")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background, in: RoundedRectangle(cornerRadius: 18))
                    VStack(alignment: .leading, spacing: 16) {
                        Label("翻页手感", systemImage: "slider.horizontal.3").font(.headline)
                        sliderTitle("最大翻开范围", "\(Int((reach * 100).rounded()))%")
                        Slider(value: $reach, in: 0.1...1, step: 0.01)
                        sliderTitle("回弹力度", String(format: "%.2f×", strength))
                        Slider(value: $strength, in: 0.25...2, step: 0.05)
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background, in: RoundedRectangle(cornerRadius: 18))
                }
                VStack(alignment: .leading, spacing: 12) {
                    HoverDelayControl(delay: $delay)
                    Text("在角落停留指定时间后准备提示标记；画面准备完成后，按住标记向内拖动，松手恢复。颜色、大小和显示时长可在“提示标记”中调整。")
                        .font(.callout).foregroundStyle(.secondary)
                }.padding(20).background(.background, in: RoundedRectangle(cornerRadius: 18))
                Label("当前支持主显示器内的普通窗口。翻页中显示静态画面，下一次翻页会重新捕获。",
                    systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(28).frame(maxWidth: 1000).frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            desktop.checkScreenAccess()
            corners = Set(UserDefaults.standard.stringArray(forKey: "PeelEnabledCorners") ?? [PeelCorner.topRight.rawValue])
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            desktop.checkScreenAccess()
        }
        .onChange(of: [reach, strength, delay]) { _, _ in desktop.settingsChanged() }
    }

    private func sliderTitle(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.subheadline.weight(.medium))
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(.secondary)
        }
    }

    private func cornerToggle(_ corner: PeelCorner, _ title: String, _ symbol: String) -> some View {
        Toggle(isOn: Binding(get: { corners.contains(corner.rawValue) }, set: { enabled in
            if enabled { corners.insert(corner.rawValue) }
            else if corners.count > 1 { corners.remove(corner.rawValue) }
            UserDefaults.standard.set(Array(corners), forKey: "PeelEnabledCorners")
            desktop.settingsChanged()
        })) { Label(title, systemImage: symbol) }.toggleStyle(.button)
    }
}

private struct PeelDemoRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> PeelDemoView { PeelDemoView(frame: .zero) }
    func updateNSView(_ nsView: PeelDemoView, context: Context) {}
}
