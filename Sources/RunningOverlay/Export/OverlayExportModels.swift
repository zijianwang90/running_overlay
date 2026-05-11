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

struct OverlayExportFrameSample: Equatable {
    var frameIndex: Int
    var clipElapsed: TimeInterval
    var activityElapsed: TimeInterval
    var sampleElapsed: TimeInterval
    var reusesPreviousRender: Bool
}

enum OverlayExportRenderPath: String, Codable, Equatable, Hashable {
    case fullFrameSingleLayer
    case layeredRegion
}

struct OverlayExportSlowFrameProfile: Codable, Equatable {
    var frameIndex: Int
    var clipElapsed: TimeInterval
    var sampleElapsed: TimeInterval
    var reusedRender: Bool
    var renderDuration: TimeInterval
    var drawDuration: TimeInterval
    var frameDuration: TimeInterval
}

struct OverlayExportSegmentProfile: Codable, Equatable {
    var segmentIndex: Int
    var segmentName: String
    var outputFileName: String
    var duration: TimeInterval
    var frameCount: Int
    var renderedFrameCount: Int
    var reusedFrameCount: Int
    var reuseRate: Double
    var totalDuration: TimeInterval
    var imageRenderDuration: TimeInterval
    var pixelBufferDrawDuration: TimeInterval
    var staticRenderDuration: TimeInterval = 0
    var dynamicRenderDuration: TimeInterval = 0
    var staticDrawDuration: TimeInterval = 0
    var dynamicDrawDuration: TimeInterval = 0
    var dynamicRenderAreaRatio: Double = 1
    var staticLayerCacheHitCount: Int = 0
    var dynamicRenderCount: Int = 0
    var appendDuration: TimeInterval
    var writerWaitDuration: TimeInterval
    var averageFrameDuration: TimeInterval
    var renderPath: OverlayExportRenderPath = .fullFrameSingleLayer
    var dynamicRenderRectX: Double = 0
    var dynamicRenderRectY: Double = 0
    var dynamicRenderRectWidth: Double = 0
    var dynamicRenderRectHeight: Double = 0
    var dynamicOverlayCount: Int = 0
    var staticOverlayCount: Int = 0
    var fullFrameFallbackCount: Int = 0
    var renderDurationP50: TimeInterval = 0
    var renderDurationP95: TimeInterval = 0
    var renderDurationMax: TimeInterval = 0
    var drawDurationP50: TimeInterval = 0
    var drawDurationP95: TimeInterval = 0
    var drawDurationMax: TimeInterval = 0
    var frameDurationP50: TimeInterval = 0
    var frameDurationP95: TimeInterval = 0
    var frameDurationMax: TimeInterval = 0
    var slowFrameThreshold: TimeInterval = 0
    var slowFrameCount: Int = 0
    var slowFrames: [OverlayExportSlowFrameProfile] = []
}

struct OverlayExportProfile: Codable, Equatable {
    var schemaVersion = 4
    var startedAt: Date
    var completedAt: Date
    var settings: ProjectSettings
    var segmentCount: Int
    var totalFrameCount: Int
    var renderedFrameCount: Int
    var reusedFrameCount: Int
    var reuseRate: Double
    var totalDuration: TimeInterval
    var imageRenderDuration: TimeInterval
    var pixelBufferDrawDuration: TimeInterval
    var staticRenderDuration: TimeInterval
    var dynamicRenderDuration: TimeInterval
    var staticDrawDuration: TimeInterval
    var dynamicDrawDuration: TimeInterval
    var dynamicRenderAreaRatio: Double
    var staticLayerCacheHitCount: Int
    var dynamicRenderCount: Int
    var appendDuration: TimeInterval
    var writerWaitDuration: TimeInterval
    var averageFrameDuration: TimeInterval
    var renderPath: OverlayExportRenderPath
    var dynamicRenderRectX: Double
    var dynamicRenderRectY: Double
    var dynamicRenderRectWidth: Double
    var dynamicRenderRectHeight: Double
    var dynamicOverlayCount: Int
    var staticOverlayCount: Int
    var fullFrameFallbackCount: Int
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
    var segments: [OverlayExportSegmentProfile]

