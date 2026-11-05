import AppKit
import Foundation

/// The editing application an editor package is prepared for. The choice only
/// changes the guidance the app shows, plus which file it can open for the
/// user; the package contents are identical.
enum EditorTarget: String, Codable, CaseIterable, Identifiable {
    case finalCutPro
    case resolve
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .finalCutPro:
            "Final Cut Pro"
        case .resolve:
            "DaVinci Resolve"
        case .other:
            "Other editor"
        }
    }

    /// Bundle identifiers this editor may ship under. Final Cut Pro Creator
    /// Studio uses `com.apple.FinalCutApp`; builds differ between editions.
    var applicationBundleIdentifiers: [String] {
        switch self {
        case .finalCutPro:
            ["com.apple.FinalCutApp", "com.apple.FinalCut"]
        case .resolve:
            ["com.blackmagic-design.DaVinciResolve", "com.blackmagic-design.DaVinciResolveStudio"]
        case .other:
            []
        }
    }

    /// The installed application, when this target names one that is present.
    var applicationURL: URL? {
        for identifier in applicationBundleIdentifiers {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
                return url
            }
        }
        return nil
    }

    var isInstalled: Bool {
        applicationURL != nil
    }
}

/// Content of the completion guidance shown after an editor package export and
/// reopened from the Help menu (ADR 0013). Step text is generated from the same
/// values the package was written with, so it always names real files.
struct EditorImportGuide: Identifiable, Equatable {
    struct Step: Identifiable, Equatable {
        var id: Int
        var title: String
        var detail: String
    }

    var id = UUID()
    var editor: EditorTarget
    var projectName: String
    /// Nil when the guide is opened from the Help menu with no fresh export.
    var packageURL: URL?
    var fcpxmlFileName: String?
    var overlayFileNames: [String]
    var frameRateID: String
    var mode: EditorPackageMode
    var codec: ProjectExportCodec

    init(
        editor: EditorTarget,
        projectName: String,
        packageURL: URL?,
        fcpxmlFileName: String?,
        overlayFileNames: [String],
        frameRateID: String,
        mode: EditorPackageMode,
        codec: ProjectExportCodec
    ) {
        self.editor = editor
        self.projectName = projectName
        self.packageURL = packageURL
        self.fcpxmlFileName = fcpxmlFileName
        self.overlayFileNames = overlayFileNames
        self.frameRateID = frameRateID
        self.mode = mode
        self.codec = codec
    }

    var headline: String {
        switch (editor, packageURL != nil) {
        case (.finalCutPro, true):
            "Overlay package ready for Final Cut Pro"
        case (.resolve, true):
            "Overlay package ready for DaVinci Resolve"
        case (.other, true):
            "Overlay package ready"
        case (.finalCutPro, false):
            "Import overlays into Final Cut Pro"
        case (.resolve, false):
            "Import overlays into DaVinci Resolve"
        case (.other, false):
            "Import overlays into your editor"
        }
    }

    var subtitle: String {
        switch packageURL {
        case .some(let url):
            "\(url.lastPathComponent) · \(frameRateID) fps"
        case .none:
            "Export for Editor writes an alpha movie, manifest, and timeline file."
        }
    }

    var steps: [Step] {
        switch editor {
        case .finalCutPro:
            finalCutProSteps
        case .resolve:
            resolveSteps
        case .other:
            otherEditorSteps
        }
    }

    var notes: [String] {
        var notes: [String] = []
        switch codec {
        case .hevcWithAlpha:
            notes.append("This package uses HEVC with alpha. If text looks soft, re-export with ProRes 4444.")
        case .proRes4444:
            notes.append("ProRes 4444 keeps text crisp and is the safer choice for color grading; files are larger.")
        }

        switch mode {
        case .perClip:
            notes.append("Each overlay movie is exactly as long as its clip, so trimming a clip also trims its overlay.")
        case .fullActivity:
            notes.append("Every clip reads a range of the full-activity movie, so you can slip the overlay manually in the editor.")
        }

        if editor == .other {
            notes.append("Overlays are transparent MOVs; no keying is required.")
        }
        if editor == .resolve {
            notes.append("Resolve does not open FCPXML from Finder. Open DaVinci Resolve copies the timeline path; then use File > Import > Timeline.")
        }
        return notes
    }

    /// File names written inside the package, in reading order.
    var packageFileNames: [String] {
        guard packageURL != nil else { return [] }
        var names: [String] = []
        if let fcpxmlFileName {
            names.append(fcpxmlFileName)
        }
        names.append(contentsOf: overlayFileNames.map { "\($0).mov" })
        names.append(EditorPackageManifest.fileName)
        names.append(EditorImportGuideText.fileName)
        return names
    }

    /// True when the sheet can launch the target app for this package.
    var canOpenInEditor: Bool {
        editor.applicationURL != nil && editor != .other && packageURL != nil && fcpxmlFileName != nil
    }

