import Foundation
import Testing
@testable import RunningOverlay

struct OverlayComponentIntervalCountdownTests {
    static func data() throws -> Data {
        let item = try #require(OverlayComponentLibraryItem.intervalComponents.first)
        return try #require(OverlayComponentLibrary.data(for: item))
    }

    @Test func bundledDefinitionResolvesWithSegmentData() throws {
        let package = try OverlayComponentLoader.load(data: Self.data())
        let activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 1_735_689_600),
            duration: 60, distanceMeters: 200,
            records: (0...60).map { t in
                ActivityRecord(
                    elapsedTime: Double(t), timestamp: Date(timeIntervalSince1970: 1_735_689_600 + Double(t)),
                    distanceMeters: Double(t) * 3.3, heartRate: 150,
                    paceSecondsPerKilometer: 300, elevationMeters: 20,
                    cadence: 176, powerWatts: 240, calories: Double(t) / 4
                )
            },
            laps: [LapRecord(
                lapIndex: 0, startElapsedTime: 0, endElapsedTime: 60,
                startDistanceMeters: 0, totalDistanceMeters: 198,
                totalElapsedTime: 60, avgPaceSecondsPerKm: 300,
                avgHeartRate: 150, maxHeartRate: 155, avgCadenceSPM: 176,
                avgPowerWatts: 240, totalAscent: nil, kind: .active
            )]
        )
        let data = OverlayComponentActivityData(
            activity: activity, elapsedTime: 30, zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720), elementScale: 1
        )
        let result = OverlayComponentResolver(definition: package.definition)
            .resolve(parameters: [:], data: data)
        #expect(result.diagnostics.isEmpty)
        #expect(!result.nodes.isEmpty)
        #expect(package.definition.id == "studio.interval-countdown")
    }
}

