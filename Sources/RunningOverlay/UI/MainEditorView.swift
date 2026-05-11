import AppKit
import SwiftUI

struct MainEditorView: View {
    @EnvironmentObject private var project: ProjectDocument
    @State private var showingExportProgress = false
    @State private var activePool: PoolKind = .media
    @State private var mediaPoolWidth: CGFloat = 380
    @State private var inspectorWidth: CGFloat = 460

    private static let mediaPoolMinWidth: CGFloat = 300
    private static let mediaPoolMaxWidth: CGFloat = 720
    private static let inspectorMinWidth: CGFloat = 460
    private static let inspectorMaxWidth: CGFloat = 720
    private static let previewMinWidth: CGFloat = 520

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            VSplitView {
                HStack(spacing: 0) {
                    PoolPanelView(activePool: $activePool)
                        .frame(width: mediaPoolWidth)
                        .frame(maxHeight: .infinity)

                    HorizontalResizeHandle(
                        width: $mediaPoolWidth,
                        minWidth: Self.mediaPoolMinWidth,
                        maxWidth: Self.mediaPoolMaxWidth,
                        sign: 1
                    )

                    PreviewCanvasView()
                        .frame(minWidth: Self.previewMinWidth, minHeight: 320)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    HorizontalResizeHandle(
                        width: $inspectorWidth,
                        minWidth: Self.inspectorMinWidth,
                        maxWidth: Self.inspectorMaxWidth,
                        sign: -1
                    )

                    ParameterPanelView()
                        .frame(width: inspectorWidth)
                        .frame(maxHeight: .infinity)
                        .clipped()
                }
                .frame(minHeight: 360, idealHeight: 800)
                .splitResizeCursor(.resizeUpDown, edge: .bottom, thickness: 18)

                TimelineView()
                    .frame(minHeight: 120, idealHeight: 130)
                    .splitResizeCursor(.resizeUpDown, edge: .top, thickness: 18)
            }

            statusBar
        }
        .background(EditorTheme.appBackground)
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
        .onKeyPress(.leftArrow) {
            guard !isTextInputFocused else { return .ignored }
            project.stepPlayheadByFrames(-1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            guard !isTextInputFocused else { return .ignored }
            project.stepPlayheadByFrames(1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            guard !isTextInputFocused else { return .ignored }
            project.nudgeSelectedOverlay(dx: 0, dy: -0.01)
            return .handled
        }
        .onKeyPress(.downArrow) {
            guard !isTextInputFocused else { return .ignored }
            project.nudgeSelectedOverlay(dx: 0, dy: 0.01)
            return .handled
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
        .onReceive(Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()) { _ in
            if !project.isPreviewingMediaPoolItem, project.previewMediaAtPlayhead() == nil {
                project.advancePlayback(by: 1.0 / 30.0)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            PoolModeSwitch(activePool: $activePool)
                .frame(width: mediaPoolWidth - (EditorTheme.panelPaddingX * 2))

            Spacer()

            if let exportProgress = project.exportProgress {
                ExportProgressButton(progress: exportProgress, isPresented: $showingExportProgress)
            }

            Button {
                project.showingExportDialog = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(EditorPrimaryButtonStyle())
        }
        .padding(.horizontal, 14)
        .frame(height: EditorTheme.panelHeaderHeight)
        .background(EditorTheme.appChrome)
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(EditorTheme.borderSubtle)
        }
    }

    private var statusBar: some View {
        HStack {
            Text(project.statusMessage)
                .foregroundStyle(EditorTheme.textSecondary)
            Spacer()
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

private struct ExportProgressButton: View {
    let progress: ExportProgressState
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                ProgressView(value: progress.overallProgress)
                    .controlSize(.small)
                    .frame(width: 68)
                Text("\(Int((progress.overallProgress * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .frame(width: 34, alignment: .trailing)
            }
        }
        .buttonStyle(EditorSecondaryButtonStyle())
        .help("Export Progress")
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

            ProgressView(value: progress.overallProgress)

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
    private static let visualWidth: CGFloat = 1
    private static let hitWidth: CGFloat = 12

    @Binding var width: CGFloat
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
                                    startWidth = width
                                }
                                let proposed = (startWidth ?? width) + sign * value.translation.width
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
