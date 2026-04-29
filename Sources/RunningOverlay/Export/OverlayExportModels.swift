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