#if canImport(CSkiaBridge)
@Suite(.serialized, .skiaSerialized)
struct OverlayComponentIntervalCountdownParityTests {
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
        direction: IntervalCountdownRingDirection = .clockwise,
        metric: IntervalCountdownCenterMetric = .time,
        value: IntervalCountdownValueDirection = .remaining,
        background: Bool = false,
        hiddenHelper: Bool = false,
        hiddenCaption: Bool = false,
        shadow: Bool = false,
        glow: Bool = false,
        ringGlow: Bool = false
    ) -> OverlayStyle {
        var style = OverlayStyle.default
        style.intervalCountdown.size = 344
        style.intervalCountdown.ringWidth = 18
        style.intervalCountdown.trackColor = OverlayColor(red: 0.16, green: 0.19, blue: 0.21, alpha: 1)
        style.intervalCountdown.fillColorMode = .customColor
        style.intervalCountdown.fillCustomColor = OverlayColor(red: 0.25, green: 0.82, blue: 0.38, alpha: 1)
        style.intervalCountdown.ringDirection = direction
        style.intervalCountdown.centerMetric = metric
        style.intervalCountdown.centerValueDirection = value
        style.intervalCountdown.ringGlowEnabled = ringGlow
        style.intervalCountdown.roundedLineCap = true
        for role in IntervalCountdownTextRole.allCases {
            var text = IntervalCountdownTextStyle.defaultFor(role: role)
            text.fontName = "Menlo"
            style.intervalCountdown.setTextStyle(text, for: role)
        }
        if hiddenHelper { style.intervalCountdown.helperText.isVisible = false }
        if hiddenCaption { style.intervalCountdown.captionText.isVisible = false }
        style.backgroundEnabled = background
        if background {
            style.backgroundColor = OverlayColor(red: 0.04, green: 0.07, blue: 0.12, alpha: 1)
            style.backgroundOpacity = 0.82
            style.backgroundPaddingX = 10
            style.backgroundPaddingY = 6
            style.backgroundRadius = 24
            style.borderEnabled = true
            style.borderColor = .white
            style.borderOpacity = 0.3
            style.borderWidth = 2
        }
        style.borderEnabled = background
        style.shadowEnabled = shadow
        if shadow {
            style.shadowOpacity = 0.35
            style.shadowRadius = 6
            style.shadowOffsetY = 2
            style.shadowThickness = 2.5
        }
        style.glowEnabled = glow
        if glow {
            style.glowIntensity = 0.6
            style.glowColor = OverlayColor(red: 0.25, green: 0.82, blue: 0.38, alpha: 1)
        }
        return style
    }

    private static func parameters(_ style: OverlayStyle) -> [String: OverlayJSONValue] {
        let s = style.intervalCountdown
        var values: [String: OverlayJSONValue] = [
            "size": .number(s.size), "centerMetric": .string(s.resolvedCenterMetric.rawValue),
            "valueDirection": .string(s.resolvedCenterValueDirection.rawValue),
            "ringWidth": .number(s.ringWidth),
            "trackColor": .string("#293036"), "trackOpacity": .number(s.trackOpacity),
            "fillColorMode": .string("customColor"), "fillColor": .string("#40D161"),
            "ringDirection": .string(s.resolvedRingDirection.rawValue),
            "roundedLineCap": .boolean(s.roundedLineCap),
            "ringGlowEnabled": .boolean(s.ringGlowEnabled),
            "ringGlowIntensity": .number(s.ringGlowIntensity),
            "backgroundEnabled": .boolean(style.backgroundEnabled),
            "backgroundColor": .string("#0A121F"), "backgroundOpacity": .number(style.backgroundOpacity),
            "backgroundPaddingX": .number(style.backgroundPaddingX),
            "backgroundPaddingY": .number(style.backgroundPaddingY),
            "backgroundRadius": .number(style.backgroundRadius),
            "borderEnabled": .boolean(style.borderEnabled),
            "borderColor": .string("#FFFFFF"), "borderOpacity": .number(style.borderOpacity),
            "borderWidth": .number(style.borderWidth)
        ]
        for role in IntervalCountdownTextRole.allCases {
            let text = s.textStyle(for: role)
            let key = role.rawValue
            if role != .countdown {
                values["\(key)Visible"] = .boolean(text.isVisible)
                values["\(key)ColorMode"] = .string(text.colorMode == .followGroupColor ? "followGroupColor" : "customColor")
                values["\(key)Color"] = .string(colorHex(text.customColor))
            } else {
                values["\(key)Color"] = .string(colorHex(text.customColor))
            }
            values["\(key)FontFamily"] = .string(text.fontName)
            values["\(key)FontSize"] = .number(text.fontSize)
            values["\(key)Weight"] = .string(text.fontWeight.rawValue)
        }
        return values
    }

    private static func colorHex(_ color: OverlayColor) -> String {
        String(format: "#%02X%02X%02X",
               Int((color.red * 255).rounded()), Int((color.green * 255).rounded()),
               Int((color.blue * 255).rounded()))
    }

    @Test func countdownMatchesNativeAcrossStates() throws {
        let reference = try OverlayComponentReference(definitionData: OverlayComponentIntervalCountdownTests.data(), source: .bundled)
        let activity = Self.activity()
        let canvas = CGSize(width: 1280, height: 720)
        let cases: [(String, OverlayStyle, Double, TimeInterval, Double)] = [
            ("track-only", Self.style(direction: .counterclockwise), 1, 0.0, 1.0),
            ("full", Self.style(), 1, 0.0, 1.0),
            ("warmup", Self.style(), 1, 30, 1.0),
            ("active", Self.style(), 1, 90, 1.5),
            ("rest-counter", Self.style(direction: .counterclockwise), 1, 150, 2.0),
            ("active-elapsed-distance", Self.style(direction: .counterclockwise, metric: .distance, value: .elapsed), 1, 100, 1.0),
            ("hidden-text", Self.style(hiddenHelper: true, hiddenCaption: true), 1, 65, 1.0),
            ("background", Self.style(background: true), 1, 75, 1.0),
            ("effect-shadow", Self.style(background: true, shadow: true), 1, 80, 1.0),
            ("effect-shadow-nobg", Self.style(shadow: true), 1, 20, 1.5),
            ("effect-glow", Self.style(glow: true), 1, 85, 1.0),
            ("effect-ring-glow", Self.style(ringGlow: true), 1, 90, 1.0)
        ]
        for (label, style, elementScale, time, _) in cases {
            let native = OverlayElement(type: .intervalCountdown, position: CGPoint(x: 0.5, y: 0.5),
                                        scale: elementScale, style: style)
            let context = OverlayRenderContext(canvasSize: canvas, activity: activity, elapsedTime: time)
            let layout = OverlayRenderModel.intervalCountdownLayout(for: native, in: context)
            let component = OverlayElement(
                type: .component,
                position: CGPoint(x: layout.rect.minX / canvas.width,
                                  y: layout.rect.minY / canvas.height),
                scale: elementScale, style: style,
                component: OverlayComponentInstance(reference: reference, parameters: Self.parameters(style))
            )
            let frame = try #require(OverlayComponentSkiaRenderer.frame(for: component, renderContext: context))
            #expect(abs(frame.width - layout.rect.width) < 0.000001, "\(label) width")
            #expect(abs(frame.height - layout.rect.height) < 0.000001, "\(label) height")
            // A host-applied element shadow takes its mask from the whole
            // component, so an enabled border adds a faint edge to the mask
            // that the native module's fill-only shadow does not have. The
            // difference stays at one or two alpha levels, hence the slightly
            // wider changed-pixel budget for that one case.
            let changedPixelRatio = label == "effect-shadow" ? 0.007 : 0.0035
            try NativeComponentParityHarness.assertParity(
                label: "countdown-\(label)", native: OverlayLayout(elements: [native]),
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
#endif
