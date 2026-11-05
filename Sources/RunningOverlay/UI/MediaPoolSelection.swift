import AppKit

/// A row in the Media Pool outline: a folder, or a clip at the root or
/// inside a folder.
enum MediaPoolRowID: Hashable {
    case folder(MediaFolder.ID)
    case media(MediaItem.ID)
}

/// One visible outline row, in display order.
struct MediaPoolOutlineRow: Equatable {
    var id: MediaPoolRowID
    /// The folder a clip row is shown inside. `nil` for folders and root clips.
    var parentFolderID: MediaFolder.ID?
    /// Folder rows only.
    var isExpanded = false
}

/// The Media Pool's own selection. It follows outline-view rules: click
/// selects, Shift extends from the anchor, Command toggles, ↑/↓ move the
/// cursor, and collapsing a folder moves selected children onto the folder.
///
/// It is separate from `ProjectDocument.selection`. The two are exclusive:
/// committing a non-empty Media Pool selection clears the editor selection
/// (see `commit(_:into:project:)`), so Delete and the Inspector never act on
/// a stale overlay or clip.
struct MediaPoolSelection: Equatable {
    var rows: Set<MediaPoolRowID> = []
    /// The fixed end of a Shift range.
    var anchor: MediaPoolRowID?
    /// The moving end: where ↑/↓ start from.
    var cursor: MediaPoolRowID?

    struct ClickModifiers: OptionSet {
        let rawValue: Int
        static let shift = ClickModifiers(rawValue: 1 << 0)
        static let command = ClickModifiers(rawValue: 1 << 1)
    }

    enum VerticalDirection {
        case up
        case down
    }

    var isEmpty: Bool { rows.isEmpty }

    var mediaIDs: Set<MediaItem.ID> {
        Set(rows.compactMap { if case .media(let id) = $0 { id } else { nil } })
    }

    var folderIDs: Set<MediaFolder.ID> {
        Set(rows.compactMap { if case .folder(let id) = $0 { id } else { nil } })
    }

    func contains(_ row: MediaPoolRowID) -> Bool {
        rows.contains(row)
    }

    mutating func clear() {
        self = MediaPoolSelection()
    }

    mutating func select(_ row: MediaPoolRowID) {
        rows = [row]
        anchor = row
        cursor = row
    }

    mutating func click(_ row: MediaPoolRowID, modifiers: ClickModifiers, in outline: [MediaPoolOutlineRow]) {
        if modifiers.contains(.shift), let anchor, let range = range(from: anchor, to: row, in: outline) {
            rows = range
            cursor = row
            return
        }
        if modifiers.contains(.command) {
            if rows.contains(row) {
                rows.remove(row)
            } else {
                rows.insert(row)
            }
            anchor = row
            cursor = row
            return
        }
        select(row)
    }

    /// ⌘A. Selects the visible clips; folders stay out so a following ⌘⌫
    /// cannot delete the hidden contents of collapsed folders.
    mutating func selectAllMedia(in outline: [MediaPoolOutlineRow]) {
        let media = outline.filter { if case .media = $0.id { true } else { false } }
        rows = Set(media.map(\.id))
        anchor = media.first?.id
        cursor = media.last?.id
    }

    /// ↑/↓, with Shift to extend from the anchor.
    mutating func move(_ direction: VerticalDirection, extending: Bool, in outline: [MediaPoolOutlineRow]) {
        guard !outline.isEmpty else { return }
        let ids = outline.map(\.id)
        let targetIndex: Int
        if let cursor, let index = ids.firstIndex(of: cursor) {
            targetIndex = direction == .up ? max(index - 1, 0) : min(index + 1, ids.count - 1)
        } else {
            targetIndex = direction == .up ? ids.count - 1 : 0
        }
        let target = ids[targetIndex]
        if extending, let anchor, let range = range(from: anchor, to: target, in: outline) {
            rows = range
            cursor = target
        } else {
            select(target)
        }
    }

