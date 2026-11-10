import Foundation
import Testing
@testable import RunningOverlay

struct OverlayComponentIntervalCountdownTests {
    static func data() throws -> Data {
        let item = try #require(OverlayComponentLibraryItem.intervalComponents.first)
        return try #require(OverlayComponentLibrary.data(for: item))
    }

    @Test func bundledDefinitionResolvesWithSegmentData() throws {
        let package = try OverlayComponentLoader.load(data: Self.data())
        let activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 1_735_689_600),
            duration: 60, distanceMeters: 200,
            records: (0...60).map { t in
                ActivityRecord(
                    elapsedTime: Double(t), timestamp: Date(timeIntervalSince1970: 1_735_689_600 + Double(t)),
                    distanceMeters: Double(t) * 3.3, heartRate: 150,
                    paceSecondsPerKilometer: 300, elevationMeters: 20,
                    cadence: 176, powerWatts: 240, calories: Double(t) / 4
                )
            },
            laps: [LapRecord(
                lapIndex: 0, startElapsedTime: 0, endElapsedTime: 60,
                startDistanceMeters: 0, totalDistanceMeters: 198,
                totalElapsedTime: 60, avgPaceSecondsPerKm: 300,
                avgHeartRate: 150, maxHeartRate: 155, avgCadenceSPM: 176,
                avgPowerWatts: 240, totalAscent: nil, kind: .active
            )]
        )
        let data = OverlayComponentActivityData(
            activity: activity, elapsedTime: 30, zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720), elementScale: 1
        )
        let result = OverlayComponentResolver(definition: package.definition)
            .resolve(parameters: [:], data: data)
        #expect(result.diagnostics.isEmpty)
        #expect(!result.nodes.isEmpty)
        #expect(package.definition.id == "studio.interval-countdown")
    }
}
