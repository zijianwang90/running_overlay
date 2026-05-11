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
    var appendDuration: TimeInterval
    var writerWaitDuration: TimeInterval
    var averageFrameDuration: TimeInterval
}

struct OverlayExportProfile: Codable, Equatable {
    var schemaVersion = 1
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
    var appendDuration: TimeInterval
    var writerWaitDuration: TimeInterval
    var averageFrameDuration: TimeInterval
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
        self.totalDuration = segments.map(\.totalDuration).reduce(0, +)
        self.imageRenderDuration = segments.map(\.imageRenderDuration).reduce(0, +)
        self.pixelBufferDrawDuration = segments.map(\.pixelBufferDrawDuration).reduce(0, +)
        self.appendDuration = segments.map(\.appendDuration).reduce(0, +)
        self.writerWaitDuration = segments.map(\.writerWaitDuration).reduce(0, +)
        self.averageFrameDuration = totalFrameCount > 0 ? self.totalDuration / Double(totalFrameCount) : 0
        self.segments = segments
    }

    func csvString() -> String {
        let header = [
            "rowType", "segmentIndex", "segmentName", "outputFileName", "duration", "frameCount",
            "renderedFrameCount", "reusedFrameCount", "reuseRate", "totalDuration",
            "imageRenderDuration", "pixelBufferDrawDuration", "appendDuration",
            "writerWaitDuration", "averageFrameDuration"
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
            String(appendDuration),
            String(writerWaitDuration),
            String(averageFrameDuration)
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
                String(segment.appendDuration),
                String(segment.writerWaitDuration),
                String(segment.averageFrameDuration)
            ])
        }
        return ([csvRow(header), summary] + segmentRows).joined(separator: "\n") + "\n"
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
