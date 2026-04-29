import Foundation

struct OverlayLayout: Equatable {
    var elements: [OverlayElement]

    static let empty = OverlayLayout(elements: [])
}

struct OverlayElement: Identifiable, Equatable {
    let id = UUID()
    var type: OverlayElementType
    var position: CGPoint
    var scale: Double
    var isVisible: Bool = true
    var isLocked: Bool = false
    var style: OverlayStyle
}

enum OverlayPasteCategory: String, Equatable {
    case numeric
    case distanceTimeline
    case elevationChart
    case runningGauge
    case routeMap
    case lapList
    case lapCard
    case lapLive
}

enum OverlayElementType: String, CaseIterable, Identifiable, Codable {
    case heartRate
    case pace
    case calories
    case elapsedTime
    case realTime
    case distance
    case distanceTimeline
    case elevation
    case elevationChart
    case cadence
    case power
    case runningGauge
    case routeMap
    case lapList
    case lapCard
    case lapLive
    case verticalOscillation
    case groundContactTime
    case strideLength
    case verticalRatio
    case groundContactBalance
    case temperature
    case grade

    var id: String { rawValue }

    var label: String {
        switch self {
        case .heartRate: "Heart Rate"
        case .pace: "Pace"
        case .calories: "Calories"
        case .elapsedTime: "Elapsed Time"
        case .realTime: "Real Time"
        case .distance: "Distance"
        case .distanceTimeline: "Distance Timeline"
        case .elevation: "Elevation"
        case .elevationChart: "Elevation Chart"
        case .cadence: "Cadence"
        case .power: "Power"
        case .runningGauge: "Running Gauge"
        case .routeMap: "Route Map"
        case .lapList: "Lap List"
        case .lapCard: "Lap Card"
        case .lapLive: "Lap Live"
        case .verticalOscillation: "Vertical Oscillation"
        case .groundContactTime: "Ground Contact Time"
        case .strideLength: "Stride Length"
        case .verticalRatio: "Vertical Ratio"
        case .groundContactBalance: "GCT Balance"
        case .temperature: "Temperature"
        case .grade: "Grade"
        }
    }

    var supportsTextPresets: Bool {
        switch self {
        case .distanceTimeline, .elevationChart, .runningGauge, .routeMap, .lapList, .lapCard, .lapLive:
            false
        default:
            true
        }
    }

    /// Numeric Overlay template applies to type-derived metric overlays only.
    /// See `docs/design/overlays/numeric/numeric-overlay-ui.md`.
    var isNumericOverlay: Bool {
        switch self {
        case .heartRate, .pace, .calories, .elapsedTime, .realTime,
             .distance, .elevation, .cadence, .power,
             .verticalOscillation, .groundContactTime, .strideLength,
             .verticalRatio, .groundContactBalance, .temperature, .grade:
            true
        default:
            false
        }
    }

    var defaultUnitOption: OverlayUnitOption {
        OverlayUnitOption.defaultOption(for: self)
    }

    /// Recommended numeric overlay style preset when adding a new element of
    /// this type. See `docs/design/overlays/numeric/numeric-overlay-ui.md`.
    var defaultNumericPreset: OverlayTextPreset? {
        isNumericOverlay ? .minimal : nil
    }

    var pasteCategory: OverlayPasteCategory {
        if isNumericOverlay {
            return .numeric
        }
        switch self {
        case .distanceTimeline:
            return .distanceTimeline
        case .elevationChart:
            return .elevationChart
        case .runningGauge:
            return .runningGauge
        case .routeMap:
            return .routeMap
        case .lapList:
            return .lapList
        case .lapCard:
            return .lapCard
        case .lapLive:
            return .lapLive
        default:
            return .numeric
        }
    }
}

enum OverlayUnitOption: String, CaseIterable, Identifiable, Codable {
    case bpm
    case paceMetric
    case paceImperial
    case paceRowing
    case distanceKilometers
    case distanceMiles
    case distanceMeters
    case elevationMeters
    case elevationFeet
    case watts
    case spm
    case kcal
    case durationHMS
    case durationMS
    case durationSeconds
    case clock24Hour
    case clock12Hour
    case oscillationMillimeters
    case oscillationCentimeters
    case contactTimeMilliseconds
    case strideLengthMeters
    case verticalRatioPercent
    case balancePercent
    case temperatureCelsius
    case temperatureFahrenheit
    case gradePercent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bpm: "bpm"
        case .paceMetric: "Metric (min/km)"
        case .paceImperial: "Imperial (min/mi)"
        case .paceRowing: "Rowing (min/500m)"
        case .distanceKilometers: "Metric (km)"
        case .distanceMiles: "Imperial (mi)"
        case .distanceMeters: "Meters (m)"
        case .elevationMeters: "Metric (m)"
        case .elevationFeet: "Imperial (ft)"
        case .watts: "watts"
        case .spm: "spm"
        case .kcal: "kcal"
        case .durationHMS: "hh:mm:ss"
        case .durationMS: "mm:ss"
        case .durationSeconds: "seconds"
        case .clock24Hour: "24-hour"
        case .clock12Hour: "12-hour"
        case .oscillationMillimeters: "Millimeters (mm)"
        case .oscillationCentimeters: "Centimeters (cm)"
        case .contactTimeMilliseconds: "Milliseconds (ms)"
        case .strideLengthMeters: "Meters (m)"
        case .verticalRatioPercent: "Percent (%)"
        case .balancePercent: "L/R %"
        case .temperatureCelsius: "Celsius (°C)"
        case .temperatureFahrenheit: "Fahrenheit (°F)"
        case .gradePercent: "Percent (%)"
        }
    }

    static func options(for type: OverlayElementType) -> [OverlayUnitOption] {
        switch type {
        case .heartRate: [.bpm]
        case .pace: [.paceMetric, .paceImperial, .paceRowing]
        case .distance: [.distanceKilometers, .distanceMiles, .distanceMeters]
        case .elevation: [.elevationMeters, .elevationFeet]
        case .power: [.watts]
        case .cadence: [.spm]
        case .calories: [.kcal]
        case .elapsedTime: [.durationHMS, .durationMS, .durationSeconds]
        case .realTime: [.clock24Hour, .clock12Hour]
        case .verticalOscillation: [.oscillationCentimeters, .oscillationMillimeters]
        case .groundContactTime: [.contactTimeMilliseconds]
        case .strideLength: [.strideLengthMeters]
        case .verticalRatio: [.verticalRatioPercent]
        case .groundContactBalance: [.balancePercent]
        case .temperature: [.temperatureCelsius, .temperatureFahrenheit]
        case .grade: [.gradePercent]
        case .distanceTimeline, .elevationChart, .runningGauge, .routeMap, .lapList, .lapCard, .lapLive:
            []
        }
    }

    static func defaultOption(for type: OverlayElementType) -> OverlayUnitOption {
        options(for: type).first ?? .bpm
    }
}

enum OverlayTextAlignment: String, CaseIterable, Identifiable, Codable {
    case leading
    case center
    case trailing

    var id: String { rawValue }

    var label: String {
        switch self {
        case .leading: "Left"
        case .center: "Center"
        case .trailing: "Right"
        }
    }

    var systemImage: String {
        switch self {
        case .leading: "text.alignleft"
        case .center: "text.aligncenter"
        case .trailing: "text.alignright"
        }
    }
}

enum OverlayTextAttachmentPosition: String, CaseIterable, Identifiable, Codable {
    case top
    case bottom
    case leading
    case trailing

    var id: String { rawValue }

    var label: String {
        switch self {
        case .top: "Top"
        case .bottom: "Bottom"
        case .leading: "Left"
        case .trailing: "Right"
        }
    }
}

struct OverlayStyle: Equatable, Codable {
    var textPreset: OverlayTextPreset
    var gaugePreset: OverlayGaugePreset
    var routeMapPreset: OverlayRouteMapPreset
    var routeMapProvider: OverlayRouteMapProvider
    var routeMapShape: OverlayRouteMapShape
    var routeMapEdgeFade: OverlayRouteMapEdgeFade
    var routeMapFadeAmount: Double
    var routeMapColorMode: OverlayRouteMapColorMode
    var routeMapGradientStart: OverlayColor
    var routeMapGradientMiddle: OverlayColor
    var routeMapGradientEnd: OverlayColor
    var routeMapMarkerStyle: OverlayRouteMapMarkerStyle
    var routeMapStartMarkerStyle: OverlayRouteMapMarkerStyle
    var routeMapEndMarkerStyle: OverlayRouteMapMarkerStyle
    var routeMapRunnerDotColor: OverlayColor
    var routeMapBackgroundStyle: OverlayRouteMapBackgroundStyle
    var routeMapLegendVisible: Bool
    var routeMapLegendMode: OverlayRouteMapLegendMode
    /// Container visual preset (Square / Circle × Hard / Gradient edge).
    /// Selecting a preset writes the bundled defaults onto the other route
    /// map fields. See `docs/design/overlays/route-map/route-map-overlay-ui.md` for the table of
    /// values each preset applies.
    var routeMapContainerPreset: OverlayRouteMapContainerPreset
    /// Alpha applied to the map snapshot only (route line, markers, and
    /// legend stay opaque). 0.0 hides the map background, 1.0 draws it at
    /// full opacity.
    var routeMapMapOpacity: Double
    /// Whether to draw the subtle border stroke around the container when not
    /// selected. The selection-state border is always shown as a UI affordance.
    var routeMapBorderVisible: Bool
    /// Container width in design units (before `element.scale` and project
    /// DPR multipliers are applied). Used by both shapes; for `.circle` the
    /// renderer takes the smaller of width / height as the diameter.
    var routeMapWidth: Double
    /// Container height in design units (before `element.scale` and project
    /// DPR multipliers are applied).
    var routeMapHeight: Double
    /// Corner radius for `.square` containers in design units. `0` = sharp
    /// corners. Circle containers ignore this value.
    var routeMapCornerRadius: Double
    var fontName: String
    var fontSize: Double
    var fontWeight: OverlayFontWeight
    var foregroundColor: OverlayColor
    var valueColor: OverlayColor
    var valueOpacity: Double
    var labelColor: OverlayColor
    var labelOpacity: Double
    var unitColor: OverlayColor
    var unitOpacity: Double
    var backgroundOpacity: Double
    var shadowOpacity: Double
    var shadowRadius: Double

    // Numeric Overlay additions (see docs/design/overlays/numeric/numeric-overlay-ui.md)
    var unitOption: OverlayUnitOption
    var showLabel: Bool
    var showUnit: Bool
    var customLabel: String
    var labelPosition: OverlayTextAttachmentPosition
    var unitPosition: OverlayTextAttachmentPosition
    var labelFontName: String
    var labelFontSize: Double
    var labelFontWeight: OverlayFontWeight
    var labelSpacing: Double
    var unitFontName: String
    var unitFontSize: Double
    var unitFontWeight: OverlayFontWeight
    var unitSpacing: Double
    var rotationDegrees: Double
    var textAlignment: OverlayTextAlignment
    var accentColor: OverlayColor
    var backgroundEnabled: Bool
    var backgroundColor: OverlayColor
    var backgroundRadius: Double
    var backgroundPaddingX: Double
    var backgroundPaddingY: Double
    var backgroundFadeOutEnabled: Bool
    var backgroundFadeOutAmount: Double
    var backgroundBlurRadius: Double
    var shadowEnabled: Bool
    var shadowOffsetX: Double
    var shadowOffsetY: Double

    /// Distance Timeline configuration. Used only by `.distanceTimeline`.
    /// See `docs/overlay-modules/distance-timeline-overlay.md`.
    var distanceTimeline: DistanceTimelineStyle

    /// Elevation Chart configuration. Used only by `.elevationChart`.
    /// See `docs/design/overlays/elevation-chart/elevation-chart-overlay-ui.md`.
    var elevationChart: ElevationChartStyle

    /// Running Gauge style. Used only by overlays of type `.runningGauge` —
    /// safely ignored otherwise. Stored as a sub-struct so the gauge can grow
    /// dial / ring / tick / region settings without polluting the rest of the
    /// overlay style namespace. See `Sources/RunningOverlay/Overlay/RunningGaugeModel.swift`.
    var gauge: RunningGaugeStyle

    /// Stats bar attached below the route map container. Visible = false by
    /// default so existing projects are unaffected.
    var routeMapStatsBar: OverlayRouteMapStatsBarConfig

    /// Lap list overlay configuration. Only used by `.lapList` elements.
    var lapList: LapListStyle

    /// Lap card overlay configuration. Only used by `.lapCard` elements.
    var lapCard: LapCardStyle

    /// Lap live overlay configuration. Only used by `.lapLive` elements.
    var lapLive: LapLiveStyle

