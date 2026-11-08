import Foundation
import Testing
@testable import RunningOverlay

/// The `metric(id, unit...)` builtin returns `OverlayValueFormatter` text for
/// every metric, display unit and time, with and without data. Native numeric
/// overlays were the parity oracle until they were removed (ADR 0014); the
/// pinned table keeps their exact formatting.
struct OverlayComponentMetricTests {
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

    private func formatterComponents(
        id: String,
        unit: String?,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval
    ) throws -> OverlayValueComponents {
        let metric = try #require(OverlayMetric(rawValue: id))
        return OverlayValueFormatter.components(
            for: metric,
            unit: unit.flatMap(OverlayUnitOption.init(rawValue:)),
            activity: activity,
            elapsedTime: elapsedTime
        )
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

    @Test(arguments: OverlayMetric.allCases.map(\.rawValue))
    func metricMatchesFormatter(id: String) throws {
        let activity = makeTimeline()
        let units: [String?] = [nil] + OverlayComponentMetricCatalog.units(for: id)
        for unit in units {
            for time in [0.0, 112.5, 262.0, 437.8, 600.0] {
                let native = try formatterComponents(id: id, unit: unit, activity: activity, elapsedTime: time)
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
        for id in OverlayMetric.allCases.map(\.rawValue) {
            let native = try formatterComponents(id: id, unit: nil, activity: activity, elapsedTime: 120)
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

    /// Exact strings the native numeric overlays showed for this timeline at
    /// 112.5 s. Clock, date and HR zone metrics are omitted: they depend on
    /// the host time zone and the user's zone preferences.
    @Test func formattingIsPinned() throws {
        let pins: [(String, String?, String)] = [
            ("heartRate", nil, "113|bpm|Heart Rate|HR"),
            ("pace", nil, "5'01\"|/km|Pace|PACE"),
            ("pace", "paceImperial", "8'05\"|/mi|Pace|PACE"),
            ("pace", "paceRowing", "2'31\"|/500m|Pace|PACE"),
            ("avgPace", nil, "4'57\"|/km|Avg Pace|AVG"),
            ("lapPace", nil, "4'57\"|/km|Lap Pace|LAP"),
            ("distance", nil, "0.38|km|Distance|DIST"),
            ("distance", "distanceMiles", "0.24|mi|Distance|DIST"),
            ("distance", "distanceMeters", "379|m|Distance|DIST"),
            ("elevation", nil, "15|m|Elevation|ELEV"),
            ("elevation", "elevationFeet", "49|ft|Elevation|ELEV"),
            ("elevationGain", nil, "3|m|Elevation Gain|GAIN"),
            ("elapsedTime", nil, "00:01:53||Elapsed Time|TIME"),
            ("elapsedTime", "durationMS", "01:53||Elapsed Time|TIME"),
            ("elapsedTime", "durationSeconds", "113||Elapsed Time|TIME"),
            ("cadence", nil, "170|spm|Cadence|CAD"),
            ("power", nil, "237|W|Power|PWR"),
            ("calories", nil, "15|kcal|Calories|CAL"),
            ("verticalOscillation", nil, "8.5|cm|Vert. Osc.|OSC"),
            ("verticalOscillation", "oscillationMillimeters", "85|mm|Vert. Osc.|OSC"),
            ("groundContactTime", nil, "240|ms|GCT|GCT"),
            ("strideLength", nil, "1.15|m|Stride|STRIDE"),
            ("verticalRatio", nil, "7.4|%|Vert. Ratio|VR"),
            ("groundContactBalance", nil, "49.8L / 50.2R|%|GCT Balance|BAL"),
            ("temperature", nil, "18°|°C|Temp|TEMP"),
            ("temperature", "temperatureFahrenheit", "64°|°F|Temp|TEMP"),
            ("grade", nil, "-0.9|%|Grade|GRD")
        ]
        let activity = makeTimeline()
        for (id, unit, expected) in pins {
            let record = try componentRecord(id: id, unit: unit, activity: activity, elapsedTime: 112.5)
            let text = [record["value"], record["unit"], record["label"], record["shortLabel"]]
                .map { $0?.string ?? "nil" }
                .joined(separator: "|")
            #expect(text == expected, "\(id) \(unit ?? "default")")
        }
    }
}
