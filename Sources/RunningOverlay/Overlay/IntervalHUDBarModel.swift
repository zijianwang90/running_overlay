import Foundation

enum IntervalHUDBarBottomBarMode: String, CaseIterable, Identifiable, Codable {
    case none
    case lapProgress
    case heartRateZones
    case paceZones

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "None"
        case .lapProgress: "Lap Progress"
        case .heartRateZones: "HR Zones"
        case .paceZones: "Pace Zones"
        }
    }

    static var selectableCases: [IntervalHUDBarBottomBarMode] {
        [.lapProgress, .heartRateZones, .paceZones]
    }
}

enum IntervalHUDBarProgressMode: String, CaseIterable, Identifiable, Codable {
    case time
    case distance

    var id: String { rawValue }

    var label: String {
        switch self {
        case .time: "Time"
        case .distance: "Distance"
        }
    }
}

enum IntervalHUDBarHRDropMode: String, CaseIterable, Identifiable, Codable {
    case bpm
    case percent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bpm: "bpm"
        case .percent: "%"
        }
    }
}

enum IntervalHUDBarRemainingPrimary: String, CaseIterable, Identifiable, Codable {
    case time
    case distance

    var id: String { rawValue }

    var label: String {
        switch self {
        case .time: "Time"
        case .distance: "Distance"
        }
    }
}

enum IntervalHUDBarPhaseDetailMode: String, CaseIterable, Identifiable, Codable {
    case time
    case distance

    var id: String { rawValue }

    var label: String {
        switch self {
        case .time: "Time Left"
        case .distance: "Distance Left"
        }
    }
}

enum IntervalHUDBarZoneDisplayMode: String, CaseIterable, Identifiable, Codable {
    case heartRateZone
    case hrDropAtRest

    var id: String { rawValue }

    var label: String {
        switch self {
        case .heartRateZone: "HR Zone"
        case .hrDropAtRest: "HR Drop at Rest"
        }
    }
}

enum IntervalHUDBarZoneMarkerPosition: String, CaseIterable, Identifiable, Codable {
    case above
    case below

    var id: String { rawValue }

    var label: String {
        switch self {
        case .above: "Above"
        case .below: "Below"
        }
    }
}

enum IntervalHUDBarTypographyRole: String, CaseIterable, Identifiable, Codable {
    case labels
    case primaryValues
    case phase
    case phaseDetail
    case metricValues
    case metricUnits

    var id: String { rawValue }

    var label: String {
        switch self {
        case .labels: "Labels"
        case .primaryValues: "Primary Values"
        case .phase: "Phase"
        case .phaseDetail: "Phase Detail"
        case .metricValues: "Metric Values"
        case .metricUnits: "Metric Units"
        }
    }
}

enum IntervalHUDBarMetric: String, CaseIterable, Identifiable, Codable {
    case heartRateZone
    case heartRate
    case pace
    case calories
    case elapsedTime
    case realTime
    case distance
    case elevation
    case cadence
    case power
    case verticalOscillation
    case groundContactTime
    case strideLength
    case verticalRatio
    case groundContactBalance
    case temperature
    case grade
    case hrDrop

    var id: String { rawValue }

    var label: String {
        switch self {
        case .heartRateZone: "HR Zone"
        case .heartRate: "HR"
        case .pace: "Pace"
        case .calories: "Calories"
        case .elapsedTime: "Elapsed Time"
        case .realTime: "Real Time"
        case .distance: "Distance"
        case .elevation: "Elevation"
        case .cadence: "Cadence"
        case .power: "Power"
        case .verticalOscillation: "Vertical Oscillation"
        case .groundContactTime: "Ground Contact Time"
        case .strideLength: "Stride Length"
        case .verticalRatio: "Vertical Ratio"
        case .groundContactBalance: "GCT Balance"
        case .temperature: "Temperature"
        case .grade: "Grade"
        case .hrDrop: "HR Drop"
        }
    }

