import SwiftUI

/// Context menu shared by an overlay on the preview canvas and its row in the
/// Inspector overlay list.
struct OverlayElementContextMenu: View {
    @EnvironmentObject private var project: ProjectDocument
    let element: OverlayElement

    var body: some View {
        Button {
            project.duplicateOverlay(element.id)
        } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }

        Divider()

        Button {
            project.copyOverlayProperties(from: element.id)
        } label: {
            Label("Copy Properties", systemImage: "doc.on.doc")
        }
        Button {
            project.pasteOverlayProperties(to: element.id)
        } label: {
            Label("Paste Properties", systemImage: "doc.on.clipboard")
        }
        .disabled(!project.canPasteOverlayProperties(to: element.id))

        Divider()

        Button {
            project.setOverlayVisibility(element.id, isVisible: !element.isVisible)
        } label: {
            Label(element.isVisible ? "Hide" : "Show", systemImage: element.isVisible ? "eye.slash" : "eye")
        }
        Button {
            project.setOverlayLocked(element.id, isLocked: !element.isLocked)
        } label: {
            Label(element.isLocked ? "Unlock" : "Lock", systemImage: element.isLocked ? "lock.open" : "lock")
        }

        Divider()

        Button(role: .destructive) {
            project.deleteOverlay(element.id)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}
