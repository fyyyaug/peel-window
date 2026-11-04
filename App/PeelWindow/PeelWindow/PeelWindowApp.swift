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
    }
}
