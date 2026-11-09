import Foundation
import Testing
@testable import RunningOverlay

struct OverlayComponentWorkoutDataTests {
    @Test func workoutAndZoneBindingsAreAcceptedByTheProtocol() throws {
        var bindings: [String: Any] = [:]
        for (index, path) in [
            "activity.duration", "activity.totalDistance", "structure.segment",
            "structure.lastWork", "structure.recovery", "zone.current",
            "zone.heartRateThreshold", "zone.paceThreshold"
        ].enumerated() {
            bindings["s\(index)"] = ["signal": path]
        }
        bindings["hrZones"] = ["list": "zone.heartRateZones"]
        bindings["paceZones"] = ["list": "zone.paceZones"]
        let json: [String: Any] = [
            "spec": "ros.component/0.1", "id": "test.workout-data", "version": "1.0.0",
            "name": "Workout data", "license": "MIT", "size": [100, 100],
            "bindings": bindings,
            "nodes": [["type": "rect", "frame": [0, 0, 100, 100], "fill": "#FFFFFF"]]
        ]
        let package = try OverlayComponentLoader.load(data: JSONSerialization.data(withJSONObject: json))
        #expect(package.definition.bindings.count == 10)
    }

    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func lap(_ index: Int, start: Double, end: Double, distance: Double, kind: LapKind) -> LapRecord {
        LapRecord(
            lapIndex: index, startElapsedTime: start, endElapsedTime: end,
            startDistanceMeters: start * 5, totalDistanceMeters: distance,
            totalElapsedTime: end - start, avgPaceSecondsPerKm: nil,
            avgHeartRate: 160, maxHeartRate: 180, avgCadenceSPM: 175,
            avgPowerWatts: 250, totalAscent: 2, kind: kind
        )
    }

    private func activity(laps: [LapRecord]? = nil) -> ActivityTimeline {
        let records = [(0.0, 140), (10, 170), (20, 180), (25, 190), (30, 150), (40, 140), (60, 160)].map { time, hr in
            ActivityRecord(
                elapsedTime: time, timestamp: start.addingTimeInterval(time),
                distanceMeters: time * 5, heartRate: hr, paceSecondsPerKilometer: 300,
                elevationMeters: 10, cadence: 175, powerWatts: 250, calories: time
            )
        }
        return ActivityTimeline(
            startDate: start, duration: 60, distanceMeters: 300, records: records,
            laps: laps ?? [
                lap(0, start: 0, end: 20, distance: 100, kind: .active),
                lap(7, start: 20, end: 40, distance: 100, kind: .rest),
                lap(12, start: 40, end: 60, distance: 100, kind: .active)
            ]
        )
    }

    private func data(_ activity: ActivityTimeline, at time: Double, zones: HeartRateZoneSnapshot? = nil) -> OverlayComponentActivityData {
        OverlayComponentActivityData(
            activity: activity, elapsedTime: time, zoneSnapshot: zones,
            canvasSize: CGSize(width: 1280, height: 720), elementScale: 1,
            intervalColors: .default
        )
    }

    @Test func normalLapsRetainRawIndicesAndWholeActivityOrder() throws {
        let source = activity()
        let provider = data(source, at: 30)
        #expect(provider.signal(path: "structure.current") == .null)
        let segment = try #require(provider.signal(path: "structure.segment").record)
        #expect(segment["index"] == .number(7))
        #expect(segment["phase"] == .string("rest"))
        #expect(segment["phaseText"] == .string("REST"))
        #expect(segment["elapsed"] == .number(10))
        #expect(segment["remaining"] == .number(10))
        #expect(segment["timeProgress"] == .number(0.5))
        #expect(segment["distanceProgress"] == .number(0.5))
        #expect(segment["elapsedDistance"] == .number(50))
        #expect(segment["remainingDistance"] == .number(50))
        #expect(segment["repIndex"] == .number(2))
        #expect(segment["repCount"] == .number(2))
        #expect(segment["repText"] == .string("2 / 2"))
        #expect(segment["groupColor"] == .color(IntervalKindColorPalette.default.rest))
        let list = try #require(provider.list(path: "structure.laps").list)
        #expect(list.compactMap { $0.record?["index"]?.number } == [0, 7, 12])
        #expect(list[1].record?["startElapsed"] == .number(20))
        #expect(list[1].record?["endElapsed"] == .number(40))
        #expect(list[1].record?["startDistance"] == .number(100))
        #expect(list[1].record?["totalAscent"] == .number(2))
        #expect(provider.signal(path: "activity.duration") == .number(60))
        #expect(provider.signal(path: "activity.totalDistance") == .number(300))
    }

