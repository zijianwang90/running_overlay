import Foundation
import Testing
@testable import RunningOverlay

struct OverlayComponentElevationChartTests {
    static func data() throws -> Data {
        let item = try #require(OverlayComponentLibraryItem.chartComponents.first {
            $0.resourceName == "elevation-chart"
        })
        return try #require(OverlayComponentLibrary.data(for: item))
    }

    @Test func bundledDefinitionResolves() throws {
        let package = try OverlayComponentLoader.load(data: Self.data())
        let activity = OverlayComponentElevationChartParityTests.activity()
        let data = OverlayComponentActivityData(
            activity: activity, elapsedTime: 90, zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720), elementScale: 1
        )
        let result = OverlayComponentResolver(definition: package.definition)
            .resolve(parameters: [:], data: data)
        #expect(result.diagnostics.isEmpty, "\(result.diagnostics)")
        #expect(package.definition.id == "studio.elevation-chart")
        #expect(!result.nodes.isEmpty)
    }
}

#if canImport(CSkiaBridge)
@Suite(.serialized, .skiaSerialized)
struct OverlayComponentElevationChartParityTests {
    static func activity() -> ActivityTimeline {
        let start = Date(timeIntervalSince1970: 1_735_689_600)
        var records: [ActivityRecord] = []
        var t: TimeInterval = 0
        while t <= 600 {
            records.append(ActivityRecord(
                elapsedTime: t, timestamp: start.addingTimeInterval(t),
                distanceMeters: t * 3.2, heartRate: 148 + Int(t / 120),
                paceSecondsPerKilometer: 312, elevationMeters: 20 + sin(t / 90) * 6,
                cadence: 176, powerWatts: 245, calories: t / 4
            ))
            t += 1
        }
        let laps = [LapRecord(
            lapIndex: 0, startElapsedTime: 0, endElapsedTime: 600,
            startDistanceMeters: 0, totalDistanceMeters: 1920,
            totalElapsedTime: 600, avgPaceSecondsPerKm: 312,
            avgHeartRate: 152, maxHeartRate: 160, avgCadenceSPM: 176,
            avgPowerWatts: 245, totalAscent: 30, kind: .active
        )]
        return ActivityTimeline(
            startDate: start, duration: 600, distanceMeters: 1920,
            records: records, laps: laps
        )
    }

    private static func style(
        preset: ElevationChartPreset = .gradientArea,
        chartStyle: ElevationChartRenderStyle = .area,
        smoothingEnabled: Bool = true,
        smoothingAmount: Double = 0.85,
        progressMode: ElevationChartProgressMode = .fullProfile,
        lineWidth: Double = 2.5,
        lineOpacity: Double = 0.96,
        fillEnabled: Bool = true,
        fillOpacity: Double = 0.40,
        dualAreaEnabled: Bool = false,
        currentMarkerEnabled: Bool = true,
        markerSizeMultiplier: Double = 1,
        markerPlayheadLineEnabled: Bool = true,
        markerLabelEnabled: Bool = true,
        gridEnabled: Bool = false,
        axisLineEnabled: Bool = true,
        axisLabelsEnabled: Bool = true,
        bigNumbersEnabled: Bool = false,
        bigNumberMetric: ElevationChartBigMetric = .currentElevation,
        backgroundEnabled: Bool = true,
        backgroundOpacity: Double = 0.42,
        cornerRadius: Double = 18,
        borderEnabled: Bool = true,
        borderOpacity: Double = 0.10,
        glowEnabled: Bool = false,
        glowOpacity: Double = 0.25
    ) -> OverlayStyle {
        var style = OverlayStyle.default
        var chart = ElevationChartStyle.preset(preset)
        chart.width = 420
        chart.height = 178
        chart.chartStyle = chartStyle
        chart.smoothingEnabled = smoothingEnabled
        chart.smoothingAmount = smoothingAmount
        chart.progressMode = progressMode
        chart.lineWidth = lineWidth
        chart.lineOpacity = lineOpacity
        chart.fillEnabled = fillEnabled
        chart.fillOpacity = fillOpacity
        chart.dualAreaEnabled = dualAreaEnabled
        chart.currentMarkerEnabled = currentMarkerEnabled
        chart.markerSizeMultiplier = markerSizeMultiplier
        chart.markerPlayheadLineEnabled = markerPlayheadLineEnabled
        chart.markerLabelEnabled = markerLabelEnabled
        chart.gridEnabled = gridEnabled
        chart.axisLineEnabled = axisLineEnabled
        chart.axisLabelsEnabled = axisLabelsEnabled
        chart.bigNumbersEnabled = bigNumbersEnabled
        chart.bigNumberMetric = bigNumberMetric
        chart.backgroundEnabled = backgroundEnabled
        chart.backgroundOpacity = backgroundOpacity
        chart.cornerRadius = cornerRadius
        chart.borderEnabled = borderEnabled
        chart.borderOpacity = borderOpacity
        chart.glowEnabled = glowEnabled
        chart.glowOpacity = glowOpacity
        style.elevationChart = chart
        style.shadowEnabled = false
        style.glowEnabled = false
        style.backgroundEnabled = chart.backgroundEnabled
        style.backgroundColor = chart.backgroundColor
        style.backgroundOpacity = chart.backgroundOpacity
        style.backgroundRadius = chart.cornerRadius
        style.backgroundPaddingX = 0
        style.backgroundPaddingY = 0
        style.borderEnabled = chart.borderEnabled
        style.borderOpacity = chart.borderOpacity
        return style
    }