    var elementType: OverlayElementType? {
        switch self {
        case .heartRateZone, .hrDrop:
            nil
        case .heartRate:
            .heartRate
        case .pace:
            .pace
        case .calories:
            .calories
        case .elapsedTime:
            .elapsedTime
        case .realTime:
            .realTime
        case .distance:
            .distance
        case .elevation:
            .elevation
        case .cadence:
            .cadence
        case .power:
            .power
        case .verticalOscillation:
            .verticalOscillation
        case .groundContactTime:
            .groundContactTime
        case .strideLength:
            .strideLength
        case .verticalRatio:
            .verticalRatio
        case .groundContactBalance:
            .groundContactBalance
        case .temperature:
            .temperature
        case .grade:
            .grade
        }
    }

    static var numericCases: [IntervalHUDBarMetric] {
        allCases.filter { $0.elementType?.isNumericOverlay == true }
    }

    var defaultUnitOption: OverlayUnitOption {
        elementType?.defaultUnitOption ?? .bpm
    }

    var unitOptions: [OverlayUnitOption] {
        elementType.map(OverlayUnitOption.options(for:)) ?? []
    }
}

struct IntervalHUDBarMetricSlot: Identifiable, Equatable, Codable {
    var id = UUID()
    var metric: IntervalHUDBarMetric
    var unitOption: OverlayUnitOption

    init(metric: IntervalHUDBarMetric, unitOption: OverlayUnitOption? = nil) {
        self.metric = metric
        self.unitOption = unitOption ?? metric.defaultUnitOption
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        metric = try container.decode(IntervalHUDBarMetric.self, forKey: .metric)
        unitOption = try container.decodeIfPresent(OverlayUnitOption.self, forKey: .unitOption) ?? metric.defaultUnitOption
    }
}

struct IntervalHUDBarTextStyle: Equatable, Codable {
    var fontName: String
    var fontSize: Double
    var fontWeight: OverlayFontWeight
}

struct IntervalHUDBarStyle: Equatable, Codable {
    var width: Double
    var height: Double
    var bottomBarEnabled: Bool
    var bottomBarMode: IntervalHUDBarBottomBarMode
    var progressMode: IntervalHUDBarProgressMode
    var hrDropMode: IntervalHUDBarHRDropMode
    var remainingPrimary: IntervalHUDBarRemainingPrimary
    var showsRep: Bool
    var showsPhase: Bool
    var phaseDetailMode: IntervalHUDBarPhaseDetailMode
    var restPhaseDetailMode: IntervalHUDBarPhaseDetailMode
    var showsRemaining: Bool
    var showsZone: Bool
    var zoneDisplayMode: IntervalHUDBarZoneDisplayMode
    var metricSlots: [IntervalHUDBarMetricSlot]
    var phaseColorFallback: OverlayColor
    var trackColor: OverlayColor
    var trackOpacity: Double
    var bottomBarSpacing: Double
    var bottomBarGlowEnabled: Bool
    var bottomBarGlowIntensity: Double
    var activeZoneWidthShare: Double
    var activeZoneHeightScale: Double
    var zoneSegmentGap: Double
    var bottomBarCornerRadius: Double
    var inactiveZoneOpacity: Double
    var zoneMarkerEnabled: Bool
    var zoneMarkerPosition: IntervalHUDBarZoneMarkerPosition
    var zoneMarkerShowsValue: Bool
    var labelText: IntervalHUDBarTextStyle
    var primaryValueText: IntervalHUDBarTextStyle
    var phaseText: IntervalHUDBarTextStyle
    var phaseDetailText: IntervalHUDBarTextStyle
    var metricValueText: IntervalHUDBarTextStyle
    var metricUnitText: IntervalHUDBarTextStyle

