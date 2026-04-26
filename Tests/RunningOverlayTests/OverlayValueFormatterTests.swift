import Foundation
import Testing
@testable import RunningOverlay

struct OverlayValueFormatterTests {
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
            ]
        )

        #expect(OverlayValueFormatter.value(for: .distance, activity: activity, elapsedTime: 5) == "0.05 km")
        #expect(OverlayValueFormatter.value(for: .heartRate, activity: activity, elapsedTime: 5) == "110 bpm")
    }

    @Test func formatsElapsedTime() {
        #expect(OverlayValueFormatter.formatDuration(65) == "01:05")
        #expect(OverlayValueFormatter.formatDuration(3661) == "1:01:01")
    }
}
