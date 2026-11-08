import Foundation
import Testing
@testable import RunningOverlay

/// String-level parity for the `metric(id, unit)` builtin. Every numeric
/// overlay type except Custom Numeric must produce exactly the value, unit,
/// label and short label of the native formatter, for every display unit and
/// across times with and without data.
struct OverlayComponentMetricParityTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    /// Records cover running dynamics, temperature and grade. Records 3–4 drop
    /// heart rate, pace and dynamics, exercising the native gap handling.
    private func makeTimeline() -> ActivityTimeline {
        let records = (0...8).map { index -> ActivityRecord in
            let time = Double(index) * 75
            let hasData = index != 3 && index != 4
            return ActivityRecord(
                elapsedTime: time,
                timestamp: start.addingTimeInterval(time),
                distanceMeters: time * 3.37,
                heartRate: hasData ? 96 + index * 11 : nil,
                paceSecondsPerKilometer: hasData ? 296.6 + Double(index) * 3.1 : nil,
                elevationMeters: 12.4 + Double(index) * 1.7,
                cadence: hasData ? 168 + index : nil,
                powerWatts: hasData ? 231 + index * 4 : nil,
                calories: time * 0.137,
                latitude: 37.0 + Double(index) * 0.001,
                longitude: -122.0 + Double(index) * 0.001,
                verticalOscillationMM: hasData ? 83.6 + Double(index) : nil,
                groundContactTimeMS: hasData ? 241.4 - Double(index) : nil,
                strideLengthM: hasData ? 1.137 + Double(index) * 0.01 : nil,
                groundContactBalance: hasData ? 49.6 + Double(index) * 0.1 : nil,
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
    }

    private func nativeComponents(
        id: String,
        unit: String?,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval
    ) throws -> OverlayValueComponents {
        let metric = try #require(OverlayComponentMetricCatalog.metrics[id])
        var style = OverlayStyle.default
        style.unitOption = OverlayComponentMetricCatalog.unitOption(for: metric, requested: unit.map { [$0] } ?? [])
        style.elevationDisplayMode = metric.elevationDisplayMode
        style.customLabel = ""
        let element = OverlayElement(
            type: metric.type,
            position: .zero,
            scale: 1,
            style: style
        )
        return OverlayValueFormatter.components(for: element, activity: activity, elapsedTime: elapsedTime)
    }

    private func componentRecord(
        id: String,
        unit: String?,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval
    ) throws -> [String: OverlayComponentValue] {
        let source = unit.map { "metric(\"\(id)\", \"\($0)\")" } ?? "metric(\"\(id)\")"
        let data = OverlayComponentActivityData(
            activity: activity,
            elapsedTime: elapsedTime,
            zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720),
            elementScale: 1
        )
        let value = try OverlayComponentExpression.parse(source)
            .evaluate(in: OverlayComponentEvaluationContext(data: data))
        return try #require(value.record)
    }

    @Test func everyNativeNumericTypeHasAMetric() {
        let covered = Set(OverlayComponentMetricCatalog.metrics.values.map(\.type))
        let numeric = OverlayElementType.allCases.filter { $0.isNumericOverlay && $0 != .customNumeric }
        #expect(numeric.allSatisfy(covered.contains))
    }

    @Test(arguments: OverlayComponentMetricCatalog.metrics.keys.sorted())
    func metricMatchesNativeFormatter(id: String) throws {
        let activity = makeTimeline()
        let units: [String?] = [nil] + OverlayComponentMetricCatalog.units(for: id)
        for unit in units {
            for time in [0.0, 112.5, 262.0, 437.8, 600.0] {
                let native = try nativeComponents(id: id, unit: unit, activity: activity, elapsedTime: time)
                let record = try componentRecord(id: id, unit: unit, activity: activity, elapsedTime: time)
                let context = "\(id) unit=\(unit ?? "default") t=\(time)"
                #expect(record["value"] == .string(native.value), "\(context)")
                #expect(record["unit"] == .string(native.unit), "\(context)")
                #expect(record["label"] == .string(native.label), "\(context)")
                #expect(record["shortLabel"] == .string(native.shortLabel), "\(context)")
            }
        }
    }

    @Test func missingDataUsesNativePlaceholders() throws {
        // A timeline without heart rate, pace or running dynamics: both paths
        // must show the native placeholders.
        let records = [0.0, 300].map { time in
            ActivityRecord(
                elapsedTime: time,
                timestamp: start.addingTimeInterval(time),
                distanceMeters: nil,
                heartRate: nil,
                paceSecondsPerKilometer: nil,
                elevationMeters: nil,
                cadence: nil,
                powerWatts: nil,
                calories: nil
            )
        }
        let activity = ActivityTimeline(
            startDate: start,
            duration: 300,
            distanceMeters: 0,
            records: records,
            laps: []
        )
        for id in OverlayComponentMetricCatalog.metrics.keys.sorted() {
            let native = try nativeComponents(id: id, unit: nil, activity: activity, elapsedTime: 120)
            let record = try componentRecord(id: id, unit: nil, activity: activity, elapsedTime: 120)
            #expect(record["value"] == .string(native.value), "\(id)")
        }
        let heartRate = try componentRecord(id: "heartRate", unit: nil, activity: activity, elapsedTime: 120)
        #expect(heartRate["value"] == .string("--"))
        let pace = try componentRecord(id: "pace", unit: "paceImperial", activity: activity, elapsedTime: 120)
        #expect(pace["value"] == .string("--'--\""))
        #expect(pace["unit"] == .string("/mi"))
    }

    @Test func unsupportedUnitFallsBackToTheMetricDefault() throws {
        let activity = makeTimeline()
        let record = try componentRecord(id: "distance", unit: "paceImperial", activity: activity, elapsedTime: 100)
        #expect(record["unit"] == .string("km"))
        // The first candidate the metric supports wins.
        let multi = try OverlayComponentExpression.parse(
            "metric(\"distance\", \"paceImperial\", \"distanceMiles\", \"distanceMeters\")"
        ).evaluate(in: OverlayComponentEvaluationContext(data: OverlayComponentActivityData(
            activity: activity,
            elapsedTime: 100,
            zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720),
            elementScale: 1
        )))
        #expect(multi.record?["unit"] == .string("mi"))
        #expect(record["icon"] == .string("ruler"))
        let unknown = try OverlayComponentExpression.parse("metric(\"speed\")")
            .evaluate(in: OverlayComponentEvaluationContext(data: OverlayComponentActivityData(
                activity: activity,
                elapsedTime: 100,
                zoneSnapshot: nil,
                canvasSize: CGSize(width: 1280, height: 720),
                elementScale: 1
            )))
        #expect(unknown == .null)
    }
}