    @Test func noLapsUseNativeActivityFallbackWithZeroProgress() throws {
        let source = activity(laps: [])
        for (time, elapsed, remaining) in [(-5.0, 0.0, 60.0), (30, 30, 30), (90, 60, 0)] {
            let segment = try #require(data(source, at: time).signal(path: "structure.segment").record)
            #expect(segment["index"] == .null)
            #expect(segment["elapsed"] == .number(elapsed))
            #expect(segment["remaining"] == .number(remaining))
            #expect(segment["timeProgress"] == .number(0))
            #expect(segment["distanceProgress"] == .number(0))
            #expect(segment["elapsedDistance"] == .number(elapsed * 5))
            #expect(segment["phaseText"] == .string("LAP"))
            #expect(segment["repText"] == .string("-- / --"))
        }
        #expect(data(source, at: 60).signal(path: "structure.lastWork") == .null)
    }

    @Test func zeroDurationAndDistanceDoNotDivideByZero() throws {
        var source = activity(laps: [lap(4, start: 0, end: 0, distance: 0, kind: .unknown)])
        source.duration = 0
        source.distanceMeters = 0
        source.records = []
        let segment = try #require(data(source, at: 10).signal(path: "structure.segment").record)
        #expect(segment["timeProgress"] == .number(0))
        #expect(segment["distanceProgress"] == .number(0))
        #expect(segment["elapsedDistance"] == .number(0))
        #expect(segment["remainingDistance"] == .number(0))
        source.laps = []
        let fallback = try #require(data(source, at: 10).signal(path: "structure.segment").record)
        // Native countdown uses max(activity.duration, 1) for fallback end time.
        #expect(fallback["remaining"] == .number(1))
        #expect(fallback["timeProgress"] == .number(0))
    }

    @Test func exactLapBoundariesAndBackwardSeekingAreStateless() throws {
        var provider = data(activity(), at: 60)
        #expect(provider.signal(path: "structure.lastWork").record?["index"] == .number(12))
        provider.elapsedTime = 20
        #expect(provider.signal(path: "structure.segment").record?["index"] == .number(7))
        #expect(provider.signal(path: "structure.lastWork").record?["index"] == .number(0))
        #expect(provider.signal(path: "structure.lastWork").record?["completionAge"] == .number(0))
        provider.elapsedTime = 19.999
        #expect(provider.signal(path: "structure.lastWork") == .null)
        provider.elapsedTime = 26
        #expect(provider.signal(path: "structure.lastWork").record?["completionAge"] == .number(6))
        // The summary displays for six seconds after the work lap ends; a
        // second active lap ending at 60 s starts a new window.
        let windows: [(time: Double, visible: Bool)] = [
            (19.999, false), (20, true), (26, true), (26.001, false), (60, true)
        ]
        for window in windows {
            provider.elapsedTime = window.time
            let summary = provider.signal(path: "structure.lastWork").record
            let age = summary?["completionAge"]?.number
            let visible = age.map { $0 >= 0 && $0 <= 6 } ?? false
            #expect(visible == window.visible, "\(window.time)")
        }
    }

    @Test func recoveryUsesOnlySamplesUpToSeekTimeInCurrentLap() throws {
        var provider = data(activity(), at: 30)
        var recovery = try #require(provider.signal(path: "structure.recovery").record)
        #expect(recovery["peakHeartRate"] == .number(190))
        #expect(recovery["drop"] == .number(40))
        #expect(abs((recovery["dropPercent"]?.number ?? 0) - 40.0 / 190 * 100) < 0.000_001)
        provider.elapsedTime = 20
        recovery = try #require(provider.signal(path: "structure.recovery").record)
        #expect(recovery["peakHeartRate"] == .number(180))
        #expect(recovery["drop"] == .number(0))
        provider.activity.laps = []
        recovery = try #require(provider.signal(path: "structure.recovery").record)
        #expect(recovery["peakHeartRate"] == .null)
        #expect(recovery["drop"] == .null)
        #expect(recovery["dropPercent"] == .null)
    }

