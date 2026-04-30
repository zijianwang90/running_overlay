import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MediaBrowserView: View {
    @EnvironmentObject private var project: ProjectDocument
    @State private var selectedMediaIDs: Set<MediaItem.ID> = []
    @State private var selectedFilterTag: MediaTag?
    @State private var statusFilter: MediaStatusFilter = .all
    @State private var searchText = ""
    @State private var hoveredMediaID: MediaItem.ID?
    @State private var isMediaBrowserActive = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            searchAndFilterStrip

            if project.mediaItems.isEmpty {
                dropTargetPlaceholder
            } else if filteredMediaItems.isEmpty {
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
                    selectedMediaIDs = Set(filteredMediaItems.map(\.id))
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
        }
        .onChange(of: selectedFilterTag) { _, _ in
            pruneSelectionToVisibleItems()
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
                selectedMediaIDs = Set(filteredMediaItems.map(\.id))
            } label: {
                Image(systemName: "checklist")
            }
            .buttonStyle(EditorIconButtonStyle(isEnabled: !filteredMediaItems.isEmpty))
            .help("Select All Visible Media")
            .accessibilityLabel("Select All Visible Media")
            .disabled(filteredMediaItems.isEmpty)

            Button {
                selectedMediaIDs.removeAll()
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(EditorIconButtonStyle(isEnabled: !selectedMediaIDs.isEmpty))
            .help("Clear Media Selection")
            .accessibilityLabel("Clear Media Selection")
            .disabled(selectedMediaIDs.isEmpty)

            filterMenu
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
                ForEach(Array(filteredMediaItems.enumerated()), id: \.element.id) { index, item in
                    mediaRow(item)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
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
                        .onTapGesture(count: 2) {
                            selectedMediaIDs = [item.id]
                            isMediaBrowserActive = true
                            project.previewMediaPoolItem(item.id)
                        }
                        .onTapGesture {
                            selectMediaItem(item)
                        }
                        .contextMenu {
                            Button("Auto Match to Current Layer") {
                                project.matchMediaItemsToCurrentLayer(actionIDs(for: item))
                            }
                            Button("Match to New Layer") {
                                project.matchMediaItemsToNewLayer(actionIDs(for: item))
                            }
                            Divider()
                            Menu("Mark") {
                                ForEach(MediaTag.allCases) { tag in
                                    Button {
                                        project.setMediaTag(tag, for: actionIDs(for: item))
                                    } label: {
                                        Label {
                                            Text(tag.label)
                                        } icon: {
                                            Image(nsImage: tag.menuIcon)
                                        }
                                    }
                                }
                                Button("Clear Mark") {
                                    project.setMediaTag(nil, for: actionIDs(for: item))
                                }
                            }
                            Divider()
                            Button("Select All") {
                                selectedMediaIDs = Set(filteredMediaItems.map(\.id))
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
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(MediaPoolStripeBackground(rowHeight: EditorTheme.mediaRowHeight))
    }

    private var filterMenu: some View {
        Menu {
            Button {
                selectedFilterTag = nil
            } label: {
                Label {
                    Text("All")
                } icon: {
                    Image(systemName: selectedFilterTag == nil ? "checkmark.circle.fill" : "circle")
                }
            }
            Divider()
            ForEach(MediaTag.allCases) { tag in
                Button {
                    selectedFilterTag = tag
                } label: {
                    MediaTagFilterMenuLabel(
                        tag: tag,
                        isSelected: selectedFilterTag == tag
                    )
                }
            }
        } label: {
            if let selectedFilterTag {
                MediaTagDot(tag: selectedFilterTag, size: 14)
            } else {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: EditorTheme.iconButtonSize, height: EditorTheme.iconButtonSize)
        .background(EditorTheme.surfaceControl)
        .clipShape(RoundedRectangle(cornerRadius: EditorTheme.controlRadius))
        .overlay {
            RoundedRectangle(cornerRadius: EditorTheme.controlRadius)
                .stroke(EditorTheme.borderSubtle, lineWidth: 1)
        }
        .help("Filter by Mark")
        .accessibilityLabel("Filter by Mark")
    }

    private var filteredMediaItems: [MediaItem] {
        let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return project.mediaItems.filter { item in
            if let selectedFilterTag, item.tag != selectedFilterTag {
                return false
            }
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

    private func mediaRow(_ item: MediaItem) -> some View {
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

            if let tag = item.tag {
                MediaTagDot(tag: tag, size: 8)
                    .help(tag.label)
            }

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

    private func selectMediaItem(_ item: MediaItem) {
        isMediaBrowserActive = true
        if NSEvent.modifierFlags.contains(.command) {
            if selectedMediaIDs.contains(item.id) {
                selectedMediaIDs.remove(item.id)
            } else {
                selectedMediaIDs.insert(item.id)
            }
        } else {
            selectedMediaIDs = [item.id]
        }
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

    private var visibleCountLabel: String {
        "\(filteredMediaItems.count) \(filteredMediaItems.count == 1 ? "clip" : "clips")"
    }

    private var filteredEmptyMessage: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "No media matches the current search"
        }
        if selectedFilterTag != nil {
            return "No media with this mark"
        }
        return "No media matches the current filter"
    }

    private func pruneSelectionToVisibleItems() {
        selectedMediaIDs.formIntersection(Set(filteredMediaItems.map(\.id)))
    }

    private func importDroppedVideoFiles(_ providers: [NSItemProvider]) -> Bool {
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
            project.importVideoURLs(collector.urls, replacingExisting: false)
        }
        return true
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes)m \(seconds)s"
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

private struct MediaTagFilterMenuLabel: View {
    let tag: MediaTag
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            MediaTagDot(tag: tag, size: 8)
            Text(tag.label)
        }
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

private struct MediaTagDot: View {
    let tag: MediaTag
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(tag.fillColor)
            .overlay {
                Circle()
                    .stroke(tag.strokeColor, lineWidth: max(size * 0.08, 1))
            }
            .frame(width: size, height: size)
    }
}

private extension MediaTag {
    var menuIcon: NSImage {
        let size = NSSize(width: 12, height: 12)
        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(x: 1, y: 1, width: 10, height: 10)
        NSColor(fillColor).setFill()
        NSBezierPath(ovalIn: rect).fill()
        NSColor(strokeColor).setStroke()
        let path = NSBezierPath(ovalIn: rect)
        path.lineWidth = 1
        path.stroke()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    var fillColor: Color {
        switch self {
        case .red:
            Color(red: 1.0, green: 0.36, blue: 0.35)
        case .orange:
            Color(red: 1.0, green: 0.58, blue: 0.26)
        case .yellow:
            Color(red: 1.0, green: 0.82, blue: 0.28)
        case .green:
            Color(red: 0.32, green: 0.78, blue: 0.42)
        case .blue:
            Color(red: 0.28, green: 0.62, blue: 1.0)
        case .purple:
            Color(red: 0.76, green: 0.32, blue: 0.92)
        case .gray:
            Color(red: 0.63, green: 0.64, blue: 0.67)
        }
    }

    var strokeColor: Color {
        switch self {
        case .red:
            Color(red: 1.0, green: 0.24, blue: 0.25)
        case .orange:
            Color(red: 1.0, green: 0.45, blue: 0.16)
        case .yellow:
            Color(red: 0.96, green: 0.68, blue: 0.02)
        case .green:
            Color(red: 0.20, green: 0.64, blue: 0.34)
        case .blue:
            Color(red: 0.12, green: 0.48, blue: 0.94)
        case .purple:
            Color(red: 0.63, green: 0.24, blue: 0.84)
        case .gray:
            Color(red: 0.48, green: 0.49, blue: 0.52)
        }
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
