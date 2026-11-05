import Foundation
import Testing
@testable import RunningOverlay

struct OverlayComponentDataTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeTimeline(structure: WorkoutStructureAnalysis = .normalAuto) -> ActivityTimeline {
        let records = (0...6).map { index -> ActivityRecord in
            let time = Double(index) * 100
            return ActivityRecord(
                elapsedTime: time,
                timestamp: start.addingTimeInterval(time),
                distanceMeters: time * 5,
                heartRate: 100 + index * 20,
                paceSecondsPerKilometer: 300,
                elevationMeters: 100 + Double(index),
                cadence: 170,
                powerWatts: 240,
                calories: time * 0.1,
                latitude: 37.0 + Double(index) * 0.001,
                longitude: -122.0 + Double(index) * 0.001,
                temperatureCelsius: 18,
                gradePercent: 0.5
            )
        }
        let laps = [
            LapRecord(
                lapIndex: 1,
                startElapsedTime: 0,
                endElapsedTime: 300,
                startDistanceMeters: 0,
                totalDistanceMeters: 1500,
                totalElapsedTime: 300,
                avgPaceSecondsPerKm: 300,
                avgHeartRate: 140,
                maxHeartRate: 160,
                avgCadenceSPM: 170,
                avgPowerWatts: 240,
                totalAscent: 10,
                kind: .active
            ),
            LapRecord(
                lapIndex: 2,
                startElapsedTime: 300,
                endElapsedTime: 600,
                startDistanceMeters: 1500,
                totalDistanceMeters: 1500,
                totalElapsedTime: 300,
                avgPaceSecondsPerKm: 280,
                avgHeartRate: 170,
                maxHeartRate: 185,
                avgCadenceSPM: 172,
                avgPowerWatts: 260,
                totalAscent: 8,
                kind: .rest
            )
        ]
        return ActivityTimeline(
            startDate: start,
            duration: 600,
            distanceMeters: 3000,
            records: records,
            laps: laps,
            workoutStructure: structure
        )
    }

    private func makeZones() -> HeartRateZoneSnapshot {
        HeartRateZoneSnapshot(
            zoneCount: 5,
            paceUnit: .minPerKm,
            zones: [
                HeartRateZone(minHR: 100, maxHR: 120),
                HeartRateZone(minHR: 121, maxHR: 200),
                HeartRateZone(),
                HeartRateZone(),
                HeartRateZone()
            ],
            thresholdHR: nil,
            thresholdPaceSecPerKm: nil
        )
    }

    @Test func exposesScalarSignalsAtElapsedTime() {
        let data = OverlayComponentActivityData(
            activity: makeTimeline(),
            elapsedTime: 150,
            zoneSnapshot: makeZones(),
            canvasSize: CGSize(width: 1920, height: 1080),
            elementScale: 1.25
        )

        #expect(data.signal(path: "activity.elapsed") == .number(150))
        #expect(data.signal(path: "activity.remaining") == .number(450))
        #expect(data.signal(path: "activity.distance") == .number(750))
        #expect(data.signal(path: "activity.heartRate") == .number(130))
        #expect(data.signal(path: "activity.pace") == .number(300))
        #expect(data.signal(path: "activity.cadence") == .number(170))
        #expect(data.signal(path: "activity.temperature") == .number(18))
        #expect(data.signal(path: "host.canvasWidth") == .number(1920))
        #expect(data.signal(path: "host.canvasHeight") == .number(1080))
        #expect(data.signal(path: "host.scale") == .number(1.25))
        #expect(data.signal(path: "weather.current") == .null)
    }

    @Test func exposesZoneRecordWithPaletteColor() throws {
        let data = OverlayComponentActivityData(
            activity: makeTimeline(),
            elapsedTime: 150,
            zoneSnapshot: makeZones(),
            canvasSize: CGSize(width: 1280, height: 720),
            elementScale: 1
        )

        let zone = try #require(data.signal(path: "zone.heartRate").record)
        #expect(zone["index"] == .number(2))
        #expect(zone["count"] == .number(5))
        #expect(zone["label"] == .string("Z2"))
        #expect(zone["lower"] == .number(121))
        #expect(zone["upper"] == .number(200))
        #expect(zone["color"] == .color(HRZonePalette.overlayColor(forIndex: 1)))
    }

    @Test func samplesSeriesWithinWindow() throws {
        let data = OverlayComponentActivityData(
            activity: makeTimeline(),
            elapsedTime: 150,
            zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720),
            elementScale: 1
        )

        let series = try #require(
            data.series(path: "activity.heartRate", window: .relative(start: -120, end: 0), samples: 5)
                .list
        )
        #expect(series.count == 5)
        #expect(series.first == .number(106))
        #expect(series.last == .number(130))

        let fullDistance = try #require(
            data.series(path: "activity.distance", window: .full, samples: 3).list
        )
        #expect(fullDistance.first == .number(0))
        #expect(fullDistance.last == .number(3000))
    }

    @Test func exposesLapAndStructureRecords() throws {
        let structured = WorkoutStructureAnalysis(
            kind: .structured,
            subtype: .interval,
            source: .auto,
            confidence: 1,
            reason: "test"
        )
        let data = OverlayComponentActivityData(
            activity: makeTimeline(structure: structured),
            elapsedTime: 150,
            zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720),
            elementScale: 1
        )

        let lap = try #require(data.signal(path: "structure.currentLap").record)
        #expect(lap["index"] == .number(1))
        #expect(lap["avgPace"] == .number(300))
        #expect(lap["avgHeartRate"] == .number(140))
        #expect(lap["kind"] == .string("active"))

        let current = try #require(data.signal(path: "structure.current").record)
        #expect(current["phase"] == .string("active"))
        #expect(current["progress"] == .number(0.5))
        #expect(current["remaining"] == .number(150))

        let laps = try #require(data.list(path: "structure.laps").list)
        #expect(laps.count == 2)
        let intervals = try #require(data.list(path: "structure.intervals").list)
        #expect(intervals.count == 2)
    }

    @Test func exposesRoutePositionWithoutMediaTime() throws {
        let data = OverlayComponentActivityData(
            activity: makeTimeline(),
            elapsedTime: 450,
            zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720),
            elementScale: 1
        )

        let route = try #require(data.signal(path: "route.current").record)
        #expect(route["lat"] == .number(37.004))
        #expect(route["lon"] == .number(-121.996))
        #expect(route["distanceFraction"] == .number(0.75))
    }

    @Test func structuredSignalIsNullForNormalWorkouts() {
        let data = OverlayComponentActivityData(
            activity: makeTimeline(),
            elapsedTime: 150,
            zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720),
            elementScale: 1
        )
        #expect(data.signal(path: "structure.current") == .null)
    }
}
