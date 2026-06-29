import SwiftUI

private enum ExportDialogLayout {
    static let trailingColumnWidth: CGFloat = 360
    static let bitrateValueWidth: CGFloat = 72
}

struct ExportDialogView: View {
    @EnvironmentObject private var project: ProjectDocument
    @Environment(\.dismiss) private var dismiss
    @State private var destination = "~/Movies"
    @State private var destinationURL: URL?
    @State private var suggestedDestinationURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies")
    @State private var didInitializeDestination = false
    @State private var isAdvancedExpanded = false
    @State private var activeHelpTooltip: ExportHelpTooltipState?

    private let outputHelpText = "1080p currently provides the best export time. 5 fps is usually the best-balanced layer data refresh rate for speed and visual quality. Higher data FPS and 4K export significantly increase render time with the current implementation."
    private let encodingHelpText = "Transparent overlay export requires alpha-capable codecs. HEVC keeps file size controlled but is significantly slower. ProRes exports much faster but creates much larger files."

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    destinationSection
                    outputSection
                    encodingSection
                    advancedSection
                }
                .padding(24)
            }

            footer
        }
        .frame(width: 680)
        .coordinateSpace(name: "exportDialog")
        .background(EditorTheme.panelBackground)
        .overlay(alignment: .topLeading) {
            if let activeHelpTooltip {
                let maxX = CGFloat(680 - 300)
                let clampedX = min(max(activeHelpTooltip.anchor.minX, 12), maxX)

                ExportHelpTooltip(text: activeHelpTooltip.text)
                    .frame(maxWidth: 300, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .offset(
                        x: clampedX,
                        y: activeHelpTooltip.anchor.maxY + 8
                    )
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.12), value: activeHelpTooltip?.text)
        .onAppear {
            initializeDestinationIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Export Overlays")
                .font(EditorTheme.panelTitleFont)
                .foregroundStyle(EditorTheme.textPrimary)

            Text("Transparent MOV overlay with alpha channel")
                .font(EditorTheme.bodyFont)
                .foregroundStyle(EditorTheme.textSecondary)
        }
        .padding(.bottom, 4)
    }

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Destination")
                .font(EditorTheme.sectionTitleFont)
                .foregroundStyle(EditorTheme.textMuted)

            HStack(spacing: 10) {
                Text(destination)
                    .font(EditorTheme.bodyFont)
                    .foregroundStyle(EditorTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: EditorTheme.controlHeight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(EditorTheme.surfaceControl)
                    .clipShape(RoundedRectangle(cornerRadius: EditorTheme.controlRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: EditorTheme.controlRadius)
                            .stroke(EditorTheme.borderSubtle, lineWidth: 1)
                    }
                    .lineLimit(1)
                    .truncationMode(.middle)

                Button {
                    chooseDestination()
                } label: {
                    Label("Choose...", systemImage: "folder")
                }
                .buttonStyle(EditorSecondaryButtonStyle())
                .help("Choose Destination")
                .disabled(project.isExporting)
            }
        }
    }

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ExportSectionHeader(
                title: "Output",
                helpText: outputHelpText,
                activeHelpTooltip: $activeHelpTooltip
            )

            SettingsGroupBox {
                ExportReadOnlyRow(label: "Format", value: "Transparent MOV")
                dividerRow
                ExportReadOnlyRow(label: "Resolution", value: project.settings.resolution.label)
                dividerRow
                ExportReadOnlyRow(label: "Frame Rate", value: project.settings.frameRate.label)
                dividerRow
                ExportReadOnlyRow(label: "Data FPS", value: project.settings.layerDataFrameRate.label)
            }
        }
    }

    private var encodingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ExportSectionHeader(
                title: "Encoding",
                helpText: encodingHelpText,
                activeHelpTooltip: $activeHelpTooltip
            )

            SettingsGroupBox {
                SettingsRow(leading: { rowLabel("Codec") }) {
                    Picker("", selection: $project.settings.exportCodec) {
                        ForEach(ProjectExportCodec.allCases) { codec in
                            Text(codec.label).tag(codec)
                        }
                    }
                    .labelsHidden()
                    .frame(width: ExportDialogLayout.trailingColumnWidth, alignment: .trailing)
                    .disabled(project.isExporting)
                }
                dividerRow
                SettingsRow(leading: { rowLabel("Bitrate") }) {
                    HStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { project.settings.bitrateMbps },
                                set: { project.settings.bitrateMbps = $0.rounded() }
                            ),
                            in: 5...100
                        )
                        .tint(EditorTheme.accentBlue)
                        .disabled(project.isExporting)

                        Text("\(Int(project.settings.bitrateMbps)) Mbps")
                            .font(EditorTheme.numericFont)
                            .foregroundStyle(EditorTheme.textPrimary)
                            .frame(width: ExportDialogLayout.bitrateValueWidth, alignment: .trailing)
                    }
                    .frame(width: ExportDialogLayout.trailingColumnWidth)
                }
            }
        }
    }

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isAdvancedExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isAdvancedExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 12)
                    Text("Advanced")
                        .font(EditorTheme.sectionTitleFont)
                    Spacer()
                }
                .foregroundStyle(EditorTheme.textMuted)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isAdvancedExpanded {
                SettingsGroupBox {
                    #if DEBUG
                    advancedGroup(title: "Diagnostics") {
                        Button("Export Test Frame") {
                            performExportAction { project.exportTestFrame(to: $0) }
                        }
                        .buttonStyle(EditorSecondaryButtonStyle())
                        .disabled(project.isExporting)

                        Button("Export Test Clip") {
                            performExportAction { project.exportTestClip(to: $0) }
                        }
                        .buttonStyle(EditorSecondaryButtonStyle())
                        .disabled(project.isExporting)

                        Button("Export Overlay JSON") {
                            performExportAction { project.exportCurrentOverlayConfigurationJSON(to: $0) }
                        }
                        .buttonStyle(EditorSecondaryButtonStyle())
                        .disabled(project.isExporting)
                    }

                    dividerRow

                    advancedGroup(title: "Project Snapshot") {
                        Button("Save Snapshot") {
                            project.saveProjectSnapshot()
                        }
                        .buttonStyle(EditorSecondaryButtonStyle())
                        .disabled(project.isExporting)

                        Button("Restore Snapshot") {
                            project.restoreProjectSnapshot()
                        }
                        .buttonStyle(EditorSecondaryButtonStyle())
                        .disabled(project.isExporting)
                    }

                    dividerRow
                    #endif

                    advancedGroup(title: "Full Activity") {
                        Button("Export Full Activity") {
                            performExportAction { project.exportFullActivityOverlay(to: $0) }
                        }
                        .buttonStyle(EditorSecondaryButtonStyle())
                        .disabled(project.isExporting)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text(project.isExporting ? "Exporting..." : "Ready to export")
                .font(EditorTheme.captionFont)
                .foregroundStyle(EditorTheme.textMuted)

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(EditorSecondaryButtonStyle())

            Button("Export") {
                performExportAction { project.exportOverlays(to: $0) }
            }
            .buttonStyle(EditorPrimaryButtonStyle())
            .keyboardShortcut(.defaultAction)
            .disabled(project.isExporting)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(EditorTheme.surfaceRaised)
        .overlay(alignment: .top) {
            Divider()
                .overlay(EditorTheme.borderSubtle)
        }
    }

    private func advancedGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(EditorTheme.captionFont)
                .foregroundStyle(EditorTheme.textMuted)
            HStack(spacing: 8) {
                content()
                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(EditorTheme.bodyFont)
            .foregroundStyle(EditorTheme.textPrimary)
    }

    private var dividerRow: some View {
        Divider()
            .overlay(EditorTheme.borderSubtle)
            .padding(.leading, 14)
    }

    @discardableResult
    private func chooseDestination() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = destinationURL ?? suggestedDestinationURL
        if panel.runModal() == .OK, let url = panel.url {
            destinationURL = url
            destination = displayPath(for: url)
            return url
        }
        return nil
    }

    private func performExportAction(_ action: (URL) -> Void) {
        guard let destinationURL = destinationURL ?? chooseDestination() else {
            return
        }
        action(destinationURL)
        dismiss()
    }

    private func initializeDestinationIfNeeded() {
        guard !didInitializeDestination else {
            return
        }

        let defaultURL = project.defaultExportDestinationURL
        suggestedDestinationURL = defaultURL
        destination = displayPath(for: defaultURL)
        didInitializeDestination = true
    }

    private func displayPath(for url: URL) -> String {
        (url.path as NSString).abbreviatingWithTildeInPath
    }
}

