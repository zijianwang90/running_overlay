import Foundation

/// `manifest.json` of an Export for Editor package (ADR 0013). It records the
/// render inputs and how each source clip maps onto the activity, so editor
/// carriers can place or re-render overlays without opening the project.
struct EditorPackageManifest: Codable, Equatable {
    static let currentSchemaVersion = 1
    static let fileName = "manifest.json"

    var schemaVersion: Int = EditorPackageManifest.currentSchemaVersion
    var generator: String = "Running Overlay Studio"
    var createdAt: Date
    var activity: Activity
    var template: OverlayTemplateManifest
    /// `directory` is `.`, the package folder.
    var output: OverlayRenderJobOutput
    var mode: EditorPackageMode
    var overlays: [Overlay]
    var clips: [Clip]

    struct Activity: Codable, Equatable {
        /// Real timestamp (UTC) of activity elapsed time 0.
        var startDate: Date
        var duration: TimeInterval
        var contentHash: String
    }

    /// One rendered alpha movie in the package.
    struct Overlay: Codable, Equatable {
        var fileName: String
        var cacheKey: String
        /// Activity elapsed seconds at the first frame of the movie.
        var activityElapsedStart: TimeInterval
        var duration: TimeInterval
    }

    /// One source clip of the project timeline and its overlay placement.
    struct Clip: Codable, Equatable {
        var mediaName: String
        /// Media source time of the clip's first frame. Project clips are
        /// untrimmed today, so this is 0.
        var mediaSourceStart: TimeInterval
        var duration: TimeInterval
        /// Activity elapsed seconds at the clip's first frame:
        /// `clip.effectiveStartTime - timeline.fitStartTime`. Negative when the
        /// clip starts before the activity.
        var activityElapsedStart: TimeInterval
        var overlayFileName: String
        /// Media time inside the overlay movie that lines up with the clip's
        /// first frame. 0 in per-clip mode; equals `activityElapsedStart` in
        /// full-activity mode.
        var overlaySourceStart: TimeInterval
    }
}

enum EditorPackageMode: String, Codable, CaseIterable, Identifiable {
    /// One overlay movie per source clip, each exactly as long as its clip.
    case perClip
    /// One overlay movie covering the whole activity; every clip references a
    /// range of it, so the overlay can be re-trimmed in the editor.
    case fullActivity

    var id: String { rawValue }
}
