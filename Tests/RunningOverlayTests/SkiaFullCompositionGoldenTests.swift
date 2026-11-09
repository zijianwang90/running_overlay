#if canImport(CSkiaBridge)
import CoreGraphics
import Foundation
import Testing
@testable import RunningOverlay

/// Full-template composition parity through the shared renderer.
///
/// Earlier goldens render one module at a time through a per-module host.
/// This scene puts every ported module on one 1080p canvas and renders it
/// through `SkiaEasyRunRenderer` (via `SkiaFrameRendererBackend`), the same
/// path preview and export use. It therefore covers z-order between modules,
/// the shared Skia canvas and asset preload, and per-frame state carried
/// across sequential module draws.
///
/// Elevation chart, HUD, and work summary are covered by their own module
/// goldens; they are omitted here to keep this scene's display windows
/// deterministic.
@Suite(.serialized, .skiaSerialized) struct SkiaFullCompositionGoldenTests {
    private static let canvas = CGSize(width: 1920, height: 1080)

    @Test func fullTemplateMatchesSwiftUI() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            let metrics = try await SkiaGoldenFrameHarness.compare(
                layout: Self.layout(),
                activity: Self.workout(),
                elapsedTime: 150,
                size: Self.canvas,
                label: "full-template"
            )
            print(metrics.description)
            #expect(metrics.changedRatio < 0.15, "\(metrics)")
            #expect(metrics.meanDelta < 2.0, "\(metrics)")
        }
    }

    // MARK: - Scene

    private static func layout() -> OverlayLayout {
        let style = pinnedStyle()
        var elements: [OverlayElement] = []

        // Numeric readings are components, which the SwiftUI oracle cannot
        // draw (ADR 0014), so this scene covers native modules only.
        var solid = SkiaTextFixtureFactory.solidColorElement()
        solid.position = CGPoint(x: 0.10, y: 0.11)
        elements.append(solid)

        var icon = SkiaTextFixtureFactory.iconElement()
        icon.position = CGPoint(x: 0.44, y: 0.10)
        elements.append(icon)

        var decorText = SkiaTextFixtureFactory.textElement()
        decorText.position = CGPoint(x: 0.15, y: 0.22)
        elements.append(decorText)

        elements.append(
            element(.distanceTimeline, at: CGPoint(x: 0.15, y: 0.78), style: style)
        )

        var routeStyle = style
        routeStyle.routeMapBackgroundStyle = .none
        elements.append(
            element(.routeMap, at: CGPoint(x: 0.78, y: 0.72), style: routeStyle)
        )

        var weatherStyle = style
        weatherStyle.weatherWidget = weatherWidget()
        elements.append(
            element(.weatherWidget, at: CGPoint(x: 0.86, y: 0.16), style: weatherStyle)
        )

        elements.append(
            element(.intervalTimeline, at: CGPoint(x: 0.50, y: 0.90), style: style)
        )
        elements.append(
            element(.intervalCountdown, at: CGPoint(x: 0.26, y: 0.42), style: style)
        )
        // Edge placement ignores the anchor and pins the bar to the bottom edge.
        elements.append(
            element(.zoneEdgeBar, at: CGPoint(x: 0.50, y: 0.50), style: style)
        )

        return OverlayLayout(elements: elements)
    }

    private static func element(
        _ type: OverlayElementType,
        at position: CGPoint,
        style: OverlayStyle
    ) -> OverlayElement {
        OverlayElement(type: type, position: position, scale: 1, style: style)
    }

    private static func pinnedStyle() -> OverlayStyle {
        var style = OverlayStyle.default
        style.fontName = "Menlo"
        style.labelFontName = "Menlo"
        style.distanceTimeline.labelFontName = "Menlo"
        style.distanceTimeline.axisLabelFontName = "Menlo"
        style.routeMapStatsBar.valueFontName = "Menlo"
        style.routeMapStatsBar.labelFontName = "Menlo"
        style.intervalTimeline.markerFontName = "Menlo"
        style.intervalCountdown.helperText.fontName = "Menlo"
        style.intervalCountdown.phaseText.fontName = "Menlo"
        style.intervalCountdown.repText.fontName = "Menlo"
        style.intervalCountdown.countdownText.fontName = "Menlo"
        style.intervalCountdown.captionText.fontName = "Menlo"
        style.zoneEdgeBar.markerText.fontName = "Menlo"
        return style
    }

    private static func weatherWidget() -> WeatherWidgetStyle {
        var widget = WeatherWidgetStyle.preset(.simpleCard)
        widget.dataSource = .openMeteo
        widget.cachedWeather = WeatherPayload(
            condition: .rain,
            temperatureCelsius: 12.4,
            humidity: 81,
            highTemperatureCelsius: 15.2,
            lowTemperatureCelsius: 9.8,
            windKph: 14,
            feelsLikeCelsius: 10.6,
            resolvedLocation: "Berlin",
            sourceDate: Date(timeIntervalSince1970: 1_735_689_600)
        )
        widget.locationText = "Berlin"
        widget.locationTextStyle.fontName = "Menlo"
        widget.conditionTextStyle.fontName = "Menlo"
        widget.temperatureTextStyle.fontName = "Menlo"
        widget.slotTitleTextStyle.fontName = "Menlo"
        widget.slotLabelTextStyle.fontName = "Menlo"
        return widget
    }

    // MARK: - Activity

    private struct LapSpec {
        var kind: LapKind
        var seconds: TimeInterval
        var heartRate: Int
        var paceSecondsPerKm: Double
    }

    /// Six-lap interval workout with per-second GPS records, so the route map
    /// and the interval modules read the same synthetic timeline.
    static func workout() -> ActivityTimeline {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let specs: [LapSpec] = [
            LapSpec(kind: .warmup, seconds: 60, heartRate: 128, paceSecondsPerKm: 330),
            LapSpec(kind: .active, seconds: 240, heartRate: 172, paceSecondsPerKm: 248),
            LapSpec(kind: .rest, seconds: 60, heartRate: 146, paceSecondsPerKm: 420),
            LapSpec(kind: .active, seconds: 240, heartRate: 178, paceSecondsPerKm: 244),
            LapSpec(kind: .rest, seconds: 60, heartRate: 148, paceSecondsPerKm: 430),
            LapSpec(kind: .cooldown, seconds: 60, heartRate: 124, paceSecondsPerKm: 360),
        ]

        var laps: [LapRecord] = []
        var records: [ActivityRecord] = []
        var elapsed: TimeInterval = 0
        var distance: Double = 0

        for (index, spec) in specs.enumerated() {
            let lapDistance = spec.seconds * 1000 / spec.paceSecondsPerKm
            laps.append(
                LapRecord(
                    lapIndex: index,
                    startElapsedTime: elapsed,
                    endElapsedTime: elapsed + spec.seconds,
                    startDistanceMeters: distance,
                    totalDistanceMeters: lapDistance,
                    totalElapsedTime: spec.seconds,
                    avgPaceSecondsPerKm: spec.paceSecondsPerKm,
                    avgHeartRate: spec.heartRate,
                    maxHeartRate: spec.heartRate + 4,
                    avgCadenceSPM: 176,
                    avgPowerWatts: 240,
                    totalAscent: nil,
                    kind: spec.kind
                )
            )
            for second in stride(
                from: elapsed,
                to: elapsed + spec.seconds,
                by: 1
            ) {
                let fraction = (second - elapsed) / spec.seconds
                records.append(
                    record(
                        at: second,
                        start: start,
                        distance: distance + lapDistance * fraction,
                        heartRate: spec.heartRate,
                        pace: spec.paceSecondsPerKm
                    )
                )
            }
            elapsed += spec.seconds
            distance += lapDistance
        }
        records.append(
            record(
                at: elapsed,
                start: start,
                distance: distance,
                heartRate: specs[specs.count - 1].heartRate,
                pace: specs[specs.count - 1].paceSecondsPerKm
            )
        )

        return ActivityTimeline(
            startDate: start,
            duration: elapsed,
            distanceMeters: distance,
            records: records,
            laps: laps
        )
    }

    private static func record(
        at elapsed: TimeInterval,
        start: Date,
        distance: Double,
        heartRate: Int,
        pace: Double
    ) -> ActivityRecord {
        ActivityRecord(
            elapsedTime: elapsed,
            timestamp: start.addingTimeInterval(elapsed),
            distanceMeters: distance,
            heartRate: heartRate,
            paceSecondsPerKilometer: pace,
            elevationMeters: 20 + 8 * sin(elapsed / 90),
            cadence: 176,
            powerWatts: 240,
            calories: elapsed / 4,
            latitude: 40.75 + 0.0020 * sin(elapsed / 110),
            longitude: -73.99 + 0.0026 * cos(elapsed / 110)
        )
    }
}
#endif
