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
    var opacity: Double = 1
    var isVisible: Bool = true
    var isLocked: Bool = false
    var style: OverlayStyle
}

enum OverlayPasteCategory: String, Equatable {
    case numeric
    case distanceTimeline
    case elevationChart
    case runningGauge
    case intervalHUDBar
    case intervalTimeline
    case zoneEdgeBar
    case routeMap
    case weather
}

enum OverlayElementType: String, CaseIterable, Identifiable, Codable {
    case heartRate
    /// Current HR zone label (`Z1`…`Zn`) from Project Settings heart-rate zones.
    /// Same numeric overlay styling as `.heartRate` plus an optional mode that
    /// tints all text with the active zone’s palette color.
    case heartRateZone
    case pace
    case avgPace
    case lapPace
    case calories
    case elapsedTime
    case realTime
    case date
    case distance
    case distanceTimeline
    case elevation
    case elevationChart
    case cadence
    case power
    case runningGauge
    case intervalHUDBar
    case intervalTimeline
    case zoneEdgeBar
    case routeMap
    case verticalOscillation
    case groundContactTime
    case strideLength
    case verticalRatio
    case groundContactBalance
    case temperature
    case grade
    case weatherWidget
    case decorSolidColor
    case decorIcon
    case decorText

    var id: String { rawValue }

    var label: String {
        switch self {
        case .heartRate: "Heart Rate"
        case .heartRateZone: "HR Zone"
        case .pace: "Pace"
        case .avgPace: "Avg Pace"
        case .lapPace: "Lap Pace"
        case .calories: "Calories"
        case .elapsedTime: "Elapsed Time"
        case .realTime: "Real Time"
        case .date: "Date"
        case .distance: "Distance"
        case .distanceTimeline: "Distance Timeline"
        case .elevation: "Elevation"
        case .elevationChart: "Elevation Chart"
        case .cadence: "Cadence"
        case .power: "Power"
        case .runningGauge: "Running Gauge"
        case .intervalHUDBar: "Interval HUD Bar"
        case .intervalTimeline: "Interval Timeline"
        case .zoneEdgeBar: "Zone Edge Bar"
        case .routeMap: "Route Map"
        case .verticalOscillation: "Vertical Oscillation"
        case .groundContactTime: "Ground Contact Time"
        case .strideLength: "Stride Length"
        case .verticalRatio: "Vertical Ratio"
        case .groundContactBalance: "GCT Balance"
        case .temperature: "Temperature"
        case .grade: "Grade"
        case .weatherWidget: "Weather Widget"
        case .decorSolidColor: "Solid Color"
        case .decorIcon: "Icon"
        case .decorText: "Text"
        }
    }

    var supportsTextPresets: Bool {
        switch self {
        case .distanceTimeline, .elevationChart, .runningGauge, .intervalHUDBar, .intervalTimeline, .zoneEdgeBar, .routeMap,
             .weatherWidget, .decorSolidColor, .decorIcon, .decorText:
            false
        default:
            true
        }
    }

    /// Decor overlays are activity-data-independent visual elements
    /// (Solid Color shapes, Icons, free-form Text).
    var isDecorOverlay: Bool {
        switch self {
        case .decorSolidColor, .decorIcon, .decorText: true
        default: false
        }
    }

    /// Numeric Overlay template applies to type-derived metric overlays only.
    /// See `docs/design/overlays/numeric/numeric-overlay-ui.md`.
    var isNumericOverlay: Bool {
        switch self {
        case .heartRate, .heartRateZone, .pace, .avgPace, .lapPace, .calories, .elapsedTime, .realTime, .date,
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

    var defaultNumericIconSystemName: String {
        switch self {
        case .heartRate: "heart"
        case .heartRateZone: "heart.text.square.fill"
        case .pace, .avgPace: "speedometer"
        case .lapPace: "flag.checkered"
        case .calories: "flame"
        case .elapsedTime: "clock"
        case .realTime: "watch.analog"
        case .date: "calendar"
        case .distance: "ruler"
        case .elevation: "mountain.2"
        case .cadence: "figure.run"
        case .power: "bolt"
        case .verticalOscillation: "arrow.up.and.down"
        case .groundContactTime: "timer"
        case .strideLength: "arrow.left.and.right"
        case .verticalRatio: "percent"
        case .groundContactBalance: "scale.3d"
        case .temperature: "thermometer"
        case .grade: "arrow.up.right"
        case .distanceTimeline: "waveform.path.ecg"
        case .elevationChart: "chart.line.uptrend.xyaxis"
        case .runningGauge: "gauge"
        case .intervalHUDBar: "rectangle.split.3x1"
        case .intervalTimeline: "timeline.selection"
        case .zoneEdgeBar: "rectangle.compress.vertical"
        case .routeMap: "map"
        case .weatherWidget: "cloud.sun.fill"
        case .decorSolidColor: "square.fill"
        case .decorIcon: "star"
        case .decorText: "textformat"
        }
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
        case .intervalHUDBar:
            return .intervalHUDBar
        case .intervalTimeline:
            return .intervalTimeline
        case .zoneEdgeBar:
            return .zoneEdgeBar
        case .routeMap:
            return .routeMap
        case .weatherWidget:
            return .weather
        default:
            return .numeric
        }
    }
}

enum ActivityMetricCatalog {
    static let selectableElementTypes: [OverlayElementType] = OverlayElementType.allCases.filter {
        $0.isNumericOverlay && $0 != .heartRateZone && $0 != .date
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
    case dateYMDHyphen
    case dateYMDSlash
    case dateMDYSlash
    case dateMDHyphen
    case dateMDSlash
    case dateMonthDay
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
        case .dateYMDHyphen: "YYYY-MM-DD"
        case .dateYMDSlash: "YYYY/MM/DD"
        case .dateMDYSlash: "MM/DD/YYYY"
        case .dateMDHyphen: "MM-DD"
        case .dateMDSlash: "MM/DD"
        case .dateMonthDay: "Month D"
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
        case .heartRateZone: []
        case .pace, .avgPace, .lapPace: [.paceMetric, .paceImperial, .paceRowing]
        case .distance: [.distanceKilometers, .distanceMiles, .distanceMeters]
        case .elevation: [.elevationMeters, .elevationFeet]
        case .power: [.watts]
        case .cadence: [.spm]
        case .calories: [.kcal]
        case .elapsedTime: [.durationHMS, .durationMS, .durationSeconds]
        case .realTime: [.clock24Hour, .clock12Hour]
        case .date: [.dateYMDHyphen, .dateYMDSlash, .dateMDYSlash, .dateMDHyphen, .dateMDSlash, .dateMonthDay]
        case .verticalOscillation: [.oscillationCentimeters, .oscillationMillimeters]
        case .groundContactTime: [.contactTimeMilliseconds]
        case .strideLength: [.strideLengthMeters]
        case .verticalRatio: [.verticalRatioPercent]
        case .groundContactBalance: [.balancePercent]
        case .temperature: [.temperatureCelsius, .temperatureFahrenheit]
        case .grade: [.gradePercent]
        case .distanceTimeline, .elevationChart, .runningGauge, .intervalHUDBar, .intervalTimeline, .zoneEdgeBar, .routeMap,
             .weatherWidget, .decorSolidColor, .decorIcon, .decorText:
            []
        }
    }