    static let `default` = OverlayStyle(
        textPreset: .minimal,
        gaugePreset: .minimalSport,
        routeMapPreset: .minimal,
        routeMapProvider: .none,
        routeMapShape: .square,
        routeMapEdgeFade: .solid,
        routeMapFadeAmount: 0.22,
        routeMapColorMode: .solid,
        routeMapGradientStart: .green,
        routeMapGradientMiddle: .yellow,
        routeMapGradientEnd: .red,
        routeMapMarkerStyle: .dot,
        routeMapStartMarkerStyle: .dot,
        routeMapEndMarkerStyle: .dot,
        routeMapRunnerDotColor: .white,
        routeMapBackgroundStyle: .dark,
        routeMapLegendVisible: true,
        routeMapLegendMode: .startFinishDistance,
        routeMapContainerPreset: .squareHardEdge,
        routeMapMapOpacity: 0.72,
        routeMapBorderVisible: true,
        routeMapWidth: 320,
        routeMapHeight: 240,
        routeMapCornerRadius: 12,
        fontName: "SF Pro",
        fontSize: 28,
        fontWeight: .semibold,
        foregroundColor: .white,
        valueColor: .white,
        valueOpacity: 1,
        labelColor: .white,
        labelOpacity: 1,
        unitColor: .white,
        unitOpacity: 1,
        backgroundOpacity: 0.22,
        shadowOpacity: 0.35,
        shadowRadius: 4,
        unitOption: .paceMetric,
        showLabel: false,
        showUnit: true,
        customLabel: "",
        labelPosition: .top,
        unitPosition: .trailing,
        labelFontName: "SF Pro",
        labelFontSize: 16,
        labelFontWeight: .medium,
        labelSpacing: 8,
        unitFontName: "SF Pro",
        unitFontSize: 20,
        unitFontWeight: .medium,
        unitSpacing: 8,
        rotationDegrees: 0,
        textAlignment: .leading,
        accentColor: .blue,
        backgroundEnabled: true,
        backgroundColor: .black,
        backgroundRadius: 6,
        backgroundPaddingX: 10,
        backgroundPaddingY: 6,
        backgroundFadeOutEnabled: false,
        backgroundFadeOutAmount: 0.22,
        backgroundBlurRadius: 0,
        shadowEnabled: true,
        shadowOffsetX: 0,
        shadowOffsetY: 2,
        distanceTimeline: .default,
        elevationChart: .default,
        gauge: RunningGaugeStyle.default,
        routeMapStatsBar: .default,
        lapList: .default,
        lapCard: .default,
        lapLive: .default
    )

    init(
        textPreset: OverlayTextPreset = .minimal,
        gaugePreset: OverlayGaugePreset = .minimalSport,
        routeMapPreset: OverlayRouteMapPreset = .minimal,
        routeMapProvider: OverlayRouteMapProvider = .none,
        routeMapShape: OverlayRouteMapShape = .square,
        routeMapEdgeFade: OverlayRouteMapEdgeFade = .solid,
        routeMapFadeAmount: Double = 0.22,
        routeMapColorMode: OverlayRouteMapColorMode = .solid,
        routeMapGradientStart: OverlayColor = .green,
        routeMapGradientMiddle: OverlayColor = .yellow,
        routeMapGradientEnd: OverlayColor = .red,
        routeMapMarkerStyle: OverlayRouteMapMarkerStyle = .dot,
        routeMapStartMarkerStyle: OverlayRouteMapMarkerStyle = .dot,
        routeMapEndMarkerStyle: OverlayRouteMapMarkerStyle = .dot,
        routeMapRunnerDotColor: OverlayColor = .white,
        routeMapBackgroundStyle: OverlayRouteMapBackgroundStyle = .dark,
        routeMapLegendVisible: Bool = true,
        routeMapLegendMode: OverlayRouteMapLegendMode = .startFinishDistance,
        routeMapContainerPreset: OverlayRouteMapContainerPreset = .squareHardEdge,
        routeMapMapOpacity: Double = 0.72,
        routeMapBorderVisible: Bool = true,
        routeMapWidth: Double = 320,
        routeMapHeight: Double = 240,
        routeMapCornerRadius: Double = 12,
        fontName: String,
        fontSize: Double,
        fontWeight: OverlayFontWeight,
        foregroundColor: OverlayColor,
        valueColor: OverlayColor = .white,
        valueOpacity: Double = 1,
        labelColor: OverlayColor = .white,
        labelOpacity: Double = 1,
        unitColor: OverlayColor = .white,
        unitOpacity: Double = 1,
        backgroundOpacity: Double,
        shadowOpacity: Double,
        shadowRadius: Double,
        unitOption: OverlayUnitOption = .paceMetric,
        showLabel: Bool = false,
        showUnit: Bool = true,
        customLabel: String = "",
        labelPosition: OverlayTextAttachmentPosition = .top,
        unitPosition: OverlayTextAttachmentPosition = .trailing,
        labelFontName: String = "SF Pro",
        labelFontSize: Double = 16,
        labelFontWeight: OverlayFontWeight = .medium,
        labelSpacing: Double = 8,
        unitFontName: String = "SF Pro",
        unitFontSize: Double = 20,
        unitFontWeight: OverlayFontWeight = .medium,
        unitSpacing: Double = 8,
        rotationDegrees: Double = 0,
        textAlignment: OverlayTextAlignment = .leading,
        accentColor: OverlayColor = .blue,
        backgroundEnabled: Bool = true,
        backgroundColor: OverlayColor = .black,
        backgroundRadius: Double = 6,
        backgroundPaddingX: Double = 10,
        backgroundPaddingY: Double = 6,
        backgroundFadeOutEnabled: Bool = false,
        backgroundFadeOutAmount: Double = 0.22,
        backgroundBlurRadius: Double = 0,
        shadowEnabled: Bool = true,
        shadowOffsetX: Double = 0,
        shadowOffsetY: Double = 2,
        distanceTimeline: DistanceTimelineStyle = .default,
        elevationChart: ElevationChartStyle = .default,
        gauge: RunningGaugeStyle = .default,
        routeMapStatsBar: OverlayRouteMapStatsBarConfig = .default,
        lapList: LapListStyle = .default,
        lapCard: LapCardStyle = .default,
        lapLive: LapLiveStyle = .default
    ) {
        self.textPreset = textPreset
        self.gaugePreset = gaugePreset
        self.routeMapPreset = routeMapPreset
        self.routeMapProvider = routeMapProvider
        self.routeMapShape = routeMapShape
        self.routeMapEdgeFade = routeMapEdgeFade
        self.routeMapFadeAmount = routeMapFadeAmount
        self.routeMapColorMode = routeMapColorMode
        self.routeMapGradientStart = routeMapGradientStart
        self.routeMapGradientMiddle = routeMapGradientMiddle
        self.routeMapGradientEnd = routeMapGradientEnd
        self.routeMapMarkerStyle = routeMapMarkerStyle
        self.routeMapStartMarkerStyle = routeMapStartMarkerStyle
        self.routeMapEndMarkerStyle = routeMapEndMarkerStyle
        self.routeMapRunnerDotColor = routeMapRunnerDotColor
        self.routeMapBackgroundStyle = routeMapBackgroundStyle
        self.routeMapLegendVisible = routeMapLegendVisible
        self.routeMapLegendMode = routeMapLegendMode
        self.routeMapContainerPreset = routeMapContainerPreset
        self.routeMapMapOpacity = min(max(routeMapMapOpacity, 0), 1)
        self.routeMapBorderVisible = routeMapBorderVisible
        self.routeMapWidth = min(max(routeMapWidth, 80), 1200)
        self.routeMapHeight = min(max(routeMapHeight, 80), 1200)
        self.routeMapCornerRadius = min(max(routeMapCornerRadius, 0), 120)
        self.fontName = fontName
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.foregroundColor = foregroundColor
        self.valueColor = valueColor
        self.valueOpacity = min(max(valueOpacity, 0), 1)
        self.labelColor = labelColor
        self.labelOpacity = min(max(labelOpacity, 0), 1)
        self.unitColor = unitColor
        self.unitOpacity = min(max(unitOpacity, 0), 1)
        self.backgroundOpacity = backgroundOpacity
        self.shadowOpacity = shadowOpacity
        self.shadowRadius = shadowRadius
        self.unitOption = unitOption
        self.showLabel = showLabel
        self.showUnit = showUnit
        self.customLabel = customLabel
        self.labelPosition = labelPosition
        self.unitPosition = unitPosition
        self.labelFontName = labelFontName
        self.labelFontSize = labelFontSize
        self.labelFontWeight = labelFontWeight
        self.labelSpacing = max(labelSpacing, 0)
        self.unitFontName = unitFontName
        self.unitFontSize = unitFontSize
        self.unitFontWeight = unitFontWeight
        self.unitSpacing = max(unitSpacing, 0)
        self.rotationDegrees = rotationDegrees
        self.textAlignment = textAlignment
        self.accentColor = accentColor
        self.backgroundEnabled = backgroundEnabled
        self.backgroundColor = backgroundColor
        self.backgroundRadius = backgroundRadius
        self.backgroundPaddingX = backgroundPaddingX
        self.backgroundPaddingY = backgroundPaddingY
        self.backgroundFadeOutEnabled = backgroundFadeOutEnabled
        self.backgroundFadeOutAmount = backgroundFadeOutAmount
        self.backgroundBlurRadius = backgroundBlurRadius
        self.shadowEnabled = shadowEnabled
        self.shadowOffsetX = shadowOffsetX
        self.shadowOffsetY = shadowOffsetY
        self.distanceTimeline = distanceTimeline
        self.elevationChart = elevationChart
        self.gauge = gauge
        self.routeMapStatsBar = routeMapStatsBar
        self.lapList = lapList
        self.lapCard = lapCard
        self.lapLive = lapLive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        textPreset = try container.decodeIfPresent(OverlayTextPreset.self, forKey: .textPreset) ?? Self.default.textPreset
        gaugePreset = try container.decodeIfPresent(OverlayGaugePreset.self, forKey: .gaugePreset) ?? Self.default.gaugePreset
        // Legacy templates may have stored `routeMapPreset = "mapKit"` when
        // the preset enum doubled as a "show map" trigger. We migrate any
        // unknown raw value (including "mapKit") to `.gradient`, and rely on
        // `routeMapBackgroundStyle` to drive map visibility going forward.
        if let raw = try container.decodeIfPresent(String.self, forKey: .routeMapPreset),
           let preset = OverlayRouteMapPreset(rawValue: raw) {
            routeMapPreset = preset
        } else {
            routeMapPreset = Self.default.routeMapPreset
        }
        routeMapProvider = try container.decodeIfPresent(OverlayRouteMapProvider.self, forKey: .routeMapProvider) ?? Self.default.routeMapProvider
        routeMapShape = try container.decodeIfPresent(OverlayRouteMapShape.self, forKey: .routeMapShape) ?? Self.default.routeMapShape
        routeMapEdgeFade = try container.decodeIfPresent(OverlayRouteMapEdgeFade.self, forKey: .routeMapEdgeFade) ?? Self.default.routeMapEdgeFade
        routeMapFadeAmount = min(max(try container.decodeIfPresent(Double.self, forKey: .routeMapFadeAmount) ?? Self.default.routeMapFadeAmount, 0), 0.45)
        routeMapColorMode = try container.decodeIfPresent(OverlayRouteMapColorMode.self, forKey: .routeMapColorMode) ?? Self.default.routeMapColorMode
        routeMapGradientStart = try container.decodeIfPresent(OverlayColor.self, forKey: .routeMapGradientStart) ?? Self.default.routeMapGradientStart
        routeMapGradientMiddle = try container.decodeIfPresent(OverlayColor.self, forKey: .routeMapGradientMiddle) ?? Self.default.routeMapGradientMiddle
        routeMapGradientEnd = try container.decodeIfPresent(OverlayColor.self, forKey: .routeMapGradientEnd) ?? Self.default.routeMapGradientEnd
        routeMapMarkerStyle = try container.decodeIfPresent(OverlayRouteMapMarkerStyle.self, forKey: .routeMapMarkerStyle) ?? Self.default.routeMapMarkerStyle
        routeMapStartMarkerStyle = try container.decodeIfPresent(OverlayRouteMapMarkerStyle.self, forKey: .routeMapStartMarkerStyle) ?? routeMapMarkerStyle
        routeMapEndMarkerStyle = try container.decodeIfPresent(OverlayRouteMapMarkerStyle.self, forKey: .routeMapEndMarkerStyle) ?? routeMapMarkerStyle
        routeMapBackgroundStyle = try container.decodeIfPresent(OverlayRouteMapBackgroundStyle.self, forKey: .routeMapBackgroundStyle) ?? Self.default.routeMapBackgroundStyle
        routeMapLegendVisible = try container.decodeIfPresent(Bool.self, forKey: .routeMapLegendVisible) ?? Self.default.routeMapLegendVisible
        routeMapLegendMode = try container.decodeIfPresent(OverlayRouteMapLegendMode.self, forKey: .routeMapLegendMode) ?? Self.default.routeMapLegendMode
        routeMapContainerPreset = try container.decodeIfPresent(OverlayRouteMapContainerPreset.self, forKey: .routeMapContainerPreset) ?? Self.default.routeMapContainerPreset
        routeMapMapOpacity = min(max(try container.decodeIfPresent(Double.self, forKey: .routeMapMapOpacity) ?? Self.default.routeMapMapOpacity, 0), 1)
        routeMapBorderVisible = try container.decodeIfPresent(Bool.self, forKey: .routeMapBorderVisible) ?? true
        routeMapWidth = min(max(try container.decodeIfPresent(Double.self, forKey: .routeMapWidth) ?? Self.default.routeMapWidth, 80), 1200)
        routeMapHeight = min(max(try container.decodeIfPresent(Double.self, forKey: .routeMapHeight) ?? Self.default.routeMapHeight, 80), 1200)
        routeMapCornerRadius = min(max(try container.decodeIfPresent(Double.self, forKey: .routeMapCornerRadius) ?? Self.default.routeMapCornerRadius, 0), 120)
        fontName = try container.decodeIfPresent(String.self, forKey: .fontName) ?? Self.default.fontName
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? Self.default.fontSize
        fontWeight = try container.decodeIfPresent(OverlayFontWeight.self, forKey: .fontWeight) ?? Self.default.fontWeight
        foregroundColor = try container.decodeIfPresent(OverlayColor.self, forKey: .foregroundColor) ?? Self.default.foregroundColor
        routeMapRunnerDotColor = try container.decodeIfPresent(OverlayColor.self, forKey: .routeMapRunnerDotColor) ?? foregroundColor
        valueColor = try container.decodeIfPresent(OverlayColor.self, forKey: .valueColor) ?? foregroundColor
        valueOpacity = min(max(try container.decodeIfPresent(Double.self, forKey: .valueOpacity) ?? Self.default.valueOpacity, 0), 1)
        labelColor = try container.decodeIfPresent(OverlayColor.self, forKey: .labelColor) ?? foregroundColor
        labelOpacity = min(max(try container.decodeIfPresent(Double.self, forKey: .labelOpacity) ?? Self.default.labelOpacity, 0), 1)
        unitColor = try container.decodeIfPresent(OverlayColor.self, forKey: .unitColor) ?? foregroundColor
        unitOpacity = min(max(try container.decodeIfPresent(Double.self, forKey: .unitOpacity) ?? Self.default.unitOpacity, 0), 1)
        backgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? Self.default.backgroundOpacity
        shadowOpacity = try container.decodeIfPresent(Double.self, forKey: .shadowOpacity) ?? Self.default.shadowOpacity
        shadowRadius = try container.decodeIfPresent(Double.self, forKey: .shadowRadius) ?? Self.default.shadowRadius
        unitOption = try container.decodeIfPresent(OverlayUnitOption.self, forKey: .unitOption) ?? Self.default.unitOption
        showLabel = try container.decodeIfPresent(Bool.self, forKey: .showLabel) ?? Self.default.showLabel
        showUnit = try container.decodeIfPresent(Bool.self, forKey: .showUnit) ?? Self.default.showUnit
        customLabel = try container.decodeIfPresent(String.self, forKey: .customLabel) ?? Self.default.customLabel
        labelPosition = try container.decodeIfPresent(OverlayTextAttachmentPosition.self, forKey: .labelPosition) ?? Self.default.labelPosition
        unitPosition = try container.decodeIfPresent(OverlayTextAttachmentPosition.self, forKey: .unitPosition) ?? Self.default.unitPosition
        labelFontName = try container.decodeIfPresent(String.self, forKey: .labelFontName) ?? Self.default.labelFontName
        labelFontSize = try container.decodeIfPresent(Double.self, forKey: .labelFontSize) ?? Self.default.labelFontSize
        labelFontWeight = try container.decodeIfPresent(OverlayFontWeight.self, forKey: .labelFontWeight) ?? Self.default.labelFontWeight
        labelSpacing = max(try container.decodeIfPresent(Double.self, forKey: .labelSpacing) ?? Self.default.labelSpacing, 0)
        unitFontName = try container.decodeIfPresent(String.self, forKey: .unitFontName) ?? Self.default.unitFontName
        unitFontSize = try container.decodeIfPresent(Double.self, forKey: .unitFontSize) ?? Self.default.unitFontSize
        unitFontWeight = try container.decodeIfPresent(OverlayFontWeight.self, forKey: .unitFontWeight) ?? Self.default.unitFontWeight
        unitSpacing = max(try container.decodeIfPresent(Double.self, forKey: .unitSpacing) ?? Self.default.unitSpacing, 0)
        rotationDegrees = try container.decodeIfPresent(Double.self, forKey: .rotationDegrees) ?? Self.default.rotationDegrees
        textAlignment = try container.decodeIfPresent(OverlayTextAlignment.self, forKey: .textAlignment) ?? Self.default.textAlignment
        accentColor = try container.decodeIfPresent(OverlayColor.self, forKey: .accentColor) ?? Self.default.accentColor
        backgroundEnabled = try container.decodeIfPresent(Bool.self, forKey: .backgroundEnabled) ?? Self.default.backgroundEnabled
        backgroundColor = try container.decodeIfPresent(OverlayColor.self, forKey: .backgroundColor) ?? Self.default.backgroundColor
        backgroundRadius = try container.decodeIfPresent(Double.self, forKey: .backgroundRadius) ?? Self.default.backgroundRadius
        backgroundPaddingX = try container.decodeIfPresent(Double.self, forKey: .backgroundPaddingX) ?? Self.default.backgroundPaddingX
        backgroundPaddingY = try container.decodeIfPresent(Double.self, forKey: .backgroundPaddingY) ?? Self.default.backgroundPaddingY
        backgroundFadeOutEnabled = try container.decodeIfPresent(Bool.self, forKey: .backgroundFadeOutEnabled) ?? Self.default.backgroundFadeOutEnabled
        backgroundFadeOutAmount = min(max(try container.decodeIfPresent(Double.self, forKey: .backgroundFadeOutAmount) ?? Self.default.backgroundFadeOutAmount, 0), 1)
        backgroundBlurRadius = max(try container.decodeIfPresent(Double.self, forKey: .backgroundBlurRadius) ?? Self.default.backgroundBlurRadius, 0)
        shadowEnabled = try container.decodeIfPresent(Bool.self, forKey: .shadowEnabled) ?? Self.default.shadowEnabled
        shadowOffsetX = try container.decodeIfPresent(Double.self, forKey: .shadowOffsetX) ?? Self.default.shadowOffsetX
        shadowOffsetY = try container.decodeIfPresent(Double.self, forKey: .shadowOffsetY) ?? Self.default.shadowOffsetY
        distanceTimeline = try container.decodeIfPresent(DistanceTimelineStyle.self, forKey: .distanceTimeline) ?? .default
        elevationChart = try container.decodeIfPresent(ElevationChartStyle.self, forKey: .elevationChart) ?? .default
        if let storedGauge = try container.decodeIfPresent(RunningGaugeStyle.self, forKey: .gauge) {
            gauge = storedGauge
        } else {
            // Migrate older projects: seed RunningGaugeStyle from the legacy
            // top-level `gaugePreset` so existing layouts keep working until
            // the user re-applies a preset from the new gauge inspector.
            gauge = RunningGaugeStyle.preset(gaugePreset)
        }
        routeMapStatsBar = try container.decodeIfPresent(OverlayRouteMapStatsBarConfig.self, forKey: .routeMapStatsBar) ?? .default
        lapList = try container.decodeIfPresent(LapListStyle.self, forKey: .lapList) ?? .default
        lapCard = try container.decodeIfPresent(LapCardStyle.self, forKey: .lapCard) ?? .default
        lapLive = try container.decodeIfPresent(LapLiveStyle.self, forKey: .lapLive) ?? .default
    }
}

