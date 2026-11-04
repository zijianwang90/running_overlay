import SwiftUI

/// Options shown before writing an Export for Editor package. The target only
/// selects the guidance shown afterwards; the package contents are the same.
struct EditorExportSheet: View {
    @EnvironmentObject private var project: ProjectDocument
    @Environment(\.dismiss) private var dismiss

    @State private var target: EditorTarget = .finalCutPro
    @State private var mode: EditorPackageMode = .perClip
    @State private var didLoadSavedOptions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    editorSection
                    overlaySection
                    encodingSection
                }
                .padding(24)
            }

            footer
        }
        .frame(width: 560)
        .background(EditorTheme.panelBackground)
        .onAppear(perform: loadSavedOptions)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Export for Editor")
                .font(EditorTheme.panelTitleFont)
                .foregroundStyle(EditorTheme.textPrimary)

            Text("Transparent overlays, a manifest, and a ready-to-import timeline")
                .font(EditorTheme.bodyFont)
                .foregroundStyle(EditorTheme.textSecondary)
        }
        .padding(.bottom, 4)
    }

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Editor")

            SettingsGroupBox {
                SettingsRow(leading: { rowText("Prepare for") }) {
                    Picker("", selection: $target) {
                        ForEach(EditorTarget.allCases) { editor in
                            Text(editor.displayName).tag(editor)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 300, alignment: .trailing)
                }

                if target == .finalCutPro && !EditorTarget.finalCutPro.isInstalled {
                    dividerRow
                    hintRow("Final Cut Pro was not found on this Mac. The package still imports there.")
                } else if target == .resolve && !EditorTarget.resolve.isInstalled {
                    dividerRow
                    hintRow("DaVinci Resolve was not found on this Mac. The package still imports there.")
                }
            }
        }
    }

    private var overlaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Overlays")

            SettingsGroupBox {
                SettingsRow(leading: { rowText("Layout") }) {
                    Picker("", selection: $mode) {
                        Text("One per clip").tag(EditorPackageMode.perClip)
                        Text("Full activity").tag(EditorPackageMode.fullActivity)
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    .frame(width: 300, alignment: .trailing)
                }
                dividerRow
                hintRow(mode == .perClip
                    ? "Each clip gets an overlay movie of its own length. Nothing to align by hand."
                    : "One movie for the whole activity; every clip reads its range from it.")
                dividerRow
                hintRow("Timeline frame rate: \(project.settings.frameRate.label). Keep the editing timeline at the same rate.")
            }
        }
    }

    private var encodingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Encoding")

            SettingsGroupBox {
                SettingsRow(leading: { rowText("Codec") }) {
                    Picker("", selection: $project.settings.exportCodec) {
                        ForEach(ProjectExportCodec.allCases) { codec in
                            Text(codec.label).tag(codec)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 300, alignment: .trailing)
                }
                dividerRow
                hintRow(project.settings.exportCodec == .proRes4444
                    ? "ProRes 4444 keeps text crisp. Files are larger."
                    : "HEVC with alpha keeps files small. Use ProRes 4444 if text looks soft.")
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("\(project.settings.resolution.width) × \(project.settings.resolution.height) · \(project.settings.frameRate.id) fps")
                .font(EditorTheme.captionFont)
                .foregroundStyle(EditorTheme.textMuted)

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(EditorSecondaryButtonStyle())

            Button("Choose Destination…") {
                saveOptions()
                dismiss()
                project.chooseEditorPackageDestination(options: EditorPackageExportOptions(target: target, mode: mode))
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

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(EditorTheme.sectionTitleFont)
            .foregroundStyle(EditorTheme.textMuted)
    }

    private func rowText(_ text: String) -> some View {
        Text(text)
            .font(EditorTheme.bodyFont)
            .foregroundStyle(EditorTheme.textPrimary)
    }

    private func hintRow(_ text: String) -> some View {
        Text(text)
            .font(EditorTheme.captionFont)
            .foregroundStyle(EditorTheme.textMuted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dividerRow: some View {
        Divider()
            .overlay(EditorTheme.borderSubtle)
            .padding(.leading, 14)
    }

    private func loadSavedOptions() {
        guard !didLoadSavedOptions else { return }
        didLoadSavedOptions = true
        let saved = project.savedEditorPackageOptions
        target = saved.target
        mode = saved.mode
    }

    private func saveOptions() {
        project.savedEditorPackageOptions = EditorPackageExportOptions(target: target, mode: mode)
    }
}
