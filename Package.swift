// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacKbdSwitcher",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KbdCore", targets: ["KbdCore"]),
    ],
    targets: [
        .target(
            name: "KbdCore",
            path: "Sources/Core",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "KbdCoreTests",
            dependencies: ["KbdCore"],
            path: "Tests/KbdCoreTests",
            exclude: ["Fixtures"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
