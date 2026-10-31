import Foundation
import Testing
@testable import RunningOverlay

@MainActor
struct MediaShowInFinderTests {
    private func item(_ name: String, url: URL?) -> MediaItem {
        MediaItem(
            displayName: name,
            fileURL: url,
            duration: 1,
            inferredStartDate: nil,
            cameraGroupID: "A",
            alignmentStatus: .needsManualPlacement
        )
    }

    @Test func mediaFileURLsKeepPoolOrderAndSkipItemsWithoutFiles() {
        let project = ProjectDocument()
        let first = item("a.mov", url: URL(fileURLWithPath: "/tmp/a.mov"))
        let noFile = item("b.mov", url: nil)
        let last = item("c.mov", url: URL(fileURLWithPath: "/tmp/c.mov"))
        project.mediaItems = [first, noFile, last]

        let urls = project.mediaFileURLs(for: [last.id, noFile.id, first.id])

        #expect(urls.map(\.lastPathComponent) == ["a.mov", "c.mov"])
    }

    @Test func missingFilesRaiseTheErrorBanner() {
        let project = ProjectDocument()
        let missing = item("gone.mov", url: URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).mov"))
        project.mediaItems = [missing]

        project.showMediaItemsInFinder([missing.id])

        #expect(project.errorNotice?.message == "1 video file could not be found.")
    }
}