    static func defaultOption(for type: OverlayElementType) -> OverlayUnitOption {
        if let first = options(for: type).first {
            return first
        }
        return .bpm
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

enum OverlayElevationDisplayMode: String, CaseIterable, Identifiable, Codable {
    case current
    case gain

    var id: String { rawValue }

    var label: String {
        switch self {
        case .current: "Current"
        case .gain: "Gain"
        }
    }
}

struct OverlayStyle: Equatable, Codable {
    var textPreset: OverlayTextPreset
    var gaugePreset: OverlayGaugePreset
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
    var routeMapRunnerMarkerStyle: OverlayRouteMapMarkerStyle
    var routeMapStartMarkerColor: OverlayColor
    var routeMapEndMarkerColor: OverlayColor
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
    var elevationDisplayMode: OverlayElevationDisplayMode
    var useFITTemperature: Bool
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
    var iconEnabled: Bool
    var iconSystemName: String
    var iconPosition: OverlayTextAttachmentPosition
    var iconTextAlignment: OverlayTextAlignment
    var iconSize: Double
    var iconColor: OverlayColor
    var iconOpacity: Double
    var iconSpacing: Double
    /// When true and the overlay is `.heartRate` or `.heartRateZone`, the
    /// numeric icon paints from `HRZonePalette` for the active zone instead of
    /// the static icon swatch. Ignored for all other overlay types.
    var iconColorsFollowHeartRateZones: Bool
    /// When true and the overlay is `.heartRate` or `.heartRateZone`, the
    /// numeric value text paints from `HRZonePalette` for the active zone
    /// instead of the value swatch. Ignored for all other overlay types.
    var valueColorsFollowHeartRateZones: Bool
    /// When true and the overlay is `.heartRate` or `.heartRateZone`, the
    /// numeric label text paints from `HRZonePalette` for the active zone
    /// instead of the label swatch. Ignored for all other overlay types.
    var labelColorsFollowHeartRateZones: Bool
    /// When true and the overlay is `.heartRate` or `.heartRateZone`, the
    /// numeric unit text paints from `HRZonePalette` for the active zone
    /// instead of the unit swatch. Ignored for all other overlay types.
    var unitColorsFollowHeartRateZones: Bool
    var rotationDegrees: Double
    var textAlignment: OverlayTextAlignment
    /// Alignment of the numeric overlay label text. Interpreted in the context
    /// of `labelPosition`: when the label sits above/below the value the field
    /// controls horizontal alignment (left/center/right); when it sits to the
    /// left or right of the value it controls vertical alignment
    /// (top/middle/bottom). Three discrete options; reuses `OverlayTextAlignment`.
    var labelTextAlignment: OverlayTextAlignment
    /// Alignment of the numeric overlay unit text. Interpreted in the context
    /// of `unitPosition`: when the unit sits above/below the value it controls
    /// horizontal alignment on its own row; when it sits to the left or right
    /// of the value (minimal preset) it controls vertical alignment of the unit
    /// relative to the value in that row. Reuses `OverlayTextAlignment`. Inline
    /// positions still baseline-lock to the value for horizontal layout; the
    /// `bigNumber` preset keeps the unit under the value with horizontal align.
    var unitTextAlignment: OverlayTextAlignment
    var accentColor: OverlayColor
    /// Numeric overlay divider — the decorative line that appears between the
    /// value and the label in presets that include one (splitLabel, editorial,
    /// pillBadge, racingStripe, sportWatch). Position/orientation is owned by
    /// the preset; these four fields control its visibility and style and
    /// follow the project-wide divider quad convention.
    var dividerEnabled: Bool
    var dividerColor: OverlayColor
    var dividerThickness: Double
    var dividerOpacity: Double
    var backgroundEnabled: Bool
    var backgroundColor: OverlayColor
    var backgroundRadius: Double
    var backgroundPaddingX: Double
    var backgroundPaddingY: Double
    /// Optional minimum frame for numeric text overlays in design units.
    /// Zero keeps the overlay sized from its rendered text.
    var numericMinWidth: Double
    var numericMinHeight: Double
    var backgroundFadeOutEnabled: Bool
    var backgroundFadeOutAmount: Double
    var backgroundBlurRadius: Double
    var borderEnabled: Bool
    var borderColor: OverlayColor
    var borderOpacity: Double
    var borderWidth: Double
    var shadowEnabled: Bool
    var shadowColor: OverlayColor
    var shadowOffsetX: Double
    var shadowOffsetY: Double
    var shadowThickness: Double
    var glowEnabled: Bool
    var glowColor: OverlayColor
    var glowIntensity: Double
    /// When true and the overlay is `.heartRateZone`, value/label/unit text
    /// paint from `HRZonePalette` for the active zone instead of the
    /// per-role swatches. Ignored for all other overlay types.
    var textColorsFollowHeartRateZones: Bool

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

    /// Decor element configuration. Used by `.decorSolidColor`, `.decorIcon`,
    /// `.decorText`. See `DecorStyle`.
    var decor: DecorStyle

    /// Weather Widget configuration. Used only by `.weatherWidget`.
    var weatherWidget: WeatherWidgetStyle

    /// Interval HUD Bar configuration. Used only by `.intervalHUDBar`.
    var intervalHUDBar: IntervalHUDBarStyle

    /// Interval Timeline configuration. Used only by `.intervalTimeline`.
    var intervalTimeline: IntervalTimelineStyle

    /// Zone Edge Bar configuration. Used only by `.zoneEdgeBar`.
    var zoneEdgeBar: ZoneEdgeBarStyle

    static let `default` = OverlayStyle(
        textPreset: .minimal,
        gaugePreset: .minimalSport,
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
        routeMapRunnerMarkerStyle: .dot,
        routeMapStartMarkerColor: .green,
        routeMapEndMarkerColor: .routeMapEndCheckerboard,
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
        fontName: FontLibraryManager.currentDefaultFamily,
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
        elevationDisplayMode: .current,
        useFITTemperature: true,
        showLabel: false,
        showUnit: true,
        customLabel: "",
        labelPosition: .top,
        unitPosition: .trailing,
        labelFontName: FontLibraryManager.currentDefaultFamily,
        labelFontSize: 16,
        labelFontWeight: .medium,
        labelSpacing: 8,
        unitFontName: FontLibraryManager.currentDefaultFamily,
        unitFontSize: 20,
        unitFontWeight: .medium,
        unitSpacing: 8,
        iconEnabled: true,
        iconSystemName: "",
        iconPosition: .leading,
        iconTextAlignment: .center,
        iconSize: 22,
        iconColor: .white,
        iconOpacity: 1,
        iconSpacing: 8,
        iconColorsFollowHeartRateZones: false,
        valueColorsFollowHeartRateZones: false,
        labelColorsFollowHeartRateZones: false,
        unitColorsFollowHeartRateZones: false,
        rotationDegrees: 0,
        textAlignment: .leading,
        labelTextAlignment: .leading,
        unitTextAlignment: .leading,
        accentColor: .blue,
        dividerEnabled: true,
        dividerColor: .white,
        dividerThickness: 2,
        dividerOpacity: 0.85,
        backgroundEnabled: true,
        backgroundColor: .black,
        backgroundRadius: 6,
        backgroundPaddingX: 10,
        backgroundPaddingY: 6,
        numericMinWidth: 0,
        numericMinHeight: 0,
        backgroundFadeOutEnabled: false,
        backgroundFadeOutAmount: 0.22,
        backgroundBlurRadius: 0,
        borderEnabled: false,
        borderColor: .white,
        borderOpacity: 0.22,
        borderWidth: 1,
        shadowEnabled: true,
        shadowColor: .black,
        shadowOffsetX: 0,
        shadowOffsetY: 2,
        shadowThickness: 1,
        glowEnabled: false,
        glowColor: .white,
        glowIntensity: 0,
        textColorsFollowHeartRateZones: false,
        distanceTimeline: .default,
        elevationChart: .default,
        gauge: RunningGaugeStyle.default,
        routeMapStatsBar: .default,
        decor: .default,
        weatherWidget: .preset(.simpleCard),
        intervalHUDBar: .default,
        intervalTimeline: .default,
        zoneEdgeBar: .default
    )

    init(
        textPreset: OverlayTextPreset = .minimal,
        gaugePreset: OverlayGaugePreset = .minimalSport,
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
        routeMapRunnerMarkerStyle: OverlayRouteMapMarkerStyle = .dot,
        routeMapStartMarkerColor: OverlayColor = .green,
        routeMapEndMarkerColor: OverlayColor = .routeMapEndCheckerboard,
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
        elevationDisplayMode: OverlayElevationDisplayMode = .current,
        useFITTemperature: Bool = true,
        showLabel: Bool = false,
        showUnit: Bool = true,
        customLabel: String = "",
        labelPosition: OverlayTextAttachmentPosition = .top,
        unitPosition: OverlayTextAttachmentPosition = .trailing,
        labelFontName: String = FontLibraryManager.currentDefaultFamily,
        labelFontSize: Double = 16,
        labelFontWeight: OverlayFontWeight = .medium,
        labelSpacing: Double = 8,
        unitFontName: String = FontLibraryManager.currentDefaultFamily,
        unitFontSize: Double = 20,
        unitFontWeight: OverlayFontWeight = .medium,
        unitSpacing: Double = 8,
        iconEnabled: Bool = true,
        iconSystemName: String = "",
        iconPosition: OverlayTextAttachmentPosition = .leading,
        iconTextAlignment: OverlayTextAlignment = .center,
        iconSize: Double = 22,
        iconColor: OverlayColor = .white,
        iconOpacity: Double = 1,
        iconSpacing: Double = 8,
        iconColorsFollowHeartRateZones: Bool = false,
        valueColorsFollowHeartRateZones: Bool = false,
        labelColorsFollowHeartRateZones: Bool = false,
        unitColorsFollowHeartRateZones: Bool = false,
        rotationDegrees: Double = 0,
        textAlignment: OverlayTextAlignment = .leading,
        labelTextAlignment: OverlayTextAlignment = .leading,
        unitTextAlignment: OverlayTextAlignment = .leading,
        accentColor: OverlayColor = .blue,
        dividerEnabled: Bool = true,
        dividerColor: OverlayColor = .white,
        dividerThickness: Double = 2,
        dividerOpacity: Double = 0.85,
        backgroundEnabled: Bool = true,
        backgroundColor: OverlayColor = .black,
        backgroundRadius: Double = 6,
        backgroundPaddingX: Double = 10,
        backgroundPaddingY: Double = 6,
        numericMinWidth: Double = 0,
        numericMinHeight: Double = 0,
        backgroundFadeOutEnabled: Bool = false,
        backgroundFadeOutAmount: Double = 0.22,
        backgroundBlurRadius: Double = 0,
        borderEnabled: Bool = false,
        borderColor: OverlayColor = .white,
        borderOpacity: Double = 0.22,
        borderWidth: Double = 1,
        shadowEnabled: Bool = true,
        shadowColor: OverlayColor = .black,
        shadowOffsetX: Double = 0,
        shadowOffsetY: Double = 2,
        shadowThickness: Double = 1,
        glowEnabled: Bool = false,
        glowColor: OverlayColor = .white,
        glowIntensity: Double = 0,
        textColorsFollowHeartRateZones: Bool = false,
        distanceTimeline: DistanceTimelineStyle = .default,
        elevationChart: ElevationChartStyle = .default,
        gauge: RunningGaugeStyle = .default,
        routeMapStatsBar: OverlayRouteMapStatsBarConfig = .default,
        decor: DecorStyle = .default,
        weatherWidget: WeatherWidgetStyle = .preset(.simpleCard),
        intervalHUDBar: IntervalHUDBarStyle = .default,
        intervalTimeline: IntervalTimelineStyle = .default,
        zoneEdgeBar: ZoneEdgeBarStyle = .default
    ) {
        self.textPreset = textPreset
        self.gaugePreset = gaugePreset
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
        self.routeMapRunnerMarkerStyle = routeMapRunnerMarkerStyle
        self.routeMapStartMarkerColor = routeMapStartMarkerColor
        self.routeMapEndMarkerColor = routeMapEndMarkerColor
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
        self.elevationDisplayMode = elevationDisplayMode
        self.useFITTemperature = useFITTemperature
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
        self.iconEnabled = iconEnabled
        self.iconSystemName = iconSystemName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.iconPosition = iconPosition
        self.iconTextAlignment = iconTextAlignment
        self.iconSize = min(max(iconSize, 8), 96)
        self.iconColor = iconColor
        self.iconOpacity = min(max(iconOpacity, 0), 1)
        self.iconSpacing = min(max(iconSpacing, 0), 60)
        self.iconColorsFollowHeartRateZones = iconColorsFollowHeartRateZones
        self.valueColorsFollowHeartRateZones = valueColorsFollowHeartRateZones
        self.labelColorsFollowHeartRateZones = labelColorsFollowHeartRateZones
        self.unitColorsFollowHeartRateZones = unitColorsFollowHeartRateZones
        self.rotationDegrees = rotationDegrees
        self.textAlignment = textAlignment
        self.labelTextAlignment = labelTextAlignment
        self.unitTextAlignment = unitTextAlignment
        self.accentColor = accentColor
        self.dividerEnabled = dividerEnabled
        self.dividerColor = dividerColor
        self.dividerThickness = min(max(dividerThickness, 0), 16)
        self.dividerOpacity = min(max(dividerOpacity, 0), 1)
        self.backgroundEnabled = backgroundEnabled
        self.backgroundColor = backgroundColor
        self.backgroundRadius = backgroundRadius
        self.backgroundPaddingX = backgroundPaddingX
        self.backgroundPaddingY = backgroundPaddingY
        self.numericMinWidth = min(max(numericMinWidth, 0), 720)
        self.numericMinHeight = min(max(numericMinHeight, 0), 360)
        self.backgroundFadeOutEnabled = backgroundFadeOutEnabled
        self.backgroundFadeOutAmount = backgroundFadeOutAmount
        self.backgroundBlurRadius = backgroundBlurRadius
        self.borderEnabled = borderEnabled
        self.borderColor = borderColor
        self.borderOpacity = borderOpacity
        self.borderWidth = borderWidth
        self.shadowEnabled = shadowEnabled
        self.shadowColor = shadowColor
        self.shadowOffsetX = shadowOffsetX
        self.shadowOffsetY = shadowOffsetY
        self.shadowThickness = shadowThickness
        self.glowEnabled = glowEnabled
        self.glowColor = glowColor
        self.glowIntensity = glowIntensity
        self.textColorsFollowHeartRateZones = textColorsFollowHeartRateZones
        self.distanceTimeline = distanceTimeline
        self.elevationChart = elevationChart
        self.gauge = gauge
        self.routeMapStatsBar = routeMapStatsBar
        self.decor = decor
        self.weatherWidget = weatherWidget
        self.intervalHUDBar = intervalHUDBar
        self.intervalTimeline = intervalTimeline
        self.zoneEdgeBar = zoneEdgeBar
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        textPreset = try container.decodeIfPresent(OverlayTextPreset.self, forKey: .textPreset) ?? Self.default.textPreset
        gaugePreset = try container.decodeIfPresent(OverlayGaugePreset.self, forKey: .gaugePreset) ?? Self.default.gaugePreset
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
        routeMapRunnerMarkerStyle = try container.decodeIfPresent(OverlayRouteMapMarkerStyle.self, forKey: .routeMapRunnerMarkerStyle) ?? Self.default.routeMapRunnerMarkerStyle
        routeMapStartMarkerColor = try container.decodeIfPresent(OverlayColor.self, forKey: .routeMapStartMarkerColor) ?? Self.default.routeMapStartMarkerColor
        routeMapEndMarkerColor = try container.decodeIfPresent(OverlayColor.self, forKey: .routeMapEndMarkerColor) ?? Self.default.routeMapEndMarkerColor
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
        elevationDisplayMode = try container.decodeIfPresent(OverlayElevationDisplayMode.self, forKey: .elevationDisplayMode) ?? Self.default.elevationDisplayMode
        useFITTemperature = try container.decodeIfPresent(Bool.self, forKey: .useFITTemperature) ?? Self.default.useFITTemperature
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
        iconEnabled = try container.decodeIfPresent(Bool.self, forKey: .iconEnabled) ?? Self.default.iconEnabled
        let decodedIconName = try container.decodeIfPresent(String.self, forKey: .iconSystemName) ?? Self.default.iconSystemName
        iconSystemName = decodedIconName.trimmingCharacters(in: .whitespacesAndNewlines)
        iconPosition = try container.decodeIfPresent(OverlayTextAttachmentPosition.self, forKey: .iconPosition) ?? Self.default.iconPosition
        iconTextAlignment = try container.decodeIfPresent(OverlayTextAlignment.self, forKey: .iconTextAlignment) ?? Self.default.iconTextAlignment
        iconSize = min(max(try container.decodeIfPresent(Double.self, forKey: .iconSize) ?? Self.default.iconSize, 8), 96)
        iconColor = try container.decodeIfPresent(OverlayColor.self, forKey: .iconColor) ?? foregroundColor
        iconOpacity = min(max(try container.decodeIfPresent(Double.self, forKey: .iconOpacity) ?? Self.default.iconOpacity, 0), 1)
        iconSpacing = min(max(try container.decodeIfPresent(Double.self, forKey: .iconSpacing) ?? Self.default.iconSpacing, 0), 60)
        iconColorsFollowHeartRateZones = try container.decodeIfPresent(Bool.self, forKey: .iconColorsFollowHeartRateZones) ?? Self.default.iconColorsFollowHeartRateZones
        let legacyTextColorsFollowHeartRateZones = try container.decodeIfPresent(Bool.self, forKey: .textColorsFollowHeartRateZones) ?? Self.default.textColorsFollowHeartRateZones
        valueColorsFollowHeartRateZones = try container.decodeIfPresent(Bool.self, forKey: .valueColorsFollowHeartRateZones) ?? legacyTextColorsFollowHeartRateZones
        labelColorsFollowHeartRateZones = try container.decodeIfPresent(Bool.self, forKey: .labelColorsFollowHeartRateZones) ?? legacyTextColorsFollowHeartRateZones
        unitColorsFollowHeartRateZones = try container.decodeIfPresent(Bool.self, forKey: .unitColorsFollowHeartRateZones) ?? legacyTextColorsFollowHeartRateZones
        rotationDegrees = try container.decodeIfPresent(Double.self, forKey: .rotationDegrees) ?? Self.default.rotationDegrees
        textAlignment = try container.decodeIfPresent(OverlayTextAlignment.self, forKey: .textAlignment) ?? Self.default.textAlignment
        labelTextAlignment = try container.decodeIfPresent(OverlayTextAlignment.self, forKey: .labelTextAlignment) ?? Self.default.labelTextAlignment
        unitTextAlignment = try container.decodeIfPresent(OverlayTextAlignment.self, forKey: .unitTextAlignment) ?? Self.default.unitTextAlignment
        accentColor = try container.decodeIfPresent(OverlayColor.self, forKey: .accentColor) ?? Self.default.accentColor
        dividerEnabled = try container.decodeIfPresent(Bool.self, forKey: .dividerEnabled) ?? Self.default.dividerEnabled
        dividerColor = try container.decodeIfPresent(OverlayColor.self, forKey: .dividerColor) ?? Self.default.dividerColor
        dividerThickness = min(max(try container.decodeIfPresent(Double.self, forKey: .dividerThickness) ?? Self.default.dividerThickness, 0), 16)
        dividerOpacity = min(max(try container.decodeIfPresent(Double.self, forKey: .dividerOpacity) ?? Self.default.dividerOpacity, 0), 1)
        backgroundEnabled = try container.decodeIfPresent(Bool.self, forKey: .backgroundEnabled) ?? Self.default.backgroundEnabled
        backgroundColor = try container.decodeIfPresent(OverlayColor.self, forKey: .backgroundColor) ?? Self.default.backgroundColor
        backgroundRadius = try container.decodeIfPresent(Double.self, forKey: .backgroundRadius) ?? Self.default.backgroundRadius
        backgroundPaddingX = try container.decodeIfPresent(Double.self, forKey: .backgroundPaddingX) ?? Self.default.backgroundPaddingX
        backgroundPaddingY = try container.decodeIfPresent(Double.self, forKey: .backgroundPaddingY) ?? Self.default.backgroundPaddingY
        numericMinWidth = min(max(try container.decodeIfPresent(Double.self, forKey: .numericMinWidth) ?? Self.default.numericMinWidth, 0), 720)
        numericMinHeight = min(max(try container.decodeIfPresent(Double.self, forKey: .numericMinHeight) ?? Self.default.numericMinHeight, 0), 360)
        backgroundFadeOutEnabled = try container.decodeIfPresent(Bool.self, forKey: .backgroundFadeOutEnabled) ?? Self.default.backgroundFadeOutEnabled
        backgroundFadeOutAmount = min(max(try container.decodeIfPresent(Double.self, forKey: .backgroundFadeOutAmount) ?? Self.default.backgroundFadeOutAmount, 0), 1)
        backgroundBlurRadius = max(try container.decodeIfPresent(Double.self, forKey: .backgroundBlurRadius) ?? Self.default.backgroundBlurRadius, 0)
        borderEnabled = try container.decodeIfPresent(Bool.self, forKey: .borderEnabled) ?? Self.default.borderEnabled
        borderColor = try container.decodeIfPresent(OverlayColor.self, forKey: .borderColor) ?? Self.default.borderColor
        borderOpacity = min(max(try container.decodeIfPresent(Double.self, forKey: .borderOpacity) ?? Self.default.borderOpacity, 0), 1)
        borderWidth = min(max(try container.decodeIfPresent(Double.self, forKey: .borderWidth) ?? Self.default.borderWidth, 0.5), 12)
        shadowEnabled = try container.decodeIfPresent(Bool.self, forKey: .shadowEnabled) ?? Self.default.shadowEnabled
        shadowColor = try container.decodeIfPresent(OverlayColor.self, forKey: .shadowColor) ?? Self.default.shadowColor
        shadowOffsetX = try container.decodeIfPresent(Double.self, forKey: .shadowOffsetX) ?? Self.default.shadowOffsetX
        shadowOffsetY = try container.decodeIfPresent(Double.self, forKey: .shadowOffsetY) ?? Self.default.shadowOffsetY
        shadowThickness = min(max(try container.decodeIfPresent(Double.self, forKey: .shadowThickness) ?? Self.default.shadowThickness, 1), 4)
        glowEnabled = try container.decodeIfPresent(Bool.self, forKey: .glowEnabled) ?? Self.default.glowEnabled
        glowColor = try container.decodeIfPresent(OverlayColor.self, forKey: .glowColor) ?? Self.default.glowColor
        glowIntensity = min(max(try container.decodeIfPresent(Double.self, forKey: .glowIntensity) ?? Self.default.glowIntensity, 0), 1)
        textColorsFollowHeartRateZones = legacyTextColorsFollowHeartRateZones
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
        decor = try container.decodeIfPresent(DecorStyle.self, forKey: .decor) ?? .default
        weatherWidget = try container.decodeIfPresent(WeatherWidgetStyle.self, forKey: .weatherWidget) ?? .preset(.simpleCard)
        intervalHUDBar = try container.decodeIfPresent(IntervalHUDBarStyle.self, forKey: .intervalHUDBar) ?? .default
        intervalTimeline = try container.decodeIfPresent(IntervalTimelineStyle.self, forKey: .intervalTimeline) ?? .default
        zoneEdgeBar = try container.decodeIfPresent(ZoneEdgeBarStyle.self, forKey: .zoneEdgeBar) ?? .default
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
    case techGlow
    case minimalWhite
    case bigNumbers

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gradientArea: "Premium Gradient"
        case .dualArea: "Dark Terrain"
        case .techGlow: "Tech Glow"
        case .minimalWhite: "Minimal White"
        case .bigNumbers: "Big Elevation"
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
    static let widthRange: ClosedRange<Double> = 220...1200
    static let heightRange: ClosedRange<Double> = 72...320

    var preset: ElevationChartPreset
    var width: Double
    var height: Double
    var chartStyle: ElevationChartRenderStyle
    var smoothingEnabled: Bool
    var smoothingAmount: Double
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
    var markerPlayheadLineEnabled: Bool
    var markerLabelEnabled: Bool
    var gridEnabled: Bool
    var axisLineEnabled: Bool
    var axisLabelsEnabled: Bool
    var bigNumbersEnabled: Bool
    var bigNumberMetric: ElevationChartBigMetric
    var bigNumberFontSize: Double
    var bigNumberFontName: String
    var bigNumberFontWeight: OverlayFontWeight
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
            height: preset == .bigNumbers ? 190 : 178,
            chartStyle: .area,
            smoothingEnabled: true,
            smoothingAmount: 0.85,
            progressMode: .fullProfile,
            chartPaddingX: 18,
            chartPaddingY: 16,
            lineColor: .white,
            lineWidth: preset == .bigNumbers ? 2.2 : 2.5,
            lineOpacity: 0.96,
            fillEnabled: true,
            fillStartColor: .green,
            fillEndColor: .blue,
            fillOpacity: preset == .bigNumbers ? 0.34 : 0.40,
            dualAreaEnabled: false,
            upperFillColor: .orange,
            lowerFillColor: .cyan,
            currentMarkerEnabled: true,
            markerColor: .blue,
            markerPlayheadLineEnabled: true,
            markerLabelEnabled: true,
            gridEnabled: false,
            axisLineEnabled: true,
            axisLabelsEnabled: true,
            bigNumbersEnabled: preset == .bigNumbers,
            bigNumberMetric: .currentElevation,
            bigNumberFontSize: preset == .bigNumbers ? 58 : 42,
            bigNumberFontName: FontLibraryManager.currentDefaultFamily,
            bigNumberFontWeight: .semibold,
            backgroundEnabled: true,
            backgroundColor: .black,
            backgroundOpacity: 0.42,
            cornerRadius: 18,
            borderEnabled: true,
            borderOpacity: 0.10,
            shadowEnabled: true,
            shadowOpacity: 0.28,
            shadowRadius: 18,
            glowEnabled: false,
            glowOpacity: 0.25,
            statsBar: ElevationChartStyle.defaultStatsBar
        )
        switch preset {
        case .gradientArea:
            break
        case .dualArea:
            style.dualAreaEnabled = true
            style.fillStartColor = OverlayColor.orange
            style.fillEndColor = OverlayColor(red: 0.18, green: 0.26, blue: 0.34, alpha: 1)
            style.upperFillColor = OverlayColor.green
            style.lowerFillColor = OverlayColor.orange
            style.markerColor = OverlayColor.orange
            style.backgroundOpacity = 0.50
            style.shadowOpacity = 0.30
            style.statsBar.slots = [
                DistanceTimelineStatsBarSlot(metric: .distance, visible: true, customLabel: ""),
                DistanceTimelineStatsBarSlot(metric: .elevation, visible: true, customLabel: "ELEV"),
                DistanceTimelineStatsBarSlot(metric: .elapsedTime, visible: true, customLabel: ""),
                DistanceTimelineStatsBarSlot(metric: .grade, visible: false, customLabel: ""),
            ]
        case .techGlow:
            style.lineColor = OverlayColor.cyan
            style.fillStartColor = OverlayColor.cyan
            style.fillEndColor = OverlayColor.blue
            style.markerColor = OverlayColor.cyan
            style.gridEnabled = true
            style.glowEnabled = true
            style.glowOpacity = 0.45
            style.backgroundOpacity = 0.46
            style.borderOpacity = 0.12
            style.shadowOpacity = 0.32
            style.shadowRadius = 20
            style.statsBar.backgroundOpacity = 0.50
        case .minimalWhite:
            style.chartStyle = .lineOnly
            style.fillEnabled = false
            style.markerColor = .white
            style.markerLabelEnabled = false
            style.markerPlayheadLineEnabled = false
            style.axisLineEnabled = false
            style.axisLabelsEnabled = false
            style.gridEnabled = false
            style.statsBar.visible = false
            style.backgroundOpacity = 0.28
            style.borderEnabled = false
            style.shadowOpacity = 0.22
            style.shadowRadius = 14
        case .bigNumbers:
            style.statsBar.visible = true
            style.statsBar.height = 46
            style.statsBar.backgroundOpacity = 0.38
            style.statsBar.valueFontSize = 18
            style.statsBar.labelFontSize = 9
            style.statsBar.slots = [
                DistanceTimelineStatsBarSlot(metric: .distance, visible: true, customLabel: ""),
                DistanceTimelineStatsBarSlot(metric: .elapsedTime, visible: true, customLabel: ""),
                DistanceTimelineStatsBarSlot(metric: .elevation, visible: false, customLabel: "ELEV"),
                DistanceTimelineStatsBarSlot(metric: .grade, visible: false, customLabel: ""),
            ]
            style.markerLabelEnabled = false
            style.axisLineEnabled = false
            style.axisLabelsEnabled = false
            style.backgroundOpacity = 0.44
            style.shadowOpacity = 0.30
            style.chartPaddingX = 18
            style.chartPaddingY = 14
        }
        return style
    }

    private static let defaultStatsBar = DistanceTimelineStatsBarConfig(
        visible: true,
        placement: .bottomAttached,
        inside: false,
        layoutMode: .equalColumns,
        width: 0,
        height: 56,
        offsetX: 0,
        offsetY: 0,
        itemSpacing: 0,
        backgroundOpacity: 0.48,
        dividerOpacity: 0.12,
        cornerRadius: 10,
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

extension ElevationChartStyle {
    private enum CodingKeys: String, CodingKey {
        case preset
        case width
        case height
        case chartStyle
        case smoothingEnabled
        case smoothingAmount
        case progressMode
        case chartPaddingX
        case chartPaddingY
        case lineColor
        case lineWidth
        case lineOpacity
        case fillEnabled
        case fillStartColor
        case fillEndColor
        case fillOpacity
        case dualAreaEnabled
        case upperFillColor
        case lowerFillColor
        case currentMarkerEnabled
        case markerColor
        case markerPlayheadLineEnabled
        case markerLabelEnabled
        case gridEnabled
        case axisLineEnabled
        case axisLabelsEnabled
        case bigNumbersEnabled
        case bigNumberMetric
        case bigNumberFontSize
        case bigNumberFontName
        case bigNumberFontWeight
        case backgroundEnabled
        case backgroundColor
        case backgroundOpacity
        case cornerRadius
        case borderEnabled
        case borderOpacity
        case shadowEnabled
        case shadowOpacity
        case shadowRadius
        case glowEnabled
        case glowOpacity
        case statsBar
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedPreset = try container.decodeIfPresent(ElevationChartPreset.self, forKey: .preset) ?? .gradientArea
        let defaults = ElevationChartStyle.preset(decodedPreset)

        preset = decodedPreset
        width = min(
            max(try container.decodeIfPresent(Double.self, forKey: .width) ?? defaults.width, Self.widthRange.lowerBound),
            Self.widthRange.upperBound
        )
        height = min(
            max(try container.decodeIfPresent(Double.self, forKey: .height) ?? defaults.height, Self.heightRange.lowerBound),
            Self.heightRange.upperBound
        )
        chartStyle = try container.decodeIfPresent(ElevationChartRenderStyle.self, forKey: .chartStyle) ?? defaults.chartStyle
        smoothingEnabled = try container.decodeIfPresent(Bool.self, forKey: .smoothingEnabled) ?? defaults.smoothingEnabled
        smoothingAmount = min(max(try container.decodeIfPresent(Double.self, forKey: .smoothingAmount) ?? defaults.smoothingAmount, 0), 1)
        progressMode = try container.decodeIfPresent(ElevationChartProgressMode.self, forKey: .progressMode) ?? defaults.progressMode
        chartPaddingX = try container.decodeIfPresent(Double.self, forKey: .chartPaddingX) ?? defaults.chartPaddingX
        chartPaddingY = try container.decodeIfPresent(Double.self, forKey: .chartPaddingY) ?? defaults.chartPaddingY
        lineColor = try container.decodeIfPresent(OverlayColor.self, forKey: .lineColor) ?? defaults.lineColor
        lineWidth = try container.decodeIfPresent(Double.self, forKey: .lineWidth) ?? defaults.lineWidth
        lineOpacity = try container.decodeIfPresent(Double.self, forKey: .lineOpacity) ?? defaults.lineOpacity
        fillEnabled = try container.decodeIfPresent(Bool.self, forKey: .fillEnabled) ?? defaults.fillEnabled
        fillStartColor = try container.decodeIfPresent(OverlayColor.self, forKey: .fillStartColor) ?? defaults.fillStartColor
        fillEndColor = try container.decodeIfPresent(OverlayColor.self, forKey: .fillEndColor) ?? defaults.fillEndColor
        fillOpacity = try container.decodeIfPresent(Double.self, forKey: .fillOpacity) ?? defaults.fillOpacity
        dualAreaEnabled = try container.decodeIfPresent(Bool.self, forKey: .dualAreaEnabled) ?? defaults.dualAreaEnabled
        upperFillColor = try container.decodeIfPresent(OverlayColor.self, forKey: .upperFillColor) ?? defaults.upperFillColor
        lowerFillColor = try container.decodeIfPresent(OverlayColor.self, forKey: .lowerFillColor) ?? defaults.lowerFillColor
        currentMarkerEnabled = try container.decodeIfPresent(Bool.self, forKey: .currentMarkerEnabled) ?? defaults.currentMarkerEnabled
        markerColor = try container.decodeIfPresent(OverlayColor.self, forKey: .markerColor) ?? defaults.markerColor
        markerPlayheadLineEnabled = try container.decodeIfPresent(Bool.self, forKey: .markerPlayheadLineEnabled) ?? defaults.markerPlayheadLineEnabled
        markerLabelEnabled = try container.decodeIfPresent(Bool.self, forKey: .markerLabelEnabled) ?? defaults.markerLabelEnabled
        gridEnabled = try container.decodeIfPresent(Bool.self, forKey: .gridEnabled) ?? defaults.gridEnabled
        axisLineEnabled = try container.decodeIfPresent(Bool.self, forKey: .axisLineEnabled) ?? defaults.axisLineEnabled
        axisLabelsEnabled = try container.decodeIfPresent(Bool.self, forKey: .axisLabelsEnabled) ?? defaults.axisLabelsEnabled
        bigNumbersEnabled = try container.decodeIfPresent(Bool.self, forKey: .bigNumbersEnabled) ?? defaults.bigNumbersEnabled
        bigNumberMetric = try container.decodeIfPresent(ElevationChartBigMetric.self, forKey: .bigNumberMetric) ?? defaults.bigNumberMetric
        bigNumberFontSize = try container.decodeIfPresent(Double.self, forKey: .bigNumberFontSize) ?? defaults.bigNumberFontSize
        bigNumberFontName = try container.decodeIfPresent(String.self, forKey: .bigNumberFontName) ?? defaults.bigNumberFontName
        bigNumberFontWeight = try container.decodeIfPresent(OverlayFontWeight.self, forKey: .bigNumberFontWeight) ?? defaults.bigNumberFontWeight
        backgroundEnabled = try container.decodeIfPresent(Bool.self, forKey: .backgroundEnabled) ?? defaults.backgroundEnabled
        backgroundColor = try container.decodeIfPresent(OverlayColor.self, forKey: .backgroundColor) ?? defaults.backgroundColor
        backgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? defaults.backgroundOpacity
        cornerRadius = try container.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? defaults.cornerRadius
        borderEnabled = try container.decodeIfPresent(Bool.self, forKey: .borderEnabled) ?? defaults.borderEnabled
        borderOpacity = try container.decodeIfPresent(Double.self, forKey: .borderOpacity) ?? defaults.borderOpacity
        shadowEnabled = try container.decodeIfPresent(Bool.self, forKey: .shadowEnabled) ?? defaults.shadowEnabled
        shadowOpacity = try container.decodeIfPresent(Double.self, forKey: .shadowOpacity) ?? defaults.shadowOpacity
        shadowRadius = try container.decodeIfPresent(Double.self, forKey: .shadowRadius) ?? defaults.shadowRadius
        glowEnabled = try container.decodeIfPresent(Bool.self, forKey: .glowEnabled) ?? defaults.glowEnabled
        glowOpacity = try container.decodeIfPresent(Double.self, forKey: .glowOpacity) ?? defaults.glowOpacity
        statsBar = try container.decodeIfPresent(DistanceTimelineStatsBarConfig.self, forKey: .statsBar) ?? defaults.statsBar
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(preset, forKey: .preset)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(chartStyle, forKey: .chartStyle)
        try container.encode(smoothingEnabled, forKey: .smoothingEnabled)
        try container.encode(smoothingAmount, forKey: .smoothingAmount)
        try container.encode(progressMode, forKey: .progressMode)
        try container.encode(chartPaddingX, forKey: .chartPaddingX)
        try container.encode(chartPaddingY, forKey: .chartPaddingY)
        try container.encode(lineColor, forKey: .lineColor)
        try container.encode(lineWidth, forKey: .lineWidth)
        try container.encode(lineOpacity, forKey: .lineOpacity)
        try container.encode(fillEnabled, forKey: .fillEnabled)
        try container.encode(fillStartColor, forKey: .fillStartColor)
        try container.encode(fillEndColor, forKey: .fillEndColor)
        try container.encode(fillOpacity, forKey: .fillOpacity)
        try container.encode(dualAreaEnabled, forKey: .dualAreaEnabled)
        try container.encode(upperFillColor, forKey: .upperFillColor)
        try container.encode(lowerFillColor, forKey: .lowerFillColor)
        try container.encode(currentMarkerEnabled, forKey: .currentMarkerEnabled)
        try container.encode(markerColor, forKey: .markerColor)
        try container.encode(markerPlayheadLineEnabled, forKey: .markerPlayheadLineEnabled)
        try container.encode(markerLabelEnabled, forKey: .markerLabelEnabled)
        try container.encode(gridEnabled, forKey: .gridEnabled)
        try container.encode(axisLineEnabled, forKey: .axisLineEnabled)
        try container.encode(axisLabelsEnabled, forKey: .axisLabelsEnabled)
        try container.encode(bigNumbersEnabled, forKey: .bigNumbersEnabled)
        try container.encode(bigNumberMetric, forKey: .bigNumberMetric)
        try container.encode(bigNumberFontSize, forKey: .bigNumberFontSize)
        try container.encode(bigNumberFontName, forKey: .bigNumberFontName)
        try container.encode(bigNumberFontWeight, forKey: .bigNumberFontWeight)
        try container.encode(backgroundEnabled, forKey: .backgroundEnabled)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encode(backgroundOpacity, forKey: .backgroundOpacity)
        try container.encode(cornerRadius, forKey: .cornerRadius)
        try container.encode(borderEnabled, forKey: .borderEnabled)
        try container.encode(borderOpacity, forKey: .borderOpacity)
        try container.encode(shadowEnabled, forKey: .shadowEnabled)
        try container.encode(shadowOpacity, forKey: .shadowOpacity)
        try container.encode(shadowRadius, forKey: .shadowRadius)
        try container.encode(glowEnabled, forKey: .glowEnabled)
        try container.encode(glowOpacity, forKey: .glowOpacity)
        try container.encode(statsBar, forKey: .statsBar)
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

/// Vertical placement of distance timeline axis text relative to the progress track (+Y is downward).
enum DistanceTimelineAxisLabelTrackPlacement: String, CaseIterable, Identifiable, Codable, Sendable {
    case below
    case above

    var id: String { rawValue }

    var label: String {
        switch self {
        case .below: "Below"
        case .above: "Above"
        }
    }
}

enum DistanceTimelineMarkerStyle: String, CaseIterable, Identifiable, Codable {
    case dot
    case pill
    case triangle

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dot: "Dot"
        case .pill: "Pill"
        case .triangle: "Triangle"
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
        valueFontName: FontLibraryManager.currentDefaultFamily,
        valueFontSize: 30,
        valueFontWeight: .semibold,
        valueColor: .white,
        labelFontName: FontLibraryManager.currentDefaultFamily,
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
        valueFontName: String = FontLibraryManager.currentDefaultFamily,
        valueFontSize: Double = 30,
        valueFontWeight: OverlayFontWeight = .semibold,
        valueColor: OverlayColor = .white,
        labelFontName: String = FontLibraryManager.currentDefaultFamily,
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
    var showTotalDistance: Bool
    var valueUnitSystem: DistanceTimelineUnitSystem
    var customValuesEnabled: Bool
    var customValues: [DistanceTimelineCustomValue]
    var customValueFontSize: Double
    var customValuesGroupSpacing: Double
    var customValueSpacing: Double
    var customValueColor: OverlayColor
    var customValueOpacity: Double
    var valueProgressSpacing: Double
    var showLabel: Bool
    var label: String
    var labelFontName: String
    var labelFontSize: Double
    var labelFontWeight: OverlayFontWeight
    var labelColor: OverlayColor
    var labelValueSpacing: Double
    /// Start / finish axis text (START/FINISH or distance endpoints).
    var showAxisLabels: Bool
    var axisLabelMode: DistanceTimelineAxisLabelMode
    var axisLabelOffset: Double
    var axisLabelFontName: String
    var axisLabelFontSize: Double
    var axisLabelFontWeight: OverlayFontWeight
    var axisLabelColor: OverlayColor
    /// Intermediate distance tick labels along the track.
    var showDistancePoints: Bool
    var distancePointCount: Int
    /// Vertical gap from the track edge for start/finish axis labels (same key as legacy `distancePointOffset` in JSON).
    var distancePointOffset: Double
    var midpointAxisLabelOffset: Double
    var axisEndpointLabelPlacement: DistanceTimelineAxisLabelTrackPlacement
    var axisMidpointLabelPlacement: DistanceTimelineAxisLabelTrackPlacement
    var markerDistanceLabelEnabled: Bool
    var markerDistanceLabelPlacement: DistanceTimelineAxisLabelTrackPlacement
    var markerDistanceLabelOffset: Double
    var currentMarkerSizeMultiplier: Double
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
    var currentMarkerStyle: DistanceTimelineMarkerStyle
    var currentMarkerColor: OverlayColor
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
        showTotalDistance: Bool = true,
        valueUnitSystem: DistanceTimelineUnitSystem = .metric,
        customValuesEnabled: Bool = false,
        customValues: [DistanceTimelineCustomValue] = Array(repeating: .empty, count: 4),
        customValueFontSize: Double = 12,
        customValuesGroupSpacing: Double = 12,
        customValueSpacing: Double = 10,
        customValueColor: OverlayColor = .white,
        customValueOpacity: Double = 0.70,
        valueProgressSpacing: Double = 8,
        showLabel: Bool,
        label: String,
        labelFontName: String = FontLibraryManager.currentDefaultFamily,
        labelFontSize: Double = 12,
        labelFontWeight: OverlayFontWeight = .medium,
        labelColor: OverlayColor = .white,
        labelValueSpacing: Double = 2,
        showAxisLabels: Bool = false,
        axisLabelMode: DistanceTimelineAxisLabelMode = .startFinish,
        axisLabelOffset: Double = 14,
        axisLabelFontName: String = FontLibraryManager.currentDefaultFamily,
        axisLabelFontSize: Double = 11,
        axisLabelFontWeight: OverlayFontWeight = .medium,
        axisLabelColor: OverlayColor = .white,
        showDistancePoints: Bool = false,
        distancePointCount: Int = 3,
        distancePointOffset: Double = 34,
        midpointAxisLabelOffset: Double = 34,
        axisEndpointLabelPlacement: DistanceTimelineAxisLabelTrackPlacement = .below,
        axisMidpointLabelPlacement: DistanceTimelineAxisLabelTrackPlacement = .below,
        markerDistanceLabelEnabled: Bool = false,
        markerDistanceLabelPlacement: DistanceTimelineAxisLabelTrackPlacement = .above,
        markerDistanceLabelOffset: Double = 12,
        currentMarkerSizeMultiplier: Double = 1,
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
        currentMarkerStyle: DistanceTimelineMarkerStyle = .dot,
        currentMarkerColor: OverlayColor? = nil,
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
        self.showTotalDistance = showTotalDistance
        self.valueUnitSystem = valueUnitSystem
        self.customValuesEnabled = customValuesEnabled
        self.customValues = Array(customValues.prefix(4)) + Array(repeating: .empty, count: max(0, 4 - customValues.count))
        self.customValueFontSize = customValueFontSize
        self.customValuesGroupSpacing = customValuesGroupSpacing
        self.customValueSpacing = customValueSpacing
        self.customValueColor = customValueColor
        self.customValueOpacity = customValueOpacity
        self.valueProgressSpacing = valueProgressSpacing
        self.showLabel = showLabel
        self.label = label
        self.labelFontName = labelFontName
        self.labelFontSize = labelFontSize
        self.labelFontWeight = labelFontWeight
        self.labelColor = labelColor
        self.labelValueSpacing = labelValueSpacing
        self.showAxisLabels = showAxisLabels
        self.axisLabelMode = axisLabelMode
        self.axisLabelOffset = axisLabelOffset
        self.axisLabelFontName = axisLabelFontName
        self.axisLabelFontSize = axisLabelFontSize
        self.axisLabelFontWeight = axisLabelFontWeight
        self.axisLabelColor = axisLabelColor
        self.showDistancePoints = showDistancePoints
        self.distancePointCount = min(max(distancePointCount, 0), 12)
        self.distancePointOffset = distancePointOffset
        self.midpointAxisLabelOffset = midpointAxisLabelOffset
        self.axisEndpointLabelPlacement = axisEndpointLabelPlacement
        self.axisMidpointLabelPlacement = axisMidpointLabelPlacement
        self.markerDistanceLabelEnabled = markerDistanceLabelEnabled
        self.markerDistanceLabelPlacement = markerDistanceLabelPlacement
        self.markerDistanceLabelOffset = markerDistanceLabelOffset
        self.currentMarkerSizeMultiplier = min(max(currentMarkerSizeMultiplier, 0.25), 4)
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
        self.currentMarkerStyle = currentMarkerStyle
        self.currentMarkerColor = currentMarkerColor ?? fillColor
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
        showTotalDistance = try c.decodeIfPresent(Bool.self, forKey: .showTotalDistance) ?? true
        valueUnitSystem = try c.decodeIfPresent(DistanceTimelineUnitSystem.self, forKey: .valueUnitSystem) ?? .metric
        customValuesEnabled = try c.decodeIfPresent(Bool.self, forKey: .customValuesEnabled) ?? false
        let decodedCustomValues = try c.decodeIfPresent([DistanceTimelineCustomValue].self, forKey: .customValues) ?? base.customValues
        customValues = Array(decodedCustomValues.prefix(4)) + Array(repeating: .empty, count: max(0, 4 - decodedCustomValues.count))
        customValueFontSize = try c.decodeIfPresent(Double.self, forKey: .customValueFontSize) ?? base.customValueFontSize
        customValuesGroupSpacing = try c.decodeIfPresent(Double.self, forKey: .customValuesGroupSpacing) ?? base.customValuesGroupSpacing
        customValueSpacing = try c.decodeIfPresent(Double.self, forKey: .customValueSpacing) ?? base.customValueSpacing
        customValueColor = try c.decodeIfPresent(OverlayColor.self, forKey: .customValueColor) ?? base.customValueColor
        customValueOpacity = try c.decodeIfPresent(Double.self, forKey: .customValueOpacity) ?? base.customValueOpacity
        valueProgressSpacing = try c.decodeIfPresent(Double.self, forKey: .valueProgressSpacing) ?? base.valueProgressSpacing
        showLabel = try c.decodeIfPresent(Bool.self, forKey: .showLabel) ?? base.showLabel
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? base.label
        labelFontName = try c.decodeIfPresent(String.self, forKey: .labelFontName) ?? base.labelFontName
        labelFontSize = try c.decodeIfPresent(Double.self, forKey: .labelFontSize) ?? base.labelFontSize
        labelFontWeight = try c.decodeIfPresent(OverlayFontWeight.self, forKey: .labelFontWeight) ?? base.labelFontWeight
        labelColor = try c.decodeIfPresent(OverlayColor.self, forKey: .labelColor) ?? base.labelColor
        labelValueSpacing = try c.decodeIfPresent(Double.self, forKey: .labelValueSpacing) ?? base.labelValueSpacing
        showAxisLabels = try c.decodeIfPresent(Bool.self, forKey: .showAxisLabels)
            ?? legacy.decodeIfPresent(Bool.self, forKey: .showStartFinishLabels)
            ?? base.showAxisLabels
        showDistancePoints = try c.decodeIfPresent(Bool.self, forKey: .showDistancePoints) ?? base.showDistancePoints

        axisLabelMode = try c.decodeIfPresent(DistanceTimelineAxisLabelMode.self, forKey: .axisLabelMode) ?? base.axisLabelMode
        axisLabelOffset = try c.decodeIfPresent(Double.self, forKey: .axisLabelOffset) ?? base.axisLabelOffset
        axisLabelFontName = try c.decodeIfPresent(String.self, forKey: .axisLabelFontName) ?? base.axisLabelFontName
        axisLabelFontSize = try c.decodeIfPresent(Double.self, forKey: .axisLabelFontSize) ?? base.axisLabelFontSize
        axisLabelFontWeight = try c.decodeIfPresent(OverlayFontWeight.self, forKey: .axisLabelFontWeight) ?? base.axisLabelFontWeight
        axisLabelColor = try c.decodeIfPresent(OverlayColor.self, forKey: .axisLabelColor) ?? base.axisLabelColor

        distancePointCount = min(max(try c.decodeIfPresent(Int.self, forKey: .distancePointCount) ?? base.distancePointCount, 0), 12)
        let legacySharedGap = try c.decodeIfPresent(Double.self, forKey: .distancePointOffset) ?? base.distancePointOffset
        distancePointOffset = legacySharedGap
        midpointAxisLabelOffset = try c.decodeIfPresent(Double.self, forKey: .midpointAxisLabelOffset) ?? legacySharedGap
        axisEndpointLabelPlacement = try c.decodeIfPresent(DistanceTimelineAxisLabelTrackPlacement.self, forKey: .axisEndpointLabelPlacement) ?? base.axisEndpointLabelPlacement
        axisMidpointLabelPlacement = try c.decodeIfPresent(DistanceTimelineAxisLabelTrackPlacement.self, forKey: .axisMidpointLabelPlacement) ?? base.axisMidpointLabelPlacement
        markerDistanceLabelEnabled = try c.decodeIfPresent(Bool.self, forKey: .markerDistanceLabelEnabled) ?? base.markerDistanceLabelEnabled
        markerDistanceLabelPlacement = try c.decodeIfPresent(DistanceTimelineAxisLabelTrackPlacement.self, forKey: .markerDistanceLabelPlacement) ?? base.markerDistanceLabelPlacement
        markerDistanceLabelOffset = try c.decodeIfPresent(Double.self, forKey: .markerDistanceLabelOffset) ?? base.markerDistanceLabelOffset
        let decodedMarkerScale = try c.decodeIfPresent(Double.self, forKey: .currentMarkerSizeMultiplier) ?? base.currentMarkerSizeMultiplier
        currentMarkerSizeMultiplier = min(max(decodedMarkerScale, 0.25), 4)
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
        currentMarkerStyle = try c.decodeIfPresent(DistanceTimelineMarkerStyle.self, forKey: .currentMarkerStyle) ?? base.currentMarkerStyle
        currentMarkerColor = try c.decodeIfPresent(OverlayColor.self, forKey: .currentMarkerColor) ?? base.currentMarkerColor
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
        case showTotalDistance
        case valueUnitSystem
        case customValuesEnabled
        case customValues
        case customValueFontSize
        case customValuesGroupSpacing
        case customValueSpacing
        case customValueColor
        case customValueOpacity
        case valueProgressSpacing
        case showLabel
        case label
        case labelFontName
        case labelFontSize
        case labelFontWeight
        case labelColor
        case labelValueSpacing
        case showAxisLabels
        case axisLabelMode
        case axisLabelOffset
        case axisLabelFontName
        case axisLabelFontSize
        case axisLabelFontWeight
        case axisLabelColor
        case showDistancePoints
        case distancePointCount
        case distancePointOffset
        case midpointAxisLabelOffset
        case axisEndpointLabelPlacement
        case axisMidpointLabelPlacement
        case markerDistanceLabelEnabled
        case markerDistanceLabelPlacement
        case markerDistanceLabelOffset
        case currentMarkerSizeMultiplier
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
        case currentMarkerStyle
        case currentMarkerColor
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
            style.showDistancePoints = false
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

extension DistanceTimelineStyle {
    /// Top edge Y of the axis label text band (layout coordinates, +Y downward), aligned with export `drawPlainText` rects.
    func distanceTimelineAxisLabelTextTopY(
        trackRect: CGRect,
        placement: DistanceTimelineAxisLabelTrackPlacement,
        scaledGap: CGFloat,
        textLineHeight: CGFloat
    ) -> CGFloat {
        switch placement {
        case .below:
            trackRect.maxY + scaledGap
        case .above:
            trackRect.minY - scaledGap - textLineHeight
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
/// shared background fade fields, `routeMapMapOpacity`, `shadowEnabled`,
/// `shadowOpacity`, `shadowRadius`, `shadowOffsetX`, `shadowOffsetY`).
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
    case heartRate
    case pace
    case avgPace
    case lapPace
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

    var id: String { rawValue }

    var label: String {
        switch self {
        case .progress: "Progress"
        case .heartRate: "Heart Rate"
        case .pace: "Pace"
        case .avgPace: "Avg Pace"
        case .lapPace: "Lap Pace"
        case .calories: "Calories"
        case .elapsedTime: "Time"
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
        }
    }

    var elementType: OverlayElementType {
        switch self {
        case .progress: .distance
        case .heartRate: .heartRate
        case .pace: .pace
        case .avgPace: .avgPace
        case .lapPace: .lapPace
        case .calories: .calories
        case .elapsedTime: .elapsedTime
        case .realTime: .realTime
        case .distance: .distance
        case .elevation: .elevation
        case .cadence: .cadence
        case .power: .power
        case .verticalOscillation: .verticalOscillation
        case .groundContactTime: .groundContactTime
        case .strideLength: .strideLength
        case .verticalRatio: .verticalRatio
        case .groundContactBalance: .groundContactBalance
        case .temperature: .temperature
        case .grade: .grade
        }
    }

    static var selectableCases: [RouteMapStatsMetric] {
        [.progress] + ActivityMetricCatalog.selectableElementTypes.compactMap(Self.init(elementType:))
    }

    init?(elementType: OverlayElementType) {
        switch elementType {
        case .heartRate: self = .heartRate
        case .pace: self = .pace
        case .avgPace: self = .avgPace
        case .lapPace: self = .lapPace
        case .calories: self = .calories
        case .elapsedTime: self = .elapsedTime
        case .realTime: self = .realTime
        case .distance: self = .distance
        case .elevation: self = .elevation
        case .cadence: self = .cadence
        case .power: self = .power
        case .verticalOscillation: self = .verticalOscillation
        case .groundContactTime: self = .groundContactTime
        case .strideLength: self = .strideLength
        case .verticalRatio: self = .verticalRatio
        case .groundContactBalance: self = .groundContactBalance
        case .temperature: self = .temperature
        case .grade: self = .grade
        default: return nil
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
        valueFontName: FontLibraryManager.currentDefaultFamily,
        valueFontSize: 30,
        valueFontWeight: .semibold,
        valueColor: .white,
        labelFontName: FontLibraryManager.currentDefaultFamily,
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
        valueFontName: String = FontLibraryManager.currentDefaultFamily,
        valueFontSize: Double = 30,
        valueFontWeight: OverlayFontWeight = .semibold,
        valueColor: OverlayColor = .white,
        labelFontName: String = FontLibraryManager.currentDefaultFamily,
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
                fontName: FontLibraryManager.currentDefaultFamily,
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
                fontName: FontLibraryManager.currentDefaultFamily,
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
                fontName: FontLibraryManager.currentDefaultFamily,
                fontWeight: .bold,
                fontSize: 32,
                textAlignment: .leading,
                showLabel: false,
                showUnit: true,
                backgroundEnabled: true,
                backgroundColor: .black,
                backgroundOpacity: 0.48,
                backgroundRadius: 999,
                accentColor: blue,
                divider: DividerTokens(color: .white, thickness: 1, opacity: 0.32)
            )
        case .metricCard:
            return OverlayPresetTokens(
                fontName: FontLibraryManager.currentDefaultFamily,
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
                fontName: FontLibraryManager.currentDefaultFamily,
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
                fontName: FontLibraryManager.currentDefaultFamily,
                fontWeight: .bold,
                fontSize: 42,
                textAlignment: .leading,
                showLabel: true,
                showUnit: true,
                backgroundEnabled: false,
                backgroundColor: nil,
                backgroundOpacity: nil,
                backgroundRadius: 0,
                accentColor: blue,
                divider: DividerTokens(color: blue, thickness: 2, opacity: 1)
            )
        case .neonGlow:
            return OverlayPresetTokens(
                fontName: FontLibraryManager.currentDefaultFamily,
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
                fontName: FontLibraryManager.currentDefaultFamily,
                fontWeight: .bold,
                fontSize: 40,
                textAlignment: .leading,
                showLabel: true,
                showUnit: true,
                backgroundEnabled: true,
                backgroundColor: .black,
                backgroundOpacity: 0.50,
                backgroundRadius: 12,
                accentColor: orange,
                divider: DividerTokens(color: orange, thickness: 5, opacity: 1)
            )
        case .editorial:
            return OverlayPresetTokens(
                fontName: FontLibraryManager.currentDefaultFamily,
                fontWeight: .bold,
                fontSize: 64,
                textAlignment: .leading,
                showLabel: true,
                showUnit: true,
                backgroundEnabled: false,
                backgroundColor: nil,
                backgroundOpacity: nil,
                backgroundRadius: 0,
                accentColor: yellow,
                divider: DividerTokens(color: yellow, thickness: 3, opacity: 1)
            )
        case .digitalWatch:
            return OverlayPresetTokens(
                fontName: PresetFontName.digitalWatch,
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
    /// Divider defaults for this preset. `nil` means "this preset has no
    /// built-in divider" — `applyOverlayTextPreset` will write
    /// `dividerEnabled = false` so the divider section stays inert until the
    /// user re-enables it. Presets that DO render a divider should supply a
    /// `DividerTokens` matching their hard-coded visual so users see no
    /// regression after switching to the preset.
    var divider: DividerTokens?
}

struct DividerTokens {
    var color: OverlayColor
    var thickness: Double
    var opacity: Double
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
    static let routeMapEndCheckerboard = OverlayColor(red: -1, green: -1, blue: -1, alpha: 1)

    var isRouteMapEndCheckerboard: Bool {
        self == .routeMapEndCheckerboard
    }
}

// MARK: - Decor Text Support Types

/// Font reference for the Decor Text element. The bundled case remains
/// decodable for compatibility with early project files; new content uses
/// system fonts or future user-uploaded font assets.
enum DecorFontRef: Equatable, Codable {
    case bundled(name: String)
    case system(family: String)
    case userAsset(id: UUID)
}

/// Gradient specification for text fill (Phase F6).
struct GradientSpec: Equatable, Codable {
    var stops: [GradientStop]
    var direction: GradientDirection
    enum GradientDirection: String, CaseIterable, Identifiable, Codable {
        case topToBottom, leftToRight, bottomLeftToTopRight, topLeftToBottomRight
        var id: String { rawValue }
    }
    struct GradientStop: Equatable, Codable {
        var position: Double  // 0...1
        var color: OverlayColor
    }
}

/// Fill mode for Decor Text: solid color or gradient.
enum DecorTextFill: Equatable, Codable {
    case solid(color: OverlayColor)
    case gradient(GradientSpec)
}

/// Text alignment options for the decor text block.
enum DecorTextAlignment: String, CaseIterable, Identifiable, Codable {
    case leading, center, trailing
    var id: String { rawValue }
    var label: String {
        switch self {
        case .leading: "Leading"
        case .center: "Center"
        case .trailing: "Trailing"
        }
    }
}

// MARK: - Decor

/// Shape variants offered by the Solid Color decor element. Circle is a
/// degenerate ellipse where width == height; the renderer collapses to the
/// shorter side and the inspector keeps the controls in lockstep.
enum DecorShape: String, CaseIterable, Identifiable, Codable {
    case rectangle
    case roundedRectangle
    case circle
    case capsule

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rectangle: "Rectangle"
        case .roundedRectangle: "Rounded"
        case .circle: "Circle"
        case .capsule: "Capsule"
        }
    }

    var systemImage: String {
        switch self {
        case .rectangle: "square"
        case .roundedRectangle: "square.dashed"
        case .circle: "circle"
        case .capsule: "capsule"
        }
    }
}

/// Sub-struct holding all decor element style fields. Per project convention
/// (mirrors `gauge`, `distanceTimeline`, etc.) decor fields live in
/// their own namespace so they don't pollute numeric overlay storage. Future
/// decor element types (Icon, Text) will extend this same struct.
struct DecorStyle: Equatable, Codable {
    /// Active solid-color shape variant.
    var shape: DecorShape
    /// Fill color drawn into the shape path.
    var fillColor: OverlayColor
    /// Width in design units (before `element.scale` is applied).
    var width: Double
    var height: Double
    var cornerRadius: Double

    // Icon (optional for backward compat)
    var iconAsset: IconAsset?
    var iconTint: OverlayColor?
    var iconPreserveSVGColors: Bool?
    var iconContentMode: IconContentMode?

    // Text (optional for backward compat)
    var textContent: String?
    var textFont: DecorFontRef?
    var textSize: Double?
    var textAlignment: DecorTextAlignment?
    var textLineHeight: Double?
    var textLetterSpacing: Double?
    var textFillMode: DecorTextFill?
    var textStrokeWidth: Double?
    var textStrokeColor: OverlayColor?
    var textAutoFit: Bool?

    static let `default` = DecorStyle(
        shape: .rectangle,
        fillColor: .white,
        width: 240,
        height: 80,
        cornerRadius: 12,
        iconAsset: nil,
        iconTint: nil,
        iconPreserveSVGColors: nil,
        iconContentMode: nil,
        textContent: nil,
        textFont: nil,
        textSize: nil,
        textAlignment: nil,
        textLineHeight: nil,
        textLetterSpacing: nil,
        textFillMode: nil,
        textStrokeWidth: nil,
        textStrokeColor: nil,
        textAutoFit: nil
    )
}


    /// Resolved text fields for a decor element, coalescing nil optionals.
    struct DecorTextResolved {
        var content: String
        var font: DecorFontRef
        var size: Double
        var alignment: DecorTextAlignment
        var lineHeight: Double
        var letterSpacing: Double
        var fillMode: DecorTextFill
        var strokeWidth: Double
        var strokeColor: OverlayColor
        var autoFit: Bool

        init(from style: DecorStyle) {
            content = style.textContent ?? "Hello"
            font = style.textFont ?? .system(family: FontLibraryManager.currentDefaultFamily)
            size = style.textSize ?? 36
            alignment = style.textAlignment ?? .center
            lineHeight = style.textLineHeight ?? 1.2
            letterSpacing = style.textLetterSpacing ?? 0
            fillMode = style.textFillMode ?? .solid(color: .white)
            strokeWidth = style.textStrokeWidth ?? 0
            strokeColor = style.textStrokeColor ?? .white
            autoFit = style.textAutoFit ?? false
        }
    }

    /// Resolved icon fields for a decor element, coalescing nil optionals
    /// to their sensible defaults.
    struct DecorIconResolved {
        var asset: IconAsset
        var tint: OverlayColor
        var preserveSVGColors: Bool
        var contentMode: IconContentMode

        init(from style: DecorStyle) {
            asset = style.iconAsset ?? .none
            tint = style.iconTint ?? .white
            preserveSVGColors = style.iconPreserveSVGColors ?? false
            contentMode = style.iconContentMode ?? .fit
        }
    }

// MARK: - Weather Widget

enum WeatherCondition: String, CaseIterable, Identifiable, Equatable, Codable {
    case sunny
    case clearNight
    case partlyCloudy
    case cloudy
    case rain
    case heavyRain
    case thunder
    case snow
    case fog
    case wind

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sunny: "Sunny"
        case .clearNight: "Clear Night"
        case .partlyCloudy: "Partly Cloudy"
        case .cloudy: "Cloudy"
        case .rain: "Rain"
        case .heavyRain: "Heavy Rain"
        case .thunder: "Thunderstorm"
        case .snow: "Snow"
        case .fog: "Fog"
        case .wind: "Wind"
        }
    }

    var sfSymbolName: String {
        switch self {
        case .sunny: "sun.max.fill"
        case .clearNight: "moon.stars.fill"
        case .partlyCloudy: "cloud.sun.fill"
        case .cloudy: "cloud.fill"
        case .rain: "cloud.drizzle.fill"
        case .heavyRain: "cloud.heavyrain.fill"
        case .thunder: "cloud.bolt.fill"
        case .snow: "snowflake"
        case .fog: "cloud.fog.fill"
        case .wind: "wind"
        }
    }

    var bundledImageName: String {
        switch self {
        case .sunny: "weather-sunny"
        case .clearNight: "weather-clear-night"
        case .partlyCloudy: "weather-partly-cloudy"
        case .cloudy: "weather-cloudy"
        case .rain: "weather-rain"
        case .heavyRain: "weather-heavy-rain"
        case .thunder: "weather-thunder"
        case .snow: "weather-snow"
        case .fog: "weather-fog"
        case .wind: "weather-wind"
        }
    }

    var iconTint: OverlayColor {
        switch self {
        case .sunny: OverlayColor(red: 1, green: 0.8, blue: 0.2, alpha: 1)
        case .clearNight: OverlayColor(red: 0.4, green: 0.5, blue: 1, alpha: 1)
        case .partlyCloudy: OverlayColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1)
        case .cloudy: OverlayColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1)
        case .rain: OverlayColor(red: 0.3, green: 0.6, blue: 1, alpha: 1)
        case .heavyRain: OverlayColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1)
        case .thunder: OverlayColor(red: 0.8, green: 0.6, blue: 0.1, alpha: 1)
        case .snow: OverlayColor(red: 0.75, green: 0.85, blue: 1, alpha: 1)
        case .fog: OverlayColor(red: 0.55, green: 0.55, blue: 0.6, alpha: 1)
        case .wind: OverlayColor(red: 0.5, green: 0.7, blue: 0.75, alpha: 1)
        }
    }

    static func fromWMO(_ code: Int) -> WeatherCondition {
        switch code {
        case 0, 1: .sunny
        case 2: .partlyCloudy
        case 3: .cloudy
        case 45, 48: .fog
        case 51, 53, 55, 56, 57, 61, 63, 65: .rain
        case 66, 67, 80, 81, 82: .heavyRain
        case 71, 73, 75, 77, 85, 86: .snow
        case 95, 96, 99: .thunder
        default: .cloudy
        }
    }

    static func fromOpenWeather(id: Int, icon: String?) -> WeatherCondition {
        switch id {
        case 200..<300:
            .thunder
        case 300..<400:
            .rain
        case 500, 501, 520, 521:
            .rain
        case 502, 503, 504, 511, 522, 531:
            .heavyRain
        case 600..<700:
            .snow
        case 701, 711, 721, 731, 741, 751, 761, 762:
            .fog
        case 771, 781:
            .wind
        case 800:
            icon?.hasSuffix("n") == true ? .clearNight : .sunny
        case 801:
            .partlyCloudy
        case 802...804:
            .cloudy
        default:
            .cloudy
        }
    }
}

enum WeatherTemperatureUnit: String, CaseIterable, Identifiable, Equatable, Codable {
    case celsius
    case fahrenheit

    var id: String { rawValue }

    var label: String {
        switch self {
        case .celsius: "Celsius (°C)"
        case .fahrenheit: "Fahrenheit (°F)"
        }
    }

    var shortLabel: String {
        switch self {
        case .celsius: "°C"
        case .fahrenheit: "°F"
        }
    }

    static func systemDefault() -> WeatherTemperatureUnit {
        Locale.current.measurementSystem == .us ? .fahrenheit : .celsius
    }

    func formatted(_ celsiusValue: Double) -> String {
        switch self {
        case .celsius: return "\(Int(celsiusValue.rounded()))°C"
        case .fahrenheit: return "\(Int((celsiusValue * 9 / 5 + 32).rounded()))°F"
        }
    }
}

enum WeatherDataSource: String, Identifiable, Equatable, Codable {
    case fitTemperature
    case manual
    case openMeteo
    case openWeather

    var id: String { rawValue }

    static let inspectorCases: [WeatherDataSource] = [.manual, .openMeteo, .openWeather]

    var label: String {
        switch self {
        case .fitTemperature: "FIT Temperature"
        case .manual: "Manual"
        case .openMeteo: "Open-Meteo API"
        case .openWeather: "OpenWeather API"
        }
    }

    var isAPI: Bool {
        switch self {
        case .openMeteo, .openWeather:
            true
        case .fitTemperature, .manual:
            false
        }
    }
}

enum WeatherMetricSlotValue: String, CaseIterable, Identifiable, Equatable, Hashable, Codable {
    case none
    case humidity
    case highLow
    case wind
    case feelsLike

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "-"
        case .humidity: "Humidity"
        case .highLow: "High / Low"
        case .wind: "Wind"
        case .feelsLike: "Feels Like"
        }
    }

    var compactLabel: String {
        switch self {
        case .none: "-"
        case .humidity: "RH"
        case .highLow: "H/L"
        case .wind: "Wind"
        case .feelsLike: "Feels"
        }
    }
}

enum WeatherWidgetPreset: String, CaseIterable, Identifiable, Equatable, Codable {
    case simpleCard
    case compactStrip
    case forecastTile
    case minimalText
    case dashboardBar

