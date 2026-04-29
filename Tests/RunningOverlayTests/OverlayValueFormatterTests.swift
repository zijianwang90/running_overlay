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
            ],
            laps: []
        )

        #expect(OverlayValueFormatter.value(for: .distance, activity: activity, elapsedTime: 5) == "0.05 km")
        #expect(OverlayValueFormatter.value(for: .heartRate, activity: activity, elapsedTime: 5) == "110 bpm")
    }

    @Test func formatsElapsedTime() {
        #expect(OverlayValueFormatter.formatDuration(65) == "00:01:05")
        #expect(OverlayValueFormatter.formatDuration(600, option: .durationHMS) == "00:10:00")
        #expect(OverlayValueFormatter.formatDuration(3661) == "01:01:01")
    }

    @Test func numericOverlayHonorsUnitOption() {
        let startDate = Date(timeIntervalSince1970: 0)
        let activity = ActivityTimeline(
            startDate: startDate,
            duration: 60,
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

        var paceElement = OverlayElement(type: .pace, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: .default)
        paceElement.style.unitOption = .paceImperial
        #expect(OverlayValueFormatter.value(for: paceElement, activity: activity, elapsedTime: 30) == "8'03\"/mi")

        paceElement.style.unitOption = .paceRowing
        #expect(OverlayValueFormatter.value(for: paceElement, activity: activity, elapsedTime: 30) == "2'30\"/500m")

        var distanceElement = OverlayElement(type: .distance, position: CGPoint(x: 0, y: 0), scale: 1, style: .default)
        distanceElement.style.unitOption = .distanceMiles
        #expect(OverlayValueFormatter.value(for: distanceElement, activity: activity, elapsedTime: 30) == "0.31 mi")

        distanceElement.style.unitOption = .distanceMeters
        #expect(OverlayValueFormatter.value(for: distanceElement, activity: activity, elapsedTime: 30) == "500 m")

        var elevationElement = OverlayElement(type: .elevation, position: CGPoint(x: 0, y: 0), scale: 1, style: .default)
        elevationElement.style.unitOption = .elevationFeet
        #expect(OverlayValueFormatter.value(for: elevationElement, activity: activity, elapsedTime: 30) == "328 ft")

        var elapsed = OverlayElement(type: .elapsedTime, position: CGPoint(x: 0, y: 0), scale: 1, style: .default)
        elapsed.style.unitOption = .durationSeconds
        #expect(OverlayValueFormatter.value(for: elapsed, activity: activity, elapsedTime: 65) == "65")
    }

    @Test func numericOverlayHonorsLabelAndUnitFlags() {
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

        var element = OverlayElement(type: .heartRate, position: .zero, scale: 1, style: .default)
        element.style.showLabel = true
        element.style.showUnit = true
        element.style.customLabel = "BPM"
        #expect(OverlayValueFormatter.value(for: element, activity: activity, elapsedTime: 5) == "BPM 120 bpm")

        element.style.showUnit = false
        #expect(OverlayValueFormatter.value(for: element, activity: activity, elapsedTime: 5) == "BPM 120")

        element.style.showLabel = false
        element.style.customLabel = ""
        element.style.showUnit = true
        #expect(OverlayValueFormatter.value(for: element, activity: activity, elapsedTime: 5) == "120 bpm")
    }
}
