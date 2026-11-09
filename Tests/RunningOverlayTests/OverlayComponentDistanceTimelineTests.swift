import Foundation
import Testing
@testable import RunningOverlay

struct OverlayComponentDistanceTimelineTests {
    static func data() throws -> Data {
        let item = try #require(OverlayComponentLibraryItem.chartComponents.first {
            $0.resourceName == "distance-timeline"
        })
        return try #require(OverlayComponentLibrary.data(for: item))
    }

    @Test func bundledDefinitionResolves() throws {
        let package = try OverlayComponentLoader.load(data: Self.data())
        let activity = OverlayComponentDistanceTimelineParityTests.activity()
        let data = OverlayComponentActivityData(
            activity: activity, elapsedTime: 90, zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720), elementScale: 1
        )
        let result = OverlayComponentResolver(definition: package.definition)
            .resolve(parameters: [:], data: data)
        #expect(result.diagnostics.isEmpty, "\(result.diagnostics)")
        #expect(package.definition.id == "studio.distance-timeline")
        #expect(!result.nodes.isEmpty)
    }
}

#if canImport(CSkiaBridge)
@Suite(.serialized, .skiaSerialized)
struct OverlayComponentDistanceTimelineParityTests {
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
        preset: DistanceTimelinePreset = .minimal,
        valueFontSize: Double = 28,
        unitSystem: DistanceTimelineUnitSystem = .metric,
        showValue: Bool = true,
        showTotalDistance: Bool = true,
        showLabel: Bool = false,
        label: String = "Distance",
        labelFontSize: Double = 12,
        labelFontWeight: OverlayFontWeight = .medium,
        labelColor: OverlayColor = .white,
        labelValueSpacing: Double = 2,
        showAxisLabels: Bool = false,
        axisLabelMode: DistanceTimelineAxisLabelMode = .startFinish,
        axisLabelOffset: Double = 14,
        axisLabelFontSize: Double = 11,
        axisEndpointPlacement: DistanceTimelineAxisLabelTrackPlacement = .below,
        axisMidpointPlacement: DistanceTimelineAxisLabelTrackPlacement = .below,
        showDistancePoints: Bool = false,
        distancePointCount: Int = 3,
        markerDistanceLabelEnabled: Bool = false,
        markerDistanceLabelPlacement: DistanceTimelineAxisLabelTrackPlacement = .above,
        markerDistanceLabelOffset: Double = 12,
        currentMarkerSizeMultiplier: Double = 1,
        backgroundEnabled: Bool = true,
        backgroundOpacity: Double = 0.70,
        borderEnabled: Bool = false,
        borderOpacity: Double = 0.18,
        cornerRadius: Double = 9,
        paddingX: Double = 14,
        paddingY: Double = 10,
        trackHeight: Double = 6,
        trackOpacity: Double = 0.24,
        fillColor: OverlayColor = .green,
        tickMarksEnabled: Bool = false,
        tickDensity: Int = 8,
        currentMarkerEnabled: Bool = false,
        currentMarkerStyle: DistanceTimelineMarkerStyle = .dot,
        currentMarkerColor: OverlayColor? = nil,
        glowEnabled: Bool = false,
        fadeEnabled: Bool = false,
        fadeEdge: DistanceTimelineFadeEdge = .right,
        fadeAmount: Double = 0.22,
        mediaSlotEnabled: Bool = false,
        mediaSlotMode: DistanceTimelineMediaSlotMode = .none,
        mediaSlotSize: Double = 30,
        elevationProfileVisible: Bool = false
    ) -> OverlayStyle {
        var style = OverlayStyle.default
        var timeline = DistanceTimelineStyle.preset(preset)
        // Attached stats bars are retired; the component and its native oracle
        // must both render the timeline alone (2026-11-09).
        timeline.statsBar.visible = false
        timeline.width = 320
        timeline.height = 68
        timeline.valueUnitSystem = unitSystem
        timeline.showValue = showValue
        timeline.showTotalDistance = showTotalDistance
        timeline.showLabel = showLabel
        timeline.label = label
        timeline.labelFontSize = labelFontSize
        timeline.labelFontWeight = labelFontWeight
        timeline.labelColor = labelColor
        timeline.labelValueSpacing = labelValueSpacing
        timeline.showAxisLabels = showAxisLabels
        timeline.axisLabelMode = axisLabelMode
        timeline.axisLabelOffset = axisLabelOffset
        timeline.axisLabelFontSize = axisLabelFontSize
        timeline.axisEndpointLabelPlacement = axisEndpointPlacement
        timeline.axisMidpointLabelPlacement = axisMidpointPlacement
        timeline.showDistancePoints = showDistancePoints
        timeline.distancePointCount = distancePointCount
        timeline.markerDistanceLabelEnabled = markerDistanceLabelEnabled
        timeline.markerDistanceLabelPlacement = markerDistanceLabelPlacement
        timeline.markerDistanceLabelOffset = markerDistanceLabelOffset
        timeline.currentMarkerSizeMultiplier = currentMarkerSizeMultiplier
        timeline.backgroundEnabled = backgroundEnabled
        timeline.backgroundOpacity = backgroundOpacity
        timeline.borderEnabled = borderEnabled
        timeline.borderOpacity = borderOpacity
        timeline.cornerRadius = cornerRadius
        timeline.paddingX = paddingX
        timeline.paddingY = paddingY
        timeline.trackHeight = trackHeight
        timeline.trackOpacity = trackOpacity
        timeline.fillColor = fillColor
        timeline.tickMarksEnabled = tickMarksEnabled
        timeline.tickDensity = tickDensity
        timeline.currentMarkerEnabled = currentMarkerEnabled
        timeline.currentMarkerStyle = currentMarkerStyle
        timeline.currentMarkerColor = currentMarkerColor ?? fillColor
        timeline.glowEnabled = glowEnabled
        timeline.fadeEnabled = fadeEnabled
        timeline.fadeEdge = fadeEdge
        timeline.fadeAmount = fadeAmount
        timeline.mediaSlotEnabled = mediaSlotEnabled
        timeline.mediaSlotMode = mediaSlotMode
        timeline.mediaSlotSize = mediaSlotSize
        timeline.elevationProfileVisible = elevationProfileVisible
        style.distanceTimeline = timeline
        style.fontSize = valueFontSize
        style.shadowEnabled = false
        style.glowEnabled = false
        style.backgroundEnabled = timeline.backgroundEnabled
        style.backgroundColor = timeline.backgroundColor
        style.backgroundOpacity = timeline.backgroundOpacity
        style.backgroundPaddingX = 0
        style.backgroundPaddingY = 0
        style.borderEnabled = timeline.borderEnabled
        style.borderColor = timeline.borderColor
        style.borderOpacity = timeline.borderOpacity
        style.borderWidth = timeline.borderWidth
        return style
    }

    private static func colorHex(_ color: OverlayColor) -> String {
        String(format: "#%02X%02X%02X",
               Int((color.red * 255).rounded()),
               Int((color.green * 255).rounded()),
               Int((color.blue * 255).rounded()))
    }

    private static func parameters(_ style: OverlayStyle) -> [String: OverlayJSONValue] {
        let t = style.distanceTimeline
        return [
            "preset": .string(t.preset.rawValue),
            "valueFontSize": .number(style.fontSize),
            "valueUnitSystem": .string(t.valueUnitSystem.rawValue),
            "showValue": .boolean(t.showValue),
            "showTotalDistance": .boolean(t.showTotalDistance),
            "showLabel": .boolean(t.showLabel),
            "label": .string(t.label),
            "labelFontFamily": .string(t.labelFontName),
            "labelFontSize": .number(t.labelFontSize),
            "labelFontWeight": .string(t.labelFontWeight.rawValue),
            "labelColor": .string(colorHex(t.labelColor)),
            "labelValueSpacing": .number(t.labelValueSpacing),
            "showAxisLabels": .boolean(t.showAxisLabels),
            "axisLabelMode": .string(t.axisLabelMode.rawValue),
            "axisLabelOffset": .number(t.axisLabelOffset),
            "axisLabelFontFamily": .string(t.axisLabelFontName),
            "axisLabelFontSize": .number(t.axisLabelFontSize),
            "axisLabelFontWeight": .string(t.axisLabelFontWeight.rawValue),
            "axisLabelColor": .string(colorHex(t.axisLabelColor)),
            "showDistancePoints": .boolean(t.showDistancePoints),
            "distancePointCount": .number(Double(t.distancePointCount)),
            "distancePointOffset": .number(t.distancePointOffset),
            "midpointAxisLabelOffset": .number(t.midpointAxisLabelOffset),
            "axisEndpointLabelPlacement": .string(t.axisEndpointLabelPlacement.rawValue),
            "axisMidpointLabelPlacement": .string(t.axisMidpointLabelPlacement.rawValue),
            "markerDistanceLabelEnabled": .boolean(t.markerDistanceLabelEnabled),
            "markerDistanceLabelPlacement": .string(t.markerDistanceLabelPlacement.rawValue),
            "markerDistanceLabelOffset": .number(t.markerDistanceLabelOffset),
            "currentMarkerSizeMultiplier": .number(t.currentMarkerSizeMultiplier),
            "backgroundEnabled": .boolean(t.backgroundEnabled),
            "backgroundColor": .string(colorHex(t.backgroundColor)),
            "backgroundOpacity": .number(t.backgroundOpacity),
            "borderEnabled": .boolean(t.borderEnabled),
            "borderColor": .string(colorHex(t.borderColor)),
            "borderOpacity": .number(t.borderOpacity),
            "borderWidth": .number(t.borderWidth),
            "cornerRadius": .number(t.cornerRadius),
            "paddingX": .number(t.paddingX),
            "paddingY": .number(t.paddingY),
            "trackHeight": .number(t.trackHeight),
            "trackOpacity": .number(t.trackOpacity),
            "fillColor": .string(colorHex(t.fillColor)),
            "tickMarksEnabled": .boolean(t.tickMarksEnabled),
            "tickDensity": .number(Double(t.tickDensity)),
            "currentMarkerEnabled": .boolean(t.currentMarkerEnabled),
            "currentMarkerStyle": .string(t.currentMarkerStyle.rawValue),
            "currentMarkerColor": .string(colorHex(t.currentMarkerColor)),
            "glowEnabled": .boolean(t.glowEnabled),
            "fadeEnabled": .boolean(t.fadeEnabled),
            "fadeEdge": .string(t.fadeEdge.rawValue),
            "fadeAmount": .number(t.fadeAmount),
            "mediaSlotEnabled": .boolean(t.mediaSlotEnabled),
            "mediaSlotMode": .string(t.mediaSlotMode.rawValue),
            "mediaSystemImage": .string(t.mediaSystemImage),
            "mediaSlotSize": .number(t.mediaSlotSize),
            "elevationProfileVisible": .boolean(t.elevationProfileVisible)
        ]
    }

    @Test func contentBoundsTrackTimelineAndVisibleLabels() throws {
        let reference = try OverlayComponentReference(
            definitionData: OverlayComponentDistanceTimelineTests.data(), source: .bundled
        )
        let context = OverlayRenderContext(
            canvasSize: CGSize(width: 1280, height: 720),
            activity: Self.activity(),
            elapsedTime: 90
        )
        func frame(_ parameters: [String: OverlayJSONValue]) throws -> CGRect {
            let element = OverlayElement(
                type: .component,
                position: CGPoint(x: 0.1, y: 0.1),
                scale: 1,
                style: .default,
                component: OverlayComponentInstance(
                    reference: reference,
                    parameters: parameters
                )
            )
            return try #require(OverlayComponentSkiaRenderer.frame(
                for: element,
                renderContext: context
            ))
        }

        // The retired attached Stats Bar used to reserve 460x150 regardless of
        // the timeline's own size. Bounds now follow the node frame and only
        // grow for labels that actually draw outside it.
        let plain = try frame([:])
        #expect(abs(plain.width - 360) < 0.001)
        #expect(abs(plain.height - 92) < 0.001)

        let wide = try frame(["timelineWidth": .number(500)])
        #expect(abs(wide.width - 540) < 0.001)

        let labeled = try frame([
            "showAxisLabels": .boolean(true),
            "axisEndpointLabelPlacement": .string("below"),
            "distancePointOffset": .number(14),
            "axisLabelFontSize": .number(11),
            "paddingY": .number(10)
        ])
        #expect(abs(labeled.height - (92 + 18.3)) < 0.001)
    }

    @Test func distanceTimelineMatchesNative() throws {
        try OverlayPreferenceFixtures.withDefaults {
            let reference = try OverlayComponentReference(
                definitionData: OverlayComponentDistanceTimelineTests.data(), source: .bundled
            )
            let activity = Self.activity()
            let canvas = CGSize(width: 1280, height: 720)
            let cases: [(String, OverlayStyle, Double, TimeInterval)] = [
                ("default", Self.style(), 1, 90),
                ("dense", Self.style(preset: .dense), 1, 90),
                ("sport", Self.style(preset: .sport), 1, 90),
                ("splits", Self.style(preset: .splits), 1, 90),
                ("route", Self.style(preset: .route), 1, 90),
                ("axis-labels", Self.style(showAxisLabels: true, showDistancePoints: true), 1, 90),
                ("marker", Self.style(currentMarkerEnabled: true, currentMarkerStyle: .triangle), 1, 90),
                ("marker-label", Self.style(markerDistanceLabelEnabled: true,
                                            markerDistanceLabelPlacement: .below,
                                            currentMarkerEnabled: true), 1, 90),
                ("ticks", Self.style(tickMarksEnabled: true, tickDensity: 16), 1, 90),
                ("label", Self.style(showLabel: true, label: "DISTANCE"), 1, 90),
                ("no-background", Self.style(backgroundEnabled: false), 1, 90),
                ("imperial", Self.style(unitSystem: .imperial), 1, 90),
                ("crop-value", Self.style(showTotalDistance: false), 1, 90),
                ("fade", Self.style(fadeEnabled: true, fadeEdge: .both, fadeAmount: 0.4), 1, 90),
                ("scaled", Self.style(), 1.5, 90),
                ("late", Self.style(preset: .dense, showAxisLabels: true), 1, 540)
            ]
            for (label, style, elementScale, time) in cases {
                let native = OverlayElement(
                    type: .distanceTimeline, position: CGPoint(x: 0.5, y: 0.5),
                    scale: elementScale, style: style
                )
                let context = OverlayRenderContext(
                    canvasSize: canvas, activity: activity, elapsedTime: time
                )
                let layout = OverlayRenderModel.distanceTimelineLayout(for: native, in: context)
                // The definition reserves 16x24 design units above/left of the
                // track so axis labels drawn outside the track rect are not
                // clipped; align the component origin so the track lands on
                // the native rect.
                let component = OverlayElement(
                    type: .component,
                    position: CGPoint(
                        x: (layout.rect.minX - 16 * elementScale) / canvas.width,
                        y: (layout.rect.minY - 24 * elementScale) / canvas.height
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
                    label: "distance-\(label)",
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