    var id: String { rawValue }

    var label: String {
        switch self {
        case .simpleCard: "Simple Card"
        case .compactStrip: "Compact Strip"
        case .forecastTile: "Forecast Tile"
        case .minimalText: "Minimal Text"
        case .dashboardBar: "Dashboard Bar"
        }
    }

    var defaultSize: CGSize {
        switch self {
        case .simpleCard: CGSize(width: 300, height: 110)
        case .compactStrip: CGSize(width: 220, height: 56)
        case .forecastTile: CGSize(width: 180, height: 180)
        case .minimalText: CGSize(width: 160, height: 92)
        case .dashboardBar: CGSize(width: 560, height: 112)
        }
    }

    var metricSlotCount: Int {
        switch self {
        case .simpleCard: 1
        case .compactStrip: 0
        case .forecastTile: 3
        case .minimalText: 0
        case .dashboardBar: 3
        }
    }

    var defaultMetricSlots: [WeatherMetricSlotValue] {
        switch self {
        case .simpleCard:
            [.humidity]
        case .compactStrip, .minimalText:
            []
        case .forecastTile:
            [.highLow, .humidity, .wind]
        case .dashboardBar:
            [.humidity, .wind, .feelsLike]
        }
    }
}

enum WeatherWidgetPalette: String, CaseIterable, Identifiable, Equatable, Codable {
    case presetDefault
    case blueGlass
    case lightGlass
    case graphite
    case minimalWhite

