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

enum IntervalTimelineCurrentLabelMetricMode: String, CaseIterable, Identifiable, Codable {
    case hidden
    case elapsed
    case remaining

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hidden: "Off"
        case .elapsed: "Live"
        case .remaining: "Remain"
        }
    }
}

enum IntervalTimelineNeighborLabelMode: String, CaseIterable, Identifiable, Codable {
    case distance
    case time

    var id: String { rawValue }

    var label: String {
        switch self {
        case .distance: "Distance"
        case .time: "Time"
        }
    }
}

enum IntervalTimelineFullSegmentLayoutMode: String, CaseIterable, Identifiable, Codable {
    case equal
    case duration

    var id: String { rawValue }

    var label: String {
        switch self {
        case .equal: "Equal"
        case .duration: "Duration"
        }
    }
}

struct IntervalTimelineStyle: Equatable, Codable {
    var width: Double
    var height: Double
    var mode: IntervalTimelineMode
    var visibleNeighbors: Int
    var fullSegmentLayoutMode: IntervalTimelineFullSegmentLayoutMode
    var showsRestSegments: Bool
    var showsWarmupSegments: Bool
    var showsCooldownSegments: Bool
    var segmentHeight: Double
    var currentSegmentHeightScale: Double
    var currentSegmentWidthFraction: Double
    var fullEqualCurrentSegmentWidthFraction: Double
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
    var currentDistanceLabelMode: IntervalTimelineCurrentLabelMetricMode
    var currentTimeLabelMode: IntervalTimelineCurrentLabelMetricMode
    var neighborLabelMode: IntervalTimelineNeighborLabelMode
    var repCounterEnabled: Bool
    var overflowHintEnabled: Bool
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
        fullSegmentLayoutMode: .equal,
        showsRestSegments: true,
        showsWarmupSegments: true,
        showsCooldownSegments: true,
        segmentHeight: 30,
        currentSegmentHeightScale: 1.35,
        currentSegmentWidthFraction: 0.28,
        fullEqualCurrentSegmentWidthFraction: 0,
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
        currentDistanceLabelMode: .elapsed,
        currentTimeLabelMode: .remaining,
        neighborLabelMode: .distance,
        repCounterEnabled: true,
        overflowHintEnabled: true,
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
        fullSegmentLayoutMode: IntervalTimelineFullSegmentLayoutMode,
        showsRestSegments: Bool,
        showsWarmupSegments: Bool,
        showsCooldownSegments: Bool,
        segmentHeight: Double,
        currentSegmentHeightScale: Double,
        currentSegmentWidthFraction: Double,
        fullEqualCurrentSegmentWidthFraction: Double,
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
        currentDistanceLabelMode: IntervalTimelineCurrentLabelMetricMode,
        currentTimeLabelMode: IntervalTimelineCurrentLabelMetricMode,
        neighborLabelMode: IntervalTimelineNeighborLabelMode,
        repCounterEnabled: Bool,
        overflowHintEnabled: Bool,
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
        self.fullSegmentLayoutMode = fullSegmentLayoutMode
        self.showsRestSegments = showsRestSegments
        self.showsWarmupSegments = showsWarmupSegments
        self.showsCooldownSegments = showsCooldownSegments
        self.segmentHeight = segmentHeight
        self.currentSegmentHeightScale = currentSegmentHeightScale
        self.currentSegmentWidthFraction = currentSegmentWidthFraction
        self.fullEqualCurrentSegmentWidthFraction = fullEqualCurrentSegmentWidthFraction
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
        self.currentDistanceLabelMode = currentDistanceLabelMode
        self.currentTimeLabelMode = currentTimeLabelMode
        self.neighborLabelMode = neighborLabelMode
        self.repCounterEnabled = repCounterEnabled
        self.overflowHintEnabled = overflowHintEnabled
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
        fullSegmentLayoutMode = try c.decodeIfPresent(IntervalTimelineFullSegmentLayoutMode.self, forKey: .fullSegmentLayoutMode) ?? base.fullSegmentLayoutMode
        showsRestSegments = try c.decodeIfPresent(Bool.self, forKey: .showsRestSegments) ?? base.showsRestSegments
        showsWarmupSegments = try c.decodeIfPresent(Bool.self, forKey: .showsWarmupSegments) ?? base.showsWarmupSegments
        showsCooldownSegments = try c.decodeIfPresent(Bool.self, forKey: .showsCooldownSegments) ?? base.showsCooldownSegments
        _ = try c.decodeIfPresent(Int.self, forKey: .maxFullSegments)
        segmentHeight = try c.decodeIfPresent(Double.self, forKey: .segmentHeight) ?? base.segmentHeight
        currentSegmentHeightScale = try c.decodeIfPresent(Double.self, forKey: .currentSegmentHeightScale) ?? base.currentSegmentHeightScale
        currentSegmentWidthFraction = try c.decodeIfPresent(Double.self, forKey: .currentSegmentWidthFraction) ?? base.currentSegmentWidthFraction
        fullEqualCurrentSegmentWidthFraction = try c.decodeIfPresent(Double.self, forKey: .fullEqualCurrentSegmentWidthFraction) ?? base.fullEqualCurrentSegmentWidthFraction
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
        currentDistanceLabelMode = try c.decodeIfPresent(IntervalTimelineCurrentLabelMetricMode.self, forKey: .currentDistanceLabelMode) ?? base.currentDistanceLabelMode
        currentTimeLabelMode = try c.decodeIfPresent(IntervalTimelineCurrentLabelMetricMode.self, forKey: .currentTimeLabelMode) ?? base.currentTimeLabelMode
        neighborLabelMode = try c.decodeIfPresent(IntervalTimelineNeighborLabelMode.self, forKey: .neighborLabelMode) ?? base.neighborLabelMode
        _ = try c.decodeIfPresent(String.self, forKey: .primaryLabelMode)
        _ = try c.decodeIfPresent(Bool.self, forKey: .durationLabelsEnabled)
        repCounterEnabled = try c.decodeIfPresent(Bool.self, forKey: .repCounterEnabled) ?? base.repCounterEnabled
        overflowHintEnabled = try c.decodeIfPresent(Bool.self, forKey: .overflowHintEnabled)
            ?? c.decodeIfPresent(Bool.self, forKey: .overflowPillsEnabled)
            ?? base.overflowHintEnabled
        warmupColor = try c.decodeIfPresent(OverlayColor.self, forKey: .warmupColor) ?? base.warmupColor
        activeColor = try c.decodeIfPresent(OverlayColor.self, forKey: .activeColor) ?? base.activeColor
        restColor = try c.decodeIfPresent(OverlayColor.self, forKey: .restColor) ?? base.restColor
        cooldownColor = try c.decodeIfPresent(OverlayColor.self, forKey: .cooldownColor) ?? base.cooldownColor
        unknownColor = try c.decodeIfPresent(OverlayColor.self, forKey: .unknownColor) ?? base.unknownColor
        completedOpacity = try c.decodeIfPresent(Double.self, forKey: .completedOpacity) ?? base.completedOpacity
        futureOpacity = try c.decodeIfPresent(Double.self, forKey: .futureOpacity) ?? base.futureOpacity
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(width, forKey: .width)
        try c.encode(height, forKey: .height)
        try c.encode(mode, forKey: .mode)
        try c.encode(visibleNeighbors, forKey: .visibleNeighbors)
        try c.encode(fullSegmentLayoutMode, forKey: .fullSegmentLayoutMode)
        try c.encode(showsRestSegments, forKey: .showsRestSegments)
        try c.encode(showsWarmupSegments, forKey: .showsWarmupSegments)
        try c.encode(showsCooldownSegments, forKey: .showsCooldownSegments)
        try c.encode(segmentHeight, forKey: .segmentHeight)
        try c.encode(currentSegmentHeightScale, forKey: .currentSegmentHeightScale)
        try c.encode(currentSegmentWidthFraction, forKey: .currentSegmentWidthFraction)
        try c.encode(fullEqualCurrentSegmentWidthFraction, forKey: .fullEqualCurrentSegmentWidthFraction)
        try c.encode(minSegmentWidth, forKey: .minSegmentWidth)
        try c.encode(segmentGap, forKey: .segmentGap)
        try c.encode(segmentCornerRadius, forKey: .segmentCornerRadius)
        try c.encode(edgeFadeEnabled, forKey: .edgeFadeEnabled)
        try c.encode(currentProgressEnabled, forKey: .currentProgressEnabled)
        try c.encode(markerEnabled, forKey: .markerEnabled)
        try c.encode(markerLabel, forKey: .markerLabel)
        try c.encode(markerPosition, forKey: .markerPosition)
        try c.encode(markerColor, forKey: .markerColor)
        try c.encode(markerFontSize, forKey: .markerFontSize)
        try c.encode(markerFontWeight, forKey: .markerFontWeight)
        try c.encode(markerFontName, forKey: .markerFontName)
        try c.encode(currentDistanceLabelMode, forKey: .currentDistanceLabelMode)
        try c.encode(currentTimeLabelMode, forKey: .currentTimeLabelMode)
        try c.encode(neighborLabelMode, forKey: .neighborLabelMode)
        try c.encode(repCounterEnabled, forKey: .repCounterEnabled)
        try c.encode(overflowHintEnabled, forKey: .overflowHintEnabled)
        try c.encode(warmupColor, forKey: .warmupColor)
        try c.encode(activeColor, forKey: .activeColor)
        try c.encode(restColor, forKey: .restColor)
        try c.encode(cooldownColor, forKey: .cooldownColor)
        try c.encode(unknownColor, forKey: .unknownColor)
        try c.encode(completedOpacity, forKey: .completedOpacity)
        try c.encode(futureOpacity, forKey: .futureOpacity)
    }

    private enum CodingKeys: String, CodingKey {
        case width
        case height
        case mode
        case visibleNeighbors
        case maxFullSegments
        case fullSegmentLayoutMode
        case showsRestSegments
        case showsWarmupSegments
        case showsCooldownSegments
        case segmentHeight
        case currentSegmentHeightScale
        case currentSegmentWidthFraction
        case fullEqualCurrentSegmentWidthFraction
        case minSegmentWidth
        case segmentGap
        case segmentCornerRadius
        case edgeFadeEnabled
        case currentProgressEnabled
        case markerEnabled
        case markerLabel
        case markerPosition
        case markerColor
        case markerFontSize
        case markerFontWeight
        case markerFontName
        case currentDistanceLabelMode
        case currentTimeLabelMode
        case neighborLabelMode
        case primaryLabelMode
        case durationLabelsEnabled
        case repCounterEnabled
        case overflowHintEnabled
        case overflowPillsEnabled
        case warmupColor
        case activeColor
        case restColor
        case cooldownColor
        case unknownColor
        case completedOpacity
        case futureOpacity
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
    var cornerRadius: Double
    var overflowEllipsisInset: Double
}

struct IntervalTimelineSegmentLayout: Identifiable, Equatable {
    var id: UUID
    var lapIndex: Int
    var rect: CGRect
    var labelLines: [String]
    var kind: LapKind
    var color: OverlayColor
    var opacity: Double
    var isCurrent: Bool
    var isCompleted: Bool
}
