// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BlinkBar",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "BlinkBar",
            path: "Sources/BlinkReminder"
        )
    ]
)
