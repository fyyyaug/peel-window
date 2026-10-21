import SwiftUI
import PeelOverlay

struct ContentView: View {
    var body: some View {
        PeelDemoRepresentable()
    }
}

private struct PeelDemoRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> PeelDemoView {
        PeelDemoView(frame: .zero)
    }

    func updateNSView(_ nsView: PeelDemoView, context: Context) {}
}

#Preview {
    ContentView()
        .frame(width: 960, height: 640)
}
