// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HeadRoom",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "HeadRoom",
            path: "Sources/HeadRoom"
        ),
        .testTarget(
            name: "HeadRoomTests",
            dependencies: ["HeadRoom"],
            path: "Tests/HeadRoomTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
