import Foundation
import Testing
@testable import RunningOverlay

@MainActor
struct OverlaySwitcherTests {
    @Test func adjacentSelectionWrapsAndSkipsLockedOverlays() {
        let project = ProjectDocument()
        project.addOverlayElement(.heartRate)
        project.addOverlayElement(.pace)
        project.addOverlayElement(.distance)
        let ids = project.overlayLayout.elements.map(\.id)
        project.setOverlayLocked(ids[1], isLocked: true)
        project.selection = .overlayElement(ids[0])

        project.selectAdjacentOverlay(1)
        #expect(project.selection == .overlayElement(ids[2]))

        project.selectAdjacentOverlay(1)
        #expect(project.selection == .overlayElement(ids[0]))

        project.selectAdjacentOverlay(-1)
        #expect(project.selection == .overlayElement(ids[2]))
    }

    @Test func adjacentSelectionStartsFromTheEndsWithoutAnOverlaySelection() {
        let project = ProjectDocument()
        project.addOverlayElement(.heartRate)
        project.addOverlayElement(.pace)
        let ids = project.overlayLayout.elements.map(\.id)

        project.selection = .none
        project.selectAdjacentOverlay(1)
        #expect(project.selection == .overlayElement(ids[0]))

        project.selection = .none
        project.selectAdjacentOverlay(-1)
        #expect(project.selection == .overlayElement(ids[1]))
    }

    @Test func adjacentSelectionDoesNothingWhenEveryOverlayIsLocked() {
        let project = ProjectDocument()
        project.addOverlayElement(.heartRate)
        let id = project.overlayLayout.elements[0].id
        project.setOverlayLocked(id, isLocked: true)
        project.selection = .none

        project.selectAdjacentOverlay(1)

        #expect(project.selection == .none)
    }

    @Test func titleLeadsWithPositionAndTotal() {
        #expect(OverlaySwitcherTitle.text(index: 3, count: 14, label: "Route Map") == "4 / 14  Route Map")
    }
}
