import Foundation
import Testing
@testable import RunningOverlay

struct OverlayComponentIntervalTimelineTests {
    static func data() throws -> Data {
        let item = try #require(OverlayComponentLibraryItem.intervalComponents.first {
            $0.resourceName == "interval-timeline"
        })
        return try #require(OverlayComponentLibrary.data(for: item))
    }

    @Test func bundledDefinitionResolvesLaps() throws {
        let package = try OverlayComponentLoader.load(data: Self.data())
        let activity = OverlayComponentIntervalTimelineParityTests.activity()
        let data = OverlayComponentActivityData(
            activity: activity, elapsedTime: 90, zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720), elementScale: 1
        )
        let result = OverlayComponentResolver(definition: package.definition)
            .resolve(parameters: [:], data: data)
        #expect(result.diagnostics.isEmpty, "\(result.diagnostics)")
        #expect(package.definition.id == "studio.interval-timeline")
        #expect(!result.nodes.isEmpty)
    }
}

#if canImport(CSkiaBridge)
@Suite(.serialized, .skiaSerialized)
struct OverlayComponentIntervalTimelineParityTests {
    static func activity() -> ActivityTimeline {
        let start = Date(timeIntervalSince1970: 1_735_689_600)
        let specs: [(LapKind, TimeInterval, Int, Double)] = [
            (.warmup, 60, 130, 340),
            (.active, 60, 176, 240), (.rest, 45, 145, 420),
            (.active, 60, 178, 235), (.rest, 45, 147, 430),
            (.active, 60, 180, 232), (.rest, 45, 149, 440),
            (.cooldown, 60, 140, 360)
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
                    distanceMeters: distance + lapDistance * (t - elapsed) / spec.1,
                    heartRate: spec.2, paceSecondsPerKilometer: spec.3,
                    elevationMeters: 20, cadence: 176, powerWatts: 240, calories: t / 4
                ))
                t += 1
            }
            elapsed += spec.1
            distance += lapDistance
        }
        return ActivityTimeline(
            startDate: start, duration: elapsed, distanceMeters: distance,
            records: records, laps: laps
        )
    }

    private static func style(
        mode: IntervalTimelineMode = .centeredWindow,
        visibleNeighbors: Int = 3,
        fullLayout: IntervalTimelineFullSegmentLayoutMode = .equal,
        showsWarmup: Bool = true,
        showsRest: Bool = true,
        showsCooldown: Bool = true,
        segmentHeight: Double = 30,
        currentHeightScale: Double = 1.35,
        currentWidth: Double = 0.28,
        fullCurrentWidth: Double = 0,
        minWidth: Double = 54,
        gap: Double = 4,
        radius: Double = 6,
        progress: Bool = true,
        marker: Bool = true,
        markerLabel: Bool = true,
        markerPosition: IntervalTimelineMarkerPosition = .liveProgress,
        markerText: String = "",
        currentWorkDistance: IntervalTimelineCurrentLabelMetricMode = .elapsed,
        currentWorkTime: IntervalTimelineCurrentLabelMetricMode = .remaining,
        restKind: Bool = true,
        currentRestDistance: IntervalTimelineCurrentLabelMetricMode = .hidden,
        currentRestTime: IntervalTimelineCurrentLabelMetricMode = .remaining,
        neighbor: IntervalTimelineNeighborLabelMode = .distance,
        repCounter: Bool = true,
        overflowHint: Bool = true,
        completedOpacity: Double = 0.45,
        futureOpacity: Double = 0.32,
        background: Bool = false,
        border: Bool = false
    ) -> OverlayStyle {
        var style = OverlayStyle.default
        let palette = IntervalKindColorPreferences.currentSnapshot()
        style.intervalTimeline = IntervalTimelineStyle(
            width: 780,
            height: 64,
            mode: mode,
            visibleNeighbors: visibleNeighbors,
            fullSegmentLayoutMode: fullLayout,
            showsRestSegments: showsRest,
            showsWarmupSegments: showsWarmup,
            showsCooldownSegments: showsCooldown,
            segmentHeight: segmentHeight,
            currentSegmentHeightScale: currentHeightScale,
            currentSegmentWidthFraction: currentWidth,
            fullEqualCurrentSegmentWidthFraction: fullCurrentWidth,
            minSegmentWidth: minWidth,
            segmentGap: gap,
            segmentCornerRadius: radius,
            edgeFadeEnabled: false,
            currentProgressEnabled: progress,
            markerEnabled: marker,
            markerLabelEnabled: markerLabel,
            markerLabel: markerText,
            markerPosition: markerPosition,
            markerColor: .white,
            markerFontSize: 11,
            markerFontWeight: .bold,
            markerFontName: "Menlo",
            currentWorkDistanceLabelMode: currentWorkDistance,
            currentWorkTimeLabelMode: currentWorkTime,
            currentRestKindLabelEnabled: restKind,
            currentRestDistanceLabelMode: currentRestDistance,
            currentRestTimeLabelMode: currentRestTime,
            neighborLabelMode: neighbor,
            repCounterEnabled: repCounter,
            overflowHintEnabled: overflowHint,
            warmupColor: palette.warmup,
            activeColor: palette.active,
            restColor: palette.rest,
            cooldownColor: palette.cooldown,
            unknownColor: OverlayColor(red: 0.38, green: 0.44, blue: 0.52, alpha: 1),
            completedOpacity: completedOpacity,
            futureOpacity: futureOpacity
        )
        style.fontName = "Menlo"
        style.foregroundColor = .white
        style.shadowEnabled = false
        style.glowEnabled = false
        style.backgroundEnabled = background
        if background {
            style.backgroundColor = OverlayColor(red: 0.04, green: 0.07, blue: 0.12, alpha: 1)
            style.backgroundOpacity = 0.82
            style.backgroundRadius = 18
            style.backgroundPaddingX = 12
            style.backgroundPaddingY = 10
        }
        style.borderEnabled = border
        if border {
            style.borderColor = .white
            style.borderOpacity = 0.3
            style.borderWidth = 2
        }
        return style
    }

    private static func colorHex(_ color: OverlayColor) -> String {
        String(format: "#%02X%02X%02X",
               Int((color.red * 255).rounded()),
               Int((color.green * 255).rounded()),
               Int((color.blue * 255).rounded()))
    }

    private static func parameters(_ style: OverlayStyle) -> [String: OverlayJSONValue] {
        let timeline = style.intervalTimeline
        return [
            "railWidth": .number(timeline.width),
            "segmentAreaHeight": .number(timeline.height),
            "mode": .string(timeline.mode == .centeredWindow ? "centered" : "full"),
            "visibleNeighbors": .number(Double(timeline.visibleNeighbors)),
            "fullLayout": .string(timeline.fullSegmentLayoutMode.rawValue),
            "showsWarmup": .boolean(timeline.showsWarmupSegments),
            "showsRest": .boolean(timeline.showsRestSegments),
            "showsCooldown": .boolean(timeline.showsCooldownSegments),
            "overflowHintEnabled": .boolean(timeline.overflowHintEnabled),
            "segmentGap": .number(timeline.segmentGap),
            "cornerRadius": .number(timeline.segmentCornerRadius),
            "segmentHeight": .number(timeline.segmentHeight),
            "currentSegmentHeightScale": .number(timeline.currentSegmentHeightScale),
            "currentSegmentWidthFraction": .number(timeline.currentSegmentWidthFraction),
            "fullEqualCurrentSegmentWidthFraction": .number(timeline.fullEqualCurrentSegmentWidthFraction),
            "minSegmentWidth": .number(timeline.minSegmentWidth),
            "currentProgressEnabled": .boolean(timeline.currentProgressEnabled),
            "repCounterEnabled": .boolean(timeline.repCounterEnabled),
            "markerEnabled": .boolean(timeline.markerEnabled),
            "markerLabelEnabled": .boolean(timeline.markerLabelEnabled),
            "markerLabel": .string(timeline.markerLabel),
            "markerPosition": .string(timeline.markerPosition.rawValue),
            "markerColor": .string(colorHex(timeline.markerColor)),
            "markerFontSize": .number(timeline.markerFontSize),
            "markerFontWeight": .string(timeline.markerFontWeight.rawValue),
            "markerFontFamily": .string(timeline.markerFontName),
            "fontFamily": .string(style.fontName),
            "currentWorkDistance": .string(timeline.currentWorkDistanceLabelMode.rawValue),
            "currentWorkTime": .string(timeline.currentWorkTimeLabelMode.rawValue),
            "currentRestKindEnabled": .boolean(timeline.currentRestKindLabelEnabled),
            "currentRestDistance": .string(timeline.currentRestDistanceLabelMode.rawValue),
            "currentRestTime": .string(timeline.currentRestTimeLabelMode.rawValue),
            "neighborLabel": .string(timeline.neighborLabelMode.rawValue),
            "completedOpacity": .number(timeline.completedOpacity),
            "futureOpacity": .number(timeline.futureOpacity),
            "warmupColor": .string(colorHex(timeline.warmupColor)),
            "activeColor": .string(colorHex(timeline.activeColor)),
            "restColor": .string(colorHex(timeline.restColor)),
            "cooldownColor": .string(colorHex(timeline.cooldownColor)),
            "unknownColor": .string(colorHex(timeline.unknownColor)),
            "foregroundColor": .string(colorHex(style.foregroundColor)),
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
    }

    @Test func intervalTimelineMatchesNative() throws {
        try OverlayPreferenceFixtures.withDefaults {
            let reference = try OverlayComponentReference(
                definitionData: OverlayComponentIntervalTimelineTests.data(), source: .bundled
            )
            let activity = Self.activity()
            let canvas = CGSize(width: 1280, height: 720)
            let cases: [(String, OverlayStyle, Double, TimeInterval)] = [
                ("centered", Self.style(), 1, 90),
                ("centered-warmup", Self.style(), 1, 20),
                ("centered-rest", Self.style(), 1, 75),
                ("full-equal", Self.style(mode: .fullSchedule), 1, 90),
                ("full-duration", Self.style(mode: .fullSchedule, fullLayout: .duration), 1, 90),
                ("full-current-width", Self.style(mode: .fullSchedule, fullCurrentWidth: 0.2), 1, 90),
                ("neighbors-hidden", Self.style(neighbor: .hidden), 1, 90),
                ("neighbors-time", Self.style(neighbor: .time), 1, 90),
                ("rest-kind-off", Self.style(restKind: false, currentRestDistance: .remaining,
                                             currentRestTime: .elapsed), 1, 75),
                ("work-earlier", Self.style(currentWorkDistance: .remaining,
                                            currentWorkTime: .elapsed), 1, 90),
                ("work-hidden", Self.style(currentWorkDistance: .hidden,
                                           currentWorkTime: .hidden), 1, 90),
                ("marker-center", Self.style(markerPosition: .segmentCenter), 1, 90),
                ("marker-text", Self.style(markerText: "LIVE"), 1, 90),
                ("marker-no-label", Self.style(markerLabel: false), 1, 90),
                ("no-marker", Self.style(progress: false, marker: false), 1, 90),
                ("no-overflow", Self.style(overflowHint: false), 1, 90),
                ("no-rep", Self.style(repCounter: false), 1, 90),
                ("filtered", Self.style(showsWarmup: false, showsCooldown: false), 1, 90),
                ("wide-current", Self.style(currentHeightScale: 1.6, currentWidth: 0.4,
                                            minWidth: 64, gap: 8), 1, 90),
                ("scaled", Self.style(), 1.5, 90),
                ("background", Self.style(background: true, border: true), 1, 90)
            ]
            for (label, style, elementScale, time) in cases {
                let native = OverlayElement(
                    type: .intervalTimeline, position: CGPoint(x: 0.5, y: 0.5),
                    scale: elementScale, style: style
                )
                let context = OverlayRenderContext(
                    canvasSize: canvas, activity: activity, elapsedTime: time
                )
                let layout = OverlayRenderModel.intervalTimelineLayout(for: native, in: context)
                let padX = style.backgroundEnabled ? style.backgroundPaddingX * elementScale : 0
                let padY = style.backgroundEnabled ? style.backgroundPaddingY * elementScale : 0
                let component = OverlayElement(
                    type: .component,
                    position: CGPoint(
                        x: (layout.rect.minX - padX) / canvas.width,
                        y: (layout.rect.minY - padY) / canvas.height
                    ),
                    scale: elementScale,
                    style: style,
                    component: OverlayComponentInstance(
                        reference: reference,
                        parameters: Self.parameters(style)
                    )
                )
                let frame = try #require(
                    OverlayComponentSkiaRenderer.frame(for: component, renderContext: context)
                )
                #expect(abs(frame.width - (layout.rect.width + padX * 2)) < 0.5,
                        "\(label) width")
                #expect(abs(frame.height - (layout.rect.height + padY * 2)) < 0.5,
                        "\(label) height")
                let ratio = label == "scaled" ? 0.005 : 0.0035
                try NativeComponentParityHarness.assertParity(
                    label: "timeline-\(label)",
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
