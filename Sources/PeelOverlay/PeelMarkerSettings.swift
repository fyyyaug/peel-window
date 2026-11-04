import AppKit

struct PeelMarkerSettings {
    let size: CGFloat
    let delay: TimeInterval
    let duration: TimeInterval
    let opacity: CGFloat
    let color: NSColor

    init(defaults: UserDefaults = .standard) {
        func value(_ key: String, _ fallback: Double, _ range: ClosedRange<Double>) -> Double {
            let saved = defaults.object(forKey: key) as? Double ?? fallback
            return saved.isFinite ? min(max(saved, range.lowerBound), range.upperBound) : fallback
        }
        size = value("PeelMarkerSize", 84, 24...140)
        delay = value("PeelMarkerDelay", 0, 0...3)
        duration = value("PeelMarkerDuration", 0, 0...30)
        opacity = value("PeelMarkerOpacity", 0.42, 0.1...1)
        color = NSColor(srgbRed: value("PeelMarkerRed", 0, 0...1),
            green: value("PeelMarkerGreen", 0.7, 0...1),
            blue: value("PeelMarkerBlue", 0.72, 0...1), alpha: 1)
    }
}
