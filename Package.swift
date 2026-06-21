// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ScreenTurn",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "ScreenTurnCore",
            targets: ["ScreenTurnCore"]
        ),
        .executable(
            name: "ScreenTurnApp",
            targets: ["ScreenTurnApp"]
        ),
        .executable(
            name: "screenturn",
            targets: ["ScreenTurnCLI"]
        ),
        .executable(
            name: "ScreenTurnSelfTest",
            targets: ["ScreenTurnSelfTest"]
        )
    ],
    targets: [
        .target(
            name: "ScreenTurnCore"
        ),
        .executableTarget(
            name: "ScreenTurnApp",
            dependencies: ["ScreenTurnCore"]
        ),
        .executableTarget(
            name: "ScreenTurnCLI",
            dependencies: ["ScreenTurnCore"]
        ),
        .executableTarget(
            name: "ScreenTurnSelfTest",
            dependencies: ["ScreenTurnCore"]
        )
    ]
)
