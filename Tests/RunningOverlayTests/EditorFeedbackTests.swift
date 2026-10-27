import Foundation
import Testing
@testable import RunningOverlay

@MainActor
struct EditorFeedbackTests {
    @Test func reportedErrorsStayVisibleUntilDismissed() {
        let project = ProjectDocument()

        project.reportError("Something failed.")
        #expect(project.statusMessage == "Something failed.")
        #expect(project.errorNotice?.message == "Something failed.")

        project.statusMessage = "Later status."
        #expect(project.errorNotice?.message == "Something failed.")

        project.dismissErrorNotice()
        #expect(project.errorNotice == nil)
    }

    @Test func aNewErrorReplacesTheBanner() {
        let project = ProjectDocument()

        project.reportError("First.")
        let first = project.errorNotice
        project.reportError("First.")

        #expect(project.errorNotice?.message == "First.")
        #expect(project.errorNotice?.id != first?.id)
    }

    @Test func failedImportsRaiseTheErrorBanner() {
        let project = ProjectDocument()

        project.importActivityURL(URL(fileURLWithPath: "/nonexistent/run-\(UUID().uuidString).fit"))
        #expect(project.errorNotice?.message.hasPrefix("Activity import failed") == true)

        project.dismissErrorNotice()
        let task = project.importVideoURLs([URL(fileURLWithPath: "/tmp/notes.txt")])
        #expect(task == nil)
        #expect(project.errorNotice?.message == "No supported video files were found.")
    }
}
