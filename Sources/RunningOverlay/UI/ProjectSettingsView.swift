import SwiftUI

struct ProjectSettingsView: View {
    @EnvironmentObject private var project: ProjectDocument
    @Environment(\.dismiss) private var dismiss
    @State private var templateName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Project Settings")
                .font(EditorTheme.panelTitleFont)
                .foregroundStyle(EditorTheme.textPrimary)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Resolution", selection: $project.settings.resolution) {
                        ForEach(ProjectResolution.presets) { resolution in
                            Text(resolution.label).tag(resolution)
                        }
                    }

                    Picker("Frame Rate", selection: $project.settings.frameRate) {
                        ForEach(ProjectFrameRate.presets) { frameRate in
                            Text(frameRate.label).tag(frameRate)
                        }
                    }

                    Picker("Layer Data FPS", selection: $project.settings.layerDataFrameRate) {
                        ForEach(ProjectLayerDataFrameRate.presets) { frameRate in
                            Text(frameRate.label).tag(frameRate)
                        }
                    }

                    HStack {
                        Text("Bitrate")
                        Slider(
                            value: Binding(
                                get: { project.settings.bitrateMbps },
                                set: { project.settings.bitrateMbps = $0.rounded() }
                            ),
                            in: 5...100
                        )
                        Text("\(Int(project.settings.bitrateMbps)) Mbps")
                            .frame(width: 72, alignment: .trailing)
                    }

                    Divider()

                    overlayTemplatesSection
                }
            }

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(EditorPrimaryButtonStyle())
            }
        }
        .padding(24)
        .frame(width: 520, height: 620)
        .background(EditorTheme.panelBackground)
    }

    private var overlayTemplatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Overlay Templates")
                .font(EditorTheme.sectionTitleFont)
                .foregroundStyle(EditorTheme.textPrimary)

            HStack(spacing: 8) {
                TextField("Template name", text: $templateName)
                    .textFieldStyle(.roundedBorder)

                Button {
                    project.saveOverlayTemplate(named: templateName)
                    if !templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        templateName = ""
                    }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("Save Current Overlay As Template")
                .disabled(project.overlayLayout.elements.isEmpty)
            }

            Button {
                project.importOverlayTemplateFile()
            } label: {
                Label("Import Template", systemImage: "square.and.arrow.down.on.square")
            }

            if project.overlayTemplates.isEmpty {
                Text("No saved templates")
                    .font(EditorTheme.captionFont)
                    .foregroundStyle(EditorTheme.textMuted)
            } else {
                VStack(spacing: 6) {
                    ForEach(project.overlayTemplates) { template in
                        HStack(spacing: 8) {
                            Button {
                                project.applyOverlayTemplate(template.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(template.name)
                                            .lineLimit(1)
                                            .foregroundStyle(EditorTheme.textPrimary)
                                        Text("\(template.elements.count) elements")
                                            .font(EditorTheme.captionFont)
                                            .foregroundStyle(EditorTheme.textMuted)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button {
                                project.exportOverlayTemplateFile(template.id)
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .buttonStyle(EditorIconButtonStyle())
                            .help("Export Template")

                            Button {
                                project.deleteOverlayTemplate(template.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(EditorIconButtonStyle(role: .destructive))
                            .help("Delete Template")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .background(EditorTheme.surfaceControl)
                        .clipShape(RoundedRectangle(cornerRadius: EditorTheme.controlRadius))
                        .overlay {
                            RoundedRectangle(cornerRadius: EditorTheme.controlRadius)
                                .stroke(EditorTheme.borderSubtle, lineWidth: 1)
                        }
                    }
                }
            }
        }
    }
}
