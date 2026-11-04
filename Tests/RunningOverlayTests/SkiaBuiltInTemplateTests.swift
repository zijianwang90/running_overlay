#if canImport(CSkiaBridge)
import AppKit
import CoreVideo
import CryptoKit
import Metal
import Testing
@testable import RunningOverlay

/// Authored product presets, not a hand-assembled approximation of their layout.
/// Compare preview's offscreen surface with export's IOSurface host while
/// advancing and scrubbing one complete synthetic interval workout.
@MainActor
@Suite(.serialized, .skiaSerialized)
struct SkiaBuiltInTemplateTests {
    @Test(arguments: ["EasyRun", "IntervalWorkout", "Race"], [1080, 2160])
    func previewAndExportAcrossWorkout(_ name: String, _ height: Int) throws {
        // CPU-only SDK builds still run the oracle tests below. A requested
        // product GPU configuration must fail rather than silently skip Metal.
        guard ProcessInfo.processInfo.environment["SKIA_GPU"] == "1" else { return }
        try OverlayPreferenceFixtures.withDefaults {
            let size = CGSize(width: height * 16 / 9, height: height)
            let layout = try load(name)
            let activity = SkiaFullCompositionGoldenTests.workout()
            #expect(layout.elements.filter(\.isVisible).allSatisfy(SkiaEasyRunRenderer.supports))
            let device = try #require(MTLCreateSystemDefaultDevice())
            let queue = try #require(device.makeCommandQueue())
            let preview = try #require(SkiaEasyRunRenderer(size: size, device: device, commandQueue: queue))
            let snapshots = makeSnapshots(layout: layout, activity: activity, size: size)
            preview.preloadAssets(layout: layout, activity: activity, mapSnapshots: snapshots)
            let exporter = try #require(try OverlayExportRendererFactory.make(
                backend: .skia, size: size, layout: layout, activity: activity, mapSnapshots: snapshots
            ))
            let buffer = try makeBuffer(size)
            let cpu = try #require(SkiaEasyRunRenderer(size: size))
            cpu.preloadAssets(layout: layout, activity: activity, mapSnapshots: snapshots)
            var signatures: [TimeInterval: SHA256.Digest] = [:]
            // Warmup, work, recovery, second work, cooldown, finish, backward
            // scrub, then rewind. Both hosts reuse their contexts and assets.
            for time: TimeInterval in [0, 150, 330, 480, 690, 720, 150, 0] {
                let pixels = try previewPixels(preview, layout: layout, activity: activity, time: time)
                try exporter.render(into: buffer, elapsedTime: time)
                try compare(pixels, to: buffer, label: "\(name)-\(height)p-\(Int(time))")
                if time == 150 && signatures[time] == nil {
                    let (pointer, stride) = try #require(cpu.render(layout: layout, activity: activity, elapsedTime: time))
                    let raster = (0..<height).flatMap { y in
                        Array(UnsafeBufferPointer(start: pointer + y * stride, count: Int(size.width) * 4))
                    }
                    try compare(raster, to: buffer, label: "\(name)-\(height)p-raster", exact: false)
                }
                let signature = SHA256.hash(data: Data(pixels))
                if let previous = signatures[time] {
                    #expect(signature == previous, "Backward scrub must restore the same frame")
                } else {
                    signatures[time] = signature
                }
                try writeReview(pixels, size: size, label: "\(name)-\(height)p-\(Int(time))")
            }
            #expect(Set(signatures.values.map { Data($0) }).count == 6,
                    "All workout samples must advance; stale or empty frames are unacceptable")
        }
    }

    @Test(arguments: ["EasyRun", "IntervalWorkout", "Race"])
    nonisolated func authoredTemplateMatchesSwiftUIOracle(_ name: String) async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            // No map network: the oracle renders the authored route geometry
            // against an empty background. Snapshot upload is covered above.
            var layout = try load(name)
            for index in layout.elements.indices where layout.elements[index].type == .routeMap {
                layout.elements[index].style.routeMapBackgroundStyle = .none
            }
            let metrics = try await SkiaGoldenFrameHarness.compare(
                layout: layout, activity: SkiaFullCompositionGoldenTests.workout(),
                elapsedTime: 150, size: CGSize(width: 1920, height: 1080),
                label: "builtin-\(name)"
            )
            print(metrics.description)
            // Same limits as the existing mixed full-composition golden.
            #expect(metrics.changedRatio < 0.15, "\(metrics)")
            #expect(metrics.meanDelta < 2, "\(metrics)")
        }
    }

    nonisolated private func load(_ name: String) throws -> OverlayLayout {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        return try OverlayTemplateStore().loadTemplateFile(from: root.appendingPathComponent(
            "Sources/RunningOverlay/Resources/Templates/\(name).rotemplate"
        )).layout
    }

    private func makeSnapshots(
        layout: OverlayLayout, activity: ActivityTimeline, size: CGSize
    ) -> [MapSnapshotRequest: NSImage] {
        var snapshots: [MapSnapshotRequest: NSImage] = [:]
        let context = OverlayRenderContext(canvasSize: size, activity: activity, elapsedTime: 150)
        for element in layout.elements where element.type == .routeMap {
            let model = OverlayRenderModel.routeMapLayout(for: element, in: context)
            guard let request = RouteMapSnapshotRequestBuilder.request(for: element, layout: model) else { continue }
            snapshots[request] = NSImage(size: model.rect.size, flipped: false) { rect in
                NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.20, alpha: 1).setFill()
                rect.fill()
                NSColor(calibratedRed: 0.25, green: 0.35, blue: 0.50, alpha: 1).setFill()
                CGRect(x: rect.width * 0.2, y: 0, width: rect.width * 0.05, height: rect.height).fill()
                return true
            }
        }
        return snapshots
    }

    private func makeBuffer(_ size: CGSize) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height),
            kCVPixelFormatType_32BGRA, [
                kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
                kCVPixelBufferMetalCompatibilityKey as String: true
            ] as CFDictionary, &buffer)
        #expect(status == kCVReturnSuccess)
        return try #require(buffer)
    }

    private func previewPixels(
        _ renderer: SkiaEasyRunRenderer, layout: OverlayLayout,
        activity: ActivityTimeline, time: TimeInterval
    ) throws -> [UInt8] {
        renderer.draw(layout: layout, activity: activity, elapsedTime: time)
        #expect(renderer.flush(sync: true))
        let (pointer, rowBytes) = try #require(renderer.readPixels())
        let width = Int(renderer.size.width)
        // Normalize row stride before hashing/comparing the two host surfaces.
        return (0..<Int(renderer.size.height)).flatMap { y in
            Array(UnsafeBufferPointer(start: pointer + y * rowBytes, count: width * 4))
        }
    }

    private func compare(_ reference: [UInt8], to buffer: CVPixelBuffer, label: String, exact: Bool = true) throws {
        #expect(CVPixelBufferLockBaseAddress(buffer, .readOnly) == kCVReturnSuccess)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let actual = try #require(CVPixelBufferGetBaseAddress(buffer)).assumingMemoryBound(to: UInt8.self)
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        var changed = 0
        var totalDelta = 0
        var visible = 0
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                var delta = 0
                for channel in 0..<4 {
                    delta += abs(Int(reference[offset + channel]) - Int(actual[y * rowBytes + x * 4 + channel]))
                }
                if delta > 8 { changed += 1 }
                totalDelta += delta
                if reference[offset + 3] > 8 { visible += 1 }
            }
        }
        let ratio = Double(changed) / Double(width * height)
        let mean = Double(totalDelta) / Double(width * height * 4)
        print("BUILTIN-HOST-PARITY \(label) changed=\(ratio) meanDelta=\(mean) visible=\(visible)")
        #expect(visible > 1000, "\(label) must contain visible overlays")
        if exact { #expect(totalDelta == 0, "\(label) preview/export pixels must match exactly") }
        #expect(ratio <= 0.02, "\(label): \(ratio)")
        #expect(mean <= 0.5, "\(label): \(mean)")
    }

    private func writeReview(_ pixels: [UInt8], size: CGSize, label: String) throws {
        guard let path = ProcessInfo.processInfo.environment["RUNNING_OVERLAY_TEMPLATE_REVIEW_DIR"] else { return }
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
        let image = try #require(CGImage(width: Int(size.width), height: Int(size.height),
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: Int(size.width) * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
                .union(.byteOrder32Little), provider: provider, decode: nil,
            shouldInterpolate: false, intent: .defaultIntent))
        let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try png.write(to: directory.appendingPathComponent("\(label).png"))
    }
}
#endif