    init(startedAt: Date, completedAt: Date, settings: ProjectSettings, segments: [OverlayExportSegmentProfile]) {
        let totalFrameCount = segments.map(\.frameCount).reduce(0, +)
        let renderedFrameCount = segments.map(\.renderedFrameCount).reduce(0, +)
        let reusedFrameCount = segments.map(\.reusedFrameCount).reduce(0, +)

        self.startedAt = startedAt
        self.completedAt = completedAt
        self.settings = settings
        self.segmentCount = segments.count
        self.totalFrameCount = totalFrameCount
        self.renderedFrameCount = renderedFrameCount
        self.reusedFrameCount = reusedFrameCount
        self.reuseRate = totalFrameCount > 0 ? Double(reusedFrameCount) / Double(totalFrameCount) : 0
        self.imageRenderDuration = segments.map(\.imageRenderDuration).reduce(0, +)
        self.pixelBufferDrawDuration = segments.map(\.pixelBufferDrawDuration).reduce(0, +)
        self.staticRenderDuration = segments.map(\.staticRenderDuration).reduce(0, +)
        self.dynamicRenderDuration = segments.map(\.dynamicRenderDuration).reduce(0, +)
        self.staticDrawDuration = segments.map(\.staticDrawDuration).reduce(0, +)
        self.dynamicDrawDuration = segments.map(\.dynamicDrawDuration).reduce(0, +)
        self.dynamicRenderAreaRatio = totalFrameCount > 0
            ? segments.map { $0.dynamicRenderAreaRatio * Double($0.frameCount) }.reduce(0, +) / Double(totalFrameCount)
            : 0
        self.staticLayerCacheHitCount = segments.map(\.staticLayerCacheHitCount).reduce(0, +)
        self.dynamicRenderCount = segments.map(\.dynamicRenderCount).reduce(0, +)
        self.totalDuration = segments.map(\.totalDuration).reduce(0, +) + self.staticRenderDuration
        self.appendDuration = segments.map(\.appendDuration).reduce(0, +)
        self.writerWaitDuration = segments.map(\.writerWaitDuration).reduce(0, +)
        self.averageFrameDuration = totalFrameCount > 0 ? self.totalDuration / Double(totalFrameCount) : 0
        self.renderPath = Set(segments.map(\.renderPath)).count == 1 ? (segments.first?.renderPath ?? .fullFrameSingleLayer) : .layeredRegion
        self.dynamicRenderRectX = segments.first?.dynamicRenderRectX ?? 0
        self.dynamicRenderRectY = segments.first?.dynamicRenderRectY ?? 0
        self.dynamicRenderRectWidth = segments.first?.dynamicRenderRectWidth ?? 0
        self.dynamicRenderRectHeight = segments.first?.dynamicRenderRectHeight ?? 0
        self.dynamicOverlayCount = segments.first?.dynamicOverlayCount ?? 0
        self.staticOverlayCount = segments.first?.staticOverlayCount ?? 0
        self.fullFrameFallbackCount = segments.map(\.fullFrameFallbackCount).reduce(0, +)
        self.renderDurationP50 = Self.weightedAverage(segments.map { ($0.renderDurationP50, $0.renderedFrameCount) })
        self.renderDurationP95 = Self.weightedAverage(segments.map { ($0.renderDurationP95, $0.renderedFrameCount) })
        self.renderDurationMax = segments.map(\.renderDurationMax).max() ?? 0
        self.drawDurationP50 = Self.weightedAverage(segments.map { ($0.drawDurationP50, $0.frameCount) })
        self.drawDurationP95 = Self.weightedAverage(segments.map { ($0.drawDurationP95, $0.frameCount) })
        self.drawDurationMax = segments.map(\.drawDurationMax).max() ?? 0
        self.frameDurationP50 = Self.weightedAverage(segments.map { ($0.frameDurationP50, $0.frameCount) })
        self.frameDurationP95 = Self.weightedAverage(segments.map { ($0.frameDurationP95, $0.frameCount) })
        self.frameDurationMax = segments.map(\.frameDurationMax).max() ?? 0
        self.slowFrameThreshold = Self.weightedAverage(segments.map { ($0.slowFrameThreshold, $0.frameCount) })
        self.slowFrameCount = segments.map(\.slowFrameCount).reduce(0, +)
        self.segments = segments
    }