enum DistanceTimelinePreset: String, CaseIterable, Identifiable, Codable {
    case minimal
    case dense
    case sport
    case splits
    case glass
    case neon
    case lowerThird
    case route

    var id: String { rawValue }

    var label: String {
        switch self {
        case .minimal: "Minimal / 极简"
        case .dense: "Dense / 密集技术"
        case .sport: "Sport / 运动"
        case .splits: "Splits / 分段刻度"
        case .glass: "Glass / 玻璃"
        case .neon: "Neon / 霓虹"
        case .lowerThird: "Lower Third / 下三分之一"
        case .route: "Route / 路线"
        }
    }

    var compactLabel: String {
        label.components(separatedBy: " / ").first ?? label
    }

    var supportsMediaSlot: Bool {
        self == .sport || self == .lowerThird
    }

    var supportsElevation: Bool {
        self == .route
    }
}

// MARK: - Elevation Chart

enum ElevationChartPreset: String, CaseIterable, Identifiable, Codable {
    case gradientArea
    case dualArea
    case bigNumbers

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gradientArea: "Gradient Area"
        case .dualArea: "Dual Area"
        case .bigNumbers: "Big Numbers"
        }
    }
}

enum ElevationChartRenderStyle: String, CaseIterable, Identifiable, Codable {
    case area
    case lineOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .area: "Area"
        case .lineOnly: "Line"
        }
    }
}

enum ElevationChartProgressMode: String, CaseIterable, Identifiable, Codable {
    case fullProfile
    case progressToCurrent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fullProfile: "Full"
        case .progressToCurrent: "Progress"
        }
    }
}

enum ElevationChartBigMetric: String, CaseIterable, Identifiable, Codable {
    case currentElevation
    case elevationGain
    case maxElevation
    case minElevation

    var id: String { rawValue }

    var label: String {
        switch self {
        case .currentElevation: "Current"
        case .elevationGain: "Gain"
        case .maxElevation: "Max"
        case .minElevation: "Min"
        }
    }
}

struct ElevationChartStyle: Equatable, Codable {
    var preset: ElevationChartPreset
    var width: Double
    var height: Double
    var chartStyle: ElevationChartRenderStyle
    var smoothingEnabled: Bool
    var progressMode: ElevationChartProgressMode
    var chartPaddingX: Double
    var chartPaddingY: Double
    var lineColor: OverlayColor
    var lineWidth: Double
    var lineOpacity: Double
    var fillEnabled: Bool
    var fillStartColor: OverlayColor
    var fillEndColor: OverlayColor
    var fillOpacity: Double
    var dualAreaEnabled: Bool
    var upperFillColor: OverlayColor
    var lowerFillColor: OverlayColor
    var currentMarkerEnabled: Bool
    var markerColor: OverlayColor
    var markerLabelEnabled: Bool
    var gridEnabled: Bool
    var axisLabelsEnabled: Bool
    var bigNumbersEnabled: Bool
    var bigNumberMetric: ElevationChartBigMetric
    var bigNumberFontSize: Double
    var backgroundEnabled: Bool
    var backgroundColor: OverlayColor
    var backgroundOpacity: Double
    var cornerRadius: Double
    var borderEnabled: Bool
    var borderOpacity: Double
    var shadowEnabled: Bool
    var shadowOpacity: Double
    var shadowRadius: Double
    var glowEnabled: Bool
    var glowOpacity: Double
    var statsBar: DistanceTimelineStatsBarConfig

    static let `default` = ElevationChartStyle.preset(.gradientArea)

    static func preset(_ preset: ElevationChartPreset) -> ElevationChartStyle {
        var style = ElevationChartStyle(
            preset: preset,
            width: 420,
            height: preset == .bigNumbers ? 190 : 170,
            chartStyle: .area,
            smoothingEnabled: true,
            progressMode: .fullProfile,
            chartPaddingX: 14,
            chartPaddingY: 10,
            lineColor: .white,
            lineWidth: preset == .bigNumbers ? 2.2 : 2.5,
            lineOpacity: 0.95,
            fillEnabled: true,
            fillStartColor: .green,
            fillEndColor: .blue,
            fillOpacity: preset == .bigNumbers ? 0.28 : 0.42,
            dualAreaEnabled: false,
            upperFillColor: .orange,
            lowerFillColor: .cyan,
            currentMarkerEnabled: true,
            markerColor: .blue,
            markerLabelEnabled: true,
            gridEnabled: false,
            axisLabelsEnabled: true,
            bigNumbersEnabled: preset == .bigNumbers,
            bigNumberMetric: .currentElevation,
            bigNumberFontSize: 42,
            backgroundEnabled: true,
            backgroundColor: .black,
            backgroundOpacity: 0.50,
            cornerRadius: 16,
            borderEnabled: true,
            borderOpacity: 0.12,
            shadowEnabled: true,
            shadowOpacity: 0.28,
            shadowRadius: 14,
            glowEnabled: false,
            glowOpacity: 0.25,
            statsBar: ElevationChartStyle.defaultStatsBar
        )
        switch preset {
        case .gradientArea:
            break
        case .dualArea:
            style.dualAreaEnabled = true
            style.fillStartColor = OverlayColor.yellow
            style.fillEndColor = OverlayColor.red
            style.markerColor = OverlayColor.red
            style.statsBar.slots = [
                DistanceTimelineStatsBarSlot(metric: .distance, visible: true, customLabel: ""),
                DistanceTimelineStatsBarSlot(metric: .elevation, visible: true, customLabel: "ELEV"),
                DistanceTimelineStatsBarSlot(metric: .elapsedTime, visible: true, customLabel: ""),
                DistanceTimelineStatsBarSlot(metric: .grade, visible: false, customLabel: ""),
            ]
        case .bigNumbers:
            style.statsBar.visible = false
            style.markerLabelEnabled = false
            style.axisLabelsEnabled = false
        }
        return style
    }