    init(
        width: Double,
        height: Double,
        bottomBarEnabled: Bool,
        bottomBarMode: IntervalHUDBarBottomBarMode,
        progressMode: IntervalHUDBarProgressMode,
        hrDropMode: IntervalHUDBarHRDropMode,
        remainingPrimary: IntervalHUDBarRemainingPrimary,
        showsRep: Bool,
        showsPhase: Bool,
        phaseDetailMode: IntervalHUDBarPhaseDetailMode,
        restPhaseDetailMode: IntervalHUDBarPhaseDetailMode,
        showsRemaining: Bool,
        showsZone: Bool,
        zoneDisplayMode: IntervalHUDBarZoneDisplayMode,
        metricSlots: [IntervalHUDBarMetricSlot],
        phaseColorFallback: OverlayColor,
        trackColor: OverlayColor,
        trackOpacity: Double,
        bottomBarSpacing: Double,
        bottomBarGlowEnabled: Bool,
        bottomBarGlowIntensity: Double,
        activeZoneWidthShare: Double,
        activeZoneHeightScale: Double,
        zoneSegmentGap: Double,
        bottomBarCornerRadius: Double,
        inactiveZoneOpacity: Double,
        zoneMarkerEnabled: Bool,
        zoneMarkerPosition: IntervalHUDBarZoneMarkerPosition,
        zoneMarkerShowsValue: Bool,
        labelText: IntervalHUDBarTextStyle,
        primaryValueText: IntervalHUDBarTextStyle,
        phaseText: IntervalHUDBarTextStyle,
        phaseDetailText: IntervalHUDBarTextStyle,
        metricValueText: IntervalHUDBarTextStyle,
        metricUnitText: IntervalHUDBarTextStyle
    ) {
        self.width = width
        self.height = height
        self.bottomBarEnabled = bottomBarEnabled
        self.bottomBarMode = bottomBarMode
        self.progressMode = progressMode
        self.hrDropMode = hrDropMode
        self.remainingPrimary = remainingPrimary
        self.showsRep = showsRep
        self.showsPhase = showsPhase
        self.phaseDetailMode = phaseDetailMode
        self.restPhaseDetailMode = restPhaseDetailMode
        self.showsRemaining = showsRemaining
        self.showsZone = showsZone
        self.zoneDisplayMode = zoneDisplayMode
        self.metricSlots = metricSlots
        self.phaseColorFallback = phaseColorFallback
        self.trackColor = trackColor
        self.trackOpacity = trackOpacity
        self.bottomBarSpacing = bottomBarSpacing
        self.bottomBarGlowEnabled = bottomBarGlowEnabled
        self.bottomBarGlowIntensity = bottomBarGlowIntensity
        self.activeZoneWidthShare = activeZoneWidthShare
        self.activeZoneHeightScale = activeZoneHeightScale
        self.zoneSegmentGap = zoneSegmentGap
        self.bottomBarCornerRadius = bottomBarCornerRadius
        self.inactiveZoneOpacity = inactiveZoneOpacity
        self.zoneMarkerEnabled = zoneMarkerEnabled
        self.zoneMarkerPosition = zoneMarkerPosition
        self.zoneMarkerShowsValue = zoneMarkerShowsValue
        self.labelText = labelText
        self.primaryValueText = primaryValueText
        self.phaseText = phaseText
        self.phaseDetailText = phaseDetailText
        self.metricValueText = metricValueText
        self.metricUnitText = metricUnitText
    }

