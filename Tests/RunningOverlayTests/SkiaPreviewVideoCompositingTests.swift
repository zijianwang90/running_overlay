#if DEBUG && canImport(CSkiaBridge)
import AVFoundation
import AppKit
import CoreGraphics
import Darwin
import Foundation
import Metal
import Testing
@testable import RunningOverlay

/// Verifies that the transparent Skia preview canvas composites over a real
/// decoded video. The video is generated locally with `AVAssetWriter`; no
/// fixture media or network access is involved.
@MainActor
@Suite(.serialized, .skiaSerialized) struct SkiaPreviewVideoCompositingTests {
    private static let size = CGSize(width: 1280, height: 720)

    @Test func realVideoCompositesBeneathTransparentSkiaOverlay() async throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            Issue.record("No Metal device available")
            return
        }

        let videoURL = try await Self.makeSyntheticVideo()
        defer { try? FileManager.default.removeItem(at: videoURL.deletingLastPathComponent()) }

        // Decode the same generated clip at two times: the first second is red,
        // the second is blue. Both go through the real H.264 decode path.
        let redVideo = try await Self.decodeFrame(at: 0.4, from: videoURL)
        let blueVideo = try await Self.decodeFrame(at: 1.6, from: videoURL)
        #expect(redVideo.width == Int(Self.size.width))
        #expect(redVideo.height == Int(Self.size.height))
        #expect(blueVideo.width == redVideo.width)
        #expect(blueVideo.height == redVideo.height)

        let redBackground = redVideo.pixel(x: 2, y: 2)
        let blueBackground = blueVideo.pixel(x: 2, y: 2)
        #expect(redBackground.r > 180 && redBackground.g < 60 && redBackground.b < 60)
        #expect(blueBackground.b > 180 && blueBackground.r < 60 && blueBackground.g < 60)

        let overlay = try Self.renderOverlay()
        let totalPixels = Self.size.width * Self.size.height

        var transparentCount = 0
        var opaqueCount = 0
        for index in stride(from: 0, to: overlay.bytes.count, by: 4) {
            switch overlay.bytes[index + 3] {
            case 0: transparentCount += 1
            case 255: opaqueCount += 1
            default: break
            }
        }

        // The Easy Run template is a sparse overlay: most of the canvas must be
        // transparent so the video below remains visible.
        #expect(Double(transparentCount) / Double(totalPixels) > 0.5)
        #expect(opaqueCount > 1_000)

        let overRed = Self.composite(overlay: overlay, background: redVideo)
        let overBlue = Self.composite(overlay: overlay, background: blueVideo)

        var transparentPixelsChecked = 0
        var opaquePixelsChecked = 0
        for index in stride(from: 0, to: overlay.bytes.count, by: 4) {
            let alpha = overlay.bytes[index + 3]
            if alpha == 0 {
                // Fully clear overlay pixels must pass the video through
                // unchanged (rounding aside).
                #expect(abs(Int(overRed.bytes[index]) - Int(redVideo.bytes[index])) <= 2)
                #expect(abs(Int(overRed.bytes[index + 1]) - Int(redVideo.bytes[index + 1])) <= 2)
                #expect(abs(Int(overRed.bytes[index + 2]) - Int(redVideo.bytes[index + 2])) <= 2)
                #expect(abs(Int(overBlue.bytes[index]) - Int(blueVideo.bytes[index])) <= 2)
                transparentPixelsChecked += 1
            } else if alpha == 255 {
                // Fully opaque overlay pixels must replace the video and be
                // identical over either background.
                #expect(abs(Int(overRed.bytes[index]) - Int(overlay.bytes[index])) <= 2)
                #expect(abs(Int(overRed.bytes[index + 1]) - Int(overlay.bytes[index + 1])) <= 2)
                #expect(abs(Int(overRed.bytes[index + 2]) - Int(overlay.bytes[index + 2])) <= 2)
                #expect(overRed.bytes[index] == overBlue.bytes[index])
                #expect(overRed.bytes[index + 1] == overBlue.bytes[index + 1])
                #expect(overRed.bytes[index + 2] == overBlue.bytes[index + 2])
                opaquePixelsChecked += 1
            }
        }

        #expect(transparentPixelsChecked == transparentCount)
        #expect(opaquePixelsChecked == opaqueCount)

        // The two backgrounds are visibly different, so transparent regions
        // prove the video is what shows through, not a baked background.
        #expect(abs(Int(overRed.bytes[0]) - Int(overBlue.bytes[0])) > 100)
    }

    // MARK: - Layer stack

    @Test func transparentCanvasSitsAboveVideoPlayer() {
        let container = NSView(frame: CGRect(origin: .zero, size: Self.size))
        container.wantsLayer = true
        let video = VideoPreviewNSView(frame: container.bounds)
        let overlay = SkiaPreviewMetalView(frame: container.bounds)
        container.addSubview(video)
        container.addSubview(overlay)
        container.layoutSubtreeIfNeeded()

        #expect(container.subviews.count == 2)
        #expect(container.subviews[0] === video)
        #expect(container.subviews[1] === overlay)
        #expect(video.layer?.sublayers?.contains { $0 is AVPlayerLayer } == true)
        #expect(overlay.metalLayer.isOpaque == false)
        #expect(overlay.metalLayer.backgroundColor == nil)
        #expect(overlay.layer?.backgroundColor?.alpha == 0)
        #expect(overlay.layer?.sublayers?.contains(overlay.metalLayer) == true)
    }

    // MARK: - Synthetic video

    private static func makeSyntheticVideo() async throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("skia-preview-video-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("synthetic-bars.mov")

        let width = Int(size.width)
        let height = Int(size.height)
        let frameRate = 30
        let frameCount = 60

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoColorPropertiesKey: [
                    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
                ],
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 8_000_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                ],
            ]
        )
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferMetalCompatibilityKey as String: true,
            ]
        )

        guard writer.canAdd(input) else {
            throw SyntheticVideoError("writer rejected the video input")
        }
        writer.add(input)
        guard writer.startWriting() else {
            throw SyntheticVideoError("writer failed to start: \(writer.error?.localizedDescription ?? "unknown")")
        }
        writer.startSession(atSourceTime: .zero)
        guard let pool = adaptor.pixelBufferPool else {
            throw SyntheticVideoError("adaptor did not create a pixel buffer pool")
        }

        for frame in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            var pixelBuffer: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer) == kCVReturnSuccess,
                  let pixelBuffer else {
                throw SyntheticVideoError("could not create a pixel buffer")
            }
            // First second red, second blue. Solid frames keep H.264 decode
            // tolerant and make pass-through checks unambiguous.
            Self.fill(
                pixelBuffer,
                bgra: frame < frameCount / 2
                    ? (b: 0, g: 0, r: 255)
                    : (b: 255, g: 0, r: 0)
            )
            let time = CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(frameRate))
            guard adaptor.append(pixelBuffer, withPresentationTime: time) else {
                throw SyntheticVideoError("append failed: \(writer.error?.localizedDescription ?? "unknown")")
            }
        }

        input.markAsFinished()
        await withCheckedContinuation { continuation in
            writer.finishWriting { continuation.resume() }
        }
        guard writer.status == .completed else {
            throw SyntheticVideoError("writer did not complete: \(writer.error?.localizedDescription ?? "unknown")")
        }
        return url
    }

    private static func fill(
        _ pixelBuffer: CVPixelBuffer,
        bgra: (b: UInt8, g: UInt8, r: UInt8)
    ) {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pattern: [UInt8] = [bgra.b, bgra.g, bgra.r, 255]
        let pixels = base.assumingMemoryBound(to: UInt8.self)
        for row in 0..<height {
            pattern.withUnsafeBytes { bytes in
                memset_pattern4(pixels + row * bytesPerRow, bytes.baseAddress!, width * 4)
            }
        }
    }

    private static func decodeFrame(at seconds: Double, from url: URL) async throws -> Bitmap {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let (image, _) = try await generator.image(
            at: CMTime(seconds: seconds, preferredTimescale: 600)
        )
        return try Bitmap(cgImage: image)
    }

    // MARK: - Skia overlay

    private static func renderOverlay() throws -> Bitmap {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw SyntheticVideoError("no Metal device")
        }
        let view = SkiaPreviewMetalView(frame: CGRect(origin: .zero, size: size))
        view.configure(
            layout: try easyRunLayout(),
            activity: activity,
            elapsedTime: 12,
            canvasSize: size,
            isPaused: true
        )

        let width = Int(size.width)
        let height = Int(size.height)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        let texture = try #require(device.makeTexture(descriptor: descriptor))
        guard view.renderIntoTexture(texture) else {
            throw SyntheticVideoError("Skia overlay render failed")
        }

        let rowBytes = width * 4
        var bytes = [UInt8](repeating: 0, count: rowBytes * height)
        texture.getBytes(
            &bytes,
            bytesPerRow: rowBytes,
            from: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0
        )
        return Bitmap(width: width, height: height, bytes: bytes)
    }

    private static func easyRunLayout() throws -> OverlayLayout {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/RunningOverlay/Resources/Templates/EasyRun.rotemplate")
        let template = try JSONDecoder().decode(OverlayTemplate.self, from: Data(contentsOf: url))
        var layout = template.layout
        layout.elements = layout.elements.filter(SkiaEasyRunRenderer.supports)
        // Keep the test offline: the Skia spike draws a local grid when the
        // MapKit snapshot background is disabled.
        for index in layout.elements.indices where layout.elements[index].type == .routeMap {
            layout.elements[index].style.routeMapBackgroundStyle = .none
        }
        return layout
    }

    // MARK: - Compositing

    /// CPU equivalent of the layer composite the window server performs:
    /// premultiplied overlay BGRA over opaque video BGRA.
    private static func composite(overlay: Bitmap, background: Bitmap) -> Bitmap {
        var result = background
        for index in stride(from: 0, to: overlay.bytes.count, by: 4) {
            let alpha = Double(overlay.bytes[index + 3]) / 255
            guard alpha > 0 else { continue }
            for channel in 0..<3 {
                let value = Double(overlay.bytes[index + channel])
                    + Double(background.bytes[index + channel]) * (1 - alpha)
                result.bytes[index + channel] = UInt8(min(255, max(0, value.rounded())))
            }
            result.bytes[index + 3] = 255
        }
        return result
    }

    // MARK: - Fixtures

    private static let activity: ActivityTimeline = {
        let start = Date(timeIntervalSince1970: 1_735_689_600)
        // Values are separate locals because one large literal times out the
        // type checker on older toolchains.
        let records: [ActivityRecord] = stride(from: 0.0, through: 60, by: 1)
            .map { (t: Double) -> ActivityRecord in
                let distanceMeters: Double = t * 3.3
                let heartRate: Int = 130 + Int(t / 3)
                let elevationMeters: Double = 20 + t / 10
                let calories: Double = t / 4
                let latitude: Double = 40.75 + 0.0006 * sin(t / 8)
                let longitude: Double = -73.99 + 0.0008 * cos(t / 8)
                return ActivityRecord(
                    elapsedTime: t,
                    timestamp: start.addingTimeInterval(t),
                    distanceMeters: distanceMeters,
                    heartRate: heartRate,
                    paceSecondsPerKilometer: 300,
                    elevationMeters: elevationMeters,
                    cadence: 176,
                    powerWatts: 250,
                    calories: calories,
                    latitude: latitude,
                    longitude: longitude
                )
            }
        return ActivityTimeline(
            startDate: start,
            duration: 60,
            distanceMeters: 200,
            records: records,
            laps: []
        )
    }()
}

private struct SyntheticVideoError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// BGRA8 bitmap used for decoded video frames, Skia readback, and composites.
private struct Bitmap {
    let width: Int
    let height: Int
    var bytes: [UInt8]

    init(width: Int, height: Int, bytes: [UInt8]) {
        self.width = width
        self.height = height
        self.bytes = bytes
    }

    init(cgImage: CGImage) throws {
        let width = cgImage.width
        let height = cgImage.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: &bytes,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: width * 4,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                      | CGBitmapInfo.byteOrder32Little.rawValue
              ) else {
            throw SyntheticVideoError("could not create a bitmap context")
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        self.init(width: width, height: height, bytes: bytes)
    }

    func pixel(x: Int, y: Int) -> (b: UInt8, g: UInt8, r: UInt8, a: UInt8) {
        let index = (y * width + x) * 4
        return (bytes[index], bytes[index + 1], bytes[index + 2], bytes[index + 3])
    }
}
#endif