    var id: String { rawValue }

    var label: String {
        switch self {
        case .presetDefault: "Preset Default"
        case .blueGlass: "Blue Glass"
        case .lightGlass: "Light Glass"
        case .graphite: "Graphite"
        case .minimalWhite: "Minimal White"
        }
    }
}

struct WeatherPayload: Equatable, Codable {
    var condition: WeatherCondition
    var temperatureCelsius: Double
    var humidity: Double?
    var highTemperatureCelsius: Double?
    var lowTemperatureCelsius: Double?
    var windKph: Double?
    var feelsLikeCelsius: Double?
    var resolvedLocation: String?
    var sourceDate: Date?
    var fetchLocationMode: WeatherFetchLocationMode?

    init(
        condition: WeatherCondition,
        temperatureCelsius: Double,
        humidity: Double?,
        highTemperatureCelsius: Double?,
        lowTemperatureCelsius: Double?,
        windKph: Double?,
        feelsLikeCelsius: Double?,
        resolvedLocation: String?,
        sourceDate: Date?,
        fetchLocationMode: WeatherFetchLocationMode? = nil
    ) {
        self.condition = condition
        self.temperatureCelsius = temperatureCelsius
        self.humidity = humidity
        self.highTemperatureCelsius = highTemperatureCelsius
        self.lowTemperatureCelsius = lowTemperatureCelsius
        self.windKph = windKph
        self.feelsLikeCelsius = feelsLikeCelsius
        self.resolvedLocation = resolvedLocation
        self.sourceDate = sourceDate
        self.fetchLocationMode = fetchLocationMode
    }
}

/// Typography for a single piece of text inside a weather widget
/// (location, condition, temperature, slot title, slot label).
/// `fontSize` is the design-time size at the preset's reference width;
/// views scale it proportionally to the rendered width.
struct WeatherTextStyle: Equatable, Codable {
    var fontName: String
    var fontSize: Double
    var fontWeight: OverlayFontWeight
    var color: OverlayColor

