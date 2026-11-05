import AppKit
import Foundation
import Testing
@testable import RunningOverlay

@MainActor
struct MediaPoolSelectionTests {
    private let folderID = UUID()
    private let childA = UUID()
    private let childB = UUID()
    private let rootA = UUID()
    private let rootB = UUID()

    /// Folder (expanded) › childA, childB, then rootA, rootB.
    private var outline: [MediaPoolOutlineRow] {
        [
            MediaPoolOutlineRow(id: .folder(folderID), isExpanded: true),
            MediaPoolOutlineRow(id: .media(childA), parentFolderID: folderID),
            MediaPoolOutlineRow(id: .media(childB), parentFolderID: folderID),
            MediaPoolOutlineRow(id: .media(rootA)),
            MediaPoolOutlineRow(id: .media(rootB)),
        ]
    }

    private func item(_ name: String, id: UUID = UUID(), folderID: MediaFolder.ID? = nil) -> MediaItem {
        MediaItem(
            id: id,
            displayName: name,
            fileURL: nil,
            duration: 10,
            inferredStartDate: nil,
            cameraGroupID: "A",
            alignmentStatus: .needsManualPlacement,
            folderID: folderID
        )
    }

    // MARK: Editor selection

    @Test func editorSelectionClearsMediaRowsAndRangeAnchor() {
        for editorSelection: EditorSelection in [.overlayElement(UUID()), .timelineClip(UUID())] {
            var selection = MediaPoolSelection()
            selection.select(.media(rootA))
            selection.clearForEditorSelection(editorSelection)
            #expect(selection.isEmpty)
            #expect(selection.anchor == nil)
            #expect(selection.cursor == nil)
        }
    }

    @Test func selectingMediaClearsTheEditorSelection() {
        let project = ProjectDocument()
        project.selection = .overlayElement(UUID())
        var current = MediaPoolSelection()

        var next = current
        next.click(.media(rootA), modifiers: [], in: outline)
        MediaPoolSelection.commit(next, into: &current, project: project)

        #expect(project.selection == .none)
        #expect(current.mediaIDs == [rootA])
    }

    @Test func emptyingTheMediaSelectionLeavesTheEditorSelectionAlone() {
        let project = ProjectDocument()
        let clipID = UUID()
        project.selection = .timelineClip(clipID)
        var current = MediaPoolSelection()

        MediaPoolSelection.commit(MediaPoolSelection(), into: &current, project: project)

        #expect(project.selection == .timelineClip(clipID))
    }

    // MARK: Clicks

    @Test func clickShiftClickAndCommandClick() {
        var selection = MediaPoolSelection()
        selection.click(.media(childA), modifiers: [], in: outline)
        selection.click(.media(rootA), modifiers: .shift, in: outline)
        #expect(selection.rows == [.media(childA), .media(childB), .media(rootA)])

        selection.click(.media(childB), modifiers: .command, in: outline)
        #expect(selection.rows == [.media(childA), .media(rootA)])

        selection.click(.folder(folderID), modifiers: [], in: outline)
        #expect(selection.rows == [.folder(folderID)])
        #expect(selection.folderIDs == [folderID])
    }

    // MARK: Keyboard

    @Test func arrowsMoveAndShiftArrowsExtend() {
        var selection = MediaPoolSelection()
        selection.move(.down, extending: false, in: outline)
        #expect(selection.rows == [.folder(folderID)])

        selection.move(.down, extending: false, in: outline)
        #expect(selection.rows == [.media(childA)])

        selection.move(.down, extending: true, in: outline)
        selection.move(.down, extending: true, in: outline)
        #expect(selection.rows == [.media(childA), .media(childB), .media(rootA)])

        selection.move(.up, extending: true, in: outline)
        #expect(selection.rows == [.media(childA), .media(childB)])

        selection.move(.up, extending: false, in: outline)
        #expect(selection.rows == [.media(childA)])
    }

    @Test func arrowsStopAtTheEnds() {
        var selection = MediaPoolSelection()
        selection.move(.up, extending: false, in: outline)
        #expect(selection.rows == [.media(rootB)])
        selection.move(.down, extending: false, in: outline)
        #expect(selection.rows == [.media(rootB)])
    }

