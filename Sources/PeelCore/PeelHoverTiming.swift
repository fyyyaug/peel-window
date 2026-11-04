import Foundation

public enum PeelHoverTiming {
    /// Capture preparation and the hover delay run concurrently.
    public static func remaining(startedAt: TimeInterval, delay: TimeInterval,
                                 now: TimeInterval) -> TimeInterval {
        max(0, startedAt + delay - now)
    }
}