    private static let defaultStatsBar = DistanceTimelineStatsBarConfig(
        visible: true,
        placement: .bottomAttached,
        inside: false,
        layoutMode: .equalColumns,
        width: 0,
        height: 58,
        offsetX: 0,
        offsetY: 0,
        itemSpacing: 0,
        backgroundOpacity: 0.62,
        dividerOpacity: 0.14,
        cornerRadius: 12,
        valueFontSize: 22,
        labelFontSize: 10,
        slots: [
            DistanceTimelineStatsBarSlot(metric: .distance, visible: true, customLabel: ""),
            DistanceTimelineStatsBarSlot(metric: .elevation, visible: true, customLabel: "ELEV"),
            DistanceTimelineStatsBarSlot(metric: .elapsedTime, visible: true, customLabel: ""),
            DistanceTimelineStatsBarSlot(metric: .grade, visible: false, customLabel: ""),
        ]
    )

    mutating func setStatsBarMetric(_ metric: RouteMapStatsMetric, at index: Int) {
        guard statsBar.slots.indices.contains(index) else { return }
        statsBar.slots[index].metric = metric
    }

    mutating func setStatsBarVisible(_ visible: Bool, at index: Int) {
        guard statsBar.slots.indices.contains(index) else { return }
        statsBar.slots[index].visible = visible
    }
}

enum DistanceTimelineMediaSlotMode: String, CaseIterable, Identifiable, Codable {
    case none
    case systemIcon
    case staticSVG
    case animatedSVG
    case image

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "None"
        case .systemIcon: "System Icon"
        case .staticSVG: "Static SVG"
        case .animatedSVG: "Animated SVG"
        case .image: "Image"
        }
    }

    var isImplemented: Bool {
        switch self {
        case .none, .systemIcon, .staticSVG, .animatedSVG:
            true
        case .image:
            false
        }
    }
}

enum OverlayIconTintMode: String, CaseIterable, Identifiable, Codable {
    case original
    case accent
    case text

    var id: String { rawValue }

    var label: String {
        switch self {
        case .original: "Original"
        case .accent: "Accent"
        case .text: "Text"
        }
    }
}

struct OverlayIconSlot: Equatable, Codable {
    var mode: DistanceTimelineMediaSlotMode
    var systemImage: String
    var assetName: String
    var svgSource: String
    var tintMode: OverlayIconTintMode
    var animationDuration: Double
    var animationSpeed: Double
    var loop: Bool

    static let `default` = OverlayIconSlot(
        mode: .systemIcon,
        systemImage: "figure.run",
        assetName: "",
        svgSource: "",
        tintMode: .accent,
        animationDuration: 1.2,
        animationSpeed: 1,
        loop: true
    )

    var hasEmbeddedSVG: Bool {
        !svgSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum DistanceTimelineFadeEdge: String, CaseIterable, Identifiable, Codable {
    case left
    case right
    case both
    case vertical
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .left: "Left"
        case .right: "Right"
        case .both: "Both"
        case .vertical: "Vertical"
        case .all: "All"
        }
    }
}

enum DistanceTimelineUnitSystem: String, CaseIterable, Identifiable, Codable {
    case metric
    case imperial

    var id: String { rawValue }

    var label: String {
        switch self {
        case .metric: "Metric"
        case .imperial: "Imperial"
        }
    }
}

enum DistanceTimelineAxisLabelMode: String, CaseIterable, Identifiable, Codable {
    case startFinish
    case distance

    var id: String { rawValue }

    var label: String {
        switch self {
        case .startFinish: "Start / Finish"
        case .distance: "Distance"
        }
    }
}

struct DistanceTimelineCustomValue: Equatable, Codable {
    var visible: Bool
    var metric: RouteMapStatsMetric
    var label: String
    var value: String

    static let empty = DistanceTimelineCustomValue(visible: false, metric: .distance, label: "", value: "")

    init(visible: Bool, metric: RouteMapStatsMetric, label: String = "", value: String = "") {
        self.visible = visible
        self.metric = metric
        self.label = label
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        visible = try c.decodeIfPresent(Bool.self, forKey: .visible) ?? false
        metric = try c.decodeIfPresent(RouteMapStatsMetric.self, forKey: .metric) ?? .distance
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        value = try c.decodeIfPresent(String.self, forKey: .value) ?? ""
    }
}

struct DistanceTimelineStatsBarSlot: Equatable, Codable {
    var metric: RouteMapStatsMetric
    var visible: Bool
    var customLabel: String
}

struct DistanceTimelineStatsBarConfig: Equatable, Codable {
    var visible: Bool
    var placement: RouteMapStatsBarPlacement
    var inside: Bool
    var layoutMode: RouteMapStatsBarLayoutMode
    var width: Double
    var height: Double
    var offsetX: Double
    var offsetY: Double
    var itemSpacing: Double
    var backgroundOpacity: Double
    var dividerOpacity: Double
    var cornerRadius: Double
    var valueFontName: String
    var valueFontSize: Double
    var valueFontWeight: OverlayFontWeight
    var valueColor: OverlayColor
    var labelFontName: String
    var labelFontSize: Double
    var labelFontWeight: OverlayFontWeight
    var labelColor: OverlayColor
    var slots: [DistanceTimelineStatsBarSlot]

    static let `default` = DistanceTimelineStatsBarConfig(
        visible: false,
        placement: .bottomAttached,
        inside: false,
        layoutMode: .equalColumns,
        width: 0,
        height: 42,
        offsetX: 0,
        offsetY: 0,
        itemSpacing: 0,
        backgroundOpacity: 0.72,
        dividerOpacity: 0.12,
        cornerRadius: 8,
        valueFontName: "SF Pro Display",
        valueFontSize: 30,
        valueFontWeight: .semibold,
        valueColor: .white,
        labelFontName: "SF Pro Display",
        labelFontSize: 10,
        labelFontWeight: .medium,
        labelColor: OverlayColor(red: 1, green: 1, blue: 1, alpha: 0.58),
        slots: [
            DistanceTimelineStatsBarSlot(metric: .distance, visible: true, customLabel: ""),
            DistanceTimelineStatsBarSlot(metric: .pace, visible: true, customLabel: ""),
            DistanceTimelineStatsBarSlot(metric: .elapsedTime, visible: false, customLabel: ""),
            DistanceTimelineStatsBarSlot(metric: .heartRate, visible: false, customLabel: ""),
        ]
    )

    init(
        visible: Bool,
        placement: RouteMapStatsBarPlacement,
        inside: Bool = false,
        layoutMode: RouteMapStatsBarLayoutMode,
        width: Double = 0,
        height: Double,
        offsetX: Double = 0,
        offsetY: Double = 0,
        itemSpacing: Double = 0,
        backgroundOpacity: Double,
        dividerOpacity: Double,
        cornerRadius: Double,
        valueFontName: String = "SF Pro Display",
        valueFontSize: Double = 30,
        valueFontWeight: OverlayFontWeight = .semibold,
        valueColor: OverlayColor = .white,
        labelFontName: String = "SF Pro Display",
        labelFontSize: Double = 10,
        labelFontWeight: OverlayFontWeight = .medium,
        labelColor: OverlayColor = OverlayColor(red: 1, green: 1, blue: 1, alpha: 0.58),
        slots: [DistanceTimelineStatsBarSlot]
    ) {
        self.visible = visible
        self.placement = placement.attachedDistanceTimelinePlacement
        self.inside = inside || placement.isInside
        self.layoutMode = layoutMode
        self.width = width
        self.height = height
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.itemSpacing = itemSpacing
        self.backgroundOpacity = backgroundOpacity
        self.dividerOpacity = dividerOpacity
        self.cornerRadius = cornerRadius
        self.valueFontName = valueFontName
        self.valueFontSize = valueFontSize
        self.valueFontWeight = valueFontWeight
        self.valueColor = valueColor
        self.labelFontName = labelFontName
        self.labelFontSize = labelFontSize
        self.labelFontWeight = labelFontWeight
        self.labelColor = labelColor
        self.slots = slots
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let base = Self.default
        visible = try c.decodeIfPresent(Bool.self, forKey: .visible) ?? base.visible
        let decodedPlacement = try c.decodeIfPresent(RouteMapStatsBarPlacement.self, forKey: .placement) ?? base.placement
        placement = decodedPlacement.attachedDistanceTimelinePlacement
        inside = try c.decodeIfPresent(Bool.self, forKey: .inside) ?? decodedPlacement.isInside
        layoutMode = try c.decodeIfPresent(RouteMapStatsBarLayoutMode.self, forKey: .layoutMode) ?? base.layoutMode
        width = try c.decodeIfPresent(Double.self, forKey: .width) ?? base.width
        height = try c.decodeIfPresent(Double.self, forKey: .height) ?? base.height
        offsetX = try c.decodeIfPresent(Double.self, forKey: .offsetX) ?? base.offsetX
        offsetY = try c.decodeIfPresent(Double.self, forKey: .offsetY) ?? base.offsetY
        itemSpacing = try c.decodeIfPresent(Double.self, forKey: .itemSpacing) ?? base.itemSpacing
        backgroundOpacity = try c.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? base.backgroundOpacity
        dividerOpacity = try c.decodeIfPresent(Double.self, forKey: .dividerOpacity) ?? base.dividerOpacity
        cornerRadius = try c.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? base.cornerRadius
        valueFontName = try c.decodeIfPresent(String.self, forKey: .valueFontName) ?? base.valueFontName
        valueFontSize = try c.decodeIfPresent(Double.self, forKey: .valueFontSize) ?? base.valueFontSize
        valueFontWeight = try c.decodeIfPresent(OverlayFontWeight.self, forKey: .valueFontWeight) ?? base.valueFontWeight
        valueColor = try c.decodeIfPresent(OverlayColor.self, forKey: .valueColor) ?? base.valueColor
        labelFontName = try c.decodeIfPresent(String.self, forKey: .labelFontName) ?? base.labelFontName
        labelFontSize = try c.decodeIfPresent(Double.self, forKey: .labelFontSize) ?? base.labelFontSize
        labelFontWeight = try c.decodeIfPresent(OverlayFontWeight.self, forKey: .labelFontWeight) ?? base.labelFontWeight
        labelColor = try c.decodeIfPresent(OverlayColor.self, forKey: .labelColor) ?? base.labelColor
        slots = try c.decodeIfPresent([DistanceTimelineStatsBarSlot].self, forKey: .slots) ?? base.slots
    }
}

struct DistanceTimelineStyle: Equatable, Codable {
    var preset: DistanceTimelinePreset
    var width: Double
    var height: Double
    var showValue: Bool
    var valueUnitSystem: DistanceTimelineUnitSystem
    var customValuesEnabled: Bool
    var customValues: [DistanceTimelineCustomValue]
    var customValueFontSize: Double
    var customValuesGroupSpacing: Double
    var customValueSpacing: Double
    var customValueColor: OverlayColor
    var customValueOpacity: Double
    var showLabel: Bool
    var label: String
    var showAxisLabels: Bool
    var axisLabelMode: DistanceTimelineAxisLabelMode
    var axisLabelOffset: Double
    var showDistancePoints: Bool
    var distancePointCount: Int
    var distancePointOffset: Double
    var statsBar: DistanceTimelineStatsBarConfig
    var backgroundEnabled: Bool
    var backgroundColor: OverlayColor
    var backgroundOpacity: Double
    var borderEnabled: Bool
    var borderColor: OverlayColor
    var borderOpacity: Double
    var borderWidth: Double
    var cornerRadius: Double
    var paddingX: Double
    var paddingY: Double
    var trackHeight: Double
    var trackOpacity: Double
    var fillColor: OverlayColor
    var tickMarksEnabled: Bool
    var tickDensity: Int
    var currentMarkerEnabled: Bool
    var glowEnabled: Bool
    var fadeEnabled: Bool
    var fadeEdge: DistanceTimelineFadeEdge
    var fadeAmount: Double
    var mediaSlotEnabled: Bool
    var mediaSlotMode: DistanceTimelineMediaSlotMode
    var mediaSystemImage: String
    var mediaSlotSize: Double
    var mediaSlot: OverlayIconSlot
    var elevationProfileVisible: Bool

    var showPercent: Bool {
        statsBar.visible && statsBar.slots.contains { $0.visible && $0.metric == .progress }
    }

    static let `default` = preset(.minimal)

