import CoreGraphics
import Foundation

// MARK: - Metrics

/// Metrics that can be bound to a Running Gauge data region. Maps to
/// `OverlayElementType` so the existing `OverlayValueFormatter` can resolve
/// label/value/unit components for each region.
enum OverlayGaugeMetric: String, CaseIterable, Identifiable, Codable {
    case distance
    case pace
    case elapsedTime
    case realTime
    case heartRate
    case power
    case cadence
    case elevation
    case calories

    var id: String { rawValue }

    var label: String {
        switch self {
        case .distance: "Distance"
        case .pace: "Pace"
        case .elapsedTime: "Elapsed Time"
        case .realTime: "Real Time"
        case .heartRate: "Heart Rate"
        case .power: "Power"
        case .cadence: "Cadence"
        case .elevation: "Elevation"
        case .calories: "Calories"
        }
    }

    var compactLabel: String {
        switch self {
        case .distance: "DISTANCE"
        case .pace: "PACE"
        case .elapsedTime: "TIME"
        case .realTime: "CLOCK"
        case .heartRate: "HR"
        case .power: "POWER"
        case .cadence: "CADENCE"
        case .elevation: "ELEV"
        case .calories: "KCAL"
        }
    }

    /// Bridges to the existing OverlayElementType so renderers can reuse the
    /// shared `OverlayValueFormatter.components(for:activity:elapsedTime:)`.
    var elementType: OverlayElementType {
        switch self {
        case .distance: .distance
        case .pace: .pace
        case .elapsedTime: .elapsedTime
        case .realTime: .realTime
        case .heartRate: .heartRate
        case .power: .power
        case .cadence: .cadence
        case .elevation: .elevation
        case .calories: .calories
        }
    }

    /// Default accent color for this metric kind. Used as a starting point
    /// when a region's `valueColor` is left at its default.
    var defaultAccent: OverlayColor {
        switch self {
        case .distance: .green
        case .pace: .blue
        case .elapsedTime: .yellow
        case .realTime: .white
        case .heartRate: .red
        case .power: .purple
        case .cadence: .cyan
        case .elevation: .orange
        case .calories: .pink
        }
    }
}

// MARK: - Region & layout enums

/// A logical region inside the gauge dial. The set of regions actually
/// rendered is determined by `RunningGaugeLayoutPreset.regions`.
enum RunningGaugeRegion: String, CaseIterable, Identifiable, Codable {
    case top
    case middle
    case bottom
    case middleLeft
    case middleCenter
    case middleRight
    case topLeft
    case topRight
    case bottomLeft
    case bottomCenter
    case bottomRight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .top: "Top"
        case .middle: "Middle"
        case .bottom: "Bottom"
        case .middleLeft: "Middle Left"
        case .middleCenter: "Middle Center"
        case .middleRight: "Middle Right"
        case .topLeft: "Top Left"
        case .topRight: "Top Right"
        case .bottomLeft: "Bottom Left"
        case .bottomCenter: "Bottom Center"
        case .bottomRight: "Bottom Right"
        }
    }
}

/// Built-in data layouts. Each preset enumerates the visible regions in
/// rendering order plus the dividers used to split them apart.
enum RunningGaugeLayoutPreset: String, CaseIterable, Identifiable, Codable {
    case topBottom
    case topMiddleBottom
    case threeZones
    case topTwoMiddleBottom
    case topThreeMiddleBottom
    case fourZones
    case fiveZones

    var id: String { rawValue }

    var label: String {
        switch self {
        case .topBottom: "Top / Bottom"
        case .topMiddleBottom: "Top / Middle / Bottom"
        case .threeZones: "Three Zones"
        case .topTwoMiddleBottom: "Top + Two Middle + Bottom"
        case .topThreeMiddleBottom: "Top + Three Middle + Bottom"
        case .fourZones: "Four Zones"
        case .fiveZones: "Five Zones"
        }
    }

