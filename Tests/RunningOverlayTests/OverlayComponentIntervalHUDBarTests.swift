import Foundation
import Testing
@testable import RunningOverlay

struct OverlayComponentIntervalHUDBarTests {
    static func data() throws -> Data {
        let item = try #require(OverlayComponentLibraryItem.intervalComponents.first {
            $0.resourceName == "interval-hud-bar"
        })
        return try #require(OverlayComponentLibrary.data(for: item))
    }

    @Test func bundledDefinitionResolvesWithWorkData() throws {
        let package = try OverlayComponentLoader.load(data: Self.data())
        let start = Date(timeIntervalSince1970: 1_735_689_600)
        let activity = ActivityTimeline(
            startDate: start, duration: 180, distanceMeters: 600,
            records: (0...180).map { t in
                ActivityRecord(
                    elapsedTime: Double(t), timestamp: start.addingTimeInterval(Double(t)),
                    distanceMeters: Double(t) * 3.3, heartRate: 150,
                    paceSecondsPerKilometer: 300, elevationMeters: 20,
                    cadence: 176, powerWatts: 240, calories: Double(t) / 4
                )
            },
            laps: [
                LapRecord(lapIndex: 0, startElapsedTime: 0, endElapsedTime: 60,
                          startDistanceMeters: 0, totalDistanceMeters: 180,
                          totalElapsedTime: 60, avgPaceSecondsPerKm: 333,
                          avgHeartRate: 140, maxHeartRate: 145, avgCadenceSPM: 172,
                          avgPowerWatts: 220, totalAscent: nil, kind: .warmup),
                LapRecord(lapIndex: 1, startElapsedTime: 60, endElapsedTime: 120,
                          startDistanceMeters: 180, totalDistanceMeters: 400,
                          totalElapsedTime: 60, avgPaceSecondsPerKm: 300,
                          avgHeartRate: 170, maxHeartRate: 178, avgCadenceSPM: 180,
                          avgPowerWatts: 260, totalAscent: nil, kind: .active),
            ]
        )
        let data = OverlayComponentActivityData(
            activity: activity, elapsedTime: 125, zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720), elementScale: 1
        )
        let result = OverlayComponentResolver(definition: package.definition)
            .resolve(parameters: [:], data: data)
        #expect(result.diagnostics.isEmpty, "\(result.diagnostics)")
        #expect(!result.nodes.isEmpty)
        #expect(package.definition.id == "studio.interval-hud-bar")
    }
}

#if canImport(CSkiaBridge)
@Suite(.serialized, .skiaSerialized)
struct OverlayComponentIntervalHUDBarParityTests {
    private static func activity(duration: TimeInterval = 180) -> ActivityTimeline {
        let start = Date(timeIntervalSince1970: 1_735_689_600)
        let specs: [(LapKind, TimeInterval, Int, Double)] = [
            (.warmup, 60, 130, 340), (.active, 60, 176, 240), (.rest, 60, 145, 420)
        ]
        var laps: [LapRecord] = []
        var records: [ActivityRecord] = []
        var elapsed: TimeInterval = 0
        var distance: Double = 0
        for (index, spec) in specs.enumerated() {
            let lapDistance = spec.1 * 1000 / spec.3
            laps.append(LapRecord(
                lapIndex: index, startElapsedTime: elapsed, endElapsedTime: elapsed + spec.1,
                startDistanceMeters: distance, totalDistanceMeters: lapDistance,
                totalElapsedTime: spec.1, avgPaceSecondsPerKm: spec.3,
                avgHeartRate: spec.2, maxHeartRate: spec.2 + 4, avgCadenceSPM: 176,
                avgPowerWatts: 240, totalAscent: nil, kind: spec.0
            ))
            var t = elapsed
            while t <= elapsed + spec.1 {
                records.append(ActivityRecord(
                    elapsedTime: t, timestamp: start.addingTimeInterval(t),
                    distanceMeters: distance + spec.1 * 1000 / spec.3 * (t - elapsed) / spec.1,
                    heartRate: spec.2, paceSecondsPerKilometer: spec.3,
                    elevationMeters: 20, cadence: 176, powerWatts: 240, calories: t / 4
                ))
                t += 1
            }
            elapsed += spec.1
            distance += lapDistance
        }
        return ActivityTimeline(
            startDate: start, duration: duration, distanceMeters: distance,
            records: records, laps: laps
        )
    }

