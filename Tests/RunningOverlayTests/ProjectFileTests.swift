import Foundation
import Testing
@testable import RunningOverlay

@MainActor
struct ProjectFileTests {
    @Test func savedProjectReopensWithContentAndCleanState() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }

        let project = fixture.makeProject()
        #expect(!project.hasUnsavedChanges)
        #expect(project.projectDisplayName == "Untitled")

        project.addOverlayElement(.heartRate)
        project.setPreviewTrackName("Camera A")
        #expect(project.hasUnsavedChanges)

        let url = fixture.directory.appendingPathComponent("Morning Run.roproj")
        try project.writeProject(to: url)
        #expect(!project.hasUnsavedChanges)
        #expect(project.projectFileURL == url)
        #expect(project.projectDisplayName == "Morning Run")

        let reopened = fixture.makeProject()
        let offline = try reopened.loadProject(from: url)
        #expect(offline.isEmpty)
        #expect(reopened.overlayLayout.elements.map(\.type) == [.heartRate])
        #expect(reopened.settings.previewTrackName == "Camera A")
        #expect(reopened.projectFileURL == url)
        #expect(!reopened.hasUnsavedChanges)
        #expect(!reopened.canUndo)
    }

    @Test func editsUndoAndRedoMarkTheProjectEdited() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }

        let project = fixture.makeProject()
        project.addOverlayElement(.pace)
        try project.writeProject(to: fixture.directory.appendingPathComponent("a.roproj"))
        #expect(!project.hasUnsavedChanges)

        project.undo()
        #expect(project.hasUnsavedChanges)

        try project.writeProject(to: fixture.directory.appendingPathComponent("a.roproj"))
        project.redo()
        #expect(project.hasUnsavedChanges)
    }

    @Test func newProjectClearsContentAndFileAssociation() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }

        let project = fixture.makeProject()
        project.addOverlayElement(.pace)
        try project.writeProject(to: fixture.directory.appendingPathComponent("a.roproj"))
        project.addOverlayElement(.heartRate)

        project.resetToNewProject()

        #expect(project.overlayLayout.elements.isEmpty)
        #expect(project.projectFileURL == nil)
        #expect(!project.hasUnsavedChanges)
        #expect(!project.canUndo)
    }

    @Test func mediaBookmarksFollowMovedFilesAndReportMissingOnes() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }

        let originalURL = fixture.directory.appendingPathComponent("clip.mov")
        let missingURL = fixture.directory.appendingPathComponent("gone.mov")
        try Data([0]).write(to: originalURL)
        try Data([0]).write(to: missingURL)

        let project = fixture.makeProject()
        project.mediaItems = [
            fixture.mediaItem(named: "clip.mov", url: originalURL),
            fixture.mediaItem(named: "gone.mov", url: missingURL)
        ]
        let projectURL = fixture.directory.appendingPathComponent("media.roproj")
        try project.writeProject(to: projectURL)
        #expect(project.mediaItems.allSatisfy { $0.bookmarkData != nil })

        let movedURL = fixture.directory.appendingPathComponent("renamed.mov")
        try FileManager.default.moveItem(at: originalURL, to: movedURL)
        try FileManager.default.removeItem(at: missingURL)

        let reopened = fixture.makeProject()
        let offline = try reopened.loadProject(from: projectURL)

        #expect(reopened.mediaItems[0].fileURL?.standardizedFileURL.resolvingSymlinksInPath()
            == movedURL.standardizedFileURL.resolvingSymlinksInPath())
        #expect(offline == [reopened.mediaItems[1].id])
    }

    @Test func relinkingFindsSameNamedFilesInAFolder() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }

        let searchFolder = fixture.directory.appendingPathComponent("Card/DCIM", isDirectory: true)
        try FileManager.default.createDirectory(at: searchFolder, withIntermediateDirectories: true)
        let foundURL = searchFolder.appendingPathComponent("GX010001.MP4")
        try Data([0]).write(to: foundURL)

        let project = fixture.makeProject()
        let offlineItem = fixture.mediaItem(
            named: "GX010001.MP4",
            url: URL(fileURLWithPath: "/Volumes/Missing/GX010001.MP4")
        )
        let unmatchedItem = fixture.mediaItem(
            named: "other.mov",
            url: URL(fileURLWithPath: "/Volumes/Missing/other.mov")
        )
        project.mediaItems = [offlineItem, unmatchedItem]

        let relinked = project.relinkMediaItems([offlineItem.id, unmatchedItem.id], searchingIn: fixture.directory)

        #expect(relinked == 1)
        #expect(project.mediaItems[0].fileURL?.lastPathComponent == "GX010001.MP4")
        #expect(project.mediaItems[0].fileURL?.deletingLastPathComponent().lastPathComponent == "DCIM")
        #expect(project.mediaItems[0].bookmarkData != nil)
        #expect(project.mediaItems[1].fileURL?.path == "/Volumes/Missing/other.mov")
        #expect(project.hasUnsavedChanges)

        project.undo()
        #expect(project.mediaItems[0].fileURL?.path == "/Volumes/Missing/GX010001.MP4")
    }

    @Test func workoutStructureSelectionIsSaved() throws {
        let snapshot = ProjectPerformanceSnapshot(
            settings: ProjectSettings(),
            activity: .empty,
            mediaItems: [],
            mediaFolders: [],
            timeline: .empty,
            overlayElements: [],
            userAssets: [],
            fitSourceName: "",
            workoutStructureSelection: .structured
        )

        let decoded = try ProjectFileFormat.decode(ProjectFileFormat.encode(snapshot))

        #expect(decoded.workoutStructureSelection == .structured)
    }

    @Test func filesWithoutNewOptionalFieldsStillDecode() throws {
        let snapshot = ProjectPerformanceSnapshot(
            settings: ProjectSettings(),
            activity: .empty,
            mediaItems: [MediaItem(
                displayName: "a.mov",
                fileURL: URL(fileURLWithPath: "/tmp/a.mov"),
                duration: 3,
                inferredStartDate: nil,
                cameraGroupID: "A",
                alignmentStatus: .needsManualPlacement
            )],
            mediaFolders: [],
            timeline: .empty,
            overlayElements: [],
            userAssets: [],
            fitSourceName: ""
        )
        var object = try #require(
            JSONSerialization.jsonObject(with: ProjectFileFormat.encode(snapshot)) as? [String: Any]
        )
        object.removeValue(forKey: "workoutStructureSelection")
        var items = try #require(object["mediaItems"] as? [[String: Any]])
        items[0].removeValue(forKey: "bookmarkData")
        object["mediaItems"] = items

        let decoded = try ProjectFileFormat.decode(JSONSerialization.data(withJSONObject: object))

        #expect(decoded.workoutStructureSelection == nil)
        #expect(decoded.mediaItems[0].bookmarkData == nil)
        #expect(decoded.mediaItems[0].displayName == "a.mov")
    }

    @Test func newerSchemaVersionIsRejectedWithAClearError() throws {
        let data = Data(#"{"schemaVersion": 99, "somethingNew": true}"#.utf8)

        #expect(throws: ProjectFileError.newerSchemaVersion(99)) {
            try ProjectFileFormat.decode(data)
        }
    }

    @Test func recentProjectsAreMostRecentFirstDedupedAndCapped() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }

        let project = fixture.makeProject()
        for index in 0..<12 {
            try project.writeProject(to: fixture.directory.appendingPathComponent("p\(index).roproj"))
        }
        try project.writeProject(to: fixture.directory.appendingPathComponent("p3.roproj"))

        #expect(project.recentProjectPaths.count == RecentProjectStore.limit)
        #expect(URL(fileURLWithPath: project.recentProjectPaths[0]).lastPathComponent == "p3.roproj")
        #expect(URL(fileURLWithPath: project.recentProjectPaths[1]).lastPathComponent == "p11.roproj")
        #expect(Set(project.recentProjectPaths).count == project.recentProjectPaths.count)

        let relaunched = fixture.makeProject()
        #expect(relaunched.recentProjectPaths == project.recentProjectPaths)

        relaunched.clearRecentProjects()
        #expect(relaunched.recentProjectPaths.isEmpty)
        #expect(fixture.makeProject().recentProjectPaths.isEmpty)
    }
}

@MainActor
private struct Fixture {
    let directory: URL
    let suiteName = "RunningOverlayTests-ProjectFile-\(UUID().uuidString)"
    let defaults: UserDefaults

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("running-overlay-project-file-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    func makeProject() -> ProjectDocument {
        ProjectDocument(userDefaults: defaults, credentialStore: InMemoryCredentialStore())
    }

    func mediaItem(named name: String, url: URL) -> MediaItem {
        MediaItem(
            displayName: name,
            fileURL: url,
            duration: 10,
            inferredStartDate: nil,
            cameraGroupID: "A",
            alignmentStatus: .needsManualPlacement
        )
    }

    func cleanUp() {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
    }
}
