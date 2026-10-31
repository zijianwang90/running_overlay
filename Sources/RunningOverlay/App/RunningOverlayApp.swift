import AppKit
import SwiftUI

struct RunningOverlayApp: App {
    @AppStorage(EditorLayoutDefaults.showsPoolPanelKey) private var showsPoolPanel = true
    @AppStorage(EditorLayoutDefaults.showsInspectorKey) private var showsInspector = true
    @NSApplicationDelegateAdaptor(RunningOverlayAppDelegate.self) private var appDelegate
    @StateObject private var project: ProjectDocument

    init() {
        let project = ProjectDocument()
        _project = StateObject(wrappedValue: project)
        RunningOverlayAppDelegate.project = project

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
                Button("New Project") {
                    project.newProject()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Open Project...") {
                    project.openProject()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Menu("Open Recent") {
                    ForEach(project.recentProjectPaths, id: \.self) { path in
                        Button(URL(fileURLWithPath: path).lastPathComponent) {
                            project.openRecentProject(path: path)
                        }
                    }
                    if !project.recentProjectPaths.isEmpty {
                        Divider()
                    }
                    Button("Clear Menu") {
                        project.clearRecentProjects()
                    }
                    .disabled(project.recentProjectPaths.isEmpty)
                }

                Divider()

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

            // Replacing the save group also removes the system Close item, so
            // Close is restated here.
            CommandGroup(replacing: .saveItem) {
                Button("Close") {
                    NSApp.keyWindow?.performClose(nil)
                }
                .keyboardShortcut("w", modifiers: [.command])

                Button("Save") {
                    project.saveProject()
                }
                .keyboardShortcut("s", modifiers: [.command])

                Button("Save As...") {
                    project.saveProjectAs()
                }
                .keyboardShortcut("S", modifiers: [.command, .shift])
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

/// Guards quitting (including closing the only editor window, which quits the
/// app) behind the unsaved-changes prompt, and opens project files from Finder.
@MainActor
final class RunningOverlayAppDelegate: NSObject, NSApplicationDelegate {
    static weak var project: ProjectDocument?
    /// Set by the editor window so a cancelled quit can bring it back.
    static var reopenMainWindow: (() -> Void)?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let project = Self.project, !project.confirmProjectCanBeReplaced() else {
            // No project, nothing unsaved, or the user saved / chose Don't Save.
            return .terminateNow
        }
        if !NSApp.windows.contains(where: \.isVisible) {
            DispatchQueue.main.async {
                Self.reopenMainWindow?()
            }
        }
        return .terminateCancel
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first(where: {
            $0.pathExtension.lowercased() == ProjectFileFormat.fileExtension
        }) else {
            return
        }
        Self.project?.openProjectFromSystem(url)
    }
}
