import Foundation
import Testing
@testable import RunningOverlay

struct OverlayComponentZoneEdgeBarTests {
    static func data() throws -> Data {
        let item = try #require(OverlayComponentLibraryItem.intervalComponents.first {
            $0.resourceName == "zone-edge-bar"
        })
        return try #require(OverlayComponentLibrary.data(for: item))
    }

    @Test func bundledDefinitionResolvesZones() throws {
        let package = try OverlayComponentLoader.load(data: Self.data())
        let start = Date(timeIntervalSince1970: 1_735_689_600)
        let activity = ActivityTimeline(
            startDate: start, duration: 120, distanceMeters: 600,
            records: (0...120).map { t in
                ActivityRecord(
                    elapsedTime: Double(t), timestamp: start.addingTimeInterval(Double(t)),
                    distanceMeters: Double(t) * 5, heartRate: 150,
                    paceSecondsPerKilometer: 300, elevationMeters: 20,
                    cadence: 176, powerWatts: 240, calories: Double(t) / 4
                )
            },
            laps: []
        )
        let data = OverlayComponentActivityData(
            activity: activity, elapsedTime: 60, zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720), elementScale: 1
        )
        let result = OverlayComponentResolver(definition: package.definition)
            .resolve(parameters: [:], data: data)
        #expect(result.diagnostics.isEmpty, "\(result.diagnostics)")
        #expect(package.definition.id == "studio.zone-edge-bar")
        #expect(!result.nodes.isEmpty)
    }
}

#if canImport(CSkiaBridge)
@Suite(.serialized, .skiaSerialized)
struct OverlayComponentZoneEdgeBarParityTests {
    private static func activity() -> ActivityTimeline {
        let start = Date(timeIntervalSince1970: 1_735_689_600)
        var records: [ActivityRecord] = []
        var t: TimeInterval = 0
        while t <= 180 {
            records.append(ActivityRecord(
                elapsedTime: t, timestamp: start.addingTimeInterval(t),
                distanceMeters: t * 3.6, heartRate: 150,
                paceSecondsPerKilometer: 300, elevationMeters: 20,
                cadence: 176, powerWatts: 240, calories: t / 4
            ))
            t += 1
        }
        return ActivityTimeline(
            startDate: start, duration: 180, distanceMeters: 648, records: records, laps: []
        )
    }

