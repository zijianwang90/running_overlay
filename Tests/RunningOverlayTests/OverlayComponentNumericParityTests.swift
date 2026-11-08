#if canImport(CSkiaBridge)
import CoreGraphics
import Foundation
import Testing
@testable import RunningOverlay

/// Pixel parity between native numeric overlays and the bundled generic
/// `studio.numeric` component. Cases are chosen pairwise over metric, icon,
/// unit and label positions, alignments, background, minimum size and element
/// scale rather than as a full Cartesian product.
@Suite(.serialized, .skiaSerialized)
struct OverlayComponentNumericParityTests {
    private static let canvas = CGSize(width: 1280, height: 720)
    private static let start = Date(timeIntervalSince1970: 1_700_000_000)

    /// Synthetic activity with running dynamics, temperature and grade so
    /// every metric renders a real value.
    nonisolated(unsafe) private static let activity: ActivityTimeline = {
        let records = (0...8).map { index -> ActivityRecord in
            let time = Double(index) * 75
            return ActivityRecord(
                elapsedTime: time,
                timestamp: start.addingTimeInterval(time),
                distanceMeters: time * 3.37,
                heartRate: 96 + index * 11,
                paceSecondsPerKilometer: 296.6 + Double(index) * 3.1,
                elevationMeters: 12.4 + Double(index) * 1.7,
                cadence: 168 + index,
                powerWatts: 231 + index * 4,
                calories: time * 0.137,
                verticalOscillationMM: 83.6 + Double(index),
                groundContactTimeMS: 241.4 - Double(index),
                strideLengthM: 1.137 + Double(index) * 0.01,
                groundContactBalance: 49.6 + Double(index) * 0.1,
                temperatureCelsius: 17.6 + Double(index) * 0.2,
                gradePercent: -1.4 + Double(index) * 0.35
            )
        }
        let laps: [LapRecord] = (1...3).map { index in
            LapRecord(
                lapIndex: index,
                startElapsedTime: Double(index - 1) * 200,
                endElapsedTime: Double(index) * 200,
                startDistanceMeters: Double(index - 1) * 674,
                totalDistanceMeters: 674,
                totalElapsedTime: 200,
                avgPaceSecondsPerKm: 297,
                avgHeartRate: 140,
                maxHeartRate: 160,
                avgCadenceSPM: 170,
                avgPowerWatts: 240,
                totalAscent: 5,
                kind: .active
            )
        }
        return ActivityTimeline(
            startDate: start,
            duration: 600,
            distanceMeters: 600 * 3.37,
            records: records,
            laps: laps
        )
    }()

    private struct Case: CustomTestStringConvertible, Sendable {
        var name: String
        var type: OverlayElementType
        var scale: Double
        var elapsed: Double = 337.5
        var configure: @Sendable (inout OverlayStyle) -> Void

        var testDescription: String { name }
    }

    private static func baseStyle() -> OverlayStyle {
        var style = OverlayStyle.default
        style.fontName = "Helvetica Neue"
        style.labelFontName = "Helvetica Neue"
        style.unitFontName = "Helvetica Neue"
        style.iconSystemName = ""
        style.backgroundColor = .black
        style.backgroundOpacity = 51.0 / 255
        return style
    }

