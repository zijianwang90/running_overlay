import AppKit
import SwiftUI

@main
struct RunningOverlayApp: App {
    @StateObject private var project = ProjectDocument()
    private let benchmarkCommand: ExportBenchmarkCommand?

    init() {
        let parsedBenchmarkCommand: ExportBenchmarkCommand?
        do {
            parsedBenchmarkCommand = try ExportBenchmarkCommand.parse()
        } catch {
            fputs("[RunningOverlayBenchmark] \(error.localizedDescription)\n", stderr)
            Foundation.exit(2)
        }
        benchmarkCommand = parsedBenchmarkCommand

        NSApplication.shared.setActivationPolicy(benchmarkCommand == nil ? .regular : .prohibited)
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        if let benchmarkCommand {
            DispatchQueue.main.async {
                Task {
                    do {
                        _ = try await ExportBenchmarkRunner.run(benchmarkCommand)
                        NSApplication.shared.terminate(nil)
                    } catch {
                        fputs("[RunningOverlayBenchmark] failed: \(error.localizedDescription)\n", stderr)
                        Foundation.exit(1)
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                NSApplication.shared.activate(ignoringOtherApps: false)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if benchmarkCommand == nil {
                MainEditorView()
                    .environmentObject(project)
                    .preferredColorScheme(.dark)
                    .frame(minWidth: 1300, minHeight: 760)
            } else {
                EmptyView()
            }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    project.undo()
                }
                .keyboardShortcut("z", modifiers: [.command])
                .disabled(benchmarkCommand != nil || !project.canUndo)

                Button("Redo") {
                    project.redo()
                }
                .keyboardShortcut("Z", modifiers: [.command, .shift])
                .disabled(benchmarkCommand != nil || !project.canRedo)
            }

            CommandGroup(after: .newItem) {
                Button("Import FIT File...") {
                    project.importFitFile()
                }
                .keyboardShortcut("i", modifiers: [.command])
                .disabled(benchmarkCommand != nil)

                Button("Import Videos...") {
                    project.importVideos()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                .disabled(benchmarkCommand != nil)
            }

            CommandMenu("Playback") {
                Button(project.isPlaying ? "Pause" : "Play") {
                    project.togglePlayback()
                }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(benchmarkCommand != nil)

                Button(project.isPlaying ? "Pause (K)" : "Play (K)") {
                    project.togglePlayback()
                }
                .keyboardShortcut("k", modifiers: [])
                .disabled(benchmarkCommand != nil)

                Button("Play Faster (L)") {
                    project.increaseForwardPlaybackRate()
                }
                .keyboardShortcut("l", modifiers: [])
                .disabled(benchmarkCommand != nil)
            }

            CommandMenu("Timeline") {
                Button("Zoom In") {
                    project.zoomTimelineIn()
                }
                .keyboardShortcut("+", modifiers: [.command])
                .disabled(benchmarkCommand != nil)

                Button("Zoom Out") {
                    project.zoomTimelineOut()
                }
                .keyboardShortcut("-", modifiers: [.command])
                .disabled(benchmarkCommand != nil)

                Button("Toggle Fit Zoom") {
                    project.toggleTimelineFitZoom()
                }
                .keyboardShortcut("z", modifiers: [.shift])
                .disabled(benchmarkCommand != nil)
            }
        }
    }
}