    /// Pinned formatting table for the finished work lap: distance 0 exercises
    /// the missing-pace and missing-metric fallbacks, 100 m the metre branch
    /// and 1500 m the kilometre branch.
    @Test func summaryMetricsUsePinnedFormattingForEveryMetricAndUnitSystem() throws {
        struct Expected {
            var value: String
            var unit: String
        }
        let activeMetric: [IntervalWorkSummaryMetric: Expected] = [
            .lapTime: Expected(value: "0:20", unit: ""),
            .avgHeartRate: Expected(value: "160", unit: "bpm"),
            .maxHeartRate: Expected(value: "180", unit: "bpm"),
            .avgPower: Expected(value: "250", unit: "W"),
            .avgCadence: Expected(value: "175", unit: "spm"),
        ]
        let missingMetric: [IntervalWorkSummaryMetric: Expected] = [
            .lapTime: Expected(value: "0:20", unit: ""),
            .avgHeartRate: Expected(value: "--", unit: "bpm"),
            .maxHeartRate: Expected(value: "--", unit: "bpm"),
            .avgPower: Expected(value: "--", unit: "W"),
            .avgCadence: Expected(value: "--", unit: "spm"),
        ]
        let expected: [Double: [IntervalWorkSummaryUnitSystem: [IntervalWorkSummaryMetric: Expected]]] = [
            0: [
                .metric: missingMetric.merging([
                    .lapPace: Expected(value: "--:--", unit: "/km"),
                    .lapDistance: Expected(value: "0", unit: "m"),
                ]) { _, new in new },
                .imperial: missingMetric.merging([
                    .lapPace: Expected(value: "--:--", unit: "/mi"),
                    .lapDistance: Expected(value: "0.00", unit: "mi"),
                ]) { _, new in new },
            ],
            100: [
                .metric: activeMetric.merging([
                    .lapPace: Expected(value: "3:20", unit: "min/km"),
                    .lapDistance: Expected(value: "100", unit: "m"),
                ]) { _, new in new },
                .imperial: activeMetric.merging([
                    .lapPace: Expected(value: "5:22", unit: "min/mile"),
                    .lapDistance: Expected(value: "0.06", unit: "mi"),
                ]) { _, new in new },
            ],
            1500: [
                .metric: activeMetric.merging([
                    .lapPace: Expected(value: "0:13", unit: "min/km"),
                    .lapDistance: Expected(value: "1.50", unit: "km"),
                ]) { _, new in new },
                .imperial: activeMetric.merging([
                    .lapPace: Expected(value: "0:21", unit: "min/mile"),
                    .lapDistance: Expected(value: "0.93", unit: "mi"),
                ]) { _, new in new },
            ],
        ]

        for distance in [0.0, 100, 1500] {
            var source = activity()
            source.laps[0].totalDistanceMeters = distance
            if distance == 0 {
                source.laps[0].avgHeartRate = nil
                source.laps[0].maxHeartRate = nil
                source.laps[0].avgPowerWatts = nil
                source.laps[0].avgCadenceSPM = nil
            }
            let provider = data(source, at: 20)
            let work = try #require(provider.signal(path: "structure.lastWork").record)
            let systems = try #require(work["metrics"]?.record)
            for system in IntervalWorkSummaryUnitSystem.allCases {
                let metrics = try #require(systems[system.rawValue]?.record)
                for metric in IntervalWorkSummaryMetric.allCases {
                    let expectedItem = try #require(expected[distance]?[system]?[metric])
                    let record = try #require(metrics[metric.rawValue]?.record)
                    #expect(record["value"] == .string(expectedItem.value), "\(metric) \(system) \(distance)")
                    #expect(record["unit"] == .string(expectedItem.unit), "\(metric) \(system) \(distance)")
                    #expect(record["label"] == .string(metric.shortLabel))
                }
            }
        }
    }