    private static func style(
        background: Bool = false,
        bottomBar: IntervalHUDBarBottomBarMode = .lapProgress,
        showsRep: Bool = true,
        showsPhase: Bool = true,
        showsRemaining: Bool = true,
        showsZone: Bool = true,
        metrics: [IntervalHUDBarMetric] = [.heartRate, .pace],
        activeWidthShare: Double = 0,
        activeHeightScale: Double = 1,
        marker: Bool = true,
        markerPosition: IntervalHUDBarZoneMarkerPosition = .above,
        markerShowsValue: Bool = true,
        thresholdMarker: Bool = true,
        zoneDisplayMode: IntervalHUDBarZoneDisplayMode = .heartRateZone,
        hrDropMode: IntervalHUDBarHRDropMode = .bpm,
        remainingPrimary: IntervalHUDBarRemainingPrimary = .distance,
        progressMode: IntervalHUDBarProgressMode = .distance
    ) -> OverlayStyle {
        var style = OverlayStyle.default
        let bar = style.intervalHUDBar
        style.intervalHUDBar = IntervalHUDBarStyle(
            width: 760, height: 116,
            bottomBarEnabled: bottomBar != .none, bottomBarMode: bottomBar,
            progressMode: progressMode, hrDropMode: hrDropMode,
            remainingPrimary: remainingPrimary,
            showsRep: showsRep, showsPhase: showsPhase,
            phaseDetailMode: bar.phaseDetailMode, restPhaseDetailMode: bar.restPhaseDetailMode,
            showsRemaining: showsRemaining, showsZone: showsZone,
            zoneDisplayMode: zoneDisplayMode,
            metricSlots: metrics.map { IntervalHUDBarMetricSlot(metric: $0) },
            phaseColorFallback: bar.phaseColorFallback,
            trackColor: bar.trackColor, trackOpacity: bar.trackOpacity,
            bottomBarSpacing: bar.bottomBarSpacing,
            bottomBarGlowEnabled: false, bottomBarGlowIntensity: bar.bottomBarGlowIntensity,
            activeZoneWidthShare: activeWidthShare, activeZoneHeightScale: activeHeightScale,
            zoneSegmentGap: bar.zoneSegmentGap,
            bottomBarCornerRadius: bar.bottomBarCornerRadius,
            bottomBarBorderEnabled: bar.bottomBarBorderEnabled,
            bottomBarBorderColor: bar.bottomBarBorderColor,
            bottomBarBorderOpacity: bar.bottomBarBorderOpacity,
            bottomBarBorderWidth: bar.bottomBarBorderWidth,
            inactiveZoneOpacity: bar.inactiveZoneOpacity,
            zoneMarkerEnabled: marker, zoneMarkerPosition: markerPosition,
            zoneMarkerShowsValue: markerShowsValue,
            thresholdZoneMarkerEnabled: thresholdMarker,
            labelText: bar.labelText, primaryValueText: bar.primaryValueText,
            phaseText: bar.phaseText, phaseDetailText: bar.phaseDetailText,
            metricValueText: bar.metricValueText, metricUnitText: bar.metricUnitText
        )
        for role in IntervalHUDBarTypographyRole.allCases {
            switch role {
            case .labels: style.intervalHUDBar.labelText.fontName = "Menlo"
            case .primaryValues: style.intervalHUDBar.primaryValueText.fontName = "Menlo"
            case .phase: style.intervalHUDBar.phaseText.fontName = "Menlo"
            case .phaseDetail: style.intervalHUDBar.phaseDetailText.fontName = "Menlo"
            case .metricValues: style.intervalHUDBar.metricValueText.fontName = "Menlo"
            case .metricUnits: style.intervalHUDBar.metricUnitText.fontName = "Menlo"
            }
        }
        style.foregroundColor = .white
        style.labelColor = OverlayColor(red: 0.84, green: 0.88, blue: 0.94, alpha: 1)
        style.unitColor = OverlayColor(red: 0.72, green: 0.78, blue: 0.86, alpha: 1)
        style.dividerColor = .white
        style.dividerOpacity = 0.16
        style.dividerThickness = 2
        style.backgroundEnabled = background
        if background {
            style.backgroundColor = OverlayColor(red: 0.04, green: 0.07, blue: 0.12, alpha: 1)
            style.backgroundOpacity = 0.82
            style.backgroundPaddingX = 12
            style.backgroundPaddingY = 10
            style.backgroundRadius = 18
            style.borderEnabled = true
            style.borderColor = .white
            style.borderOpacity = 0.3
            style.borderWidth = 2
            style.shadowEnabled = true
            style.shadowOpacity = 0.4
            style.shadowRadius = 8
            style.shadowOffsetY = 3
        } else {
            style.shadowEnabled = false
        }
        style.glowEnabled = false
        return style
    }

