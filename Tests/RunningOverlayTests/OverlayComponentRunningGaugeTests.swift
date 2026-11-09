import Foundation
import Testing
@testable import RunningOverlay

struct OverlayComponentRunningGaugeTests {
    static func data() throws -> Data {
        let item = try #require(OverlayComponentLibraryItem.chartComponents.first {
            $0.resourceName == "running-gauge"
        })
        return try #require(OverlayComponentLibrary.data(for: item))
    }

    @Test func bundledDefinitionResolves() throws {
        let package = try OverlayComponentLoader.load(data: Self.data())
        let activity = Self.activity()
        let data = OverlayComponentActivityData(
            activity: activity, elapsedTime: 90, zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720), elementScale: 1
        )
        let result = OverlayComponentResolver(definition: package.definition)
            .resolve(parameters: [:], data: data)
        #expect(result.diagnostics.isEmpty, "\(result.diagnostics)")
        #expect(package.definition.id == "studio.running-gauge")
        #expect(!result.nodes.isEmpty)
    }

    static func activity() -> ActivityTimeline {
        let start = Date(timeIntervalSince1970: 1_735_689_600)
        var records: [ActivityRecord] = []
        var t: TimeInterval = 0
        while t <= 600 {
            records.append(ActivityRecord(
                elapsedTime: t, timestamp: start.addingTimeInterval(t),
                distanceMeters: t * 3.2, heartRate: 148 + Int(t / 120),
                paceSecondsPerKilometer: 312, elevationMeters: 20 + sin(t / 90) * 6,
                cadence: 176, powerWatts: 245, calories: t / 4
            ))
            t += 1
        }
        let laps = [LapRecord(
            lapIndex: 0, startElapsedTime: 0, endElapsedTime: 600,
            startDistanceMeters: 0, totalDistanceMeters: 1920,
            totalElapsedTime: 600, avgPaceSecondsPerKm: 312,
            avgHeartRate: 152, maxHeartRate: 160, avgCadenceSPM: 176,
            avgPowerWatts: 245, totalAscent: 30, kind: .active
        )]
        return ActivityTimeline(
            startDate: start, duration: 600, distanceMeters: 1920,
            records: records, laps: laps
        )
    }
}
