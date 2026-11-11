import SwiftUI
import PeelOverlay
import PeelCore

struct ContentView: View {
    var body: some View {
        TabView {
            DesktopPreferencesView()
                .tabItem { Label("Desktop", systemImage: "macwindow.on.rectangle") }
            MarkerSettingsView()
                .tabItem { Label("Corner Marker", systemImage: "cursorarrow.rays") }
            PeelDemoRepresentable()
                .tabItem { Label("Peel Preview", systemImage: "play.rectangle") }
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
                        Text("Peel a window to see what’s behind it.")
                            .font(.title3).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label(desktop.isEnabled ? String(localized: "Desktop Mode On") : String(localized: "Desktop Mode Off"),
                        systemImage: desktop.isEnabled ? "circle.fill" : "pause.circle")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(desktop.isEnabled ? Color.teal : Color.secondary)
                        .padding(10).background(.quaternary, in: Capsule())
                }
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: Binding(get: { desktop.isEnabled }, set: desktop.setEnabled)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Continuous Desktop Peeling").font(.headline)
                            Text("Stays enabled when you switch apps.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.toggleStyle(.switch)
                    Divider()
                    HStack {
                        Label(desktop.hasScreenAccess ? String(localized: "Screen Recording Ready") : String(localized: "Screen Recording Permission Required"),
                            systemImage: desktop.hasScreenAccess ? "checkmark.shield" : "lock")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(desktop.hasScreenAccess ? String(localized: "Check Again") : String(localized: "Set Up Permission")) {
                            desktop.checkScreenAccess(request: true)
                        }
                    }
                }.padding(20).background(.background, in: RoundedRectangle(cornerRadius: 18))
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 15) {
                        Label("Enabled Corners", systemImage: "viewfinder").font(.headline)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            cornerToggle(.topLeft, "Top Left", "arrow.up.left")
                            cornerToggle(.topRight, "Top Right", "arrow.up.right")
                            cornerToggle(.bottomLeft, "Bottom Left", "arrow.down.left")
                            cornerToggle(.bottomRight, "Bottom Right", "arrow.down.right")
                        }
                        Text("Keep at least one corner enabled. Pointer movement steers the fold.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background, in: RoundedRectangle(cornerRadius: 18))
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Peel Behavior", systemImage: "slider.horizontal.3").font(.headline)
                        sliderTitle("Maximum Peel Size", reach.formatted(.percent.precision(.fractionLength(0))))
                        Slider(value: $reach, in: 0.1...1, step: 0.01)
                        sliderTitle("Return Strength", strength.formatted(.number.precision(.fractionLength(2))) + "×")
                        Slider(value: $strength, in: 0.25...2, step: 0.05)
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background, in: RoundedRectangle(cornerRadius: 18))
                }
                VStack(alignment: .leading, spacing: 12) {
                    HoverDelayControl(delay: $delay)
                    Text("Hover over a corner to show its marker. Drag the marker inward and release to restore the window. If the first image is still loading, keep holding to continue as soon as it’s ready. Adjust color, size, and duration in Corner Marker.")
                        .font(.callout).foregroundStyle(.secondary)
                }.padding(20).background(.background, in: RoundedRectangle(cornerRadius: 18))
                Label("Supports standard windows fully on the main display. Each peel uses a fresh still image.",
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

    private func sliderTitle(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(title).font(.subheadline.weight(.medium))
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(.secondary)
        }
    }

    private func cornerToggle(_ corner: PeelCorner, _ title: LocalizedStringKey, _ symbol: String) -> some View {
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
