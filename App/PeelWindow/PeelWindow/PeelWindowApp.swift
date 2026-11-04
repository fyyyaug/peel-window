import SwiftUI
import PeelOverlay

@main
struct PeelWindowApp: App {
    @StateObject private var desktop = PeelDesktopController.shared
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 820, minHeight: 560)
        }
        .defaultSize(width: 960, height: 640)
        .commands {
            CommandGroup(after: .appSettings) {
                Toggle("Enable Desktop Peeling", isOn: Binding(
                    get: { desktop.isEnabled },
                    set: { desktop.setEnabled($0) }
                ))
            }
        }
        Settings {
            MarkerSettingsView()
        }
    }
}

private struct MarkerSettingsView: View {
    @AppStorage("PeelMarkerSize") private var size = 84.0
    @AppStorage("PeelMarkerDelay") private var delay = 0.0
    @AppStorage("PeelMarkerDuration") private var duration = 0.0
    @AppStorage("PeelMarkerOpacity") private var opacity = 0.42
    @AppStorage("PeelMarkerRed") private var red = 0.0
    @AppStorage("PeelMarkerGreen") private var green = 0.7
    @AppStorage("PeelMarkerBlue") private var blue = 0.72

    private var markerColor: Binding<Color> {
        Binding(get: { Color(red: red, green: green, blue: blue) }, set: { color in
            guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return }
            red = rgb.redComponent
            green = rgb.greenComponent
            blue = rgb.blueComponent
        })
    }

    var body: some View {
        Form {
            Section("角落提示标记") {
                Slider(value: $size, in: 24...140, step: 2) {
                    Text("大小：\(Int(size)) 点")
                }
                Slider(value: $opacity, in: 0.1...1, step: 0.05) {
                    Text("不透明度：\(Int((opacity * 100).rounded()))%")
                }
                ColorPicker("颜色", selection: markerColor, supportsOpacity: false)
                Slider(value: $delay, in: 0...3, step: 0.1) {
                    Text("出现延迟：\(delay, specifier: "%.1f") 秒")
                }
                Slider(value: $duration, in: 0...30, step: 1) {
                    Text(duration == 0 ? "显示时长：停留期间一直显示" : "显示时长：\(Int(duration)) 秒")
                }
                Text("鼠标停留在窗口角落后开始准备标记，截图准备可能增加少量等待时间。显示时长设为 0 时持续显示；自动隐藏后，移开鼠标再靠近即可重新显示。拖动期间不会自动隐藏。")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 14)
                        .fill(markerColor.wrappedValue.opacity(opacity))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(opacity)))
                        .frame(width: size, height: size)
                    Spacer()
                }.frame(height: 150)
                Button("恢复默认设置") {
                    size = 84; opacity = 0.42; delay = 0; duration = 0
                    red = 0; green = 0.7; blue = 0.72
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .onChange(of: [size, opacity, delay, duration, red, green, blue]) { _, _ in
            PeelDesktopController.shared.settingsChanged()
        }
    }
}
