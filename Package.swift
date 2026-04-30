// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RunningOverlay",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "RunningOverlay",
            targets: ["RunningOverlay"]
        )
    ],
    targets: [
        .executableTarget(
            name: "RunningOverlay",
            path: "Sources/RunningOverlay",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "RunningOverlayTests",
            dependencies: ["RunningOverlay"],
            path: "Tests/RunningOverlayTests",
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