    init(fontName: String = FontLibraryManager.currentDefaultFamily,
         fontSize: Double,
         fontWeight: OverlayFontWeight,
         color: OverlayColor) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.color = color
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fontName = try c.decodeIfPresent(String.self, forKey: .fontName) ?? FontLibraryManager.currentDefaultFamily
        fontSize = try c.decodeIfPresent(Double.self, forKey: .fontSize) ?? 14
        fontWeight = try c.decodeIfPresent(OverlayFontWeight.self, forKey: .fontWeight) ?? .medium
        color = try c.decodeIfPresent(OverlayColor.self, forKey: .color) ?? .white
    }

    private enum CodingKeys: String, CodingKey {
        case fontName, fontSize, fontWeight, color
    }
}

struct WeatherWidgetStyle: Equatable, Codable {
    var preset: WeatherWidgetPreset
    var dataSource: WeatherDataSource
    var useFITTemperature: Bool
    var manualCondition: WeatherCondition
    var manualTemperatureCelsius: Double
    var manualHumidity: Double
    var manualHigh: Double
    var manualLow: Double
    var manualWind: Double
    var manualFeelsLike: Double
    var conditionLabelOverride: String
    var humiditySuffix: String
    var humidityMetricLabel: String
    var windMetricLabel: String
    var feelsLikeMetricLabel: String
    var temperatureUnit: WeatherTemperatureUnit
    var locationText: String
    var showLocation: Bool
    var showWeekday: Bool
    var showHumidity: Bool
    var showHighLow: Bool
    var showWind: Bool
    var showFeelsLike: Bool
    var metricSlots: [WeatherMetricSlotValue]
    var cardBackgroundColor: OverlayColor
    var cardBackgroundOpacity: Double
    var cardCornerRadius: Double
    var dividerEnabled: Bool
    var dividerColor: OverlayColor
    var dividerThickness: Double
    var dividerOpacity: Double
    var palette: WeatherWidgetPalette
    var iconSize: Double
    var showIcon: Bool
    var showConditionLabel: Bool
    var width: Double
    var height: Double
    var slotBackgroundColor: OverlayColor
    var slotBackgroundOpacity: Double
    var slotSpacing: Double
    var locationTextStyle: WeatherTextStyle
    var conditionTextStyle: WeatherTextStyle
    var temperatureTextStyle: WeatherTextStyle
    var slotTitleTextStyle: WeatherTextStyle
    var slotLabelTextStyle: WeatherTextStyle
    var cachedWeather: WeatherPayload?

