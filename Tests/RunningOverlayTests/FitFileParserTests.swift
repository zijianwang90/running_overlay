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

    @Test func estimatesRecordCaloriesFromLapTotalsWhenRecordsOmitCalories() throws {
        var parser = FitFileParser(data: fitDataWithLapCaloriesOnly())
        let activity = try parser.parse()

        #expect(activity.duration == 60)
        #expect(activity.records.map(\.calories) == [0, 40, 100])
        #expect(activity.calories(at: 15) == 20)
        #expect(activity.calories(at: 45) == 70)
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

    private func fitDataWithLapCaloriesOnly() -> Data {
        let startUnix: UInt32 = 1_735_689_600
        let startFit = startUnix - 631_065_600
        var data = Data()

        let sessionFields: [(UInt8, UInt8, UInt8)] = [
            (2, 4, 0x86),   // start_time
            (7, 4, 0x86),   // total_elapsed_time, milliseconds
            (9, 4, 0x86),   // total_distance, centimeters
            (11, 2, 0x84),  // total_calories
        ]
        data.append(fitDefinition(local: 0, globalMessage: 18, fields: sessionFields))
        data.append(0)
        appendUInt32(startFit, to: &data)
        appendUInt32(60_000, to: &data)
        appendUInt32(20_000, to: &data)
        appendUInt16(100, to: &data)

        let recordFields: [(UInt8, UInt8, UInt8)] = [
            (253, 4, 0x86), // timestamp
            (5, 4, 0x86),   // distance
        ]
        data.append(fitDefinition(local: 1, globalMessage: 20, fields: recordFields))
        for (seconds, distance) in [(0, 0), (30, 10_000), (60, 20_000)] {
            data.append(1)
            appendUInt32(startFit + UInt32(seconds), to: &data)
            appendUInt32(UInt32(distance), to: &data)
        }

        let lapFields: [(UInt8, UInt8, UInt8)] = [
            (2, 4, 0x86),   // start_time
            (7, 4, 0x86),   // total_elapsed_time, milliseconds
            (9, 4, 0x86),   // total_distance, centimeters
            (11, 2, 0x84),  // total_calories
            (253, 4, 0x86), // timestamp
        ]
        data.append(fitDefinition(local: 2, globalMessage: 19, fields: lapFields))
        for (startSeconds, elapsedMilliseconds, distance, calories) in [
            (0, 30_000, 10_000, 40),
            (30, 30_000, 10_000, 60),
        ] {
            data.append(2)
            appendUInt32(startFit + UInt32(startSeconds), to: &data)
            appendUInt32(UInt32(elapsedMilliseconds), to: &data)
            appendUInt32(UInt32(distance), to: &data)
            appendUInt16(UInt16(calories), to: &data)
            appendUInt32(startFit + UInt32(startSeconds + 30), to: &data)
        }

        var header = Data([14, 0x10])
        appendUInt16(0, to: &header)
        appendUInt32(UInt32(data.count), to: &header)
        header.append(contentsOf: ".FIT".utf8)
        header.append(contentsOf: [0, 0])
        header.append(data)
        return header
    }

    private func fitDefinition(
        local: UInt8,
        globalMessage: UInt16,
        fields: [(UInt8, UInt8, UInt8)]
    ) -> Data {
        var payload = Data([0x40 | local, 0, 0])
        appendUInt16(globalMessage, to: &payload)
        payload.append(UInt8(fields.count))
        for field in fields {
            payload.append(contentsOf: [field.0, field.1, field.2])
        }
        return payload
    }

    private func appendUInt16(_ value: UInt16, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }

    private func appendUInt32(_ value: UInt32, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }
}
