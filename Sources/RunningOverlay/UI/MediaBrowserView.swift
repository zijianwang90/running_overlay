import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MediaBrowserView: View {
    @EnvironmentObject private var project: ProjectDocument
    @State private var selectedMediaIDs: Set<MediaItem.ID> = []
    @State private var selectionAnchorID: MediaItem.ID?
    @State private var expandedFolderIDs: Set<MediaFolder.ID> = []
    @State private var editingFolderID: MediaFolder.ID?
    @State private var editingFolderName: String = ""
    @State private var statusFilter: MediaStatusFilter = .all
    @State private var searchText = ""
    @State private var hoveredMediaID: MediaItem.ID?
    @State private var hoveredFolderID: MediaFolder.ID?
    @State private var dropTargetFolderID: MediaFolder.ID?
    @State private var isRootDropTarget = false
    @State private var isMediaBrowserActive = false
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
                isActive: $isMediaBrowserActive,
                onSelectAll: {
                    selectedMediaIDs = Set(allVisibleMediaIDs)
                },
                onFocusLost: {
                    project.clearMediaPoolPreview()
                }
            )
        )
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            importDroppedVideoFiles(providers)
        }
        .onChange(of: project.mediaItems.map(\.id)) { _, ids in
            selectedMediaIDs.formIntersection(Set(ids))
            if let anchor = selectionAnchorID, !ids.contains(anchor) {
                selectionAnchorID = nil
            }
        }
        .onChange(of: project.mediaFolders.map(\.id)) { _, ids in
            expandedFolderIDs.formIntersection(Set(ids))
            if let editing = editingFolderID, !ids.contains(editing) {
                editingFolderID = nil
            }
        }
        .onChange(of: statusFilter) { _, _ in
            pruneSelectionToVisibleItems()
        }
        .onChange(of: searchText) { _, _ in
            pruneSelectionToVisibleItems()
        }
    }

    private var header: some View {
        EditorPanelHeader(title: "Media") {
            Button {
                let newID = project.createMediaFolder(containing: rootSelectedMediaIDs)
                expandedFolderIDs.insert(newID)
                beginRenaming(folderID: newID)
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .buttonStyle(EditorIconButtonStyle(isEnabled: true))
            .help(rootSelectedMediaIDs.isEmpty ? "New Folder" : "New Folder from \(rootSelectedMediaIDs.count) Selected Item(s)")
            .accessibilityLabel("New Folder")

            Button {
                selectedMediaIDs = Set(allVisibleMediaIDs)
            } label: {
                Image(systemName: "checklist")
            }
            .buttonStyle(EditorIconButtonStyle(isEnabled: !allVisibleMediaIDs.isEmpty))
            .help("Select All Visible Media")
            .accessibilityLabel("Select All Visible Media")
            .disabled(allVisibleMediaIDs.isEmpty)

            Button {
                selectedMediaIDs.removeAll()
                selectionAnchorID = nil
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(EditorIconButtonStyle(isEnabled: !selectedMediaIDs.isEmpty))
            .help("Clear Media Selection")
            .accessibilityLabel("Clear Media Selection")
            .disabled(selectedMediaIDs.isEmpty)
        }
    }

    private var searchAndFilterStrip: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: EditorTheme.space2) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(EditorTheme.textMuted)
                TextField("Search media", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(EditorTheme.bodyFont)
                    .foregroundStyle(EditorTheme.textPrimary)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(EditorTheme.textMuted)
                    .help("Clear Search")
                }
            }
            .padding(.horizontal, EditorTheme.space2)
            .frame(height: 30)
            .background(EditorTheme.surfaceControl)
            .clipShape(RoundedRectangle(cornerRadius: EditorTheme.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: EditorTheme.controlRadius)
                    .stroke(EditorTheme.borderSubtle, lineWidth: 1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(EditorTheme.borderSubtle)
                    .frame(height: 1)
            }

            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Text(visibleCountLabel)
                        .font(EditorTheme.captionFont)
                        .foregroundStyle(EditorTheme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(MediaStatusFilter.allCases) { filter in
                        Button {
                            statusFilter = filter
                        } label: {
                            Text(filter.label)
                        }
                        .buttonStyle(MediaFilterChipStyle(isSelected: statusFilter == filter))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, !project.mediaItems.isEmpty && project.activity.duration > 0 ? 4 : 8)

                if !project.mediaItems.isEmpty && project.activity.duration > 0 {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(EditorTheme.successGreen)
                            .frame(width: 6, height: 6)
                        Text(project.fitSourceName.isEmpty ? "FIT loaded" : project.fitSourceName)
                            .font(EditorTheme.captionFont)
                            .foregroundStyle(EditorTheme.textMuted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            project.importFitFile()
                        } label: {
                            Text("Replace")
                                .font(EditorTheme.captionFont)
                                .foregroundStyle(EditorTheme.textMuted)
                                .underline()
                        }
                        .buttonStyle(.plain)
                        .help("Replace the current FIT file")
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(EditorTheme.borderSubtle)
                    .frame(height: 1)
            }
        }
        .background(EditorTheme.panelBackground)
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
                    selectedMediaIDs.removeAll()
                    selectionAnchorID = nil
                    isMediaBrowserActive = true
                }
                .background(MediaPoolStripeBackground(rowHeight: EditorTheme.mediaRowHeight))
                .background(
                    rootDropOverlayBackground
                )
                .onDrop(
                    of: [UTType.text.identifier, UTType.fileURL.identifier],
                    delegate: MediaPoolDropDelegate(
                        targetFolderID: nil,
                        selectedMediaIDs: selectedMediaIDs,
                        isHighlighted: $isRootDropTarget,
                        onMoveItem: performDrop,
                        onImportFiles: { urls, folder in
                            importVideoURLs(urls, intoFolder: folder)
                        }
                    )
                )
        )
    }

    @ViewBuilder
    private var rootDropOverlayBackground: some View {
        if isRootDropTarget {
            Rectangle()
                .fill(EditorTheme.accentBlue.opacity(0.08))
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
        let isHovered = hoveredFolderID == folder.id
        let isDropTarget = dropTargetFolderID == folder.id
        let isEditing = editingFolderID == folder.id

        return HStack(spacing: 8) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(EditorTheme.textMuted)
                .frame(width: 12)
            Image(systemName: isExpanded ? "folder" : "folder.fill")
                .font(.system(size: 14))
                .foregroundStyle(EditorTheme.accentBlue)
            if isEditing {
                folderRenameField(folder: folder)
            } else {
                Text(folder.name)
                    .font(EditorTheme.bodyStrongFont)
                    .foregroundStyle(EditorTheme.textPrimary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if !isEditing {
                Text("\(childCount)")
                    .font(EditorTheme.captionFont.monospacedDigit())
                    .foregroundStyle(EditorTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .frame(height: EditorTheme.mediaRowHeight, alignment: .center)
        .background(folderBackground(index: index, isHovered: isHovered, isDropTarget: isDropTarget))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(EditorTheme.borderSubtle.opacity(0.72))
                .frame(height: 1)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredFolderID = hovering ? folder.id : (hoveredFolderID == folder.id ? nil : hoveredFolderID)
        }
        .onTapGesture {
            if isEditing {
                return
            }
            toggleFolderExpansion(folder.id)
            isMediaBrowserActive = true
        }
        .contextMenu {
            Button("Auto Match to Current Layer") {
                project.matchMediaItemsToCurrentLayer(mediaIDs(inFolder: folder.id))
            }
            .disabled(mediaIDs(inFolder: folder.id).isEmpty)
            Button("Match to New Layer") {
                project.matchMediaItemsToNewLayer(mediaIDs(inFolder: folder.id))
            }
            .disabled(mediaIDs(inFolder: folder.id).isEmpty)
            Divider()
            Button("Rename Folder") { beginRenaming(folderID: folder.id) }
            Button("Delete Folder") { project.deleteMediaFolder(folder.id) }
        }
        .onDrop(
            of: [UTType.text.identifier, UTType.fileURL.identifier],
            delegate: MediaPoolDropDelegate(
                targetFolderID: folder.id,
                selectedMediaIDs: selectedMediaIDs,
                isHighlighted: Binding(
                    get: { dropTargetFolderID == folder.id },
                    set: { newValue in
                        dropTargetFolderID = newValue ? folder.id : (dropTargetFolderID == folder.id ? nil : dropTargetFolderID)
                    }
                ),
                onMoveItem: performDrop,
                onImportFiles: { urls, target in
                    importVideoURLs(urls, intoFolder: target)
                }
            )
        )
    }

    private func mediaRowContainer(item: MediaItem, inFolder: Bool, index: Int) -> some View {
        mediaRow(item, inFolder: inFolder)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, inFolder ? 28 : 12)
            .padding(.trailing, 12)
            .frame(height: EditorTheme.mediaRowHeight, alignment: .center)
            .background(rowBackground(index: index, item: item))
            .overlay(alignment: .leading) {
                if selectedMediaIDs.contains(item.id) {
                    Rectangle()
                        .fill(EditorTheme.accentBlue)
                        .frame(width: 2)
                }
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(EditorTheme.borderSubtle.opacity(0.72))
                    .frame(height: 1)
            }
            .contentShape(Rectangle())
            .onHover { isHovering in
                hoveredMediaID = isHovering ? item.id : (hoveredMediaID == item.id ? nil : hoveredMediaID)
            }
            .onTapGesture {
                handleMediaTap(item)
            }
            .contextMenu {
                Button("Auto Match to Current Layer") {
                    project.matchMediaItemsToCurrentLayer(actionIDs(for: item))
                }
                Button("Match to New Layer") {
                    project.matchMediaItemsToNewLayer(actionIDs(for: item))
                }
                Divider()
                Menu("Add to Folder") {
                    Button("New Folder from Selection") {
                        let ids = actionIDs(for: item).intersection(rootMediaIDs)
                        let newID = project.createMediaFolder(containing: ids)
                        expandedFolderIDs.insert(newID)
                        beginRenaming(folderID: newID)
                    }
                    if !project.mediaFolders.isEmpty {
                        Divider()
                        ForEach(project.mediaFolders) { folder in
                            Button(folder.name) {
                                project.moveMediaItems(actionIDs(for: item), toFolder: folder.id)
                                expandedFolderIDs.insert(folder.id)
                            }
                        }
                    }
                }
                if anyInFolder(actionIDs(for: item)) {
                    Button("Move to Root") {
                        project.moveMediaItems(actionIDs(for: item), toFolder: nil)
                    }
                }
                Divider()
                Button("Select All") {
                    selectedMediaIDs = Set(allVisibleMediaIDs)
                }
                Button("Delete from Media Pool") {
                    let ids = actionIDs(for: item)
                    selectedMediaIDs.subtract(ids)
                    project.deleteMediaItems(ids)
                }
            }
            .onDrag {
                NSItemProvider(object: item.id.uuidString as NSString)
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                importDroppedVideoFiles(providers, intoFolder: nil)
            }
    }

    private func importVideoURLs(_ urls: [URL], intoFolder folderID: MediaFolder.ID?) {
        project.importVideoURLs(urls, replacingExisting: false, intoFolder: folderID)
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
                    .stroke(EditorTheme.accentBlue, lineWidth: 1.5)
            }
            .frame(maxWidth: .infinity)
    }

    private func handleMediaTap(_ item: MediaItem) {
        isMediaBrowserActive = true
        let clickCount = NSApp.currentEvent?.clickCount ?? 1
        if clickCount >= 2 {
            selectedMediaIDs = [item.id]
            selectionAnchorID = item.id
            project.previewMediaPoolItem(item.id)
            return
        }
        let modifiers = NSEvent.modifierFlags
        if modifiers.contains(.shift), let anchor = selectionAnchorID {
            let ids = allVisibleMediaIDs
            if let anchorIndex = ids.firstIndex(of: anchor), let targetIndex = ids.firstIndex(of: item.id) {
                let range = anchorIndex <= targetIndex ? anchorIndex...targetIndex : targetIndex...anchorIndex
                selectedMediaIDs = Set(ids[range])
                return
            }
        }
        if modifiers.contains(.command) {
            if selectedMediaIDs.contains(item.id) {
                selectedMediaIDs.remove(item.id)
            } else {
                selectedMediaIDs.insert(item.id)
            }
            selectionAnchorID = item.id
            return
        }
        selectedMediaIDs = [item.id]
        selectionAnchorID = item.id
    }

    private func performDrop(droppedItemID: MediaItem.ID, draggedFromSelection: Bool, targetFolderID: MediaFolder.ID?) {
        let idsToMove: Set<MediaItem.ID>
        if draggedFromSelection {
            idsToMove = selectedMediaIDs
        } else {
            idsToMove = [droppedItemID]
        }
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
    }

    private func toggleFolderExpansion(_ folderID: MediaFolder.ID) {
        if expandedFolderIDs.contains(folderID) {
            expandedFolderIDs.remove(folderID)
            let idsInFolder = Set(project.mediaItems.filter { $0.folderID == folderID }.map(\.id))
            if !idsInFolder.isEmpty {
                selectedMediaIDs.subtract(idsInFolder)
                if let anchor = selectionAnchorID, idsInFolder.contains(anchor) {
                    selectionAnchorID = nil
                }
            }
        } else {
            expandedFolderIDs.insert(folderID)
        }
    }

    private func anyInFolder(_ ids: Set<MediaItem.ID>) -> Bool {
        project.mediaItems.contains { ids.contains($0.id) && $0.folderID != nil }
    }

    private var rootMediaIDs: Set<MediaItem.ID> {
        Set(project.mediaItems.filter { $0.folderID == nil }.map(\.id))
    }

    private var rootSelectedMediaIDs: Set<MediaItem.ID> {
        selectedMediaIDs.intersection(rootMediaIDs)
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

    private var allVisibleMediaIDs: [MediaItem.ID] {
        visibleRows.compactMap { row in
            if case .media(let item, _) = row.kind { return item.id }
            return nil
        }
    }

    private func mediaRow(_ item: MediaItem, inFolder: Bool) -> some View {
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
                        .background(EditorTheme.accentBlue)
                        .clipShape(Circle())
                        .offset(x: 3, y: -3)
                }
                }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(EditorTheme.bodyStrongFont)
                    .foregroundStyle(EditorTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: EditorTheme.space2) {
                    Text(formatDuration(item.duration))
                        .monospacedDigit()
                    if let inferredStartDate = item.inferredStartDate {
                        Text(inferredStartDate.formatted(date: .abbreviated, time: .standard))
                            .lineLimit(1)
                    }
                }
                .font(EditorTheme.captionFont)
                .foregroundStyle(EditorTheme.textMuted)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            MediaStatusDot(status: item.alignmentStatus, size: 8)
        }
    }

    @ViewBuilder private var dropTargetPlaceholder: some View {
        if project.activity.duration <= 0 {
            fitImportPlaceholder
        } else {
            videoImportPlaceholder
        }
    }

    private var fitImportPlaceholder: some View {
        VStack(spacing: 8) {
            Spacer()
            StepIndicator(currentStep: .fit)
                .padding(.bottom, EditorTheme.space2)
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 32))
                .foregroundStyle(EditorTheme.textMuted)
            Text("Import FIT")
                .font(EditorTheme.bodyStrongFont)
                .foregroundStyle(EditorTheme.textSecondary)
            Text("Start with running activity data")
                .font(EditorTheme.captionFont)
                .foregroundStyle(EditorTheme.textMuted)
                .multilineTextAlignment(.center)
            Button {
                project.importFitFile()
            } label: {
                Label("Import FIT", systemImage: "plus")
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
        VStack(spacing: 8) {
            Spacer()
            StepIndicator(currentStep: .videos)
            Button {
                project.importFitFile()
            } label: {
                Text("Replace FIT")
                    .font(EditorTheme.captionFont)
                    .foregroundStyle(EditorTheme.textMuted)
                    .underline()
            }
            .buttonStyle(.plain)
            .help("Replace the current FIT file")
            .padding(.bottom, EditorTheme.space2)
            Image(systemName: "video.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(EditorTheme.textMuted)
            Text("Drop videos here")
                .font(EditorTheme.bodyStrongFont)
                .foregroundStyle(EditorTheme.textSecondary)
            Text("Import clips to match them with your running activity")
                .font(EditorTheme.captionFont)
                .foregroundStyle(EditorTheme.textMuted)
                .multilineTextAlignment(.center)
            Button {
                project.importVideos()
            } label: {
                Label("Import Videos", systemImage: "plus")
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
                .stroke(EditorTheme.borderSubtle, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .padding(EditorTheme.space4)
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

    private func actionIDs(for item: MediaItem) -> Set<MediaItem.ID> {
        if selectedMediaIDs.contains(item.id) {
            return selectedMediaIDs
        }
        return [item.id]
    }

    private func rowBackground(index: Int, item: MediaItem) -> Color {
        if selectedMediaIDs.contains(item.id) {
            return MediaBrowserColor.selectedRow
        }
        if hoveredMediaID == item.id {
            return MediaBrowserColor.hoverRow
        }
        return index.isMultiple(of: 2) ? MediaBrowserColor.evenRow : MediaBrowserColor.oddRow
    }

    private func folderBackground(index: Int, isHovered: Bool, isDropTarget: Bool) -> Color {
        if isDropTarget {
            return EditorTheme.accentBlue.opacity(0.18)
        }
        if isHovered {
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

    private func pruneSelectionToVisibleItems() {
        let visible = Set(filteredMediaItems.map(\.id))
        selectedMediaIDs.formIntersection(visible)
        if let anchor = selectionAnchorID, !visible.contains(anchor) {
            selectionAnchorID = nil
        }
    }

    private func importDroppedVideoFiles(_ providers: [NSItemProvider], intoFolder folderID: MediaFolder.ID? = nil) -> Bool {
        guard project.activity.duration > 0 else {
            project.statusMessage = "Import a FIT file before importing videos."
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
            project.importVideoURLs(collector.urls, replacingExisting: false, intoFolder: folderID)
        }
        return true
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes)m \(seconds)s"
    }
}

private struct MediaPoolDropDelegate: DropDelegate {
    let targetFolderID: MediaFolder.ID?
    let selectedMediaIDs: Set<MediaItem.ID>
    @Binding var isHighlighted: Bool
    let onMoveItem: @MainActor @Sendable (MediaItem.ID, Bool, MediaFolder.ID?) -> Void
    let onImportFiles: @MainActor @Sendable ([URL], MediaFolder.ID?) -> Void

    func dropEntered(info: DropInfo) {
        isHighlighted = true
    }

    func dropExited(info: DropInfo) {
        isHighlighted = false
    }

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text.identifier, UTType.fileURL.identifier])
    }

    func performDrop(info: DropInfo) -> Bool {
        isHighlighted = false
        let folderID = targetFolderID

        let fileProviders = info.itemProviders(for: [UTType.fileURL.identifier])
        if !fileProviders.isEmpty {
            let collector = DroppedURLCollector()
            let group = DispatchGroup()
            for provider in fileProviders {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
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
            let importFiles = onImportFiles
            group.notify(queue: .main) {
                Task { @MainActor in
                    importFiles(collector.urls, folderID)
                }
            }
            return true
        }

        let textProviders = info.itemProviders(for: [UTType.text.identifier])
        guard let provider = textProviders.first else { return false }
        let selected = selectedMediaIDs
        let move = onMoveItem
        provider.loadObject(ofClass: NSString.self) { reading, _ in
            guard let string = reading as? String, let mediaID = UUID(uuidString: string) else { return }
            let draggedFromSelection = selected.contains(mediaID)
            Task { @MainActor in
                move(mediaID, draggedFromSelection, folderID)
            }
        }
        return true
    }
}

private struct StepIndicator: View {
    enum CurrentStep {
        case fit
        case videos
    }

    let currentStep: CurrentStep

    var body: some View {
        HStack(spacing: EditorTheme.space2) {
            step(label: "1 FIT", state: currentStep == .fit ? .active : .complete)

            Rectangle()
                .fill(EditorTheme.borderSubtle)
                .frame(width: 18, height: 1)

            step(label: "2 Videos", state: currentStep == .videos ? .active : .inactive)
        }
    }

    private func step(label: String, state: StepState) -> some View {
        Text(label)
            .font(EditorTheme.captionFont.weight(.medium))
            .foregroundStyle(state.foreground)
            .padding(.horizontal, EditorTheme.space2)
            .frame(height: 22)
            .background(state.background)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(state.border, lineWidth: 1)
            }
    }

    private enum StepState {
        case active
        case complete
        case inactive

        var foreground: Color {
            switch self {
            case .active:
                Color.white
            case .complete:
                EditorTheme.successGreen
            case .inactive:
                EditorTheme.textMuted
            }
        }

        var background: Color {
            switch self {
            case .active:
                EditorTheme.accentBlue
            case .complete:
                EditorTheme.surfaceControl
            case .inactive:
                EditorTheme.surfacePressed
            }
        }

        var border: Color {
            switch self {
            case .active:
                EditorTheme.accentBlue
            case .complete:
                EditorTheme.successGreen.opacity(0.7)
            case .inactive:
                EditorTheme.borderSubtle
            }
        }
    }
}

private struct MediaBrowserKeyHandler: NSViewRepresentable {
    @Binding var isActive: Bool
    var onSelectAll: () -> Void
    var onFocusLost: () -> Void

    func makeNSView(context: Context) -> MediaBrowserKeyCaptureView {
        let view = MediaBrowserKeyCaptureView()
        view.onSelectAll = onSelectAll
        view.onFocusLost = {
            isActive = false
            onFocusLost()
        }
        return view
    }

    func updateNSView(_ nsView: MediaBrowserKeyCaptureView, context: Context) {
        nsView.onSelectAll = onSelectAll
        nsView.onFocusLost = {
            isActive = false
            onFocusLost()
        }

        guard isActive, nsView.window?.firstResponder !== nsView else {
            return
        }
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class MediaBrowserKeyCaptureView: NSView {
    var onSelectAll: (() -> Void)?
    var onFocusLost: (() -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override var focusRingType: NSFocusRingType {
        get { .none }
        set {}
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "a" {
            onSelectAll?()
            return
        }
        super.keyDown(with: event)
    }

    override func resignFirstResponder() -> Bool {
        let didResign = super.resignFirstResponder()
        if didResign {
            DispatchQueue.main.async { [weak self] in
                self?.onFocusLost?()
            }
        }
        return didResign
    }
}

private enum MediaStatusFilter: String, CaseIterable, Identifiable {
    case all
    case ready
    case aligned

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:
            "All"
        case .ready:
            "Ready"
        case .aligned:
            "Aligned"
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

private struct MediaFilterChipStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(isSelected ? Color.white : EditorTheme.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(background(isPressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? EditorTheme.accentBlue : EditorTheme.borderSubtle, lineWidth: 1)
            }
    }

    private func background(isPressed: Bool) -> Color {
        if isPressed {
            return EditorTheme.surfacePressed
        }
        return isSelected ? EditorTheme.accentBlue : EditorTheme.surfaceControl
    }
}

private struct MediaStatusDot: View {
    let status: AlignmentStatus
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(fill)
            .overlay {
                Circle()
                    .stroke(stroke, lineWidth: max(size * 0.08, 1))
            }
            .frame(width: size, height: size)
            .help(status.label)
            .accessibilityLabel(status.label)
    }

    private var fill: Color {
        switch status {
        case .aligned:
            EditorTheme.successGreen
        case .readyToMatch:
            EditorTheme.warningYellow
        case .needsManualPlacement:
            EditorTheme.textMuted
        }
    }

    private var stroke: Color {
        switch status {
        case .aligned:
            EditorTheme.successGreen.opacity(0.78)
        case .readyToMatch:
            EditorTheme.warningYellow.opacity(0.78)
        case .needsManualPlacement:
            EditorTheme.textMuted.opacity(0.78)
        }
    }
}

private enum MediaBrowserColor {
    static let panel = EditorTheme.panelBackground
    static let evenRow = EditorTheme.panelHeader
    static let oddRow = EditorTheme.panelBackground
    static let hoverRow = Color(hex: 0x222932)
    static let selectedRow = EditorTheme.surfaceSelected
    static let thumbnailBackground = Color(hex: 0x101418)
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
