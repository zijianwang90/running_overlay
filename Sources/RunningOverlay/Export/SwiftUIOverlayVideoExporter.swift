import AppKit
import AVFoundation
import CoreVideo
import Foundation
import SwiftUI

enum SwiftUIOverlayExportError: LocalizedError {
    case noSupportedOverlays
    case cannotCreatePixelBuffer
    case cannotStartWriting(String)
    case appendFailed(String)

    var errorDescription: String? {
        switch self {
        case .noSupportedOverlays:
            "No supported overlays are available for SwiftUI experimental export."
        case .cannotCreatePixelBuffer:
            "Could not create an export pixel buffer."
        case .cannotStartWriting(let reason):
            "Could not start writing SwiftUI overlay video: \(reason)"
        case .appendFailed(let reason):
            "Could not append SwiftUI overlay frame: \(reason)"
        }
    }
}

struct SwiftUIOverlayVideoExporter {
    static func export(job: OverlayExportJob, progress: @escaping @MainActor (OverlayExportProgress) -> Void) async throws {
        guard !job.segments.isEmpty else {
            throw OverlayExportError.noSegments
        }

        let supportedOverlays = job.overlayLayout.elements.filter(\.isVisible)
        guard !supportedOverlays.isEmpty else {
            throw SwiftUIOverlayExportError.noSupportedOverlays
        }

        try FileManager.default.createDirectory(at: job.destinationURL, withIntermediateDirectories: true)
        let routeMapSnapshots = await loadRouteMapSnapshots(
            overlays: supportedOverlays,
            activity: job.activity,
            size: CGSize(width: job.settings.resolution.width, height: job.settings.resolution.height)
        )

        let profileStartedAt = Date()
        var segmentProfiles: [OverlayExportSegmentProfile] = []

        for (index, segment) in job.segments.enumerated() {
            if Task.isCancelled {
                throw OverlayExportError.cancelled
            }
            await progress(OverlayExportProgress(segmentIndex: index, segmentCount: job.segments.count, segmentName: segment.sourceFileName, segmentProgress: 0))
            let segmentProfile = try await export(
                segment: segment,
                segmentIndex: index,
                segmentCount: job.segments.count,
                job: job,
                overlays: supportedOverlays,
                routeMapSnapshots: routeMapSnapshots,
                progress: progress
            )
            segmentProfiles.append(segmentProfile)
            await progress(OverlayExportProgress(segmentIndex: index, segmentCount: job.segments.count, segmentName: segment.sourceFileName, segmentProgress: 1))
        }

        try writeProfile(
            OverlayExportProfile(
                startedAt: profileStartedAt,
                completedAt: Date(),
                settings: job.settings,
                segments: segmentProfiles
            ),
            to: job.destinationURL
        )
    }

    static func exportFramePNG(
        overlayLayout: OverlayLayout,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        size: CGSize,
        outputURL: URL
    ) async throws {
        let supportedOverlays = overlayLayout.elements.filter(\.isVisible)
        guard !supportedOverlays.isEmpty else {
            throw SwiftUIOverlayExportError.noSupportedOverlays
        }
        let routeMapSnapshots = await loadRouteMapSnapshots(
            overlays: supportedOverlays,
            activity: activity,
            size: size
        )

        let frameView = SwiftUIOverlayFrameView(
            size: size,
            overlays: supportedOverlays,
            activity: activity,
            elapsedTime: elapsedTime,
            routeMapSnapshots: routeMapSnapshots
        )
        guard let cgImage = await MainActor.run(body: {
            let renderer = ImageRenderer(content: frameView)
            renderer.isOpaque = false
            renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
            renderer.scale = 1
            return renderer.cgImage
        }) else {
            throw SwiftUIOverlayExportError.appendFailed("ImageRenderer did not produce a frame image.")
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw SwiftUIOverlayExportError.appendFailed("Could not convert SwiftUI frame to PNG data.")
        }
        try data.write(to: outputURL)
    }

