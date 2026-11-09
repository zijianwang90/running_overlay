#if canImport(CSkiaBridge)
import AppKit
import CoreGraphics
import Foundation
import Metal
import Testing
@testable import RunningOverlay

/// Validates the real preview/export chart path: the same chart element is
/// drawn by `SkiaEasyRunRenderer` over an offscreen Metal surface and over the
/// raster bridge, then compared. Skips when Metal or a GPU Skia context is
/// unavailable.
///
/// `SkiaChartsGoldenTests` covers SwiftUI parity on the CPU raster context.
/// These tests only exercise GPU-vs-CPU differences in the production host:
/// gradient shaders, blur/opacity layers, image upload, and glyph rasterizing.
@Suite(.serialized, .skiaSerialized)
struct SkiaChartsGPUParityTests {
    private static let canvas = CGSize(width: 1280, height: 720)
    private static let elapsedTime: TimeInterval = 300
    private static let activity = SkiaChartsGoldenTests.activity(duration: 600)

    @Test func distanceTimelineGPUParity() throws {
        var layout = try easyRunLayout()
        layout.elements = layout.elements
            .filter { $0.type == .distanceTimeline }
            .map { element in
                var copy = element
                copy.position = CGPoint(x: 0.4737, y: 0.3071)
                return copy
            }
        #expect(!layout.elements.isEmpty)
        try compare(
            label: "distance-timeline",
            layout: layout,
            elapsedTime: Self.elapsedTime
        )
    }

    @Test func elevationGradientGPUParity() throws {
        try compare(
            label: "elevation-gradient-area",
            layout: OverlayLayout(elements: [elevationElement(.gradientArea)]),
            elapsedTime: Self.elapsedTime
        )
    }

    @Test func elevationTechGlowGPUParity() throws {
        try compare(
            label: "elevation-tech-glow",
            layout: OverlayLayout(elements: [elevationElement(.techGlow)]),
            elapsedTime: Self.elapsedTime
        )
    }

    // MARK: - Comparison

    private func compare(
        label: String,
        layout: OverlayLayout,
        elapsedTime: TimeInterval
    ) throws {
        let size = Self.canvas
        let activity = Self.activity

        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            print("CHART-GPU-PARITY \(label) skipped: no Metal device")
            return
        }
        guard let gpu = SkiaEasyRunRenderer(
            size: size,
            device: device,
            commandQueue: queue
        ) else {
            print("CHART-GPU-PARITY \(label) skipped: no GPU Skia context")
            return
        }
        let cpu = try #require(SkiaEasyRunRenderer(size: size))

        cpu.preloadAssets(layout: layout, activity: activity)
        gpu.preloadAssets(layout: layout, activity: activity)

        let (cpuPointer, cpuRowBytes) = try #require(cpu.render(
            layout: layout,
            activity: activity,
            elapsedTime: elapsedTime
        ))
        let cpuPixels = Array(
            UnsafeBufferPointer(
                start: cpuPointer,
                count: cpuRowBytes * Int(size.height)
            )
        )

        gpu.draw(layout: layout, activity: activity, elapsedTime: elapsedTime)
        gpu.flush(sync: true)
        let (gpuPointer, gpuRowBytes) = try #require(
            gpu.readPixels(),
            "GPU Skia readback failed"
        )
        let gpuPixels = Array(
            UnsafeBufferPointer(
                start: gpuPointer,
                count: gpuRowBytes * Int(size.height)
            )
        )

        let width = Int(size.width)
        let height = Int(size.height)
        var changed = 0
        var maxDelta = 0
        var maxDeltaAt = "none"
        var totalDelta = 0
        var diffBox = CGRect.null
        for y in 0..<height {
            for x in 0..<width {
                var pixelDelta = 0
                for channel in 0..<4 {
                    let delta = abs(
                        Int(cpuPixels[y * cpuRowBytes + x * 4 + channel])
                            - Int(gpuPixels[y * gpuRowBytes + x * 4 + channel])
                    )
                    pixelDelta += delta
                    if delta > maxDelta {
                        maxDelta = delta
                        maxDeltaAt = "(\(x),\(y),c\(channel))"
                    }
                }
                if pixelDelta > 8 {
                    changed += 1
                    diffBox = diffBox.union(
                        CGRect(x: x, y: y, width: 1, height: 1)
                    )
                }
                totalDelta += pixelDelta
            }
        }
        let meanDelta = Double(totalDelta) / Double(width * height * 4)
        let changedRatio = Double(changed) / Double(width * height)

        print(
            "CHART-GPU-PARITY \(label) changed=\(changed)/\(width * height) "
                + "(\(String(format: "%.3f", changedRatio * 100))%) "
                + "meanDelta=\(String(format: "%.4f", meanDelta)) "
                + "maxDelta=\(maxDelta) at=\(maxDeltaAt) "
                + "diffBox=\(changed > 0 ? "\(diffBox)" : "none")"
        )

        // The GPU host must draw the same frame; only AA and shader rounding
        // may differ by a channel step or two.
        #expect(changedRatio <= 0.02, "\(label) changed \(changedRatio)")
        #expect(meanDelta <= 0.5, "\(label) mean \(meanDelta)")

        if changed > 0 {
            try? writePNG(pixels: cpuPixels, rowBytes: cpuRowBytes, label: "\(label)-cpu")
            try? writePNG(pixels: gpuPixels, rowBytes: gpuRowBytes, label: "\(label)-gpu")
        }
    }

    // MARK: - Fixtures

    private func easyRunLayout() throws -> OverlayLayout {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(
                "Sources/RunningOverlay/Resources/Templates/EasyRun.rotemplate"
            )
        let template = try JSONDecoder().decode(
            OverlayTemplate.self,
            from: Data(contentsOf: url)
        )
        return template.layout
    }

    private func elevationElement(
        _ preset: ElevationChartPreset
    ) -> OverlayElement {
        var style = OverlayStyle.default
        var elevation = ElevationChartStyle.preset(preset)
        elevation.bigNumberFontName = "Helvetica Neue"
        elevation.statsBar.valueFontName = "Helvetica Neue"
        elevation.statsBar.labelFontName = "Helvetica Neue"
        style.elevationChart = elevation
        style.fontName = "Helvetica Neue"
        return OverlayElement(
            type: .elevationChart,
            position: CGPoint(x: 0.5333, y: 0.4417),
            scale: 1,
            style: style
        )
    }

    private func writePNG(
        pixels: [UInt8],
        rowBytes: Int,
        label: String
    ) throws {
        let data = Data(pixels) as CFData
        let provider = try #require(CGDataProvider(data: data))
        let image = try #require(CGImage(
            width: Int(Self.canvas.width),
            height: Int(Self.canvas.height),
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: rowBytes,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(
                rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue
            ),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))
        let rep = NSBitmapImageRep(cgImage: image)
        let png = try #require(rep.representation(using: .png, properties: [:]))
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("skia-charts-gpu", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try png.write(to: directory.appendingPathComponent("\(label).png"))
    }
}
#endif
