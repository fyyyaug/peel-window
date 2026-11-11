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

struct MarkerSettingsView: View {
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
            Section("Corner Marker") {
                Slider(value: $size, in: 24...140, step: 2) {
                    Text("Size: \(Int(size)) pt")
                }
                Slider(value: $opacity, in: 0.1...1, step: 0.05) {
                    Text("Opacity: \(opacity.formatted(.percent.precision(.fractionLength(0))))")
                }
                ColorPicker("Color", selection: markerColor, supportsOpacity: false)
                HoverDelayControl(delay: $delay)
                Slider(value: $duration, in: 0...30, step: 1) {
                    if duration == 0 {
                        Text("Visible while hovering")
                    } else {
                        Text("Visible for \(Int(duration)) s")
                    }
                }
                Text("The image starts loading as you approach a corner. Set the duration to 0 to keep the marker visible while hovering. If it hides, move away and back to show it again. The marker stays visible while dragging.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 14)
                        .fill(markerColor.wrappedValue.opacity(opacity))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(opacity)))
                        .frame(width: size, height: size)
                    Spacer()
                }.frame(height: 150)
                Button("Restore Defaults") {
                    size = 84; opacity = 0.42; delay = 0; duration = 0
                    red = 0; green = 0.7; blue = 0.72
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 500, idealWidth: 580, minHeight: 560)
        .onChange(of: [size, opacity, delay, duration, red, green, blue]) { _, _ in
            PeelDesktopController.shared.settingsChanged()
        }
    }
}


struct HoverDelayControl: View {
    @Binding var delay: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Hover Activation Time").font(.subheadline.weight(.medium))
                Spacer()
                TextField("s", value: $delay, format: .number.precision(.fractionLength(3)))
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 90)
                    .accessibilityLabel("Hover activation time in seconds")
                Text("s").foregroundStyle(.secondary)
            }
            Slider(value: $delay, in: 0...10, step: 0.001)
            Text("Enter a delay to the nearest millisecond. Set it to 0 to show the marker immediately. If the first image is still loading, keep holding to continue when it’s ready.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onChange(of: delay) { _, value in
            let safe = value.isFinite ? min(max(value, 0), 10) : 0
            if value != safe { delay = safe }
        }
    }
}