    var compactLabel: String {
        switch self {
        case .topBottom: "Top/Bottom"
        case .topMiddleBottom: "T/M/B"
        case .threeZones: "Three Zones"
        case .topTwoMiddleBottom: "T+2M+B"
        case .topThreeMiddleBottom: "T+3M+B"
        case .fourZones: "Four Zones"
        case .fiveZones: "Five Zones"
        }
    }

    var regions: [RunningGaugeRegion] {
        switch self {
        case .topBottom: [.top, .bottom]
        case .topMiddleBottom: [.top, .middle, .bottom]
        case .threeZones: [.top, .bottomLeft, .bottomRight]
        case .topTwoMiddleBottom: [.top, .middleLeft, .middleRight, .bottom]
        case .topThreeMiddleBottom: [.top, .middleLeft, .middleCenter, .middleRight, .bottom]
        case .fourZones: [.topLeft, .topRight, .bottomLeft, .bottomRight]
        case .fiveZones: [.top, .middleLeft, .middleRight, .bottomLeft, .bottomRight]
        }
    }
}

enum RunningGaugeProgressMode: String, CaseIterable, Identifiable, Codable {
    case none
    case distanceTarget
    case elapsedTimeTarget
    case heartRateZone
    case powerZone
    case paceIntensity
    case customPercentage

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "None"
        case .distanceTarget: "Distance Progress"
        case .elapsedTimeTarget: "Time Progress"
        case .heartRateZone: "HR Zone"
        case .powerZone: "Power Zone"
        case .paceIntensity: "Pace Intensity"
        case .customPercentage: "Custom %"
        }
    }
}

// MARK: - Per-region config

struct RunningGaugeRegionConfig: Identifiable, Equatable, Codable {
    var region: RunningGaugeRegion
    var metric: OverlayGaugeMetric
    var customLabel: String
    var showLabel: Bool
    var showUnit: Bool
    var showIcon: Bool
    var valueFontScale: Double
    var labelFontScale: Double
    var unitFontScale: Double
    var valueWeight: OverlayFontWeight
    var labelWeight: OverlayFontWeight
    var valueColor: OverlayColor?
    var labelColor: OverlayColor?

    var id: String { region.rawValue }

    init(
        region: RunningGaugeRegion,
        metric: OverlayGaugeMetric,
        customLabel: String = "",
        showLabel: Bool = true,
        showUnit: Bool = true,
        showIcon: Bool = false,
        valueFontScale: Double = 1.0,
        labelFontScale: Double = 0.32,
        unitFontScale: Double = 0.42,
        valueWeight: OverlayFontWeight = .bold,
        labelWeight: OverlayFontWeight = .medium,
        valueColor: OverlayColor? = nil,
        labelColor: OverlayColor? = nil
    ) {
        self.region = region
        self.metric = metric
        self.customLabel = customLabel
        self.showLabel = showLabel
        self.showUnit = showUnit
        self.showIcon = showIcon
        self.valueFontScale = valueFontScale
        self.labelFontScale = labelFontScale
        self.unitFontScale = unitFontScale
        self.valueWeight = valueWeight
        self.labelWeight = labelWeight
        self.valueColor = valueColor
        self.labelColor = labelColor
    }
}

// MARK: - RunningGaugeStyle

/// Encapsulates everything needed to render a Running Gauge. Lives as a
/// sub-struct of `OverlayStyle.gauge` so the rest of the overlay system stays
/// type-agnostic.
struct RunningGaugeStyle: Equatable, Codable {
    var stylePreset: OverlayGaugePreset
    var layoutPreset: RunningGaugeLayoutPreset
    var regions: [RunningGaugeRegionConfig]

    // Dial
    var dialBackgroundColor: OverlayColor
    var dialBackgroundOpacity: Double
    var glassEffectEnabled: Bool

    // Outer ring
    var outerRingEnabled: Bool
    var outerRingColor: OverlayColor
    var outerRingOpacity: Double
    var outerRingWidthScale: Double

    // Tick marks
    var tickMarksEnabled: Bool
    var tickColor: OverlayColor
    var tickOpacity: Double
    var majorTickOpacity: Double
    var tickCount: Int
    var majorTickEvery: Int