    private static let cases: [Case] = [
        Case(name: "heart-rate-default", type: .heartRate, scale: 1) { _ in },
        Case(name: "pace-imperial-wide-top-label", type: .pace, scale: 1.5) { style in
            style.unitOption = .paceImperial
            style.showLabel = true
            style.customLabel = "Current Pace Per Mile"
            style.labelPosition = .top
        },
        Case(name: "distance-miles-label-bottom-unit-bottom-center", type: .distance, scale: 2) { style in
            style.unitOption = .distanceMiles
            style.showLabel = true
            style.labelPosition = .bottom
            style.unitPosition = .bottom
            style.unitTextAlignment = .center
            style.iconPosition = .trailing
        },
        Case(name: "elevation-gain-feet-leading-label-leading-unit-icon-top", type: .elevation, scale: 1) { style in
            style.elevationDisplayMode = .gain
            style.unitOption = .elevationFeet
            style.showLabel = true
            style.labelPosition = .leading
            style.unitPosition = .leading
            style.iconPosition = .top
            style.iconTextAlignment = .center
        },
        Case(name: "elapsed-trailing-label-icon-bottom-min-width", type: .elapsedTime, scale: 1.5) { style in
            style.showLabel = true
            style.labelPosition = .trailing
            style.iconPosition = .bottom
            style.iconTextAlignment = .trailing
            style.numericMinWidth = 200
        },
        Case(name: "cadence-trailing-label-wide-bottom-unit-no-chrome", type: .cadence, scale: 1) { style in
            style.showLabel = true
            style.labelPosition = .trailing
            style.unitPosition = .bottom
            style.unitTextAlignment = .trailing
            style.unitFontSize = 44
            style.iconEnabled = false
            style.backgroundEnabled = false
        },
        Case(name: "temperature-f-leading-unit-middle-top-label", type: .temperature, scale: 2) { style in
            style.unitOption = .temperatureFahrenheit
            style.unitPosition = .leading
            style.unitTextAlignment = .center
            style.showLabel = true
            style.labelPosition = .top
        },
        Case(name: "gct-balance-unit-end-icon-leading-start", type: .groundContactBalance, scale: 1) { style in
            style.unitTextAlignment = .trailing
            style.iconTextAlignment = .leading
        },
        Case(name: "real-time-12h-leading-label-icon-trailing", type: .realTime, scale: 1) { style in
            style.unitOption = .clock12Hour
            style.showLabel = true
            style.labelPosition = .leading
            style.iconPosition = .trailing
            style.iconTextAlignment = .trailing
        },
        Case(name: "date-month-day-icon-top-start-custom-background", type: .date, scale: 1.5) { style in
            style.unitOption = .dateMonthDay
            style.showLabel = true
            style.labelPosition = .top
            style.iconPosition = .top
            style.iconTextAlignment = .leading
            style.backgroundRadius = 12
            style.backgroundPaddingX = 4
            style.backgroundPaddingY = 2
            style.numericMinHeight = 90
        },
        Case(name: "oscillation-mm-weights-fonts-label-bottom", type: .verticalOscillation, scale: 1) { style in
            style.unitOption = .oscillationMillimeters
            style.unitPosition = .leading
            style.unitFontWeight = .bold
            style.unitFontName = "Avenir Next"
            style.showLabel = true
            style.labelPosition = .bottom
            style.labelFontWeight = .regular
            style.labelFontName = "Avenir Next"
            style.iconTextAlignment = .trailing
            style.iconSize = 34
            style.iconSpacing = 3
        },
        Case(name: "grade-unit-end-top-label-colors", type: .grade, scale: 1) { style in
            style.unitTextAlignment = .trailing
            style.showLabel = true
            style.labelPosition = .top
            style.valueColor = OverlayColor(red: 1, green: 0.8, blue: 0.2, alpha: 1)
            style.unitColor = OverlayColor(red: 0.4, green: 0.9, blue: 1, alpha: 1)
            style.labelColor = OverlayColor(red: 1, green: 0.4, blue: 0.6, alpha: 1)
            style.iconColor = OverlayColor(red: 0.6, green: 1, blue: 0.5, alpha: 1)
            style.fontSize = 40
            style.labelFontSize = 13
        },
        Case(name: "power-no-unit-hidden-unit-icon-off", type: .power, scale: 1.5) { style in
            style.showUnit = false
            style.iconEnabled = false
            style.showLabel = true
            style.labelPosition = .leading
            style.labelSpacing = 20
        }
    ]

