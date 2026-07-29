// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GhostMark",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "GhostMark", targets: ["GhostMark"])
    ],
    targets: [
        .executableTarget(name: "GhostMark"),
        .testTarget(
            name: "GhostMarkTests",
            dependencies: ["GhostMark"]
        )
    ],
    swiftLanguageModes: [.v5]
)