    private static func export(
        segment: OverlayExportSegment,
        segmentIndex: Int,
        segmentCount: Int,
        job: OverlayExportJob,
        overlays: [OverlayElement],
        routeMapSnapshots: [MapSnapshotRequest: NSImage],
        progress: @escaping @MainActor (OverlayExportProgress) -> Void
    ) async throws -> OverlayExportSegmentProfile {
        let outputURL = outputURL(for: segment, destinationURL: job.destinationURL)
        try? FileManager.default.removeItem(at: outputURL)
        let segmentStartedAt = Date()

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        let width = job.settings.resolution.width
        let height = job.settings.resolution.height
        let frameRate = job.settings.frameRate.value

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
            throw SwiftUIOverlayExportError.cannotStartWriting("writer input is not supported")
        }
        writer.add(input)

        guard writer.startWriting() else {
            throw SwiftUIOverlayExportError.cannotStartWriting(writer.error?.localizedDescription ?? "unknown error")
        }
        writer.startSession(atSourceTime: .zero)

        guard let pixelBufferPool = adaptor.pixelBufferPool else {
            throw SwiftUIOverlayExportError.cannotCreatePixelBuffer
        }

        let samples = frameSamples(
            segment: segment,
            frameRate: frameRate,
            activityDuration: job.activity.duration,
            layerDataFrameRate: job.settings.layerDataFrameRate.value,
            fitStartTime: job.fitStartTime
        )
        let frameCount = samples.count
        let progressInterval = max(frameCount / 100, 1)
        var imageRenderDuration: TimeInterval = 0
        var pixelBufferDrawDuration: TimeInterval = 0
        var appendDuration: TimeInterval = 0
        var writerWaitDuration: TimeInterval = 0
        var renderedFrameCount = 0
        var reusedFrameCount = 0
        var previousSampleElapsed: TimeInterval?
        var previousCGImage: CGImage?

