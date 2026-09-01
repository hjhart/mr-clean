// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MrClean",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "MrCleanCore", path: "Sources/MrCleanCore"),
        .executableTarget(
            name: "MrClean",
            dependencies: ["MrCleanCore"],
            path: "Sources/MrClean"
        ),
        .testTarget(
            name: "MrCleanCoreTests",
            dependencies: ["MrCleanCore"],
            path: "Tests/MrCleanCoreTests"
        ),
    ]
)