private struct ExportHelpTooltipState: Equatable {
    let text: String
    let anchor: CGRect
}

private struct ExportSectionHeader: View {
    let title: String
    let helpText: String
    @Binding var activeHelpTooltip: ExportHelpTooltipState?

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(EditorTheme.sectionTitleFont)
                .foregroundStyle(EditorTheme.textMuted)
            ExportHelpIcon(helpText: helpText, activeHelpTooltip: $activeHelpTooltip)
            Spacer()
        }
        .frame(height: 28)
    }
}

private struct ExportHelpIcon: View {
    let helpText: String
    @Binding var activeHelpTooltip: ExportHelpTooltipState?
    @State private var isHovering = false
    @State private var anchor = CGRect.zero

    var body: some View {
        Image(systemName: "exclamationmark.circle")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(isHovering ? EditorTheme.textSecondary : EditorTheme.textMuted)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
            .accessibilityLabel(Text("Export help"))
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    activeHelpTooltip = ExportHelpTooltipState(text: helpText, anchor: anchor)
                } else if activeHelpTooltip?.text == helpText {
                    activeHelpTooltip = nil
                }
            }
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            updateAnchor(proxy.frame(in: .named("exportDialog")))
                        }
                        .onChange(of: proxy.size) { _, _ in
                            updateAnchor(proxy.frame(in: .named("exportDialog")))
                        }
                }
            }
    }

    private func updateAnchor(_ frame: CGRect) {
        guard frame != .zero else { return }
        anchor = frame
        if isHovering {
            activeHelpTooltip = ExportHelpTooltipState(text: helpText, anchor: frame)
        }
    }
}

private struct ExportHelpTooltip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(EditorTheme.captionFont)
            .foregroundStyle(EditorTheme.textPrimary)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(EditorTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(EditorTheme.borderSubtle, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.28), radius: 10, y: 4)
    }
}

private struct ExportReadOnlyRow: View {
    let label: String
    let value: String

    var body: some View {
        SettingsRow(leading: {
            Text(label)
                .font(EditorTheme.bodyFont)
                .foregroundStyle(EditorTheme.textPrimary)
        }, trailing: {
            Text(value)
                .font(EditorTheme.numericFont)
                .foregroundStyle(EditorTheme.textPrimary)
                .frame(width: ExportDialogLayout.trailingColumnWidth, alignment: .trailing)
        })
    }
}