    init(
        preset: DistanceTimelinePreset,
        width: Double,
        height: Double,
        showValue: Bool = true,
        valueUnitSystem: DistanceTimelineUnitSystem = .metric,
        customValuesEnabled: Bool = false,
        customValues: [DistanceTimelineCustomValue] = Array(repeating: .empty, count: 4),
        customValueFontSize: Double = 12,
        customValuesGroupSpacing: Double = 12,
        customValueSpacing: Double = 10,
        customValueColor: OverlayColor = .white,
        customValueOpacity: Double = 0.70,
        showLabel: Bool,
        label: String,
        showAxisLabels: Bool = false,
        axisLabelMode: DistanceTimelineAxisLabelMode = .startFinish,
        axisLabelOffset: Double = 14,
        showDistancePoints: Bool = false,
        distancePointCount: Int = 3,
        distancePointOffset: Double = 34,
        statsBar: DistanceTimelineStatsBarConfig = .default,
        backgroundEnabled: Bool,
        backgroundColor: OverlayColor,
        backgroundOpacity: Double,
        borderEnabled: Bool,
        borderColor: OverlayColor,
        borderOpacity: Double,
        borderWidth: Double,
        cornerRadius: Double,
        paddingX: Double,
        paddingY: Double,
        trackHeight: Double,
        trackOpacity: Double,
        fillColor: OverlayColor,
        tickMarksEnabled: Bool,
        tickDensity: Int = 16,
        currentMarkerEnabled: Bool,
        glowEnabled: Bool,
        fadeEnabled: Bool,
        fadeEdge: DistanceTimelineFadeEdge,
        fadeAmount: Double,
        mediaSlotEnabled: Bool,
        mediaSlotMode: DistanceTimelineMediaSlotMode,
        mediaSystemImage: String,
        mediaSlotSize: Double,
        mediaSlot: OverlayIconSlot,
        elevationProfileVisible: Bool
    ) {
        self.preset = preset
        self.width = width
        self.height = height
        self.showValue = showValue
        self.valueUnitSystem = valueUnitSystem
        self.customValuesEnabled = customValuesEnabled
        self.customValues = Array(customValues.prefix(4)) + Array(repeating: .empty, count: max(0, 4 - customValues.count))
        self.customValueFontSize = customValueFontSize
        self.customValuesGroupSpacing = customValuesGroupSpacing
        self.customValueSpacing = customValueSpacing
        self.customValueColor = customValueColor
        self.customValueOpacity = customValueOpacity
        self.showLabel = showLabel
        self.label = label
        self.showAxisLabels = showAxisLabels
        self.axisLabelMode = axisLabelMode
        self.axisLabelOffset = axisLabelOffset
        self.showDistancePoints = showDistancePoints
        self.distancePointCount = min(max(distancePointCount, 0), 12)
        self.distancePointOffset = distancePointOffset
        self.statsBar = statsBar
        self.backgroundEnabled = backgroundEnabled
        self.backgroundColor = backgroundColor
        self.backgroundOpacity = backgroundOpacity
        self.borderEnabled = borderEnabled
        self.borderColor = borderColor
        self.borderOpacity = borderOpacity
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.paddingX = paddingX
        self.paddingY = paddingY
        self.trackHeight = trackHeight
        self.trackOpacity = trackOpacity
        self.fillColor = fillColor
        self.tickMarksEnabled = tickMarksEnabled
        self.tickDensity = min(max(tickDensity, 2), 40)
        self.currentMarkerEnabled = currentMarkerEnabled
        self.glowEnabled = glowEnabled
        self.fadeEnabled = fadeEnabled
        self.fadeEdge = fadeEdge
        self.fadeAmount = fadeAmount
        self.mediaSlotEnabled = mediaSlotEnabled
        self.mediaSlotMode = mediaSlotMode
        self.mediaSystemImage = mediaSystemImage
        self.mediaSlotSize = mediaSlotSize
        self.mediaSlot = mediaSlot
        self.elevationProfileVisible = elevationProfileVisible
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
        let presetValue = try c.decodeIfPresent(DistanceTimelinePreset.self, forKey: .preset) ?? .minimal
        let base = DistanceTimelineStyle.preset(presetValue)

        preset = presetValue
        width = try c.decodeIfPresent(Double.self, forKey: .width) ?? base.width
        height = try c.decodeIfPresent(Double.self, forKey: .height) ?? base.height
        showValue = try c.decodeIfPresent(Bool.self, forKey: .showValue) ?? true
        valueUnitSystem = try c.decodeIfPresent(DistanceTimelineUnitSystem.self, forKey: .valueUnitSystem) ?? .metric
        customValuesEnabled = try c.decodeIfPresent(Bool.self, forKey: .customValuesEnabled) ?? false
        let decodedCustomValues = try c.decodeIfPresent([DistanceTimelineCustomValue].self, forKey: .customValues) ?? base.customValues
        customValues = Array(decodedCustomValues.prefix(4)) + Array(repeating: .empty, count: max(0, 4 - decodedCustomValues.count))
        customValueFontSize = try c.decodeIfPresent(Double.self, forKey: .customValueFontSize) ?? base.customValueFontSize
        customValuesGroupSpacing = try c.decodeIfPresent(Double.self, forKey: .customValuesGroupSpacing) ?? base.customValuesGroupSpacing
        customValueSpacing = try c.decodeIfPresent(Double.self, forKey: .customValueSpacing) ?? base.customValueSpacing
        customValueColor = try c.decodeIfPresent(OverlayColor.self, forKey: .customValueColor) ?? base.customValueColor
        customValueOpacity = try c.decodeIfPresent(Double.self, forKey: .customValueOpacity) ?? base.customValueOpacity
        showLabel = try c.decodeIfPresent(Bool.self, forKey: .showLabel) ?? base.showLabel
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? base.label
        showAxisLabels = try c.decodeIfPresent(Bool.self, forKey: .showAxisLabels)
            ?? legacy.decodeIfPresent(Bool.self, forKey: .showStartFinishLabels)
            ?? base.showAxisLabels
        axisLabelMode = try c.decodeIfPresent(DistanceTimelineAxisLabelMode.self, forKey: .axisLabelMode) ?? base.axisLabelMode
        axisLabelOffset = try c.decodeIfPresent(Double.self, forKey: .axisLabelOffset) ?? base.axisLabelOffset
        showDistancePoints = try c.decodeIfPresent(Bool.self, forKey: .showDistancePoints) ?? base.showDistancePoints
        distancePointCount = min(max(try c.decodeIfPresent(Int.self, forKey: .distancePointCount) ?? base.distancePointCount, 0), 12)
        distancePointOffset = try c.decodeIfPresent(Double.self, forKey: .distancePointOffset) ?? base.distancePointOffset
        statsBar = try c.decodeIfPresent(DistanceTimelineStatsBarConfig.self, forKey: .statsBar) ?? base.statsBar
        backgroundEnabled = try c.decodeIfPresent(Bool.self, forKey: .backgroundEnabled) ?? base.backgroundEnabled
        backgroundColor = try c.decodeIfPresent(OverlayColor.self, forKey: .backgroundColor) ?? base.backgroundColor
        backgroundOpacity = try c.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? base.backgroundOpacity
        borderEnabled = try c.decodeIfPresent(Bool.self, forKey: .borderEnabled) ?? base.borderEnabled
        borderColor = try c.decodeIfPresent(OverlayColor.self, forKey: .borderColor) ?? base.borderColor
        borderOpacity = try c.decodeIfPresent(Double.self, forKey: .borderOpacity) ?? base.borderOpacity
        borderWidth = try c.decodeIfPresent(Double.self, forKey: .borderWidth) ?? base.borderWidth
        cornerRadius = try c.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? base.cornerRadius
        paddingX = try c.decodeIfPresent(Double.self, forKey: .paddingX) ?? base.paddingX
        paddingY = try c.decodeIfPresent(Double.self, forKey: .paddingY) ?? base.paddingY
        trackHeight = try c.decodeIfPresent(Double.self, forKey: .trackHeight) ?? base.trackHeight
        trackOpacity = try c.decodeIfPresent(Double.self, forKey: .trackOpacity) ?? base.trackOpacity
        fillColor = try c.decodeIfPresent(OverlayColor.self, forKey: .fillColor) ?? base.fillColor
        tickMarksEnabled = try c.decodeIfPresent(Bool.self, forKey: .tickMarksEnabled) ?? base.tickMarksEnabled
        tickDensity = min(max(try c.decodeIfPresent(Int.self, forKey: .tickDensity) ?? base.tickDensity, 2), 40)
        currentMarkerEnabled = try c.decodeIfPresent(Bool.self, forKey: .currentMarkerEnabled) ?? base.currentMarkerEnabled
        glowEnabled = try c.decodeIfPresent(Bool.self, forKey: .glowEnabled) ?? base.glowEnabled
        fadeEnabled = try c.decodeIfPresent(Bool.self, forKey: .fadeEnabled) ?? base.fadeEnabled
        fadeEdge = try c.decodeIfPresent(DistanceTimelineFadeEdge.self, forKey: .fadeEdge) ?? base.fadeEdge
        fadeAmount = try c.decodeIfPresent(Double.self, forKey: .fadeAmount) ?? base.fadeAmount
        mediaSlotEnabled = try c.decodeIfPresent(Bool.self, forKey: .mediaSlotEnabled) ?? base.mediaSlotEnabled
        mediaSlotMode = try c.decodeIfPresent(DistanceTimelineMediaSlotMode.self, forKey: .mediaSlotMode) ?? base.mediaSlotMode
        mediaSystemImage = try c.decodeIfPresent(String.self, forKey: .mediaSystemImage) ?? base.mediaSystemImage
        mediaSlotSize = try c.decodeIfPresent(Double.self, forKey: .mediaSlotSize) ?? base.mediaSlotSize
        mediaSlot = try c.decodeIfPresent(OverlayIconSlot.self, forKey: .mediaSlot) ?? base.mediaSlot
        elevationProfileVisible = try c.decodeIfPresent(Bool.self, forKey: .elevationProfileVisible) ?? base.elevationProfileVisible

        if (try legacy.decodeIfPresent(Bool.self, forKey: .showPercent) ?? false), !statsBar.visible {
            statsBar.visible = true
            statsBar.placement = .rightAttached
            statsBar.inside = false
            statsBar.layoutMode = .compact
            if statsBar.slots.isEmpty {
                statsBar.slots = DistanceTimelineStatsBarConfig.default.slots
            }
            statsBar.slots[0] = DistanceTimelineStatsBarSlot(metric: .progress, visible: true, customLabel: "")
        }
    }

    private enum CodingKeys: String, CodingKey {
        case preset
        case width
        case height
        case showValue
        case valueUnitSystem
        case customValuesEnabled
        case customValues
        case customValueFontSize
        case customValuesGroupSpacing
        case customValueSpacing
        case customValueColor
        case customValueOpacity
        case showLabel
        case label
        case showAxisLabels
        case axisLabelMode
        case axisLabelOffset
        case showDistancePoints
        case distancePointCount
        case distancePointOffset
        case statsBar
        case backgroundEnabled
        case backgroundColor
        case backgroundOpacity
        case borderEnabled
        case borderColor
        case borderOpacity
        case borderWidth
        case cornerRadius
        case paddingX
        case paddingY
        case trackHeight
        case trackOpacity
        case fillColor
        case tickMarksEnabled
        case tickDensity
        case currentMarkerEnabled
        case glowEnabled
        case fadeEnabled
        case fadeEdge
        case fadeAmount
        case mediaSlotEnabled
        case mediaSlotMode
        case mediaSystemImage
        case mediaSlotSize
        case mediaSlot
        case elevationProfileVisible
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case showPercent
        case showStartFinishLabels
    }