    /// Final Cut Pro opens `.fcpxml` from Finder. DaVinci Resolve does not
    /// register the type, so the sheet launches it and copies the path for
    /// File > Import > Timeline instead.
    var opensTimelineFileDirectly: Bool {
        editor == .finalCutPro
    }

    var openButtonTitle: String {
        opensTimelineFileDirectly ? "Open in \(editor.displayName)" : "Open \(editor.displayName)"
    }

    /// Text of `How to Import.txt`, written into the package so guidance
    /// survives copying the folder to another machine.
    func importInstructionsText() -> String {
        var lines: [String] = []
        lines.append("Running Overlay Studio — Editor Package")
        lines.append("")
        lines.append("Project: \(projectName)")
        lines.append("Prepared for: \(editor.displayName)")
        lines.append("Overlays: \(mode == .perClip ? "one per clip" : "one full-activity movie")")
        lines.append("Frame rate: \(frameRateID) fps")
        lines.append("Codec: \(codec.label)")
        lines.append("")

        if !packageFileNames.isEmpty {
            lines.append("Files")
            for name in packageFileNames {
                lines.append("- \(name)")
            }
            lines.append("")
        }

        lines.append(editor.displayName)
        for (index, step) in steps.enumerated() {
            lines.append("\(index + 1). \(step.title)")
            lines.append("   \(step.detail)")
        }

        if !notes.isEmpty {
            lines.append("")
            lines.append("Notes")
            for note in notes {
                lines.append("- \(note)")
            }
        }

        lines.append("")
        lines.append("Generated by Running Overlay Studio.")
        return lines.joined(separator: "\n") + "\n"
    }

    private var timelineReference: String {
        if let fcpxmlFileName {
            return "the package's \(fcpxmlFileName)"
        }
        return "the .fcpxml file in the package"
    }

    private var overlayReference: String {
        overlayFileNames.first.map { "\($0).mov" } ?? "an overlay .mov"
    }

    private var finalCutProSteps: [Step] {
        [
            Step(
                id: 0,
                title: "Open the timeline",
                detail: packageURL == nil
                    ? "Double-click \(timelineReference), or choose File > Import > XML in Final Cut Pro."
                    : "Click Open in Final Cut Pro below, or double-click \(timelineReference)."
            ),
            Step(
                id: 1,
                title: "Choose a library",
                detail: "The project appears in a new event. If Final Cut Pro asks, pick or create a library."
            ),
            Step(
                id: 2,
                title: "Edit on lane 1",
                detail: "Each source clip has its overlay stacked directly above it on lane 1. The movie is already transparent, so no keying is needed."
            )
        ]
    }

    private var resolveSteps: [Step] {
        [
            Step(
                id: 0,
                title: "Match the timeline frame rate",
                detail: "In DaVinci Resolve, open Project Settings > Master Settings and set the Timeline frame rate to \(frameRateID) fps. Resolve cannot change it after media is imported."
            ),
            Step(
                id: 1,
                title: "Import the timeline",
                detail: "Choose File > Import > Timeline… and select \(timelineReference). Keep \"Automatically import source clips into Media Pool\" selected."
            ),
            Step(
                id: 2,
                title: "Check the overlay track",
                detail: "Overlays land on the track above their clip (V2). Alpha is preserved; if the canvas looks milky, make sure the overlay track sits above the video."
            )
        ]
    }

    private var otherEditorSteps: [Step] {
        [
            Step(
                id: 0,
                title: "Place the overlay above your footage",
                detail: "Drag \(overlayReference) onto a track directly above the source clip."
            ),
            Step(
                id: 1,
                title: "Align the first frame",
                detail: mode == .perClip
                    ? "Line up the overlay's first frame with the clip's first frame. The manifest records the activity offset of every clip."
                    : "The overlay covers the whole activity. Start it at the clip's activity offset recorded in \(EditorPackageManifest.fileName)."
            ),
            Step(
                id: 2,
                title: "Trim to the clip",
                detail: "Trim the overlay to the clip length. The movie is transparent, so it can sit above the footage without blending."
            )
        ]
    }
}

enum EditorImportGuideText {
    static let fileName = "How to Import.txt"
}

/// Export for Editor choices remembered between exports. They affect guidance
/// and overlay layout, never the project document.
struct EditorPackageExportOptions: Codable, Equatable {
    /// Whether the Export dialog also writes an editor package. Off by
    /// default so the familiar overlay export is unchanged.
    var enabled: Bool = false
    var target: EditorTarget = .finalCutPro
    var mode: EditorPackageMode = .perClip

    private enum CodingKeys: String, CodingKey {
        case enabled, target, mode
    }

    init(enabled: Bool = false, target: EditorTarget = .finalCutPro, mode: EditorPackageMode = .perClip) {
        self.enabled = enabled
        self.target = target
        self.mode = mode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        target = try container.decodeIfPresent(EditorTarget.self, forKey: .target) ?? .finalCutPro
        mode = try container.decodeIfPresent(EditorPackageMode.self, forKey: .mode) ?? .perClip
    }
}
