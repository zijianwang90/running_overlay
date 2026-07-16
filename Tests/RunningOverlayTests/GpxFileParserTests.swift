import Foundation
import Testing
@testable import RunningOverlay

struct GpxFileParserTests {
    @Test func parsesSyntheticRepositoryFixture() throws {
        let url = try fixtureURL()
        let activity = try GpxFileParser.parse(url: url)

        #expect(activity.startDate == ISO8601DateFormatter().date(from: "2025-01-01T12:00:00Z"))
        #expect(activity.duration == 30)
        #expect(activity.records.count == 4)
        #expect(activity.records.map(\.elapsedTime) == [0, 10, 20, 30])
        #expect(activity.distanceMeters > 20)
        #expect(activity.distanceMeters < 25)
        #expect(activity.records[1].heartRate == 140)
        #expect(activity.records[1].cadence == 172)
        #expect(activity.records[1].powerWatts == 250)
        #expect(activity.records[1].temperatureCelsius == 18.5)
        #expect(activity.records[1].genericFields["gpx.sample"] == 42)
        #expect(activity.records[0].paceSecondsPerKilometer == 1000.0 / 3.0)
        #expect(activity.records[3].powerWatts == 275)
        #expect(activity.routePoints.count == 4)
        #expect(activity.laps.isEmpty)
    }

    @Test func parsesOptionalExternalGPXSampleWhenProvided() throws {
        guard let path = ProcessInfo.processInfo.environment["RUNNING_OVERLAY_GPX_SAMPLE"] else {
            return
        }
        let activity = try GpxFileParser.parse(url: URL(fileURLWithPath: path))
        #expect(activity.duration > 0)
        #expect(activity.records.count > 1)
    }

    @Test func commonActivityParserRoutesGPXAndFITFiles() throws {
        let gpxURL = try fixtureURL()
        let gpx = try ActivityFileParser.parse(url: gpxURL)
        let fitURL = try #require(
            Bundle.module.url(
                forResource: "synthetic-run",
                withExtension: "fit",
                subdirectory: "Fixtures/Activities"
            )
        )
        let fit = try ActivityFileParser.parse(url: fitURL)

        #expect(gpx.duration == 30)
        #expect(fit.duration == 60)
        #expect(ActivityFileParser.format(for: gpxURL) == .gpx)
        #expect(ActivityFileParser.format(for: fitURL) == .fit)
    }

    @Test func rejectsGPXWithoutTimedTrackPoints() {
        let data = Data("""
        <gpx version="1.1"><trk><trkseg>
          <trkpt lat="43" lon="-79"><ele>100</ele></trkpt>
        </trkseg></trk></gpx>
        """.utf8)

        #expect(throws: GpxFileParserError.missingTrackPointTimes) {
            try GpxFileParser.parse(data: data)
        }
    }

    @Test func rejectsInvalidTimestamp() {
        let data = Data("""
        <gpx version="1.1"><trk><trkseg>
          <trkpt lat="43" lon="-79"><time>not-a-date</time></trkpt>
        </trkseg></trk></gpx>
        """.utf8)

        do {
            _ = try GpxFileParser.parse(data: data)
            Issue.record("Expected an invalid timestamp error")
        } catch let error as GpxFileParserError {
            #expect(error.localizedDescription.contains("ISO 8601"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test @MainActor func projectImportsGPXAndRestoresSourceNameOnUndo() throws {
        let project = ProjectDocument()

        project.importActivityURL(try fixtureURL())

        #expect(project.activitySourceName == "synthetic-run.gpx")
        #expect(project.activity.duration == 30)
        #expect(project.statusMessage.contains("Loaded GPX"))

        project.undo()

        #expect(project.activity == .empty)
        #expect(project.activitySourceName.isEmpty)
    }

    private func fixtureURL() throws -> URL {
        try #require(
            Bundle.module.url(
                forResource: "synthetic-run",
                withExtension: "gpx",
                subdirectory: "Fixtures/Activities"
            )
        )
    }
}
