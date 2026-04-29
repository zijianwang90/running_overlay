import SwiftUI

struct ProjectSettingsView: View {
    @EnvironmentObject private var project: ProjectDocument
    @Environment(\.dismiss) private var dismiss

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
}
