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
    dependencies: [
        .package(url: "https://github.com/airbnb/lottie-ios.git", from: "4.5.0")
    ],
    targets: [
        .executableTarget(
            name: "RunningOverlay",
            dependencies: [
                .product(name: "Lottie", package: "lottie-ios")
            ],
            path: "Sources/RunningOverlay",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "RunningOverlayTests",
            dependencies: [
                "RunningOverlay",
                .product(name: "Lottie", package: "lottie-ios")
            ],
            path: "Tests/RunningOverlayTests",
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
