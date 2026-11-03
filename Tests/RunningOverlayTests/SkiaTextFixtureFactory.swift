#if canImport(CSkiaBridge)
import CoreGraphics
import Foundation
@testable import RunningOverlay

/// Deterministic 1080p fixtures for Skia text goldens.
///
/// Fonts are pinned to faces that ship with macOS (Menlo, Menlo-Bold,
/// Georgia) so measurements do not depend on the user's font library. All
/// data is synthetic; no network access or private FIT files are used.
enum SkiaTextFixtureFactory {
    static let canvasSize = CGSize(width: 1920, height: 1080)
    static let elapsedTime: TimeInterval = 30

    static func activity() -> ActivityTimeline {
        let start = Date(timeIntervalSince1970: 1_735_689_600)
        let records = stride(from: 0.0, through: 60, by: 1).map { t in
            ActivityRecord(
                elapsedTime: t,
                timestamp: start.addingTimeInterval(t),
                distanceMeters: t * 3.3,
                heartRate: 130 + Int(t / 3),
                paceSecondsPerKilometer: 300,
                elevationMeters: 20 + t / 10,
                cadence: 176,
                powerWatts: 250,
                calories: t / 4,
                latitude: 40.75 + 0.0006 * sin(t / 8),
                longitude: -73.99 + 0.0008 * cos(t / 8)
            )
        }
        return ActivityTimeline(
            startDate: start,
            duration: 60,
            distanceMeters: 200,
            records: records,
            laps: []
        )
    }

