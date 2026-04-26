import Foundation
import Testing
@testable import RunningOverlay

struct FitFileParserTests {
    @Test func parsesProvidedFitSampleWhenAvailable() throws {
        let path = ProcessInfo.processInfo.environment["RUNNING_OVERLAY_FIT_SAMPLE"]
            ?? "/Users/codywang/Downloads/477043634401739053.fit"
        let url = URL(fileURLWithPath: path)

        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        let activity = try FitFileParser.parse(url: url)
        #expect(activity.duration > 0)
        #expect(activity.records.count > 0)
        #expect((activity.records.last?.elapsedTime ?? 0) > 0)
        #expect(Set(activity.records.compactMap(\.heartRate)).count > 1)
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