    init(
        preset: WeatherWidgetPreset,
        dataSource: WeatherDataSource,
        useFITTemperature: Bool = false,
        manualCondition: WeatherCondition,
        manualTemperatureCelsius: Double,
        manualHumidity: Double,
        manualHigh: Double,
        manualLow: Double,
        manualWind: Double,
        manualFeelsLike: Double,
        conditionLabelOverride: String,
        humiditySuffix: String,
        humidityMetricLabel: String,
        windMetricLabel: String,
        feelsLikeMetricLabel: String,
        temperatureUnit: WeatherTemperatureUnit,
        locationText: String,
        showLocation: Bool,
        showWeekday: Bool,
        showHumidity: Bool,
        showHighLow: Bool,
        showWind: Bool,
        showFeelsLike: Bool,
        metricSlots: [WeatherMetricSlotValue],
        cardBackgroundColor: OverlayColor,
        cardBackgroundOpacity: Double,
        cardCornerRadius: Double,
        dividerEnabled: Bool,
        dividerColor: OverlayColor,
        dividerThickness: Double,
        dividerOpacity: Double,
        palette: WeatherWidgetPalette,
        iconSize: Double,
        showIcon: Bool,
        showConditionLabel: Bool,
        width: Double,
        height: Double,
        slotBackgroundColor: OverlayColor,
        slotBackgroundOpacity: Double,
        slotSpacing: Double,
        locationTextStyle: WeatherTextStyle,
        conditionTextStyle: WeatherTextStyle,
        temperatureTextStyle: WeatherTextStyle,
        slotTitleTextStyle: WeatherTextStyle,
        slotLabelTextStyle: WeatherTextStyle,
        cachedWeather: WeatherPayload?
    ) {
        self.preset = preset
        self.dataSource = dataSource
        self.useFITTemperature = useFITTemperature
        self.manualCondition = manualCondition
        self.manualTemperatureCelsius = manualTemperatureCelsius
        self.manualHumidity = manualHumidity
        self.manualHigh = manualHigh
        self.manualLow = manualLow
        self.manualWind = manualWind
        self.manualFeelsLike = manualFeelsLike
        self.conditionLabelOverride = conditionLabelOverride
        self.humiditySuffix = humiditySuffix
        self.humidityMetricLabel = humidityMetricLabel
        self.windMetricLabel = windMetricLabel
        self.feelsLikeMetricLabel = feelsLikeMetricLabel
        self.temperatureUnit = temperatureUnit
        self.locationText = locationText
        self.showLocation = showLocation
        self.showWeekday = showWeekday
        self.showHumidity = showHumidity
        self.showHighLow = showHighLow
        self.showWind = showWind
        self.showFeelsLike = showFeelsLike
        self.metricSlots = Self.normalizedMetricSlots(metricSlots, for: preset)
        self.cardBackgroundColor = cardBackgroundColor
        self.cardBackgroundOpacity = cardBackgroundOpacity
        self.cardCornerRadius = cardCornerRadius
        self.dividerEnabled = dividerEnabled
        self.dividerColor = dividerColor
        self.dividerThickness = dividerThickness
        self.dividerOpacity = dividerOpacity
        self.palette = palette
        self.iconSize = iconSize
        self.showIcon = showIcon
        self.showConditionLabel = showConditionLabel
        self.width = width
        self.height = height
        self.slotBackgroundColor = slotBackgroundColor
        self.slotBackgroundOpacity = slotBackgroundOpacity
        self.slotSpacing = slotSpacing
        self.locationTextStyle = locationTextStyle
        self.conditionTextStyle = conditionTextStyle
        self.temperatureTextStyle = temperatureTextStyle
        self.slotTitleTextStyle = slotTitleTextStyle
        self.slotLabelTextStyle = slotLabelTextStyle
        self.cachedWeather = cachedWeather
    }