    // Progress ring
    var progressRingEnabled: Bool
    var progressMode: RunningGaugeProgressMode
    var progressColor: OverlayColor
    var progressTrackColor: OverlayColor
    var progressTrackOpacity: Double
    var progressRingWidthScale: Double
    var progressRoundedCaps: Bool

    // Dividers
    var dividerEnabled: Bool
    var dividerColor: OverlayColor
    var dividerOpacity: Double
    var dividerWidth: Double

    // Typography
    var fontName: String
    var monospacedDigits: Bool
    var primaryFontWeight: OverlayFontWeight
    var secondaryFontWeight: OverlayFontWeight

    // Color
    var primaryTextColor: OverlayColor
    var secondaryTextColor: OverlayColor
    var accentColor: OverlayColor

    // Effects
    var shadowEnabled: Bool
    var shadowOpacity: Double
    var shadowRadius: Double
    var glowEnabled: Bool
    var glowColor: OverlayColor
    var glowOpacity: Double
    var glowRadius: Double

    static let `default` = RunningGaugeStyle.preset(.roadRun)

    static func preset(_ preset: OverlayGaugePreset) -> RunningGaugeStyle {
        switch preset {
        case .minimalSport: return minimalSport
        case .highContrast: return highContrastSport
        case .roadRun: return roadRun
        case .trailAdventure: return trailAdventure
        case .techFuture: return futureTech
        case .retroDigital: return retroDigital
        case .premiumGlass: return premiumGlass
        }
    }

    /// Returns the recommended region defaults for the given layout. Used when
    /// the user picks a different layout from the inspector and we need to
    /// regenerate sensible per-region metric assignments.
    static func defaultRegions(for layout: RunningGaugeLayoutPreset) -> [RunningGaugeRegionConfig] {
        switch layout {
        case .topBottom:
            return [
                RunningGaugeRegionConfig(region: .top, metric: .distance, valueFontScale: 1.0),
                RunningGaugeRegionConfig(region: .bottom, metric: .elapsedTime, valueFontScale: 0.74)
            ]
        case .topMiddleBottom:
            return [
                RunningGaugeRegionConfig(region: .top, metric: .elapsedTime, valueFontScale: 0.78),
                RunningGaugeRegionConfig(region: .middle, metric: .distance, valueFontScale: 1.0),
                RunningGaugeRegionConfig(region: .bottom, metric: .heartRate, valueFontScale: 0.70)
            ]
        case .threeZones:
            return [
                RunningGaugeRegionConfig(region: .top, metric: .distance, valueFontScale: 1.0),
                RunningGaugeRegionConfig(region: .bottomLeft, metric: .elapsedTime, valueFontScale: 0.66),
                RunningGaugeRegionConfig(region: .bottomRight, metric: .pace, valueFontScale: 0.66)
            ]
        case .topTwoMiddleBottom:
            return [
                RunningGaugeRegionConfig(region: .top, metric: .distance, valueFontScale: 1.0),
                RunningGaugeRegionConfig(region: .middleLeft, metric: .pace, valueFontScale: 0.62),
                RunningGaugeRegionConfig(region: .middleRight, metric: .elapsedTime, valueFontScale: 0.62),
                RunningGaugeRegionConfig(region: .bottom, metric: .heartRate, valueFontScale: 0.66)
            ]
        case .topThreeMiddleBottom:
            return [
                RunningGaugeRegionConfig(region: .top, metric: .distance, valueFontScale: 1.0),
                RunningGaugeRegionConfig(region: .middleLeft, metric: .pace, valueFontScale: 0.50),
                RunningGaugeRegionConfig(region: .middleCenter, metric: .power, valueFontScale: 0.50),
                RunningGaugeRegionConfig(region: .middleRight, metric: .cadence, valueFontScale: 0.50),
                RunningGaugeRegionConfig(region: .bottom, metric: .heartRate, valueFontScale: 0.62)
            ]
        case .fourZones:
            return [
                RunningGaugeRegionConfig(region: .topLeft, metric: .distance, valueFontScale: 0.78),
                RunningGaugeRegionConfig(region: .topRight, metric: .elapsedTime, valueFontScale: 0.78),
                RunningGaugeRegionConfig(region: .bottomLeft, metric: .pace, valueFontScale: 0.78),
                RunningGaugeRegionConfig(region: .bottomRight, metric: .heartRate, valueFontScale: 0.78)
            ]
        case .fiveZones:
            return [
                RunningGaugeRegionConfig(region: .top, metric: .distance, valueFontScale: 1.0),
                RunningGaugeRegionConfig(region: .middleLeft, metric: .pace, valueFontScale: 0.58),
                RunningGaugeRegionConfig(region: .middleRight, metric: .elapsedTime, valueFontScale: 0.58),
                RunningGaugeRegionConfig(region: .bottomLeft, metric: .heartRate, valueFontScale: 0.58),
                RunningGaugeRegionConfig(region: .bottomRight, metric: .power, valueFontScale: 0.58)
            ]
        }
    }
}

