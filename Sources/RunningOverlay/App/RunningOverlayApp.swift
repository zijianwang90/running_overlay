import AppKit
import SwiftUI

struct RunningOverlayApp: App {
    @AppStorage(EditorLayoutDefaults.showsPoolPanelKey) private var showsPoolPanel = true
    @AppStorage(EditorLayoutDefaults.showsInspectorKey) private var showsInspector = true
    @StateObject private var project: ProjectDocument

    init() {
        let project = ProjectDocument()
        _project = StateObject(wrappedValue: project)

        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)

        if let launchCommand = RunningOverlayLaunchConfiguration.command {
            if let activityURL = launchCommand.activityURL {
                project.importActivityURL(activityURL)
            }
            if !launchCommand.videoURLs.isEmpty {
                project.importVideoURLs(launchCommand.videoURLs)
            }
        }

        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: false)
        }
    }

    var body: some Scene {
        Window("Running Overlay Studio", id: "main") {
            MainEditorView()
                .environmentObject(project)
                .preferredColorScheme(.dark)
                .frame(minHeight: 760)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
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

            CommandGroup(replacing: .newItem) {
                Button("Import Activity File...") {
                    project.importActivityFile()
                }
                .keyboardShortcut("i", modifiers: [.command])

                Button("Import Videos...") {
                    project.importVideos()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }

            CommandGroup(after: .sidebar) {
                Button(showsPoolPanel ? "Hide Pools" : "Show Pools") {
                    showsPoolPanel.toggle()
                }
                .keyboardShortcut("s", modifiers: [.control, .command])

                Button(showsInspector ? "Hide Inspector" : "Show Inspector") {
                    showsInspector.toggle()
                }
                .keyboardShortcut("i", modifiers: [.option, .command])
            }

            CommandGroup(after: .pasteboard) {
                Button("Duplicate Overlay") {
                    project.duplicateSelectedOverlay()
                }
                .keyboardShortcut("d", modifiers: [.command])
                .disabled(project.selectedOverlayID == nil)
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

                Button("Play Slower (J)") {
                    project.decreaseForwardPlaybackRate()
                }
                .keyboardShortcut("j", modifiers: [])
                .disabled(!project.isPlaying)

                Divider()

                // Navigation keys are handled by the editor so they keep their
                // meaning in lists and text fields; titles show the key.
                Button("Go to Start (Home)") {
                    project.movePlayheadToStart()
                }

                Button("Go to End (End)") {
                    project.movePlayheadToEnd()
                }

                Button("Previous Edit Point (Up Arrow)") {
                    project.jumpToEditPoint(forward: false)
                }

                Button("Next Edit Point (Down Arrow)") {
                    project.jumpToEditPoint(forward: true)
                }
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

                Button("Toggle Fit Zoom") {
                    project.toggleTimelineFitZoom()
                }
                .keyboardShortcut("z", modifiers: [.shift])
            }
        }
    }
}
