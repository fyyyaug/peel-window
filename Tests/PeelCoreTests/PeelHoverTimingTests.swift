import Testing
@testable import PeelCore

@Test("A short hover delay includes time already spent preparing the screenshot")
func concurrentHoverPreparation() {
    let remaining = PeelHoverTiming.remaining(startedAt: 10, delay: 0.1, now: 10.09)
    #expect(abs(remaining - 0.01) < 0.000001)
    #expect(PeelHoverTiming.remaining(startedAt: 10, delay: 0.1, now: 10.2) == 0)
}

@Test("Millisecond hover settings retain their precision")
func millisecondDelay() {
    #expect(abs(PeelHoverTiming.remaining(startedAt: 10, delay: 0.001, now: 10) - 0.001) < 0.000001)
    #expect(PeelHoverTiming.remaining(startedAt: 10, delay: 0, now: 10) == 0)
}