// MARK: - Built-in style presets

extension RunningGaugeStyle {
    static var minimalSport: RunningGaugeStyle {
        RunningGaugeStyle(
            stylePreset: .minimalSport,
            layoutPreset: .topTwoMiddleBottom,
            regions: defaultRegions(for: .topTwoMiddleBottom),
            dialBackgroundColor: .black,
            dialBackgroundOpacity: 0.62,
            glassEffectEnabled: false,
            outerRingEnabled: true,
            outerRingColor: .white,
            outerRingOpacity: 0.45,
            outerRingWidthScale: 0.020,
            tickMarksEnabled: true,
            tickColor: .white,
            tickOpacity: 0.35,
            majorTickOpacity: 0.85,
            tickCount: 60,
            majorTickEvery: 5,
            progressRingEnabled: false,
            progressMode: .distanceTarget,
            progressColor: .white,
            progressTrackColor: .white,
            progressTrackOpacity: 0.18,
            progressRingWidthScale: 0.022,
            progressRoundedCaps: true,
            dividerEnabled: true,
            dividerColor: .white,
            dividerOpacity: 0.22,
            dividerWidth: 1,
            fontName: "SF Pro",
            monospacedDigits: true,
            primaryFontWeight: .bold,
            secondaryFontWeight: .medium,
            primaryTextColor: .white,
            secondaryTextColor: .white,
            accentColor: .white,
            shadowEnabled: true,
            shadowOpacity: 0.35,
            shadowRadius: 10,
            glowEnabled: false,
            glowColor: .white,
            glowOpacity: 0.0,
            glowRadius: 0
        )
    }

    static var highContrastSport: RunningGaugeStyle {
        RunningGaugeStyle(
            stylePreset: .highContrast,
            layoutPreset: .threeZones,
            regions: defaultRegions(for: .threeZones),
            dialBackgroundColor: .black,
            dialBackgroundOpacity: 0.78,
            glassEffectEnabled: false,
            outerRingEnabled: true,
            outerRingColor: .white,
            outerRingOpacity: 0.85,
            outerRingWidthScale: 0.024,
            tickMarksEnabled: true,
            tickColor: .white,
            tickOpacity: 0.60,
            majorTickOpacity: 1.0,
            tickCount: 60,
            majorTickEvery: 5,
            progressRingEnabled: true,
            progressMode: .distanceTarget,
            progressColor: .white,
            progressTrackColor: .white,
            progressTrackOpacity: 0.20,
            progressRingWidthScale: 0.026,
            progressRoundedCaps: true,
            dividerEnabled: true,
            dividerColor: .white,
            dividerOpacity: 0.30,
            dividerWidth: 1,
            fontName: "SF Pro",
            monospacedDigits: true,
            primaryFontWeight: .bold,
            secondaryFontWeight: .semibold,
            primaryTextColor: .white,
            secondaryTextColor: .white,
            accentColor: .yellow,
            shadowEnabled: true,
            shadowOpacity: 0.55,
            shadowRadius: 12,
            glowEnabled: false,
            glowColor: .white,
            glowOpacity: 0.0,
            glowRadius: 0
        )
    }