    /// Collapsing a folder hides its children. Selected children are
    /// replaced by the folder itself (Finder's behaviour); the rest of the
    /// selection is kept.
    mutating func collapse(folder folderID: MediaFolder.ID, childIDs: Set<MediaItem.ID>) {
        let hidden = Set(childIDs.map(MediaPoolRowID.media))
        if !hidden.isDisjoint(with: rows) {
            rows.subtract(hidden)
            rows.insert(.folder(folderID))
        }
        if let anchor, hidden.contains(anchor) {
            self.anchor = .folder(folderID)
        }
        if let cursor, hidden.contains(cursor) {
            self.cursor = .folder(folderID)
        }
    }

    /// Drops rows that are no longer visible, for example after a search.
    mutating func prune(toVisible outline: [MediaPoolOutlineRow]) {
        let visible = Set(outline.map(\.id))
        rows.formIntersection(visible)
        if let anchor, !visible.contains(anchor) { self.anchor = nil }
        if let cursor, !visible.contains(cursor) { self.cursor = nil }
    }

    private func range(from start: MediaPoolRowID, to end: MediaPoolRowID, in outline: [MediaPoolOutlineRow]) -> Set<MediaPoolRowID>? {
        let ids = outline.map(\.id)
        guard let startIndex = ids.firstIndex(of: start), let endIndex = ids.firstIndex(of: end) else {
            return nil
        }
        return Set(ids[min(startIndex, endIndex)...max(startIndex, endIndex)])
    }
}

extension MediaPoolSelection {
    /// What ←/→ do on the cursor row.
    enum HorizontalAction: Equatable {
        case collapse(MediaFolder.ID)
        case expand(MediaFolder.ID)
        case selectParent(MediaFolder.ID)
        case none
    }

    enum HorizontalDirection {
        case left
        case right
    }

    func horizontalAction(_ direction: HorizontalDirection, in outline: [MediaPoolOutlineRow]) -> HorizontalAction {
        guard let cursor, let row = outline.first(where: { $0.id == cursor }) else {
            return .none
        }
        switch (direction, row.id) {
        case (.left, .folder(let folderID)):
            return row.isExpanded ? .collapse(folderID) : .none
        case (.right, .folder(let folderID)):
            return row.isExpanded ? .none : .expand(folderID)
        case (.left, .media):
            return row.parentFolderID.map(HorizontalAction.selectParent) ?? .none
        case (.right, .media):
            return .none
        }
    }
}

extension MediaPoolSelection {
    /// The single place the Media Pool writes its selection. A non-empty
    /// Media Pool selection clears the editor selection so only one
    /// selection is current; pruning to empty leaves the editor alone.
    @MainActor
    static func commit(_ newValue: MediaPoolSelection, into current: inout MediaPoolSelection, project: ProjectDocument) {
        current = newValue
        if !newValue.isEmpty, project.selection != .none {
            project.clearSelection()
        }
    }
}

/// A key the Media Pool list handles while it has keyboard focus.
enum MediaPoolKeyCommand: Equatable {
    case selectAll
    case move(MediaPoolSelection.VerticalDirection, extending: Bool)
    case horizontal(MediaPoolSelection.HorizontalDirection)
    case rename
    case delete
    case clearSelection
    case showInFinder

    init?(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, characters: String?) {
        let flags = modifiers.intersection([.command, .option, .control, .shift])
        switch keyCode {
        case 126 where flags.subtracting(.shift).isEmpty:
            self = .move(.up, extending: flags.contains(.shift))
        case 125 where flags.subtracting(.shift).isEmpty:
            self = .move(.down, extending: flags.contains(.shift))
        // Option+←/→ is the recursive form; folders are one level deep.
        case 123 where flags.subtracting(.option).isEmpty:
            self = .horizontal(.left)
        case 124 where flags.subtracting(.option).isEmpty:
            self = .horizontal(.right)
        case 36 where flags.isEmpty, 76 where flags.isEmpty:
            self = .rename
        case 51 where flags.isEmpty || flags == .command:
            self = .delete
        case 117 where flags.isEmpty:
            self = .delete
        case 53 where flags.isEmpty:
            self = .clearSelection
        default:
            let key = characters?.lowercased()
            if flags == .command, key == "a" {
                self = .selectAll
            } else if flags == [.command, .shift], key == "r" {
                self = .showInFinder
            } else {
                return nil
            }
        }
    }
}
