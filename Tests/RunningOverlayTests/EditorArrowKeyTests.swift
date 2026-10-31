import Foundation
import Testing
@testable import RunningOverlay

@MainActor
struct EditorArrowKeyTests {
    @Test func arrowKeysNudgeSelectedOverlayByOutputPixels() {
        let project = ProjectDocument()
        project.addOverlayElement(.heartRate)
        let elementID = project.overlayLayout.elements[0].id
        let start = project.overlayLayout.elements[0].position
        let playhead = project.timeline.playhead

        #expect(project.handleArrowKey(.right, largeStep: false))
        #expect(project.handleArrowKey(.down, largeStep: true))

        let moved = project.overlayLayout.elements[0].position
        #expect(abs(moved.x - (start.x + 1.0 / 1920)) < 1e-9)
        #expect(abs(moved.y - (start.y + 10.0 / 1080)) < 1e-9)
        #expect(project.timeline.playhead == playhead)
        #expect(project.selection == .overlayElement(elementID))

        project.undo()
        #expect(abs(project.overlayLayout.elements[0].position.y - start.y) < 1e-9)
        project.undo()
        #expect(project.overlayLayout.elements[0].position == start)
    }

    @Test func arrowKeysStepPlayheadWithoutMovableOverlaySelection() {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 10,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        project.settings.frameRate = .fps25
        project.setPlayhead(2)

        project.selection = .none
        #expect(project.handleArrowKey(.right, largeStep: false))
        #expect(abs(project.timeline.playhead - 2.04) < 0.0001)
        #expect(project.handleArrowKey(.right, largeStep: true))
        #expect(abs(project.timeline.playhead - 2.44) < 0.0001)
        #expect(project.handleArrowKey(.left, largeStep: true))
        project.setPlayhead(2)

        project.addOverlayElement(.pace)
        let elementID = project.overlayLayout.elements[0].id
        let position = project.overlayLayout.elements[0].position
        project.setOverlayLocked(elementID, isLocked: true)
        project.selection = .overlayElement(elementID)

        #expect(project.handleArrowKey(.left, largeStep: false))
        #expect(abs(project.timeline.playhead - 1.96) < 0.0001)
        // Up/Down navigate edit points instead of moving a locked overlay.
        #expect(project.handleArrowKey(.down, largeStep: false))
        #expect(project.timeline.playhead == 10)
        #expect(!project.handleArrowKey(.down, largeStep: false))
        #expect(project.overlayLayout.elements[0].position == position)
    }
}