    static var roadRun: RunningGaugeStyle {
        RunningGaugeStyle(
            stylePreset: .roadRun,
            layoutPreset: .topTwoMiddleBottom,
            regions: defaultRegions(for: .topTwoMiddleBottom),
            dialBackgroundColor: .black,
            dialBackgroundOpacity: 0.70,
            glassEffectEnabled: false,
            outerRingEnabled: true,
            outerRingColor: .white,
            outerRingOpacity: 0.50,
            outerRingWidthScale: 0.022,
            tickMarksEnabled: true,
            tickColor: .white,
            tickOpacity: 0.42,
            majorTickOpacity: 0.95,
            tickCount: 60,
            majorTickEvery: 5,
            progressRingEnabled: true,
            progressMode: .distanceTarget,
            progressColor: .orange,
            progressTrackColor: .white,
            progressTrackOpacity: 0.22,
            progressRingWidthScale: 0.026,
            progressRoundedCaps: true,
            dividerEnabled: true,
            dividerColor: .white,
            dividerOpacity: 0.22,
            dividerWidth: 1,
            fontName: "SF Pro",
            monospacedDigits: true,
            primaryFontWeight: .bold,
            secondaryFontWeight: .medium,
            primaryTextColor: .white,
            secondaryTextColor: .white,
            accentColor: .orange,
            shadowEnabled: true,
            shadowOpacity: 0.45,
            shadowRadius: 12,
            glowEnabled: false,
            glowColor: .orange,
            glowOpacity: 0.0,
            glowRadius: 0
        )
    }

    static var trailAdventure: RunningGaugeStyle {
        RunningGaugeStyle(
            stylePreset: .trailAdventure,
            layoutPreset: .topThreeMiddleBottom,
            regions: defaultRegions(for: .topThreeMiddleBottom),
            dialBackgroundColor: OverlayColor(red: 0.06, green: 0.07, blue: 0.04, alpha: 1),
            dialBackgroundOpacity: 0.70,
            glassEffectEnabled: false,
            outerRingEnabled: true,
            outerRingColor: .green,
            outerRingOpacity: 0.55,
            outerRingWidthScale: 0.022,
            tickMarksEnabled: true,
            tickColor: .green,
            tickOpacity: 0.32,
            majorTickOpacity: 0.85,
            tickCount: 60,
            majorTickEvery: 5,
            progressRingEnabled: true,
            progressMode: .distanceTarget,
            progressColor: .green,
            progressTrackColor: .white,
            progressTrackOpacity: 0.18,
            progressRingWidthScale: 0.024,
            progressRoundedCaps: true,
            dividerEnabled: true,
            dividerColor: .white,
            dividerOpacity: 0.20,
            dividerWidth: 1,
            fontName: "SF Pro",
            monospacedDigits: true,
            primaryFontWeight: .bold,
            secondaryFontWeight: .medium,
            primaryTextColor: .white,
            secondaryTextColor: .white,
            accentColor: .green,
            shadowEnabled: true,
            shadowOpacity: 0.40,
            shadowRadius: 14,
            glowEnabled: false,
            glowColor: .green,
            glowOpacity: 0.0,
            glowRadius: 0
        )
    }

