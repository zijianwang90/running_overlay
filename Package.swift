// swift-tools-version: 6.0

import Foundation
import PackageDescription

// Optional Skia spike: set SKIA_DIR to an unpacked Skia checkout/prebuilt.
// CPU builds use static archives under out/Release-arm64/.
// GPU builds (SKIA_GPU=1) use the shared library under lib/.
let skiaDir = ProcessInfo.processInfo.environment["SKIA_DIR"]
let skiaGPU = ProcessInfo.processInfo.environment["SKIA_GPU"] == "1"
// Experimental dual-backend package built by scripts/build-skia-experimental.py.
let skiaGraphite = ProcessInfo.processInfo.environment["SKIA_GRAPHITE"] == "1"

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
    let linkerSettings: [LinkerSetting]
    if skiaGPU {
        linkerSettings = [
            .unsafeFlags([
                "-L\(skiaDir)/lib", "-lskia",
                "-Xlinker", "-rpath", "-Xlinker", "\(skiaDir)/lib"
            ]),
            .linkedFramework("Metal"),
            .linkedFramework("QuartzCore"),
            .linkedFramework("CoreText"),
            .linkedFramework("CoreGraphics"),
            .linkedFramework("AppKit")
        ]
    } else {
        let libs = ["skia", "skshaper", "skunicode_core", "skunicode_icu", "icu", "harfbuzz", "freetype2", "png", "zlib", "expat", "jpeg", "webp"]
        linkerSettings = libs.map { .unsafeFlags(["\(skiaDir)/out/Release-arm64/lib\($0).a"]) }
            + [.linkedFramework("CoreText"), .linkedFramework("CoreGraphics")]
    }
    return [
        .target(
            name: "CSkiaBridge",
            path: "Sources/CSkiaBridge",
            cxxSettings: [.unsafeFlags(["-std=c++20", "-I\(skiaDir)"])]
                + (skiaGraphite ? [.define("SKB_ENABLE_GRAPHITE")] : []),
            linkerSettings: linkerSettings
        )
    ]
}