        for sample in samples {
            if Task.isCancelled {
                writer.cancelWriting()
                throw OverlayExportError.cancelled
            }
            let waitStartedAt = Date()
            while !input.isReadyForMoreMediaData {
                if Task.isCancelled {
                    writer.cancelWriting()
                    throw OverlayExportError.cancelled
                }
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            writerWaitDuration += Date().timeIntervalSince(waitStartedAt)

            guard let pixelBuffer = makePixelBuffer(from: pixelBufferPool) else {
                throw SwiftUIOverlayExportError.cannotCreatePixelBuffer
            }

            let cgImage: CGImage
            if previousSampleElapsed == sample.sampleElapsed, let cachedCGImage = previousCGImage {
                cgImage = cachedCGImage
                reusedFrameCount += 1
            } else {
                let renderStartedAt = Date()
                let frameView = SwiftUIOverlayFrameView(
                    size: CGSize(width: width, height: height),
                    overlays: overlays,
                    activity: job.activity,
                    elapsedTime: sample.sampleElapsed,
                    routeMapSnapshots: routeMapSnapshots
                )
                guard let renderedCGImage = await MainActor.run(body: {
                    let renderer = ImageRenderer(content: frameView)
                    renderer.isOpaque = false
                    renderer.proposedSize = ProposedViewSize(width: CGFloat(width), height: CGFloat(height))
                    renderer.scale = 1
                    return renderer.cgImage
                }) else {
                    throw SwiftUIOverlayExportError.appendFailed("ImageRenderer did not produce a CGImage.")
                }
                imageRenderDuration += Date().timeIntervalSince(renderStartedAt)
                cgImage = renderedCGImage
                previousSampleElapsed = sample.sampleElapsed
                previousCGImage = renderedCGImage
                renderedFrameCount += 1
            }

            let drawStartedAt = Date()
            try draw(cgImage: cgImage, into: pixelBuffer, size: CGSize(width: width, height: height))
            pixelBufferDrawDuration += Date().timeIntervalSince(drawStartedAt)

            let presentationTime = CMTime(seconds: sample.clipElapsed, preferredTimescale: 600)
            let appendStartedAt = Date()
            guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                throw SwiftUIOverlayExportError.appendFailed(writer.error?.localizedDescription ?? "unknown error")
            }
            appendDuration += Date().timeIntervalSince(appendStartedAt)

            if sample.frameIndex % progressInterval == 0 || sample.frameIndex == frameCount - 1 {
                await progress(OverlayExportProgress(
                    segmentIndex: segmentIndex,
                    segmentCount: segmentCount,
                    segmentName: segment.sourceFileName,
                    segmentProgress: Double(sample.frameIndex + 1) / Double(frameCount)
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
            throw SwiftUIOverlayExportError.appendFailed(error.localizedDescription)
        }

        let totalDuration = Date().timeIntervalSince(segmentStartedAt)
        return OverlayExportSegmentProfile(
            segmentIndex: segmentIndex,
            segmentName: segment.sourceFileName,
            outputFileName: outputURL.lastPathComponent,
            duration: segment.duration,
            frameCount: frameCount,
            renderedFrameCount: renderedFrameCount,
            reusedFrameCount: reusedFrameCount,
            reuseRate: frameCount > 0 ? Double(reusedFrameCount) / Double(frameCount) : 0,
            totalDuration: totalDuration,
            imageRenderDuration: imageRenderDuration,
            pixelBufferDrawDuration: pixelBufferDrawDuration,
            appendDuration: appendDuration,
            writerWaitDuration: writerWaitDuration,
            averageFrameDuration: frameCount > 0 ? totalDuration / Double(frameCount) : 0
        )
    }

    private static func loadRouteMapSnapshots(
        overlays: [OverlayElement],
        activity: ActivityTimeline,
        size: CGSize
    ) async -> [MapSnapshotRequest: NSImage] {
        let context = OverlayRenderContext(canvasSize: size, activity: activity, elapsedTime: 0)
        let requests = Set(overlays.compactMap { element -> MapSnapshotRequest? in
            guard element.type == .routeMap else { return nil }
            let layout = OverlayRenderModel.routeMapLayout(for: element, in: context)
            return RouteMapSnapshotRequestBuilder.request(for: element, layout: layout)
        })
        guard !requests.isEmpty else {
            return [:]
        }

        let provider = MapKitMapSnapshotProvider()
        var snapshots: [MapSnapshotRequest: NSImage] = [:]
        for request in requests {
            if Task.isCancelled {
                return snapshots
            }
            let result = await withCheckedContinuation { continuation in
                provider.snapshot(for: request) { result in
                    continuation.resume(returning: result)
                }
            }
            if case .success(let image) = result {
                snapshots[request] = image
            }
        }
        return snapshots
    }

    private static func draw(cgImage: CGImage, into pixelBuffer: CVPixelBuffer, size: CGSize) throws {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            throw SwiftUIOverlayExportError.cannotCreatePixelBuffer
        }

        context.clear(CGRect(origin: .zero, size: size))
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
    }

    private static func outputURL(for segment: OverlayExportSegment, destinationURL: URL) -> URL {
        let baseName = URL(fileURLWithPath: segment.sourceFileName).deletingPathExtension().lastPathComponent
        return destinationURL.appendingPathComponent("\(baseName)_swiftui_overlay.mov")
    }

    private static func writeProfile(_ profile: OverlayExportProfile, to destinationURL: URL) throws {
        let stamp = profileTimestampFormatter.string(from: profile.completedAt)
        let jsonURL = destinationURL.appendingPathComponent("export_profile_\(stamp).json")
        let csvURL = destinationURL.appendingPathComponent("export_profile_\(stamp).csv")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(profile).write(to: jsonURL)
        try Data(profile.csvString().utf8).write(to: csvURL)
    }

    private static var profileTimestampFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
        return formatter
    }

    private static func makePixelBuffer(from pool: CVPixelBufferPool) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        return pixelBuffer
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

