import Foundation
import Testing
@testable import RunningOverlay

/// Interpolation now walks records with a binary search because chart series
/// ask for hundreds of values per frame. These cases pin the previous
/// linear-scan semantics: exact records win, missing values are skipped, and
/// out-of-range times clamp to the nearest usable record.
struct ActivityTimelineInterpolationTests {
    private static let start = Date(timeIntervalSince1970: 1_735_689_600)

    /// Records at 0/10/20/30 s. Power is recorded only at 0 and 20 s; the
    /// route is recorded only at 0/10/20 s.
    private static func timeline() -> ActivityTimeline {
        let records: [ActivityRecord] = [
            ActivityRecord(
                elapsedTime: 0, timestamp: start, distanceMeters: 0,
                heartRate: 120, paceSecondsPerKilometer: 300,
                elevationMeters: nil, cadence: nil, powerWatts: 100, calories: nil,
                latitude: 40.0, longitude: -73.0
            ),
            ActivityRecord(
                elapsedTime: 10, timestamp: start.addingTimeInterval(10),
                distanceMeters: 50, heartRate: 140, paceSecondsPerKilometer: 300,
                elevationMeters: nil, cadence: nil, powerWatts: nil, calories: nil,
                latitude: 40.001, longitude: -73.001
            ),
            ActivityRecord(
                elapsedTime: 20, timestamp: start.addingTimeInterval(20),
                distanceMeters: 100, heartRate: 160, paceSecondsPerKilometer: 300,
                elevationMeters: nil, cadence: nil, powerWatts: 120, calories: nil,
                latitude: 40.002, longitude: -73.002
            ),
            ActivityRecord(
                elapsedTime: 30, timestamp: start.addingTimeInterval(30),
                distanceMeters: 150, heartRate: 170, paceSecondsPerKilometer: 300,
                elevationMeters: nil, cadence: nil, powerWatts: nil, calories: nil
            )
        ]
        return ActivityTimeline(
            startDate: start, duration: 30, distanceMeters: 150,
            records: records, laps: []
        )
    }

    @Test func metricsInterpolateBetweenRecords() {
        let activity = Self.timeline()
        #expect(activity.heartRate(at: 5) == 130)
        #expect(activity.heartRate(at: 10) == 140)
        #expect(activity.heartRate(at: 15) == 150)
    }

    @Test func outOfRangeTimesClampToNearestRecord() {
        let activity = Self.timeline()
        #expect(activity.heartRate(at: -5) == 120)
        #expect(activity.heartRate(at: 999) == 170)
    }

    @Test func missingValuesAreSkipped() {
        let activity = Self.timeline()
        // 0 s and 20 s carry power; the 5 s lookup crosses the missing 10 s
        // and blends over the whole 0-20 s span.
        #expect(activity.power(at: 5) == 105)
        // 10 s itself has no power: neighbours 0 s and 20 s blend to 110.
        #expect(activity.power(at: 10) == 110)
        // Nothing after 20 s has power, so the last value holds.
        #expect(activity.power(at: 25) == 120)
        #expect(activity.power(at: 30) == 120)
    }

    @Test func emptyTimelineReturnsNoValues() {
        let empty = ActivityTimeline(
            startDate: Self.start, duration: 60, distanceMeters: 0,
            records: [], laps: []
        )
        #expect(empty.heartRate(at: 10) == nil)
        #expect(empty.power(at: 10) == nil)
        #expect(empty.routePoint(at: 10) == nil)
    }

    @Test func routePointInterpolatesAndSkipsMissingCoordinates() throws {
        let activity = Self.timeline()
        let midpoint = try #require(activity.routePoint(at: 5))
        #expect(abs(midpoint.latitude - 40.0005) < 1e-9)
        #expect(abs(midpoint.longitude - (-73.0005)) < 1e-9)

        // 30 s has no coordinate; the 20 s point is the last usable one.
        let clampedEnd = try #require(activity.routePoint(at: 30))
        #expect(clampedEnd.elapsedTime == 20)
        #expect(abs(clampedEnd.latitude - 40.002) < 1e-9)

        // Before the first coordinate the route clamps to the first point.
        let clampedStart = try #require(activity.routePoint(at: -1))
        #expect(clampedStart.elapsedTime == 0)
    }
}