    private static func colorHex(_ color: OverlayColor) -> String {
        String(format: "#%02X%02X%02X",
               Int((color.red * 255).rounded()), Int((color.green * 255).rounded()),
               Int((color.blue * 255).rounded()))
    }

    private static func parameters(_ style: OverlayStyle) -> [String: OverlayJSONValue] {
        let h = style.intervalHUDBar
        var values: [String: OverlayJSONValue] = [
            "barWidth": .number(h.width),
            "barHeight": .number(h.height),
            "showsRep": .boolean(h.showsRep),
            "showsPhase": .boolean(h.showsPhase),
            "phaseDetailMode": .string(h.phaseDetailMode.rawValue),
            "restPhaseDetailMode": .string(h.restPhaseDetailMode.rawValue),
            "showsRemaining": .boolean(h.showsRemaining),
            "remainingPrimary": .string(h.remainingPrimary.rawValue),
            "showsZone": .boolean(h.showsZone),
            "zoneDisplayMode": .string(h.zoneDisplayMode.rawValue),
            "hrDropMode": .string(h.hrDropMode.rawValue),
            "progressMode": .string(h.progressMode.rawValue),
            "bottomBarMode": .string(h.bottomBarEnabled ? h.bottomBarMode.rawValue : "none"),
            "bottomBarSpacing": .number(h.bottomBarSpacing),
            "trackColor": .string(colorHex(h.trackColor)),
            "trackOpacity": .number(h.trackOpacity),
            "bottomBarGlowEnabled": .boolean(h.bottomBarGlowEnabled),
            "bottomBarGlowIntensity": .number(h.bottomBarGlowIntensity),
            "activeZoneWidthShare": .number(h.activeZoneWidthShare),
            "activeZoneHeightScale": .number(h.activeZoneHeightScale),
            "zoneSegmentGap": .number(h.zoneSegmentGap),
            "bottomBarCornerRadius": .number(h.bottomBarCornerRadius),
            "bottomBarBorderEnabled": .boolean(h.bottomBarBorderEnabled),
            "bottomBarBorderColor": .string(colorHex(h.bottomBarBorderColor)),
            "bottomBarBorderOpacity": .number(h.bottomBarBorderOpacity),
            "bottomBarBorderWidth": .number(h.bottomBarBorderWidth),
            "inactiveZoneOpacity": .number(h.inactiveZoneOpacity),
            "zoneMarkerEnabled": .boolean(h.zoneMarkerEnabled),
            "zoneMarkerPosition": .string(h.zoneMarkerPosition.rawValue),
            "zoneMarkerShowsValue": .boolean(h.zoneMarkerShowsValue),
            "thresholdZoneMarkerEnabled": .boolean(h.thresholdZoneMarkerEnabled),
            "foregroundColor": .string(colorHex(style.foregroundColor)),
            "labelColor": .string(colorHex(style.labelColor)),
            "unitColor": .string(colorHex(style.unitColor)),
            "dividerEnabled": .boolean(style.dividerEnabled),
            "dividerColor": .string(colorHex(style.dividerColor)),
            "dividerOpacity": .number(style.dividerOpacity),
            "dividerThickness": .number(style.dividerThickness),
            "backgroundEnabled": .boolean(style.backgroundEnabled),
            "backgroundColor": .string(colorHex(style.backgroundColor)),
            "backgroundOpacity": .number(style.backgroundOpacity),
            "backgroundRadius": .number(style.backgroundRadius),
            "backgroundPaddingX": .number(style.backgroundPaddingX),
            "backgroundPaddingY": .number(style.backgroundPaddingY),
            "borderEnabled": .boolean(style.borderEnabled),
            "borderColor": .string(colorHex(style.borderColor)),
            "borderOpacity": .number(style.borderOpacity),
            "borderWidth": .number(style.borderWidth)
        ]
        let slots = (0..<5).map { index -> String in
            guard index < h.metricSlots.count else { return "none" }
            return h.metricSlots[index].metric.rawValue
        }
        for (index, metric) in slots.enumerated() {
            values["slot\(index + 1)Metric"] = .string(metric)
        }
        let roles: [(String, IntervalHUDBarTextStyle)] = [
            ("label", h.labelText),
            ("primaryValue", h.primaryValueText),
            ("phase", h.phaseText),
            ("phaseDetail", h.phaseDetailText),
            ("metricValue", h.metricValueText),
            ("metricUnit", h.metricUnitText)
        ]
        for (prefix, text) in roles {
            values["\(prefix)FontFamily"] = .string(text.fontName)
            values["\(prefix)FontSize"] = .number(text.fontSize)
            values["\(prefix)FontWeight"] = .string(text.fontWeight.rawValue)
        }
        return values
    }

