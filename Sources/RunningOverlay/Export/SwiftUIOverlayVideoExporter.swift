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

struct ExportRenderPlan: Equatable {
    static let dynamicFullFrameAreaThreshold: Double = 0.85
    static let safePadding: CGFloat = 96

    var canvasSize: CGSize
    var allOverlays: [OverlayElement]
    var staticOverlays: [OverlayElement]
    var dynamicOverlays: [OverlayElement]
    var dynamicRenderRect: CGRect
    var dynamicRenderAreaRatio: Double
    var usesFullFrameDynamicRender: Bool
    var renderPath: OverlayExportRenderPath {
        usesFullFrameDynamicRender ? .fullFrameSingleLayer : .layeredRegion
    }

    init(overlays: [OverlayElement], canvasSize: CGSize, activity: ActivityTimeline) {
        self.canvasSize = canvasSize
        allOverlays = overlays
        staticOverlays = overlays.filter(Self.isStaticOverlay)
        dynamicOverlays = overlays.filter { !Self.isStaticOverlay($0) }

        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        let context = OverlayRenderContext(canvasSize: canvasSize, activity: activity, elapsedTime: 0)
        let rawDynamicRect = dynamicOverlays
            .compactMap { Self.renderRect(for: $0, context: context) }
            .reduce(CGRect.null) { $0.union($1) }

        let paddedRect = rawDynamicRect.isNull
            ? .zero
            : rawDynamicRect
                .insetBy(dx: -Self.safePadding, dy: -Self.safePadding)
                .intersection(canvasRect)
                .integral
        let areaRatio = canvasRect.width > 0 && canvasRect.height > 0
            ? (paddedRect.width * paddedRect.height) / (canvasRect.width * canvasRect.height)
            : 0
        usesFullFrameDynamicRender = areaRatio >= Self.dynamicFullFrameAreaThreshold
        dynamicRenderRect = usesFullFrameDynamicRender && !dynamicOverlays.isEmpty ? canvasRect : paddedRect
        dynamicRenderAreaRatio = canvasRect.width > 0 && canvasRect.height > 0
            ? (dynamicRenderRect.width * dynamicRenderRect.height) / (canvasRect.width * canvasRect.height)
            : 0
    }

    static func isStaticOverlay(_ element: OverlayElement) -> Bool {
        switch element.type {
        case .decorSolidColor, .decorIcon, .decorText:
            true
        default:
            false
        }
    }

    static func renderRect(for element: OverlayElement, context: OverlayRenderContext) -> CGRect? {
        switch element.type {
        case .distanceTimeline:
            return OverlayRenderModel.distanceTimelineLayout(for: element, in: context).rect
        case .routeMap:
            return OverlayRenderModel.routeMapLayout(for: element, in: context).rect
        case .elevationChart:
            return OverlayRenderModel.elevationChartLayout(for: element, in: context).rect
        case .runningGauge:
            return OverlayRenderModel.runningGaugeLayout(for: element, in: context).rect
        case .lapList:
            return OverlayRenderModel.lapListLayout(for: element, in: context).rect
        case .lapCard:
            return OverlayRenderModel.lapCardLayout(for: element, in: context).rect
        case .lapLive:
            return OverlayRenderModel.lapLiveLayout(for: element, in: context).rect
        case .weatherWidget:
            return OverlayRenderModel.weatherWidgetLayout(for: element, in: context).rect
        case .decorSolidColor:
            return centeredRect(for: element, size: OverlayRenderModel.decorSolidColorLayout(for: element, in: context).size, canvasSize: context.canvasSize)
        case .decorIcon:
            return centeredRect(for: element, size: OverlayRenderModel.decorIconLayout(for: element, in: context).size, canvasSize: context.canvasSize)
        case .decorText:
            return centeredRect(for: element, size: OverlayRenderModel.decorTextLayout(for: element, in: context).size, canvasSize: context.canvasSize)
        default:
            return estimatedTextRect(for: element, context: context)
        }
    }