    static var futureTech: RunningGaugeStyle {
        RunningGaugeStyle(
            stylePreset: .techFuture,
            layoutPreset: .topTwoMiddleBottom,
            regions: {
                var regs = defaultRegions(for: .topTwoMiddleBottom)
                if let i = regs.firstIndex(where: { $0.region == .bottom }) {
                    regs[i].metric = .power
                }
                return regs
            }(),
            dialBackgroundColor: OverlayColor(red: 0.02, green: 0.04, blue: 0.07, alpha: 1),
            dialBackgroundOpacity: 0.66,
            glassEffectEnabled: false,
            outerRingEnabled: true,
            outerRingColor: .cyan,
            outerRingOpacity: 0.55,
            outerRingWidthScale: 0.022,
            tickMarksEnabled: true,
            tickColor: .cyan,
            tickOpacity: 0.45,
            majorTickOpacity: 0.95,
            tickCount: 60,
            majorTickEvery: 5,
            progressRingEnabled: true,
            progressMode: .distanceTarget,
            progressColor: .blue,
            progressTrackColor: .cyan,
            progressTrackOpacity: 0.20,
            progressRingWidthScale: 0.024,
            progressRoundedCaps: true,
            dividerEnabled: true,
            dividerColor: .cyan,
            dividerOpacity: 0.26,
            dividerWidth: 1,
            fontName: "SF Pro",
            monospacedDigits: true,
            primaryFontWeight: .bold,
            secondaryFontWeight: .medium,
            primaryTextColor: .white,
            secondaryTextColor: .cyan,
            accentColor: .blue,
            shadowEnabled: true,
            shadowOpacity: 0.40,
            shadowRadius: 14,
            glowEnabled: true,
            glowColor: .blue,
            glowOpacity: 0.45,
            glowRadius: 10
        )
    }

    static var retroDigital: RunningGaugeStyle {
        RunningGaugeStyle(
            stylePreset: .retroDigital,
            layoutPreset: .topMiddleBottom,
            regions: {
                var regs = defaultRegions(for: .topMiddleBottom)
                if let i = regs.firstIndex(where: { $0.region == .top }) {
                    regs[i].metric = .distance
                    regs[i].valueFontScale = 1.0
                }
                if let i = regs.firstIndex(where: { $0.region == .middle }) {
                    regs[i].metric = .elapsedTime
                    regs[i].valueFontScale = 0.74
                }
                if let i = regs.firstIndex(where: { $0.region == .bottom }) {
                    regs[i].metric = .heartRate
                    regs[i].valueFontScale = 0.62
                }
                return regs
            }(),
            dialBackgroundColor: OverlayColor(red: 0.05, green: 0.045, blue: 0.035, alpha: 1),
            dialBackgroundOpacity: 0.78,
            glassEffectEnabled: false,
            outerRingEnabled: true,
            outerRingColor: .white,
            outerRingOpacity: 0.40,
            outerRingWidthScale: 0.020,
            tickMarksEnabled: true,
            tickColor: .green,
            tickOpacity: 0.42,
            majorTickOpacity: 0.85,
            tickCount: 72,
            majorTickEvery: 6,
            progressRingEnabled: false,
            progressMode: .none,
            progressColor: .green,
            progressTrackColor: .white,
            progressTrackOpacity: 0.18,
            progressRingWidthScale: 0.022,
            progressRoundedCaps: false,
            dividerEnabled: true,
            dividerColor: .green,
            dividerOpacity: 0.28,
            dividerWidth: 1,
            fontName: BundledFontName.digitalWatch,
            monospacedDigits: true,
            primaryFontWeight: .medium,
            secondaryFontWeight: .medium,
            primaryTextColor: .green,
            secondaryTextColor: .green,
            accentColor: .green,
            shadowEnabled: true,
            shadowOpacity: 0.40,
            shadowRadius: 12,
            glowEnabled: true,
            glowColor: .green,
            glowOpacity: 0.20,
            glowRadius: 6
        )
    }

    static var premiumGlass: RunningGaugeStyle {
        RunningGaugeStyle(
            stylePreset: .premiumGlass,
            layoutPreset: .topTwoMiddleBottom,
            regions: defaultRegions(for: .topTwoMiddleBottom),
            dialBackgroundColor: .black,
            dialBackgroundOpacity: 0.42,
            glassEffectEnabled: true,
            outerRingEnabled: true,
            outerRingColor: .white,
            outerRingOpacity: 0.32,
            outerRingWidthScale: 0.018,
            tickMarksEnabled: true,
            tickColor: .white,
            tickOpacity: 0.25,
            majorTickOpacity: 0.70,
            tickCount: 60,
            majorTickEvery: 5,
            progressRingEnabled: true,
            progressMode: .distanceTarget,
            progressColor: .blue,
            progressTrackColor: .white,
            progressTrackOpacity: 0.18,
            progressRingWidthScale: 0.020,
            progressRoundedCaps: true,
            dividerEnabled: true,
            dividerColor: .white,
            dividerOpacity: 0.18,
            dividerWidth: 1,
            fontName: "SF Pro",
            monospacedDigits: true,
            primaryFontWeight: .bold,
            secondaryFontWeight: .medium,
            primaryTextColor: .white,
            secondaryTextColor: .white,
            accentColor: .blue,
            shadowEnabled: true,
            shadowOpacity: 0.45,
            shadowRadius: 16,
            glowEnabled: false,
            glowColor: .white,
            glowOpacity: 0.0,
            glowRadius: 0
        )
    }
}

