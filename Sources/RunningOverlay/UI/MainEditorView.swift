import AppKit
import QuartzCore
import SwiftUI

struct MainEditorView: View {
    @EnvironmentObject private var project: ProjectDocument
    @Environment(\.openWindow) private var openWindow
    @State private var showingExportProgress = false
    @State private var activePool: PoolKind = .media
    @State private var mediaPoolWidth: CGFloat = 380
    @State private var inspectorWidth: CGFloat = 460
    @State private var lastPlaybackTickTime: CFTimeInterval?

    private static let timelineMinHeight: CGFloat = 96
    private static let timelineIdealHeight: CGFloat = 110

    var body: some View {
        GeometryReader { geometry in
            let layout = EditorPaneLayout(
                availableWidth: geometry.size.width,
                preferredMediaWidth: mediaPoolWidth,
                preferredInspectorWidth: inspectorWidth
            )
            VStack(spacing: 0) {
                VSplitView {
                    HStack(spacing: 0) {
                        PoolPanelView(activePool: $activePool)
                            .frame(width: layout.mediaWidth)
                            .frame(maxHeight: .infinity)

                        HorizontalResizeHandle(
                            width: $mediaPoolWidth,
                            displayedWidth: layout.mediaWidth,
                            minWidth: EditorPaneLayout.mediaMinWidth,
                            maxWidth: layout.mediaMaxWidth,
                            sign: 1
                        )

                        PreviewCanvasView()
                            .frame(minWidth: EditorPaneLayout.previewMinWidth, minHeight: 320)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        HorizontalResizeHandle(
                            width: $inspectorWidth,
                            displayedWidth: layout.inspectorWidth,
                            minWidth: EditorPaneLayout.inspectorMinWidth,
                            maxWidth: layout.inspectorMaxWidth,
                            sign: -1
                        )

                        ParameterPanelView()
                            .frame(width: layout.inspectorWidth)
                            .frame(maxHeight: .infinity)
                            .clipped()
                    }
                    .frame(minHeight: 360, idealHeight: 800)
                    .splitResizeCursor(.resizeUpDown, edge: .bottom, thickness: 18)

                    TimelineView()
                        .frame(minHeight: Self.timelineMinHeight, idealHeight: Self.timelineIdealHeight)
                        .splitResizeCursor(.resizeUpDown, edge: .top, thickness: 18)
                }

                statusBar
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    PoolModeSwitch(activePool: $activePool, compactLabels: true)
                        .frame(width: layout.mediaWidth - (EditorTheme.panelPaddingX * 2))
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    if let exportProgress = project.exportProgress {
                        ExportProgressButton(progress: exportProgress, isPresented: $showingExportProgress)
                    }

                    Button {
                        project.showingExportDialog = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export")
                        }
                    }
                    .buttonStyle(EditorPrimaryButtonStyle())
                    .help("Export overlays")
                }
            }
        }
        .background(EditorTheme.appBackground)
        .background(WindowDocumentEditedState(isEdited: project.hasUnsavedChanges))
        .navigationTitle(project.projectDisplayName)
        .onAppear {
            RunningOverlayAppDelegate.reopenMainWindow = { openWindow(id: "main") }
            project.offerAutosaveRecoveryIfNeeded()
        }
        .toolbarBackground(EditorTheme.appChrome, for: .windowToolbar)
        .overlay(alignment: .top) {
            if let toastMessage = project.toastMessage {
                EditorToastView(message: toastMessage)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.18), value: project.toastMessage)
        .sheet(isPresented: $project.showingProjectSettings) {
            ProjectSettingsView()
                .environmentObject(project)
        }
        .sheet(isPresented: $project.showingExportDialog) {
            ExportDialogView()
                .environmentObject(project)
        }
        .onKeyPress(.space) {
            guard !isTextInputFocused else { return .ignored }
            project.togglePlayback()
            return .handled
        }
        .onKeyPress("k") {
            guard !isTextInputFocused else { return .ignored }
            project.togglePlayback()
            return .handled
        }
        .onKeyPress("l") {
            guard !isTextInputFocused else { return .ignored }
            project.increaseForwardPlaybackRate()
            return .handled
        }
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in
            guard !isTextInputFocused else { return .ignored }
            let direction: EditorArrowKey
            switch press.key {
            case .leftArrow: direction = .left
            case .rightArrow: direction = .right
            case .upArrow: direction = .up
            default: direction = .down
            }
            let handled = project.handleArrowKey(direction, largeStep: press.modifiers.contains(.shift))
            return handled ? .handled : .ignored
        }
        .onKeyPress(.delete) {
            guard !isTextInputFocused else { return .ignored }
            project.deleteSelectedItem()
            return .handled
        }
        .onKeyPress(.deleteForward) {
            guard !isTextInputFocused else { return .ignored }
            project.deleteSelectedItem()
            return .handled
        }
        .onReceive(Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()) { _ in
            let shouldDrive = project.isPlaying
                && !project.isPreviewingMediaPoolItem
                && project.previewMediaAtPlayhead() == nil
            guard shouldDrive else {
                lastPlaybackTickTime = nil
                return
            }
            let now = CACurrentMediaTime()
            defer { lastPlaybackTickTime = now }
            guard let last = lastPlaybackTickTime else { return }
            // Cap delta so a long stall doesn't fling the playhead forward.
            let delta = min(max(now - last, 0), 0.25)
            project.advancePlayback(by: delta)
        }
    }

    private var statusBar: some View {
        HStack {
            Text(project.statusMessage)
                .foregroundStyle(EditorTheme.textSecondary)
            Spacer()
            Text(project.hasUnsavedChanges ? "\(project.projectDisplayName) — Edited" : project.projectDisplayName)
                .foregroundStyle(EditorTheme.textMuted)
                .lineLimit(1)
                .help(project.projectFileURL?.path ?? "Not saved yet")
            Button {
                project.showingProjectSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(EditorTheme.textSecondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Project Settings")
        }
        .font(EditorTheme.captionFont)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(EditorTheme.appChrome)
        .overlay(alignment: .top) {
            Divider()
                .overlay(EditorTheme.borderSubtle)
        }
    }

    private var isTextInputFocused: Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        if let textView = responder as? NSTextView, textView.isEditable {
            return true
        }
        return responder is NSTextField
    }
}