    @Test func selectAllTakesVisibleClipsOnly() {
        var selection = MediaPoolSelection()
        selection.selectAllMedia(in: outline)
        #expect(selection.mediaIDs == [childA, childB, rootA, rootB])
        #expect(selection.folderIDs.isEmpty)
    }

    @Test func leftAndRightCollapseExpandAndSelectTheParent() {
        var selection = MediaPoolSelection()
        selection.select(.folder(folderID))
        #expect(selection.horizontalAction(.left, in: outline) == .collapse(folderID))
        #expect(selection.horizontalAction(.right, in: outline) == .none)

        var collapsed = outline
        collapsed[0].isExpanded = false
        #expect(selection.horizontalAction(.right, in: collapsed) == .expand(folderID))
        #expect(selection.horizontalAction(.left, in: collapsed) == .none)

        selection.select(.media(childB))
        #expect(selection.horizontalAction(.left, in: outline) == .selectParent(folderID))
        selection.select(.media(rootA))
        #expect(selection.horizontalAction(.left, in: outline) == .none)
    }

    @Test func collapsingAFolderKeepsUnrelatedSelection() {
        var selection = MediaPoolSelection()
        selection.click(.media(childA), modifiers: [], in: outline)
        selection.click(.media(rootB), modifiers: .command, in: outline)

        selection.collapse(folder: folderID, childIDs: [childA, childB])

        #expect(selection.rows == [.folder(folderID), .media(rootB)])
    }

    @Test func collapsingAFolderWithoutSelectedChildrenChangesNothing() {
        var selection = MediaPoolSelection()
        selection.select(.media(rootA))
        let before = selection

        selection.collapse(folder: folderID, childIDs: [childA, childB])

        #expect(selection == before)
    }

    @Test func keyCommandsMapStandardKeys() {
        func command(_ keyCode: UInt16, _ modifiers: NSEvent.ModifierFlags = [], _ characters: String? = nil) -> MediaPoolKeyCommand? {
            MediaPoolKeyCommand(keyCode: keyCode, modifiers: modifiers, characters: characters)
        }
        #expect(command(126, [.numericPad, .function]) == .move(.up, extending: false))
        #expect(command(125, .shift) == .move(.down, extending: true))
        #expect(command(123) == .horizontal(.left))
        #expect(command(124, .option) == .horizontal(.right))
        #expect(command(36) == .rename)
        #expect(command(51, .command) == .delete)
        #expect(command(51) == .delete)
        #expect(command(117) == .delete)
        #expect(command(53) == .clearSelection)
        #expect(command(0, .command, "a") == .selectAll)
        #expect(command(15, [.command, .shift], "R") == .showInFinder)

        #expect(command(36, .command) == nil)
        #expect(command(126, .command) == nil)
        #expect(command(49) == nil)
    }

    // MARK: Delete

    @Test func deletingAMixedSelectionIsOneUndoStep() {
        let project = ProjectDocument()
        let folder = MediaFolder(name: "Morning")
        let inFolder = item("in.mov", folderID: folder.id)
        let root = item("root.mov")
        let kept = item("kept.mov")
        project.mediaFolders = [folder]
        project.mediaItems = [inFolder, root, kept]

        project.deleteMediaPoolItems([root.id], folders: [folder.id])

        #expect(project.mediaItems.map(\.id) == [kept.id])
        #expect(project.mediaFolders.isEmpty)

        project.undo()

        #expect(project.mediaItems.map(\.id) == [inFolder.id, root.id, kept.id])
        #expect(project.mediaFolders.map(\.id) == [folder.id])
        #expect(!project.canUndo)
    }

    // MARK: Formatting

    @Test func durationsMatchTheTimeline() {
        #expect(MediaPoolFormat.duration(252) == "4:12")
        #expect(MediaPoolFormat.duration(5.9) == "0:05")
        #expect(MediaPoolFormat.duration(3725) == "1:02:05")
        #expect(MediaPoolFormat.subtitle(duration: 78, startDate: nil) == "1:18")
    }
}