    func csvString() -> String {
        let header = [
            "rowType", "segmentIndex", "segmentName", "outputFileName", "duration", "frameCount",
            "renderedFrameCount", "reusedFrameCount", "reuseRate", "totalDuration",
            "imageRenderDuration", "pixelBufferDrawDuration", "staticRenderDuration",
            "dynamicRenderDuration", "staticDrawDuration", "dynamicDrawDuration",
            "dynamicRenderAreaRatio", "staticLayerCacheHitCount", "dynamicRenderCount", "appendDuration",
            "writerWaitDuration", "averageFrameDuration", "renderPath", "dynamicRenderRectX",
            "dynamicRenderRectY", "dynamicRenderRectWidth", "dynamicRenderRectHeight",
            "dynamicOverlayCount", "staticOverlayCount", "fullFrameFallbackCount",
            "renderDurationP50", "renderDurationP95", "renderDurationMax",
            "drawDurationP50", "drawDurationP95", "drawDurationMax",
            "frameDurationP50", "frameDurationP95", "frameDurationMax",
            "slowFrameThreshold", "slowFrameCount"
        ]
        let summary = csvRow([
            "summary", "", "", "", "",
            String(totalFrameCount),
            String(renderedFrameCount),
            String(reusedFrameCount),
            String(reuseRate),
            String(totalDuration),
            String(imageRenderDuration),
            String(pixelBufferDrawDuration),
            String(staticRenderDuration),
            String(dynamicRenderDuration),
            String(staticDrawDuration),
            String(dynamicDrawDuration),
            String(dynamicRenderAreaRatio),
            String(staticLayerCacheHitCount),
            String(dynamicRenderCount),
            String(appendDuration),
            String(writerWaitDuration),
            String(averageFrameDuration),
            renderPath.rawValue,
            String(dynamicRenderRectX),
            String(dynamicRenderRectY),
            String(dynamicRenderRectWidth),
            String(dynamicRenderRectHeight),
            String(dynamicOverlayCount),
            String(staticOverlayCount),
            String(fullFrameFallbackCount),
            String(renderDurationP50),
            String(renderDurationP95),
            String(renderDurationMax),
            String(drawDurationP50),
            String(drawDurationP95),
            String(drawDurationMax),
            String(frameDurationP50),
            String(frameDurationP95),
            String(frameDurationMax),
            String(slowFrameThreshold),
            String(slowFrameCount)
        ])
        let segmentRows = segments.map { segment in
            csvRow([
                "segment",
                String(segment.segmentIndex),
                segment.segmentName,
                segment.outputFileName,
                String(segment.duration),
                String(segment.frameCount),
                String(segment.renderedFrameCount),
                String(segment.reusedFrameCount),
                String(segment.reuseRate),
                String(segment.totalDuration),
                String(segment.imageRenderDuration),
                String(segment.pixelBufferDrawDuration),
                String(segment.staticRenderDuration),
                String(segment.dynamicRenderDuration),
                String(segment.staticDrawDuration),
                String(segment.dynamicDrawDuration),
                String(segment.dynamicRenderAreaRatio),
                String(segment.staticLayerCacheHitCount),
                String(segment.dynamicRenderCount),
                String(segment.appendDuration),
                String(segment.writerWaitDuration),
                String(segment.averageFrameDuration),
                segment.renderPath.rawValue,
                String(segment.dynamicRenderRectX),
                String(segment.dynamicRenderRectY),
                String(segment.dynamicRenderRectWidth),
                String(segment.dynamicRenderRectHeight),
                String(segment.dynamicOverlayCount),
                String(segment.staticOverlayCount),
                String(segment.fullFrameFallbackCount),
                String(segment.renderDurationP50),
                String(segment.renderDurationP95),
                String(segment.renderDurationMax),
                String(segment.drawDurationP50),
                String(segment.drawDurationP95),
                String(segment.drawDurationMax),
                String(segment.frameDurationP50),
                String(segment.frameDurationP95),
                String(segment.frameDurationMax),
                String(segment.slowFrameThreshold),
                String(segment.slowFrameCount)
            ])
        }
        return ([csvRow(header), summary] + segmentRows).joined(separator: "\n") + "\n"
    }

    private static func weightedAverage(_ values: [(TimeInterval, Int)]) -> TimeInterval {
        let totalWeight = values.map(\.1).reduce(0, +)
        guard totalWeight > 0 else {
            return 0
        }
        return values.map { $0.0 * Double($0.1) }.reduce(0, +) / Double(totalWeight)
    }

    private func csvRow(_ values: [String]) -> String {
        values.map { value in
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        .joined(separator: ",")
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
