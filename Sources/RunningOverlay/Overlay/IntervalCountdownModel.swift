import Foundation

enum IntervalCountdownColorMode: String, CaseIterable, Identifiable, Codable {
    case followGroupColor
    case customColor

    var id: String { rawValue }

    var label: String {
        switch self {
        case .followGroupColor: "Follow Group"
        case .customColor: "Custom"
        }
    }
}

enum IntervalCountdownRingDirection: String, CaseIterable, Identifiable, Codable {
    case clockwise
    case counterclockwise

    var id: String { rawValue }

    var label: String {
        switch self {
        case .clockwise: "Clockwise"
        case .counterclockwise: "Counterclockwise"
        }
    }

    var progressDescription: String {
        switch self {
        case .clockwise: "Full to Empty"
        case .counterclockwise: "Empty to Full"
        }
    }
}

enum IntervalCountdownCenterMetric: String, CaseIterable, Identifiable, Codable {
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

enum IntervalCountdownValueDirection: String, CaseIterable, Identifiable, Codable {
    case remaining
    case elapsed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .remaining: "End to 0"
        case .elapsed: "0 to End"
        }
    }
}

enum IntervalCountdownTextRole: String, CaseIterable, Identifiable, Codable {
    case helper
    case phase
    case rep
    case countdown
    case caption

    var id: String { rawValue }

    var label: String {
        switch self {
        case .helper: "Helper"
        case .phase: "Phase"
        case .rep: "Rep"
        case .countdown: "Countdown"
        case .caption: "Caption"
        }
    }

    var isHideable: Bool {
        self != .countdown
    }
}

struct IntervalCountdownTextStyle: Equatable, Codable {
    var isVisible: Bool
    var fontName: String
    var fontSize: Double
    var fontWeight: OverlayFontWeight
    var colorMode: IntervalCountdownColorMode
    var customColor: OverlayColor

    static func defaultFor(role: IntervalCountdownTextRole) -> IntervalCountdownTextStyle {
        switch role {
        case .helper:
            IntervalCountdownTextStyle(
                isVisible: true,
                fontName: FontLibraryManager.currentDefaultFamily,
                fontSize: 14,
                fontWeight: .semibold,
                colorMode: .customColor,
                customColor: OverlayColor(red: 0.71, green: 0.75, blue: 0.78, alpha: 1)
            )
        case .phase:
            IntervalCountdownTextStyle(
                isVisible: true,
                fontName: FontLibraryManager.currentDefaultFamily,
                fontSize: 16,
                fontWeight: .bold,
                colorMode: .followGroupColor,
                customColor: .orange
            )
        case .rep:
            IntervalCountdownTextStyle(
                isVisible: true,
                fontName: FontLibraryManager.currentDefaultFamily,
                fontSize: 16,
                fontWeight: .bold,
                colorMode: .followGroupColor,
                customColor: .orange
            )
        case .countdown:
            IntervalCountdownTextStyle(
                isVisible: true,
                fontName: FontLibraryManager.currentDefaultFamily,
                fontSize: 74,
                fontWeight: .bold,
                colorMode: .customColor,
                customColor: .white
            )
        case .caption:
            IntervalCountdownTextStyle(
                isVisible: true,
                fontName: FontLibraryManager.currentDefaultFamily,
                fontSize: 13,
                fontWeight: .regular,
                colorMode: .customColor,
                customColor: OverlayColor(red: 0.49, green: 0.53, blue: 0.58, alpha: 1)
            )
        }
    }
}

struct IntervalCountdownStyle: Equatable, Codable {
    var size: Double
    /// `nil` preserves the original time-based center value for projects and
    /// templates saved before this control existed.
    var centerMetric: IntervalCountdownCenterMetric?
    /// `nil` preserves the original end-to-zero center value direction.
    var centerValueDirection: IntervalCountdownValueDirection?
    var ringWidth: Double
    var trackColor: OverlayColor
    var trackOpacity: Double
    var fillColorMode: IntervalCountdownColorMode
    var fillCustomColor: OverlayColor
    /// `nil` preserves the original clockwise remaining-time behavior for
    /// projects and templates saved before this control existed.
    var ringDirection: IntervalCountdownRingDirection?
    var roundedLineCap: Bool
    var ringGlowEnabled: Bool
    var ringGlowIntensity: Double
    var helperText: IntervalCountdownTextStyle
    var phaseText: IntervalCountdownTextStyle
    var repText: IntervalCountdownTextStyle
    var countdownText: IntervalCountdownTextStyle
    var captionText: IntervalCountdownTextStyle

    static let `default` = IntervalCountdownStyle(
        size: 344,
        centerMetric: .time,
        centerValueDirection: .remaining,
        ringWidth: 18,
        trackColor: OverlayColor(red: 0.16, green: 0.19, blue: 0.21, alpha: 1),
        trackOpacity: 1,
        fillColorMode: .followGroupColor,
        fillCustomColor: .orange,
        ringDirection: .clockwise,
        roundedLineCap: true,
        ringGlowEnabled: true,
        ringGlowIntensity: 0.45,
        helperText: .defaultFor(role: .helper),
        phaseText: .defaultFor(role: .phase),
        repText: .defaultFor(role: .rep),
        countdownText: .defaultFor(role: .countdown),
        captionText: .defaultFor(role: .caption)
    )

    var resolvedRingDirection: IntervalCountdownRingDirection {
        ringDirection ?? .clockwise
    }

    var resolvedCenterMetric: IntervalCountdownCenterMetric {
        centerMetric ?? .time
    }

    var resolvedCenterValueDirection: IntervalCountdownValueDirection {
        centerValueDirection ?? .remaining
    }

    mutating func setTextStyle(_ textStyle: IntervalCountdownTextStyle, for role: IntervalCountdownTextRole) {
        switch role {
        case .helper:
            helperText = textStyle
        case .phase:
            phaseText = textStyle
        case .rep:
            repText = textStyle
        case .countdown:
            countdownText = textStyle
            countdownText.isVisible = true
        case .caption:
            captionText = textStyle
        }
    }

    func textStyle(for role: IntervalCountdownTextRole) -> IntervalCountdownTextStyle {
        switch role {
        case .helper: helperText
        case .phase: phaseText
        case .rep: repText
        case .countdown: countdownText
        case .caption: captionText
        }
    }
}

struct IntervalCountdownRenderLayout: Equatable {
    struct TextItem: Identifiable, Equatable {
        var id: IntervalCountdownTextRole { role }
        var role: IntervalCountdownTextRole
        var text: String
        var style: IntervalCountdownTextStyle
        var color: OverlayColor
        var fontSize: Double
    }

    var style: IntervalCountdownStyle
    var rect: CGRect
    var progress: Double
    var ringColor: OverlayColor
    var lapKind: LapKind
    var countdownText: String
    var phaseText: String
    var repText: String?
    var textItems: [TextItem]
    var ringWidth: Double
    var innerDiameter: Double
    var backgroundPaddingX: Double
    var backgroundPaddingY: Double
    var backgroundRadius: Double
    var borderWidth: Double
    var shadowRadius: Double
    var shadowOffsetX: Double
    var shadowOffsetY: Double
}
