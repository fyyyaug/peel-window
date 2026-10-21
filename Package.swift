// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "PeelWindowKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "PeelCore", targets: ["PeelCore"]),
        .library(name: "PeelInteraction", targets: ["PeelInteraction"]),
        .library(name: "PeelWindowing", targets: ["PeelWindowing"]),
        .library(name: "PeelCapture", targets: ["PeelCapture"]),
        .library(name: "PeelRenderer", targets: ["PeelRenderer"]),
        .library(name: "PeelOverlay", targets: ["PeelOverlay"]),
    ],
    targets: [
        .target(name: "PeelCore"),
        .target(
            name: "PeelInteraction",
            dependencies: ["PeelCore"]
        ),
        .target(
            name: "PeelWindowing",
            dependencies: ["PeelCore"]
        ),
        .target(
            name: "PeelCapture",
            dependencies: ["PeelCore", "PeelWindowing"]
        ),
        .target(
            name: "PeelRenderer",
            dependencies: ["PeelCore"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "PeelOverlay",
            dependencies: [
                "PeelCore",
                "PeelInteraction",
                "PeelRenderer",
                "PeelWindowing",
                "PeelCapture",
            ]
        ),
        .testTarget(
            name: "PeelCoreTests",
            dependencies: ["PeelCore"]
        ),
        .testTarget(
            name: "PeelInteractionTests",
            dependencies: ["PeelCore", "PeelInteraction"]
        ),
        .testTarget(
            name: "PeelRendererTests",
            dependencies: ["PeelCore", "PeelRenderer"]
        ),
    ]
)