    private static func colorHex(_ color: OverlayColor) -> String {
        String(format: "#%02X%02X%02X",
               Int((color.red * 255).rounded()),
               Int((color.green * 255).rounded()),
               Int((color.blue * 255).rounded()))
    }

    private static func parameters(_ style: OverlayStyle) -> [String: OverlayJSONValue] {
        let c = style.elevationChart
        return [
            "preset": .string(c.preset.rawValue),
            "chartStyle": .string(c.chartStyle.rawValue),
            "smoothingEnabled": .boolean(c.smoothingEnabled),
            "smoothingAmount": .number(c.smoothingAmount),
            "progressMode": .string(c.progressMode.rawValue),
            "chartPaddingX": .number(c.chartPaddingX),
            "chartPaddingY": .number(c.chartPaddingY),
            "lineColor": .string(colorHex(c.lineColor)),
            "lineWidth": .number(c.lineWidth),
            "lineOpacity": .number(c.lineOpacity),
            "fillEnabled": .boolean(c.fillEnabled),
            "fillStartColor": .string(colorHex(c.fillStartColor)),
            "fillEndColor": .string(colorHex(c.fillEndColor)),
            "fillOpacity": .number(c.fillOpacity),
            "dualAreaEnabled": .boolean(c.dualAreaEnabled),
            "upperFillColor": .string(colorHex(c.upperFillColor)),
            "lowerFillColor": .string(colorHex(c.lowerFillColor)),
            "currentMarkerEnabled": .boolean(c.currentMarkerEnabled),
            "markerColor": .string(colorHex(c.markerColor)),
            "markerSizeMultiplier": .number(c.markerSizeMultiplier),
            "markerPlayheadLineEnabled": .boolean(c.markerPlayheadLineEnabled),
            "markerLabelEnabled": .boolean(c.markerLabelEnabled),
            "gridEnabled": .boolean(c.gridEnabled),
            "axisLineEnabled": .boolean(c.axisLineEnabled),
            "axisLabelsEnabled": .boolean(c.axisLabelsEnabled),
            "bigNumbersEnabled": .boolean(c.bigNumbersEnabled),
            "bigNumberMetric": .string(c.bigNumberMetric.rawValue),
            "bigNumberFontSize": .number(c.bigNumberFontSize),
            "bigNumberFontFamily": .string(c.bigNumberFontName),
            "bigNumberFontWeight": .string(c.bigNumberFontWeight.rawValue),
            "backgroundEnabled": .boolean(c.backgroundEnabled),
            "backgroundColor": .string(colorHex(c.backgroundColor)),
            "backgroundOpacity": .number(c.backgroundOpacity),
            "cornerRadius": .number(c.cornerRadius),
            "borderEnabled": .boolean(c.borderEnabled),
            "borderOpacity": .number(c.borderOpacity),
            "shadowEnabled": .boolean(c.shadowEnabled),
            "shadowOpacity": .number(c.shadowOpacity),
            "shadowRadius": .number(c.shadowRadius),
            "glowEnabled": .boolean(c.glowEnabled),
            "glowOpacity": .number(c.glowOpacity),
            "fontFamily": .string(style.fontName),
            "foregroundColor": .string(colorHex(style.foregroundColor)),
            "valueFontSize": .number(style.fontSize)
        ]
    }