/// Mirrors unsaved changes onto the window's close-button dot.
private struct WindowDocumentEditedState: NSViewRepresentable {
    var isEdited: Bool

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let isEdited = isEdited
        DispatchQueue.main.async {
            nsView.window?.isDocumentEdited = isEdited
        }
    }
}

private struct EditorToastView: View {
    var message: String

    var body: some View {
        Text(message)
            .font(EditorTheme.bodyFont.weight(.semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 560)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.82))
            )
            .shadow(color: .black.opacity(0.24), radius: 12, y: 6)
    }
}

private struct ExportProgressButton: View {
    let progress: ExportProgressState
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            if progress.isCompleted {
                Label("Export Complete", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(EditorTheme.successGreen)
            } else {
                HStack(spacing: 6) {
                    ProgressView(value: progress.overallProgress)
                        .controlSize(.small)
                        .frame(width: 68)
                    Text("\(Int((progress.overallProgress * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                        .frame(width: 34, alignment: .trailing)
                }
            }
        }
        .buttonStyle(EditorSecondaryButtonStyle())
        .help(progress.isCompleted ? "Export Complete" : "Export Progress")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ExportProgressPopover(progress: progress)
        }
    }
}

private struct ExportProgressPopover: View {
    @EnvironmentObject private var project: ProjectDocument
    let progress: ExportProgressState

