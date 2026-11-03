#if canImport(CSkiaBridge)
import AppKit
import CoreGraphics
import Foundation
import Metal
import Testing
@testable import RunningOverlay

/// Phase 1 of the GPU spike: render the Easy Run template through a Metal-backed
/// Skia surface and compare it with the raster bridge used by the CPU spike.
@Suite(.serialized) struct SkiaGPUSpikeTests {
    @Test func easyRunGPUvsCPU() async throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            Issue.record("No Metal device available")
            return
        }

        let layout = try Self.easyRunLayout()
        let activity = SkiaSpikeTests.activity()
        let size = CGSize(width: 1920, height: 1080)
        let cpu = try #require(SkiaEasyRunRenderer(size: size))
        let gpu = try #require(
            SkiaEasyRunRenderer(size: size, device: device, commandQueue: queue)
        )
        let frames = 60

        for i in 0..<5 {
            _ = cpu.render(layout: layout, activity: activity, elapsedTime: Double(i) * 0.5)
            gpu.draw(layout: layout, activity: activity, elapsedTime: Double(i) * 0.5)
            gpu.flush(sync: true)
        }

        let cpuStart = ContinuousClock.now
        var cpuPixels = [UInt8]()
        var cpuRow = 0
        for i in 0..<frames {
            let (ptr, row) = cpu.render(
                layout: layout,
                activity: activity,
                elapsedTime: Double(i) * 0.5
            )
            if i == frames - 1 {
                cpuPixels = Array(UnsafeBufferPointer(start: ptr, count: row * 1080))
                cpuRow = row
            }
        }
        let cpuMs = Self.ms(ContinuousClock.now - cpuStart) / Double(frames)

        let gpuStart = ContinuousClock.now
        for i in 0..<frames {
            gpu.draw(layout: layout, activity: activity, elapsedTime: Double(i) * 0.5)
            gpu.flush(sync: true)
        }
        let gpuMs = Self.ms(ContinuousClock.now - gpuStart) / Double(frames)

        // Throughput when submissions are pipelined and the GPU is waited on once.
        let gpuAsyncStart = ContinuousClock.now
        for i in 0..<frames {
            gpu.draw(layout: layout, activity: activity, elapsedTime: Double(i) * 0.5)
            gpu.flush(sync: false)
        }
        gpu.flush(sync: true)
        let gpuAsyncMs = Self.ms(ContinuousClock.now - gpuAsyncStart) / Double(frames)

        let gpuReadStart = ContinuousClock.now
        var gpuPixels = [UInt8]()
        var gpuRow = 0
        for i in 0..<frames {
            gpu.draw(layout: layout, activity: activity, elapsedTime: Double(i) * 0.5)
            gpu.flush(sync: true)
            let (ptr, row) = try #require(gpu.readPixels())
            if i == frames - 1 {
                gpuPixels = Array(UnsafeBufferPointer(start: ptr, count: row * 1080))
                gpuRow = row
            }
        }
        let gpuReadMs = Self.ms(ContinuousClock.now - gpuReadStart) / Double(frames)

        var changed = 0
        var delta = 0
        var diffBox = CGRect.null
        for y in 0..<1080 {
            for x in 0..<1920 {
                var pixelDelta = 0
                for channel in 0..<4 {
                    pixelDelta += abs(
                        Int(cpuPixels[y * cpuRow + x * 4 + channel])
                            - Int(gpuPixels[y * gpuRow + x * 4 + channel])
                    )
                }
                if pixelDelta > 8 {
                    changed += 1
                    diffBox = diffBox.union(CGRect(x: x, y: y, width: 1, height: 1))
                }
                delta += pixelDelta
            }
        }

        print(
            "GPU-SPIKE cpu=\(Self.fmt(cpuMs))ms/frame "
                + "gpu=\(Self.fmt(gpuMs))ms "
                + "gpu-async=\(Self.fmt(gpuAsyncMs))ms "
                + "gpu+read=\(Self.fmt(gpuReadMs))ms "
                + "changedPixels=\(changed) "
                + "meanDelta=\(Self.fmt(Double(delta) / (1920 * 1080 * 4))) "
                + "diffBox=\(diffBox)"
        )

        let cpuRep = NSBitmapImageRep(cgImage: Self.cgImage(cpuPixels, cpuRow, 1920, 1080))
        if let png = cpuRep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "/tmp/skia-gpu-cpu.png"))
        }
        let gpuRep = NSBitmapImageRep(cgImage: Self.cgImage(gpuPixels, gpuRow, 1920, 1080))
        if let png = gpuRep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "/tmp/skia-gpu-metal.png"))
        }

        #expect(gpuMs > 0)
        #expect(changed < 1920 * 1080)
    }

    @Test func perModuleGPUvsCPU() async throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            Issue.record("No Metal device available")
            return
        }
        let layout = try Self.easyRunLayout()
        let activity = SkiaSpikeTests.activity()
        let size = CGSize(width: 1920, height: 1080)
        let cpu = try #require(SkiaEasyRunRenderer(size: size))
        let gpu = try #require(
            SkiaEasyRunRenderer(size: size, device: device, commandQueue: queue)
        )
        let frames = 30

        for element in layout.elements {
            var single = layout
            single.elements = [element]

            for i in 0..<3 {
                _ = cpu.render(layout: single, activity: activity, elapsedTime: Double(i))
                gpu.draw(layout: single, activity: activity, elapsedTime: Double(i))
                gpu.flush(sync: true)
            }

            let cpuStart = ContinuousClock.now
            for i in 0..<frames {
                _ = cpu.render(
                    layout: single,
                    activity: activity,
                    elapsedTime: Double(i) * 0.5
                )
            }
            let cpuMs = Self.ms(ContinuousClock.now - cpuStart) / Double(frames)

            let gpuStart = ContinuousClock.now
            for i in 0..<frames {
                gpu.draw(layout: single, activity: activity, elapsedTime: Double(i) * 0.5)
                gpu.flush(sync: true)
            }
            let gpuMs = Self.ms(ContinuousClock.now - gpuStart) / Double(frames)

            let gpuAsyncStart = ContinuousClock.now
            for i in 0..<frames {
                gpu.draw(layout: single, activity: activity, elapsedTime: Double(i) * 0.5)
                gpu.flush(sync: false)
            }
            gpu.flush(sync: true)
            let gpuAsyncMs = Self.ms(ContinuousClock.now - gpuAsyncStart) / Double(frames)

            print(
                "GPU-MODULE \(element.type.rawValue) "
                    + "cpu=\(Self.fmt(cpuMs))ms gpu=\(Self.fmt(gpuMs))ms "
                    + "gpu-async=\(Self.fmt(gpuAsyncMs))ms"
            )
        }
    }

    @Test func resolutionScaling() async throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            Issue.record("No Metal device available")
            return
        }
        let layout = try Self.easyRunLayout()
        let activity = SkiaSpikeTests.activity()
        let frames = 30

        for size in [CGSize(width: 1920, height: 1080), CGSize(width: 3840, height: 2160)] {
            let cpu = try #require(SkiaEasyRunRenderer(size: size))
            let gpu = try #require(
                SkiaEasyRunRenderer(size: size, device: device, commandQueue: queue)
            )

            for i in 0..<3 {
                _ = cpu.render(layout: layout, activity: activity, elapsedTime: Double(i))
                gpu.draw(layout: layout, activity: activity, elapsedTime: Double(i))
                gpu.flush(sync: true)
                _ = try await SwiftUIOverlayVideoExporter.renderFrameCGImage(
                    overlayLayout: layout,
                    activity: activity,
                    elapsedTime: Double(i),
                    size: size
                )
            }

            let cpuStart = ContinuousClock.now
            for i in 0..<frames {
                _ = cpu.render(
                    layout: layout,
                    activity: activity,
                    elapsedTime: Double(i) * 0.5
                )
            }
            let cpuMs = Self.ms(ContinuousClock.now - cpuStart) / Double(frames)

            let swiftStart = ContinuousClock.now
            var lastImage: CGImage?
            for i in 0..<frames {
                lastImage = try await SwiftUIOverlayVideoExporter.renderFrameCGImage(
                    overlayLayout: layout,
                    activity: activity,
                    elapsedTime: Double(i) * 0.5,
                    size: size
                )
            }
            let swiftMs = Self.ms(ContinuousClock.now - swiftStart) / Double(frames)
            let imageSize = lastImage.map { "\($0.width)x\($0.height)" } ?? "nil"

            let image = try #require(lastImage)
            let drawStart = ContinuousClock.now
            for _ in 0..<frames {
                _ = try #require(
                    SwiftUIOverlayVideoExporter.rasterizeCanvas(
                        draws: [(image, CGRect(origin: .zero, size: size))],
                        canvasSize: size
                    )
                )
            }
            let drawMs = Self.ms(ContinuousClock.now - drawStart) / Double(frames)

            let gpuStart = ContinuousClock.now
            for i in 0..<frames {
                gpu.draw(layout: layout, activity: activity, elapsedTime: Double(i) * 0.5)
                gpu.flush(sync: false)
            }
            gpu.flush(sync: true)
            let gpuMs = Self.ms(ContinuousClock.now - gpuStart) / Double(frames)

            print(
                "GPU-SCALE \(Int(size.width))x\(Int(size.height)) "
                    + "cpu=\(Self.fmt(cpuMs))ms swiftui=\(Self.fmt(swiftMs))ms "
                    + "swiftui+draw=\(Self.fmt(swiftMs + drawMs))ms "
                    + "image=\(imageSize) gpu-async=\(Self.fmt(gpuMs))ms"
            )
        }
    }

    static func easyRunLayout() throws -> OverlayLayout {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/RunningOverlay/Resources/Templates/EasyRun.rotemplate")
        let template = try JSONDecoder().decode(OverlayTemplate.self, from: Data(contentsOf: url))
        var layout = template.layout
        layout.elements = layout.elements.filter(SkiaEasyRunRenderer.supports)
        // Keep the comparison deterministic and offline, matching the CPU spike.
        for index in layout.elements.indices where layout.elements[index].type == .routeMap {
            layout.elements[index].style.routeMapBackgroundStyle = .none
        }
        return layout
    }

    private static func cgImage(
        _ pixels: [UInt8],
        _ rowBytes: Int,
        _ width: Int,
        _ height: Int
    ) -> CGImage {
        let data = Data(pixels) as CFData
        let provider = CGDataProvider(data: data)!
        return CGImage(
            width: width,
            height: height,
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
        )!
    }

    private static func ms(_ duration: Duration) -> Double {
        Double(duration.components.seconds) * 1000
            + Double(duration.components.attoseconds) / 1e15
    }

    private static func fmt(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}
#endif
