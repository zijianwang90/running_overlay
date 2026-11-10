import Foundation
import Testing
@testable import RunningOverlay

struct OverlayValueFormatterTests {
    /// Value and unit as the former native numeric overlays assembled them.
    private func text(
        _ metric: OverlayMetric,
        unit: OverlayUnitOption? = nil,
        activity: ActivityTimeline,
        at elapsedTime: TimeInterval
    ) -> String {
        let components = OverlayValueFormatter.components(
            for: metric,
            unit: unit,
            activity: activity,
            elapsedTime: elapsedTime
        )
        guard !components.unit.isEmpty else { return components.value }
        return components.unit.hasPrefix("/")
            ? components.value + components.unit
            : components.value + " " + components.unit
    }

    @Test func formatsInterpolatedDistanceAndHeartRate() {
        let startDate = Date(timeIntervalSince1970: 1_000)
        let activity = ActivityTimeline(
            startDate: startDate,
            duration: 10,
            distanceMeters: 100,
            records: [
                ActivityRecord(
                    elapsedTime: 0,
                    timestamp: startDate,
                    distanceMeters: 0,
                    heartRate: 100,
                    paceSecondsPerKilometer: nil,
                    elevationMeters: nil,
                    cadence: nil,
                    powerWatts: nil,
                    calories: nil
                ),
                ActivityRecord(
                    elapsedTime: 10,
                    timestamp: startDate.addingTimeInterval(10),
                    distanceMeters: 100,
                    heartRate: 120,
                    paceSecondsPerKilometer: nil,
                    elevationMeters: nil,
                    cadence: nil,
                    powerWatts: nil,
                    calories: nil
                )
            ],
            laps: []
        )

        #expect(text(.distance, activity: activity, at: 5) == "0.05 km")
        #expect(text(.heartRate, activity: activity, at: 5) == "110 bpm")
    }

    @Test func formatsElapsedTime() {
        #expect(OverlayValueFormatter.formatDuration(65) == "00:01:05")
        #expect(OverlayValueFormatter.formatDuration(600, option: .durationHMS) == "00:10:00")
        #expect(OverlayValueFormatter.formatDuration(3661) == "01:01:01")
    }