    private static let queueHeight: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(progress.title)
                    .font(EditorTheme.sectionTitleFont)
                    .foregroundStyle(EditorTheme.textPrimary)
                Spacer()
                Text("\(progress.completedCount)/\(progress.items.count)")
                    .font(EditorTheme.numericFont)
                    .foregroundStyle(EditorTheme.textSecondary)
            }

            if project.isExporting {
                Button {
                    project.cancelExport()
                } label: {
                    Label("Cancel Export", systemImage: "xmark.circle")
                }
            }

            if progress.isCompleted {
                Label("Export complete", systemImage: "checkmark.circle.fill")
                    .font(EditorTheme.bodyStrongFont)
                    .foregroundStyle(EditorTheme.successGreen)
            } else {
                ProgressView(value: progress.overallProgress)
            }

            if let failureMessage = progress.failureMessage {
                Text(failureMessage)
                    .font(.caption)
                    .foregroundStyle(EditorTheme.dangerRed)
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(progress.items) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.name)
                                    .lineLimit(1)
                                Spacer()
                                Text(item.status.rawValue)
                                    .foregroundStyle(statusColor(item.status))
                                Text("\(Int((item.progress * 100).rounded()))%")
                                    .monospacedDigit()
                                    .frame(width: 42, alignment: .trailing)
                            }
                            .font(.caption)
                            ProgressView(value: item.progress)
                        }
                    }
                }
                .padding(.trailing, 6)
            }
            .frame(height: Self.queueHeight)
        }
        .padding(14)
        .frame(width: 360)
        .background(EditorTheme.surfaceRaised)
    }

    private func statusColor(_ status: ExportProgressItemStatus) -> Color {
        switch status {
        case .queued:
            EditorTheme.textMuted
        case .exporting:
            EditorTheme.accentBlue
        case .completed:
            EditorTheme.successGreen
        case .failed:
            EditorTheme.dangerRed
        case .cancelled:
            EditorTheme.warningYellow
        }
    }
}

private struct HorizontalResizeHandle: View {
    private static let visualWidth: CGFloat = EditorPaneLayout.dividerWidth
    private static let hitWidth: CGFloat = 12

    @Binding var width: CGFloat
    let displayedWidth: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let sign: CGFloat

    @State private var startWidth: CGFloat?

    var body: some View {
        EditorTheme.borderSubtle
            .frame(width: Self.visualWidth)
            .overlay {
                Color.clear
                    .frame(width: Self.hitWidth)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        if hovering {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if startWidth == nil {
                                    startWidth = displayedWidth
                                }
                                let proposed = (startWidth ?? displayedWidth) + sign * value.translation.width
                                width = min(max(proposed, minWidth), maxWidth)
                            }
                            .onEnded { _ in
                                startWidth = nil
                            }
                    )
            }
        .frame(maxHeight: .infinity)
    }
}

/// Resolves user-preferred pane widths against the actual window content width.
/// Preferences stay intact when the window shrinks, so widening restores them.
struct EditorPaneLayout {
    static let mediaMinWidth: CGFloat = 300
    static let inspectorMinWidth: CGFloat = 460
    static let previewMinWidth: CGFloat = 520
    static let paneMaxWidth: CGFloat = 720
    static let dividerWidth: CGFloat = 1
    static let minimumWindowWidth: CGFloat = 1300

    let mediaWidth: CGFloat
    let inspectorWidth: CGFloat
    let mediaMaxWidth: CGFloat
    let inspectorMaxWidth: CGFloat

    init(availableWidth: CGFloat, preferredMediaWidth: CGFloat, preferredInspectorWidth: CGFloat) {
        let sideBudget = availableWidth - Self.previewMinWidth - 2 * Self.dividerWidth
        inspectorWidth = min(
            max(preferredInspectorWidth, Self.inspectorMinWidth),
            min(Self.paneMaxWidth, max(Self.inspectorMinWidth, sideBudget - Self.mediaMinWidth))
        )
        mediaWidth = min(
            max(preferredMediaWidth, Self.mediaMinWidth),
            min(Self.paneMaxWidth, max(Self.mediaMinWidth, sideBudget - inspectorWidth))
        )
        mediaMaxWidth = min(Self.paneMaxWidth, max(Self.mediaMinWidth, sideBudget - inspectorWidth))
        inspectorMaxWidth = min(Self.paneMaxWidth, max(Self.inspectorMinWidth, sideBudget - mediaWidth))
    }
}