    /// Test-side legacy mapping: the M5d converter will formalize it.
    private static func parameters(for element: OverlayElement) -> [String: OverlayJSONValue] {
        let style = element.style
        let scale = element.scale
        func hex(_ color: OverlayColor, opacity: Double = 1) -> OverlayJSONValue {
            var color = color
            color.alpha *= opacity
            return .string(color.componentHexString)
        }
        func align(_ alignment: OverlayTextAlignment) -> OverlayJSONValue {
            switch alignment {
            case .leading: .string("start")
            case .center: .string("center")
            case .trailing: .string("end")
            }
        }
        let metricId: String = element.type == .elevation && style.elevationDisplayMode == .gain
            ? "elevationGain"
            : OverlayComponentMetricCatalog.metrics.first {
                $0.value.type == element.type && $0.value.elevationDisplayMode == .current
            }?.key ?? ""
        var parameters: [String: OverlayJSONValue] = [
            "metricId": .string(metricId),
            "valueFont": .string(style.fontName),
            "valueSize": .number(style.fontSize),
            "valueColor": hex(style.valueColor, opacity: style.valueOpacity),
            "valueFollowsZone": .boolean(style.valueColorsFollowHeartRateZones),
            "showUnit": .boolean(style.showUnit && style.unitPosition != .top),
            "unitPosition": .string(style.unitPosition == .top ? "trailing" : style.unitPosition.rawValue),
            "unitAlign": align(style.unitTextAlignment),
            "unitFont": .string(style.unitFontName),
            "unitSize": .number(style.unitFontSize),
            "unitWeight": .string(style.unitFontWeight.rawValue),
            "unitColor": hex(style.unitColor, opacity: style.unitOpacity),
            "unitSpacing": .number(style.unitSpacing),
            "unitFollowsZone": .boolean(style.unitColorsFollowHeartRateZones),
            "showLabel": .boolean(style.showLabel),
            "labelText": .string(style.customLabel),
            "labelPosition": .string(style.labelPosition.rawValue),
            "labelFont": .string(style.labelFontName),
            "labelSize": .number(style.labelFontSize),
            "labelWeight": .string(style.labelFontWeight.rawValue),
            "labelColor": hex(style.labelColor, opacity: style.labelOpacity),
            "labelSpacing": .number(style.labelSpacing),
            "labelFollowsZone": .boolean(style.labelColorsFollowHeartRateZones),
            "showIcon": .boolean(style.iconEnabled),
            "iconName": .string(style.iconSystemName),
            "iconPosition": .string(style.iconPosition.rawValue),
            "iconAlign": align(style.iconTextAlignment),
            "iconSize": .number(style.iconSize),
            "iconColor": hex(style.iconColor, opacity: style.iconOpacity),
            "iconSpacing": .number(style.iconSpacing),
            "iconFollowsZone": .boolean(style.iconColorsFollowHeartRateZones),
            "showBackground": .boolean(style.backgroundEnabled),
            "backgroundColor": hex(style.backgroundColor, opacity: style.backgroundOpacity),
            // Native background geometry scales with the canvas only.
            "backgroundRadius": .number(style.backgroundRadius / scale),
            "paddingX": .number(style.backgroundPaddingX / scale),
            "paddingY": .number(style.backgroundPaddingY / scale),
            "minWidth": .number(style.numericMinWidth),
            "minHeight": .number(style.numericMinHeight)
        ]
        let unit = style.unitOption.rawValue
        for (key, family) in [
            ("paceUnit", OverlayElementType.pace), ("distanceUnit", .distance),
            ("elevationUnit", .elevation), ("durationFormat", .elapsedTime),
            ("clockFormat", .realTime), ("dateFormat", .date),
            ("oscillationUnit", .verticalOscillation), ("temperatureUnit", .temperature)
        ] where OverlayUnitOption.options(for: family).map(\.rawValue).contains(unit) {
            parameters[key] = .string(unit)
        }
        return parameters
    }

    private static func pair(for testCase: Case) throws -> (native: OverlayLayout, component: OverlayLayout) {
        var style = baseStyle()
        testCase.configure(&style)
        let native = OverlayElement(
            type: testCase.type,
            position: CGPoint(x: 0.2, y: 0.2),
            scale: testCase.scale,
            opacity: 1,
            style: style
        )
        let item = try #require(OverlayComponentLibraryItem.numericPresets.first)
        let reference = try OverlayComponentLibrary.reference(for: item)
        let component = OverlayElement(
            type: .component,
            position: native.position,
            scale: native.scale,
            opacity: 1,
            style: style,
            component: OverlayComponentInstance(reference: reference, parameters: parameters(for: native))
        )
        return (OverlayLayout(elements: [native]), OverlayLayout(elements: [component]))
    }

    @Test(arguments: cases)
    private func numericComponentMatchesNative(_ testCase: Case) throws {
        let (native, component) = try Self.pair(for: testCase)
        // The component must resolve cleanly; a silent fallback would hide a
        // broken definition behind matching blank renders.
        let instance = try #require(component.elements.first?.component)
        let data = OverlayComponentActivityData(
            activity: Self.activity,
            elapsedTime: testCase.elapsed,
            zoneSnapshot: HeartRateZonePreferences.currentSnapshot(),
            canvasSize: Self.canvas,
            elementScale: testCase.scale
        )
        let resolved = try #require(OverlayComponentRegistry.resolve(instance: instance, data: data))
        #expect(resolved.diagnostics.isEmpty, "\(resolved.diagnostics)")

        try NativeComponentParityHarness.assertParity(
            label: "numeric-\(testCase.name)",
            native: native,
            component: component,
            activity: Self.activity,
            elapsedTime: testCase.elapsed,
            size: Self.canvas,
            thresholds: .exact
        )
    }
}
#endif