    static func preset(_ presetValue: DistanceTimelinePreset) -> DistanceTimelineStyle {
        switch presetValue {
        case .minimal:
            return DistanceTimelineStyle(
                preset: presetValue,
                width: 280,
                height: 68,
                showLabel: false,
                label: "Distance",
                backgroundEnabled: true,
                backgroundColor: .black,
                backgroundOpacity: 0.70,
                borderEnabled: false,
                borderColor: .white,
                borderOpacity: 0.18,
                borderWidth: 1,
                cornerRadius: 9,
                paddingX: 14,
                paddingY: 10,
                trackHeight: 6,
                trackOpacity: 0.24,
                fillColor: .green,
                tickMarksEnabled: false,
                currentMarkerEnabled: false,
                glowEnabled: false,
                fadeEnabled: false,
                fadeEdge: .right,
                fadeAmount: 0.22,
                mediaSlotEnabled: false,
                mediaSlotMode: .none,
                mediaSystemImage: "figure.run",
                mediaSlotSize: 30,
                mediaSlot: .default,
                elevationProfileVisible: false
            )
        case .dense:
            var style = preset(.minimal)
            style.preset = presetValue
            style.width = 320
            style.height = 92
            style.showLabel = true
            style.showAxisLabels = true
            style.axisLabelMode = .startFinish
            style.showDistancePoints = true
            style.distancePointCount = 3
            style.backgroundOpacity = 0.82
            style.borderEnabled = true
            style.borderOpacity = 0.18
            style.cornerRadius = 6
            style.trackHeight = 8
            style.tickMarksEnabled = true
            style.tickDensity = 16
            style.currentMarkerEnabled = true
            return style
        case .sport:
            var style = preset(.minimal)
            style.preset = presetValue
            style.width = 340
            style.height = 86
            style.showLabel = true
            style.statsBar.visible = true
            style.statsBar.placement = .rightAttached
            style.statsBar.inside = false
            style.statsBar.layoutMode = .compact
            style.statsBar.height = 58
            style.statsBar.slots = [
                DistanceTimelineStatsBarSlot(metric: .progress, visible: true, customLabel: ""),
                DistanceTimelineStatsBarSlot(metric: .pace, visible: false, customLabel: ""),
                DistanceTimelineStatsBarSlot(metric: .elapsedTime, visible: false, customLabel: ""),
                DistanceTimelineStatsBarSlot(metric: .heartRate, visible: false, customLabel: ""),
            ]
            style.backgroundOpacity = 0.76
            style.cornerRadius = 14
            style.paddingX = 16
            style.trackHeight = 8
            style.currentMarkerEnabled = true
            style.mediaSlotEnabled = true
            style.mediaSlotMode = .systemIcon
            style.mediaSlotSize = 34
            style.mediaSlot = .default
            return style
        case .splits:
            var style = preset(.minimal)
            style.preset = presetValue
            style.width = 360
            style.height = 78
            style.showAxisLabels = true
            style.axisLabelMode = .distance
            style.showDistancePoints = true
            style.distancePointCount = 4
            style.backgroundOpacity = 0.65
            style.borderEnabled = true
            style.borderOpacity = 0.20
            style.tickMarksEnabled = true
            style.tickDensity = 10
            style.currentMarkerEnabled = true
            return style
        case .glass:
            var style = preset(.minimal)
            style.preset = presetValue
            style.width = 320
            style.height = 76
            style.showLabel = true
            style.backgroundEnabled = false
            style.backgroundOpacity = 0
            style.borderEnabled = true
            style.borderOpacity = 0.34
            style.cornerRadius = 16
            style.fadeEnabled = true
            style.fadeEdge = .both
            style.fadeAmount = 0.24
            return style
        case .neon:
            var style = preset(.minimal)
            style.preset = presetValue
            style.width = 330
            style.height = 72
            style.statsBar.visible = true
            style.statsBar.placement = .rightAttached
            style.statsBar.inside = false
            style.statsBar.layoutMode = .compact
            style.statsBar.height = 58
            style.statsBar.slots = [
                DistanceTimelineStatsBarSlot(metric: .progress, visible: true, customLabel: ""),
                DistanceTimelineStatsBarSlot(metric: .pace, visible: false, customLabel: ""),
                DistanceTimelineStatsBarSlot(metric: .elapsedTime, visible: false, customLabel: ""),
                DistanceTimelineStatsBarSlot(metric: .heartRate, visible: false, customLabel: ""),
            ]
            style.backgroundOpacity = 0.60
            style.fillColor = .cyan
            style.trackOpacity = 0.18
            style.trackHeight = 5
            style.currentMarkerEnabled = true
            style.glowEnabled = true
            return style
        case .lowerThird:
            var style = preset(.minimal)
            style.preset = presetValue
            style.width = 460
            style.height = 82
            style.showLabel = true
            style.statsBar.visible = true
            style.statsBar.placement = .rightAttached
            style.statsBar.inside = false
            style.statsBar.layoutMode = .compact
            style.statsBar.height = 72
            style.statsBar.slots = [
                DistanceTimelineStatsBarSlot(metric: .progress, visible: true, customLabel: ""),
                DistanceTimelineStatsBarSlot(metric: .pace, visible: false, customLabel: ""),
                DistanceTimelineStatsBarSlot(metric: .elapsedTime, visible: false, customLabel: ""),
                DistanceTimelineStatsBarSlot(metric: .heartRate, visible: false, customLabel: ""),
            ]
            style.backgroundOpacity = 0.62
            style.cornerRadius = 7
            style.paddingX = 18
            style.mediaSlotEnabled = true
            style.mediaSlotMode = .systemIcon
            style.mediaSlotSize = 36
            style.mediaSlot = .default
            style.fadeEnabled = true
            style.fadeEdge = .right
            style.fadeAmount = 0.28
            return style
        case .route:
            var style = preset(.minimal)
            style.preset = presetValue
            style.width = 370
            style.height = 102
            style.showLabel = true
            style.showAxisLabels = true
            style.axisLabelMode = .startFinish
            style.backgroundOpacity = 0.58
            style.borderEnabled = true
            style.borderOpacity = 0.16
            style.trackHeight = 5
            style.currentMarkerEnabled = true
            style.elevationProfileVisible = true
            style.fadeEnabled = true
            style.fadeEdge = .both
            style.fadeAmount = 0.24
            return style
        }
    }
}

enum OverlayRouteMapPreset: String, CaseIterable, Identifiable, Codable {
    case minimal
    case gradient
    case glow

    var id: String { rawValue }

    /// Display label. Route Style now describes the polyline appearance only;
    /// whether a map background is rendered is a separate decision driven by
    /// `OverlayStyle.routeMapBackgroundStyle` (and the dedicated "Show Map"
    /// toggle in the Inspector). The legacy `mapKit` case is migrated to
    /// `gradient` on decode for backward compatibility.
    var label: String {
        switch self {
        case .minimal: "Minimal / 极简轨迹"
        case .gradient: "Gradient / 渐变轨迹"
        case .glow: "Glow / 发光轨迹"
        }
    }
}

enum OverlayRouteMapProvider: String, CaseIterable, Identifiable, Codable {
    case none
    case mapKit
    case customStaticAPI

    var id: String { rawValue }
}

enum OverlayRouteMapShape: String, CaseIterable, Identifiable, Codable {
    case square
    case circle

    var id: String { rawValue }

    var label: String {
        switch self {
        case .square: "Square / 方形"
        case .circle: "Circle / 圆形"
        }
    }
}

enum OverlayRouteMapEdgeFade: String, CaseIterable, Identifiable, Codable {
    case solid
    case fadeOut

    var id: String { rawValue }

    var label: String {
        switch self {
        case .solid: "Solid Edge / 实心边缘"
        case .fadeOut: "Fade Out / 边缘渐变"
        }
    }
}

enum OverlayRouteMapColorMode: String, CaseIterable, Identifiable, Codable {
    case solid
    case gradient

    var id: String { rawValue }

    var label: String {
        switch self {
        case .solid: "Solid / 纯色"
        case .gradient: "Gradient / 渐变"
        }
    }
}

enum OverlayRouteMapMarkerStyle: String, CaseIterable, Identifiable, Codable {
    case hidden
    case dot
    case pin
    case flag

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hidden: "Hidden / 隐藏"
        case .dot: "Dot / 圆点"
        case .pin: "Pin / 定位针"
        case .flag: "Flag / 旗帜"
        }
    }
}

enum OverlayRouteMapLegendMode: String, CaseIterable, Identifiable, Codable {
    case minimal
    case startFinishDistance
    case gradientBand

    var id: String { rawValue }

    var label: String {
        switch self {
        case .minimal: "Minimal / 仅起终点"
        case .startFinishDistance: "With Distance / 起终点+里程"
        case .gradientBand: "Gradient Band / 渐变色带"
        }
    }
}

enum OverlayRouteMapBackgroundStyle: String, CaseIterable, Identifiable, Codable {
    case none
    case dark
    case light
    case terrain
    case satellite

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "None / 无底图"
        case .dark: "Dark / 深色"
        case .light: "Light / 浅色"
        case .terrain: "Terrain / 地形"
        case .satellite: "Satellite / 卫星"
        }
    }

    /// Map style choices excluding `.none`. The Inspector's Map Style picker
    /// uses this list since "show map" is a separate toggle.
    static var visibleCases: [OverlayRouteMapBackgroundStyle] { [.dark, .light, .terrain, .satellite] }
}

/// Container visual preset for the Route Map overlay. Selecting a preset
/// writes a bundle of defaults onto the element (`routeMapShape`,
/// `routeMapEdgeFade`, `routeMapFadeAmount`, `routeMapMapOpacity`,
/// `shadowEnabled`, `shadowOpacity`, `shadowRadius`,
/// `shadowOffsetX`, `shadowOffsetY`).
///
/// See `docs/design/overlays/route-map/route-map-overlay-ui.md` and
/// `docs/design/overlays/route-map/route-map-overlay-ui.spec.json` for the table of values each
/// preset applies.
enum OverlayRouteMapContainerPreset: String, CaseIterable, Identifiable, Codable {
    case squareHardEdge
    case circleHardEdge
    case squareGradientEdge
    case circleGradientEdge

    var id: String { rawValue }

    var label: String {
        switch self {
        case .squareHardEdge: "Square Hard / 方形硬边界"
        case .circleHardEdge: "Circle Hard / 圆形硬边界"
        case .squareGradientEdge: "Square Gradient / 方形渐变"
        case .circleGradientEdge: "Circle Gradient / 圆形渐变"
        }
    }

    var shape: OverlayRouteMapShape {
        switch self {
        case .squareHardEdge, .squareGradientEdge: .square
        case .circleHardEdge, .circleGradientEdge: .circle
        }
    }

    var edgeFade: OverlayRouteMapEdgeFade {
        switch self {
        case .squareHardEdge, .circleHardEdge: .solid
        case .squareGradientEdge, .circleGradientEdge: .fadeOut
        }
    }

    /// Edge softness amount. `0` for hard-edge presets so the renderer skips
    /// the alpha mask and clips with the raw shape.
    var fadeAmount: Double {
        switch self {
        case .squareHardEdge, .circleHardEdge: 0
        case .squareGradientEdge: 0.30
        case .circleGradientEdge: 0.34
        }
    }

    var mapOpacity: Double {
        switch self {
        case .squareHardEdge, .circleHardEdge: 0.72
        case .squareGradientEdge, .circleGradientEdge: 0.58
        }
    }

    var shadowEnabled: Bool {
        switch self {
        case .squareHardEdge, .circleHardEdge: true
        case .squareGradientEdge, .circleGradientEdge: false
        }
    }

    var shadowOpacity: Double {
        switch self {
        case .squareHardEdge: 0.35
        case .circleHardEdge: 0.38
        case .squareGradientEdge, .circleGradientEdge: 0
        }
    }

    var shadowRadius: Double {
        switch self {
        case .squareHardEdge: 14
        case .circleHardEdge: 16
        case .squareGradientEdge, .circleGradientEdge: 0
        }
    }

    var shadowOffsetX: Double { 0 }

    var shadowOffsetY: Double {
        switch self {
        case .squareHardEdge, .circleHardEdge: 6
        case .squareGradientEdge, .circleGradientEdge: 0
        }
    }
}

enum RouteMapStatsMetric: String, CaseIterable, Identifiable, Codable {
    case progress
    case distance
    case pace
    case elapsedTime
    case heartRate
    case elevation
    case grade
    case cadence
    case power
    case calories

    var id: String { rawValue }

    var label: String {
        switch self {
        case .progress: "Progress"
        case .distance: "Distance"
        case .pace: "Pace"
        case .elapsedTime: "Time"
        case .heartRate: "Heart Rate"
        case .elevation: "Elevation"
        case .grade: "Grade"
        case .cadence: "Cadence"
        case .power: "Power"
        case .calories: "Calories"
        }
    }

    var elementType: OverlayElementType {
        switch self {
        case .progress: .distance
        case .distance: .distance
        case .pace: .pace
        case .elapsedTime: .elapsedTime
        case .heartRate: .heartRate
        case .elevation: .elevation
        case .grade: .grade
        case .cadence: .cadence
        case .power: .power
        case .calories: .calories
        }
    }
}

// MARK: - Stats Bar enums

enum RouteMapStatsBarPlacement: String, CaseIterable, Identifiable, Codable {
    case bottomAttached
    case topAttached
    case leftAttached
    case rightAttached
    case insideBottom
    case insideTop

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bottomAttached: "Bottom"
        case .topAttached:    "Top"
        case .leftAttached:   "Left"
        case .rightAttached:  "Right"
        case .insideBottom:   "Inside Bottom"
        case .insideTop:      "Inside Top"
        }
    }

    var isVertical: Bool { self == .leftAttached || self == .rightAttached }
    var isInside: Bool   { self == .insideBottom || self == .insideTop }

    var attachedDistanceTimelinePlacement: RouteMapStatsBarPlacement {
        switch self {
        case .insideTop: .topAttached
        case .insideBottom: .bottomAttached
        default: self
        }
    }
}

enum RouteMapStatsBarLayoutMode: String, CaseIterable, Identifiable, Codable {
    /// All slots the same width, horizontal.
    case equalColumns
    /// First slot prominent (wider, larger font), rest equal.
    case emphasis
    /// Two rows × two columns (up to 4 slots).
    case grid2x2
    /// Slots stacked vertically — ideal for left/right placement.
    case stack
    /// Single dense row with inline value+unit and tiny label.
    case compact

    var id: String { rawValue }

