import Foundation
import Testing
@testable import RunningOverlay

@MainActor
struct OverlayDuplicateTests {
    @Test func duplicateStacksAnOffsetUnlockedCopyAboveTheOriginalAndSelectsIt() throws {
        let project = ProjectDocument()
        project.addOverlayElement(.heartRate)
        project.addOverlayElement(.pace)
        let original = project.overlayLayout.elements[0]
        project.setOverlayOpacity(original.id, opacity: 0.5)
        project.finishContinuousEdit()
        project.setOverlayLocked(original.id, isLocked: true)
        project.setOverlayVisibility(original.id, isVisible: false)
        let source = project.overlayLayout.elements[0]

        project.duplicateOverlay(source.id)

        let elements = project.overlayLayout.elements
        #expect(elements.map(\.type) == [.heartRate, .heartRate, .pace])
        let copy = elements[1]
        #expect(copy.id != source.id)
        #expect(project.selection == .overlayElement(copy.id))
        #expect(copy.style == source.style)
        #expect(copy.scale == source.scale)
        #expect(copy.opacity == 0.5)
        #expect(copy.isVisible)
        #expect(!copy.isLocked)
        #expect(abs(copy.position.x - (source.position.x + 24.0 / 1920)) < 1e-9)
        #expect(abs(copy.position.y - (source.position.y + 24.0 / 1080)) < 1e-9)

        project.undo()
        #expect(project.overlayLayout.elements.map(\.id) == [source.id, elements[2].id])
    }

    @Test func duplicateSelectedOverlayNeedsAnOverlaySelection() {
        let project = ProjectDocument()
        project.addOverlayElement(.pace)
        project.selection = .none

        #expect(project.selectedOverlayID == nil)
        project.duplicateSelectedOverlay()
        #expect(project.overlayLayout.elements.count == 1)

        project.selection = .overlayElement(project.overlayLayout.elements[0].id)
        project.duplicateSelectedOverlay()
        #expect(project.overlayLayout.elements.count == 2)
        #expect(project.selectedOverlayID == project.overlayLayout.elements[1].id)
    }
}