    @Test func zonesPreserveSnapshotSlotsAndInclusiveFirstMatchBoundaries() throws {
        let snapshot = HeartRateZoneSnapshot(
            zoneCount: 5, paceUnit: .minPerMile,
            zones: [
                HeartRateZone(minHR: 100, maxHR: 180, minPaceSecPerKm: 400, maxPaceSecPerKm: 300),
                HeartRateZone(minHR: 180, maxHR: 200, maxPaceSecPerKm: 300),
                HeartRateZone(), HeartRateZone(), HeartRateZone(),
                HeartRateZone(minHR: 1, maxHR: 250)
            ], thresholdHR: 180, thresholdPaceSecPerKm: 350
        )
        var provider = data(activity(), at: 20, zones: snapshot)
        let zones = try #require(provider.list(path: "zone.heartRateZones").list)
        #expect(zones.count == 5)
        #expect(zones[2].record?["lower"] == .null)
        #expect(zones[2].record?["color"] == .color(HRZonePalette.overlayColor(forIndex: 2)))
        let hr = try #require(provider.signal(path: "zone.heartRate").record)
        #expect(hr["index"] == .number(1))
        #expect(hr["fraction"] == .number(1))
        #expect(hr["valueText"] == .string("180 bpm"))
        #expect(provider.signal(path: "zone.heartRateThreshold").record?["fraction"] == .number(1))
        let pace = try #require(provider.signal(path: "zone.pace").record)
        #expect(pace["lower"] == .number(400))
        #expect(pace["upper"] == .number(300))
        #expect(pace["fraction"] == .number(0))
        #expect(pace["valueText"] == .string("8:03 min/mile"))
        #expect(provider.signal(path: "zone.paceThreshold").record?["fraction"] == .number(0.5))
        #expect(provider.signal(path: "zone.paceThreshold").record?["valueText"] == .string("T"))
        #expect(provider.signal(path: "structure.segment").record?["phaseColor"] == .color(IntervalKindColorPalette.default.rest))
        provider.elapsedTime = 10
        #expect(provider.signal(path: "structure.segment").record?["groupColor"] == .color(IntervalKindColorPalette.default.active))
        #expect(provider.signal(path: "structure.segment").record?["phaseColor"] == .color(HRZonePalette.overlayColor(forIndex: 0)))
        provider.activity.records = provider.activity.records.map { record in
            var result = record
            result.heartRate = nil
            return result
        }
        #expect(provider.signal(path: "zone.heartRate") == .null)
        #expect(provider.signal(path: "zone.current") == provider.signal(path: "zone.pace"))
        provider.intervalColors.active = .white
        #expect(provider.signal(path: "structure.segment").record?["groupColor"] == .color(.white))
        #expect(provider.signal(path: "structure.segment").record?["phaseColor"] == .color(HRZonePalette.overlayColor(forIndex: 0)))
        provider.activity.records = provider.activity.records.map { record in
            var result = record
            result.paceSecondsPerKilometer = 0
            return result
        }
        #expect(provider.signal(path: "zone.pace") == .null)
        #expect(provider.signal(path: "zone.current") == .null)
        #expect(provider.signal(path: "structure.segment").record?["phaseColor"] == .color(.white))
    }

    @Test func missingZonesAndOpenBoundariesHaveStableResults() throws {
        var provider = data(activity(), at: 20)
        #expect(provider.signal(path: "zone.current") == .null)
        #expect(provider.signal(path: "zone.heartRateThreshold") == .null)
        #expect(provider.list(path: "zone.paceZones") == .null)
        provider.zoneSnapshot = HeartRateZoneSnapshot(
            zoneCount: 5, paceUnit: .minPerKm,
            zones: [HeartRateZone(minHR: 100, minPaceSecPerKm: 250)],
            thresholdHR: nil, thresholdPaceSecPerKm: 0
        )
        #expect(provider.signal(path: "zone.heartRate").record?["fraction"] == .number(0.5))
        #expect(provider.signal(path: "zone.pace").record?["fraction"] == .number(0.5))
        #expect(provider.signal(path: "zone.paceThreshold") == .null)
        #expect(provider.list(path: "zone.paceZones").list?.count == 5)
        provider.zoneSnapshot?.zones = Array(repeating: HeartRateZone(), count: 5)
        #expect(provider.signal(path: "zone.current") == .null)
        #expect(provider.signal(path: "zone.pace") == .null)
    }
}