    init(from decoder: Decoder) throws {
        let defaults = Self.default
        let container = try decoder.container(keyedBy: CodingKeys.self)
        width = try container.decodeIfPresent(Double.self, forKey: .width) ?? defaults.width
        height = try container.decodeIfPresent(Double.self, forKey: .height) ?? defaults.height
        let decodedBottomBarMode = try container.decodeIfPresent(IntervalHUDBarBottomBarMode.self, forKey: .bottomBarMode) ?? defaults.bottomBarMode
        bottomBarEnabled = try container.decodeIfPresent(Bool.self, forKey: .bottomBarEnabled) ?? (decodedBottomBarMode != .none)
        bottomBarMode = decodedBottomBarMode == .none ? defaults.bottomBarMode : decodedBottomBarMode
        progressMode = try container.decodeIfPresent(IntervalHUDBarProgressMode.self, forKey: .progressMode) ?? defaults.progressMode
        hrDropMode = try container.decodeIfPresent(IntervalHUDBarHRDropMode.self, forKey: .hrDropMode) ?? defaults.hrDropMode
        remainingPrimary = try container.decodeIfPresent(IntervalHUDBarRemainingPrimary.self, forKey: .remainingPrimary) ?? defaults.remainingPrimary
        showsRep = try container.decodeIfPresent(Bool.self, forKey: .showsRep) ?? defaults.showsRep
        showsPhase = try container.decodeIfPresent(Bool.self, forKey: .showsPhase) ?? defaults.showsPhase
        phaseDetailMode = try container.decodeIfPresent(IntervalHUDBarPhaseDetailMode.self, forKey: .phaseDetailMode) ?? defaults.phaseDetailMode
        restPhaseDetailMode = try container.decodeIfPresent(IntervalHUDBarPhaseDetailMode.self, forKey: .restPhaseDetailMode) ?? defaults.restPhaseDetailMode
        showsRemaining = try container.decodeIfPresent(Bool.self, forKey: .showsRemaining) ?? defaults.showsRemaining
        showsZone = try container.decodeIfPresent(Bool.self, forKey: .showsZone) ?? defaults.showsZone
        zoneDisplayMode = try container.decodeIfPresent(IntervalHUDBarZoneDisplayMode.self, forKey: .zoneDisplayMode) ?? defaults.zoneDisplayMode
        let decodedMetricSlots = try container.decodeIfPresent([IntervalHUDBarMetricSlot].self, forKey: .metricSlots) ?? defaults.metricSlots
        metricSlots = decodedMetricSlots.filter { $0.metric.elementType?.isNumericOverlay == true }
        phaseColorFallback = try container.decodeIfPresent(OverlayColor.self, forKey: .phaseColorFallback) ?? defaults.phaseColorFallback
        trackColor = try container.decodeIfPresent(OverlayColor.self, forKey: .trackColor) ?? defaults.trackColor
        trackOpacity = try container.decodeIfPresent(Double.self, forKey: .trackOpacity) ?? defaults.trackOpacity
        bottomBarSpacing = try container.decodeIfPresent(Double.self, forKey: .bottomBarSpacing) ?? defaults.bottomBarSpacing
        bottomBarGlowEnabled = try container.decodeIfPresent(Bool.self, forKey: .bottomBarGlowEnabled) ?? defaults.bottomBarGlowEnabled
        bottomBarGlowIntensity = try container.decodeIfPresent(Double.self, forKey: .bottomBarGlowIntensity) ?? defaults.bottomBarGlowIntensity
        activeZoneWidthShare = try container.decodeIfPresent(Double.self, forKey: .activeZoneWidthShare) ?? defaults.activeZoneWidthShare
        activeZoneHeightScale = try container.decodeIfPresent(Double.self, forKey: .activeZoneHeightScale) ?? defaults.activeZoneHeightScale
        zoneSegmentGap = try container.decodeIfPresent(Double.self, forKey: .zoneSegmentGap) ?? defaults.zoneSegmentGap
        bottomBarCornerRadius = try container.decodeIfPresent(Double.self, forKey: .bottomBarCornerRadius) ?? defaults.bottomBarCornerRadius
        inactiveZoneOpacity = try container.decodeIfPresent(Double.self, forKey: .inactiveZoneOpacity) ?? defaults.inactiveZoneOpacity
        zoneMarkerEnabled = try container.decodeIfPresent(Bool.self, forKey: .zoneMarkerEnabled) ?? defaults.zoneMarkerEnabled
        zoneMarkerPosition = try container.decodeIfPresent(IntervalHUDBarZoneMarkerPosition.self, forKey: .zoneMarkerPosition) ?? defaults.zoneMarkerPosition
        zoneMarkerShowsValue = try container.decodeIfPresent(Bool.self, forKey: .zoneMarkerShowsValue) ?? defaults.zoneMarkerShowsValue
        labelText = try container.decodeIfPresent(IntervalHUDBarTextStyle.self, forKey: .labelText) ?? defaults.labelText
        primaryValueText = try container.decodeIfPresent(IntervalHUDBarTextStyle.self, forKey: .primaryValueText) ?? defaults.primaryValueText
        phaseText = try container.decodeIfPresent(IntervalHUDBarTextStyle.self, forKey: .phaseText) ?? defaults.phaseText
        phaseDetailText = try container.decodeIfPresent(IntervalHUDBarTextStyle.self, forKey: .phaseDetailText) ?? defaults.phaseDetailText
        metricValueText = try container.decodeIfPresent(IntervalHUDBarTextStyle.self, forKey: .metricValueText) ?? defaults.metricValueText
        metricUnitText = try container.decodeIfPresent(IntervalHUDBarTextStyle.self, forKey: .metricUnitText) ?? defaults.metricUnitText
    }

