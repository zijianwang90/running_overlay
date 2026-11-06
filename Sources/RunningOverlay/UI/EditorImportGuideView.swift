import AppKit
import SwiftUI

/// Shown after an Export for Editor export, and from the Help menu. Gives the
/// steps for the chosen editor and can open or reveal the package.
struct EditorImportGuideView: View {
    let guide: EditorImportGuide
    /// Security-scoped bookmark for the package, when it came from an export.
    var packageBookmark: Data?

    @Environment(\.dismiss) private var dismiss
    @State private var openFailure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if !guide.packageFileNames.isEmpty {
                        fileSection
                    }
                    stepsSection
                    if !guide.notes.isEmpty {
                        notesSection
                    }
                    if let openFailure {
                        Text(openFailure)
                            .font(EditorTheme.captionFont)
                            .foregroundStyle(EditorTheme.warningYellow)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(24)
            }

            footer
        }
        .frame(width: 620)
        .background(EditorTheme.panelBackground)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(EditorTheme.accentBlue)
                Text(guide.headline)
                    .font(EditorTheme.panelTitleFont)
                    .foregroundStyle(EditorTheme.textPrimary)
            }

            Text(guide.subtitle)
                .font(EditorTheme.bodyFont)
                .foregroundStyle(EditorTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.bottom, 4)
    }

    private var fileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("In the package")
                .font(EditorTheme.sectionTitleFont)
                .foregroundStyle(EditorTheme.textMuted)

            SettingsGroupBox {
                ForEach(Array(guide.packageFileNames.enumerated()), id: \.offset) { index, name in
                    if index > 0 {
                        Divider()
                            .overlay(EditorTheme.borderSubtle)
                            .padding(.leading, 14)
                    }
                    Text(name)
                        .font(EditorTheme.captionFont)
                        .foregroundStyle(EditorTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How to import")
                .font(EditorTheme.sectionTitleFont)
                .foregroundStyle(EditorTheme.textMuted)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(guide.steps) { step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(step.id + 1)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(EditorTheme.textPrimary)
                            .frame(width: 20, height: 20)
                            .background(EditorTheme.surfaceControl)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(EditorTheme.textPrimary)
                            Text(step.detail)
                                .font(EditorTheme.bodyFont)
                                .foregroundStyle(EditorTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EditorTheme.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: EditorTheme.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: EditorTheme.controlRadius)
                    .stroke(EditorTheme.borderSubtle, lineWidth: 1)
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(guide.notes.enumerated()), id: \.offset) { _, note in
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                        .font(EditorTheme.captionFont)
                        .foregroundStyle(EditorTheme.textMuted)
                    Text(note)
                        .font(EditorTheme.captionFont)
                        .foregroundStyle(EditorTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if let packageURL = guide.packageURL {
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([packageURL])
                }
                .buttonStyle(EditorSecondaryButtonStyle())

                Button("Copy Timeline Path") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(
                        packageURL.appendingPathComponent(guide.fcpxmlFileName ?? "").path,
                        forType: .string
                    )
                }
                .buttonStyle(EditorSecondaryButtonStyle())
            }

            Spacer()

            if guide.canOpenInEditor {
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(EditorSecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)

                Button(guide.openButtonTitle) {
                    openInEditor()
                }
                .buttonStyle(EditorPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(EditorPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(EditorTheme.surfaceRaised)
        .overlay(alignment: .top) {
            Divider()
                .overlay(EditorTheme.borderSubtle)
        }
    }

    /// Resolves the export folder through its security-scoped bookmark so the
    /// sandboxed app can read the timeline even after the export finished.
    private func resolvedPackageURL(_ original: URL) -> URL {
        guard let packageBookmark else { return original }
        var isStale = false
        return (try? URL(
            resolvingBookmarkData: packageBookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )) ?? original
    }

    private func openInEditor() {
        openFailure = nil
        guard let guidePackageURL = guide.packageURL,
              let fcpxmlFileName = guide.fcpxmlFileName,
              let applicationURL = guide.editor.applicationURL else {
            return
        }

        let packageURL = resolvedPackageURL(guidePackageURL)

        let timelineURL = packageURL.appendingPathComponent(fcpxmlFileName)
        // The package folder was chosen through NSOpenPanel; re-assert its
        // sandbox extension for the open call.
        let didStart = packageURL.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                packageURL.stopAccessingSecurityScopedResource()
            }
        }

        guard FileManager.default.fileExists(atPath: timelineURL.path) else {
            openFailure = "The timeline file is no longer in the package. Choose Show in Finder to look for it."
            return
        }

        let editorName = guide.editor.displayName
        let configuration = NSWorkspace.OpenConfiguration()

        guard guide.opensTimelineFileDirectly else {
            // Resolve does not accept .fcpxml from Finder. Launch it and put
            // the timeline path on the clipboard for File > Import > Timeline.
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(timelineURL.path, forType: .string)
            NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) { _, error in
                guard let error else { return }
                Task { @MainActor in
                    openFailure = "Could not open \(editorName): \(error.localizedDescription)"
                }
            }
            return
        }

        NSWorkspace.shared.open([timelineURL], withApplicationAt: applicationURL, configuration: configuration) { _, error in
            guard let error else { return }
            Task { @MainActor in
                openFailure = "Could not open \(editorName): \(error.localizedDescription)"
            }
        }
    }
}