    static let `default` = WeatherWidgetStyle.preset(.simpleCard)

    static func preset(_ presetValue: WeatherWidgetPreset) -> WeatherWidgetStyle {
        switch presetValue {
        case .simpleCard:
            WeatherWidgetStyle(
                preset: .simpleCard, dataSource: .manual,
                manualCondition: .rain, manualTemperatureCelsius: 13,
                manualHumidity: 87, manualHigh: 16, manualLow: 11,
                manualWind: 12, manualFeelsLike: 21,
                conditionLabelOverride: "", humiditySuffix: "RH",
                humidityMetricLabel: "RH", windMetricLabel: "Wind", feelsLikeMetricLabel: "Feels",
                temperatureUnit: .systemDefault(), locationText: "大阪, 日本",
                showLocation: true, showWeekday: true, showHumidity: true,
                showHighLow: false, showWind: false, showFeelsLike: false,
                metricSlots: WeatherWidgetPreset.simpleCard.defaultMetricSlots,
                cardBackgroundColor: OverlayColor(red: 0.30, green: 0.62, blue: 1.0, alpha: 1),
                cardBackgroundOpacity: 0.92, cardCornerRadius: 10,
                dividerEnabled: true, dividerColor: .white, dividerThickness: 1, dividerOpacity: 0.34,
                palette: .blueGlass, iconSize: 54, showIcon: true,
                showConditionLabel: true, width: 300, height: 110,
                slotBackgroundColor: .white, slotBackgroundOpacity: 0.16, slotSpacing: 10,
                locationTextStyle: WeatherTextStyle(fontSize: 19, fontWeight: .bold, color: .white),
                conditionTextStyle: WeatherTextStyle(fontSize: 26, fontWeight: .semibold, color: .white),
                temperatureTextStyle: WeatherTextStyle(fontSize: 33, fontWeight: .bold, color: .white),
                slotTitleTextStyle: WeatherTextStyle(fontSize: 15, fontWeight: .semibold, color: OverlayColor(red: 1, green: 1, blue: 1, alpha: 0.72)),
                slotLabelTextStyle: WeatherTextStyle(fontSize: 15, fontWeight: .semibold, color: OverlayColor(red: 1, green: 1, blue: 1, alpha: 0.72)),
                cachedWeather: nil
            )
        case .compactStrip:
            WeatherWidgetStyle(
                preset: .compactStrip, dataSource: .manual,
                manualCondition: .rain, manualTemperatureCelsius: 13,
                manualHumidity: 87, manualHigh: 16, manualLow: 11,
                manualWind: 0, manualFeelsLike: 0,
                conditionLabelOverride: "", humiditySuffix: "RH",
                humidityMetricLabel: "RH", windMetricLabel: "Wind", feelsLikeMetricLabel: "Feels",
                temperatureUnit: .systemDefault(), locationText: "Osaka",
                showLocation: true, showWeekday: false, showHumidity: false,
                showHighLow: false, showWind: false, showFeelsLike: false,
                metricSlots: WeatherWidgetPreset.compactStrip.defaultMetricSlots,
                cardBackgroundColor: OverlayColor(red: 0.90, green: 0.96, blue: 1.0, alpha: 1),
                cardBackgroundOpacity: 0.96, cardCornerRadius: 28,
                dividerEnabled: true, dividerColor: OverlayColor(red: 0.20, green: 0.34, blue: 0.52, alpha: 1), dividerThickness: 1, dividerOpacity: 0.15,
                palette: .lightGlass, iconSize: 32, showIcon: true,
                showConditionLabel: true, width: 220, height: 56,
                slotBackgroundColor: OverlayColor(red: 0.20, green: 0.34, blue: 0.52, alpha: 1), slotBackgroundOpacity: 0.10, slotSpacing: 10,
                locationTextStyle: WeatherTextStyle(fontSize: 11, fontWeight: .medium, color: OverlayColor(red: 0.25, green: 0.37, blue: 0.52, alpha: 0.78)),
                conditionTextStyle: WeatherTextStyle(fontSize: 12, fontWeight: .semibold, color: OverlayColor(red: 0.08, green: 0.17, blue: 0.29, alpha: 0.86)),
                temperatureTextStyle: WeatherTextStyle(fontSize: 28, fontWeight: .bold, color: OverlayColor(red: 0.08, green: 0.17, blue: 0.29, alpha: 1)),
                slotTitleTextStyle: WeatherTextStyle(fontSize: 11, fontWeight: .semibold, color: OverlayColor(red: 0.25, green: 0.37, blue: 0.52, alpha: 0.78)),
                slotLabelTextStyle: WeatherTextStyle(fontSize: 11, fontWeight: .semibold, color: OverlayColor(red: 0.08, green: 0.17, blue: 0.29, alpha: 1)),
                cachedWeather: nil
            )
        case .forecastTile:
            WeatherWidgetStyle(
                preset: .forecastTile, dataSource: .manual,
                manualCondition: .partlyCloudy, manualTemperatureCelsius: 13,
                manualHumidity: 87, manualHigh: 16, manualLow: 11,
                manualWind: 0, manualFeelsLike: 0,
                conditionLabelOverride: "", humiditySuffix: "RH",
                humidityMetricLabel: "RH", windMetricLabel: "Wind", feelsLikeMetricLabel: "Feels",
                temperatureUnit: .systemDefault(), locationText: "大阪, 日本",
                showLocation: true, showWeekday: true, showHumidity: true,
                showHighLow: true, showWind: false, showFeelsLike: false,
                metricSlots: WeatherWidgetPreset.forecastTile.defaultMetricSlots,
                cardBackgroundColor: OverlayColor(red: 0.12, green: 0.18, blue: 0.25, alpha: 1),
                cardBackgroundOpacity: 0.88, cardCornerRadius: 16,
                dividerEnabled: true, dividerColor: .white, dividerThickness: 1, dividerOpacity: 0.18,
                palette: .graphite, iconSize: 54, showIcon: true,
                showConditionLabel: false, width: 180, height: 180,
                slotBackgroundColor: .white, slotBackgroundOpacity: 0.12, slotSpacing: 7,
                locationTextStyle: WeatherTextStyle(fontSize: 15, fontWeight: .semibold, color: .white),
                conditionTextStyle: WeatherTextStyle(fontSize: 11, fontWeight: .medium, color: OverlayColor(red: 1, green: 1, blue: 1, alpha: 0.66)),
                temperatureTextStyle: WeatherTextStyle(fontSize: 43, fontWeight: .bold, color: .white),
                slotTitleTextStyle: WeatherTextStyle(fontSize: 11, fontWeight: .semibold, color: OverlayColor(red: 1, green: 1, blue: 1, alpha: 0.66)),
                slotLabelTextStyle: WeatherTextStyle(fontSize: 11, fontWeight: .semibold, color: OverlayColor(red: 1, green: 1, blue: 1, alpha: 0.66)),
                cachedWeather: nil
            )
        case .minimalText:
            WeatherWidgetStyle(
                preset: .minimalText, dataSource: .manual,
                manualCondition: .cloudy, manualTemperatureCelsius: 13,
                manualHumidity: 50, manualHigh: 16, manualLow: 11,
                manualWind: 0, manualFeelsLike: 0,
                conditionLabelOverride: "", humiditySuffix: "RH",
                humidityMetricLabel: "RH", windMetricLabel: "Wind", feelsLikeMetricLabel: "Feels",
                temperatureUnit: .systemDefault(), locationText: "大阪, 日本",
                showLocation: true, showWeekday: false, showHumidity: false,
                showHighLow: false, showWind: false, showFeelsLike: false,
                metricSlots: WeatherWidgetPreset.minimalText.defaultMetricSlots,
                cardBackgroundColor: OverlayColor(red: 0, green: 0, blue: 0, alpha: 1),
                cardBackgroundOpacity: 0, cardCornerRadius: 0,
                dividerEnabled: true, dividerColor: .white, dividerThickness: 1, dividerOpacity: 0.2,
                palette: .minimalWhite, iconSize: 30, showIcon: true,
                showConditionLabel: true, width: 180, height: 110,
                slotBackgroundColor: .black, slotBackgroundOpacity: 0.18, slotSpacing: 8,
                locationTextStyle: WeatherTextStyle(fontSize: 15, fontWeight: .semibold, color: OverlayColor(red: 1, green: 1, blue: 1, alpha: 0.76)),
                conditionTextStyle: WeatherTextStyle(fontSize: 14, fontWeight: .medium, color: OverlayColor(red: 1, green: 1, blue: 1, alpha: 0.76)),
                temperatureTextStyle: WeatherTextStyle(fontSize: 48, fontWeight: .bold, color: .white),
                slotTitleTextStyle: WeatherTextStyle(fontSize: 11, fontWeight: .semibold, color: OverlayColor(red: 1, green: 1, blue: 1, alpha: 0.76)),
                slotLabelTextStyle: WeatherTextStyle(fontSize: 13, fontWeight: .bold, color: .white),
                cachedWeather: nil
            )
        case .dashboardBar:
            WeatherWidgetStyle(
                preset: .dashboardBar, dataSource: .manual,
                manualCondition: .rain, manualTemperatureCelsius: 13,
                manualHumidity: 87, manualHigh: 16, manualLow: 11,
                manualWind: 9, manualFeelsLike: 12,
                conditionLabelOverride: "", humiditySuffix: "RH",
                humidityMetricLabel: "RH", windMetricLabel: "Wind", feelsLikeMetricLabel: "Feels",
                temperatureUnit: .systemDefault(), locationText: "大阪, 日本",
                showLocation: true, showWeekday: false, showHumidity: true,
                showHighLow: false, showWind: true, showFeelsLike: true,
                metricSlots: WeatherWidgetPreset.dashboardBar.defaultMetricSlots,
                cardBackgroundColor: OverlayColor(red: 0.12, green: 0.14, blue: 0.17, alpha: 1),
                cardBackgroundOpacity: 0.90, cardCornerRadius: 12,
                dividerEnabled: true, dividerColor: .white, dividerThickness: 1, dividerOpacity: 0.18,
                palette: .graphite, iconSize: 38, showIcon: true,
                showConditionLabel: true, width: 560, height: 112,
                slotBackgroundColor: .white, slotBackgroundOpacity: 0.12, slotSpacing: 10,
                locationTextStyle: WeatherTextStyle(fontSize: 17, fontWeight: .bold, color: .white),
                conditionTextStyle: WeatherTextStyle(fontSize: 13, fontWeight: .medium, color: OverlayColor(red: 1, green: 1, blue: 1, alpha: 0.66)),
                temperatureTextStyle: WeatherTextStyle(fontSize: 46, fontWeight: .bold, color: .white),
                slotTitleTextStyle: WeatherTextStyle(fontSize: 11, fontWeight: .semibold, color: OverlayColor(red: 1, green: 1, blue: 1, alpha: 0.66)),
                slotLabelTextStyle: WeatherTextStyle(fontSize: 13, fontWeight: .bold, color: .white),
                cachedWeather: nil
            )
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = WeatherWidgetStyle.preset(try c.decodeIfPresent(WeatherWidgetPreset.self, forKey: .preset) ?? .simpleCard)
        preset = try c.decodeIfPresent(WeatherWidgetPreset.self, forKey: .preset) ?? defaults.preset
        let decodedDataSource = try c.decodeIfPresent(WeatherDataSource.self, forKey: .dataSource) ?? defaults.dataSource
        switch decodedDataSource {
        case .fitTemperature:
            dataSource = .manual
        default:
            dataSource = decodedDataSource
        }
        useFITTemperature = try c.decodeIfPresent(Bool.self, forKey: .useFITTemperature)
            ?? (decodedDataSource == .fitTemperature)
        manualCondition = try c.decodeIfPresent(WeatherCondition.self, forKey: .manualCondition) ?? defaults.manualCondition
        manualTemperatureCelsius = try c.decodeIfPresent(Double.self, forKey: .manualTemperatureCelsius) ?? defaults.manualTemperatureCelsius
        manualHumidity = try c.decodeIfPresent(Double.self, forKey: .manualHumidity) ?? defaults.manualHumidity
        manualHigh = try c.decodeIfPresent(Double.self, forKey: .manualHigh) ?? defaults.manualHigh
        manualLow = try c.decodeIfPresent(Double.self, forKey: .manualLow) ?? defaults.manualLow
        manualWind = try c.decodeIfPresent(Double.self, forKey: .manualWind) ?? defaults.manualWind
        manualFeelsLike = try c.decodeIfPresent(Double.self, forKey: .manualFeelsLike) ?? defaults.manualFeelsLike
        conditionLabelOverride = try c.decodeIfPresent(String.self, forKey: .conditionLabelOverride) ?? defaults.conditionLabelOverride
        humiditySuffix = try c.decodeIfPresent(String.self, forKey: .humiditySuffix) ?? defaults.humiditySuffix
        humidityMetricLabel = try c.decodeIfPresent(String.self, forKey: .humidityMetricLabel) ?? defaults.humidityMetricLabel
        windMetricLabel = try c.decodeIfPresent(String.self, forKey: .windMetricLabel) ?? defaults.windMetricLabel
        feelsLikeMetricLabel = try c.decodeIfPresent(String.self, forKey: .feelsLikeMetricLabel) ?? defaults.feelsLikeMetricLabel
        temperatureUnit = try c.decodeIfPresent(WeatherTemperatureUnit.self, forKey: .temperatureUnit) ?? defaults.temperatureUnit
        locationText = try c.decodeIfPresent(String.self, forKey: .locationText) ?? defaults.locationText
        showLocation = try c.decodeIfPresent(Bool.self, forKey: .showLocation) ?? defaults.showLocation
        showWeekday = try c.decodeIfPresent(Bool.self, forKey: .showWeekday) ?? defaults.showWeekday
        showHumidity = try c.decodeIfPresent(Bool.self, forKey: .showHumidity) ?? defaults.showHumidity
        showHighLow = try c.decodeIfPresent(Bool.self, forKey: .showHighLow) ?? defaults.showHighLow
        showWind = try c.decodeIfPresent(Bool.self, forKey: .showWind) ?? defaults.showWind
        showFeelsLike = try c.decodeIfPresent(Bool.self, forKey: .showFeelsLike) ?? defaults.showFeelsLike
        metricSlots = Self.normalizedMetricSlots(
            try c.decodeIfPresent([WeatherMetricSlotValue].self, forKey: .metricSlots)
                ?? Self.legacyMetricSlots(showHumidity: showHumidity, showHighLow: showHighLow, showWind: showWind, showFeelsLike: showFeelsLike, fallback: defaults.metricSlots),
            for: preset
        )
        cardBackgroundColor = try c.decodeIfPresent(OverlayColor.self, forKey: .cardBackgroundColor) ?? defaults.cardBackgroundColor
        cardBackgroundOpacity = try c.decodeIfPresent(Double.self, forKey: .cardBackgroundOpacity) ?? defaults.cardBackgroundOpacity
        cardCornerRadius = try c.decodeIfPresent(Double.self, forKey: .cardCornerRadius) ?? defaults.cardCornerRadius
        dividerEnabled = try c.decodeIfPresent(Bool.self, forKey: .dividerEnabled) ?? defaults.dividerEnabled
        dividerColor = try c.decodeIfPresent(OverlayColor.self, forKey: .dividerColor) ?? defaults.dividerColor
        dividerThickness = try c.decodeIfPresent(Double.self, forKey: .dividerThickness) ?? defaults.dividerThickness
        dividerOpacity = try c.decodeIfPresent(Double.self, forKey: .dividerOpacity) ?? defaults.dividerOpacity
        palette = try c.decodeIfPresent(WeatherWidgetPalette.self, forKey: .palette) ?? defaults.palette
        iconSize = try c.decodeIfPresent(Double.self, forKey: .iconSize) ?? defaults.iconSize
        showIcon = try c.decodeIfPresent(Bool.self, forKey: .showIcon) ?? true
        showConditionLabel = try c.decodeIfPresent(Bool.self, forKey: .showConditionLabel) ?? defaults.showConditionLabel
        width = try c.decodeIfPresent(Double.self, forKey: .width) ?? defaults.width
        height = try c.decodeIfPresent(Double.self, forKey: .height) ?? defaults.height
        slotBackgroundColor = try c.decodeIfPresent(OverlayColor.self, forKey: .slotBackgroundColor) ?? defaults.slotBackgroundColor
        slotBackgroundOpacity = try c.decodeIfPresent(Double.self, forKey: .slotBackgroundOpacity) ?? defaults.slotBackgroundOpacity
        slotSpacing = try c.decodeIfPresent(Double.self, forKey: .slotSpacing) ?? defaults.slotSpacing
        locationTextStyle = try c.decodeIfPresent(WeatherTextStyle.self, forKey: .locationTextStyle) ?? defaults.locationTextStyle
        conditionTextStyle = try c.decodeIfPresent(WeatherTextStyle.self, forKey: .conditionTextStyle) ?? defaults.conditionTextStyle
        temperatureTextStyle = try c.decodeIfPresent(WeatherTextStyle.self, forKey: .temperatureTextStyle) ?? defaults.temperatureTextStyle
        slotTitleTextStyle = try c.decodeIfPresent(WeatherTextStyle.self, forKey: .slotTitleTextStyle) ?? defaults.slotTitleTextStyle
        slotLabelTextStyle = try c.decodeIfPresent(WeatherTextStyle.self, forKey: .slotLabelTextStyle) ?? defaults.slotLabelTextStyle
        cachedWeather = try c.decodeIfPresent(WeatherPayload.self, forKey: .cachedWeather)
    }

    func normalizedMetricSlots() -> [WeatherMetricSlotValue] {
        Self.normalizedMetricSlots(metricSlots, for: preset)
    }

    static func normalizedMetricSlots(_ slots: [WeatherMetricSlotValue], for preset: WeatherWidgetPreset) -> [WeatherMetricSlotValue] {
        let count = preset.metricSlotCount
        guard count > 0 else { return [] }
        let seed = slots.isEmpty ? preset.defaultMetricSlots : slots
        var normalized = Array(seed.prefix(count))
        while normalized.count < count {
            normalized.append(preset.defaultMetricSlots[safe: normalized.count] ?? .humidity)
        }
        return normalized
    }

    private static func legacyMetricSlots(
        showHumidity: Bool,
        showHighLow: Bool,
        showWind: Bool,
        showFeelsLike: Bool,
        fallback: [WeatherMetricSlotValue]
    ) -> [WeatherMetricSlotValue] {
        var slots: [WeatherMetricSlotValue] = []
        if showHumidity { slots.append(.humidity) }
        if showHighLow { slots.append(.highLow) }
        if showWind { slots.append(.wind) }
        if showFeelsLike { slots.append(.feelsLike) }
        return slots.isEmpty ? fallback : slots
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
