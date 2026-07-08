import Foundation

enum IntervalWorkSummaryMetric: String, CaseIterable, Identifiable, Codable {
    case lapTime
    case lapPace
    case lapDistance
    case avgHeartRate
    case maxHeartRate
    case avgPower
    case avgCadence

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lapTime: "Lap Time"
        case .lapPace: "Lap Pace"
        case .lapDistance: "Lap Distance"
        case .avgHeartRate: "Avg Heart Rate"
        case .maxHeartRate: "Max Heart Rate"
        case .avgPower: "Avg Power"
        case .avgCadence: "Avg Cadence"
        }
    }

    var shortLabel: String {
        switch self {
        case .lapTime: "LAP TIME"
        case .lapPace: "PACE"
        case .lapDistance: "DIST"
        case .avgHeartRate: "HR"
        case .maxHeartRate: "MAX HR"
        case .avgPower: "POWER"
        case .avgCadence: "CAD"
        }
    }
}

enum IntervalWorkSummaryUnitSystem: String, CaseIterable, Identifiable, Codable {
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

enum IntervalWorkSummaryTextRole: String, CaseIterable, Identifiable, Codable {
    case componentLabel
    case primaryValue
    case primaryLabel
    case secondaryValue
    case secondaryLabel

    var id: String { rawValue }

    var label: String {
        switch self {
        case .componentLabel: "Summary Label"
        case .primaryValue: "Primary Value"
        case .primaryLabel: "Primary Label"
        case .secondaryValue: "Secondary Value"
        case .secondaryLabel: "Secondary Label"
        }
    }

    var isHideable: Bool {
        switch self {
        case .primaryValue, .secondaryValue: false
        default: true
        }
    }
}

struct IntervalWorkSummaryTextStyle: Equatable, Codable {
    var isVisible: Bool
    var fontName: String
    var fontSize: Double
    var fontWeight: OverlayFontWeight
    var colorMode: IntervalCountdownColorMode
    var customColor: OverlayColor

    static func defaultFor(role: IntervalWorkSummaryTextRole) -> IntervalWorkSummaryTextStyle {
        switch role {
        case .componentLabel:
            IntervalWorkSummaryTextStyle(
                isVisible: true,
                fontName: FontLibraryManager.currentDefaultFamily,
                fontSize: 18,
                fontWeight: .bold,
                colorMode: .followGroupColor,
                customColor: OverlayColor(red: 1, green: 0.36, blue: 0.18, alpha: 1)
            )
        case .primaryValue:
            IntervalWorkSummaryTextStyle(
                isVisible: true,
                fontName: FontLibraryManager.currentDefaultFamily,
                fontSize: 88,
                fontWeight: .bold,
                colorMode: .customColor,
                customColor: .white
            )
        case .primaryLabel:
            IntervalWorkSummaryTextStyle(
                isVisible: true,
                fontName: FontLibraryManager.currentDefaultFamily,
                fontSize: 20,
                fontWeight: .bold,
                colorMode: .followGroupColor,
                customColor: OverlayColor(red: 1, green: 0.36, blue: 0.18, alpha: 1)
            )
        case .secondaryValue:
            IntervalWorkSummaryTextStyle(
                isVisible: true,
                fontName: FontLibraryManager.currentDefaultFamily,
                fontSize: 32,
                fontWeight: .bold,
                colorMode: .customColor,
                customColor: .white
            )
        case .secondaryLabel:
            IntervalWorkSummaryTextStyle(
                isVisible: true,
                fontName: FontLibraryManager.currentDefaultFamily,
                fontSize: 14,
                fontWeight: .bold,
                colorMode: .followGroupColor,
                customColor: OverlayColor(red: 1, green: 0.36, blue: 0.18, alpha: 1)
            )
        }
    }
}

struct IntervalWorkSummarySlot: Identifiable, Equatable, Codable {
    var id = UUID()
    var metric: IntervalWorkSummaryMetric
    var isVisible: Bool
    var customLabel: String
    var labelVisible: Bool

