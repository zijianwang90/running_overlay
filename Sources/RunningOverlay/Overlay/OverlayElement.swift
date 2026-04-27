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
    var style: OverlayStyle
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
        }
    }

    var supportsTextPresets: Bool {
        switch self {
        case .distanceTimeline, .elevationChart, .runningGauge, .routeMap:
            false
        default:
            true
        }
    }

    /// Numeric Overlay template applies to type-derived metric overlays only.
    /// See `docs/design/numeric-overlay-ui.md`.
    var isNumericOverlay: Bool {
        switch self {
        case .heartRate, .pace, .calories, .elapsedTime, .realTime,
             .distance, .elevation, .cadence, .power:
            true
        default:
            false
        }
    }

    var defaultUnitOption: OverlayUnitOption {
        OverlayUnitOption.defaultOption(for: self)
    }

    /// Recommended numeric overlay style preset when adding a new element of
    /// this type. See `docs/design/numeric-overlay-ui.md`.
    var defaultNumericPreset: OverlayTextPreset? {
        switch self {
        case .distance: .minimal
        case .pace: .minimal
        case .heartRate: .pillBadge
        case .power: .racingStripe
        case .cadence: .pillBadge
        case .calories: .metricCard
        case .elevation: .minimalLabel
        case .elapsedTime: .digitalWatch
        case .realTime: .minimal
        default: nil
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
        case .distanceTimeline, .elevationChart, .runningGauge, .routeMap:
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
    var routeMapBackgroundStyle: OverlayRouteMapBackgroundStyle
    var routeMapLegendVisible: Bool
    var routeMapLegendMode: OverlayRouteMapLegendMode
    /// Container visual preset (Square / Circle × Hard / Gradient edge).
    /// Selecting a preset writes the bundled defaults onto the other route
    /// map fields. See `docs/design/route-map-overlay-ui.md` for the table of
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
    var fontName: String
    var fontSize: Double
    var fontWeight: OverlayFontWeight
    var foregroundColor: OverlayColor
    var backgroundOpacity: Double
    var shadowOpacity: Double
    var shadowRadius: Double

    // Numeric Overlay additions (see docs/design/numeric-overlay-ui.md)
    var unitOption: OverlayUnitOption
    var showLabel: Bool
    var showUnit: Bool
    var customLabel: String
    var rotationDegrees: Double
    var textAlignment: OverlayTextAlignment
    var accentColor: OverlayColor
    var backgroundEnabled: Bool
    var backgroundColor: OverlayColor
    var backgroundRadius: Double
    var backgroundPaddingX: Double
    var backgroundPaddingY: Double
    var shadowEnabled: Bool
    var shadowOffsetX: Double
    var shadowOffsetY: Double

    /// Running Gauge style. Used only by overlays of type `.runningGauge` —
    /// safely ignored otherwise. Stored as a sub-struct so the gauge can grow
    /// dial / ring / tick / region settings without polluting the rest of the
    /// overlay style namespace. See `Sources/RunningOverlay/Overlay/RunningGaugeModel.swift`.
    var gauge: RunningGaugeStyle

    /// Stats bar attached below the route map container. Visible = false by
    /// default so existing projects are unaffected.
    var routeMapStatsBar: OverlayRouteMapStatsBarConfig

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
        routeMapBackgroundStyle: .dark,
        routeMapLegendVisible: true,
        routeMapLegendMode: .startFinishDistance,
        routeMapContainerPreset: .squareHardEdge,
        routeMapMapOpacity: 0.72,
        routeMapBorderVisible: true,
        routeMapWidth: 320,
        routeMapHeight: 240,
        fontName: "SF Pro",
        fontSize: 28,
        fontWeight: .semibold,
        foregroundColor: .white,
        backgroundOpacity: 0.22,
        shadowOpacity: 0.35,
        shadowRadius: 4,
        unitOption: .paceMetric,
        showLabel: false,
        showUnit: true,
        customLabel: "",
        rotationDegrees: 0,
        textAlignment: .leading,
        accentColor: .blue,
        backgroundEnabled: true,
        backgroundColor: .black,
        backgroundRadius: 6,
        backgroundPaddingX: 10,
        backgroundPaddingY: 6,
        shadowEnabled: true,
        shadowOffsetX: 0,
        shadowOffsetY: 2,
        gauge: RunningGaugeStyle.default,
        routeMapStatsBar: .default
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
        routeMapBackgroundStyle: OverlayRouteMapBackgroundStyle = .dark,
        routeMapLegendVisible: Bool = true,
        routeMapLegendMode: OverlayRouteMapLegendMode = .startFinishDistance,
        routeMapContainerPreset: OverlayRouteMapContainerPreset = .squareHardEdge,
        routeMapMapOpacity: Double = 0.72,
        routeMapBorderVisible: Bool = true,
        routeMapWidth: Double = 320,
        routeMapHeight: Double = 240,
        fontName: String,
        fontSize: Double,
        fontWeight: OverlayFontWeight,
        foregroundColor: OverlayColor,
        backgroundOpacity: Double,
        shadowOpacity: Double,
        shadowRadius: Double,
        unitOption: OverlayUnitOption = .paceMetric,
        showLabel: Bool = false,
        showUnit: Bool = true,
        customLabel: String = "",
        rotationDegrees: Double = 0,
        textAlignment: OverlayTextAlignment = .leading,
        accentColor: OverlayColor = .blue,
        backgroundEnabled: Bool = true,
        backgroundColor: OverlayColor = .black,
        backgroundRadius: Double = 6,
        backgroundPaddingX: Double = 10,
        backgroundPaddingY: Double = 6,
        shadowEnabled: Bool = true,
        shadowOffsetX: Double = 0,
        shadowOffsetY: Double = 2,
        gauge: RunningGaugeStyle = .default,
        routeMapStatsBar: OverlayRouteMapStatsBarConfig = .default
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
        self.routeMapBackgroundStyle = routeMapBackgroundStyle
        self.routeMapLegendVisible = routeMapLegendVisible
        self.routeMapLegendMode = routeMapLegendMode
        self.routeMapContainerPreset = routeMapContainerPreset
        self.routeMapMapOpacity = min(max(routeMapMapOpacity, 0), 1)
        self.routeMapBorderVisible = routeMapBorderVisible
        self.routeMapWidth = min(max(routeMapWidth, 80), 1200)
        self.routeMapHeight = min(max(routeMapHeight, 80), 1200)
        self.fontName = fontName
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.foregroundColor = foregroundColor
        self.backgroundOpacity = backgroundOpacity
        self.shadowOpacity = shadowOpacity
        self.shadowRadius = shadowRadius
        self.unitOption = unitOption
        self.showLabel = showLabel
        self.showUnit = showUnit
        self.customLabel = customLabel
        self.rotationDegrees = rotationDegrees
        self.textAlignment = textAlignment
        self.accentColor = accentColor
        self.backgroundEnabled = backgroundEnabled
        self.backgroundColor = backgroundColor
        self.backgroundRadius = backgroundRadius
        self.backgroundPaddingX = backgroundPaddingX
        self.backgroundPaddingY = backgroundPaddingY
        self.shadowEnabled = shadowEnabled
        self.shadowOffsetX = shadowOffsetX
        self.shadowOffsetY = shadowOffsetY
        self.gauge = gauge
        self.routeMapStatsBar = routeMapStatsBar
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
        fontName = try container.decodeIfPresent(String.self, forKey: .fontName) ?? Self.default.fontName
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? Self.default.fontSize
        fontWeight = try container.decodeIfPresent(OverlayFontWeight.self, forKey: .fontWeight) ?? Self.default.fontWeight
        foregroundColor = try container.decodeIfPresent(OverlayColor.self, forKey: .foregroundColor) ?? Self.default.foregroundColor
        backgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? Self.default.backgroundOpacity
        shadowOpacity = try container.decodeIfPresent(Double.self, forKey: .shadowOpacity) ?? Self.default.shadowOpacity
        shadowRadius = try container.decodeIfPresent(Double.self, forKey: .shadowRadius) ?? Self.default.shadowRadius
        unitOption = try container.decodeIfPresent(OverlayUnitOption.self, forKey: .unitOption) ?? Self.default.unitOption
        showLabel = try container.decodeIfPresent(Bool.self, forKey: .showLabel) ?? Self.default.showLabel
        showUnit = try container.decodeIfPresent(Bool.self, forKey: .showUnit) ?? Self.default.showUnit
        customLabel = try container.decodeIfPresent(String.self, forKey: .customLabel) ?? Self.default.customLabel
        rotationDegrees = try container.decodeIfPresent(Double.self, forKey: .rotationDegrees) ?? Self.default.rotationDegrees
        textAlignment = try container.decodeIfPresent(OverlayTextAlignment.self, forKey: .textAlignment) ?? Self.default.textAlignment
        accentColor = try container.decodeIfPresent(OverlayColor.self, forKey: .accentColor) ?? Self.default.accentColor
        backgroundEnabled = try container.decodeIfPresent(Bool.self, forKey: .backgroundEnabled) ?? Self.default.backgroundEnabled
        backgroundColor = try container.decodeIfPresent(OverlayColor.self, forKey: .backgroundColor) ?? Self.default.backgroundColor
        backgroundRadius = try container.decodeIfPresent(Double.self, forKey: .backgroundRadius) ?? Self.default.backgroundRadius
        backgroundPaddingX = try container.decodeIfPresent(Double.self, forKey: .backgroundPaddingX) ?? Self.default.backgroundPaddingX
        backgroundPaddingY = try container.decodeIfPresent(Double.self, forKey: .backgroundPaddingY) ?? Self.default.backgroundPaddingY
        shadowEnabled = try container.decodeIfPresent(Bool.self, forKey: .shadowEnabled) ?? Self.default.shadowEnabled
        shadowOffsetX = try container.decodeIfPresent(Double.self, forKey: .shadowOffsetX) ?? Self.default.shadowOffsetX
        shadowOffsetY = try container.decodeIfPresent(Double.self, forKey: .shadowOffsetY) ?? Self.default.shadowOffsetY
        if let storedGauge = try container.decodeIfPresent(RunningGaugeStyle.self, forKey: .gauge) {
            gauge = storedGauge
        } else {
            // Migrate older projects: seed RunningGaugeStyle from the legacy
            // top-level `gaugePreset` so existing layouts keep working until
            // the user re-applies a preset from the new gauge inspector.
            gauge = RunningGaugeStyle.preset(gaugePreset)
        }
        routeMapStatsBar = try container.decodeIfPresent(OverlayRouteMapStatsBarConfig.self, forKey: .routeMapStatsBar) ?? .default
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
/// See `docs/design/route-map-overlay-ui.md` and
/// `docs/design/route-map-overlay-ui.spec.json` for the table of values each
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
    case distance
    case pace
    case elapsedTime
    case heartRate
    case elevation
    case cadence
    case power
    case calories

    var id: String { rawValue }

    var label: String {
        switch self {
        case .distance: "Distance"
        case .pace: "Pace"
        case .elapsedTime: "Time"
        case .heartRate: "Heart Rate"
        case .elevation: "Elevation"
        case .cadence: "Cadence"
        case .power: "Power"
        case .calories: "Calories"
        }
    }

    var elementType: OverlayElementType {
        switch self {
        case .distance: .distance
        case .pace: .pace
        case .elapsedTime: .elapsedTime
        case .heartRate: .heartRate
        case .elevation: .elevation
        case .cadence: .cadence
        case .power: .power
        case .calories: .calories
        }
    }
}

struct RouteMapStatsBarSlot: Equatable, Codable {
    var metric: RouteMapStatsMetric
    var visible: Bool
    var customLabel: String
}

struct OverlayRouteMapStatsBarConfig: Equatable, Codable {
    var visible: Bool
    var backgroundOpacity: Double
    var slots: [RouteMapStatsBarSlot]

    static let `default` = OverlayRouteMapStatsBarConfig(
        visible: false,
        backgroundOpacity: 0.88,
        slots: [
            RouteMapStatsBarSlot(metric: .distance,    visible: true, customLabel: ""),
            RouteMapStatsBarSlot(metric: .pace,        visible: true, customLabel: ""),
            RouteMapStatsBarSlot(metric: .elapsedTime, visible: true, customLabel: ""),
            RouteMapStatsBarSlot(metric: .heartRate,   visible: true, customLabel: ""),
        ]
    )
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
    // Canonical numeric overlay style presets. See `docs/design/numeric-overlay-ui.md`
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