    var label: String {
        switch self {
        case .equalColumns: "Equal"
        case .emphasis:     "Emphasis"
        case .grid2x2:      "2×2 Grid"
        case .stack:        "Stack"
        case .compact:      "Compact"
        }
    }
}

// MARK: - Stats Bar model

struct RouteMapStatsBarSlot: Equatable, Codable {
    var metric: RouteMapStatsMetric
    var visible: Bool
    var customLabel: String
}

struct OverlayRouteMapStatsBarConfig: Equatable, Codable {
    var visible: Bool
    var placement: RouteMapStatsBarPlacement
    var inside: Bool
    var layoutMode: RouteMapStatsBarLayoutMode
    /// Bar thickness in design units. For bottom/top this is height;
    /// for left/right this is the horizontal width. Range 32...160.
    var height: Double
    /// Long-side span in design units. 0 = auto (fills map edge span).
    var width: Double
    var offsetX: Double
    var offsetY: Double
    var itemSpacing: Double
    var backgroundOpacity: Double
    /// Gaussian blur radius applied to the bar background (design units). 0 = off.
    var blurRadius: Double
    /// Opacity of the 1 pt divider lines between slots.
    var dividerOpacity: Double
    /// Corner radius of the bar background shape (design units).
    var cornerRadius: Double
    var valueFontName: String
    var valueFontSize: Double
    var valueFontWeight: OverlayFontWeight
    var valueColor: OverlayColor
    var labelFontName: String
    var labelFontSize: Double
    var labelFontWeight: OverlayFontWeight
    var labelColor: OverlayColor
    var slots: [RouteMapStatsBarSlot]

    static let `default` = OverlayRouteMapStatsBarConfig(
        visible: false,
        placement: .bottomAttached,
        inside: false,
        layoutMode: .equalColumns,
        height: 64,
        width: 0,
        offsetX: 0,
        offsetY: 0,
        itemSpacing: 0,
        backgroundOpacity: 0.88,
        blurRadius: 0,
        dividerOpacity: 0.12,
        cornerRadius: 0,
        valueFontName: "SF Pro Display",
        valueFontSize: 30,
        valueFontWeight: .semibold,
        valueColor: .white,
        labelFontName: "SF Pro Display",
        labelFontSize: 10,
        labelFontWeight: .medium,
        labelColor: OverlayColor(red: 1, green: 1, blue: 1, alpha: 0.58),
        slots: [
            RouteMapStatsBarSlot(metric: .distance,    visible: true,  customLabel: ""),
            RouteMapStatsBarSlot(metric: .pace,        visible: true,  customLabel: ""),
            RouteMapStatsBarSlot(metric: .elapsedTime, visible: true,  customLabel: ""),
            RouteMapStatsBarSlot(metric: .heartRate,   visible: false, customLabel: ""),
        ]
    )

    init(
        visible: Bool,
        placement: RouteMapStatsBarPlacement = .bottomAttached,
        inside: Bool = false,
        layoutMode: RouteMapStatsBarLayoutMode = .equalColumns,
        height: Double = 64,
        width: Double = 0,
        offsetX: Double = 0,
        offsetY: Double = 0,
        itemSpacing: Double = 0,
        backgroundOpacity: Double = 0.88,
        blurRadius: Double = 0,
        dividerOpacity: Double = 0.12,
        cornerRadius: Double = 0,
        valueFontName: String = "SF Pro Display",
        valueFontSize: Double = 30,
        valueFontWeight: OverlayFontWeight = .semibold,
        valueColor: OverlayColor = .white,
        labelFontName: String = "SF Pro Display",
        labelFontSize: Double = 10,
        labelFontWeight: OverlayFontWeight = .medium,
        labelColor: OverlayColor = OverlayColor(red: 1, green: 1, blue: 1, alpha: 0.58),
        slots: [RouteMapStatsBarSlot]
    ) {
        self.visible = visible
        self.placement = placement
        self.inside = inside
        self.layoutMode = layoutMode
        self.height = min(max(height, 32), 160)
        self.width = max(width, 0)
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.itemSpacing = min(max(itemSpacing, 0), 32)
        self.backgroundOpacity = min(max(backgroundOpacity, 0), 1)
        self.blurRadius = min(max(blurRadius, 0), 32)
        self.dividerOpacity = min(max(dividerOpacity, 0), 1)
        self.cornerRadius = min(max(cornerRadius, 0), 40)
        self.valueFontName = valueFontName
        self.valueFontSize = valueFontSize
        self.valueFontWeight = valueFontWeight
        self.valueColor = valueColor
        self.labelFontName = labelFontName
        self.labelFontSize = labelFontSize
        self.labelFontWeight = labelFontWeight
        self.labelColor = labelColor
        self.slots = slots
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        visible           = try c.decodeIfPresent(Bool.self,                        forKey: .visible)           ?? false
        placement         = try c.decodeIfPresent(RouteMapStatsBarPlacement.self,   forKey: .placement)         ?? .bottomAttached
        inside            = try c.decodeIfPresent(Bool.self,                        forKey: .inside)            ?? false
        layoutMode        = try c.decodeIfPresent(RouteMapStatsBarLayoutMode.self,  forKey: .layoutMode)        ?? .equalColumns
        height            = min(max(try c.decodeIfPresent(Double.self,              forKey: .height)            ?? 64,   32), 160)
        width             = max(try c.decodeIfPresent(Double.self,                  forKey: .width)             ?? 0,    0)
        offsetX           = try c.decodeIfPresent(Double.self,                      forKey: .offsetX)           ?? 0
        offsetY           = try c.decodeIfPresent(Double.self,                      forKey: .offsetY)           ?? 0
        itemSpacing       = min(max(try c.decodeIfPresent(Double.self,              forKey: .itemSpacing)       ?? 0,    0),  32)
        backgroundOpacity = min(max(try c.decodeIfPresent(Double.self,              forKey: .backgroundOpacity) ?? 0.88, 0),  1)
        blurRadius        = min(max(try c.decodeIfPresent(Double.self,              forKey: .blurRadius)        ?? 0,    0),  32)
        dividerOpacity    = min(max(try c.decodeIfPresent(Double.self,              forKey: .dividerOpacity)    ?? 0.12, 0),  1)
        cornerRadius      = min(max(try c.decodeIfPresent(Double.self,              forKey: .cornerRadius)      ?? 0,    0),  40)
        valueFontName     = try c.decodeIfPresent(String.self,                      forKey: .valueFontName)     ?? Self.default.valueFontName
        valueFontSize     = try c.decodeIfPresent(Double.self,                      forKey: .valueFontSize)     ?? Self.default.valueFontSize
        valueFontWeight   = try c.decodeIfPresent(OverlayFontWeight.self,           forKey: .valueFontWeight)   ?? Self.default.valueFontWeight
        valueColor        = try c.decodeIfPresent(OverlayColor.self,                forKey: .valueColor)        ?? Self.default.valueColor
        labelFontName     = try c.decodeIfPresent(String.self,                      forKey: .labelFontName)     ?? Self.default.labelFontName
        labelFontSize     = try c.decodeIfPresent(Double.self,                      forKey: .labelFontSize)     ?? Self.default.labelFontSize
        labelFontWeight   = try c.decodeIfPresent(OverlayFontWeight.self,           forKey: .labelFontWeight)   ?? Self.default.labelFontWeight
        labelColor        = try c.decodeIfPresent(OverlayColor.self,                forKey: .labelColor)        ?? Self.default.labelColor
        slots             = try c.decodeIfPresent([RouteMapStatsBarSlot].self,      forKey: .slots)             ?? Self.default.slots
    }
}

enum OverlayGaugePreset: String, CaseIterable, Identifiable, Codable {
    case minimalSport
    case highContrast
    case roadRun
    case trailAdventure
    case techFuture
    case retroDigital
    case premiumGlass

    var id: String { rawValue }

    var label: String {
        switch self {
        case .minimalSport: "Minimal Sport / 极简运动"
        case .highContrast: "High Contrast Sport / 高对比运动"
        case .roadRun: "Road Run / 公路跑风格"
        case .trailAdventure: "Trail Adventure / 越野探险"
        case .techFuture: "Future Tech / 科技未来"
        case .retroDigital: "Retro Digital / 复古数显"
        case .premiumGlass: "Premium Glass / 精致玻璃"
        }
    }
}

enum OverlayTextPreset: String, CaseIterable, Identifiable, Codable {
    // Canonical numeric overlay style presets. See `docs/design/overlays/numeric/numeric-overlay-ui.md`
    // and the brief in `assets/image-413a701b-...png`.
    case minimal           // Minimal Clean
    case minimalLabel      // Minimal Label
    case pillBadge         // Pill (compact + label modes)
    case metricCard        // Metric Card
    case bigNumber         // Big Number
    case splitLabel        // Split Label
    case neonGlow          // Neon Glow
    case racingStripe      // Racing Stripe
    case editorial         // Editorial
    case digitalWatch      // Digital Watch

    // Deprecated cases — kept for backward compatibility with previously
    // saved projects/templates. Hidden from the inspector preset picker.
    case sportWatch
    case inlineGhost
    case accentBar
    case sportNeon
    case serifEditorial

    var id: String { rawValue }

    var label: String {
        switch self {
        case .minimal: "Minimal Clean / 极简干净"
        case .minimalLabel: "Minimal Label / 极简标签"
        case .pillBadge: "Pill / 胶囊样式"
        case .metricCard: "Metric Card / 数据卡片"
        case .bigNumber: "Big Number / 大数字"
        case .splitLabel: "Split Label / 分离标签"
        case .neonGlow: "Neon Glow / 霓虹发光"
        case .racingStripe: "Racing Stripe / 竞速条"
        case .editorial: "Editorial / 杂志标题风"
        case .digitalWatch: "Digital Watch / 数字表盘风"
        case .sportWatch: "Sport Watch / 运动手表"
        case .inlineGhost: "Inline Ghost / 横向影子"
        case .accentBar: "Accent Bar / 强调竖线"
        case .sportNeon: "Sport Neon / 霓虹运动"
        case .serifEditorial: "Serif Editorial / 衬线刊物"
        }
    }

    /// The canonical 10 numeric overlay presets the inspector picker should
    /// expose. Deprecated cases stay decodable but never appear in the menu.
    static let numericPresets: [OverlayTextPreset] = [
        .minimal, .minimalLabel, .pillBadge, .metricCard, .bigNumber,
        .splitLabel, .neonGlow, .racingStripe, .editorial, .digitalWatch
    ]

    /// Recommended typography/style tokens applied when the preset is picked.
    var recommendedTokens: OverlayPresetTokens? {
        // Use canonical `OverlayColor` constants so the inspector swatch strip
        // can highlight the active accent after a preset is applied.
        let blue = OverlayColor.blue
        let cyan = OverlayColor.cyan
        let orange = OverlayColor.orange
        let yellow = OverlayColor.yellow
        let phosphor = OverlayColor.green

        switch self {
        case .minimal:
            return OverlayPresetTokens(
                fontName: "SF Pro",
                fontWeight: .semibold,
                fontSize: 34,
                textAlignment: .leading,
                showLabel: false,
                showUnit: true,
                backgroundEnabled: false,
                backgroundColor: nil,
                backgroundOpacity: nil,
                backgroundRadius: 0,
                accentColor: blue
            )
        case .minimalLabel:
            return OverlayPresetTokens(
                fontName: "SF Pro",
                fontWeight: .semibold,
                fontSize: 34,
                textAlignment: .leading,
                showLabel: true,
                showUnit: true,
                backgroundEnabled: false,
                backgroundColor: nil,
                backgroundOpacity: nil,
                backgroundRadius: 0,
                accentColor: blue
            )
        case .pillBadge:
            return OverlayPresetTokens(
                fontName: "SF Pro",
                fontWeight: .bold,
                fontSize: 32,
                textAlignment: .leading,
                showLabel: false,
                showUnit: true,
                backgroundEnabled: true,
                backgroundColor: .black,
                backgroundOpacity: 0.48,
                backgroundRadius: 999,
                accentColor: blue
            )
        case .metricCard:
            return OverlayPresetTokens(
                fontName: "SF Pro",
                fontWeight: .bold,
                fontSize: 42,
                textAlignment: .leading,
                showLabel: true,
                showUnit: true,
                backgroundEnabled: true,
                backgroundColor: .black,
                backgroundOpacity: 0.50,
                backgroundRadius: 16,
                accentColor: blue
            )
        case .bigNumber:
            return OverlayPresetTokens(
                fontName: "SF Pro",
                fontWeight: .bold,
                fontSize: 82,
                textAlignment: .trailing,
                showLabel: false,
                showUnit: true,
                backgroundEnabled: false,
                backgroundColor: nil,
                backgroundOpacity: nil,
                backgroundRadius: 0,
                accentColor: blue
            )
        case .splitLabel:
            return OverlayPresetTokens(
                fontName: "SF Pro",
                fontWeight: .bold,
                fontSize: 42,
                textAlignment: .leading,
                showLabel: true,
                showUnit: true,
                backgroundEnabled: false,
                backgroundColor: nil,
                backgroundOpacity: nil,
                backgroundRadius: 0,
                accentColor: blue
            )
        case .neonGlow:
            return OverlayPresetTokens(
                fontName: "SF Pro",
                fontWeight: .bold,
                fontSize: 42,
                textAlignment: .leading,
                showLabel: false,
                showUnit: true,
                backgroundEnabled: false,
                backgroundColor: nil,
                backgroundOpacity: nil,
                backgroundRadius: 0,
                accentColor: cyan
            )
        case .racingStripe:
            return OverlayPresetTokens(
                fontName: "SF Pro",
                fontWeight: .bold,
                fontSize: 40,
                textAlignment: .leading,
                showLabel: true,
                showUnit: true,
                backgroundEnabled: true,
                backgroundColor: .black,
                backgroundOpacity: 0.50,
                backgroundRadius: 12,
                accentColor: orange
            )
        case .editorial:
            return OverlayPresetTokens(
                fontName: "SF Pro",
                fontWeight: .bold,
                fontSize: 64,
                textAlignment: .leading,
                showLabel: true,
                showUnit: true,
                backgroundEnabled: false,
                backgroundColor: nil,
                backgroundOpacity: nil,
                backgroundRadius: 0,
                accentColor: yellow
            )
        case .digitalWatch:
            return OverlayPresetTokens(
                fontName: BundledFontName.digitalWatch,
                fontWeight: .medium,
                fontSize: 40,
                textAlignment: .leading,
                showLabel: true,
                showUnit: true,
                backgroundEnabled: true,
                backgroundColor: .black,
                backgroundOpacity: 0.60,
                backgroundRadius: 10,
                accentColor: phosphor
            )
        case .sportWatch, .inlineGhost, .accentBar, .sportNeon, .serifEditorial:
            return nil
        }
    }
}

