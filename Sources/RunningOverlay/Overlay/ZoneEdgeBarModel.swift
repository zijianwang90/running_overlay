import Foundation

enum ZoneEdgeBarMetric: String, CaseIterable, Identifiable, Codable {
    case heartRate
    case pace

    var id: String { rawValue }

    var label: String {
        switch self {
        case .heartRate: "Heart Rate"
        case .pace: "Pace"
        }
    }
}

enum ZoneEdgeBarPlacement: String, CaseIterable, Identifiable, Codable {
    case edge
    case free

    var id: String { rawValue }

    var label: String {
        switch self {
        case .edge: "Edge"
        case .free: "Free"
        }
    }
}

enum ZoneEdgeBarEdge: String, CaseIterable, Identifiable, Codable {
    case top
    case bottom
    case left
    case right

    var id: String { rawValue }

    var label: String {
        switch self {
        case .top: "Top"
        case .bottom: "Bottom"
        case .left: "Left"
        case .right: "Right"
        }
    }
}

enum ZoneEdgeBarOrientation: String, CaseIterable, Identifiable, Codable {
    case horizontal
    case vertical

    var id: String { rawValue }

    var label: String {
        switch self {
        case .horizontal: "Horizontal"
        case .vertical: "Vertical"
        }
    }
}

struct ZoneEdgeBarStyle: Equatable, Codable {
    var metric: ZoneEdgeBarMetric
    var placement: ZoneEdgeBarPlacement
    var edge: ZoneEdgeBarEdge
    var orientation: ZoneEdgeBarOrientation
    var length: Double
    var thickness: Double
    var edgeInset: Double
    var activeZoneWidthShare: Double
    var activeZoneHeightScale: Double
    var zoneSegmentGap: Double
    var cornerRadius: Double
    var inactiveZoneOpacity: Double
    var borderEnabled: Bool
    var borderColor: OverlayColor
    var borderOpacity: Double
    var borderWidth: Double
    var glowEnabled: Bool
    var glowIntensity: Double
    var markerEnabled: Bool
    var markerShowsValue: Bool
    /// Multiplier for the current-zone arrow. `1` matches the original
    /// thickness-derived size.
    var markerSizeScale: Double
    var thresholdMarkerEnabled: Bool
    /// Multiplier for the threshold "T" line and its label. `1` matches the
    /// original thickness-derived size.
    var thresholdMarkerSizeScale: Double
    var markerText: IntervalHUDBarTextStyle

    static let `default` = ZoneEdgeBarStyle(
        metric: .heartRate,
        placement: .edge,
        edge: .bottom,
        orientation: .horizontal,
        length: 780,
        thickness: 10,
        edgeInset: 0,
        activeZoneWidthShare: 0,
        activeZoneHeightScale: 1,
        zoneSegmentGap: 2,
        cornerRadius: 5,
        inactiveZoneOpacity: 0.55,
        borderEnabled: true,
        borderColor: .white,
        borderOpacity: 0.12,
        borderWidth: 1,
        glowEnabled: false,
        glowIntensity: 0.45,
        markerEnabled: true,
        markerShowsValue: true,
        markerSizeScale: 1,
        thresholdMarkerEnabled: true,
        thresholdMarkerSizeScale: 1,
        markerText: IntervalHUDBarTextStyle(fontName: FontLibraryManager.currentDefaultFamily, fontSize: 12, fontWeight: .semibold)
    )
}

extension ZoneEdgeBarStyle {
    /// Decodes older project files and templates that predate the marker size
    /// controls. Implemented in an extension so the memberwise initializer
    /// stays available.
    init(from decoder: Decoder) throws {
        let defaults = Self.default
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metric = try container.decodeIfPresent(ZoneEdgeBarMetric.self, forKey: .metric) ?? defaults.metric
        placement = try container.decodeIfPresent(ZoneEdgeBarPlacement.self, forKey: .placement) ?? defaults.placement
        edge = try container.decodeIfPresent(ZoneEdgeBarEdge.self, forKey: .edge) ?? defaults.edge
        orientation = try container.decodeIfPresent(ZoneEdgeBarOrientation.self, forKey: .orientation) ?? defaults.orientation
        length = try container.decodeIfPresent(Double.self, forKey: .length) ?? defaults.length
        thickness = try container.decodeIfPresent(Double.self, forKey: .thickness) ?? defaults.thickness
        edgeInset = try container.decodeIfPresent(Double.self, forKey: .edgeInset) ?? defaults.edgeInset
        activeZoneWidthShare = try container.decodeIfPresent(Double.self, forKey: .activeZoneWidthShare) ?? defaults.activeZoneWidthShare
        activeZoneHeightScale = try container.decodeIfPresent(Double.self, forKey: .activeZoneHeightScale) ?? defaults.activeZoneHeightScale
        zoneSegmentGap = try container.decodeIfPresent(Double.self, forKey: .zoneSegmentGap) ?? defaults.zoneSegmentGap
        cornerRadius = try container.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? defaults.cornerRadius
        inactiveZoneOpacity = try container.decodeIfPresent(Double.self, forKey: .inactiveZoneOpacity) ?? defaults.inactiveZoneOpacity
        borderEnabled = try container.decodeIfPresent(Bool.self, forKey: .borderEnabled) ?? defaults.borderEnabled
        borderColor = try container.decodeIfPresent(OverlayColor.self, forKey: .borderColor) ?? defaults.borderColor
        borderOpacity = try container.decodeIfPresent(Double.self, forKey: .borderOpacity) ?? defaults.borderOpacity
        borderWidth = try container.decodeIfPresent(Double.self, forKey: .borderWidth) ?? defaults.borderWidth
        glowEnabled = try container.decodeIfPresent(Bool.self, forKey: .glowEnabled) ?? defaults.glowEnabled
        glowIntensity = try container.decodeIfPresent(Double.self, forKey: .glowIntensity) ?? defaults.glowIntensity
        markerEnabled = try container.decodeIfPresent(Bool.self, forKey: .markerEnabled) ?? defaults.markerEnabled
        markerShowsValue = try container.decodeIfPresent(Bool.self, forKey: .markerShowsValue) ?? defaults.markerShowsValue
        markerSizeScale = try container.decodeIfPresent(Double.self, forKey: .markerSizeScale) ?? defaults.markerSizeScale
        thresholdMarkerEnabled = try container.decodeIfPresent(Bool.self, forKey: .thresholdMarkerEnabled) ?? defaults.thresholdMarkerEnabled
        thresholdMarkerSizeScale = try container.decodeIfPresent(Double.self, forKey: .thresholdMarkerSizeScale) ?? defaults.thresholdMarkerSizeScale
        markerText = try container.decodeIfPresent(IntervalHUDBarTextStyle.self, forKey: .markerText) ?? defaults.markerText
    }
}

struct ZoneEdgeBarRenderLayout {
    var style: ZoneEdgeBarStyle
    var rect: CGRect
    var barRect: CGRect
    var orientation: ZoneEdgeBarOrientation
    var markerSide: ZoneEdgeBarMarkerSide
    var zoneSegments: [IntervalHUDBarZoneSegment]
    var activeZoneIndex: Int?
    var zoneMarker: IntervalHUDBarZoneMarker?
    var thresholdZoneMarker: IntervalHUDBarZoneMarker?
    var markerText: IntervalHUDBarTextStyle
}

enum ZoneEdgeBarMarkerSide: Equatable {
    case above
    case below
    case leading
    case trailing
}
