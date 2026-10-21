# Tests

Package tests will mirror the production modules, beginning with deterministic
interaction and geometry tests in `PeelCoreTests` and `PeelInteractionTests`.

The current Apple Command Line Tools installation does not include either the
Swift Testing or XCTest runtime, so test targets are intentionally deferred
until full Xcode is available. Production module compilation is still validated
with `swift build`.