// MARK: - Region frame computation

struct RunningGaugeRegionFrame: Equatable {
    var region: RunningGaugeRegion
    var rect: CGRect
}

enum RunningGaugeLayoutEngine {
    /// Returns frames for every region listed in `layout.regions`. Frames are
    /// in the gauge-local coordinate space (origin at top-left of the bounding
    /// square, width/height equal to the gauge diameter). Renderers translate
    /// these to canvas coordinates as needed.
    static func regionFrames(
        for layout: RunningGaugeLayoutPreset,
        in size: CGSize
    ) -> [RunningGaugeRegionFrame] {
        let w = size.width
        let h = size.height
        switch layout {
        case .topBottom:
            return [
                .init(region: .top, rect: CGRect(x: w * 0.18, y: h * 0.22, width: w * 0.64, height: h * 0.30)),
                .init(region: .bottom, rect: CGRect(x: w * 0.22, y: h * 0.58, width: w * 0.56, height: h * 0.24))
            ]
        case .topMiddleBottom:
            return [
                .init(region: .top, rect: CGRect(x: w * 0.20, y: h * 0.16, width: w * 0.60, height: h * 0.20)),
                .init(region: .middle, rect: CGRect(x: w * 0.16, y: h * 0.40, width: w * 0.68, height: h * 0.26)),
                .init(region: .bottom, rect: CGRect(x: w * 0.24, y: h * 0.70, width: w * 0.52, height: h * 0.18))
            ]
        case .threeZones:
            return [
                .init(region: .top, rect: CGRect(x: w * 0.16, y: h * 0.18, width: w * 0.68, height: h * 0.32)),
                .init(region: .bottomLeft, rect: CGRect(x: w * 0.14, y: h * 0.58, width: w * 0.34, height: h * 0.24)),
                .init(region: .bottomRight, rect: CGRect(x: w * 0.52, y: h * 0.58, width: w * 0.34, height: h * 0.24))
            ]
        case .topTwoMiddleBottom:
            return [
                .init(region: .top, rect: CGRect(x: w * 0.18, y: h * 0.16, width: w * 0.64, height: h * 0.28)),
                .init(region: .middleLeft, rect: CGRect(x: w * 0.12, y: h * 0.46, width: w * 0.36, height: h * 0.22)),
                .init(region: .middleRight, rect: CGRect(x: w * 0.52, y: h * 0.46, width: w * 0.36, height: h * 0.22)),
                .init(region: .bottom, rect: CGRect(x: w * 0.25, y: h * 0.71, width: w * 0.50, height: h * 0.18))
            ]
        case .topThreeMiddleBottom:
            return [
                .init(region: .top, rect: CGRect(x: w * 0.18, y: h * 0.14, width: w * 0.64, height: h * 0.26)),
                .init(region: .middleLeft, rect: CGRect(x: w * 0.10, y: h * 0.45, width: w * 0.25, height: h * 0.22)),
                .init(region: .middleCenter, rect: CGRect(x: w * 0.375, y: h * 0.45, width: w * 0.25, height: h * 0.22)),
                .init(region: .middleRight, rect: CGRect(x: w * 0.65, y: h * 0.45, width: w * 0.25, height: h * 0.22)),
                .init(region: .bottom, rect: CGRect(x: w * 0.25, y: h * 0.71, width: w * 0.50, height: h * 0.18))
            ]
        case .fourZones:
            return [
                .init(region: .topLeft, rect: CGRect(x: w * 0.14, y: h * 0.22, width: w * 0.34, height: h * 0.26)),
                .init(region: .topRight, rect: CGRect(x: w * 0.52, y: h * 0.22, width: w * 0.34, height: h * 0.26)),
                .init(region: .bottomLeft, rect: CGRect(x: w * 0.14, y: h * 0.54, width: w * 0.34, height: h * 0.26)),
                .init(region: .bottomRight, rect: CGRect(x: w * 0.52, y: h * 0.54, width: w * 0.34, height: h * 0.26))
            ]
        case .fiveZones:
            return [
                .init(region: .top, rect: CGRect(x: w * 0.18, y: h * 0.13, width: w * 0.64, height: h * 0.22)),
                .init(region: .middleLeft, rect: CGRect(x: w * 0.12, y: h * 0.40, width: w * 0.34, height: h * 0.20)),
                .init(region: .middleRight, rect: CGRect(x: w * 0.54, y: h * 0.40, width: w * 0.34, height: h * 0.20)),
                .init(region: .bottomLeft, rect: CGRect(x: w * 0.12, y: h * 0.66, width: w * 0.34, height: h * 0.20)),
                .init(region: .bottomRight, rect: CGRect(x: w * 0.54, y: h * 0.66, width: w * 0.34, height: h * 0.20))
            ]
        }
    }

