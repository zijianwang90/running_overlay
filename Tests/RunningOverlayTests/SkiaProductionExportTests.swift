#if canImport(CSkiaBridge)
import AppKit
@preconcurrency import AVFoundation
import CoreVideo
import Foundation
import Testing
@testable import RunningOverlay

@MainActor
@Suite(.serialized, .skiaSerialized)
struct SkiaProductionExportTests {
    @Test(arguments: ProjectExportCodec.allCases)
    func exportedMoviesPreservePixelsTimingReuseAndProgress(_ codec: ProjectExportCodec) async throws {
        let destination = directory()
        defer { try? FileManager.default.removeItem(at: destination) }
        let job = try makeJob(destination: destination, codec: codec)
        var progress: [OverlayExportProgress] = []
        try await SwiftUIOverlayVideoExporter.export(job: job, backend: .skia) { progress.append($0) }
        #expect(progress.filter { $0.segmentProgress == 1 }.map(\.segmentIndex).contains(1))
        for index in 0..<2 {
            let values = progress.filter { $0.segmentIndex == index }.map(\.segmentProgress)
            #expect(values.first == 0 && values.last == 1)
            #expect(values == values.sorted())
        }

        let files = try FileManager.default.contentsOfDirectory(at: destination, includingPropertiesForKeys: nil)
        let movies = files.filter { $0.pathExtension == "mov" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        #expect(movies.count == 2)
        for (movieIndex, movie) in movies.enumerated() {
            var expectedFrames: [Int: NSBitmapImageRep] = [:]
            for frameIndex in [0, 30] {
                let expectedURL = destination.appendingPathComponent("expected-\(movieIndex)-\(frameIndex).png")
                try await SwiftUIOverlayVideoExporter.exportFramePNG(
                    overlayLayout: job.overlayLayout, activity: job.activity,
                    elapsedTime: (movieIndex == 0 ? 2 : 4) + Double(frameIndex) / 30,
                    size: CGSize(width: 1280, height: 720), outputURL: expectedURL, backend: .skia
                )
                expectedFrames[frameIndex] = try #require(NSBitmapImageRep(data: Data(contentsOf: expectedURL)))
            }
            let asset = AVURLAsset(url: movie)
            let duration = try await asset.load(.duration)
            #expect(abs(duration.seconds - 1.4) < 0.001)
            let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
            let format = try #require(try await track.load(.formatDescriptions).first)
            let extensions = try #require(CMFormatDescriptionGetExtensions(format) as? [String: Any])
            #expect(extensions[kCMFormatDescriptionExtension_ColorPrimaries as String] as? String
                == kCMFormatDescriptionColorPrimaries_ITU_R_709_2 as String)
            #expect(extensions[kCMFormatDescriptionExtension_TransferFunction as String] as? String
                == kCMFormatDescriptionTransferFunction_ITU_R_709_2 as String)
            #expect(extensions[kCMFormatDescriptionExtension_YCbCrMatrix as String] as? String
                == kCMFormatDescriptionYCbCrMatrix_ITU_R_709_2 as String)
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ])
            reader.add(output)
            #expect(reader.startReading())
            var count = 0
            while let sample = output.copyNextSampleBuffer() {
                #expect(abs(CMSampleBufferGetPresentationTimeStamp(sample).seconds - Double(count) / 30) < 0.001)
                if let expected = expectedFrames[count] {
                    let buffer = try #require(CMSampleBufferGetImageBuffer(sample))
                    CVPixelBufferLockBaseAddress(buffer, .readOnly)
                    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
                    let base = try #require(CVPixelBufferGetBaseAddress(buffer)).assumingMemoryBound(to: UInt8.self)
                    let stride = CVPixelBufferGetBytesPerRow(buffer)
                    // Two deliberately overlapping decor layers near the top.
                    // Check alpha, top-left orientation, z-order and color after
                    // real codec decode rather than inspecting the render buffer.
                    let top = 144 * stride + 256 * 4
                    let bottom = 576 * stride + 256 * 4
                    #expect(base[top + 2] > 220 && base[top] < 25)
                    #expect(base[top + 3] > 240)
                    #expect(base[bottom + 3] < 5)
                    #expect(base[3] < 5)
                    let translucent = 144 * stride + 768 * 4
                    #expect((120...136).contains(Int(base[translucent + 3])))
                    var alphaDifference = 0.0
                    var visiblePixels = 0
                    // The elapsed-time text distinguishes the activity offset
                    // and segment start from unconverted project time.
                    for y in Swift.stride(from: 400, to: 700, by: 2) {
                        for x in Swift.stride(from: 400, to: 1100, by: 2) {
                            let actualAlpha = Int(base[y * stride + x * 4 + 3])
                            let expectedAlpha = Int((expected.colorAt(x: x, y: y)?.alphaComponent ?? 0) * 255)
                            if actualAlpha > 0 || expectedAlpha > 0 {
                                visiblePixels += 1
                                alphaDifference += Double(abs(actualAlpha - expectedAlpha))
                            }
                        }
                    }
                    #expect(visiblePixels > 100)
                    #expect(alphaDifference / Double(max(visiblePixels, 1)) < 5)
                }
                count += 1
            }
            #expect(reader.status == .completed)
            #expect(count == 42)
        }
        let profileURL = try #require(files.first { $0.pathExtension == "json" })
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let profile = try decoder.decode(OverlayExportProfile.self, from: Data(contentsOf: profileURL))
        #expect(profile.segments.count == 2)
        for segment in profile.segments {
            #expect(segment.renderPath == .skiaMetal)
            #expect(segment.renderedFrameCount == 7)
            #expect(segment.reusedFrameCount == 35)
            #expect(segment.staticRenderDuration == 0)
            #expect(segment.staticOverlayCount == 0)
            #expect(segment.overlayProfiles.isEmpty)
        }
    }

    @Test func pngUsesTheSelectedRenderer() async throws {
        let destination = directory()
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: destination) }
        let job = try makeJob(destination: destination, codec: .proRes4444)
        let url = destination.appendingPathComponent("frame.png")
        try await SwiftUIOverlayVideoExporter.exportFramePNG(
            overlayLayout: job.overlayLayout, activity: job.activity, elapsedTime: 0,
            size: CGSize(width: 1280, height: 720), outputURL: url, backend: .skia
        )
        let bitmap = try #require(NSBitmapImageRep(data: Data(contentsOf: url)))
        let top = try #require(bitmap.colorAt(x: 256, y: 144)?.usingColorSpace(.deviceRGB))
        #expect(top.redComponent > 0.9 && top.blueComponent < 0.1 && top.alphaComponent > 0.9)
        #expect(bitmap.colorAt(x: 256, y: 576)?.alphaComponent == 0)
    }

    @Test func cancellationStopsBeforeTheNextSegment() async throws {
        let destination = directory()
        defer { try? FileManager.default.removeItem(at: destination) }
        let job = try makeJob(destination: destination, codec: .proRes4444)
        let task = Task {
            try await SwiftUIOverlayVideoExporter.export(job: job, backend: .skia) { progress in
                if progress.segmentIndex == 0 && progress.segmentProgress > 0 {
                    withUnsafeCurrentTask { $0?.cancel() }
                }
            }
        }
        do {
            try await task.value
            Issue.record("Cancelled export completed successfully")
        } catch OverlayExportError.cancelled {
        } catch is CancellationError {
        }
        let movies = try FileManager.default.contentsOfDirectory(at: destination, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "mov" }
        #expect(movies.count <= 1)
    }

    private func directory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("skia-production-\(UUID().uuidString)")
    }

    private func makeJob(destination: URL, codec: ProjectExportCodec) throws -> OverlayExportJob {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Activities/synthetic-run.fit")
        var settings = ProjectSettings()
        settings.resolution = .hd720
        settings.frameRate = .fps30
        settings.layerDataFrameRate = .fps5
        settings.exportCodec = codec
        var red = SkiaTextFixtureFactory.solidColorElement()
        red.position = CGPoint(x: 0.2, y: 0.2)
        red.style.decor.fillColor = OverlayColor(red: 1, green: 0, blue: 0, alpha: 1)
        var blue = OverlayElement(type: red.type, position: red.position, scale: red.scale, style: red.style)
        blue.style.decor.fillColor = OverlayColor(red: 0, green: 0, blue: 1, alpha: 1)
        var translucent = OverlayElement(type: red.type, position: CGPoint(x: 0.6, y: 0.2), scale: red.scale, style: red.style)
        translucent.style.decor.fillColor = OverlayColor(red: 0, green: 1, blue: 0, alpha: 0.5)
        var timeStyle = SkiaTextFixtureFactory.style()
        timeStyle.fontSize = 100
        let time = OverlayElement(type: .elapsedTime, position: CGPoint(x: 0.4, y: 0.65), scale: 1, style: timeStyle)
        return OverlayExportJob(
            destinationURL: destination, settings: settings,
            activity: try FitFileParser.parse(url: fixture),
            overlayLayout: OverlayLayout(elements: [blue, red, translucent, time]),
            fitStartTime: 1,
            segments: [
                OverlayExportSegment(startTime: 3, duration: 1.4, sourceFileName: "a.mov"),
                OverlayExportSegment(startTime: 5, duration: 1.4, sourceFileName: "b.mov")
            ], writesProfile: true
        )
    }
}
#else
import Foundation
import Testing
@testable import RunningOverlay

@MainActor
struct SkiaProductionExportTests {
    @Test func explicitSkiaSelectionRequiresTheCompiledBackend() throws {
        #expect(throws: OverlayRendererBackendError.self) {
            try OverlayExportRendererFactory.make(
                backend: .skia, size: CGSize(width: 1280, height: 720),
                layout: OverlayLayout(elements: []), activity: .empty, mapSnapshots: [:]
            )
        }
        #expect(try OverlayExportRendererFactory.make(
            backend: .swiftUI, size: CGSize(width: 1280, height: 720),
            layout: OverlayLayout(elements: []), activity: .empty, mapSnapshots: [:]
        ) == nil)
    }
}
#endif
