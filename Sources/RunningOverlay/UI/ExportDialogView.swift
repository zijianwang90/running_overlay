import SwiftUI

struct ExportDialogView: View {
    @EnvironmentObject private var project: ProjectDocument
    @Environment(\.dismiss) private var dismiss
    @State private var destination = "~/Movies"
    @State private var destinationURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies")
    @State private var didInitializeDestination = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Export Overlays")
                .font(EditorTheme.panelTitleFont)
                .foregroundStyle(EditorTheme.textPrimary)

            Text("Transparent MOV overlay export")
                .font(EditorTheme.bodyFont)
                .foregroundStyle(EditorTheme.textSecondary)

            LabeledContent("Destination") {
                HStack {
                    TextField("Destination", text: $destination)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        chooseDestination()
                    } label: {
                        Image(systemName: "folder")
                    }
                    .help("Choose Destination")
                }
            }

            LabeledContent("Resolution") {
                Text(project.settings.resolution.label)
            }

            LabeledContent("Frame Rate") {
                Text(project.settings.frameRate.label)
            }

            LabeledContent("Layer Data FPS") {
                Text(project.settings.layerDataFrameRate.label)
            }

            LabeledContent("Codec") {
                Picker("Codec", selection: $project.settings.exportCodec) {
                    ForEach(ProjectExportCodec.allCases) { codec in
                        Text(codec.label).tag(codec)
                    }
                }
                .labelsHidden()
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

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Export Test Clip") {
                    destinationURL = URL(fileURLWithPath: (destination as NSString).expandingTildeInPath)
                    project.exportTestClip(to: destinationURL)
                    dismiss()
                }
                .disabled(project.isExporting)
                Button("Export Test Frame") {
                    destinationURL = URL(fileURLWithPath: (destination as NSString).expandingTildeInPath)
                    project.exportTestFrame(to: destinationURL)
                    dismiss()
                }
                .disabled(project.isExporting)
                Button("Export") {
                    destinationURL = URL(fileURLWithPath: (destination as NSString).expandingTildeInPath)
                    project.exportOverlays(to: destinationURL)
                    dismiss()
                }
                .buttonStyle(EditorPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(project.isExporting)

                Button("Export Full Activity") {
                    destinationURL = URL(fileURLWithPath: (destination as NSString).expandingTildeInPath)
                    project.exportFullActivityOverlay(to: destinationURL)
                    dismiss()
                }
                .disabled(project.isExporting)
            }
        }
        .padding(24)
        .frame(width: 620)
        .background(EditorTheme.panelBackground)
        .onAppear {
            initializeDestinationIfNeeded()
        }
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
