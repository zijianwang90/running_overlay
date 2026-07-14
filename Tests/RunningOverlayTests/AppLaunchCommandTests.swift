import Foundation
import Testing
@testable import RunningOverlay

@MainActor
struct AppLaunchCommandTests {
    @Test func parsesFitAndVideoPaths() throws {
        let parsed = try AppLaunchCommand.parse(arguments: [
            "RunningOverlay",
            "--fit", "Fixtures/run.fit",
            "--video", "/tmp/run video.mp4",
            "--video", "/tmp/finish.mov"
        ])
        let command = try #require(parsed)

        #expect(command.fitURL?.path.hasSuffix("/Fixtures/run.fit") == true)
        #expect(command.videoURLs.map(\.path) == ["/tmp/run video.mp4", "/tmp/finish.mov"])
    }

    @Test func supportsEitherLaunchFileIndependently() throws {
        let parsedFit = try AppLaunchCommand.parse(arguments: [
            "RunningOverlay", "--fit", "~/run.fit"
        ])
        let parsedVideo = try AppLaunchCommand.parse(arguments: [
            "RunningOverlay", "--video", "run.mov"
        ])
        let fitOnly = try #require(parsedFit)
        let videoOnly = try #require(parsedVideo)

        #expect(fitOnly.fitURL?.path == FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("run.fit").path)
        #expect(fitOnly.videoURLs.isEmpty)
        #expect(videoOnly.fitURL == nil)
        #expect(videoOnly.videoURLs.first?.path.hasSuffix("/run.mov") == true)
    }

    @Test func returnsNilWithoutLaunchFileArguments() throws {
        #expect(try AppLaunchCommand.parse(arguments: ["RunningOverlay"]) == nil)
    }

    @Test func rejectsMissingArgumentValue() {
        #expect(throws: AppLaunchCommandError.missingValue("--fit")) {
            try AppLaunchCommand.parse(arguments: ["RunningOverlay", "--fit", "--video", "run.mov"])
        }
    }

    @Test func projectImportsFitDirectlyWithoutFilePicker() throws {
        let url = try #require(
            Bundle.module.url(
                forResource: "synthetic-run",
                withExtension: "fit",
                subdirectory: "Fixtures/Activities"
            )
        )
        let project = ProjectDocument()

        project.importFitURL(url)

        #expect(project.fitSourceName == "synthetic-run.fit")
        #expect(project.activity.duration == 60)
        #expect(project.activity.records.count == 3)
    }
}
