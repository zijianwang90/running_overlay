#if canImport(CSkiaBridge)
import AVFoundation
import AppKit
import CoreVideo
import Foundation
import Metal
import Testing
@testable import RunningOverlay

/// Phase 2 of the GPU spike: render directly into the export pixel buffer's
/// IOSurface and append it to an AVAssetWriter, with no CPU readback or
/// per-overlay compositing.
@Suite(.serialized) struct SkiaGPUExportBenchmarkTests {
    @Test(arguments: ProjectExportCodec.allCases)
    func exportEasyRunZeroCopy(codec: ProjectExportCodec) async throws {
        try await Self.runExport(
            codec: codec,
            size: CGSize(width: 1920, height: 1080)
        )
    }

    @Test func exportEasyRunZeroCopy4KProRes() async throws {
        try await Self.runExport(
            codec: .proRes4444,
            size: CGSize(width: 3840, height: 2160)
        )
    }

    private static func runExport(
        codec: ProjectExportCodec,
        size: CGSize
    ) async throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            Issue.record("No Metal device available")
            return
        }

        let layout = try SkiaGPUSpikeTests.easyRunLayout()
        let activity = try Self.syntheticActivity()
        let width = Int(size.width)
        let height = Int(size.height)
        let frameRate: Int32 = 30
        let layerDataFPS = 5
        let framesPerSample = Int(frameRate) / layerDataFPS
        let segmentCount = 10
        let segmentDuration = 5
        let framesPerSegment = segmentDuration * Int(frameRate)

        let sizeLabel = "\(width)x\(height)"
        let outputDirectory = URL(
            fileURLWithPath: "/tmp/skia-gpu-export-\(codec.rawValue)-\(sizeLabel)"
        )
        try? FileManager.default.removeItem(at: outputDirectory)
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        // Two contexts on separate command queues let the next sample render
        // while the previous sample's GPU work finishes.
        var renderers: [SkiaEasyRunRenderer] = []
        for renderQueue in [queue, try #require(device.makeCommandQueue())] {
            renderers.append(
                try #require(
                    SkiaEasyRunRenderer(
                        size: size,
                        device: device,
                        commandQueue: renderQueue,
                        offscreen: false
                    )
                )
            )
        }

        var renderDuration: Double = 0
        var gpuWaitDuration: Double = 0
        var wrapDuration: Double = 0
        var appendDuration: Double = 0
        var writerWaitDuration: Double = 0
        var uniqueRenderCount = 0
        let totalStart = ContinuousClock.now

        for segmentIndex in 0..<segmentCount {
            let outputURL = outputDirectory.appendingPathComponent(
                String(format: "gpu_clip_%02d.mov", segmentIndex + 1)
            )
            let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
            let input = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: SwiftUIOverlayVideoExporter.outputSettings(
                    codec: codec,
                    width: width,
                    height: height,
                    bitrateMbps: 100
                )
            )
            input.expectsMediaDataInRealTime = false
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: Self.pixelBufferAttributes(
                    width: width,
                    height: height
                )
            )
            guard writer.canAdd(input) else {
                Issue.record("Writer rejected the video input")
                return
            }
            writer.add(input)
            guard writer.startWriting() else {
                Issue.record("Writer failed to start: \(writer.error?.localizedDescription ?? "unknown")")
                return
            }
            writer.startSession(atSourceTime: .zero)
            guard let pool = adaptor.pixelBufferPool else {
                Issue.record("Adaptor did not create a pixel buffer pool")
                return
            }

            struct PendingFrame {
                let pixelBuffer: CVPixelBuffer
                let texture: MTLTexture
                let rendererIndex: Int
                let sampleIndex: Int
            }

            func appendFrames(
                _ pixelBuffer: CVPixelBuffer,
                sampleIndex: Int
            ) async throws -> Bool {
                for repeatIndex in 0..<framesPerSample {
                    while !input.isReadyForMoreMediaData {
                        let waitStart = ContinuousClock.now
                        try await Task.sleep(nanoseconds: 100_000)
                        writerWaitDuration += Self.seconds(ContinuousClock.now - waitStart)
                    }
                    let appendStart = ContinuousClock.now
                    let frameIndex = sampleIndex * framesPerSample + repeatIndex
                    let presentationTime = CMTime(
                        value: CMTimeValue(frameIndex),
                        timescale: CMTimeScale(frameRate)
                    )
                    guard adaptor.append(
                        pixelBuffer,
                        withPresentationTime: presentationTime
                    ) else {
                        Issue.record(
                            "Append failed: \(writer.error?.localizedDescription ?? "unknown")"
                        )
                        return false
                    }
                    appendDuration += Self.seconds(ContinuousClock.now - appendStart)
                }
                return true
            }

            var pending: [PendingFrame] = []
            let samplesPerSegment = segmentDuration * layerDataFPS

            for sampleIndex in 0..<samplesPerSegment {
                let rendererIndex = sampleIndex % renderers.count
                let renderer = renderers[rendererIndex]

                var pixelBuffer: CVPixelBuffer?
                guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
                    == kCVReturnSuccess,
                      let pixelBuffer else {
                    Issue.record("Could not create a pixel buffer")
                    return
                }

                let wrapStart = ContinuousClock.now
                guard let ioSurface = CVPixelBufferGetIOSurface(pixelBuffer)?
                    .takeUnretainedValue() else {
                    Issue.record("Pixel buffer is not IOSurface-backed")
                    return
                }
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: .bgra8Unorm,
                    width: width,
                    height: height,
                    mipmapped: false
                )
                descriptor.usage = [.renderTarget, .shaderRead]
                descriptor.storageMode = .shared
                guard let texture = device.makeTexture(
                    descriptor: descriptor,
                    iosurface: ioSurface,
                    plane: 0
                ) else {
                    Issue.record("Could not create an MTLTexture from the IOSurface")
                    return
                }
                guard renderer.wrap(texture: texture) else {
                    Issue.record("Skia rejected the wrapped texture")
                    return
                }
                wrapDuration += Self.seconds(ContinuousClock.now - wrapStart)

                let renderStart = ContinuousClock.now
                let elapsedTime = Double(segmentIndex * segmentDuration)
                    + Double(sampleIndex) / Double(layerDataFPS)
                renderer.draw(
                    layout: layout,
                    activity: activity,
                    elapsedTime: elapsedTime
                )
                renderer.flush(sync: false)
                renderDuration += Self.seconds(ContinuousClock.now - renderStart)
                uniqueRenderCount += 1

                if segmentIndex == 0, sampleIndex == 0 {
                    renderer.flush(sync: true)
                    Self.writePNG(
                        pixelBuffer,
                        width: width,
                        height: height,
                        to: "/tmp/skia-gpu-export-\(codec.rawValue)-\(sizeLabel)-first.png"
                    )
                }

                pending.append(
                    PendingFrame(
                        pixelBuffer: pixelBuffer,
                        texture: texture,
                        rendererIndex: rendererIndex,
                        sampleIndex: sampleIndex
                    )
                )

                if pending.count == 2 {
                    let oldest = pending.removeFirst()
                    let waitStart = ContinuousClock.now
                    renderers[oldest.rendererIndex].flush(sync: true)
                    gpuWaitDuration += Self.seconds(ContinuousClock.now - waitStart)
                    guard try await appendFrames(
                        oldest.pixelBuffer,
                        sampleIndex: oldest.sampleIndex
                    ) else { return }
                }
            }

            for oldest in pending {
                let waitStart = ContinuousClock.now
                renderers[oldest.rendererIndex].flush(sync: true)
                gpuWaitDuration += Self.seconds(ContinuousClock.now - waitStart)
                guard try await appendFrames(
                    oldest.pixelBuffer,
                    sampleIndex: oldest.sampleIndex
                ) else { return }
            }

            input.markAsFinished()
            await withCheckedContinuation { continuation in
                writer.finishWriting { continuation.resume() }
            }
            guard writer.status == .completed else {
                Issue.record(
                    "Writer did not complete: \(writer.error?.localizedDescription ?? "unknown")"
                )
                return
            }
        }

        let total = Self.seconds(ContinuousClock.now - totalStart)
        print(
            "GPU-EXPORT \(sizeLabel) codec=\(codec.rawValue) total=\(Self.fmt(total))s "
                + "render=\(Self.fmt(renderDuration))s "
                + "gpuWait=\(Self.fmt(gpuWaitDuration))s "
                + "wrap=\(Self.fmt(wrapDuration))s "
                + "append=\(Self.fmt(appendDuration))s "
                + "wait=\(Self.fmt(writerWaitDuration))s "
                + "unique=\(uniqueRenderCount) "
                + "frames=\(segmentCount * framesPerSegment)"
        )

        #expect(uniqueRenderCount == segmentCount * (segmentDuration * layerDataFPS))
        #expect(total > 0)
    }

    @Test func iosurfaceTextureCost() async throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            Issue.record("No Metal device available")
            return
        }
        let layout = try SkiaGPUSpikeTests.easyRunLayout()
        let activity = SkiaSpikeTests.activity()
        let size = CGSize(width: 1920, height: 1080)
        let width = Int(size.width)
        let height = Int(size.height)
        let frames = 30

        let offscreen = try #require(
            SkiaEasyRunRenderer(size: size, device: device, commandQueue: queue)
        )
        let wrapped = try #require(
            SkiaEasyRunRenderer(
                size: size,
                device: device,
                commandQueue: queue,
                offscreen: false
            )
        )

        var pixelBuffer: CVPixelBuffer?
        let attributes = Self.pixelBufferAttributes(width: width, height: height)
        guard CVPixelBufferCreate(
            nil,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        ) == kCVReturnSuccess,
              let pixelBuffer,
              let ioSurface = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() else {
            Issue.record("Could not create an IOSurface-backed pixel buffer")
            return
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        let texture = try #require(
            device.makeTexture(descriptor: descriptor, iosurface: ioSurface, plane: 0)
        )
        guard wrapped.wrap(texture: texture) else {
            Issue.record("Skia rejected the wrapped texture")
            return
        }

        for i in 0..<3 {
            offscreen.draw(layout: layout, activity: activity, elapsedTime: Double(i))
            offscreen.flush(sync: true)
            wrapped.draw(layout: layout, activity: activity, elapsedTime: Double(i))
            wrapped.flush(sync: true)
        }

        let offscreenStart = ContinuousClock.now
        for i in 0..<frames {
            offscreen.draw(layout: layout, activity: activity, elapsedTime: Double(i) * 0.5)
            offscreen.flush(sync: true)
        }
        let offscreenMs = Self.seconds(ContinuousClock.now - offscreenStart)
            / Double(frames) * 1000

        let wrappedStart = ContinuousClock.now
        for i in 0..<frames {
            wrapped.draw(layout: layout, activity: activity, elapsedTime: Double(i) * 0.5)
            wrapped.flush(sync: true)
        }
        let wrappedMs = Self.seconds(ContinuousClock.now - wrappedStart)
            / Double(frames) * 1000

        let wrappedAsyncStart = ContinuousClock.now
        for i in 0..<frames {
            wrapped.draw(layout: layout, activity: activity, elapsedTime: Double(i) * 0.5)
            wrapped.flush(sync: false)
        }
        wrapped.flush(sync: true)
        let wrappedAsyncMs = Self.seconds(ContinuousClock.now - wrappedAsyncStart)
            / Double(frames) * 1000

        print(
            "GPU-IOSURFACE offscreen-sync=\(Self.fmt(offscreenMs))ms "
                + "wrapped-sync=\(Self.fmt(wrappedMs))ms "
                + "wrapped-async=\(Self.fmt(wrappedAsyncMs))ms"
        )
    }

    private static func syntheticActivity() throws -> ActivityTimeline {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Tests/RunningOverlayTests/Fixtures/Activities/synthetic-run.fit")
        return try FitFileParser.parse(url: url)
    }

    private static func pixelBufferAttributes(width: Int, height: Int) -> [String: Any] {
        [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
    }

    private static func writePNG(
        _ pixelBuffer: CVPixelBuffer,
        width: Int,
        height: Int,
        to path: String
    ) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        let rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let provider = CGDataProvider(
            data: Data(bytes: base, count: rowBytes * height) as CFData
        ) else { return }
        guard let image = CGImage(
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
        ) else { return }
        let rep = NSBitmapImageRep(cgImage: image)
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
        }
    }

    private static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds)
            + Double(duration.components.attoseconds) / 1e18
    }

    private static func fmt(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}
#endif
