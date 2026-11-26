// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GridApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "GridApp", targets: ["GridApp"])
    ],
    targets: [
        .executableTarget(
            name: "GridApp",
            path: "Sources/GridApp"
        )
    ]
)
