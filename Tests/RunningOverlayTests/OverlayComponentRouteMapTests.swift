import Foundation
import Testing
@testable import RunningOverlay

struct OverlayComponentRouteMapTests {
    static func data() throws -> Data {
        let item = try #require(OverlayComponentLibraryItem.chartComponents.first {
            $0.resourceName == "route-map"
        })
        return try #require(OverlayComponentLibrary.data(for: item))
    }

    @Test func bundledDefinitionResolves() throws {
        let package = try OverlayComponentLoader.load(data: Self.data())
        let activity = OverlayComponentRouteMapParityTests.activity()
        let data = OverlayComponentActivityData(
            activity: activity, elapsedTime: 90, zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720), elementScale: 1
        )
        let result = OverlayComponentResolver(definition: package.definition)
            .resolve(parameters: [:], data: data)
        #expect(result.diagnostics.isEmpty, "\(result.diagnostics)")
        #expect(package.definition.id == "studio.route-map")
        #expect(!result.nodes.isEmpty)
    }
}

#if canImport(CSkiaBridge)
@Suite(.serialized, .skiaSerialized)
struct OverlayComponentRouteMapParityTests {
    static func activity() -> ActivityTimeline {
        let start = Date(timeIntervalSince1970: 1_735_689_600)
        var records: [ActivityRecord] = []
        var t: TimeInterval = 0
        while t <= 600 {
            let phase = t / 600
            records.append(ActivityRecord(
                elapsedTime: t, timestamp: start.addingTimeInterval(t),
                distanceMeters: t * 3.2, heartRate: 148 + Int(t / 120),
                paceSecondsPerKilometer: 312, elevationMeters: 20 + sin(t / 90) * 6,
                cadence: 176, powerWatts: 245, calories: t / 4,
                latitude: 31.2304 + phase * 0.012 + sin(phase * 6) * 0.003,
                longitude: 121.4737 + phase * 0.008 + cos(phase * 5) * 0.002
            ))
            t += 5
        }
        return ActivityTimeline(
            startDate: start, duration: 600, distanceMeters: 1920,
            records: records, laps: []
        )
    }

    private static func style(
        shape: OverlayRouteMapShape = .square,
        backgroundStyle: OverlayRouteMapBackgroundStyle = .dark,
        cornerRadius: Double = 12,
        startMarkerStyle: OverlayRouteMapMarkerStyle = .dot,
        endMarkerStyle: OverlayRouteMapMarkerStyle = .dot,
        runnerMarkerStyle: OverlayRouteMapMarkerStyle = .dot,
        borderEnabled: Bool = true,
        borderOpacity: Double = 0.18
    ) -> OverlayStyle {
        var style = OverlayStyle.default
        style.routeMapShape = shape
        style.routeMapBackgroundStyle = backgroundStyle
        style.routeMapCornerRadius = cornerRadius
        style.backgroundRadius = cornerRadius
        style.backgroundEnabled = backgroundStyle != .none
        style.backgroundPaddingX = 0
        style.backgroundPaddingY = 0
        style.routeMapWidth = 320
        style.routeMapHeight = 320
        style.routeMapStartMarkerStyle = startMarkerStyle
        style.routeMapEndMarkerStyle = endMarkerStyle
        style.routeMapRunnerMarkerStyle = runnerMarkerStyle
        style.routeMapStartMarkerColor = .white
        style.routeMapEndMarkerColor = .white
        style.routeMapRunnerDotColor = .orange
        style.routeMapMapOpacity = 0.72
        style.glowEnabled = false
        style.shadowEnabled = false
        style.borderEnabled = borderEnabled
        style.borderColor = .white
        style.borderOpacity = borderOpacity
        style.foregroundColor = .white
        style.fontName = FontLibraryManager.currentDefaultFamily
        return style
    }

    private static func colorHex(_ color: OverlayColor) -> String {
        String(format: "#%02X%02X%02X",
               Int((color.red * 255).rounded()),
               Int((color.green * 255).rounded()),
               Int((color.blue * 255).rounded()))
    }

    private static func parameters(_ style: OverlayStyle) -> [String: OverlayJSONValue] {
        [
            "shape": .string(style.routeMapShape.rawValue),
            "backgroundStyle": .string(style.routeMapBackgroundStyle.rawValue),
            "cornerRadius": .number(style.routeMapCornerRadius),
            "backgroundOpacity": .number(style.backgroundOpacity),
            "startMarkerStyle": .string(style.routeMapStartMarkerStyle.rawValue),
            "endMarkerStyle": .string(style.routeMapEndMarkerStyle.rawValue),
            "runnerMarkerStyle": .string(style.routeMapRunnerMarkerStyle.rawValue),
            "startMarkerColor": .string(colorHex(style.routeMapStartMarkerColor)),
            "endMarkerColor": .string(colorHex(style.routeMapEndMarkerColor)),
            "runnerMarkerColor": .string(colorHex(style.routeMapRunnerDotColor)),
            "glowEnabled": .boolean(style.glowEnabled),
            "mapOpacity": .number(style.routeMapMapOpacity),
            "borderEnabled": .boolean(style.borderEnabled),
            "borderOpacity": .number(style.borderOpacity),
            "foregroundColor": .string(colorHex(style.foregroundColor)),
            "fontFamily": .string(style.fontName)
        ]
    }

    @Test func routeMapMatchesNative() throws {
        try OverlayPreferenceFixtures.withDefaults {
            let reference = try OverlayComponentReference(
                definitionData: OverlayComponentRouteMapTests.data(), source: .bundled
            )
            let activity = Self.activity()
            let canvas = CGSize(width: 1280, height: 720)
            let cases: [(String, OverlayStyle, Double, TimeInterval)] = [
                ("square", Self.style(), 1, 90),
                ("circle", Self.style(shape: .circle, cornerRadius: 0), 1, 90),
                ("hidden-markers", Self.style(startMarkerStyle: .hidden,
                                              endMarkerStyle: .hidden,
                                              runnerMarkerStyle: .hidden), 1, 90),
                ("no-border", Self.style(borderEnabled: false), 1, 90),
                ("no-background", Self.style(backgroundStyle: .none), 1, 90),
                ("rounded", Self.style(cornerRadius: 40), 1, 90),
                ("scaled", Self.style(), 1.5, 90),
                ("late", Self.style(shape: .circle, cornerRadius: 0), 1, 540)
            ]
            for (label, style, elementScale, time) in cases {
                let native = OverlayElement(
                    type: .routeMap, position: CGPoint(x: 0.5, y: 0.5),
                    scale: elementScale, style: style
                )
                let context = OverlayRenderContext(
                    canvasSize: canvas, activity: activity, elapsedTime: time
                )
                let layout = OverlayRenderModel.routeMapLayout(for: native, in: context)
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
                    label: "route-\\(label)",
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