struct OverlayPresetTokens {
    var fontName: String
    var fontWeight: OverlayFontWeight
    var fontSize: Double
    var textAlignment: OverlayTextAlignment
    var showLabel: Bool
    var showUnit: Bool
    var labelPosition: OverlayTextAttachmentPosition = .top
    var unitPosition: OverlayTextAttachmentPosition = .trailing
    var labelFontSize: Double? = nil
    var labelFontWeight: OverlayFontWeight? = nil
    var unitFontSize: Double? = nil
    var unitFontWeight: OverlayFontWeight? = nil
    var backgroundEnabled: Bool
    var backgroundColor: OverlayColor?
    var backgroundOpacity: Double?
    var backgroundRadius: Double
    var accentColor: OverlayColor?
}

enum OverlayFontWeight: String, CaseIterable, Identifiable, Codable {
    case regular
    case medium
    case semibold
    case bold

    var id: String { rawValue }

    var label: String {
        switch self {
        case .regular: "Regular"
        case .medium: "Medium"
        case .semibold: "Semibold"
        case .bold: "Bold"
        }
    }
}

struct OverlayColor: Equatable, Hashable, Codable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    static let white = OverlayColor(red: 1, green: 1, blue: 1, alpha: 1)
    static let black = OverlayColor(red: 0, green: 0, blue: 0, alpha: 1)
    static let red = OverlayColor(red: 1, green: 0.24, blue: 0.2, alpha: 1)
    static let orange = OverlayColor(red: 1, green: 0.54, blue: 0.12, alpha: 1)
    static let yellow = OverlayColor(red: 1, green: 0.82, blue: 0.18, alpha: 1)
    static let green = OverlayColor(red: 0.25, green: 0.82, blue: 0.38, alpha: 1)
    static let blue = OverlayColor(red: 0.22, green: 0.58, blue: 1, alpha: 1)
    static let cyan = OverlayColor(red: 0.25, green: 0.75, blue: 1, alpha: 1)
    static let purple = OverlayColor(red: 0.56, green: 0.28, blue: 1, alpha: 1)
    static let pink = OverlayColor(red: 1, green: 0.28, blue: 0.43, alpha: 1)
}

// MARK: - Lap List

enum LapProgressMode: String, Equatable, Codable {
    case distance
    case time
}

enum LapListAnchor: String, CaseIterable, Identifiable, Equatable, Codable {
    case top
    case center
    case bottom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .top: "Top / 顶部"
        case .center: "Center / 居中"
        case .bottom: "Bottom / 底部"
        }
    }
}

enum LapColumnMetric: String, CaseIterable, Identifiable, Equatable, Codable {
    case lapNumber
    case lapKind
    case distance
    case elapsedTime
    case pace
    case heartRate
    case cadence
    case power
    case ascent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lapNumber: "Lap #"
        case .lapKind: "Type"
        case .distance: "Distance"
        case .elapsedTime: "Time"
        case .pace: "Pace"
        case .heartRate: "HR"
        case .cadence: "Cadence"
        case .power: "Power"
        case .ascent: "Ascent"
        }
    }
}

struct LapListColumn: Identifiable, Equatable, Codable {
    var metric: LapColumnMetric
    var visible: Bool

    var id: String { metric.rawValue }
}

struct LapListStyle: Equatable, Codable {
    var visibleRowCount: Int
    var currentRowAnchor: LapListAnchor
    var fadeEnabled: Bool
    var fadeMinOpacity: Double
    var progressBarEnabled: Bool
    var progressMode: LapProgressMode
    var progressColor: OverlayColor
    var progressOpacity: Double
    var showCompletedMark: Bool
    var rowHeight: Double
    var rowCornerRadius: Double
    var rowSpacing: Double
    var backgroundOpacity: Double
    var columns: [LapListColumn]

    static let `default` = LapListStyle(
        visibleRowCount: 5,
        currentRowAnchor: .center,
        fadeEnabled: true,
        fadeMinOpacity: 0.25,
        progressBarEnabled: true,
        progressMode: .distance,
        progressColor: .blue,
        progressOpacity: 0.35,
        showCompletedMark: false,
        rowHeight: 36,
        rowCornerRadius: 4,
        rowSpacing: 2,
        backgroundOpacity: 0.75,
        columns: [
            LapListColumn(metric: .lapNumber, visible: true),
            LapListColumn(metric: .lapKind, visible: true),
            LapListColumn(metric: .distance, visible: true),
            LapListColumn(metric: .elapsedTime, visible: true),
            LapListColumn(metric: .pace, visible: true),
            LapListColumn(metric: .heartRate, visible: false),
            LapListColumn(metric: .cadence, visible: false),
            LapListColumn(metric: .power, visible: false),
            LapListColumn(metric: .ascent, visible: false),
        ]
    )
}

// MARK: - Recovery Metric

/// Metrics that can be displayed in the recovery section of Lap Card / Lap Live
/// when the current lap kind is `.rest`.
enum RecoveryMetric: String, CaseIterable, Identifiable, Equatable, Codable {
    /// Peak HR recorded since the start of the current rest lap.
    case peakHR
    /// Current interpolated heart rate.
    case currentHR
    /// bpm dropped from the rest-lap peak to now.
    case hrDrop
    /// Percentage of peak HR that has been shed (drop / peak × 100).
    case hrDropPercent
    /// Time elapsed in the current rest lap (mm:ss).
    case restElapsedTime
    /// How many bpm the current HR is still above a user-configured target.
    case targetHRGap

    var id: String { rawValue }

    var label: String {
        switch self {
        case .peakHR: "Peak HR"
        case .currentHR: "HR Now"
        case .hrDrop: "HR Drop"
        case .hrDropPercent: "Drop %"
        case .restElapsedTime: "Rest Time"
        case .targetHRGap: "→ Target"
        }
    }
}

// MARK: - Lap Card

/// Columns shown in a Lap Card recap — superset of `LapColumnMetric` with `maxHR`.
enum LapCardColumn: String, CaseIterable, Identifiable, Equatable, Codable {
    case lapNumber
    case lapKind
    case distance
    case elapsedTime
    case pace
    case avgHR
    case maxHR
    case cadence
    case power
    case ascent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lapNumber: "Lap #"
        case .lapKind: "Type"
        case .distance: "Distance"
        case .elapsedTime: "Time"
        case .pace: "Avg Pace"
        case .avgHR: "Avg HR"
        case .maxHR: "Max HR"
        case .cadence: "Cadence"
        case .power: "Power"
        case .ascent: "Ascent"
        }
    }
}

struct LapCardColumnConfig: Identifiable, Equatable, Codable {
    var column: LapCardColumn
    var visible: Bool

    var id: String { column.rawValue }
}

struct LapCardStyle: Equatable, Codable {
    /// Width of the card in design units (before element.scale).
    var cardWidth: Double
    var cornerRadius: Double
    var backgroundOpacity: Double
    /// Ordered list of stat columns to display.
    var columns: [LapCardColumnConfig]
    /// When true, a recovery HR section is appended during rest laps.
    var showRecoverySection: Bool
    /// Recovery metrics shown in the recovery section.
    var recoveryMetrics: [RecoveryMetric]
    /// Target HR for `.targetHRGap`. 0 means the metric is disabled.
    var recoveryTargetHR: Int
    /// Show a recovery-progress bar toward the target HR.
    var recoveryProgressEnabled: Bool
    var progressColor: OverlayColor

    static let `default` = LapCardStyle(
        cardWidth: 280,
        cornerRadius: 8,
        backgroundOpacity: 0.80,
        columns: [
            LapCardColumnConfig(column: .lapNumber, visible: true),
            LapCardColumnConfig(column: .lapKind, visible: true),
            LapCardColumnConfig(column: .distance, visible: true),
            LapCardColumnConfig(column: .elapsedTime, visible: true),
            LapCardColumnConfig(column: .pace, visible: true),
            LapCardColumnConfig(column: .avgHR, visible: true),
            LapCardColumnConfig(column: .maxHR, visible: false),
            LapCardColumnConfig(column: .cadence, visible: false),
            LapCardColumnConfig(column: .power, visible: false),
            LapCardColumnConfig(column: .ascent, visible: false),
        ],
        showRecoverySection: true,
        recoveryMetrics: [.currentHR, .hrDrop, .hrDropPercent, .restElapsedTime],
        recoveryTargetHR: 0,
        recoveryProgressEnabled: false,
        progressColor: .blue
    )
}

// MARK: - Lap Live

/// Metrics shown in the active-lap panel of Lap Live.
enum LapLiveMetric: String, CaseIterable, Identifiable, Equatable, Codable {
    case lapElapsedTime
    case lapDistance
    case pace
    case heartRate
    case power
    case cadence

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lapElapsedTime: "Lap Time"
        case .lapDistance: "Lap Dist"
        case .pace: "Pace"
        case .heartRate: "HR"
        case .power: "Power"
        case .cadence: "Cadence"
        }
    }
}

enum LapLiveRestMode: String, CaseIterable, Identifiable, Equatable, Codable {
    /// Show the full recovery metrics section.
    case recovery
    /// Show a minimal condensed view (lap number + rest time only).
    case minimal
    /// Hide the overlay entirely during rest laps.
    case hidden

    var id: String { rawValue }

    var label: String {
        switch self {
        case .recovery: "Recovery Panel"
        case .minimal: "Minimal"
        case .hidden: "Hide"
        }
    }
}

struct LapLiveMetricConfig: Identifiable, Equatable, Codable {
    var metric: LapLiveMetric
    var visible: Bool

    var id: String { metric.rawValue }
}

struct LapLiveStyle: Equatable, Codable {
    var cardWidth: Double
    var cornerRadius: Double
    var backgroundOpacity: Double
    /// Metrics visible in active-lap mode.
    var activeMetrics: [LapLiveMetricConfig]
    /// Show a progress bar for the current lap.
    var showProgressBar: Bool
    var progressMode: LapProgressMode
    var progressColor: OverlayColor
    var progressOpacity: Double
    /// What to display when the current lap kind is `.rest`.
    var restMode: LapLiveRestMode
    /// Recovery metrics shown when restMode == .recovery.
    var recoveryMetrics: [RecoveryMetric]
    var recoveryTargetHR: Int
    var recoveryProgressEnabled: Bool

    static let `default` = LapLiveStyle(
        cardWidth: 240,
        cornerRadius: 8,
        backgroundOpacity: 0.80,
        activeMetrics: [
            LapLiveMetricConfig(metric: .lapElapsedTime, visible: true),
            LapLiveMetricConfig(metric: .lapDistance, visible: true),
            LapLiveMetricConfig(metric: .pace, visible: true),
            LapLiveMetricConfig(metric: .heartRate, visible: true),
            LapLiveMetricConfig(metric: .power, visible: false),
            LapLiveMetricConfig(metric: .cadence, visible: false),
        ],
        showProgressBar: true,
        progressMode: .distance,
        progressColor: .blue,
        progressOpacity: 0.35,
        restMode: .recovery,
        recoveryMetrics: [.currentHR, .hrDrop, .hrDropPercent, .restElapsedTime],
        recoveryTargetHR: 0,
        recoveryProgressEnabled: false
    )
}