    @Test func hudBarMatchesNativeAcrossStates() throws {
        try OverlayPreferenceFixtures.withDefaults {
            let reference = try OverlayComponentReference(
                definitionData: OverlayComponentIntervalHUDBarTests.data(), source: .bundled
            )
            let activity = Self.activity()
            let canvas = CGSize(width: 1280, height: 720)
            let cases: [(String, OverlayStyle, Double, TimeInterval)] = [
                ("lap-active", Self.style(), 1, 90),
                ("lap-warmup", Self.style(), 1, 30),
                ("zones-hr", Self.style(bottomBar: .heartRateZones), 1, 90),
                ("zones-hr-warmup", Self.style(bottomBar: .heartRateZones), 1, 20),
                ("zones-pace", Self.style(bottomBar: .paceZones), 1, 95),
                ("zones-hr-wide", Self.style(bottomBar: .heartRateZones, activeWidthShare: 0.25,
                                             activeHeightScale: 1.4), 1, 90),
                ("no-bottom-bar", Self.style(bottomBar: .none), 1, 90),
                ("rest", Self.style(), 1, 150),
                ("hidden-cells", Self.style(showsRep: false, showsPhase: false,
                                            showsRemaining: false), 1, 90),
                ("three-metrics", Self.style(metrics: [.heartRate, .pace, .cadence]), 1, 90),
                ("scaled", Self.style(bottomBar: .heartRateZones), 1.5, 90),
                ("markers-below", Self.style(bottomBar: .heartRateZones,
                                             markerPosition: .below), 1, 90),
                ("marker-no-value", Self.style(bottomBar: .heartRateZones,
                                               markerShowsValue: false), 1, 90),
                ("no-markers", Self.style(bottomBar: .heartRateZones, marker: false,
                                          thresholdMarker: false), 1, 90),
                ("hr-drop-rest", Self.style(zoneDisplayMode: .hrDropAtRest,
                                            hrDropMode: .percent), 1, 150),
                ("remaining-time", Self.style(remainingPrimary: .time), 1, 90),
                ("progress-time", Self.style(progressMode: .time), 1, 90),
                ("background", Self.style(background: true), 1, 90),
                ("background-zones", Self.style(background: true, bottomBar: .heartRateZones), 1, 90)
            ]
            for (label, style, elementScale, time) in cases {
                let native = OverlayElement(type: .intervalHUDBar, position: CGPoint(x: 0.5, y: 0.5),
                                            scale: elementScale, style: style)
                let context = OverlayRenderContext(canvasSize: canvas, activity: activity, elapsedTime: time)
                let layout = OverlayRenderModel.intervalHUDBarLayout(for: native, in: context)
                let component = OverlayElement(
                    type: .component,
                    position: CGPoint(x: (layout.rect.minX - layout.backgroundPaddingX) / canvas.width,
                                      y: (layout.rect.minY - layout.backgroundPaddingY) / canvas.height),
                    scale: elementScale, style: style,
                    component: OverlayComponentInstance(reference: reference, parameters: Self.parameters(style))
                )
                let frame = try #require(OverlayComponentSkiaRenderer.frame(for: component, renderContext: context))
                #expect(abs(frame.width - (layout.rect.width + layout.backgroundPaddingX * 2)) < 0.5,
                        "\(label) width")
                #expect(abs(frame.height - (layout.rect.height + layout.backgroundPaddingY * 2)) < 0.5,
                        "\(label) height")
                let changedPixelRatio = label == "scaled" ? 0.005 : (label.hasPrefix("background") ? 0.006 : 0.0035)
                try NativeComponentParityHarness.assertParity(
                    label: "hud-\(label)", native: OverlayLayout(elements: [native]),
                    component: OverlayLayout(elements: [component]), activity: activity,
                    elapsedTime: time, size: canvas, thresholds: .init(
                        channelTolerance: 2,
                        maximumChangedPixelRatio: changedPixelRatio,
                        maximumChannelDelta: 80,
                        maximumMeanChannelDelta: 0.13
                    )
                )
            }
        }
    }
}
#endif
