import Foundation
import Testing
@testable import RunningOverlay

struct FitFileParserTests {
    @Test func parsesSyntheticRepositoryFixture() throws {
        let url = try #require(
            Bundle.module.url(
                forResource: "synthetic-run",
                withExtension: "fit",
                subdirectory: "Fixtures/Activities"
            )
        )

        let activity = try FitFileParser.parse(url: url)
        #expect(activity.duration == 60)
        #expect(activity.distanceMeters == 200)
        #expect(activity.records.count == 3)
        #expect(activity.records.map(\.heartRate) == [120, 145, 160])
        #expect(activity.records.last?.elapsedTime == 60)
    }

    @Test func parsesOptionalExternalFitSampleWhenProvided() throws {
        guard let path = ProcessInfo.processInfo.environment["RUNNING_OVERLAY_FIT_SAMPLE"] else {
            return
        }
        let activity = try FitFileParser.parse(url: URL(fileURLWithPath: path))
        #expect(activity.duration > 0)
        #expect(activity.records.count > 0)
    }

    @Test func parsesGoProStyleRunningVideoFilenames() throws {
        let date = try #require(FilenameDateParser.date(from: "PRO_VID_20260425_083915_00_001"))
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)

        #expect(components.year == 2026)
        #expect(components.month == 4)
        #expect(components.day == 25)
        #expect(components.hour == 8)
        #expect(components.minute == 39)
        #expect(components.second == 15)
    }
}
