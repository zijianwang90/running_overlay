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
    var currentSegmentWidthFraction: Double
    var minSegmentWidth: Double
    var segmentGap: Double
    var segmentCornerRadius: Double
    var edgeFadeEnabled: Bool
    var currentProgressEnabled: Bool
    var markerEnabled: Bool
    var markerLabel: String
    var markerPosition: IntervalTimelineMarkerPosition
    var markerColor: OverlayColor
    var markerFontSize: Double
    var markerFontWeight: OverlayFontWeight
    var markerFontName: String
    var primaryLabelMode: IntervalTimelineLabelMode
    var durationLabelsEnabled: Bool
    var repCounterEnabled: Bool
    var overflowPillsEnabled: Bool
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
        currentSegmentWidthFraction: 0.28,
        minSegmentWidth: 54,
        segmentGap: 4,
        segmentCornerRadius: 6,
        edgeFadeEnabled: true,
        currentProgressEnabled: true,
        markerEnabled: true,
        markerLabel: "NOW",
        markerPosition: .liveProgress,
        markerColor: .white,
        markerFontSize: 11,
        markerFontWeight: .bold,
        markerFontName: "",
        primaryLabelMode: .distance,
        durationLabelsEnabled: true,
        repCounterEnabled: true,
        overflowPillsEnabled: true,
        warmupColor: .blue,
        activeColor: .orange,
        restColor: .green,
        cooldownColor: .purple,
        unknownColor: OverlayColor(red: 0.38, green: 0.44, blue: 0.52, alpha: 1),
        completedOpacity: 0.58,
        futureOpacity: 0.82
    )

    init(
        width: Double,
        height: Double,
        mode: IntervalTimelineMode,
        visibleNeighbors: Int,
        maxFullSegments: Int,
        segmentHeight: Double,
        currentSegmentHeightScale: Double,
        currentSegmentWidthFraction: Double,
        minSegmentWidth: Double,
        segmentGap: Double,
        segmentCornerRadius: Double,
        edgeFadeEnabled: Bool,
        currentProgressEnabled: Bool,
        markerEnabled: Bool,
        markerLabel: String,
        markerPosition: IntervalTimelineMarkerPosition,
        markerColor: OverlayColor,
        markerFontSize: Double,
        markerFontWeight: OverlayFontWeight,
        markerFontName: String,
        primaryLabelMode: IntervalTimelineLabelMode,
        durationLabelsEnabled: Bool,
        repCounterEnabled: Bool,
        overflowPillsEnabled: Bool,
        warmupColor: OverlayColor,
        activeColor: OverlayColor,
        restColor: OverlayColor,
        cooldownColor: OverlayColor,
        unknownColor: OverlayColor,
        completedOpacity: Double,
        futureOpacity: Double
    ) {
        self.width = width
        self.height = height
        self.mode = mode
        self.visibleNeighbors = visibleNeighbors
        self.maxFullSegments = maxFullSegments
        self.segmentHeight = segmentHeight
        self.currentSegmentHeightScale = currentSegmentHeightScale
        self.currentSegmentWidthFraction = currentSegmentWidthFraction
        self.minSegmentWidth = minSegmentWidth
        self.segmentGap = segmentGap
        self.segmentCornerRadius = segmentCornerRadius
        self.edgeFadeEnabled = edgeFadeEnabled
        self.currentProgressEnabled = currentProgressEnabled
        self.markerEnabled = markerEnabled
        self.markerLabel = markerLabel
        self.markerPosition = markerPosition
        self.markerColor = markerColor
        self.markerFontSize = markerFontSize
        self.markerFontWeight = markerFontWeight
        self.markerFontName = markerFontName
        self.primaryLabelMode = primaryLabelMode
        self.durationLabelsEnabled = durationLabelsEnabled
        self.repCounterEnabled = repCounterEnabled
        self.overflowPillsEnabled = overflowPillsEnabled
        self.warmupColor = warmupColor
        self.activeColor = activeColor
        self.restColor = restColor
        self.cooldownColor = cooldownColor
        self.unknownColor = unknownColor
        self.completedOpacity = completedOpacity
        self.futureOpacity = futureOpacity
    }

    init(from decoder: Decoder) throws {
        let base = Self.default
        let c = try decoder.container(keyedBy: CodingKeys.self)
        width = try c.decodeIfPresent(Double.self, forKey: .width) ?? base.width
        height = try c.decodeIfPresent(Double.self, forKey: .height) ?? base.height
        mode = try c.decodeIfPresent(IntervalTimelineMode.self, forKey: .mode) ?? base.mode
        visibleNeighbors = try c.decodeIfPresent(Int.self, forKey: .visibleNeighbors) ?? base.visibleNeighbors
        maxFullSegments = try c.decodeIfPresent(Int.self, forKey: .maxFullSegments) ?? base.maxFullSegments
        segmentHeight = try c.decodeIfPresent(Double.self, forKey: .segmentHeight) ?? base.segmentHeight
        currentSegmentHeightScale = try c.decodeIfPresent(Double.self, forKey: .currentSegmentHeightScale) ?? base.currentSegmentHeightScale
        currentSegmentWidthFraction = try c.decodeIfPresent(Double.self, forKey: .currentSegmentWidthFraction) ?? base.currentSegmentWidthFraction
        minSegmentWidth = try c.decodeIfPresent(Double.self, forKey: .minSegmentWidth) ?? base.minSegmentWidth
        segmentGap = try c.decodeIfPresent(Double.self, forKey: .segmentGap) ?? base.segmentGap
        segmentCornerRadius = try c.decodeIfPresent(Double.self, forKey: .segmentCornerRadius) ?? base.segmentCornerRadius
        edgeFadeEnabled = try c.decodeIfPresent(Bool.self, forKey: .edgeFadeEnabled) ?? base.edgeFadeEnabled
        currentProgressEnabled = try c.decodeIfPresent(Bool.self, forKey: .currentProgressEnabled) ?? base.currentProgressEnabled
        markerEnabled = try c.decodeIfPresent(Bool.self, forKey: .markerEnabled) ?? base.markerEnabled
        markerLabel = try c.decodeIfPresent(String.self, forKey: .markerLabel) ?? base.markerLabel
        markerPosition = try c.decodeIfPresent(IntervalTimelineMarkerPosition.self, forKey: .markerPosition) ?? base.markerPosition
        markerColor = try c.decodeIfPresent(OverlayColor.self, forKey: .markerColor) ?? base.markerColor
        markerFontSize = try c.decodeIfPresent(Double.self, forKey: .markerFontSize) ?? base.markerFontSize
        markerFontWeight = try c.decodeIfPresent(OverlayFontWeight.self, forKey: .markerFontWeight) ?? base.markerFontWeight
        markerFontName = try c.decodeIfPresent(String.self, forKey: .markerFontName) ?? base.markerFontName
        primaryLabelMode = try c.decodeIfPresent(IntervalTimelineLabelMode.self, forKey: .primaryLabelMode) ?? base.primaryLabelMode
        durationLabelsEnabled = try c.decodeIfPresent(Bool.self, forKey: .durationLabelsEnabled) ?? base.durationLabelsEnabled
        repCounterEnabled = try c.decodeIfPresent(Bool.self, forKey: .repCounterEnabled) ?? base.repCounterEnabled
        overflowPillsEnabled = try c.decodeIfPresent(Bool.self, forKey: .overflowPillsEnabled) ?? base.overflowPillsEnabled
        warmupColor = try c.decodeIfPresent(OverlayColor.self, forKey: .warmupColor) ?? base.warmupColor
        activeColor = try c.decodeIfPresent(OverlayColor.self, forKey: .activeColor) ?? base.activeColor
        restColor = try c.decodeIfPresent(OverlayColor.self, forKey: .restColor) ?? base.restColor
        cooldownColor = try c.decodeIfPresent(OverlayColor.self, forKey: .cooldownColor) ?? base.cooldownColor
        unknownColor = try c.decodeIfPresent(OverlayColor.self, forKey: .unknownColor) ?? base.unknownColor
        completedOpacity = try c.decodeIfPresent(Double.self, forKey: .completedOpacity) ?? base.completedOpacity
        futureOpacity = try c.decodeIfPresent(Double.self, forKey: .futureOpacity) ?? base.futureOpacity
    }
}

struct IntervalTimelineRenderLayout: Equatable {
    var style: IntervalTimelineStyle
    var rect: CGRect
    var contentRect: CGRect
    var segments: [IntervalTimelineSegmentLayout]
    var leftOverflowCount: Int
    var rightOverflowCount: Int
    var currentProgress: Double
    var markerX: Double
    var markerTopY: Double
    var markerTriangleHeight: Double
    var markerLabelHeight: Double
    var markerLabel: String
    var repText: String?
    var labelFontSize: Double
    var durationFontSize: Double
    var pillFontSize: Double
    var ghostFontSize: Double
    var cornerRadius: Double
    var overflowGhostInset: Double
    var overflowEllipsisInset: Double
    var overflowPillInset: Double
    var overflowPillSize: CGSize
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
