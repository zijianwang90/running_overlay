#if canImport(CSkiaBridge)
import AppKit
import CoreGraphics
import Foundation
import Metal
import Testing
@testable import RunningOverlay

/// GPU-path parity for the text and decor modules.
///
/// `SkiaTextGoldenTests` compares `SkiaTextModule` against the SwiftUI oracle
/// on a CPU raster context. Preview and export instead draw through
/// `SkiaEasyRunRenderer`, which may be Metal-backed. These tests render the
/// same production elements through both hosts and compare the resulting
/// pixels, so GPU-only differences (glyph masks, image upload, layer
/// compositing) are visible.
///
/// Metal is optional: the suite is disabled when no device exists, and the
/// test returns without failing when the bridge was built without GPU support.
///
/// The export-frame opacity divergence is unchanged and intentionally not
/// worked around here; see
/// `docs/superpowers/plans/notes/2026-11-02-skia-text-inventory.md`.
@Suite(.serialized) struct SkiaTextGPUParityTests {
    private struct MetalHandles {
        let device: MTLDevice
        let commandQueue: MTLCommandQueue
    }

    /// `nil` on machines without Metal, which marks the suite skipped.
    private static let metal: MetalHandles? = {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue()
        else {
            return nil
        }
        return MetalHandles(device: device, commandQueue: commandQueue)
    }()

    @Test(.enabled(if: SkiaTextGPUParityTests.metal != nil))
    func minimalTextMatchesGPU() throws {
        var style = SkiaTextFixtureFactory.style()
        style.iconEnabled = true
        style.iconSystemName = "heart.fill"
        // The default minimal element exercises glyphs, the rounded
        // background, label/unit runs, and the icon's BGRA upload.
        // Fractional anchors exercise subpixel glyph and shape coverage, where
        // Ganesh and the raster backend are most likely to differ.
        let element = SkiaTextFixtureFactory.element(
            position: CGPoint(x: 0.2137, y: 0.3071),
            style: style
        )
        try compareGPU(
            element: element,
            label: "minimal-text",
            maxChangedRatio: 0.02,
            maxMeanDelta: 1
        )
    }

    @Test(.enabled(if: SkiaTextGPUParityTests.metal != nil))
    func decorIconMatchesGPU() throws {
        let base = SkiaTextFixtureFactory.iconElement()
        let element = OverlayElement(
            type: base.type,
            position: CGPoint(x: 0.5031, y: 0.4969),
            scale: base.scale,
            style: base.style
        )
        try compareGPU(
            element: element,
            label: "decor-icon",
            maxChangedRatio: 0.02,
            maxMeanDelta: 1
        )
    }

    // MARK: - Rendering

    private struct PixelBuffer {
        var bytes: [UInt8]
        var rowBytes: Int
    }

    private struct ParityMetrics: CustomStringConvertible {
        var label: String
        var changedPixels: Int
        var totalPixels: Int
        var meanDelta: Double
        var maxDelta: Int

        var changedRatio: Double {
            totalPixels > 0 ? Double(changedPixels) / Double(totalPixels) : 0
        }

        var description: String {
            "SKIA-GPU-PARITY \(label) "
                + "changed=\(changedPixels)/\(totalPixels) "
                + "(\(String(format: "%.3f", changedRatio * 100))%) "
                + "meanDelta=\(String(format: "%.4f", meanDelta)) "
                + "maxDelta=\(maxDelta)"
        }
    }

    private func compareGPU(
        element: OverlayElement,
        label: String,
        maxChangedRatio: Double,
        maxMeanDelta: Double
    ) throws {
        let size = SkiaTextFixtureFactory.canvasSize
        let activity = SkiaTextFixtureFactory.activity()
        let layout = OverlayLayout(elements: [element])
        let elapsedTime = SkiaTextFixtureFactory.elapsedTime

        let cpu = try #require(SkiaEasyRunRenderer(size: size))
        let cpuPixels = {
            let (pointer, rowBytes) = cpu.render(
                layout: layout,
                activity: activity,
                elapsedTime: elapsedTime
            )
            return PixelBuffer(
                bytes: Array(
                    UnsafeBufferPointer(
                        start: pointer,
                        count: rowBytes * Int(size.height)
                    )
                ),
                rowBytes: rowBytes
            )
        }()

        // A Metal device can still exist when the bridge was compiled without
        // GPU support; treat that as an unavailable environment, not a defect.
        guard let handles = Self.metal,
              let gpu = SkiaEasyRunRenderer(
                  size: size,
                  device: handles.device,
                  commandQueue: handles.commandQueue
              )
        else {
            print("SKIA-GPU-PARITY \(label) skipped: no GPU Skia context")
            return
        }

        gpu.draw(layout: layout, activity: activity, elapsedTime: elapsedTime)
        gpu.flush(sync: true)
        let (gpuPointer, gpuRowBytes) = try #require(
            gpu.readPixels(),
            "GPU Skia readback failed"
        )
        let gpuPixels = PixelBuffer(
            bytes: Array(
                UnsafeBufferPointer(
                    start: gpuPointer,
                    count: gpuRowBytes * Int(size.height)
                )
            ),
            rowBytes: gpuRowBytes
        )

        let metrics = Self.compare(
            reference: cpuPixels,
            candidate: gpuPixels,
            width: Int(size.width),
            height: Int(size.height),
            label: label
        )
        print(metrics.description)
        try Self.writePNGs(
            reference: cpuPixels,
            candidate: gpuPixels,
            width: Int(size.width),
            height: Int(size.height),
            label: label
        )
        #expect(metrics.changedRatio < maxChangedRatio)
        #expect(metrics.meanDelta < maxMeanDelta)
    }

    private static func compare(
        reference: PixelBuffer,
        candidate: PixelBuffer,
        width: Int,
        height: Int,
        label: String,
        threshold: Int = 8
    ) -> ParityMetrics {
        var changed = 0
        var maxDelta = 0
        var totalDelta = 0
        for y in 0..<height {
            for x in 0..<width {
                let index = y * 4
                var pixelDelta = 0
                for channel in 0..<4 {
                    pixelDelta += abs(
                        Int(reference.bytes[index + x * 4 + channel])
                            - Int(candidate.bytes[index + x * 4 + channel])
                    )
                }
                if pixelDelta > threshold {
                    changed += 1
                }
                maxDelta = max(maxDelta, pixelDelta)
                totalDelta += pixelDelta
            }
        }
        return ParityMetrics(
            label: label,
            changedPixels: changed,
            totalPixels: width * height,
            meanDelta: Double(totalDelta) / Double(width * height * 4),
            maxDelta: maxDelta
        )
    }

    private static func writePNGs(
        reference: PixelBuffer,
        candidate: PixelBuffer,
        width: Int,
        height: Int,
        label: String
    ) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("skia-text-gpu-parity", isDirectory: true)
            .appendingPathComponent(label, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        for (name, pixels) in [("cpu", reference), ("gpu", candidate)] {
            guard let image = cgImage(pixels, width: width, height: height) else {
                continue
            }
            let representation = NSBitmapImageRep(cgImage: image)
            guard let png = representation.representation(
                using: .png,
                properties: [:]
            ) else {
                continue
            }
            try png.write(to: directory.appendingPathComponent("\(name).png"))
        }
    }

    private static func cgImage(
        _ pixels: PixelBuffer,
        width: Int,
        height: Int
    ) -> CGImage? {
        let data = Data(pixels.bytes) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: pixels.rowBytes,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(
                rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue
            ),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
#endif
