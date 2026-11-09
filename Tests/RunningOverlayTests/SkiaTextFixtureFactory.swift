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
        // Values are separate locals because one large literal times out the
        // type checker on older toolchains.
        let records: [ActivityRecord] = stride(from: 0.0, through: 60, by: 1)
            .map { (t: Double) -> ActivityRecord in
                let distanceMeters: Double = t * 3.3
                let heartRate: Int = 130 + Int(t / 3)
                let elevationMeters: Double = 20 + t / 10
                let calories: Double = t / 4
                let latitude: Double = 40.75 + 0.0006 * sin(t / 8)
                let longitude: Double = -73.99 + 0.0008 * cos(t / 8)
                return ActivityRecord(
                    elapsedTime: t,
                    timestamp: start.addingTimeInterval(t),
                    distanceMeters: distanceMeters,
                    heartRate: heartRate,
                    paceSecondsPerKilometer: 300,
                    elevationMeters: elevationMeters,
                    cadence: 176,
                    powerWatts: 250,
                    calories: calories,
                    latitude: latitude,
                    longitude: longitude
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
        style.unitFontSize = 20
        style.foregroundColor = .white
        style.valueColor = .white
        style.labelColor = OverlayColor(red: 0.85, green: 0.90, blue: 1, alpha: 1)
        style.unitColor = OverlayColor(red: 0.75, green: 0.85, blue: 1, alpha: 1)
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
        style.textAlignment = .leading
        style.dividerEnabled = true
        style.dividerColor = .white
        style.dividerThickness = 2
        style.dividerOpacity = 0.5
        style.iconSize = 22
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
        return style
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
}
#endif
