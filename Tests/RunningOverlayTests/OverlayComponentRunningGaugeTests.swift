import Foundation
import Testing
@testable import RunningOverlay

struct OverlayComponentRunningGaugeTests {
    static func data() throws -> Data {
        let item = try #require(OverlayComponentLibraryItem.chartComponents.first {
            $0.resourceName == "running-gauge"
        })
        return try #require(OverlayComponentLibrary.data(for: item))
    }

    @Test func bundledDefinitionResolves() throws {
        let package = try OverlayComponentLoader.load(data: Self.data())
        let activity = OverlayComponentRunningGaugeParityTests.activity()
        let data = OverlayComponentActivityData(
            activity: activity, elapsedTime: 90, zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720), elementScale: 1
        )
        let result = OverlayComponentResolver(definition: package.definition)
            .resolve(parameters: [:], data: data)
        #expect(result.diagnostics.isEmpty, "\(result.diagnostics)")
        #expect(package.definition.id == "studio.running-gauge")
        #expect(!result.nodes.isEmpty)
    }
}

#if canImport(CSkiaBridge)
@Suite(.serialized, .skiaSerialized)
struct OverlayComponentRunningGaugeParityTests {
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
        layout: RunningGaugeLayoutPreset = .topTwoMiddleBottom,
        progress: RunningGaugeProgressMode = .distanceTarget,
        dialOpacity: Double = 0.70,
        glass: Bool = false,
        outerRing: Bool = true,
        outerRingOpacity: Double = 0.50,
        outerRingWidth: Double = 0.022,
        ticks: Bool = true,
        tickOpacity: Double = 0.42,
        majorTickOpacity: Double = 0.95,
        tickCount: Int = 60,
        majorTickEvery: Int = 5,
        progressRing: Bool = true,
        progressColor: OverlayColor = .orange,
        progressTrackOpacity: Double = 0.22,
        progressWidth: Double = 0.026,
        roundedCaps: Bool = true,
        dividers: Bool = true,
        dividerOpacity: Double = 0.22,
        dividerWidth: Double = 1,
        font: String = "Menlo",
        monospaced: Bool = true,
        primaryWeight: OverlayFontWeight = .bold,
        secondaryWeight: OverlayFontWeight = .medium,
        regions: [RunningGaugeRegionConfig] = RunningGaugeStyle.defaultRegions(for: .topTwoMiddleBottom)
    ) -> OverlayStyle {
        var style = OverlayStyle.default
        var gauge = RunningGaugeStyle.default
        gauge.layoutPreset = layout
        gauge.regions = regions
        gauge.dialBackgroundColor = .black
        gauge.dialBackgroundOpacity = dialOpacity
        gauge.glassEffectEnabled = glass
        gauge.outerRingEnabled = outerRing
        gauge.outerRingColor = .white
        gauge.outerRingOpacity = outerRingOpacity
        gauge.outerRingWidthScale = outerRingWidth
        gauge.tickMarksEnabled = ticks
        gauge.tickColor = .white
        gauge.tickOpacity = tickOpacity
        gauge.majorTickOpacity = majorTickOpacity
        gauge.tickCount = tickCount
        gauge.majorTickEvery = majorTickEvery
        gauge.progressRingEnabled = progressRing
        gauge.progressMode = progress
        gauge.progressColor = progressColor
        gauge.progressTrackColor = .white
        gauge.progressTrackOpacity = progressTrackOpacity
        gauge.progressRingWidthScale = progressWidth
        gauge.progressRoundedCaps = roundedCaps
        gauge.dividerEnabled = dividers
        gauge.dividerColor = .white
        gauge.dividerOpacity = dividerOpacity
        gauge.dividerWidth = dividerWidth
        gauge.fontName = font
        gauge.monospacedDigits = monospaced
        gauge.primaryFontWeight = primaryWeight
        gauge.secondaryFontWeight = secondaryWeight
        gauge.primaryTextColor = .white
        gauge.secondaryTextColor = .white
        gauge.accentColor = .orange
        gauge.shadowEnabled = false
        gauge.glowEnabled = false
        style.gauge = gauge
        style.shadowEnabled = false
        style.glowEnabled = false
        return style
    }

    private static func colorHex(_ color: OverlayColor) -> String {
        String(format: "#%02X%02X%02X",
               Int((color.red * 255).rounded()),
               Int((color.green * 255).rounded()),
               Int((color.blue * 255).rounded()))
    }

    private static let regionKeys: [(RunningGaugeRegion, String)] = [
        (.top, "top"), (.middle, "middle"), (.bottom, "bottom"),
        (.middleLeft, "middleLeft"), (.middleCenter, "middleCenter"),
        (.middleRight, "middleRight"), (.topLeft, "topLeft"),
        (.topRight, "topRight"), (.bottomLeft, "bottomLeft"),
        (.bottomRight, "bottomRight")
    ]

    private static func parameters(_ style: OverlayStyle, progress: Double) -> [String: OverlayJSONValue] {
        let gauge = style.gauge
        var result: [String: OverlayJSONValue] = [
            "layoutPreset": .string(gauge.layoutPreset.rawValue),
            "progress": .number(progress),
            "dialBackgroundColor": .string(colorHex(gauge.dialBackgroundColor)),
            "dialBackgroundOpacity": .number(gauge.dialBackgroundOpacity),
            "glassEffectEnabled": .boolean(gauge.glassEffectEnabled),
            "outerRingEnabled": .boolean(gauge.outerRingEnabled),
            "outerRingColor": .string(colorHex(gauge.outerRingColor)),
            "outerRingOpacity": .number(gauge.outerRingOpacity),
            "outerRingWidthScale": .number(gauge.outerRingWidthScale),
            "tickMarksEnabled": .boolean(gauge.tickMarksEnabled),
            "tickColor": .string(colorHex(gauge.tickColor)),
            "tickOpacity": .number(gauge.tickOpacity),
            "majorTickOpacity": .number(gauge.majorTickOpacity),
            "tickCount": .number(Double(gauge.tickCount)),
            "majorTickEvery": .number(Double(gauge.majorTickEvery)),
            "progressRingEnabled": .boolean(gauge.progressRingEnabled),
            "progressColor": .string(colorHex(gauge.progressColor)),
            "progressTrackColor": .string(colorHex(gauge.progressTrackColor)),
            "progressTrackOpacity": .number(gauge.progressTrackOpacity),
            "progressRingWidthScale": .number(gauge.progressRingWidthScale),
            "progressRoundedCaps": .boolean(gauge.progressRoundedCaps),
            "dividerEnabled": .boolean(gauge.dividerEnabled),
            "dividerColor": .string(colorHex(gauge.dividerColor)),
            "dividerOpacity": .number(gauge.dividerOpacity),
            "dividerWidth": .number(gauge.dividerWidth),
            "fontFamily": .string(gauge.fontName),
            "monospacedDigits": .boolean(gauge.monospacedDigits),
            "primaryFontWeight": .string(gauge.primaryFontWeight.rawValue),
            "secondaryFontWeight": .string(gauge.secondaryFontWeight.rawValue),
            "primaryTextColor": .string(colorHex(gauge.primaryTextColor)),
            "secondaryTextColor": .string(colorHex(gauge.secondaryTextColor)),
            "accentColor": .string(colorHex(gauge.accentColor))
        ]
        for (region, key) in regionKeys {
            guard let config = gauge.regions.first(where: { $0.region == region }) else {
                // Keep the definition's defaults for unused regions.
                continue
            }
            result["\(key)Metric"] = .string(config.metric.overlayMetric.rawValue)
            result["\(key)ValueFontScale"] = .number(config.valueFontScale)
            result["\(key)ShowLabel"] = .boolean(config.showLabel)
            result["\(key)ShowUnit"] = .boolean(config.showUnit)
            result["\(key)CustomLabel"] = .string(config.customLabel)
        }
        return result
    }

    @Test func runningGaugeMatchesNative() throws {
        try OverlayPreferenceFixtures.withDefaults {
            let reference = try OverlayComponentReference(
                definitionData: OverlayComponentRunningGaugeTests.data(), source: .bundled
            )
            let activity = Self.activity()
            let canvas = CGSize(width: 1280, height: 720)
            let hiddenLabels = RunningGaugeStyle.defaultRegions(for: .topTwoMiddleBottom).map { config in
                var copy = config
                copy.showLabel = false
                copy.showUnit = false
                return copy
            }
            let cases: [(String, OverlayStyle, Double, TimeInterval)] = [
                ("default", Self.style(), 1, 90),
                ("top-bottom", Self.style(layout: .topBottom,
                                          regions: RunningGaugeStyle.defaultRegions(for: .topBottom)), 1, 90),
                ("top-middle-bottom", Self.style(layout: .topMiddleBottom,
                                                 regions: RunningGaugeStyle.defaultRegions(for: .topMiddleBottom)), 1, 90),
                ("three-zones", Self.style(layout: .threeZones,
                                           regions: RunningGaugeStyle.defaultRegions(for: .threeZones)), 1, 90),
                ("top-three-middle-bottom", Self.style(layout: .topThreeMiddleBottom,
                                                       regions: RunningGaugeStyle.defaultRegions(for: .topThreeMiddleBottom)), 1, 90),
                ("four-zones", Self.style(layout: .fourZones,
                                          regions: RunningGaugeStyle.defaultRegions(for: .fourZones)), 1, 90),
                ("five-zones", Self.style(layout: .fiveZones,
                                          regions: RunningGaugeStyle.defaultRegions(for: .fiveZones)), 1, 90),
                ("no-rings", Self.style(outerRing: false, progressRing: false), 1, 90),
                ("no-ticks", Self.style(ticks: false), 1, 90),
                ("no-dividers", Self.style(dividers: false), 1, 90),
                ("glass", Self.style(glass: true), 1, 90),
                ("caps-off", Self.style(roundedCaps: false), 1, 90),
                ("compact-ticks", Self.style(outerRingWidth: 0.04, tickCount: 24, majorTickEvery: 4,
                                             progressWidth: 0.05), 1, 90),
                ("hidden-labels", Self.style(regions: hiddenLabels), 1, 90),
                ("scaled", Self.style(), 1.5, 90),
                ("mono-off", Self.style(monospaced: false, primaryWeight: .semibold,
                                        secondaryWeight: .regular), 1, 90),
                ("zero-progress", Self.style(ticks: false, progressTrackOpacity: 0), 1, 90)
            ]
            for (label, style, elementScale, time) in cases {
                let nativeStyle = style
                let native = OverlayElement(
                    type: .runningGauge, position: CGPoint(x: 0.5, y: 0.5),
                    scale: elementScale, style: nativeStyle
                )
                let context = OverlayRenderContext(
                    canvasSize: canvas, activity: activity, elapsedTime: time
                )
                let layout = OverlayRenderModel.runningGaugeLayout(for: native, in: context)
                let progress: Double
                switch nativeStyle.gauge.progressMode {
                case .distanceTarget:
                    progress = activity.distanceMeters > 0
                        ? activity.distance(at: time) / activity.distanceMeters : 0
                case .none:
                    progress = 0
                default:
                    progress = activity.duration > 0 ? time / activity.duration : 0
                }
                let component = OverlayElement(
                    type: .component,
                    position: CGPoint(
                        x: layout.rect.minX / canvas.width,
                        y: layout.rect.minY / canvas.height
                    ),
                    scale: elementScale,
                    style: nativeStyle,
                    component: OverlayComponentInstance(
                        reference: reference,
                        parameters: Self.parameters(nativeStyle, progress: progress)
                    )
                )
                let frame = try #require(
                    OverlayComponentSkiaRenderer.frame(for: component, renderContext: context)
                )
                #expect(abs(frame.width - layout.diameter) < 0.5, "\(label) width")
                #expect(abs(frame.height - layout.diameter) < 0.5, "\(label) height")
                let ratio = label == "scaled" ? 0.005 : 0.0035
                try NativeComponentParityHarness.assertParity(
                    label: "gauge-\(label)",
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
