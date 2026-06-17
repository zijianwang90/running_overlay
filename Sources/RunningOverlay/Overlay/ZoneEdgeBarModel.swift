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
    var thresholdMarkerEnabled: Bool
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
        thresholdMarkerEnabled: true,
        markerText: IntervalHUDBarTextStyle(fontName: FontLibraryManager.currentDefaultFamily, fontSize: 12, fontWeight: .semibold)
    )
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
