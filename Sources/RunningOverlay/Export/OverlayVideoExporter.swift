import AppKit
import AVFoundation
import CoreVideo
import Foundation

struct OverlayExportSegment {
    var startTime: TimeInterval
    var duration: TimeInterval
    var sourceFileName: String
}

struct OverlayExportJob {
    var destinationURL: URL
    var settings: ProjectSettings
    var activity: ActivityTimeline
    var overlayLayout: OverlayLayout
    var fitStartTime: TimeInterval = 0
    var segments: [OverlayExportSegment]
    var renderGuides = false
}

struct OverlayExportProgress {
    var segmentIndex: Int
    var segmentCount: Int
    var segmentName: String
    var segmentProgress: Double

    var message: String {
        "Exporting \(segmentIndex + 1)/\(segmentCount): \(segmentName)"
    }
}

enum OverlayExportError: LocalizedError {
    case cancelled
    case noSegments
    case cannotCreatePixelBuffer
    case cannotStartWriting(String)
    case appendFailed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            "Export was cancelled."
        case .noSegments:
            "No timeline clips are available to export."
        case .cannotCreatePixelBuffer:
            "Could not create an export pixel buffer."
        case .cannotStartWriting(let reason):
            "Could not start writing overlay video: \(reason)"
        case .appendFailed(let reason):
            "Could not append overlay frame: \(reason)"
        }
    }
}

struct OverlayVideoExporter {
    static func export(job: OverlayExportJob, progress: @escaping @MainActor (OverlayExportProgress) -> Void) async throws {
        guard !job.segments.isEmpty else {
            throw OverlayExportError.noSegments
        }

        try FileManager.default.createDirectory(at: job.destinationURL, withIntermediateDirectories: true)

        for (index, segment) in job.segments.enumerated() {
            if Task.isCancelled {
                throw OverlayExportError.cancelled
            }
            await progress(OverlayExportProgress(segmentIndex: index, segmentCount: job.segments.count, segmentName: segment.sourceFileName, segmentProgress: 0))
            try await export(segment: segment, segmentIndex: index, segmentCount: job.segments.count, job: job, progress: progress)
            await progress(OverlayExportProgress(segmentIndex: index, segmentCount: job.segments.count, segmentName: segment.sourceFileName, segmentProgress: 1))
        }
    }

    private static func export(
        segment: OverlayExportSegment,
        segmentIndex: Int,
        segmentCount: Int,
        job: OverlayExportJob,
        progress: @escaping @MainActor (OverlayExportProgress) -> Void
    ) async throws {
        let outputURL = outputURL(for: segment, destinationURL: job.destinationURL)
        try? FileManager.default.removeItem(at: outputURL)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        let width = job.settings.resolution.width
        let height = job.settings.resolution.height
        let frameRate = job.settings.frameRate.value
        var renderCache = OverlayRenderCache()

        let outputSettings = outputSettings(
            codec: job.settings.exportCodec,
            width: width,
            height: height,
            bitrateMbps: job.settings.bitrateMbps
        )
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
            ]
        )

        guard writer.canAdd(input) else {
            throw OverlayExportError.cannotStartWriting("writer input is not supported")
        }
        writer.add(input)

        guard writer.startWriting() else {
            throw OverlayExportError.cannotStartWriting(writer.error?.localizedDescription ?? "unknown error")
        }
        writer.startSession(atSourceTime: .zero)

        guard let pixelBufferPool = adaptor.pixelBufferPool else {
            throw OverlayExportError.cannotCreatePixelBuffer
        }

        let frameCount = max(1, Int(ceil(segment.duration * frameRate)))
        let progressInterval = max(frameCount / 100, 1)
        for frameIndex in 0..<frameCount {
            if Task.isCancelled {
                writer.cancelWriting()
                throw OverlayExportError.cancelled
            }
            while !input.isReadyForMoreMediaData {
                if Task.isCancelled {
                    writer.cancelWriting()
                    throw OverlayExportError.cancelled
                }
                try await Task.sleep(nanoseconds: 1_000_000)
            }

            guard let pixelBuffer = makePixelBuffer(from: pixelBufferPool) else {
                throw OverlayExportError.cannotCreatePixelBuffer
            }
            let clipElapsed = Double(frameIndex) / frameRate
            let activityElapsed = segment.startTime + clipElapsed
            let sampleElapsed = quantizedLayerDataTime(
                activityElapsed - job.fitStartTime,
                activityDuration: job.activity.duration,
                layerDataFrameRate: job.settings.layerDataFrameRate.value
            )
            try OverlayFrameRenderer.render(
                pixelBuffer: pixelBuffer,
                request: OverlayFrameRenderRequest(
                    size: CGSize(width: width, height: height),
                    layout: job.overlayLayout,
                    activity: job.activity,
                    elapsedTime: sampleElapsed,
                    renderGuides: job.renderGuides,
                    flipVerticallyAfterRender: true
                ),
                cache: &renderCache
            )

            let presentationTime = CMTime(seconds: clipElapsed, preferredTimescale: 600)
            guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                throw OverlayExportError.appendFailed(writer.error?.localizedDescription ?? "unknown error")
            }

            if frameIndex % progressInterval == 0 || frameIndex == frameCount - 1 {
                await progress(OverlayExportProgress(
                    segmentIndex: segmentIndex,
                    segmentCount: segmentCount,
                    segmentName: segment.sourceFileName,
                    segmentProgress: Double(frameIndex + 1) / Double(frameCount)
                ))
            }
        }

        input.markAsFinished()
        await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume()
            }
        }

        if let error = writer.error {
            throw OverlayExportError.appendFailed(error.localizedDescription)
        }
    }

    private static func outputURL(for segment: OverlayExportSegment, destinationURL: URL) -> URL {
        let baseName = URL(fileURLWithPath: segment.sourceFileName).deletingPathExtension().lastPathComponent
        return destinationURL.appendingPathComponent("\(baseName)_overlay.mov")
    }

    private static func outputSettings(codec: ProjectExportCodec, width: Int, height: Int, bitrateMbps: Double) -> [String: Any] {
        var settings: [String: Any] = [
            AVVideoCodecKey: codec.avCodec,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]

        if codec == .hevcWithAlpha {
            settings[AVVideoCompressionPropertiesKey] = [
                AVVideoAverageBitRateKey: Int(bitrateMbps * 1_000_000)
            ]
        }

        return settings
    }

    private static func makePixelBuffer(from pool: CVPixelBufferPool) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(
            kCFAllocatorDefault,
            pool,
            &pixelBuffer
        )
        return pixelBuffer
    }

    private static func quantizedLayerDataTime(
        _ elapsedTime: TimeInterval,
        activityDuration: TimeInterval,
        layerDataFrameRate: Double
    ) -> TimeInterval {
        let fps = max(layerDataFrameRate, 1)
        let frame = floor(max(elapsedTime, 0) * fps)
        return min(frame / fps, activityDuration)
    }
}

private extension ProjectExportCodec {
    var avCodec: AVVideoCodecType {
        switch self {
        case .hevcWithAlpha:
            .hevcWithAlpha
        case .proRes4444:
            .proRes4444
        }
    }
}
