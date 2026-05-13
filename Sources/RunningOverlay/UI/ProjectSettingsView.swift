import SwiftUI

struct ProjectSettingsView: View {
    @EnvironmentObject private var project: ProjectDocument
    @Environment(\.dismiss) private var dismiss
    @State private var showingFontLibrary = false
    @State private var showingHeartRateZones = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Project Settings")
                .font(EditorTheme.panelTitleFont)
                .foregroundStyle(EditorTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // MARK: - Video
                    SettingsSectionHeader(title: "Video")
                    SettingsGroupBox {
                        videoSection
                    }

                    // MARK: - Encoding
                    SettingsSectionHeader(title: "Encoding")
                    SettingsGroupBox {
                        bitrateSection
                    }

                    // MARK: - Typography
                    SettingsSectionHeader(title: "Typography")
                    SettingsGroupBox {
                        typographySection
                    }

                    // MARK: - Physiology
                    SettingsSectionHeader(title: "Physiology")
                    SettingsGroupBox {
                        heartRateZonesSection
                    }
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
        .sheet(isPresented: $showingFontLibrary) {
            FontLibraryView()
        }
        .sheet(isPresented: $showingHeartRateZones) {
            HeartRateZonesView()
        }
    }

    // MARK: - Physiology

    private var heartRateZonesSection: some View {
        SettingsRow(
            leading: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Heart Rate Zones")
                        .font(EditorTheme.bodyStrongFont)
                        .foregroundStyle(EditorTheme.textPrimary)
                    Text("Configure HR and pace ranges for overlays.")
                        .font(EditorTheme.captionFont)
                        .foregroundStyle(EditorTheme.textSecondary)
                }
            },
            trailing: {
                Button("Configure…") {
                    showingHeartRateZones = true
                }
                .buttonStyle(EditorSecondaryButtonStyle())
            }
        )
    }

    // MARK: - Video

    private var videoSection: some View {
        VStack(spacing: 0) {
            SettingsRow(leading: { dropdownLabel("Resolution") }) {
                Picker("", selection: $project.settings.resolution) {
                    ForEach(ProjectResolution.presets) { r in Text(r.label).tag(r) }
                }
                .labelsHidden()
                .frame(width: 160)
            }
            dividerRow
            SettingsRow(leading: { dropdownLabel("Frame Rate") }) {
                Picker("", selection: $project.settings.frameRate) {
                    ForEach(ProjectFrameRate.presets) { f in Text(f.label).tag(f) }
                }
                .labelsHidden()
                .frame(width: 160)
            }
            dividerRow
            SettingsRow(leading: { dropdownLabel("Layer Data FPS") }) {
                Picker("", selection: $project.settings.layerDataFrameRate) {
                    ForEach(ProjectLayerDataFrameRate.presets) { f in Text(f.label).tag(f) }
                }
                .labelsHidden()
                .frame(width: 160)
            }
        }
    }

    // MARK: - Encoding

    private var bitrateSection: some View {
        SettingsRow(
            leading: { dropdownLabel("Bitrate") },
            trailing: {
                HStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { project.settings.bitrateMbps },
                            set: { project.settings.bitrateMbps = $0.rounded() }
                        ),
                        in: 5...100
                    )
                    .tint(EditorTheme.accentBlue)
                    Text("\(Int(project.settings.bitrateMbps)) Mbps")
                        .font(EditorTheme.numericFont)
                        .foregroundStyle(EditorTheme.textPrimary)
                        .frame(width: 64, alignment: .trailing)
                }
            }
        )
    }

    // MARK: - Typography

    private var typographySection: some View {
        SettingsRow(
            leading: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Font Library")
                        .font(EditorTheme.bodyStrongFont)
                        .foregroundStyle(EditorTheme.textPrimary)
                    Text("Choose fonts shown in overlay menus.")
                        .font(EditorTheme.captionFont)
                        .foregroundStyle(EditorTheme.textSecondary)
                }
            },
            trailing: {
                Button("Manage…") {
                    showingFontLibrary = true
                }
                .buttonStyle(EditorSecondaryButtonStyle())
            }
        )
    }

    // MARK: - Helpers

    private func dropdownLabel(_ text: String) -> some View {
        Text(text)
            .font(EditorTheme.bodyFont)
            .foregroundStyle(EditorTheme.textPrimary)
    }

    private var dividerRow: some View {
        Divider()
            .overlay(EditorTheme.borderSubtle)
            .padding(.leading, 14)
    }
}