    @Test func formatsActivityDateWithCommonStyles() {
        let timestamp = Date(timeIntervalSince1970: 1_718_452_800) // 2024-06-15 12:00:00 UTC
        let activity = ActivityTimeline(
            startDate: timestamp,
            duration: 0,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        #expect(text(.date, unit: .dateYMDHyphen, activity: activity, at: 0) == "2024-06-15")
        #expect(text(.date, unit: .dateMDYSlash, activity: activity, at: 0) == "06/15/2024")
        #expect(text(.date, unit: .dateMDSlash, activity: activity, at: 0) == "06/15")
        #expect(text(.date, unit: .dateMonthDay, activity: activity, at: 0) == "Jun 15")
    }

    @Test func elapsedTimeOverlayExcludesTimerPausedSegments() {
        let startDate = Date(timeIntervalSince1970: 0)
        let activity = ActivityTimeline(
            startDate: startDate,
            duration: 300,
            distanceMeters: 1000,
            records: [],
            laps: [],
            annotatedSegments: [
                ActivityAnnotatedSegment(kind: .timerPaused, startElapsedTime: 60, endElapsedTime: 120),
                ActivityAnnotatedSegment(kind: .timerPaused, startElapsedTime: 180, endElapsedTime: 210)
            ]
        )

        #expect(activity.activeElapsedTime(at: 50) == 50)
        #expect(activity.activeElapsedTime(at: 90) == 60)
        #expect(activity.activeElapsedTime(at: 150) == 90)
        #expect(activity.activeElapsedTime(at: 240) == 150)
        #expect(text(.elapsedTime, activity: activity, at: 240) == "00:02:30")
    }

    @Test func formatsHeartRateZoneComponents() {
        let startDate = Date(timeIntervalSince1970: 0)
        let activity = ActivityTimeline(
            startDate: startDate,
            duration: 60,
            distanceMeters: 1000,
            records: [
                ActivityRecord(
                    elapsedTime: 0,
                    timestamp: startDate,
                    distanceMeters: 0,
                    heartRate: 120,
                    paceSecondsPerKilometer: nil,
                    elevationMeters: nil,
                    cadence: nil,
                    powerWatts: nil,
                    calories: nil
                )
            ],
            laps: []
        )
        let components = OverlayValueFormatter.components(for: OverlayMetric.heartRateZone, activity: activity, elapsedTime: 0)
        #expect(components.label == "HR Zone")
        #expect(components.shortLabel == "ZONE")
        #expect(components.unit == "")
    }

    @Test func numericOverlayHonorsUnitOption() {
        let startDate = Date(timeIntervalSince1970: 0)
        let activity = ActivityTimeline(
            startDate: startDate,
            duration: 120,
            distanceMeters: 1000,
            records: [
                ActivityRecord(
                    elapsedTime: 0, timestamp: startDate, distanceMeters: 0,
                    heartRate: 150, paceSecondsPerKilometer: 300, elevationMeters: 100,
                    cadence: 180, powerWatts: 250, calories: 0
                ),
                ActivityRecord(
                    elapsedTime: 60, timestamp: startDate.addingTimeInterval(60), distanceMeters: 1000,
                    heartRate: 150, paceSecondsPerKilometer: 300, elevationMeters: 100,
                    cadence: 180, powerWatts: 250, calories: 50
                )
            ],
            laps: []
        )

        #expect(text(.pace, unit: .paceImperial, activity: activity, at: 30) == "8'03\"/mi")
        #expect(text(.pace, unit: .paceRowing, activity: activity, at: 30) == "2'30\"/500m")
        #expect(text(.distance, unit: .distanceMiles, activity: activity, at: 30) == "0.31 mi")
        #expect(text(.distance, unit: .distanceMeters, activity: activity, at: 30) == "500 m")
        #expect(text(.elevation, unit: .elevationFeet, activity: activity, at: 30) == "328 ft")
        #expect(text(.elevationGain, unit: .elevationMeters, activity: activity, at: 30) == "0 m")
        #expect(text(.elapsedTime, unit: .durationSeconds, activity: activity, at: 65) == "65")
        // A unit from another metric family falls back to the metric default.
        #expect(text(.distance, unit: .paceImperial, activity: activity, at: 30) == "0.50 km")
    }

    @Test func temperatureFormatsFITTemperature() {
        let startDate = Date(timeIntervalSince1970: 0)
        let activity = ActivityTimeline(
            startDate: startDate,
            duration: 60,
            distanceMeters: 0,
            records: [
                ActivityRecord(
                    elapsedTime: 0, timestamp: startDate, distanceMeters: 0,
                    heartRate: nil, paceSecondsPerKilometer: nil, elevationMeters: nil,
                    cadence: nil, powerWatts: nil, calories: nil,
                    temperatureCelsius: 10
                ),
                ActivityRecord(
                    elapsedTime: 60, timestamp: startDate.addingTimeInterval(60), distanceMeters: 0,
                    heartRate: nil, paceSecondsPerKilometer: nil, elevationMeters: nil,
                    cadence: nil, powerWatts: nil, calories: nil,
                    temperatureCelsius: 20
                )
            ],
            laps: []
        )

        #expect(text(.temperature, unit: .temperatureCelsius, activity: activity, at: 30) == "15° °C")
        #expect(text(.temperature, unit: .temperatureFahrenheit, activity: activity, at: 30) == "59° °F")
        let missing = ActivityTimeline(startDate: startDate, duration: 60, distanceMeters: 0, records: [], laps: [])
        #expect(text(.temperature, activity: missing, at: 30) == "-- °C")
    }

    @Test func elevationOverlayCanSwitchBetweenCurrentAndGain() {
        let startDate = Date(timeIntervalSince1970: 0)
        let activity = ActivityTimeline(
            startDate: startDate,
            duration: 30,
            distanceMeters: 1000,
            records: [
                ActivityRecord(
                    elapsedTime: 0, timestamp: startDate, distanceMeters: 0,
                    heartRate: nil, paceSecondsPerKilometer: nil, elevationMeters: 100,
                    cadence: nil, powerWatts: nil, calories: nil
                ),
                ActivityRecord(
                    elapsedTime: 10, timestamp: startDate.addingTimeInterval(10), distanceMeters: 300,
                    heartRate: nil, paceSecondsPerKilometer: nil, elevationMeters: 110,
                    cadence: nil, powerWatts: nil, calories: nil
                ),
                ActivityRecord(
                    elapsedTime: 20, timestamp: startDate.addingTimeInterval(20), distanceMeters: 700,
                    heartRate: nil, paceSecondsPerKilometer: nil, elevationMeters: 105,
                    cadence: nil, powerWatts: nil, calories: nil
                ),
                ActivityRecord(
                    elapsedTime: 30, timestamp: startDate.addingTimeInterval(30), distanceMeters: 1000,
                    heartRate: nil, paceSecondsPerKilometer: nil, elevationMeters: 125,
                    cadence: nil, powerWatts: nil, calories: nil
                )
            ],
            laps: []
        )

        #expect(text(.elevation, activity: activity, at: 25) == "115 m")
        #expect(text(.elevationGain, activity: activity, at: 25) == "20 m")
        let components = OverlayValueFormatter.components(for: OverlayMetric.elevationGain, activity: activity, elapsedTime: 25)
        #expect(components.label == "Elevation Gain")
        #expect(components.shortLabel == "GAIN")
    }

    @Test func customLabelReplacesDefaultLabel() {
        let startDate = Date(timeIntervalSince1970: 0)
        let activity = ActivityTimeline(
            startDate: startDate,
            duration: 10,
            distanceMeters: 0,
            records: [
                ActivityRecord(elapsedTime: 0, timestamp: startDate, distanceMeters: 0, heartRate: 120, paceSecondsPerKilometer: nil, elevationMeters: nil, cadence: nil, powerWatts: nil, calories: nil),
                ActivityRecord(elapsedTime: 10, timestamp: startDate.addingTimeInterval(10), distanceMeters: 0, heartRate: 120, paceSecondsPerKilometer: nil, elevationMeters: nil, cadence: nil, powerWatts: nil, calories: nil)
            ],
            laps: []
        )

        let custom = OverlayValueFormatter.components(
            for: OverlayMetric.heartRate,
            customLabel: "  BPM ",
            activity: activity,
            elapsedTime: 5
        )
        #expect(custom.label == "BPM")
        #expect(custom.value == "120")
        let blank = OverlayValueFormatter.components(for: OverlayMetric.heartRate, customLabel: "  ", activity: activity, elapsedTime: 5)
        #expect(blank.label == "Heart Rate")
    }

    @Test func avgPaceUsesCumulativeSessionAverage() {
        let startDate = Date(timeIntervalSince1970: 0)
        let activity = ActivityTimeline(
            startDate: startDate,
            duration: 60,
            distanceMeters: 1000,
            records: [
                ActivityRecord(
                    elapsedTime: 0, timestamp: startDate, distanceMeters: 0,
                    heartRate: nil, paceSecondsPerKilometer: nil, elevationMeters: nil,
                    cadence: nil, powerWatts: nil, calories: nil
                ),
                ActivityRecord(
                    elapsedTime: 60, timestamp: startDate.addingTimeInterval(60), distanceMeters: 1000,
                    heartRate: nil, paceSecondsPerKilometer: nil, elevationMeters: nil,
                    cadence: nil, powerWatts: nil, calories: nil
                )
            ],
            laps: []
        )

        #expect(activity.avgPace(at: 60) == 60)
        #expect(activity.avgPace(at: 0) == nil)
        #expect(text(.avgPace, activity: activity, at: 60) == "1'00\"/km")
        #expect(text(.avgPace, activity: activity, at: 0) == "--'--\"/km")
    }

    @Test func lapPaceUsesRunningAverageWithinCurrentLap() {
        let startDate = Date(timeIntervalSince1970: 0)
        let activity = ActivityTimeline(
            startDate: startDate,
            duration: 200,
            distanceMeters: 500,
            records: [
                ActivityRecord(
                    elapsedTime: 0, timestamp: startDate, distanceMeters: 0,
                    heartRate: nil, paceSecondsPerKilometer: nil, elevationMeters: nil,
                    cadence: nil, powerWatts: nil, calories: nil
                ),
                ActivityRecord(
                    elapsedTime: 100, timestamp: startDate.addingTimeInterval(100), distanceMeters: 200,
                    heartRate: nil, paceSecondsPerKilometer: nil, elevationMeters: nil,
                    cadence: nil, powerWatts: nil, calories: nil
                ),
                ActivityRecord(
                    elapsedTime: 160, timestamp: startDate.addingTimeInterval(160), distanceMeters: 360,
                    heartRate: nil, paceSecondsPerKilometer: nil, elevationMeters: nil,
                    cadence: nil, powerWatts: nil, calories: nil
                ),
                ActivityRecord(
                    elapsedTime: 200, timestamp: startDate.addingTimeInterval(200), distanceMeters: 500,
                    heartRate: nil, paceSecondsPerKilometer: nil, elevationMeters: nil,
                    cadence: nil, powerWatts: nil, calories: nil
                )
            ],
            laps: [
                LapRecord(
                    lapIndex: 0, startElapsedTime: 100, endElapsedTime: 200,
                    startDistanceMeters: 200, totalDistanceMeters: 300, totalElapsedTime: 100,
                    avgPaceSecondsPerKm: nil, avgHeartRate: nil, maxHeartRate: nil,
                    avgCadenceSPM: nil, avgPowerWatts: nil, totalAscent: nil, kind: .active
                )
            ]
        )

        #expect(activity.lapPace(at: 99) == nil)
        #expect(activity.lapPace(at: 160) == 375)
        #expect(text(.lapPace, activity: activity, at: 160) == "6'15\"/km")
    }

    @Test func lapPaceRoundsAcrossMinuteBoundary() {
        let startDate = Date(timeIntervalSince1970: 0)
        let activity = ActivityTimeline(
            startDate: startDate,
            duration: 300,
            distanceMeters: 1000,
            records: [
                ActivityRecord(
                    elapsedTime: 0, timestamp: startDate, distanceMeters: 0,
                    heartRate: nil, paceSecondsPerKilometer: nil, elevationMeters: nil,
                    cadence: nil, powerWatts: nil, calories: nil
                ),
                ActivityRecord(
                    elapsedTime: 239.6, timestamp: startDate.addingTimeInterval(239.6), distanceMeters: 1000,
                    heartRate: nil, paceSecondsPerKilometer: nil, elevationMeters: nil,
                    cadence: nil, powerWatts: nil, calories: nil
                )
            ],
            laps: [
                LapRecord(
                    lapIndex: 0, startElapsedTime: 0, endElapsedTime: 300,
                    startDistanceMeters: 0, totalDistanceMeters: 1000, totalElapsedTime: 300,
                    avgPaceSecondsPerKm: nil, avgHeartRate: nil, maxHeartRate: nil,
                    avgCadenceSPM: nil, avgPowerWatts: nil, totalAscent: nil, kind: .active
                )
            ]
        )

        #expect(text(.lapPace, activity: activity, at: 239.6) == "4'00\"/km")
    }

}
