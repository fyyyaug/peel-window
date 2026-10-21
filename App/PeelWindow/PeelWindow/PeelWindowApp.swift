import SwiftUI

@main
struct PeelWindowApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 820, minHeight: 560)
        }
        .defaultSize(width: 960, height: 640)
    }
}