    init(
        metric: IntervalWorkSummaryMetric,
        isVisible: Bool = true,
        customLabel: String = "",
        labelVisible: Bool = true
    ) {
        self.metric = metric
        self.isVisible = isVisible
        self.customLabel = customLabel
        self.labelVisible = labelVisible
    }
}

struct IntervalWorkSummaryStyle: Equatable, Codable {
    var width: Double
    var height: Double
    var displayDuration: Double
    var unitSystem: IntervalWorkSummaryUnitSystem
    var componentLabel: String
    var primaryMetric: IntervalWorkSummaryMetric
    var primaryLabelVisible: Bool
    var secondarySlots: [IntervalWorkSummarySlot]
    var dividerEnabled: Bool
    var dividerColor: OverlayColor
    var dividerOpacity: Double
    var dividerWidth: Double
    var accentColorMode: IntervalCountdownColorMode
    var accentCustomColor: OverlayColor
    var componentLabelText: IntervalWorkSummaryTextStyle
    var primaryValueText: IntervalWorkSummaryTextStyle
    var primaryLabelText: IntervalWorkSummaryTextStyle
    var secondaryValueText: IntervalWorkSummaryTextStyle
    var secondaryLabelText: IntervalWorkSummaryTextStyle

    static let `default` = IntervalWorkSummaryStyle(
        width: 560,
        height: 260,
        displayDuration: 6,
        unitSystem: .metric,
        componentLabel: "WORK SUMMARY",
        primaryMetric: .lapTime,
        primaryLabelVisible: true,
        secondarySlots: [
            IntervalWorkSummarySlot(metric: .lapPace),
            IntervalWorkSummarySlot(metric: .lapDistance),
            IntervalWorkSummarySlot(metric: .avgHeartRate),
        ],
        dividerEnabled: true,
        dividerColor: .white,
        dividerOpacity: 0.18,
        dividerWidth: 1,
        accentColorMode: .followGroupColor,
        accentCustomColor: OverlayColor(red: 1, green: 0.36, blue: 0.18, alpha: 1),
        componentLabelText: .defaultFor(role: .componentLabel),
        primaryValueText: .defaultFor(role: .primaryValue),
        primaryLabelText: .defaultFor(role: .primaryLabel),
        secondaryValueText: .defaultFor(role: .secondaryValue),
        secondaryLabelText: .defaultFor(role: .secondaryLabel)
    )

    func textStyle(for role: IntervalWorkSummaryTextRole) -> IntervalWorkSummaryTextStyle {
        switch role {
        case .componentLabel: componentLabelText
        case .primaryValue: primaryValueText
        case .primaryLabel: primaryLabelText
        case .secondaryValue: secondaryValueText
        case .secondaryLabel: secondaryLabelText
        }
    }

    mutating func setTextStyle(_ textStyle: IntervalWorkSummaryTextStyle, for role: IntervalWorkSummaryTextRole) {
        var style = textStyle
        if !role.isHideable {
            style.isVisible = true
        }
        switch role {
        case .componentLabel:
            componentLabelText = style
        case .primaryValue:
            primaryValueText = style
        case .primaryLabel:
            primaryLabelText = style
        case .secondaryValue:
            secondaryValueText = style
        case .secondaryLabel:
            secondaryLabelText = style
        }
    }

    var normalizedSecondarySlots: [IntervalWorkSummarySlot] {
        var slots = Array(secondarySlots.prefix(3))
        while slots.count < 3 {
            let fallback: IntervalWorkSummaryMetric = slots.count == 0 ? .lapPace : (slots.count == 1 ? .lapDistance : .avgHeartRate)
            slots.append(IntervalWorkSummarySlot(metric: fallback, isVisible: false))
        }
        return slots
    }
}

struct IntervalWorkSummaryMetricItem: Equatable {
    var metric: IntervalWorkSummaryMetric
    var value: String
    var unit: String
    var label: String
    var labelVisible: Bool
}

struct IntervalWorkSummaryRenderLayout {
    struct TextItem: Equatable {
        var role: IntervalWorkSummaryTextRole
        var style: IntervalWorkSummaryTextStyle
        var color: OverlayColor
        var fontSize: Double
    }

    var style: IntervalWorkSummaryStyle
    var rect: CGRect
    var isVisible: Bool
    var completedLap: LapRecord?
    var groupColor: OverlayColor
    var accentColor: OverlayColor
    var componentLabel: String
    var primary: IntervalWorkSummaryMetricItem
    var secondaryItems: [IntervalWorkSummaryMetricItem]
    var textItems: [IntervalWorkSummaryTextRole: TextItem]
    var backgroundPaddingX: Double
    var backgroundPaddingY: Double
    var backgroundRadius: Double
    var borderWidth: Double
    var shadowRadius: Double
    var shadowOffsetX: Double
    var shadowOffsetY: Double
}