    static func style() -> OverlayStyle {
        var style = OverlayStyle.default
        style.fontName = "Menlo-Bold"
        style.fontSize = 42
        style.fontWeight = .semibold
        style.labelFontName = "Menlo"
        style.labelFontSize = 14
        style.labelFontWeight = .regular
        style.unitFontName = "Menlo"
        style.unitFontSize = 20
        style.unitFontWeight = .regular
        style.foregroundColor = .white
        style.valueColor = .white
        style.valueOpacity = 1
        style.labelColor = OverlayColor(red: 0.85, green: 0.90, blue: 1, alpha: 1)
        style.labelOpacity = 0.95
        style.unitColor = OverlayColor(red: 0.75, green: 0.85, blue: 1, alpha: 1)
        style.unitOpacity = 0.90
        style.accentColor = OverlayColor(red: 1, green: 0.35, blue: 0.20, alpha: 1)
        style.backgroundColor = OverlayColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 1)
        style.backgroundOpacity = 0.62
        style.backgroundEnabled = true
        style.backgroundPaddingX = 15
        style.backgroundPaddingY = 9
        style.backgroundRadius = 10
        style.backgroundFadeOutEnabled = false
        style.backgroundFadeOutAmount = 0
        style.backgroundBlurRadius = 0
        style.showLabel = true
        style.showUnit = true
        style.labelPosition = .top
        style.unitPosition = .trailing
        style.labelSpacing = 4
        style.unitSpacing = 6
        style.labelTextAlignment = .leading
        style.textAlignment = .leading
        style.unitTextAlignment = .leading
        style.dividerEnabled = true
        style.dividerColor = .white
        style.dividerThickness = 2
        style.dividerOpacity = 0.5
        style.iconEnabled = false
        style.iconSystemName = "heart.fill"
        style.iconPosition = .leading
        style.iconTextAlignment = .center
        style.iconSize = 22
        style.iconColor = .white
        style.iconOpacity = 1
        style.iconSpacing = 8
        style.borderEnabled = false
        style.borderWidth = 1
        style.borderColor = .white
        style.borderOpacity = 0.35
        style.shadowEnabled = false
        style.shadowRadius = 0
        style.shadowOffsetX = 0
        style.shadowOffsetY = 0
        style.shadowOpacity = 0
        style.glowEnabled = false
        style.glowIntensity = 0
        style.numericMinWidth = 0
        style.numericMinHeight = 0
        style.textColorsFollowHeartRateZones = false
        style.iconColorsFollowHeartRateZones = false
        style.valueColorsFollowHeartRateZones = false
        style.labelColorsFollowHeartRateZones = false
        style.unitColorsFollowHeartRateZones = false
        return style
    }

    static func element(
        position: CGPoint = CGPoint(x: 0.2, y: 0.3),
        style: OverlayStyle? = nil
    ) -> OverlayElement {
        OverlayElement(
            type: .heartRate,
            position: position,
            scale: 1,
            style: style ?? self.style()
        )
    }

    /// Production layout: exactly what the renderer evaluates for a numeric
    /// element (preset is forced to `.minimal`).
    static func productionLayout(
        for element: OverlayElement,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval = elapsedTime,
        canvasSize: CGSize = canvasSize
    ) -> OverlayTextRenderLayout {
        OverlayRenderModel.textLayout(
            for: element,
            in: OverlayRenderContext(
                canvasSize: canvasSize,
                activity: activity,
                elapsedTime: elapsedTime
            )
        )
    }

    /// Direct-layout oracle: the production layout with the preset under test
    /// swapped in. Numeric elements force `dividerEnabled = false` and leading
    /// alignments, so restore the style values the presets are designed for.
    static func directLayout(
        for element: OverlayElement,
        preset: OverlayTextPreset,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval = elapsedTime,
        canvasSize: CGSize = canvasSize
    ) -> OverlayTextRenderLayout {
        var layout = productionLayout(
            for: element,
            activity: activity,
            elapsedTime: elapsedTime,
            canvasSize: canvasSize
        )
        layout.preset = preset
        layout.dividerEnabled = element.style.dividerEnabled
        layout.labelTextAlignment = element.style.labelTextAlignment
        layout.valueTextAlignment = element.style.textAlignment
        layout.unitTextAlignment = element.style.unitTextAlignment
        return layout
    }

    static func effectsStyle() -> OverlayStyle {
        var style = self.style()
        style.borderEnabled = true
        style.borderWidth = 2
        style.borderColor = OverlayColor(
            red: 0.4,
            green: 0.85,
            blue: 1,
            alpha: 1
        )
        style.borderOpacity = 0.9
        style.glowEnabled = true
        style.glowIntensity = 0.55
        style.glowColor = OverlayColor(
            red: 1,
            green: 0.35,
            blue: 0.2,
            alpha: 1
        )
        style.shadowEnabled = true
        style.shadowRadius = 10
        style.shadowOffsetX = 6
        style.shadowOffsetY = 8
        style.shadowOpacity = 0.7
        style.shadowThickness = 2
        style.shadowColor = .black
        return style
    }

    static func effectsElement() -> OverlayElement {
        OverlayElement(
            type: .heartRate,
            position: CGPoint(x: 0.2, y: 0.3),
            scale: 1,
            style: effectsStyle()
        )
    }

    static func effectsSolidColorElement() -> OverlayElement {
        var style = effectsStyle()
        style.decor = .default
        style.decor.shape = .roundedRectangle
        style.decor.fillColor = OverlayColor(
            red: 0.2,
            green: 0.55,
            blue: 1,
            alpha: 0.8
        )
        style.decor.width = 220
        style.decor.height = 90
        style.decor.cornerRadius = 16
        return OverlayElement(
            type: .decorSolidColor,
            position: CGPoint(x: 0.5, y: 0.5),
            scale: 1,
            style: style
        )
    }

    // MARK: - Decor fixtures

    static func decorStyle() -> OverlayStyle {
        var style = self.style()
        style.decor = .default
        style.borderEnabled = false
        style.shadowEnabled = false
        style.glowEnabled = false
        return style
    }

    static func solidColorElement() -> OverlayElement {
        var style = decorStyle()
        style.decor.shape = .roundedRectangle
        style.decor.fillColor = OverlayColor(
            red: 1,
            green: 0.35,
            blue: 0.2,
            alpha: 0.85
        )
        style.decor.width = 240
        style.decor.height = 80
        style.decor.cornerRadius = 18
        return OverlayElement(
            type: .decorSolidColor,
            position: CGPoint(x: 0.5, y: 0.5),
            scale: 1,
            style: style
        )
    }

    static func iconElement() -> OverlayElement {
        var style = decorStyle()
        style.decor.iconAsset = .sfSymbol(
            name: "figure.run",
            weight: .regular,
            scale: .medium
        )
        style.decor.iconTint = .white
        style.decor.iconPreserveSVGColors = false
        style.decor.iconContentMode = .fit
        style.decor.width = 160
        style.decor.height = 160
        return OverlayElement(
            type: .decorIcon,
            position: CGPoint(x: 0.5, y: 0.5),
            scale: 1,
            style: style
        )
    }

    static func textElement() -> OverlayElement {
        var style = decorStyle()
        style.decor.width = 480
        style.decor.height = 120
        style.decor.textContent = "FINISH"
        style.decor.textFont = .system(family: "Menlo")
        style.decor.textSize = 64
        style.decor.textAlignment = .center
        style.decor.textLineHeight = 1.2
        style.decor.textLetterSpacing = 2
        style.decor.textFillMode = .solid(color: .white)
        style.decor.textStrokeWidth = 2
        style.decor.textStrokeColor = OverlayColor(
            red: 1,
            green: 0.35,
            blue: 0.2,
            alpha: 1
        )
        style.decor.textAutoFit = false
        return OverlayElement(
            type: .decorText,
            position: CGPoint(x: 0.5, y: 0.5),
            scale: 1,
            style: style
        )
    }

    static let canonicalPresets: [OverlayTextPreset] = [        .minimal,
        .minimalLabel,
        .pillBadge,
        .metricCard,
        .bigNumber,
        .splitLabel,
        .neonGlow,
        .racingStripe,
        .editorial,
        .digitalWatch
    ]

    static let deprecatedPresets: [OverlayTextPreset] = [
        .sportWatch,
        .inlineGhost,
        .accentBar,
        .sportNeon,
        .serifEditorial
    ]
}
#endif
