// swift-tools-version: 6.0

import Foundation
import PackageDescription

// Optional Skia spike: set SKIA_DIR to an unpacked Skia checkout/prebuilt (include/ and out/Release-arm64/).
let skiaDir = ProcessInfo.processInfo.environment["SKIA_DIR"]

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
    dependencies: [],
    targets: skiaTargets + [
        .executableTarget(
            name: "RunningOverlay",
            dependencies: skiaDir == nil ? [] : ["CSkiaBridge"],
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

var skiaTargets: [Target] {
    guard let skiaDir else { return [] }
    let libs = ["skia", "skshaper", "skunicode_core", "skunicode_icu", "icu", "harfbuzz", "freetype2", "png", "zlib", "expat", "jpeg", "webp"]
    return [
        .target(
            name: "CSkiaBridge",
            path: "Sources/CSkiaBridge",
            cxxSettings: [.unsafeFlags(["-std=c++17", "-I\(skiaDir)"])],
            linkerSettings: libs.map { .unsafeFlags(["\(skiaDir)/out/Release-arm64/lib\($0).a"]) }
                + [.linkedFramework("CoreText"), .linkedFramework("CoreGraphics")]
        )
    ]
}
