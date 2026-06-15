import SwiftUI

struct TemplatePoolView: View {
    @EnvironmentObject private var project: ProjectDocument
    @State private var pendingBuiltInApply: BuiltInOverlayTemplate?
    @State private var pendingUserApply: OverlayTemplate?
    @State private var pendingDelete: OverlayTemplate?
    @State private var renamingTemplate: OverlayTemplate?
    @State private var renameText = ""

    var body: some View {
        VStack(spacing: 0) {
            EditorPanelHeader(title: "Templates") {
                Text("Apply layouts")
                    .font(EditorTheme.captionFont)
                    .foregroundStyle(EditorTheme.textMuted)
                    .lineLimit(1)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    templateSection(title: "Built-in Templates") {
                        VStack(spacing: 0) {
                            ForEach(BuiltInOverlayTemplate.all) { template in
                                TemplatePoolRow(title: template.name) {
                                    applyBuiltInTemplate(template)
                                }
                            }
                        }
                    }

                    templateSection(title: "User Templates") {
                        if project.overlayTemplates.isEmpty {
                            TemplateEmptyRow()
                                .contextMenu {
                                    Button {
                                        project.importOverlayTemplateFile()
                                    } label: {
                                        Label("Import Template...", systemImage: "tray.and.arrow.down")
                                    }
                                }
                        } else {
                            VStack(spacing: 0) {
                                ForEach(project.overlayTemplates) { template in
                                    TemplatePoolRow(title: template.name) {
                                        applyUserTemplate(template)
                                    }
                                    .contextMenu {
                                        Button {
                                            beginRename(template)
                                        } label: {
                                            Label("Rename", systemImage: "pencil")
                                        }
                                        Button {
                                            project.duplicateOverlayTemplate(template.id)
                                        } label: {
                                            Label("Duplicate", systemImage: "doc.on.doc")
                                        }
                                        Button {
                                            project.exportOverlayTemplateFile(template.id)
                                        } label: {
                                            Label("Export...", systemImage: "square.and.arrow.up")
                                        }
                                        Divider()
                                        Button(role: .destructive) {
                                            pendingDelete = template
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Spacer(minLength: EditorTheme.space6)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            footer
        }
        .background(EditorTheme.panelBackground)
        .confirmationDialog(
            "Replace current overlays with \(pendingBuiltInApply?.name ?? "this template")?",
            isPresented: Binding(
                get: { pendingBuiltInApply != nil },
                set: { if !$0 { pendingBuiltInApply = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pendingBuiltInApply {
                Button("Replace Overlays", role: .destructive) {
                    project.applyBuiltInOverlayTemplate(pendingBuiltInApply)
                    self.pendingBuiltInApply = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingBuiltInApply = nil
            }
        } message: {
            Text("This will clear the current overlay layout and apply the selected template.")
        }
        .confirmationDialog(
            "Replace current overlays with \(pendingUserApply?.name ?? "this template")?",
            isPresented: Binding(
                get: { pendingUserApply != nil },
                set: { if !$0 { pendingUserApply = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pendingUserApply {
                Button("Replace Overlays", role: .destructive) {
                    project.applyOverlayTemplate(pendingUserApply.id)
                    self.pendingUserApply = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingUserApply = nil
            }
        } message: {
            Text("This will clear the current overlay layout and apply the selected template.")
        }
        .confirmationDialog(
            "Delete \(pendingDelete?.name ?? "this template")?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pendingDelete {
                Button("Delete Template", role: .destructive) {
                    project.deleteOverlayTemplate(pendingDelete.id)
                    self.pendingDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text("This removes the saved template from your local template library.")
        }
        .sheet(item: $renamingTemplate) { template in
            TemplateRenameSheet(
                templateName: $renameText,
                onCancel: {
                    renamingTemplate = nil
                },
                onSave: {
                    project.renameOverlayTemplate(template.id, to: renameText)
                    renamingTemplate = nil
                }
            )
        }
    }

    private func templateSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(EditorTheme.sectionTitleFont)
                    .foregroundStyle(EditorTheme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, EditorTheme.panelPaddingX)
            .frame(height: 40)
            .background(EditorTheme.panelHeader)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(EditorTheme.borderSubtle)
                    .frame(height: 1)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack(spacing: EditorTheme.space2) {
            Button {
                project.importOverlayTemplateFile()
            } label: {
                Image(systemName: "tray.and.arrow.down")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(TemplateImportButtonStyle())
            .help("Import Template")
            .accessibilityLabel("Import Template")

            Button {
                project.saveCurrentOverlayTemplateWithGeneratedName()
            } label: {
                Label("Save Current as Template", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(EditorPrimaryButtonStyle())
            .disabled(project.overlayLayout.elements.isEmpty)
            .help(project.overlayLayout.elements.isEmpty ? "Add overlays before saving a template" : "Save Current as Template")
        }
        .padding(.horizontal, EditorTheme.panelPaddingX)
        .padding(.vertical, EditorTheme.space3)
        .background(EditorTheme.panelHeader)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(EditorTheme.borderSubtle)
                .frame(height: 1)
        }
    }

    private func beginRename(_ template: OverlayTemplate) {
        renameText = template.name
        renamingTemplate = template
    }

    private func applyBuiltInTemplate(_ template: BuiltInOverlayTemplate) {
        guard !project.overlayLayout.elements.isEmpty else {
            project.applyBuiltInOverlayTemplate(template)
            return
        }

        pendingBuiltInApply = template
    }

    private func applyUserTemplate(_ template: OverlayTemplate) {
        guard !project.overlayLayout.elements.isEmpty else {
            project.applyOverlayTemplate(template.id)
            return
        }

        pendingUserApply = template
    }
}

private struct TemplatePoolRow: View {
    var title: String
    var action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(EditorTheme.bodyFont)
                    .foregroundStyle(EditorTheme.textPrimary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, EditorTheme.panelPaddingX)
            .frame(height: 30)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(isHovering ? EditorTheme.surfaceHover : Color.clear)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(EditorTheme.borderSubtle.opacity(0.72))
                    .frame(height: 1)
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

private struct TemplateEmptyRow: View {
    var body: some View {
        HStack {
            Text("No saved templates yet")
                .font(EditorTheme.bodyFont)
                .foregroundStyle(EditorTheme.textMuted)
            Spacer()
        }
        .padding(.horizontal, EditorTheme.panelPaddingX)
        .frame(height: 30)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(EditorTheme.borderSubtle.opacity(0.72))
                .frame(height: 1)
        }
    }
}

private struct TemplateRenameSheet: View {
    @Binding var templateName: String
    var onCancel: () -> Void
    var onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: EditorTheme.space4) {
            Text("Rename Template")
                .font(EditorTheme.sectionTitleFont)
                .foregroundStyle(EditorTheme.textPrimary)

            TextField("Template name", text: $templateName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Rename", action: onSave)
                    .buttonStyle(EditorPrimaryButtonStyle())
                    .disabled(templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(EditorTheme.space5)
        .frame(width: 340)
        .background(EditorTheme.panelBackground)
    }
}

private struct TemplateImportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(EditorTheme.textSecondary)
            .background(configuration.isPressed ? EditorTheme.surfacePressed : EditorTheme.surfaceControl)
            .clipShape(RoundedRectangle(cornerRadius: EditorTheme.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: EditorTheme.controlRadius)
                    .stroke(EditorTheme.borderSubtle, lineWidth: 1)
            }
    }
}
