import Foundation

enum IntervalTimelineMode: String, CaseIterable, Identifiable, Codable {
    case centeredWindow
    case fullSchedule

    var id: String { rawValue }

    var label: String {
        switch self {
        case .centeredWindow: "Centered"
        case .fullSchedule: "Full"
        }
    }
}

enum IntervalTimelineMarkerPosition: String, CaseIterable, Identifiable, Codable {
    case liveProgress
    case segmentCenter

    var id: String { rawValue }

    var label: String {
        switch self {
        case .liveProgress: "Progress"
        case .segmentCenter: "Center"
        }
    }
}

enum IntervalTimelineLabelMode: String, CaseIterable, Identifiable, Codable {
    case kind
    case distance

    var id: String { rawValue }

    var label: String {
        switch self {
        case .kind: "Kind"
        case .distance: "Distance"
        }
    }
}

struct IntervalTimelineStyle: Equatable, Codable {
    var width: Double
    var height: Double
    var mode: IntervalTimelineMode
    var visibleNeighbors: Int
    var maxFullSegments: Int
    var segmentHeight: Double
    var currentSegmentHeightScale: Double
    var minSegmentWidth: Double
    var segmentGap: Double
    var edgeFadeEnabled: Bool
    var currentProgressEnabled: Bool
    var markerEnabled: Bool
    var markerLabel: String
    var markerPosition: IntervalTimelineMarkerPosition
    var primaryLabelMode: IntervalTimelineLabelMode
    var durationLabelsEnabled: Bool
    var repCounterEnabled: Bool
    var overflowPillsEnabled: Bool
    var railEnabled: Bool
    var railSpacing: Double
    var railDotSize: Double
    var railColor: OverlayColor
    var railOpacity: Double
    var railLineColor: OverlayColor
    var railLineWidth: Double
    var warmupColor: OverlayColor
    var activeColor: OverlayColor
    var restColor: OverlayColor
    var cooldownColor: OverlayColor
    var unknownColor: OverlayColor
    var completedOpacity: Double
    var futureOpacity: Double

    static let `default` = IntervalTimelineStyle(
        width: 780,
        height: 64,
        mode: .centeredWindow,
        visibleNeighbors: 3,
        maxFullSegments: 12,
        segmentHeight: 30,
        currentSegmentHeightScale: 1.35,
        minSegmentWidth: 54,
        segmentGap: 4,
        edgeFadeEnabled: true,
        currentProgressEnabled: true,
        markerEnabled: true,
        markerLabel: "NOW",
        markerPosition: .liveProgress,
        primaryLabelMode: .distance,
        durationLabelsEnabled: true,
        repCounterEnabled: true,
        overflowPillsEnabled: true,
        railEnabled: true,
        railSpacing: 5,
        railDotSize: 5,
        railColor: .white,
        railOpacity: 0.36,
        railLineColor: OverlayColor(red: 0.42, green: 0.48, blue: 0.54, alpha: 1),
        railLineWidth: 5,
        warmupColor: .blue,
        activeColor: .orange,
        restColor: .green,
        cooldownColor: .purple,
        unknownColor: OverlayColor(red: 0.38, green: 0.44, blue: 0.52, alpha: 1),
        completedOpacity: 0.58,
        futureOpacity: 0.82
    )
}

struct IntervalTimelineRenderLayout: Equatable {
    var style: IntervalTimelineStyle
    var rect: CGRect
    var contentRect: CGRect
    var railY: Double
    var railDots: [CGPoint]
    var segments: [IntervalTimelineSegmentLayout]
    var leftOverflowCount: Int
    var rightOverflowCount: Int
    var currentProgress: Double
    var markerX: Double
    var markerLabel: String
    var repText: String?
    var labelFontSize: Double
    var durationFontSize: Double
    var pillFontSize: Double
    var ghostFontSize: Double
    var cornerRadius: Double
}

struct IntervalTimelineSegmentLayout: Identifiable, Equatable {
    var id: UUID
    var lapIndex: Int
    var rect: CGRect
    var label: String
    var durationText: String
    var kind: LapKind
    var color: OverlayColor
    var opacity: Double
    var isCurrent: Bool
    var isCompleted: Bool
}
