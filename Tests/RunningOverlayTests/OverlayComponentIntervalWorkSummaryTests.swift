import Foundation
import Testing
@testable import RunningOverlay

struct OverlayComponentIntervalWorkSummaryTests {
    static func data() throws -> Data {
        let item = try #require(OverlayComponentLibraryItem.intervalComponents.first {
            $0.resourceName == "interval-work-summary"
        })
        return try #require(OverlayComponentLibrary.data(for: item))
    }

    @Test func bundledDefinitionResolvesWithWorkData() throws {
        let package = try OverlayComponentLoader.load(data: Self.data())
        let activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 1_735_689_600),
            duration: 180, distanceMeters: 600,
            records: (0...180).map { t in
                ActivityRecord(
                    elapsedTime: Double(t),
                    timestamp: Date(timeIntervalSince1970: 1_735_689_600 + Double(t)),
                    distanceMeters: Double(t) * 3.3, heartRate: 150,
                    paceSecondsPerKilometer: 300, elevationMeters: 20,
                    cadence: 176, powerWatts: 240, calories: Double(t) / 4
                )
            },
            laps: [
                LapRecord(lapIndex: 0, startElapsedTime: 0, endElapsedTime: 60,
                          startDistanceMeters: 0, totalDistanceMeters: 180,
                          totalElapsedTime: 60, avgPaceSecondsPerKm: 333,
                          avgHeartRate: 140, maxHeartRate: 145, avgCadenceSPM: 172,
                          avgPowerWatts: 220, totalAscent: nil, kind: .warmup),
                LapRecord(lapIndex: 1, startElapsedTime: 60, endElapsedTime: 120,
                          startDistanceMeters: 180, totalDistanceMeters: 400,
                          totalElapsedTime: 60, avgPaceSecondsPerKm: 300,
                          avgHeartRate: 170, maxHeartRate: 178, avgCadenceSPM: 180,
                          avgPowerWatts: 260, totalAscent: nil, kind: .active),
            ]
        )
        let data = OverlayComponentActivityData(
            activity: activity, elapsedTime: 125, zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720), elementScale: 1
        )
        let result = OverlayComponentResolver(definition: package.definition)
            .resolve(parameters: [:], data: data)
        #expect(result.diagnostics.isEmpty)
        #expect(!result.nodes.isEmpty)
        #expect(package.definition.id == "studio.interval-work-summary")
    }
}
