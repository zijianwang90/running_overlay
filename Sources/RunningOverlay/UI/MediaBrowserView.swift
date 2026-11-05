import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MediaBrowserView: View {
    @EnvironmentObject private var project: ProjectDocument
    @Environment(\.controlActiveState) private var controlActiveState
    @State private var selection = MediaPoolSelection()
    @State private var expandedFolderIDs: Set<MediaFolder.ID> = []
    @State private var editingFolderID: MediaFolder.ID?
    @State private var editingFolderName: String = ""
    @State private var statusFilter: MediaStatusFilter = .all
    @State private var searchText = ""
    @State private var searchFocusRequest = 0
    @State private var hoveredRowID: MediaPoolRowID?
    @State private var dropTargetFolderID: MediaFolder.ID?
    @State private var isRootDropTarget = false
    @State private var isPlaceholderDropTarget = false
    /// Asks the key capture view to take (true) or give up (false) keyboard focus.
    @State private var wantsKeyboardFocus = false
    /// Whether the key capture view is the first responder.
    @State private var hasKeyboardFocus = false
    @FocusState private var renameFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            searchAndFilterStrip

            if project.mediaItems.isEmpty && project.mediaFolders.isEmpty {
                dropTargetPlaceholder
            } else if visibleRows.isEmpty {
                emptyFilterPlaceholder
            } else {
                mediaList
            }
        }
        .background(EditorTheme.panelBackground)
        .background(
            MediaBrowserKeyHandler(
                wantsFocus: $wantsKeyboardFocus,
                hasFocus: $hasKeyboardFocus,
                onCommand: handleKeyCommand,
                onFocusLost: {
                    project.clearMediaPoolPreview()
                }
            )
        )
        .background(findShortcut)
        .contentShape(Rectangle())
        .onDrop(
            of: [.fileURL],
            delegate: MediaPoolDropDelegate(
                acceptsFiles: hasActivity,
                acceptsMediaRows: false,
                onTargetChange: { isPlaceholderDropTarget = $0 },
                perform: { importDroppedVideoFiles($0) }
            )
        )
        .onChange(of: project.mediaItems.map(\.id)) { _, _ in
            selection.prune(toVisible: outlineRows)
        }
        .onChange(of: project.mediaFolders.map(\.id)) { _, ids in
            expandedFolderIDs.formIntersection(Set(ids))
            if let editing = editingFolderID, !ids.contains(editing) {
                editingFolderID = nil
            }
            selection.prune(toVisible: outlineRows)
        }
        .onChange(of: statusFilter) { _, _ in
            selection.prune(toVisible: outlineRows)
        }
        .onChange(of: searchText) { _, _ in
            selection.prune(toVisible: outlineRows)
        }
        .onChange(of: project.selection) { _, newValue in
            // Selecting an overlay or clip makes that the current selection;
            // the list keeps its rows but stops taking keys.
            if newValue != .none {
                wantsKeyboardFocus = false
            }
        }
    }

    private var hasActivity: Bool {
        project.activity.duration > 0
    }

    private var header: some View {
        EditorPanelHeader(title: "Media", subtitle: project.mediaItems.isEmpty ? nil : visibleCountLabel) {
            Button {
                let ids = selection.mediaIDs
                let newID = project.createMediaFolder(containing: ids)
                expandedFolderIDs.insert(newID)
                beginRenaming(folderID: newID)
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .buttonStyle(EditorIconButtonStyle(isEnabled: true))
            .help(selection.mediaIDs.isEmpty ? "New Folder" : "New Folder with \(selection.mediaIDs.count) Selected Clip(s)")
            .accessibilityLabel("New Folder")

            Button {
                project.importVideos()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(EditorIconButtonStyle(isEnabled: hasActivity))
            .disabled(!hasActivity)
            .help(hasActivity ? "Import Videos" : "Import an activity before importing videos")
            .accessibilityLabel("Import Videos")
        }
    }

    /// ⌘F focuses the search field while the Media Pool is showing.
    private var findShortcut: some View {
        Button("Find Media") {
            searchFocusRequest += 1
        }
        .keyboardShortcut("f", modifiers: .command)
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private var searchAndFilterStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            MediaSearchField(text: $searchText, focusRequest: searchFocusRequest)
                .frame(height: 22)

            Picker("Filter", selection: $statusFilter) {
                ForEach(MediaStatusFilter.allCases) { filter in
                    filter.label
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelStyle(.titleAndIcon)
            .labelsHidden()
            .controlSize(.small)
            .help("Filter by alignment status")

            if hasActivity {
                activityStatusRow
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(EditorTheme.panelBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(EditorTheme.borderSubtle)
                .frame(height: 1)
        }
    }

    private var activityStatusRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(MediaBrowserColor.aligned)
                .accessibilityLabel("Activity loaded")
            VStack(alignment: .leading, spacing: 1) {
                Text(project.activitySourceName.isEmpty ? "Activity loaded" : project.activitySourceName)
                    .font(EditorTheme.captionFont)
                    .foregroundStyle(EditorTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(project.workoutStructureSummary)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(EditorTheme.textMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            WorkoutTypePicker()

            Menu {
                Button("Replace Activity…") {
                    project.importActivityFile()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Activity Actions")
            .accessibilityLabel("Activity Actions")
        }
    }

    private var mediaList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(visibleRows.enumerated()), id: \.element.id) { index, row in
                    rowView(row, index: index)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    updateSelection { $0.clear() }
                    wantsKeyboardFocus = true
                }
                .background(MediaPoolStripeBackground(rowHeight: EditorTheme.mediaRowHeight))
                .background(
                    rootDropOverlayBackground
                )
                .onDrop(
                    of: [.plainText, .fileURL],
                    delegate: MediaPoolDropDelegate(
                        acceptsFiles: hasActivity,
                        acceptsMediaRows: true,
                        onTargetChange: { isRootDropTarget = $0 },
                        perform: { handleDrop(providers: $0, targetFolderID: nil) }
                    )
                )
        )
        .overlay {
            if isListEmphasized {
                Rectangle()
                    .strokeBorder(MediaBrowserColor.focusRing, lineWidth: 2)
                    .allowsHitTesting(false)
            }
        }
        .contextMenu {
            emptyAreaContextMenu
        }
    }

    /// Keys go to the list and the window is active: selected rows use the
    /// accent colour. Otherwise they turn gray.
    private var isListEmphasized: Bool {
        hasKeyboardFocus && controlActiveState == .key
    }

    @ViewBuilder
    private var emptyAreaContextMenu: some View {
        Button("Import Videos…") {
            project.importVideos()
        }
        .disabled(!hasActivity)
        Button("New Folder") {
            let newID = project.createMediaFolder()
            expandedFolderIDs.insert(newID)
            beginRenaming(folderID: newID)
        }
        Divider()
        Button("Select All") {
            updateSelection { $0.selectAllMedia(in: outlineRows) }
        }
        .keyboardShortcut("a", modifiers: .command)
        .disabled(allVisibleMediaIDs.isEmpty)
    }

    @ViewBuilder
    private var rootDropOverlayBackground: some View {
        if isRootDropTarget {
            Rectangle()
                .fill(Color.accentColor.opacity(0.08))
        }
    }

    @ViewBuilder
    private func rowView(_ row: VisibleRow, index: Int) -> some View {
        switch row.kind {
        case .folder(let folder, let childCount, let isExpanded):
            folderRow(folder: folder, childCount: childCount, isExpanded: isExpanded, index: index)
        case .media(let item, let inFolder):
            mediaRowContainer(item: item, inFolder: inFolder, index: index)
        }
    }

    private func folderRow(folder: MediaFolder, childCount: Int, isExpanded: Bool, index: Int) -> some View {
        let rowID = MediaPoolRowID.folder(folder.id)
        let isDropTarget = dropTargetFolderID == folder.id
        let isEditing = editingFolderID == folder.id
        let isSelected = selection.contains(rowID)
        let emphasized = isSelected && isListEmphasized

        return HStack(spacing: 6) {
            Button {
                toggleFolderExpansion(folder.id)
                wantsKeyboardFocus = true
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .foregroundStyle(emphasized ? MediaBrowserColor.emphasizedSecondaryText : EditorTheme.textMuted)
                    .frame(width: 14, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isFilterActive)
            .help(isExpanded ? "Collapse" : "Expand")
            .accessibilityLabel(isExpanded ? "Collapse \(folder.name)" : "Expand \(folder.name)")

            Image(systemName: "folder")
                .font(.system(size: 14))
                .foregroundStyle(emphasized ? MediaBrowserColor.emphasizedText : Color.accentColor)
            if isEditing {
                folderRenameField(folder: folder)
            } else {
                Text(folder.name)
                    .font(EditorTheme.bodyStrongFont)
                    .foregroundStyle(emphasized ? MediaBrowserColor.emphasizedText : EditorTheme.textPrimary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if !isEditing {
                Text("\(childCount)")
                    .font(EditorTheme.captionFont.monospacedDigit())
                    .foregroundStyle(emphasized ? MediaBrowserColor.emphasizedSecondaryText : EditorTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .frame(height: EditorTheme.mediaRowHeight, alignment: .center)
        .background(rowBackground(index: index, row: rowID, isDropTarget: isDropTarget))
        .overlay {
            if isDropTarget {
                Rectangle()
                    .strokeBorder(Color.accentColor, lineWidth: 2)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(EditorTheme.borderSubtle.opacity(0.72))
                .frame(height: 1)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            setHovered(rowID, hovering)
        }
        .onTapGesture {
            if isEditing {
                return
            }
            handleRowClick(rowID)
        }
        .contextMenu {
            rowContextMenu(for: rowID)
        }
        .onDrop(
            of: [.plainText, .fileURL],
            delegate: MediaPoolDropDelegate(
                acceptsFiles: hasActivity,
                acceptsMediaRows: true,
                onTargetChange: { isTargeted in
                    dropTargetFolderID = isTargeted ? folder.id : (dropTargetFolderID == folder.id ? nil : dropTargetFolderID)
                },
                perform: { handleDrop(providers: $0, targetFolderID: folder.id) }
            )
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func mediaRowContainer(item: MediaItem, inFolder: Bool, index: Int) -> some View {
        let rowID = MediaPoolRowID.media(item.id)
        let isSelected = selection.contains(rowID)

        return mediaRow(item, emphasized: isSelected && isListEmphasized)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, inFolder ? 40 : 12)
            .padding(.trailing, 12)
            .frame(height: EditorTheme.mediaRowHeight, alignment: .center)
            .background(rowBackground(index: index, row: rowID, isDropTarget: false))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(EditorTheme.borderSubtle.opacity(0.72))
                    .frame(height: 1)
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                setHovered(rowID, hovering)
            }
            .onTapGesture {
                handleRowClick(rowID)
            }
            .contextMenu {
                rowContextMenu(for: rowID)
            }
            .onDrag {
                NSItemProvider(object: item.id.uuidString as NSString)
            }
            .onDrop(
                of: [.fileURL],
                delegate: MediaPoolDropDelegate(
                    acceptsFiles: hasActivity,
                    acceptsMediaRows: false,
                    onTargetChange: { _ in },
                    perform: { importDroppedVideoFiles($0, intoFolder: nil) }
                )
            )
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Commands for the clicked row. When the row is part of the selection
    /// they act on the whole selection.
    @ViewBuilder
    private func rowContextMenu(for row: MediaPoolRowID) -> some View {
        let targets = selection.contains(row) ? selection.rows : [row]
        let targetMedia = Set(targets.compactMap { if case .media(let id) = $0 { id } else { nil } })
        let targetFolders = Set(targets.compactMap { if case .folder(let id) = $0 { id } else { nil } })
        let clipIDs = targetMedia.union(targetFolders.flatMap { mediaIDs(inFolder: $0) })
        let singleFolder: MediaFolder? = targetMedia.isEmpty && targetFolders.count == 1
            ? project.mediaFolders.first { targetFolders.contains($0.id) }
            : nil

        if !clipIDs.isEmpty {
            Button(clipIDs.count > 1 ? "Auto Match \(clipIDs.count) Clips to Current Layer" : "Auto Match to Current Layer") {
                project.matchMediaItemsToCurrentLayer(clipIDs)
            }
            Button("Match to New Layer") {
                project.matchMediaItemsToNewLayer(clipIDs)
            }
            matchToLayerMenu(for: clipIDs)
        }

        if targetFolders.isEmpty {
            Divider()
            if !project.mediaFileURLs(for: targetMedia).isEmpty {
                Button("Show in Finder") {
                    project.showMediaItemsInFinder(targetMedia)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
            Menu("Move to Folder") {
                Button("New Folder with Selection") {
                    let newID = project.createMediaFolder(containing: targetMedia)
                    expandedFolderIDs.insert(newID)
                    beginRenaming(folderID: newID)
                }
                let destinations = project.mediaFolders.filter { folder in
                    project.mediaItems.contains { targetMedia.contains($0.id) && $0.folderID != folder.id }
                }
                if !destinations.isEmpty {
                    Divider()
                    ForEach(destinations) { folder in
                        Button(folder.name) {
                            project.moveMediaItems(targetMedia, toFolder: folder.id)
                            expandedFolderIDs.insert(folder.id)
                        }
                    }
                }
            }
            if anyInFolder(targetMedia) {
                Button("Move to Root") {
                    project.moveMediaItems(targetMedia, toFolder: nil)
                }
            }
        }

        if let singleFolder {
            Divider()
            Button("Rename") { beginRenaming(folderID: singleFolder.id) }
            Button("New Folder") {
                let newID = project.createMediaFolder()
                expandedFolderIDs.insert(newID)
                beginRenaming(folderID: newID)
            }
        }

        Divider()
        if let singleFolder {
            let childCount = mediaIDs(inFolder: singleFolder.id).count
            if childCount > 0 {
                Button("Delete Folder, Keep Clips") {
                    updateSelection { $0.rows.remove(.folder(singleFolder.id)) }
                    project.deleteMediaFolder(singleFolder.id)
                }
            }
            Button(childCount == 0 ? "Delete Folder" : "Delete Folder and \(childCount) \(childCount == 1 ? "Clip" : "Clips")") {
                deleteRows(targets)
            }
            .keyboardShortcut(.delete, modifiers: .command)
        } else {
            Button("Delete from Media Pool") {
                deleteRows(targets)
            }
            .keyboardShortcut(.delete, modifiers: .command)
        }
    }

    @ViewBuilder
    private func matchToLayerMenu(for mediaItemIDs: Set<MediaItem.ID>) -> some View {
        Menu("Match to Layer") {
            if project.timeline.tracks.isEmpty {
                Text("No Layers")
            } else {
                ForEach(project.timeline.tracks) { track in
                    Button(track.name) {
                        project.matchMediaItems(mediaItemIDs, toLayer: track.name)
                    }
                }
            }
        }
        .disabled(mediaItemIDs.isEmpty || project.timeline.tracks.isEmpty)
    }

    private func handleDrop(providers: [NSItemProvider], targetFolderID: MediaFolder.ID?) -> Bool {
        let fileURLProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        if !fileURLProviders.isEmpty {
            return importDroppedVideoFiles(fileURLProviders, intoFolder: targetFolderID)
        }

        guard let provider = providers.first else { return false }
        let capturedSelection = selection.mediaIDs
        let target = targetFolderID
        provider.loadObject(ofClass: NSString.self) { reading, _ in
            guard let string = reading as? String, let mediaID = UUID(uuidString: string) else { return }
            Task { @MainActor in
                performDrop(droppedItemID: mediaID, selectedMediaIDs: capturedSelection, targetFolderID: target)
            }
        }
        return true
    }

    private func mediaIDs(inFolder folderID: MediaFolder.ID) -> Set<MediaItem.ID> {
        Set(project.mediaItems.filter { $0.folderID == folderID }.map(\.id))
    }

    @ViewBuilder
    private func folderRenameField(folder: MediaFolder) -> some View {
        TextField("Folder name", text: $editingFolderName, onCommit: { commitFolderRename(folder.id) })
            .textFieldStyle(.plain)
            .font(EditorTheme.bodyStrongFont)
            .foregroundStyle(EditorTheme.textPrimary)
            .focused($renameFieldFocused)
            .submitLabel(.done)
            .onExitCommand {
                editingFolderID = nil
                wantsKeyboardFocus = true
            }
            .onAppear {
                DispatchQueue.main.async {
                    renameFieldFocused = true
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(EditorTheme.surfaceControl)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor, lineWidth: 1.5)
            }
            .frame(maxWidth: .infinity)
    }

    /// Writes the Media Pool selection. A non-empty selection clears the
    /// editor selection, so the Inspector and Delete never act on a stale
    /// overlay or clip.
    private func updateSelection(_ change: (inout MediaPoolSelection) -> Void) {
        var next = selection
        change(&next)
        MediaPoolSelection.commit(next, into: &selection, project: project)
    }

    private func handleRowClick(_ row: MediaPoolRowID) {
        wantsKeyboardFocus = true
        let clickCount = NSApp.currentEvent?.clickCount ?? 1
        if clickCount >= 2 {
            switch row {
            case .media(let mediaID):
                updateSelection { $0.select(row) }
                project.previewMediaPoolItem(mediaID)
            case .folder(let folderID):
                if !isFilterActive {
                    toggleFolderExpansion(folderID)
                }
            }
            return
        }
        let flags = NSEvent.modifierFlags
        var modifiers: MediaPoolSelection.ClickModifiers = []
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.command) { modifiers.insert(.command) }
        let outline = outlineRows
        updateSelection { $0.click(row, modifiers: modifiers, in: outline) }
    }

    private func handleKeyCommand(_ command: MediaPoolKeyCommand) -> Bool {
        let outline = outlineRows
        switch command {
        case .selectAll:
            updateSelection { $0.selectAllMedia(in: outline) }
        case .move(let direction, let extending):
            updateSelection { $0.move(direction, extending: extending, in: outline) }
        case .horizontal(let direction):
            switch selection.horizontalAction(direction, in: outline) {
            case .collapse(let folderID):
                if !isFilterActive { collapseFolder(folderID) }
            case .expand(let folderID):
                if !isFilterActive { expandedFolderIDs.insert(folderID) }
            case .selectParent(let folderID):
                updateSelection { $0.select(.folder(folderID)) }
            case .none:
                break
            }
        case .rename:
            if selection.rows.count == 1, case .folder(let folderID) = selection.rows.first {
                beginRenaming(folderID: folderID)
            } else {
                NSSound.beep()
            }
        case .delete:
            if selection.isEmpty {
                NSSound.beep()
            } else {
                deleteRows(selection.rows)
            }
        case .clearSelection:
            guard !selection.isEmpty else { return false }
            updateSelection { $0.clear() }
        case .showInFinder:
            guard !selection.mediaIDs.isEmpty else { return false }
            project.showMediaItemsInFinder(selection.mediaIDs)
        }
        return true
    }

    /// Deletes clips and folders (with their clips) as one undo step.
    private func deleteRows(_ rows: Set<MediaPoolRowID>) {
        let media = Set(rows.compactMap { if case .media(let id) = $0 { id } else { nil } })
        let folders = Set(rows.compactMap { if case .folder(let id) = $0 { id } else { nil } })
        updateSelection { $0.rows.subtract(rows) }
        project.deleteMediaPoolItems(media, folders: folders)
    }

    private func performDrop(droppedItemID: MediaItem.ID, selectedMediaIDs: Set<MediaItem.ID>, targetFolderID: MediaFolder.ID?) {
        let idsToMove = selectedMediaIDs.contains(droppedItemID) ? selectedMediaIDs : [droppedItemID]
        project.moveMediaItems(idsToMove, toFolder: targetFolderID)
        if let targetFolderID {
            expandedFolderIDs.insert(targetFolderID)
        }
    }

    private func beginRenaming(folderID: MediaFolder.ID) {
        guard let folder = project.mediaFolders.first(where: { $0.id == folderID }) else {
            return
        }
        editingFolderID = folderID
        editingFolderName = folder.name
    }

    private func commitFolderRename(_ folderID: MediaFolder.ID) {
        let name = editingFolderName
        editingFolderID = nil
        project.renameMediaFolder(folderID, to: name)
        wantsKeyboardFocus = true
    }

    private func toggleFolderExpansion(_ folderID: MediaFolder.ID) {
        if expandedFolderIDs.contains(folderID) {
            collapseFolder(folderID)
        } else {
            expandedFolderIDs.insert(folderID)
        }
    }

    private func collapseFolder(_ folderID: MediaFolder.ID) {
        expandedFolderIDs.remove(folderID)
        let children = mediaIDs(inFolder: folderID)
        updateSelection { $0.collapse(folder: folderID, childIDs: children) }
    }

    private func setHovered(_ row: MediaPoolRowID, _ hovering: Bool) {
        if hovering {
            hoveredRowID = row
        } else if hoveredRowID == row {
            hoveredRowID = nil
        }
    }

    private func anyInFolder(_ ids: Set<MediaItem.ID>) -> Bool {
        project.mediaItems.contains { ids.contains($0.id) && $0.folderID != nil }
    }

    private var filteredMediaItems: [MediaItem] {
        let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return project.mediaItems.filter { item in
            if !statusFilter.includes(item.alignmentStatus) {
                return false
            }
            if !normalizedSearch.isEmpty,
               item.displayName.localizedCaseInsensitiveContains(normalizedSearch) == false {
                return false
            }
            return true
        }
    }

    private var isFilterActive: Bool {
        if statusFilter != .all { return true }
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        return false
    }

    private struct VisibleRow: Identifiable {
        enum Kind {
            case folder(MediaFolder, childCount: Int, isExpanded: Bool)
            case media(MediaItem, inFolder: Bool)
        }

        let id: String
        let kind: Kind

        var outlineRow: MediaPoolOutlineRow {
            switch kind {
            case .folder(let folder, _, let isExpanded):
                MediaPoolOutlineRow(id: .folder(folder.id), isExpanded: isExpanded)
            case .media(let item, let inFolder):
                MediaPoolOutlineRow(id: .media(item.id), parentFolderID: inFolder ? item.folderID : nil)
            }
        }
    }

    private var visibleRows: [VisibleRow] {
        let visibleItems = filteredMediaItems
        let visibleItemsByFolder = Dictionary(grouping: visibleItems) { $0.folderID }
        var rows: [VisibleRow] = []

        for folder in project.mediaFolders {
            let children = visibleItemsByFolder[folder.id] ?? []
            if isFilterActive && children.isEmpty {
                continue
            }
            let isExpanded = isFilterActive ? true : expandedFolderIDs.contains(folder.id)
            rows.append(
                VisibleRow(
                    id: "folder-\(folder.id.uuidString)",
                    kind: .folder(folder, childCount: children.count, isExpanded: isExpanded)
                )
            )
            if isExpanded {
                for item in children {
                    rows.append(
                        VisibleRow(
                            id: "media-\(item.id.uuidString)",
                            kind: .media(item, inFolder: true)
                        )
                    )
                }
            }
        }

        for item in (visibleItemsByFolder[nil] ?? []) {
            rows.append(
                VisibleRow(
                    id: "media-\(item.id.uuidString)",
                    kind: .media(item, inFolder: false)
                )
            )
        }

        return rows
    }

    private var outlineRows: [MediaPoolOutlineRow] {
        visibleRows.map(\.outlineRow)
    }

    private var allVisibleMediaIDs: [MediaItem.ID] {
        visibleRows.compactMap { row in
            if case .media(let item, _) = row.kind { return item.id }
            return nil
        }
    }

    private func mediaRow(_ item: MediaItem, emphasized: Bool) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(MediaBrowserColor.thumbnailBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(EditorTheme.borderSubtle, lineWidth: 1)
                }
                .overlay {
                    Image(systemName: "play.rectangle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(EditorTheme.textMuted)
                }
                .overlay(alignment: .topTrailing) {
                    if project.mediaPoolPreviewItemID == item.id {
                        Image(systemName: "play.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(3)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                            .offset(x: 3, y: -3)
                    }
                }
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(EditorTheme.bodyStrongFont)
                    .foregroundStyle(emphasized ? MediaBrowserColor.emphasizedText : EditorTheme.textPrimary)
                    .lineLimit(1)

                Text(MediaPoolFormat.subtitle(duration: item.duration, startDate: item.inferredStartDate))
                    .monospacedDigit()
                    .lineLimit(1)
                    .font(EditorTheme.captionFont)
                    .foregroundStyle(emphasized ? MediaBrowserColor.emphasizedSecondaryText : EditorTheme.textMuted)
                    .help(item.inferredStartDate.map { $0.formatted(date: .abbreviated, time: .standard) } ?? "")
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            MediaStatusSymbol(status: item.alignmentStatus, emphasized: emphasized)
        }
    }

    /// Scrolls in short windows, where the fixed-height placeholder would
    /// otherwise overflow the panel and clip its header.
    private var dropTargetPlaceholder: some View {
        GeometryReader { proxy in
            ScrollView {
                Group {
                    if hasActivity {
                        videoImportPlaceholder
                    } else {
                        fitImportPlaceholder
                    }
                }
                .frame(minHeight: proxy.size.height)
            }
        }
    }

    /// While a video is dragged over it, this explains why the drop is
    /// refused instead of reporting an error after the drop.
    private var fitImportPlaceholder: some View {
        let isRefusingDrop = isPlaceholderDropTarget
        return VStack(spacing: 8) {
            Spacer()
            StepIndicator(currentStep: .fit)
                .padding(.bottom, EditorTheme.space2)
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 32))
                .foregroundStyle(EditorTheme.textMuted)
            Text(isRefusingDrop ? "Import an Activity First" : "Import Activity")
                .font(EditorTheme.bodyStrongFont)
                .foregroundStyle(EditorTheme.textSecondary)
            Text(isRefusingDrop ? "Videos are matched to a FIT or GPX activity." : "Choose a FIT or GPX running activity")
                .font(EditorTheme.captionFont)
                .foregroundStyle(EditorTheme.textMuted)
                .multilineTextAlignment(.center)
            Button {
                project.importActivityFile()
            } label: {
                Label("Import Activity…", systemImage: "plus")
            }
            .buttonStyle(EditorPrimaryButtonStyle())
            Text("Then import videos")
                .font(EditorTheme.captionFont)
                .foregroundStyle(EditorTheme.textMuted)
            Spacer()
        }
        .padding(EditorTheme.space4)
        .frame(maxWidth: .infinity)
        .background(EditorTheme.panelBackground)
        .overlay {
            RoundedRectangle(cornerRadius: EditorTheme.panelRadius)
                .stroke(EditorTheme.borderSubtle, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .padding(EditorTheme.space4)
        }
    }

    private var videoImportPlaceholder: some View {
        let isAcceptingDrop = isPlaceholderDropTarget
        return VStack(spacing: 8) {
            Spacer()
            StepIndicator(currentStep: .videos)
                .padding(.bottom, EditorTheme.space2)
            Image(systemName: "video.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(isAcceptingDrop ? Color.accentColor : EditorTheme.textMuted)
            Text(isAcceptingDrop ? "Release to Import" : "Drop videos here")
                .font(EditorTheme.bodyStrongFont)
                .foregroundStyle(EditorTheme.textSecondary)
            Text("Import clips to match them with your running activity")
                .font(EditorTheme.captionFont)
                .foregroundStyle(EditorTheme.textMuted)
                .multilineTextAlignment(.center)
            Button {
                project.importVideos()
            } label: {
                Label("Import Videos…", systemImage: "plus")
            }
            .buttonStyle(EditorPrimaryButtonStyle())
            Text("MP4, MOV")
                .font(EditorTheme.captionFont)
                .foregroundStyle(EditorTheme.textMuted)
            Spacer()
        }
        .padding(EditorTheme.space4)
        .frame(maxWidth: .infinity)
        .background(EditorTheme.panelBackground)
        .overlay {
            RoundedRectangle(cornerRadius: EditorTheme.panelRadius)
                .fill(isAcceptingDrop ? Color.accentColor.opacity(0.08) : Color.clear)
                .overlay {
                    RoundedRectangle(cornerRadius: EditorTheme.panelRadius)
                        .stroke(
                            isAcceptingDrop ? Color.accentColor : EditorTheme.borderSubtle,
                            style: StrokeStyle(lineWidth: isAcceptingDrop ? 2 : 1, dash: [5, 5])
                        )
                }
                .padding(EditorTheme.space4)
                .allowsHitTesting(false)
        }
    }

    private var emptyFilterPlaceholder: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 28))
                .foregroundStyle(EditorTheme.textMuted)
            Text(filteredEmptyMessage)
                .font(EditorTheme.bodyFont)
                .foregroundStyle(EditorTheme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(EditorTheme.panelBackground)
    }

    private func rowBackground(index: Int, row: MediaPoolRowID, isDropTarget: Bool) -> Color {
        if isDropTarget {
            return Color.accentColor.opacity(0.12)
        }
        if selection.contains(row) {
            return isListEmphasized ? MediaBrowserColor.selectedRow : MediaBrowserColor.unemphasizedSelectedRow
        }
        if hoveredRowID == row {
            return MediaBrowserColor.hoverRow
        }
        return index.isMultiple(of: 2) ? MediaBrowserColor.evenRow : MediaBrowserColor.oddRow
    }

    private var visibleCountLabel: String {
        let count = filteredMediaItems.count
        return "\(count) \(count == 1 ? "clip" : "clips")"
    }

    private var filteredEmptyMessage: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "No media matches the current search"
        }
        return "No media matches the current filter"
    }

    private func importDroppedVideoFiles(_ providers: [NSItemProvider], intoFolder folderID: MediaFolder.ID? = nil) -> Bool {
        // The drop delegates refuse files before an activity exists, so this
        // is only a guard.
        guard hasActivity else {
            return false
        }

        let fileURLIdentifier = UTType.fileURL.identifier
        let collector = DroppedURLCollector()
        let group = DispatchGroup()

        for provider in providers where provider.hasItemConformingToTypeIdentifier(fileURLIdentifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: fileURLIdentifier, options: nil) { item, _ in
                defer { group.leave() }
                if let data = item as? Data,
                   let string = String(data: data, encoding: .utf8),
                   let url = URL(string: string) {
                    collector.append(url)
                } else if let url = item as? URL {
                    collector.append(url)
                }
            }
        }

        group.notify(queue: .main) {
            project.importVideoURLs(collector.urls, intoFolder: folderID)
        }
        return true
    }
}

/// Text for the second line of a media row.
enum MediaPoolFormat {
    /// `4:12`, or `1:02:05` past an hour, matching the Timeline.
    static func duration(_ duration: TimeInterval) -> String {
        let total = max(Int(duration.rounded(.down)), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Duration and start time without seconds, such as `4:12 · 8:39 AM`.
    /// The full date goes in the row's help tag.
    static func subtitle(duration: TimeInterval, startDate: Date?) -> String {
        guard let startDate else { return Self.duration(duration) }
        return "\(Self.duration(duration)) · \(startDate.formatted(date: .omitted, time: .shortened))"
    }
}

/// The workout-type pop-up shared by every Activity status row.
private struct WorkoutTypePicker: View {
    @EnvironmentObject private var project: ProjectDocument

    var body: some View {
        Picker(
            "Workout type",
            selection: Binding(
                get: { project.workoutStructureSelection },
                set: { newValue in
                    guard newValue != project.workoutStructureSelection else { return }
                    project.setWorkoutStructureSelection(newValue)
                }
            )
        ) {
            ForEach(WorkoutStructureSelection.allCases) { selection in
                Text(selection.label)
                    .tag(selection)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .controlSize(.small)
        .fixedSize()
        .help("Workout type")
    }
}

/// The system search field. Its cancel button and Escape clear the text.
private struct MediaSearchField: NSViewRepresentable {
    @Binding var text: String
    /// Incremented to move keyboard focus into the field (⌘F).
    var focusRequest: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = "Search"
        field.controlSize = .small
        field.font = .systemFont(ofSize: NSFont.systemFontSize(for: .small))
        field.sendsSearchStringImmediately = true
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.searchChanged(_:))
        field.setAccessibilityLabel("Search Media")
        context.coordinator.lastFocusRequest = focusRequest
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.text = $text
        if field.stringValue != text {
            field.stringValue = text
        }
        if context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            DispatchQueue.main.async {
                field.window?.makeFirstResponder(field)
            }
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>
        var lastFocusRequest = 0

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            text.wrappedValue = field.stringValue
        }

        @objc func searchChanged(_ sender: NSSearchField) {
            text.wrappedValue = sender.stringValue
        }
    }
}

/// Refuses drops the Media Pool cannot take while the pointer is still
/// moving, so the cursor never shows a `+` for a drop that would fail.
private struct MediaPoolDropDelegate: DropDelegate {
    /// Video files need an activity to match against.
    var acceptsFiles: Bool
    /// Rows dragged from inside the Media Pool.
    var acceptsMediaRows: Bool
    var onTargetChange: (Bool) -> Void
    var perform: ([NSItemProvider]) -> Bool

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.fileURL, .plainText])
    }

    func dropEntered(info: DropInfo) {
        onTargetChange(true)
    }

    func dropExited(info: DropInfo) {
        onTargetChange(false)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard let operation = operation(for: info) else {
            return DropProposal(operation: .forbidden)
        }
        return DropProposal(operation: operation)
    }

    func performDrop(info: DropInfo) -> Bool {
        onTargetChange(false)
        guard operation(for: info) != nil else { return false }
        return perform(info.itemProviders(for: [.fileURL, .plainText]))
    }

    private func operation(for info: DropInfo) -> DropOperation? {
        if info.hasItemsConforming(to: [.fileURL]) {
            return acceptsFiles ? .copy : nil
        }
        if info.hasItemsConforming(to: [.plainText]) {
            return acceptsMediaRows ? .move : nil
        }
        return nil
    }
}

/// Plain progress text, not a control: "✓ Activity · 2 Videos".
private struct StepIndicator: View {
    enum CurrentStep {
        case fit
        case videos
    }

    let currentStep: CurrentStep

    var body: some View {
        HStack(spacing: 6) {
            step(
                "Activity",
                systemImage: currentStep == .fit ? "1.circle" : "checkmark.circle.fill",
                color: currentStep == .fit ? EditorTheme.textPrimary : MediaBrowserColor.aligned,
                isCurrent: currentStep == .fit
            )
            Text("·")
                .foregroundStyle(EditorTheme.textMuted)
            step(
                "Videos",
                systemImage: "2.circle",
                color: currentStep == .videos ? EditorTheme.textPrimary : EditorTheme.textMuted,
                isCurrent: currentStep == .videos
            )
        }
        .font(EditorTheme.captionFont)
        .accessibilityElement(children: .combine)
    }

    private func step(_ label: String, systemImage: String, color: Color, isCurrent: Bool) -> some View {
        Label(label, systemImage: systemImage)
            .labelStyle(.titleAndIcon)
            .fontWeight(isCurrent ? .semibold : .regular)
            .foregroundStyle(color)
    }
}

/// Which Media Pool owns the keyboard. `MainEditorView` checks this so its
/// window-wide Delete does not act on the editor selection while the list
/// is focused.
enum MediaPoolKeyFocus {
    @MainActor static func owns(_ responder: NSResponder?) -> Bool {
        responder is MediaBrowserKeyCaptureView
    }
}

private struct MediaBrowserKeyHandler: NSViewRepresentable {
    @Binding var wantsFocus: Bool
    @Binding var hasFocus: Bool
    var onCommand: (MediaPoolKeyCommand) -> Bool
    var onFocusLost: () -> Void

    func makeNSView(context: Context) -> MediaBrowserKeyCaptureView {
        let view = MediaBrowserKeyCaptureView()
        configure(view)
        return view
    }

    func updateNSView(_ nsView: MediaBrowserKeyCaptureView, context: Context) {
        configure(nsView)

        let isFirstResponder = nsView.window?.firstResponder === nsView
        // Claim focus once per request. Re-claiming on every update would
        // pull keys back from a timeline or canvas click that landed before
        // the async focus-lost callback cleared `wantsFocus`.
        if !wantsFocus {
            nsView.hasPendingFocusRequest = false
        }
        if wantsFocus, !isFirstResponder, !nsView.hasPendingFocusRequest, nsView.window != nil {
            nsView.hasPendingFocusRequest = true
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        } else if !wantsFocus, isFirstResponder {
            DispatchQueue.main.async {
                if nsView.window?.firstResponder === nsView {
                    nsView.window?.makeFirstResponder(nil)
                }
            }
        }
    }

    private func configure(_ view: MediaBrowserKeyCaptureView) {
        view.onCommand = onCommand
        view.onFocusChange = { focused in
            hasFocus = focused
            wantsFocus = focused
            if !focused {
                onFocusLost()
            }
        }
    }
}

private final class MediaBrowserKeyCaptureView: NSView {
    var onCommand: ((MediaPoolKeyCommand) -> Bool)?
    var onFocusChange: ((Bool) -> Void)?
    var hasPendingFocusRequest = false

    override var acceptsFirstResponder: Bool {
        true
    }

    /// The list draws its own focus ring around the rows.
    override var focusRingType: NSFocusRingType {
        get { .none }
        set {}
    }

    override func becomeFirstResponder() -> Bool {
        let didBecome = super.becomeFirstResponder()
        if didBecome {
            DispatchQueue.main.async { [weak self] in
                self?.onFocusChange?(true)
            }
        }
        return didBecome
    }

    override func resignFirstResponder() -> Bool {
        let didResign = super.resignFirstResponder()
        if didResign {
            DispatchQueue.main.async { [weak self] in
                self?.onFocusChange?(false)
            }
        }
        return didResign
    }

    override func keyDown(with event: NSEvent) {
        if let command = MediaPoolKeyCommand(
            keyCode: event.keyCode,
            modifiers: event.modifierFlags,
            characters: event.charactersIgnoringModifiers
        ), onCommand?(command) == true {
            return
        }
        super.keyDown(with: event)
    }

    /// Edit > Select All.
    override func selectAll(_ sender: Any?) {
        _ = onCommand?(.selectAll)
    }

    /// Edit > Delete.
    @objc func delete(_ sender: Any?) {
        _ = onCommand?(.delete)
    }
}

private enum MediaStatusFilter: String, CaseIterable, Identifiable {
    case all
    case ready
    case aligned

    var id: String { rawValue }

    @ViewBuilder
    var label: some View {
        switch self {
        case .all:
            Text("All")
        case .ready:
            Label("Ready", systemImage: MediaStatusSymbol.symbolName(for: .readyToMatch(source: "")))
        case .aligned:
            Label("Aligned", systemImage: MediaStatusSymbol.symbolName(for: .aligned(source: "")))
        }
    }

    func includes(_ status: AlignmentStatus) -> Bool {
        switch (self, status) {
        case (.all, _):
            true
        case (.ready, .readyToMatch):
            true
        case (.aligned, .aligned):
            true
        default:
            false
        }
    }
}

/// Alignment status as a symbol plus colour, so it reads without colour.
private struct MediaStatusSymbol: View {
    let status: AlignmentStatus
    var emphasized = false

    static func symbolName(for status: AlignmentStatus) -> String {
        switch status {
        case .aligned:
            "checkmark.circle.fill"
        case .readyToMatch:
            "clock"
        case .needsManualPlacement:
            "questionmark.circle"
        }
    }

    var body: some View {
        Image(systemName: Self.symbolName(for: status))
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(emphasized ? MediaBrowserColor.emphasizedText : color)
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
            .help(status.helpText)
            .accessibilityLabel(status.helpText)
    }

    private var color: Color {
        switch status {
        case .aligned:
            MediaBrowserColor.aligned
        case .readyToMatch:
            MediaBrowserColor.ready
        case .needsManualPlacement:
            MediaBrowserColor.manual
        }
    }
}

private enum MediaBrowserColor {
    static let panel = EditorTheme.panelBackground
    static let evenRow = EditorTheme.panelHeader
    static let oddRow = EditorTheme.panelBackground
    static let hoverRow = Color(nsColor: .quaternarySystemFill)
    static let selectedRow = Color(nsColor: .selectedContentBackgroundColor)
    static let unemphasizedSelectedRow = Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
    static let emphasizedText = Color(nsColor: .alternateSelectedControlTextColor)
    static let emphasizedSecondaryText = Color(nsColor: .alternateSelectedControlTextColor).opacity(0.8)
    static let focusRing = Color(nsColor: .keyboardFocusIndicatorColor)
    static let thumbnailBackground = Color(nsColor: .underPageBackgroundColor)
    static let aligned = Color(nsColor: .systemGreen)
    static let ready = Color(nsColor: .systemYellow)
    static let manual = Color(nsColor: .systemGray)
}

private struct MediaPoolStripeBackground: View {
    let rowHeight: CGFloat

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                ForEach(0..<stripeCount(for: proxy.size.height), id: \.self) { index in
                    (index.isMultiple(of: 2) ? MediaBrowserColor.evenRow : MediaBrowserColor.oddRow)
                        .frame(height: rowHeight)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(MediaBrowserColor.panel)
        }
    }

    private func stripeCount(for height: CGFloat) -> Int {
        max(Int(ceil(height / max(rowHeight, 1))) + 1, 1)
    }
}

private final class DroppedURLCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URL] = []

    var urls: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ url: URL) {
        lock.lock()
        storage.append(url)
        lock.unlock()
    }
}
