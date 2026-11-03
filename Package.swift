// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchStash",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "NotchStashCore"),
        .executableTarget(name: "NotchStash", dependencies: ["NotchStashCore"]),
        .testTarget(name: "NotchStashCoreTests", dependencies: ["NotchStashCore"]),
    ]
)