    @Test func elevationChartMatchesNative() throws {
        try OverlayPreferenceFixtures.withDefaults {
            let reference = try OverlayComponentReference(
                definitionData: OverlayComponentElevationChartTests.data(), source: .bundled
            )
            let activity = Self.activity()
            let canvas = CGSize(width: 1280, height: 720)
            let cases: [(String, OverlayStyle, Double, TimeInterval)] = [
                ("default", Self.style(), 1, 90),
                ("dual-area", Self.style(preset: .dualArea), 1, 90),
                ("tech-glow", Self.style(preset: .techGlow), 1, 90),
                ("minimal-white", Self.style(preset: .minimalWhite), 1, 90),
                ("big-numbers", Self.style(preset: .bigNumbers, bigNumbersEnabled: true), 1, 90),
                ("line-only", Self.style(chartStyle: .lineOnly), 1, 90),
                ("progress", Self.style(progressMode: .progressToCurrent), 1, 90),
                ("grid", Self.style(gridEnabled: true), 1, 90),
                ("no-marker", Self.style(currentMarkerEnabled: false), 1, 90),
                ("big-marker", Self.style(markerSizeMultiplier: 1.8), 1, 90),
                ("no-fill", Self.style(fillEnabled: false), 1, 90),
                ("smooth-off", Self.style(smoothingEnabled: false), 1, 90),
                ("no-background", Self.style(backgroundEnabled: false), 1, 90),
                ("no-axis", Self.style(axisLineEnabled: false, axisLabelsEnabled: false), 1, 90),
                ("glow", Self.style(glowEnabled: true, glowOpacity: 0.4), 1, 90),
                ("scaled", Self.style(), 1.5, 90),
                ("late", Self.style(progressMode: .progressToCurrent), 1, 540)
            ]
            for (label, style, elementScale, time) in cases {
                let native = OverlayElement(
                    type: .elevationChart, position: CGPoint(x: 0.5, y: 0.5),
                    scale: elementScale, style: style
                )
                let context = OverlayRenderContext(
                    canvasSize: canvas, activity: activity, elapsedTime: time
                )
                let layout = OverlayRenderModel.elevationChartLayout(for: native, in: context)
                let component = OverlayElement(
                    type: .component,
                    position: CGPoint(
                        x: layout.rect.minX / canvas.width,
                        y: layout.rect.minY / canvas.height
                    ),
                    scale: elementScale,
                    style: style,
                    component: OverlayComponentInstance(
                        reference: reference,
                        parameters: Self.parameters(style)
                    )
                )
                let ratio = label == "scaled" ? 0.005 : 0.0035
                try NativeComponentParityHarness.assertParity(
                    label: "elevation-\(label)",
                    native: OverlayLayout(elements: [native]),
                    component: OverlayLayout(elements: [component]),
                    activity: activity,
                    elapsedTime: time,
                    size: canvas,
                    thresholds: .init(
                        channelTolerance: 2,
                        maximumChangedPixelRatio: ratio,
                        maximumChannelDelta: 80,
                        maximumMeanChannelDelta: 0.13
                    )
                )
            }
        }
    }
}
#endif