    static let `default` = IntervalHUDBarStyle(
        width: 760,
        height: 116,
        bottomBarEnabled: true,
        bottomBarMode: .lapProgress,
        progressMode: .distance,
        hrDropMode: .bpm,
        remainingPrimary: .time,
        showsRep: true,
        showsPhase: true,
        phaseDetailMode: .distance,
        restPhaseDetailMode: .distance,
        showsRemaining: true,
        showsZone: true,
        zoneDisplayMode: .hrDropAtRest,
        metricSlots: [
            IntervalHUDBarMetricSlot(metric: .heartRate),
            IntervalHUDBarMetricSlot(metric: .pace)
        ],
        phaseColorFallback: OverlayColor(red: 1, green: 0.38, blue: 0.14, alpha: 1),
        trackColor: .white,
        trackOpacity: 0.14,
        bottomBarSpacing: 10,
        bottomBarGlowEnabled: false,
        bottomBarGlowIntensity: 0.45,
        activeZoneWidthShare: 0,
        activeZoneHeightScale: 1,
        zoneSegmentGap: 2,
        bottomBarCornerRadius: 5,
        inactiveZoneOpacity: 0.55,
        zoneMarkerEnabled: true,
        zoneMarkerPosition: .above,
        zoneMarkerShowsValue: true,
        labelText: IntervalHUDBarTextStyle(fontName: FontLibraryManager.currentDefaultFamily, fontSize: 13, fontWeight: .bold),
        primaryValueText: IntervalHUDBarTextStyle(fontName: FontLibraryManager.currentDefaultFamily, fontSize: 34, fontWeight: .bold),
        phaseText: IntervalHUDBarTextStyle(fontName: FontLibraryManager.currentDefaultFamily, fontSize: 30, fontWeight: .bold),
        phaseDetailText: IntervalHUDBarTextStyle(fontName: FontLibraryManager.currentDefaultFamily, fontSize: 20, fontWeight: .semibold),
        metricValueText: IntervalHUDBarTextStyle(fontName: FontLibraryManager.currentDefaultFamily, fontSize: 20, fontWeight: .bold),
        metricUnitText: IntervalHUDBarTextStyle(fontName: FontLibraryManager.currentDefaultFamily, fontSize: 12, fontWeight: .semibold)
    )
}

struct HeartRateZoneSnapshot: Equatable {
    var zoneCount: Int
    var paceUnit: PaceUnit
    var zones: [HeartRateZone]

    static let empty = HeartRateZoneSnapshot(
        zoneCount: 5,
        paceUnit: .minPerKm,
        zones: HeartRateZone.emptySlots()
    )
}

struct IntervalHUDBarRenderLayout {
    var style: IntervalHUDBarStyle
    var rect: CGRect
    var phaseLabel: String
    var phaseDetail: String
    var phaseColor: OverlayColor
    var repText: String
    var remainingTimeText: String
    var remainingDistanceText: String
    var remainingPrimaryLabel: String
    var remainingPrimaryText: String
    var remainingSecondaryText: String
    var progress: Double
    var zoneItem: IntervalHUDBarMetricItem?
    var metricItems: [IntervalHUDBarMetricItem]
    var zoneSegments: [IntervalHUDBarZoneSegment]
    var activeZoneIndex: Int?
    var bottomBarActiveZoneIndex: Int?
    var zoneMarker: IntervalHUDBarZoneMarker?
    var labelText: IntervalHUDBarTextStyle
    var primaryValueText: IntervalHUDBarTextStyle
    var phaseText: IntervalHUDBarTextStyle
    var phaseDetailText: IntervalHUDBarTextStyle
    var metricValueText: IntervalHUDBarTextStyle
    var metricUnitText: IntervalHUDBarTextStyle
    var barHeight: Double
}

struct IntervalHUDBarMetricItem: Identifiable, Equatable {
    var id = UUID()
    var metric: IntervalHUDBarMetric
    var label: String
    var value: String
    var unit: String
    var accentColor: OverlayColor?
}

struct IntervalHUDBarZoneSegment: Identifiable, Equatable {
    var id = UUID()
    var index: Int
    var label: String
    var color: OverlayColor
}

struct IntervalHUDBarZoneMarker: Equatable {
    var zoneIndex: Int
    var fractionInZone: Double
    var valueText: String
    var color: OverlayColor
}

struct IntervalHUDBarZoneSegmentFrame: Equatable {
    var index: Int
    var start: Double
    var width: Double
}