    /// Divider line segments in gauge-local normalised coordinates (0...1 on
    /// both axes). Renderers map these to the safe inset rect.
    static func dividerSegments(for layout: RunningGaugeLayoutPreset) -> [(CGPoint, CGPoint)] {
        switch layout {
        case .topBottom:
            return [(CGPoint(x: 0.0, y: 0.5), CGPoint(x: 1.0, y: 0.5))]
        case .topMiddleBottom:
            return [
                (CGPoint(x: 0.0, y: 0.36), CGPoint(x: 1.0, y: 0.36)),
                (CGPoint(x: 0.0, y: 0.68), CGPoint(x: 1.0, y: 0.68))
            ]
        case .threeZones:
            return [
                (CGPoint(x: 0.0, y: 0.50), CGPoint(x: 1.0, y: 0.50)),
                (CGPoint(x: 0.5, y: 0.50), CGPoint(x: 0.5, y: 1.0))
            ]
        case .topTwoMiddleBottom:
            return [
                (CGPoint(x: 0.0, y: 0.44), CGPoint(x: 1.0, y: 0.44)),
                (CGPoint(x: 0.5, y: 0.44), CGPoint(x: 0.5, y: 0.70)),
                (CGPoint(x: 0.0, y: 0.70), CGPoint(x: 1.0, y: 0.70))
            ]
        case .topThreeMiddleBottom:
            return [
                (CGPoint(x: 0.0, y: 0.42), CGPoint(x: 1.0, y: 0.42)),
                (CGPoint(x: 0.333, y: 0.42), CGPoint(x: 0.333, y: 0.70)),
                (CGPoint(x: 0.667, y: 0.42), CGPoint(x: 0.667, y: 0.70)),
                (CGPoint(x: 0.0, y: 0.70), CGPoint(x: 1.0, y: 0.70))
            ]
        case .fourZones:
            return [
                (CGPoint(x: 0.0, y: 0.50), CGPoint(x: 1.0, y: 0.50)),
                (CGPoint(x: 0.5, y: 0.10), CGPoint(x: 0.5, y: 0.90))
            ]
        case .fiveZones:
            return [
                (CGPoint(x: 0.0, y: 0.36), CGPoint(x: 1.0, y: 0.36)),
                (CGPoint(x: 0.5, y: 0.36), CGPoint(x: 0.5, y: 0.62)),
                (CGPoint(x: 0.0, y: 0.62), CGPoint(x: 1.0, y: 0.62)),
                (CGPoint(x: 0.5, y: 0.62), CGPoint(x: 0.5, y: 0.90))
            ]
        }
    }
}
