// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Hando",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Hando",
            path: "Sources/Hando"
        ),
        .testTarget(
            name: "HandoTests",
            dependencies: ["Hando"],
            path: "Tests/HandoTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
