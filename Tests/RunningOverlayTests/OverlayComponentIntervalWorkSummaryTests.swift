import Foundation
import Testing
@testable import RunningOverlay

struct OverlayComponentIntervalWorkSummaryTests {
    static func data() throws -> Data {
        let item = try #require(OverlayComponentLibraryItem.intervalComponents.first {
            $0.resourceName == "interval-work-summary"
        })
        return try #require(OverlayComponentLibrary.data(for: item))
    }

    @Test func bundledDefinitionResolvesWithWorkData() throws {
        let package = try OverlayComponentLoader.load(data: Self.data())
        let activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 1_735_689_600),
            duration: 180, distanceMeters: 600,
            records: (0...180).map { t in
                ActivityRecord(
                    elapsedTime: Double(t),
                    timestamp: Date(timeIntervalSince1970: 1_735_689_600 + Double(t)),
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
        #expect(result.diagnostics.isEmpty)
        #expect(!result.nodes.isEmpty)
        #expect(package.definition.id == "studio.interval-work-summary")
    }
}

#if canImport(CSkiaBridge)
@Suite(.serialized, .skiaSerialized)
struct OverlayComponentIntervalWorkSummaryParityTests {
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
        unitSystem: IntervalWorkSummaryUnitSystem = .metric,
        background: Bool = false,
        primary: IntervalWorkSummaryMetric = .lapTime,
        secondaryVisible: [Bool] = [true, true, true],
        labelsVisible: Bool = true
    ) -> OverlayStyle {
        var style = OverlayStyle.default
        style.intervalWorkSummary.unitSystem = unitSystem
        style.intervalWorkSummary.primaryMetric = primary
        for (index, visible) in secondaryVisible.enumerated() where index < 3 {
            style.intervalWorkSummary.secondarySlots[index].isVisible = visible
        }
        style.intervalWorkSummary.componentLabelText.fontName = "Menlo"
        style.intervalWorkSummary.primaryValueText.fontName = "Menlo"
        style.intervalWorkSummary.primaryLabelText.fontName = "Menlo"
        style.intervalWorkSummary.secondaryValueText.fontName = "Menlo"
        style.intervalWorkSummary.secondaryLabelText.fontName = "Menlo"
        if !labelsVisible {
            style.intervalWorkSummary.primaryLabelText.isVisible = false
            style.intervalWorkSummary.secondaryLabelText.isVisible = false
        }
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

    private static func parameters(_ style: OverlayStyle) -> [String: OverlayJSONValue] {
        let s = style.intervalWorkSummary
        var values: [String: OverlayJSONValue] = [
            "summaryWidth": .number(s.width),
            "summaryHeight": .number(s.height),
            "unitSystem": .string(s.unitSystem.rawValue),
            "displayDuration": .number(s.displayDuration),
            "componentLabel": .string(s.componentLabel),
            "componentLabelTextVisible": .boolean(s.componentLabelText.isVisible),
            "primaryMetric": .string(s.primaryMetric.rawValue),
            "primaryMetricLabelVisible": .boolean(s.primaryLabelVisible),
            "primaryLabelTextVisible": .boolean(s.primaryLabelText.isVisible),
            "dividerEnabled": .boolean(s.dividerEnabled),
            "dividerOpacity": .number(s.dividerOpacity),
            "dividerWidth": .number(s.dividerWidth),
            "accentColorMode": .string(s.accentColorMode == .followGroupColor ? "followGroupColor" : "customColor"),
            "accentColor": .string(colorHex(s.accentCustomColor)),
            "secondaryLabelTextVisible": .boolean(s.secondaryLabelText.isVisible),
            "backgroundEnabled": .boolean(style.backgroundEnabled),
            "backgroundColor": .string(colorHex(style.backgroundColor)),
            "backgroundOpacity": .number(style.backgroundOpacity),
            "backgroundRadius": .number(style.backgroundRadius),
            "backgroundPaddingX": .number(style.backgroundPaddingX),
            "backgroundPaddingY": .number(style.backgroundPaddingY),
            "borderEnabled": .boolean(style.borderEnabled),
            "borderOpacity": .number(style.borderOpacity),
            "borderWidth": .number(style.borderWidth)
        ]
        for (index, slot) in s.normalizedSecondarySlots.enumerated() {
            values["slot\(index + 1)Metric"] = .string(slot.metric.rawValue)
            values["slot\(index + 1)Visible"] = .boolean(slot.isVisible)
            values["slot\(index + 1)LabelVisible"] = .boolean(slot.labelVisible)
        }
        let roles: [(String, IntervalWorkSummaryTextRole)] = [
            ("componentLabel", .componentLabel),
            ("primaryValue", .primaryValue),
            ("primaryLabel", .primaryLabel),
            ("secondaryValue", .secondaryValue),
            ("secondaryLabel", .secondaryLabel)
        ]
        for (prefix, role) in roles {
            let text = s.textStyle(for: role)
            values["\(prefix)FontFamily"] = .string(text.fontName)
            values["\(prefix)FontSize"] = .number(text.fontSize)
            values["\(prefix)FontWeight"] = .string(text.fontWeight.rawValue)
            values["\(prefix)ColorMode"] = .string(text.colorMode == .followGroupColor ? "followGroupColor" : "customColor")
            values["\(prefix)CustomColor"] = .string(colorHex(text.customColor))
        }
        return values
    }

    private static func colorHex(_ color: OverlayColor) -> String {
        String(format: "#%02X%02X%02X",
               Int((color.red * 255).rounded()), Int((color.green * 255).rounded()),
               Int((color.blue * 255).rounded()))
    }

    @Test func workSummaryMatchesNativeAcrossStates() throws {
        let reference = try OverlayComponentReference(definitionData: OverlayComponentIntervalWorkSummaryTests.data(), source: .bundled)
        let activity = Self.activity()
        let canvas = CGSize(width: 1280, height: 720)
        let cases: [(String, OverlayStyle, Double, TimeInterval)] = [
            ("default", Self.style(), 1, 125),
            ("imperial", Self.style(unitSystem: .imperial), 1, 125),
            ("one-column", Self.style(secondaryVisible: [true, false, false]), 1, 125),
            ("no-columns", Self.style(secondaryVisible: [false, false, false]), 1, 125),
            ("hidden-labels", Self.style(labelsVisible: false), 1, 125),
            ("primary-pace", Self.style(primary: .lapPace), 1, 121),
            ("background", Self.style(background: true), 1, 123),
            ("scaled", Self.style(), 1.5, 125)
        ]
        for (label, style, elementScale, time) in cases {
            let native = OverlayElement(type: .intervalWorkSummary, position: CGPoint(x: 0.5, y: 0.5),
                                        scale: elementScale, style: style)
            let context = OverlayRenderContext(canvasSize: canvas, activity: activity, elapsedTime: time)
            let layout = OverlayRenderModel.intervalWorkSummaryLayout(for: native, in: context)
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
            try NativeComponentParityHarness.assertParity(
                label: "work-summary-\(label)", native: OverlayLayout(elements: [native]),
                component: OverlayLayout(elements: [component]), activity: activity,
                elapsedTime: time, size: canvas, thresholds: .init(
                    channelTolerance: 2,
                    maximumChangedPixelRatio: 0.0035,
                    maximumChannelDelta: 80,
                    maximumMeanChannelDelta: 0.13
                )
            )
        }
    }
}
#endif