    static func frameSamples(
        segment: OverlayExportSegment,
        frameRate: Double,
        activityDuration: TimeInterval,
        layerDataFrameRate: Double,
        fitStartTime: TimeInterval
    ) -> [OverlayExportFrameSample] {
        let fps = max(frameRate, 1)
        let frameCount = max(1, Int(ceil(segment.duration * fps)))
        var samples: [OverlayExportFrameSample] = []
        samples.reserveCapacity(frameCount)
        var previousSampleElapsed: TimeInterval?

        for frameIndex in 0..<frameCount {
            let clipElapsed = Double(frameIndex) / fps
            let activityElapsed = segment.startTime + clipElapsed
            let sampleElapsed = quantizedLayerDataTime(
                activityElapsed - fitStartTime,
                activityDuration: activityDuration,
                layerDataFrameRate: layerDataFrameRate
            )
            samples.append(OverlayExportFrameSample(
                frameIndex: frameIndex,
                clipElapsed: clipElapsed,
                activityElapsed: activityElapsed,
                sampleElapsed: sampleElapsed,
                reusesPreviousRender: previousSampleElapsed == sampleElapsed
            ))
            previousSampleElapsed = sampleElapsed
        }

        return samples
    }

    static func quantizedLayerDataTime(
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

private struct SwiftUIOverlayFrameView: View {
    let size: CGSize
    let overlays: [OverlayElement]
    let activity: ActivityTimeline
    let elapsedTime: TimeInterval
    let routeMapSnapshots: [MapSnapshotRequest: NSImage]

    var body: some View {
        ZStack {
            Color.clear
            ForEach(overlays) { element in
                let context = OverlayRenderContext(canvasSize: size, activity: activity, elapsedTime: elapsedTime)
                Group {
                    switch element.type {
                    case .distanceTimeline:
                        OverlaySharedDistanceTimelineView(
                            element: element,
                            layout: OverlayRenderModel.distanceTimelineLayout(for: element, in: context),
                            isInteractive: false
                        )
                    case .routeMap:
                        let layout = OverlayRenderModel.routeMapLayout(for: element, in: context)
                        let snapshot = RouteMapSnapshotRequestBuilder
                            .request(for: element, layout: layout)
                            .flatMap { routeMapSnapshots[$0] }
                        OverlaySharedRouteMapView(
                            element: element,
                            layout: layout,
                            isInteractive: false,
                            staticMapSnapshot: snapshot
                        )
                    case .elevationChart:
                        OverlaySharedElevationChartView(
                            element: element,
                            layout: OverlayRenderModel.elevationChartLayout(for: element, in: context)
                        )
                    case .runningGauge:
                        OverlaySharedRunningGaugeView(
                            element: element,
                            layout: OverlayRenderModel.runningGaugeLayout(for: element, in: context),
                            isInteractive: false
                        )
                    case .lapList:
                        OverlaySharedLapListView(
                            element: element,
                            layout: OverlayRenderModel.lapListLayout(for: element, in: context)
                        )
                    case .lapCard:
                        OverlaySharedLapCardView(
                            element: element,
                            layout: OverlayRenderModel.lapCardLayout(for: element, in: context)
                        )
                    case .lapLive:
                        OverlaySharedLapLiveView(
                            element: element,
                            layout: OverlayRenderModel.lapLiveLayout(for: element, in: context)
                        )
                    case .decorSolidColor:
                        OverlaySharedDecorSolidColorView(
                            element: element,
                            layout: OverlayRenderModel.decorSolidColorLayout(for: element, in: context)
                        )
                    case .decorIcon:
                        OverlaySharedDecorIconView(
                            element: element,
                            layout: OverlayRenderModel.decorIconLayout(for: element, in: context)
                        )
                    case .decorText:
                        OverlaySharedDecorTextView(
                            element: element,
                            layout: OverlayRenderModel.decorTextLayout(for: element, in: context)
                        )
                    case .weatherWidget:
                        OverlaySharedWeatherWidgetView(
                            element: element,
                            layout: OverlayRenderModel.weatherWidgetLayout(for: element, in: context)
                        )
                    default:
                        OverlaySharedTextPresetView(
                            element: element,
                            layout: OverlayRenderModel.textLayout(for: element, in: context),
                            isInteractive: false
                        )
                    }
                }
                .position(x: size.width * element.position.x, y: size.height * element.position.y)
            }
        }
        .frame(width: size.width, height: size.height)
        .compositingGroup()
    }
}