    private static func centeredRect(for element: OverlayElement, size: CGSize, canvasSize: CGSize) -> CGRect {
        CGRect(
            x: canvasSize.width * element.position.x - size.width / 2,
            y: canvasSize.height * element.position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private static func estimatedTextRect(for element: OverlayElement, context: OverlayRenderContext) -> CGRect {
        let layout = OverlayRenderModel.textLayout(for: element, in: context)
        let valueWidth = max(CGFloat(layout.value.count) * layout.fontSize * 0.62, layout.fontSize * 2)
        let labelWidth = max(CGFloat(layout.components.label.count) * layout.labelFontSize * 0.52, 0)
        let unitWidth = max(CGFloat(layout.components.unit.count) * layout.unitFontSize * 0.52, 0)
        let width = valueWidth + labelWidth + unitWidth + layout.horizontalPadding * 2 + layout.labelSpacing + layout.unitSpacing
        let height = max(layout.fontSize, layout.labelFontSize + layout.unitFontSize) + layout.verticalPadding * 2
        return centeredRect(for: element, size: CGSize(width: width, height: height), canvasSize: context.canvasSize)
    }
}

private struct ExportFrameTiming {
    var frameIndex: Int
    var clipElapsed: TimeInterval
    var sampleElapsed: TimeInterval
    var reusedRender: Bool
    var renderDuration: TimeInterval
    var drawDuration: TimeInterval
    var frameDuration: TimeInterval
}

private struct ExportFrameTimingSummary {
    var renderDurationP50: TimeInterval
    var renderDurationP95: TimeInterval
    var renderDurationMax: TimeInterval
    var drawDurationP50: TimeInterval
    var drawDurationP95: TimeInterval
    var drawDurationMax: TimeInterval
    var frameDurationP50: TimeInterval
    var frameDurationP95: TimeInterval
    var frameDurationMax: TimeInterval
    var slowFrameThreshold: TimeInterval
    var slowFrameCount: Int
    var slowFrames: [OverlayExportSlowFrameProfile]
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
        let renderPlan = ExportRenderPlan(
            overlays: supportedOverlays,
            canvasSize: CGSize(width: job.settings.resolution.width, height: job.settings.resolution.height),
            activity: job.activity
        )
        let staticLayer: CGImage?
        let staticRenderDuration: TimeInterval
        if renderPlan.usesFullFrameDynamicRender || renderPlan.staticOverlays.isEmpty {
            staticLayer = nil
            staticRenderDuration = 0
        } else {
            let staticLayerStartedAt = Date()
            staticLayer = try await renderLayer(
                size: renderPlan.canvasSize,
                renderRect: CGRect(origin: .zero, size: renderPlan.canvasSize),
                overlays: renderPlan.staticOverlays,
                activity: job.activity,
                elapsedTime: 0,
                routeMapSnapshots: routeMapSnapshots
            )
            staticRenderDuration = Date().timeIntervalSince(staticLayerStartedAt)
        }

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
                renderPlan: renderPlan,
                staticLayer: staticLayer,
                staticRenderDuration: index == 0 ? staticRenderDuration : 0,
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
        renderPlan: ExportRenderPlan,
        staticLayer: CGImage?,
        staticRenderDuration: TimeInterval,
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
        var dynamicRenderDuration: TimeInterval = 0
        var staticDrawDuration: TimeInterval = 0
        var dynamicDrawDuration: TimeInterval = 0
        var appendDuration: TimeInterval = 0
        var writerWaitDuration: TimeInterval = 0
        var renderedFrameCount = 0
        var reusedFrameCount = 0
        var dynamicRenderCount = 0
        var previousSampleElapsed: TimeInterval?
        var previousRenderedImage: CGImage?
        var frameTimings: [ExportFrameTiming] = []
        frameTimings.reserveCapacity(frameCount)

        for sample in samples {
            let frameStartedAt = Date()
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

            var renderDurationForFrame: TimeInterval = 0
            var drawDurationForFrame: TimeInterval = 0
            var reusedRenderForFrame = false

            if renderPlan.usesFullFrameDynamicRender {
                let frameImage: CGImage
                if previousSampleElapsed == sample.sampleElapsed, let cachedImage = previousRenderedImage {
                    frameImage = cachedImage
                    reusedFrameCount += 1
                    reusedRenderForFrame = true
                } else {
                    let renderStartedAt = Date()
                    guard let renderedImage = try await renderLayer(
                        size: renderPlan.canvasSize,
                        renderRect: CGRect(origin: .zero, size: renderPlan.canvasSize),
                        overlays: renderPlan.allOverlays,
                        activity: job.activity,
                        elapsedTime: sample.sampleElapsed,
                        routeMapSnapshots: routeMapSnapshots
                    ) else {
                        throw SwiftUIOverlayExportError.appendFailed("ImageRenderer did not produce a full-frame image.")
                    }
                    let renderDuration = Date().timeIntervalSince(renderStartedAt)
                    renderDurationForFrame = renderDuration
                    dynamicRenderDuration += renderDuration
                    imageRenderDuration += renderDuration
                    previousSampleElapsed = sample.sampleElapsed
                    previousRenderedImage = renderedImage
                    frameImage = renderedImage
                    renderedFrameCount += 1
                    dynamicRenderCount += 1
                }

                let drawStartedAt = Date()
                try clearAndDraw(cgImage: frameImage, into: pixelBuffer, size: renderPlan.canvasSize)
                let duration = Date().timeIntervalSince(drawStartedAt)
                drawDurationForFrame += duration
                dynamicDrawDuration += duration
                pixelBufferDrawDuration += duration
            } else {
                let dynamicImage: CGImage?
                if renderPlan.dynamicOverlays.isEmpty {
                    dynamicImage = nil
                } else if previousSampleElapsed == sample.sampleElapsed, let cachedDynamicImage = previousRenderedImage {
                    dynamicImage = cachedDynamicImage
                    reusedFrameCount += 1
                    reusedRenderForFrame = true
                } else {
                    let renderStartedAt = Date()
                    dynamicImage = try await renderLayer(
                        size: renderPlan.canvasSize,
                        renderRect: renderPlan.dynamicRenderRect,
                        overlays: renderPlan.dynamicOverlays,
                        activity: job.activity,
                        elapsedTime: sample.sampleElapsed,
                        routeMapSnapshots: routeMapSnapshots
                    )
                    let renderDuration = Date().timeIntervalSince(renderStartedAt)
                    renderDurationForFrame = renderDuration
                    dynamicRenderDuration += renderDuration
                    imageRenderDuration += renderDuration
                    if let dynamicImage {
                        previousSampleElapsed = sample.sampleElapsed
                        previousRenderedImage = dynamicImage
                        renderedFrameCount += 1
                        dynamicRenderCount += 1
                    }
                }

                let clearStartedAt = Date()
                try clear(pixelBuffer: pixelBuffer, size: CGSize(width: width, height: height))
                let clearDuration = Date().timeIntervalSince(clearStartedAt)
                drawDurationForFrame += clearDuration
                pixelBufferDrawDuration += clearDuration
                if let staticLayer {
                    let staticDrawStartedAt = Date()
                    try draw(cgImage: staticLayer, into: pixelBuffer, rect: CGRect(origin: .zero, size: renderPlan.canvasSize))
                    let duration = Date().timeIntervalSince(staticDrawStartedAt)
                    drawDurationForFrame += duration
                    staticDrawDuration += duration
                    pixelBufferDrawDuration += duration
                }
                if let dynamicImage {
                    let dynamicDrawStartedAt = Date()
                    try draw(cgImage: dynamicImage, into: pixelBuffer, rect: renderPlan.dynamicRenderRect)
                    let duration = Date().timeIntervalSince(dynamicDrawStartedAt)
                    drawDurationForFrame += duration
                    dynamicDrawDuration += duration
                    pixelBufferDrawDuration += duration
                }
            }

            let presentationTime = CMTime(seconds: sample.clipElapsed, preferredTimescale: 600)
            let appendStartedAt = Date()
            guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                throw SwiftUIOverlayExportError.appendFailed(writer.error?.localizedDescription ?? "unknown error")
            }
            appendDuration += Date().timeIntervalSince(appendStartedAt)
            frameTimings.append(ExportFrameTiming(
                frameIndex: sample.frameIndex,
                clipElapsed: sample.clipElapsed,
                sampleElapsed: sample.sampleElapsed,
                reusedRender: reusedRenderForFrame,
                renderDuration: renderDurationForFrame,
                drawDuration: drawDurationForFrame,
                frameDuration: Date().timeIntervalSince(frameStartedAt)
            ))

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
        let frameTimingSummary = summarizeFrameTimings(frameTimings)
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
            imageRenderDuration: staticRenderDuration + imageRenderDuration,
            pixelBufferDrawDuration: pixelBufferDrawDuration,
            staticRenderDuration: staticRenderDuration,
            dynamicRenderDuration: dynamicRenderDuration,
            staticDrawDuration: staticDrawDuration,
            dynamicDrawDuration: dynamicDrawDuration,
            dynamicRenderAreaRatio: renderPlan.dynamicRenderAreaRatio,
            staticLayerCacheHitCount: staticLayer == nil ? 0 : frameCount,
            dynamicRenderCount: dynamicRenderCount,
            appendDuration: appendDuration,
            writerWaitDuration: writerWaitDuration,
            averageFrameDuration: frameCount > 0 ? totalDuration / Double(frameCount) : 0,
            renderPath: renderPlan.renderPath,
            dynamicRenderRectX: Double(renderPlan.dynamicRenderRect.origin.x),
            dynamicRenderRectY: Double(renderPlan.dynamicRenderRect.origin.y),
            dynamicRenderRectWidth: Double(renderPlan.dynamicRenderRect.width),
            dynamicRenderRectHeight: Double(renderPlan.dynamicRenderRect.height),
            dynamicOverlayCount: renderPlan.dynamicOverlays.count,
            staticOverlayCount: renderPlan.staticOverlays.count,
            fullFrameFallbackCount: renderPlan.usesFullFrameDynamicRender ? 1 : 0,
            renderDurationP50: frameTimingSummary.renderDurationP50,
            renderDurationP95: frameTimingSummary.renderDurationP95,
            renderDurationMax: frameTimingSummary.renderDurationMax,
            drawDurationP50: frameTimingSummary.drawDurationP50,
            drawDurationP95: frameTimingSummary.drawDurationP95,
            drawDurationMax: frameTimingSummary.drawDurationMax,
            frameDurationP50: frameTimingSummary.frameDurationP50,
            frameDurationP95: frameTimingSummary.frameDurationP95,
            frameDurationMax: frameTimingSummary.frameDurationMax,
            slowFrameThreshold: frameTimingSummary.slowFrameThreshold,
            slowFrameCount: frameTimingSummary.slowFrameCount,
            slowFrames: frameTimingSummary.slowFrames
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

    private static func summarizeFrameTimings(_ timings: [ExportFrameTiming]) -> ExportFrameTimingSummary {
        let renderDurations = timings
            .map(\.renderDuration)
            .filter { $0 > 0 }
            .sorted()
        let drawDurations = timings.map(\.drawDuration).sorted()
        let frameDurations = timings.map(\.frameDuration).sorted()
        let frameP50 = percentile(frameDurations, 0.50)
        let frameP95 = percentile(frameDurations, 0.95)
        let slowFrameThreshold = max(frameP95 * 2, frameP50 * 4, 0.05)
        let slowFrameCount = timings.filter { $0.frameDuration >= slowFrameThreshold }.count
        let slowFrames = timings
            .sorted { lhs, rhs in
                if lhs.frameDuration == rhs.frameDuration {
                    return lhs.frameIndex < rhs.frameIndex
                }
                return lhs.frameDuration > rhs.frameDuration
            }
            .prefix(10)
            .map {
                OverlayExportSlowFrameProfile(
                    frameIndex: $0.frameIndex,
                    clipElapsed: $0.clipElapsed,
                    sampleElapsed: $0.sampleElapsed,
                    reusedRender: $0.reusedRender,
                    renderDuration: $0.renderDuration,
                    drawDuration: $0.drawDuration,
                    frameDuration: $0.frameDuration
                )
            }

        return ExportFrameTimingSummary(
            renderDurationP50: percentile(renderDurations, 0.50),
            renderDurationP95: percentile(renderDurations, 0.95),
            renderDurationMax: renderDurations.last ?? 0,
            drawDurationP50: percentile(drawDurations, 0.50),
            drawDurationP95: percentile(drawDurations, 0.95),
            drawDurationMax: drawDurations.last ?? 0,
            frameDurationP50: frameP50,
            frameDurationP95: frameP95,
            frameDurationMax: frameDurations.last ?? 0,
            slowFrameThreshold: slowFrameThreshold,
            slowFrameCount: slowFrameCount,
            slowFrames: Array(slowFrames)
        )
    }

    private static func percentile(_ sortedValues: [TimeInterval], _ percentile: Double) -> TimeInterval {
        guard !sortedValues.isEmpty else {
            return 0
        }
        guard sortedValues.count > 1 else {
            return sortedValues[0]
        }
        let clampedPercentile = min(max(percentile, 0), 1)
        let position = clampedPercentile * Double(sortedValues.count - 1)
        let lowerIndex = Int(floor(position))
        let upperIndex = Int(ceil(position))
        guard lowerIndex != upperIndex else {
            return sortedValues[lowerIndex]
        }
        let weight = position - Double(lowerIndex)
        return sortedValues[lowerIndex] * (1 - weight) + sortedValues[upperIndex] * weight
    }

    private static func renderLayer(
        size: CGSize,
        renderRect: CGRect,
        overlays: [OverlayElement],
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        routeMapSnapshots: [MapSnapshotRequest: NSImage]
    ) async throws -> CGImage? {
        guard !overlays.isEmpty, renderRect.width > 0, renderRect.height > 0 else {
            return nil
        }

        let layerView = SwiftUIOverlayLayerView(
            canvasSize: size,
            renderRect: renderRect,
            overlays: overlays,
            activity: activity,
            elapsedTime: elapsedTime,
            routeMapSnapshots: routeMapSnapshots
        )
        guard let cgImage = await MainActor.run(body: {
            let renderer = ImageRenderer(content: layerView)
            renderer.isOpaque = false
            renderer.proposedSize = ProposedViewSize(width: renderRect.width, height: renderRect.height)
            renderer.scale = 1
            return renderer.cgImage
        }) else {
            throw SwiftUIOverlayExportError.appendFailed("ImageRenderer did not produce a layer image.")
        }
        return cgImage
    }

    private static func clear(pixelBuffer: CVPixelBuffer, size: CGSize) throws {
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
    }

    private static func clearAndDraw(cgImage: CGImage, into pixelBuffer: CVPixelBuffer, size: CGSize) throws {
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

        let rect = CGRect(origin: .zero, size: size)
        context.clear(rect)
        context.draw(cgImage, in: rect)
    }

    private static func draw(cgImage: CGImage, into pixelBuffer: CVPixelBuffer, rect: CGRect) throws {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            throw SwiftUIOverlayExportError.cannotCreatePixelBuffer
        }

        context.draw(cgImage, in: rect)
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

private struct SwiftUIOverlayLayerView: View {
    let canvasSize: CGSize
    let renderRect: CGRect
    let overlays: [OverlayElement]
    let activity: ActivityTimeline
    let elapsedTime: TimeInterval
    let routeMapSnapshots: [MapSnapshotRequest: NSImage]

    var body: some View {
        ZStack(alignment: .topLeading) {
            SwiftUIOverlayFrameView(
                size: canvasSize,
                overlays: overlays,
                activity: activity,
                elapsedTime: elapsedTime,
                routeMapSnapshots: routeMapSnapshots
            )
            .offset(x: -renderRect.minX, y: -renderRect.minY)
        }
        .frame(width: renderRect.width, height: renderRect.height, alignment: .topLeading)
        .clipped()
    }
}