    private static func style(
        metric: ZoneEdgeBarMetric = .heartRate,
        placement: ZoneEdgeBarPlacement = .free,
        edge: ZoneEdgeBarEdge = .bottom,
        orientation: ZoneEdgeBarOrientation = .horizontal,
        activeWidthShare: Double = 0,
        activeHeightScale: Double = 1,
        segmentGap: Double = 2,
        cornerRadius: Double = 5,
        inactiveOpacity: Double = 0.55,
        border: Bool = true,
        glow: Bool = false,
        glowIntensity: Double = 0.45,
        marker: Bool = true,
        markerShowsValue: Bool = true,
        markerSizeScale: Double = 1,
        threshold: Bool = true,
        thresholdSizeScale: Double = 1
    ) -> OverlayStyle {
        var style = OverlayStyle.default
        style.zoneEdgeBar = ZoneEdgeBarStyle(
            metric: metric,
            placement: placement,
            edge: edge,
            orientation: orientation,
            length: 780,
            thickness: 10,
            edgeInset: 24,
            activeZoneWidthShare: activeWidthShare,
            activeZoneHeightScale: activeHeightScale,
            zoneSegmentGap: segmentGap,
            cornerRadius: cornerRadius,
            inactiveZoneOpacity: inactiveOpacity,
            borderEnabled: border,
            borderColor: .white,
            borderOpacity: 0.12,
            borderWidth: 1,
            glowEnabled: glow,
            glowIntensity: glowIntensity,
            markerEnabled: marker,
            markerShowsValue: markerShowsValue,
            markerSizeScale: markerSizeScale,
            thresholdMarkerEnabled: threshold,
            thresholdMarkerSizeScale: thresholdSizeScale,
            markerText: IntervalHUDBarTextStyle(
                fontName: "Menlo", fontSize: 12, fontWeight: .semibold
            )
        )
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

    private static func parameters(
        _ style: OverlayStyle,
        orientation: ZoneEdgeBarOrientation,
        markerSide: ZoneEdgeBarMarkerSide
    ) -> [String: OverlayJSONValue] {
        let bar = style.zoneEdgeBar
        let side: String
        switch markerSide {
        case .above: side = "above"
        case .below: side = "below"
        case .leading: side = "leading"
        case .trailing: side = "trailing"
        }
        return [
            "metric": .string(bar.metric.rawValue),
            "orientation": .string(orientation == .horizontal ? "horizontal" : "vertical"),
            "markerSide": .string(side),
            "length": .number(bar.length),
            "thickness": .number(bar.thickness),
            "activeZoneWidthShare": .number(bar.activeZoneWidthShare),
            "activeZoneHeightScale": .number(bar.activeZoneHeightScale),
            "zoneSegmentGap": .number(bar.zoneSegmentGap),
            "cornerRadius": .number(bar.cornerRadius),
            "inactiveZoneOpacity": .number(bar.inactiveZoneOpacity),
            "borderEnabled": .boolean(bar.borderEnabled),
            "borderColor": .string(colorHex(bar.borderColor)),
            "borderOpacity": .number(bar.borderOpacity),
            "borderWidth": .number(bar.borderWidth),
            "glowEnabled": .boolean(bar.glowEnabled),
            "glowIntensity": .number(bar.glowIntensity),
            "markerEnabled": .boolean(bar.markerEnabled),
            "markerShowsValue": .boolean(bar.markerShowsValue),
            "markerSizeScale": .number(bar.markerSizeScale),
            "thresholdMarkerEnabled": .boolean(bar.thresholdMarkerEnabled),
            "thresholdMarkerSizeScale": .number(bar.thresholdMarkerSizeScale),
            "fontFamily": .string(bar.markerText.fontName),
            "fontSize": .number(bar.markerText.fontSize),
            "fontWeight": .string(bar.markerText.fontWeight.rawValue)
        ]
    }

    @Test func zoneEdgeBarMatchesNative() throws {
        try OverlayPreferenceFixtures.withDefaults {
            let reference = try OverlayComponentReference(
                definitionData: OverlayComponentZoneEdgeBarTests.data(), source: .bundled
            )
            let activity = Self.activity()
            let canvas = CGSize(width: 1280, height: 720)
            let cases: [(String, OverlayStyle, Double, TimeInterval)] = [
                ("hr-free-above", Self.style(), 1, 90),
                ("hr-free-below", Self.style(placement: .free, edge: .bottom), 1, 90),
                ("hr-edge-bottom", Self.style(placement: .edge, edge: .bottom), 1, 90),
                ("hr-edge-top", Self.style(placement: .edge, edge: .top), 1, 90),
                ("pace-free-above", Self.style(metric: .pace), 1, 90),
                ("vertical-free-trailing", Self.style(orientation: .vertical), 1, 90),
                ("vertical-edge-left", Self.style(placement: .edge, edge: .left), 1, 90),
                ("vertical-edge-right", Self.style(placement: .edge, edge: .right), 1, 90),
                ("wide", Self.style(activeWidthShare: 0.3, activeHeightScale: 1.6,
                                    segmentGap: 4), 1, 90),
                ("no-border", Self.style(border: false), 1, 90),
                ("glow", Self.style(glow: true, glowIntensity: 0.5), 1, 90),
                ("marker-no-value", Self.style(markerShowsValue: false), 1, 90),
                ("marker-scaled", Self.style(markerSizeScale: 1.8, thresholdSizeScale: 0.7), 1, 90),
                ("scaled", Self.style(), 1.5, 90),
                ("inactive-low", Self.style(inactiveOpacity: 0.3), 1, 90),
                ("corner-zero", Self.style(cornerRadius: 0), 1, 90)
            ]
            for (label, style, elementScale, time) in cases {
                let native = OverlayElement(
                    type: .zoneEdgeBar, position: CGPoint(x: 0.5, y: 0.5),
                    scale: elementScale, style: style
                )
                let context = OverlayRenderContext(
                    canvasSize: canvas, activity: activity, elapsedTime: time
                )
                let layout = OverlayRenderModel.zoneEdgeBarLayout(for: native, in: context)
                let margin = 64 * elementScale
                let component = OverlayElement(
                    type: .component,
                    position: CGPoint(
                        x: (layout.rect.minX - margin) / canvas.width,
                        y: (layout.rect.minY - margin) / canvas.height
                    ),
                    scale: elementScale,
                    style: style,
                    component: OverlayComponentInstance(
                        reference: reference,
                        parameters: Self.parameters(
                            style,
                            orientation: layout.orientation,
                            markerSide: layout.markerSide
                        )
                    )
                )
                let frame = try #require(
                    OverlayComponentSkiaRenderer.frame(for: component, renderContext: context)
                )
                #expect(abs(frame.width - (layout.rect.width + margin * 2)) < 0.5,
                        "\(label) width")
                #expect(abs(frame.height - (layout.rect.height + margin * 2)) < 0.5,
                        "\(label) height")
                let ratio = label == "scaled" ? 0.005 : 0.0035
                try NativeComponentParityHarness.assertParity(
                    label: "zone-edge-\(label)",
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
