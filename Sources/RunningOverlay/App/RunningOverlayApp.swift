import AppKit
import SwiftUI

@main
struct RunningOverlayApp: App {
    @StateObject private var project = ProjectDocument()

    init() {
        BundledFonts.registerAll()
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: false)
        }
    }

    var body: some Scene {
        WindowGroup {
            MainEditorView()
                .environmentObject(project)
                .preferredColorScheme(.dark)
                .frame(minWidth: 1180, minHeight: 760)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    project.undo()
                }
                .keyboardShortcut("z", modifiers: [.command])
                .disabled(!project.canUndo)

                Button("Redo") {
                    project.redo()
                }
                .keyboardShortcut("Z", modifiers: [.command, .shift])
                .disabled(!project.canRedo)
            }

            CommandGroup(after: .newItem) {
                Button("Import FIT File...") {
                    project.importFitFile()
                }
                .keyboardShortcut("i", modifiers: [.command])

                Button("Import Videos...") {
                    project.importVideos()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }

            CommandMenu("Playback") {
                Button(project.isPlaying ? "Pause" : "Play") {
                    project.togglePlayback()
                }
                .keyboardShortcut(.space, modifiers: [])

                Button(project.isPlaying ? "Pause (K)" : "Play (K)") {
                    project.togglePlayback()
                }
                .keyboardShortcut("k", modifiers: [])

                Button("Play Faster (L)") {
                    project.increaseForwardPlaybackRate()
                }
                .keyboardShortcut("l", modifiers: [])
            }

            CommandMenu("Timeline") {
                Button("Zoom In") {
                    project.zoomTimelineIn()
                }
                .keyboardShortcut("+", modifiers: [.command])

                Button("Zoom Out") {
                    project.zoomTimelineOut()
                }
                .keyboardShortcut("-", modifiers: [.command])
            }
        }
    }
}
