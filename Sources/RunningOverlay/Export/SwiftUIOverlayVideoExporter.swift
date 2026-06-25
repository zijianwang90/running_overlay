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
    static let perOverlayAreaThreshold: Double = 0.85
    static let numericBatchAreaThreshold: Double = 0.45
    static let safePadding: CGFloat = 96

    var canvasSize: CGSize
    var allOverlays: [OverlayElement]
    var staticOverlays: [OverlayElement]
    var dynamicOverlays: [OverlayElement]
    var dynamicRenderRect: CGRect
    var dynamicRenderAreaRatio: Double
    var usesFullFrameDynamicRender: Bool
    var overlayRenderItems: [ExportOverlayRenderItem]
    var overlayRenderAreaRatio: Double
    var usesPerOverlayRender: Bool
    var renderPath: OverlayExportRenderPath {
        if usesPerOverlayRender {
            .perOverlay
        } else {
            usesFullFrameDynamicRender ? .fullFrameSingleLayer : .layeredRegion
        }
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
        let individualOverlayItems = dynamicOverlays.compactMap { element -> ExportOverlayRenderItem? in
            guard let renderRect = Self.renderRect(for: element, context: context) else {
                return nil
            }
            let paddedOverlayRect = renderRect
                .insetBy(dx: -Self.safePadding, dy: -Self.safePadding)
                .intersection(canvasRect)
                .integral
            guard paddedOverlayRect.width > 0, paddedOverlayRect.height > 0 else {
                return nil
            }
            return ExportOverlayRenderItem(
                id: element.id,
                elements: [element],
                renderRect: paddedOverlayRect,
                usesRouteMapStaticCache: Self.canUseRouteMapStaticCache(for: element, context: context),
                usesElevationChartStaticFillCache: Self.canUseElevationChartStaticFillCache(for: element, context: context)
            )
        }
        let overlayItems = Self.overlayItemsByBatchingNumericOverlays(
            individualOverlayItems,
            canvasRect: canvasRect
        )
        overlayRenderItems = overlayItems
        overlayRenderAreaRatio = canvasRect.width > 0 && canvasRect.height > 0
            ? overlayItems.map { Double(($0.renderRect.width * $0.renderRect.height) / (canvasRect.width * canvasRect.height)) }.reduce(0, +)
            : 0
        usesPerOverlayRender = usesFullFrameDynamicRender
            && staticOverlays.isEmpty
            && !dynamicOverlays.isEmpty
            && individualOverlayItems.count == dynamicOverlays.count
            && overlayItems.map(\.elements.count).reduce(0, +) == dynamicOverlays.count
            && overlayRenderAreaRatio < Self.perOverlayAreaThreshold
    }

    static func isStaticOverlay(_ element: OverlayElement) -> Bool {
        switch element.type {
        case .decorSolidColor, .decorIcon, .decorText:
            true
        default:
            false
        }
    }

    static func canUseRouteMapStaticCache(for element: OverlayElement, context: OverlayRenderContext) -> Bool {
        guard element.type == .routeMap else {
            return false
        }
        let layout = OverlayRenderModel.routeMapLayout(for: element, in: context)
        return layout.geometry != nil && (layout.statsBarLayout?.items.isEmpty ?? true)
    }

    /// Whether a full-profile elevation chart can use the static fill cache:
    /// the chart geometry (grid, axis, area fill, line) is identical on every
    /// frame, so it is baked once and only the cheap current-position marker is
    /// re-rendered per frame. The dual-area progress boundary is reproduced by
    /// cropping a baked lower-fill layer, so dual area is eligible too.
    ///
    /// Excludes charts whose per-frame content cannot be reduced to the marker:
    /// progress-to-current mode (geometry grows), big numbers and a visible
    /// stats bar (data text changes per frame), and the shared foreground glow
    /// (applied to the whole composite, which the layered cache cannot match).
    static func canUseElevationChartStaticFillCache(for element: OverlayElement, context: OverlayRenderContext) -> Bool {
        guard element.type == .elevationChart else {
            return false
        }
        let style = element.style.elevationChart
        guard style.progressMode == .fullProfile else {
            return false
        }
        guard style.fillEnabled, style.chartStyle == .area else {
            return false
        }
        guard !style.bigNumbersEnabled else {
            return false
        }
        guard !element.style.glowEnabled else {
            return false
        }
        let layout = OverlayRenderModel.elevationChartLayout(for: element, in: context)
        guard layout.statsBarLayout == nil else {
            return false
        }
        return true
    }

    static func isNumericBatchCandidate(_ element: OverlayElement) -> Bool {
        switch element.type {
        case .heartRate, .heartRateZone, .pace, .avgPace, .lapPace, .calories, .elapsedTime, .realTime, .date, .distance, .elevation, .cadence, .power, .verticalOscillation, .groundContactTime, .strideLength, .verticalRatio, .groundContactBalance, .temperature, .grade:
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
        case .intervalHUDBar:
            return OverlayRenderModel.intervalHUDBarLayout(for: element, in: context).rect
        case .intervalTimeline:
            return OverlayRenderModel.intervalTimelineLayout(for: element, in: context).rect
        case .zoneEdgeBar:
            return OverlayRenderModel.zoneEdgeBarLayout(for: element, in: context).rect
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

    private static func topLeadingRect(for element: OverlayElement, size: CGSize, canvasSize: CGSize) -> CGRect {
        CGRect(
            x: canvasSize.width * element.position.x,
            y: canvasSize.height * element.position.y,
            width: size.width,
            height: size.height
        )
    }

    private static func estimatedTextRect(for element: OverlayElement, context: OverlayRenderContext) -> CGRect {
        let layout = OverlayRenderModel.textLayout(for: element, in: context)
        let valueWidth = max(CGFloat(layout.value.count) * layout.fontSize * 0.62, layout.fontSize * 2)
        let labelWidth = max(CGFloat(layout.components.label.count) * layout.labelFontSize * 0.52, 0)
        let unitWidth = max(CGFloat(layout.components.unit.count) * layout.unitFontSize * 0.52, 0)
        var width = valueWidth + labelWidth + unitWidth + layout.horizontalPadding * 2 + layout.labelSpacing + layout.unitSpacing
        var height = max(layout.fontSize, layout.labelFontSize + layout.unitFontSize) + layout.verticalPadding * 2
        if layout.iconEnabled {
            switch layout.iconPosition {
            case .leading, .trailing:
                width += layout.iconSize + layout.iconSpacing
                height = max(height, layout.iconSize + layout.verticalPadding * 2)
            case .top, .bottom:
                width = max(width, layout.iconSize + layout.horizontalPadding * 2)
                height += layout.iconSize + layout.iconSpacing
            }
        }
        let size = CGSize(width: width, height: height)
        if element.type.isNumericOverlay {
            return topLeadingRect(for: element, size: size, canvasSize: context.canvasSize)
        }
        return centeredRect(for: element, size: size, canvasSize: context.canvasSize)
    }

    private static func overlayItemsByBatchingNumericOverlays(
        _ items: [ExportOverlayRenderItem],
        canvasRect: CGRect
    ) -> [ExportOverlayRenderItem] {
        let numericItems = items.filter { item in
            item.elements.count == 1
                && !item.usesRouteMapStaticCache
                && item.elements.first.map(isNumericBatchCandidate) == true
        }
        guard numericItems.count >= 2, canvasRect.width > 0, canvasRect.height > 0 else {
            return items
        }

        let numericUnion = numericItems
            .map(\.renderRect)
            .reduce(CGRect.null) { $0.union($1) }
            .intersection(canvasRect)
            .integral
        guard !numericUnion.isNull, numericUnion.width > 0, numericUnion.height > 0 else {
            return items
        }

        let canvasArea = canvasRect.width * canvasRect.height
        let unionArea = numericUnion.width * numericUnion.height
        let individualArea = numericItems
            .map { $0.renderRect.width * $0.renderRect.height }
            .reduce(0, +)
        guard Double(unionArea / canvasArea) < Self.numericBatchAreaThreshold,
              unionArea < individualArea else {
            return items
        }

        let numericIDs = Set(numericItems.map(\.id))
        let batchedElements = numericItems.flatMap(\.elements)
        var result: [ExportOverlayRenderItem] = []
        var insertedBatch = false
        for item in items {
            if numericIDs.contains(item.id) {
                if !insertedBatch {
                    result.append(ExportOverlayRenderItem(
                        id: batchedElements[0].id,
                        elements: batchedElements,
                        renderRect: numericUnion,
                        usesRouteMapStaticCache: false
                    ))
                    insertedBatch = true
                }
            } else {
                result.append(item)
            }
        }
        return result
    }
}

struct ExportOverlayRenderItem: Equatable {
    var id: UUID
    var elements: [OverlayElement]
    var renderRect: CGRect
    var usesRouteMapStaticCache: Bool
    var usesElevationChartStaticFillCache = false

    var element: OverlayElement {
        elements[0]
    }

    var isBatch: Bool {
        elements.count > 1
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

private struct ExportOverlayRenderedImage {
    var overlayID: UUID
    var cgImage: CGImage
    var renderRect: CGRect
}

/// Baked static layers for a full-profile elevation chart. The chart geometry
/// is identical every frame, so the background chrome, grid, axis, base fill,
/// and line are rendered once. Only the current-position marker is rendered per
/// frame. For dual-area charts the lower fill is baked separately and cropped
/// to the right of the playback boundary each frame, reproducing the moving
/// two-tone split without re-rasterizing the chart.
struct ExportElevationChartStaticFillCache {
    var overlayID: UUID
    var renderRect: CGRect
    /// Chrome + grid + axis line + base (upper/single) fill. No line, marker, or labels.
    var backLayer: CGImage
    /// Dual-area lower fill only (full width). `nil` for single-area charts.
    var lowerLayer: CGImage?
    /// Chart line + glow only.
    var lineLayer: CGImage
    var isDual: Bool
    /// Geometry used to map the playback progress to a pixel column in the
    /// baked layer images (all in design points == pixels at export scale 1).
    var canvasWidth: Double
    var positionX: Double
    var cardWidth: Double
    var horizontalPadding: Double
    var chartAreaWidth: Double
}

private struct ExportOverlayRenderStats {
    var overlayID: UUID
    var overlayType: OverlayElementType
    var renderRect: CGRect
    var renderCount = 0
    var renderDuration: TimeInterval = 0
    var drawCount = 0
    var drawDuration: TimeInterval = 0
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
        let routeMapStaticLayerStartedAt = Date()
        var routeMapStaticLayerCache: [UUID: ExportOverlayRenderedImage] = [:]
        if renderPlan.usesPerOverlayRender {
            for item in renderPlan.overlayRenderItems where item.usesRouteMapStaticCache {
                guard let renderedImage = try await renderRouteMapLayer(
                    size: renderPlan.canvasSize,
                    renderRect: item.renderRect,
                    element: item.element,
                    activity: job.activity,
                    elapsedTime: 0,
                    routeMapSnapshots: routeMapSnapshots,
                    showsBaseContent: true,
                    showsCurrentMarker: false,
                    showsContainerEffects: true
                ) else {
                    throw SwiftUIOverlayExportError.appendFailed("ImageRenderer did not produce a route map static image.")
                }
                routeMapStaticLayerCache[item.id] = ExportOverlayRenderedImage(
                    overlayID: item.id,
                    cgImage: renderedImage,
                    renderRect: item.renderRect
                )
            }
        }
        let routeMapStaticRenderDuration = routeMapStaticLayerCache.isEmpty
            ? 0
            : Date().timeIntervalSince(routeMapStaticLayerStartedAt)

        let elevationChartStaticLayerStartedAt = Date()
        var elevationChartStaticFillCache: [UUID: ExportElevationChartStaticFillCache] = [:]
        if renderPlan.usesPerOverlayRender {
            for item in renderPlan.overlayRenderItems where item.usesElevationChartStaticFillCache {
                elevationChartStaticFillCache[item.id] = try await buildElevationChartStaticFillCache(
                    item: item,
                    canvasSize: renderPlan.canvasSize,
                    activity: job.activity
                )
            }
        }
        let elevationChartStaticRenderDuration = elevationChartStaticFillCache.isEmpty
            ? 0
            : Date().timeIntervalSince(elevationChartStaticLayerStartedAt)

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
                staticRenderDuration: index == 0 ? staticRenderDuration + routeMapStaticRenderDuration + elevationChartStaticRenderDuration : 0,
                routeMapStaticLayerCache: routeMapStaticLayerCache,
                elevationChartStaticFillCache: elevationChartStaticFillCache,
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

        guard let cgImage = await MainActor.run(body: {
            let frameView = SwiftUIOverlayFrameView(
                size: size,
                overlays: supportedOverlays,
                activity: activity,
                elapsedTime: elapsedTime,
                routeMapSnapshots: routeMapSnapshots.snapshots
            )
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
        routeMapStaticLayerCache: [UUID: ExportOverlayRenderedImage],
        elevationChartStaticFillCache: [UUID: ExportElevationChartStaticFillCache],
        routeMapSnapshots: RouteMapSnapshotCache,
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
        var previousOverlayImages: [ExportOverlayRenderedImage] = []
        var overlayStats = Dictionary(uniqueKeysWithValues: renderPlan.overlayRenderItems.map {
            (
                $0.id,
                ExportOverlayRenderStats(
                    overlayID: $0.id,
                    overlayType: $0.element.type,
                    renderRect: $0.renderRect
                )
            )
        })
        var overlayRenderCount = 0
        var overlayDrawCount = 0
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

            if renderPlan.usesPerOverlayRender {
                let overlayImages: [ExportOverlayRenderedImage]
                if previousSampleElapsed == sample.sampleElapsed, !previousOverlayImages.isEmpty {
                    overlayImages = previousOverlayImages
                    reusedFrameCount += 1
                    reusedRenderForFrame = true
                } else {
                    let renderStartedAt = Date()
                    var renderedImages: [ExportOverlayRenderedImage] = []
                    renderedImages.reserveCapacity(renderPlan.overlayRenderItems.count)
                    for item in renderPlan.overlayRenderItems {
                        let overlayRenderStartedAt = Date()
                        let renderedImage: CGImage
                        if item.usesRouteMapStaticCache {
                            if let staticRouteMapImage = routeMapStaticLayerCache[item.id] {
                                renderedImages.append(staticRouteMapImage)
                            }
                            guard let markerImage = try await renderRouteMapLayer(
                                size: renderPlan.canvasSize,
                                renderRect: item.renderRect,
                                element: item.element,
                                activity: job.activity,
                                elapsedTime: sample.sampleElapsed,
                                routeMapSnapshots: routeMapSnapshots,
                                showsBaseContent: false,
                                showsCurrentMarker: true,
                                showsContainerEffects: false
                            ) else {
                                throw SwiftUIOverlayExportError.appendFailed("ImageRenderer did not produce a route map marker image.")
                            }
                            renderedImage = markerImage
                        } else if item.usesElevationChartStaticFillCache, let cache = elevationChartStaticFillCache[item.id] {
                            let progressContext = OverlayRenderContext(
                                canvasSize: renderPlan.canvasSize,
                                activity: job.activity,
                                elapsedTime: sample.sampleElapsed
                            )
                            let progress = OverlayRenderModel.elevationChartLayout(for: item.element, in: progressContext).progress
                            guard let markerImage = try await renderElevationChartLayer(
                                size: renderPlan.canvasSize,
                                renderRect: item.renderRect,
                                element: item.element,
                                activity: job.activity,
                                elapsedTime: sample.sampleElapsed,
                                visibility: elevationChartMarkerVisibility
                            ) else {
                                throw SwiftUIOverlayExportError.appendFailed("ImageRenderer did not produce an elevation chart marker image.")
                            }
                            let draws = elevationChartCompositeDrawList(
                                cache: cache,
                                markerImage: markerImage,
                                progress: progress
                            )
                            for draw in draws.dropLast() {
                                renderedImages.append(ExportOverlayRenderedImage(
                                    overlayID: item.id,
                                    cgImage: draw.0,
                                    renderRect: draw.1
                                ))
                            }
                            renderedImage = markerImage
                        } else {
                            guard let layerImage = try await renderLayer(
                                size: renderPlan.canvasSize,
                                renderRect: item.renderRect,
                                overlays: item.elements,
                                activity: job.activity,
                                elapsedTime: sample.sampleElapsed,
                                routeMapSnapshots: routeMapSnapshots
                            ) else {
                                throw SwiftUIOverlayExportError.appendFailed("ImageRenderer did not produce an overlay image.")
                            }
                            renderedImage = layerImage
                        }
                        let overlayRenderDuration = Date().timeIntervalSince(overlayRenderStartedAt)
                        overlayStats[item.id]?.renderCount += 1
                        overlayStats[item.id]?.renderDuration += overlayRenderDuration
                        overlayRenderCount += 1
                        renderedImages.append(ExportOverlayRenderedImage(
                            overlayID: item.id,
                            cgImage: renderedImage,
                            renderRect: item.renderRect
                        ))
                    }
                    let renderDuration = Date().timeIntervalSince(renderStartedAt)
                    renderDurationForFrame = renderDuration
                    dynamicRenderDuration += renderDuration
                    imageRenderDuration += renderDuration
                    previousSampleElapsed = sample.sampleElapsed
                    previousOverlayImages = renderedImages
                    overlayImages = renderedImages
                    renderedFrameCount += 1
                    dynamicRenderCount += 1
                }

                let drawStartedAt = Date()
                try clearAndDraw(cgImages: overlayImages.map { ($0.cgImage, $0.renderRect) }, into: pixelBuffer, size: renderPlan.canvasSize)
                let duration = Date().timeIntervalSince(drawStartedAt)
                drawDurationForFrame += duration
                dynamicDrawDuration += duration
                pixelBufferDrawDuration += duration
                overlayDrawCount += overlayImages.count
                let drawDurationPerOverlay = overlayImages.isEmpty ? 0 : duration / Double(overlayImages.count)
                for overlayImage in overlayImages {
                    overlayStats[overlayImage.overlayID]?.drawCount += 1
                    overlayStats[overlayImage.overlayID]?.drawDuration += drawDurationPerOverlay
                }
            } else if renderPlan.usesFullFrameDynamicRender {
                let frameImage: CGImage
                if previousSampleElapsed == sample.sampleElapsed, let cachedImage = previousRenderedImage {
                    frameImage = cachedImage
                    reusedFrameCount += 1
                    reusedRenderForFrame = true
                } else {
                    let renderStartedAt = Date()
                    let renderedImage = try await renderFullFrame(
                        size: renderPlan.canvasSize,
                        overlays: renderPlan.allOverlays,
                        activity: job.activity,
                        elapsedTime: sample.sampleElapsed,
                        routeMapSnapshots: routeMapSnapshots
                    )
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
                        previousOverlayImages = []
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
        let canvasArea = renderPlan.canvasSize.width * renderPlan.canvasSize.height
        let overlayRenderAreaRatio = renderPlan.overlayRenderAreaRatio
        let overlayProfiles = renderPlan.overlayRenderItems.map { item in
            let stats = overlayStats[item.id] ?? ExportOverlayRenderStats(
                overlayID: item.id,
                overlayType: item.element.type,
                renderRect: item.renderRect
            )
            return OverlayExportOverlayProfile(
                overlayID: stats.overlayID,
                overlayType: stats.overlayType,
                renderRectX: Double(stats.renderRect.origin.x),
                renderRectY: Double(stats.renderRect.origin.y),
                renderRectWidth: Double(stats.renderRect.width),
                renderRectHeight: Double(stats.renderRect.height),
                renderAreaRatio: canvasArea > 0 ? (stats.renderRect.width * stats.renderRect.height) / canvasArea : 0,
                renderCount: stats.renderCount,
                renderDuration: stats.renderDuration,
                drawCount: stats.drawCount,
                drawDuration: stats.drawDuration
            )
        }
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
            fullFrameFallbackCount: renderPlan.renderPath == .fullFrameSingleLayer ? 1 : 0,
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
            slowFrames: frameTimingSummary.slowFrames,
            overlayRenderPathEnabled: renderPlan.usesPerOverlayRender,
            overlayRenderAreaRatio: overlayRenderAreaRatio,
            overlayRenderCount: overlayRenderCount,
            overlayDrawCount: overlayDrawCount,
            overlayProfiles: overlayProfiles
        )
    }

    private static func loadRouteMapSnapshots(
        overlays: [OverlayElement],
        activity: ActivityTimeline,
        size: CGSize
    ) async -> RouteMapSnapshotCache {
        let context = OverlayRenderContext(canvasSize: size, activity: activity, elapsedTime: 0)
        let requests = Set(overlays.compactMap { element -> MapSnapshotRequest? in
            guard element.type == .routeMap else { return nil }
            let layout = OverlayRenderModel.routeMapLayout(for: element, in: context)
            return RouteMapSnapshotRequestBuilder.request(for: element, layout: layout)
        })
        guard !requests.isEmpty else {
            return RouteMapSnapshotCache()
        }

        let provider = MapKitMapSnapshotProvider()
        var snapshots: [MapSnapshotRequest: NSImage] = [:]
        for request in requests {
            if Task.isCancelled {
                return RouteMapSnapshotCache(snapshots)
            }
            if let image = await provider.snapshotImage(for: request).image {
                snapshots[request] = image
            }
        }
        return RouteMapSnapshotCache(snapshots)
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

    private static func renderFullFrame(
        size: CGSize,
        overlays: [OverlayElement],
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        routeMapSnapshots: RouteMapSnapshotCache
    ) async throws -> CGImage {
        guard let cgImage = await MainActor.run(body: {
            autoreleasepool {
                let frameView = SwiftUIOverlayFrameView(
                    size: size,
                    overlays: overlays,
                    activity: activity,
                    elapsedTime: elapsedTime,
                    routeMapSnapshots: routeMapSnapshots.snapshots
                )
                let renderer = ImageRenderer(content: frameView)
                renderer.isOpaque = false
                renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
                renderer.scale = 1
                return renderer.cgImage
            }
        }) else {
            throw SwiftUIOverlayExportError.appendFailed("ImageRenderer did not produce a full-frame image.")
        }
        return cgImage
    }

    private static func renderLayer(
        size: CGSize,
        renderRect: CGRect,
        overlays: [OverlayElement],
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        routeMapSnapshots: RouteMapSnapshotCache
    ) async throws -> CGImage? {
        guard !overlays.isEmpty, renderRect.width > 0, renderRect.height > 0 else {
            return nil
        }

        guard let cgImage = await MainActor.run(body: {
            autoreleasepool {
                let layerView = SwiftUIOverlayLayerView(
                    canvasSize: size,
                    renderRect: renderRect,
                    overlays: overlays,
                    activity: activity,
                    elapsedTime: elapsedTime,
                    routeMapSnapshots: routeMapSnapshots.snapshots
                )
                let renderer = ImageRenderer(content: layerView)
                renderer.isOpaque = false
                renderer.proposedSize = ProposedViewSize(width: renderRect.width, height: renderRect.height)
                renderer.scale = 1
                return renderer.cgImage
            }
        }) else {
            throw SwiftUIOverlayExportError.appendFailed("ImageRenderer did not produce a layer image.")
        }
        return cgImage
    }

    private static func renderRouteMapLayer(
        size: CGSize,
        renderRect: CGRect,
        element: OverlayElement,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        routeMapSnapshots: RouteMapSnapshotCache,
        showsBaseContent: Bool,
        showsCurrentMarker: Bool,
        showsContainerEffects: Bool
    ) async throws -> CGImage? {
        guard renderRect.width > 0, renderRect.height > 0 else {
            return nil
        }

        guard let cgImage = await MainActor.run(body: {
            autoreleasepool {
                let layerView = SwiftUIRouteMapLayerView(
                    canvasSize: size,
                    renderRect: renderRect,
                    element: element,
                    activity: activity,
                    elapsedTime: elapsedTime,
                    routeMapSnapshots: routeMapSnapshots.snapshots,
                    showsBaseContent: showsBaseContent,
                    showsCurrentMarker: showsCurrentMarker,
                    showsContainerEffects: showsContainerEffects
                )
                let renderer = ImageRenderer(content: layerView)
                renderer.isOpaque = false
                renderer.proposedSize = ProposedViewSize(width: renderRect.width, height: renderRect.height)
                renderer.scale = 1
                return renderer.cgImage
            }
        }) else {
            throw SwiftUIOverlayExportError.appendFailed("ImageRenderer did not produce a route map layer image.")
        }
        return cgImage
    }

    private static func renderElevationChartLayer(
        size: CGSize,
        renderRect: CGRect,
        element: OverlayElement,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        visibility: ElevationChartLayerVisibility
    ) async throws -> CGImage? {
        guard renderRect.width > 0, renderRect.height > 0 else {
            return nil
        }

        guard let cgImage = await MainActor.run(body: {
            autoreleasepool {
                let layerView = SwiftUIElevationChartLayerView(
                    canvasSize: size,
                    renderRect: renderRect,
                    element: element,
                    activity: activity,
                    elapsedTime: elapsedTime,
                    visibility: visibility
                )
                let renderer = ImageRenderer(content: layerView)
                renderer.isOpaque = false
                renderer.proposedSize = ProposedViewSize(width: renderRect.width, height: renderRect.height)
                renderer.scale = 1
                return renderer.cgImage
            }
        }) else {
            throw SwiftUIOverlayExportError.appendFailed("ImageRenderer did not produce an elevation chart layer image.")
        }
        return cgImage
    }

    /// Visibility for the static base layer: chrome, grid, axis line, and the
    /// base (upper/single) fill. Outer effects (shadow/glow) are applied here
    /// so the composite keeps a single drop shadow.
    static let elevationChartBaseVisibility = ElevationChartLayerVisibility(
        showsContainerChrome: true,
        showsGrid: true,
        showsAxisLine: true,
        showsAxisLabels: false,
        fillMode: .baseFill,
        showsLine: false,
        showsMarker: false,
        showsStatsBar: false,
        showsBigNumbers: false,
        appliesOuterEffects: true
    )

    /// Visibility for the dual-area lower fill layer (fill only, nothing else).
    static let elevationChartLowerVisibility = ElevationChartLayerVisibility(
        showsContainerChrome: false,
        showsGrid: false,
        showsAxisLine: false,
        showsAxisLabels: false,
        fillMode: .lowerOnly,
        showsLine: false,
        showsMarker: false,
        showsStatsBar: false,
        showsBigNumbers: false,
        appliesOuterEffects: false
    )

    /// Visibility for the static line layer (line + glow only).
    static let elevationChartLineVisibility = ElevationChartLayerVisibility(
        showsContainerChrome: false,
        showsGrid: false,
        showsAxisLine: false,
        showsAxisLabels: false,
        fillMode: .none,
        showsLine: true,
        showsMarker: false,
        showsStatsBar: false,
        showsBigNumbers: false,
        appliesOuterEffects: false
    )

    /// Visibility for the per-frame dynamic layer: current marker plus axis
    /// labels (labels sit above the marker to match the standard z-order).
    static let elevationChartMarkerVisibility = ElevationChartLayerVisibility(
        showsContainerChrome: false,
        showsGrid: false,
        showsAxisLine: false,
        showsAxisLabels: true,
        fillMode: .none,
        showsLine: false,
        showsMarker: true,
        showsStatsBar: false,
        showsBigNumbers: false,
        appliesOuterEffects: false
    )

    /// Pixel column (from the left edge of the baked layer image) where the
    /// dual-area playback boundary falls, matching the live mask at
    /// `chartAreaWidth * progress`. All inputs are design points, which equal
    /// pixels because export renders at scale 1.
    static func elevationChartCutXInImage(
        progress: Double,
        cache: ExportElevationChartStaticFillCache
    ) -> Double {
        let clamped = max(0, min(1, progress))
        let cardLeft = cache.canvasWidth * cache.positionX - cache.cardWidth / 2
        let chartAreaLeft = cardLeft + cache.horizontalPadding
        return chartAreaLeft + cache.chartAreaWidth * clamped - cache.renderRect.minX
    }

    /// Ordered draw list compositing the baked static layers with the dynamic
    /// marker for a given progress: base, dual-area lower fill cropped to the
    /// right of the boundary, line, then marker.
    static func elevationChartCompositeDrawList(
        cache: ExportElevationChartStaticFillCache,
        markerImage: CGImage,
        progress: Double
    ) -> [(CGImage, CGRect)] {
        var draws: [(CGImage, CGRect)] = [(cache.backLayer, cache.renderRect)]
        if cache.isDual, let lower = cache.lowerLayer {
            let imageWidth = lower.width
            let cutX = elevationChartCutXInImage(progress: progress, cache: cache)
            let cutPixel = max(0, min(imageWidth, Int(cutX.rounded())))
            if cutPixel < imageWidth {
                let cropRect = CGRect(x: cutPixel, y: 0, width: imageWidth - cutPixel, height: lower.height)
                if let cropped = lower.cropping(to: cropRect) {
                    let destRect = CGRect(
                        x: cache.renderRect.minX + Double(cutPixel),
                        y: cache.renderRect.minY,
                        width: Double(imageWidth - cutPixel),
                        height: cache.renderRect.height
                    )
                    draws.append((cropped, destRect))
                }
            }
        }
        draws.append((cache.lineLayer, cache.renderRect))
        draws.append((markerImage, cache.renderRect))
        return draws
    }

    private static func buildElevationChartStaticFillCache(
        item: ExportOverlayRenderItem,
        canvasSize: CGSize,
        activity: ActivityTimeline
    ) async throws -> ExportElevationChartStaticFillCache {
        let element = item.element
        let context = OverlayRenderContext(canvasSize: canvasSize, activity: activity, elapsedTime: 0)
        let layout = OverlayRenderModel.elevationChartLayout(for: element, in: context)
        let isDual = element.style.elevationChart.dualAreaEnabled

        guard let backLayer = try await renderElevationChartLayer(
            size: canvasSize,
            renderRect: item.renderRect,
            element: element,
            activity: activity,
            elapsedTime: 0,
            visibility: elevationChartBaseVisibility
        ) else {
            throw SwiftUIOverlayExportError.appendFailed("ImageRenderer did not produce an elevation chart base layer.")
        }

        var lowerLayer: CGImage?
        if isDual {
            guard let lower = try await renderElevationChartLayer(
                size: canvasSize,
                renderRect: item.renderRect,
                element: element,
                activity: activity,
                elapsedTime: 0,
                visibility: elevationChartLowerVisibility
            ) else {
                throw SwiftUIOverlayExportError.appendFailed("ImageRenderer did not produce an elevation chart lower-fill layer.")
            }
            lowerLayer = lower
        }

        guard let lineLayer = try await renderElevationChartLayer(
            size: canvasSize,
            renderRect: item.renderRect,
            element: element,
            activity: activity,
            elapsedTime: 0,
            visibility: elevationChartLineVisibility
        ) else {
            throw SwiftUIOverlayExportError.appendFailed("ImageRenderer did not produce an elevation chart line layer.")
        }

        return ExportElevationChartStaticFillCache(
            overlayID: item.id,
            renderRect: item.renderRect,
            backLayer: backLayer,
            lowerLayer: lowerLayer,
            lineLayer: lineLayer,
            isDual: isDual,
            canvasWidth: canvasSize.width,
            positionX: element.position.x,
            cardWidth: layout.rect.width,
            horizontalPadding: layout.horizontalPadding,
            chartAreaWidth: layout.rect.width - layout.horizontalPadding * 2
        )
    }

    private static func clear(pixelBuffer: CVPixelBuffer, size: CGSize) throws {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        try autoreleasepool {
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
    }

    private static func clearAndDraw(cgImage: CGImage, into pixelBuffer: CVPixelBuffer, size: CGSize) throws {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        try autoreleasepool {
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
    }

    private static func clearAndDraw(cgImages: [(CGImage, CGRect)], into pixelBuffer: CVPixelBuffer, size: CGSize) throws {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        try autoreleasepool {
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
            for (cgImage, rect) in cgImages {
                context.draw(cgImage, in: pixelBufferDrawRect(forTopLeftRect: rect, canvasSize: size))
            }
        }
    }

    private static func draw(cgImage: CGImage, into pixelBuffer: CVPixelBuffer, rect: CGRect) throws {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        try autoreleasepool {
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

            let canvasSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
            context.draw(cgImage, in: pixelBufferDrawRect(forTopLeftRect: rect, canvasSize: canvasSize))
        }
    }

    static func pixelBufferDrawRect(forTopLeftRect rect: CGRect, canvasSize: CGSize) -> CGRect {
        CGRect(
            x: rect.minX,
            y: canvasSize.height - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    /// Composites an ordered draw list (top-left rects) into a fresh canvas-sized
    /// premultiplied BGRA buffer, mirroring `clearAndDraw(cgImages:)`. Returned as
    /// raw bytes for parity comparison in tests.
    static func rasterizeCanvas(draws: [(CGImage, CGRect)], canvasSize: CGSize) -> [UInt8]? {
        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        guard width > 0, height > 0 else { return nil }
        let bytesPerRow = width * 4
        var data = [UInt8](repeating: 0, count: bytesPerRow * height)
        let success = data.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let context = CGContext(
                data: rawBuffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
            ) else {
                return false
            }
            context.clear(CGRect(origin: .zero, size: canvasSize))
            for (cgImage, rect) in draws {
                context.draw(cgImage, in: pixelBufferDrawRect(forTopLeftRect: rect, canvasSize: canvasSize))
            }
            return true
        }
        return success ? data : nil
    }

    /// Mean and max per-byte difference between the static-fill-cache composite
    /// and a full single-pass render of the same elevation chart at a given
    /// elapsed time. Test seam for verifying export pixel parity.
    static func elevationChartStaticFillParity(
        element: OverlayElement,
        canvasSize: CGSize,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval
    ) async throws -> (meanAbsDiff: Double, maxAbsDiff: Int, progress: Double) {
        let baseContext = OverlayRenderContext(canvasSize: canvasSize, activity: activity, elapsedTime: 0)
        guard let rawRect = ExportRenderPlan.renderRect(for: element, context: baseContext) else {
            throw SwiftUIOverlayExportError.noSupportedOverlays
        }
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        let renderRect = rawRect
            .insetBy(dx: -ExportRenderPlan.safePadding, dy: -ExportRenderPlan.safePadding)
            .intersection(canvasRect)
            .integral
        let item = ExportOverlayRenderItem(
            id: element.id,
            elements: [element],
            renderRect: renderRect,
            usesRouteMapStaticCache: false,
            usesElevationChartStaticFillCache: true
        )
        let cache = try await buildElevationChartStaticFillCache(item: item, canvasSize: canvasSize, activity: activity)

        guard let reference = try await renderLayer(
            size: canvasSize,
            renderRect: renderRect,
            overlays: [element],
            activity: activity,
            elapsedTime: elapsedTime,
            routeMapSnapshots: RouteMapSnapshotCache()
        ) else {
            throw SwiftUIOverlayExportError.appendFailed("Reference render produced no image.")
        }
        guard let markerImage = try await renderElevationChartLayer(
            size: canvasSize,
            renderRect: renderRect,
            element: element,
            activity: activity,
            elapsedTime: elapsedTime,
            visibility: elevationChartMarkerVisibility
        ) else {
            throw SwiftUIOverlayExportError.appendFailed("Marker render produced no image.")
        }
        let progress = OverlayRenderModel.elevationChartLayout(
            for: element,
            in: OverlayRenderContext(canvasSize: canvasSize, activity: activity, elapsedTime: elapsedTime)
        ).progress
        let composite = elevationChartCompositeDrawList(cache: cache, markerImage: markerImage, progress: progress)

        guard let referenceBuffer = rasterizeCanvas(draws: [(reference, renderRect)], canvasSize: canvasSize),
              let compositeBuffer = rasterizeCanvas(draws: composite, canvasSize: canvasSize) else {
            throw SwiftUIOverlayExportError.cannotCreatePixelBuffer
        }

        var total = 0.0
        var maxDiff = 0
        let count = min(referenceBuffer.count, compositeBuffer.count)
        for index in 0..<count {
            let diff = abs(Int(referenceBuffer[index]) - Int(compositeBuffer[index]))
            total += Double(diff)
            if diff > maxDiff { maxDiff = diff }
        }
        return (total / Double(max(count, 1)), maxDiff, progress)
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
                    case .intervalHUDBar:
                        OverlaySharedIntervalHUDBarView(
                            element: element,
                            layout: OverlayRenderModel.intervalHUDBarLayout(for: element, in: context)
                        )
                    case .intervalTimeline:
                        OverlaySharedIntervalTimelineView(
                            element: element,
                            layout: OverlayRenderModel.intervalTimelineLayout(for: element, in: context)
                        )
                    case .zoneEdgeBar:
                        OverlaySharedZoneEdgeBarView(
                            element: element,
                            layout: OverlayRenderModel.zoneEdgeBarLayout(for: element, in: context)
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
                .exportOverlayPosition(for: element, in: context, canvasSize: size)
            }
        }
        .frame(width: size.width, height: size.height)
        .compositingGroup()
    }
}

private extension View {
    @ViewBuilder
    func exportOverlayPosition(for element: OverlayElement, in context: OverlayRenderContext, canvasSize: CGSize) -> some View {
        if element.type.isNumericOverlay {
            self
                .alignmentGuide(HorizontalAlignment.center) { _ in
                    canvasSize.width * (0.5 - element.position.x)
                }
                .alignmentGuide(VerticalAlignment.center) { _ in
                    canvasSize.height * (0.5 - element.position.y)
                }
        } else {
            self
                .position(resolvedExportOverlayPosition(for: element, in: context, canvasSize: canvasSize))
        }
    }

    private func resolvedExportOverlayPosition(for element: OverlayElement, in context: OverlayRenderContext, canvasSize: CGSize) -> CGPoint {
        guard element.type == .zoneEdgeBar else {
            return CGPoint(
                x: canvasSize.width * element.position.x,
                y: canvasSize.height * element.position.y
            )
        }

        let rect = OverlayRenderModel.zoneEdgeBarLayout(for: element, in: context).rect
        return CGPoint(x: rect.midX, y: rect.midY)
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

private struct SwiftUIRouteMapLayerView: View {
    let canvasSize: CGSize
    let renderRect: CGRect
    let element: OverlayElement
    let activity: ActivityTimeline
    let elapsedTime: TimeInterval
    let routeMapSnapshots: [MapSnapshotRequest: NSImage]
    let showsBaseContent: Bool
    let showsCurrentMarker: Bool
    let showsContainerEffects: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            let context = OverlayRenderContext(canvasSize: canvasSize, activity: activity, elapsedTime: elapsedTime)
            let layout = OverlayRenderModel.routeMapLayout(for: element, in: context)
            let snapshot = RouteMapSnapshotRequestBuilder
                .request(for: element, layout: layout)
                .flatMap { routeMapSnapshots[$0] }
            OverlaySharedRouteMapView(
                element: element,
                layout: layout,
                isInteractive: false,
                staticMapSnapshot: snapshot,
                showsBaseContent: showsBaseContent,
                showsCurrentMarker: showsCurrentMarker,
                showsContainerEffects: showsContainerEffects
            )
            .position(x: canvasSize.width * element.position.x, y: canvasSize.height * element.position.y)
            .offset(x: -renderRect.minX, y: -renderRect.minY)
        }
        .frame(width: renderRect.width, height: renderRect.height, alignment: .topLeading)
        .clipped()
    }
}

private struct SwiftUIElevationChartLayerView: View {
    let canvasSize: CGSize
    let renderRect: CGRect
    let element: OverlayElement
    let activity: ActivityTimeline
    let elapsedTime: TimeInterval
    let visibility: ElevationChartLayerVisibility

    var body: some View {
        ZStack(alignment: .topLeading) {
            let context = OverlayRenderContext(canvasSize: canvasSize, activity: activity, elapsedTime: elapsedTime)
            let layout = OverlayRenderModel.elevationChartLayout(for: element, in: context)
            OverlaySharedElevationChartView(
                element: element,
                layout: layout,
                visibility: visibility
            )
            .position(x: canvasSize.width * element.position.x, y: canvasSize.height * element.position.y)
            .offset(x: -renderRect.minX, y: -renderRect.minY)
        }
        .frame(width: renderRect.width, height: renderRect.height, alignment: .topLeading)
        .clipped()
    }
}
