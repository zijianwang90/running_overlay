import SwiftUI

struct ExportDialogView: View {
    @EnvironmentObject private var project: ProjectDocument
    @Environment(\.dismiss) private var dismiss
    @State private var destination = "~/Movies"
    @State private var destinationURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies")
    @State private var didInitializeDestination = false
    @State private var isAdvancedExpanded = false

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
        .background(EditorTheme.panelBackground)
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
                TextField("Destination", text: $destination)
                    .textFieldStyle(.plain)
                    .font(EditorTheme.bodyFont)
                    .foregroundStyle(EditorTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: EditorTheme.controlHeight)
                    .background(EditorTheme.surfaceControl)
                    .clipShape(RoundedRectangle(cornerRadius: EditorTheme.controlRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: EditorTheme.controlRadius)
                            .stroke(EditorTheme.borderSubtle, lineWidth: 1)
                    }
                    .disabled(project.isExporting)

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
            ExportSectionHeader(title: "Output", helpText: outputHelpText)

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
            ExportSectionHeader(title: "Encoding", helpText: encodingHelpText)

            SettingsGroupBox {
                SettingsRow(leading: { rowLabel("Codec") }) {
                    Picker("", selection: $project.settings.exportCodec) {
                        ForEach(ProjectExportCodec.allCases) { codec in
                            Text(codec.label).tag(codec)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)
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
                            .frame(width: 72, alignment: .trailing)
                    }
                    .frame(width: 360)
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
                    advancedGroup(title: "Diagnostics") {
                        Button("Export Test Frame") {
                            performExportAction { project.exportTestFrame(to: destinationURL) }
                        }
                        .buttonStyle(EditorSecondaryButtonStyle())
                        .disabled(project.isExporting)

                        Button("Export Test Clip") {
                            performExportAction { project.exportTestClip(to: destinationURL) }
                        }
                        .buttonStyle(EditorSecondaryButtonStyle())
                        .disabled(project.isExporting)

                        Button("Export Overlay JSON") {
                            performExportAction { project.exportCurrentOverlayConfigurationJSON(to: destinationURL) }
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

                    advancedGroup(title: "Full Activity") {
                        Button("Export Full Activity") {
                            performExportAction { project.exportFullActivityOverlay(to: destinationURL) }
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
                performExportAction { project.exportOverlays(to: destinationURL) }
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

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = destinationURL
        if panel.runModal() == .OK, let url = panel.url {
            destinationURL = url
            destination = displayPath(for: url)
        }
    }

    private func performExportAction(_ action: () -> Void) {
        destinationURL = URL(fileURLWithPath: (destination as NSString).expandingTildeInPath)
        action()
        dismiss()
    }

    private func initializeDestinationIfNeeded() {
        guard !didInitializeDestination else {
            return
        }

        let defaultURL = project.defaultExportDestinationURL
        destinationURL = defaultURL
        destination = displayPath(for: defaultURL)
        didInitializeDestination = true
    }

    private func displayPath(for url: URL) -> String {
        (url.path as NSString).abbreviatingWithTildeInPath
    }
}

private struct ExportSectionHeader: View {
    let title: String
    let helpText: String

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(EditorTheme.sectionTitleFont)
                .foregroundStyle(EditorTheme.textMuted)
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(EditorTheme.textMuted)
                .frame(width: 28, height: 28)
                .help(helpText)
                .accessibilityLabel(Text("\(title) export help"))
            Spacer()
        }
        .frame(height: 28)
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
        })
    }
}
