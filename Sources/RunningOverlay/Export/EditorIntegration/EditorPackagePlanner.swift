import Foundation

/// One media-bearing timeline clip as the planner consumes it. Time values
/// are in project timeline time; the planner converts them to activity
/// elapsed time for the render spans (ADR 0013).
struct EditorPackageSourceClip: Equatable {
    var mediaName: String
    var mediaURL: URL?
    var effectiveStartTime: TimeInterval
    var duration: TimeInterval
    var trackIndex: Int
    var clipIndex: Int
}

/// Pure output of `EditorPackagePlanner`: what to render and how each source
/// clip maps onto the result.
struct EditorPackagePlan: Equatable {
    /// Render spans in activity elapsed seconds, in timeline order.
    var spans: [OverlayRenderSpan]
    /// Manifest clip entries in the same order as `sources`.
    var clips: [EditorPackageManifest.Clip]
    /// Media-bearing clips, sorted by project timeline start then track order.
    var sources: [EditorPackageSourceClip]
}

/// Maps project timeline clips onto editor package render spans (ADR 0013).
///
/// Time domains are explicit: clip starts arrive as project timeline time
/// (`effectiveStartTime`); spans are emitted in activity elapsed seconds.
enum EditorPackagePlanner {
    static let fullActivityOverlayName = "full_activity_overlay"
    static let overlayNameSuffix = "_overlay"

    static func plan(
        clips: [EditorPackageSourceClip],
        fitStartTime: TimeInterval,
        activityDuration: TimeInterval,
        mode: EditorPackageMode
    ) -> EditorPackagePlan {
        let sources = clips
            .enumerated()
            .filter { $0.element.mediaURL != nil && $0.element.duration > 0 }
            .sorted { lhs, rhs in
                let left = lhs.element
                let right = rhs.element
                if left.effectiveStartTime != right.effectiveStartTime {
                    return left.effectiveStartTime < right.effectiveStartTime
                }
                if left.trackIndex != right.trackIndex {
                    return left.trackIndex < right.trackIndex
                }
                if left.clipIndex != right.clipIndex {
                    return left.clipIndex < right.clipIndex
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)

        switch mode {
        case .perClip:
            var usedNames: Set<String> = []
            var spans: [OverlayRenderSpan] = []
            var manifestClips: [EditorPackageManifest.Clip] = []
            for source in sources {
                let name = EditorPackageNaming.uniqueOverlayName(
                    base: EditorPackageNaming.sanitizedBaseName(source.mediaName),
                    usedNames: &usedNames
                )
                let activityElapsedStart = source.effectiveStartTime - fitStartTime
                spans.append(OverlayRenderSpan(
                    name: name,
                    activityElapsedStart: activityElapsedStart,
                    duration: source.duration
                ))
                manifestClips.append(EditorPackageManifest.Clip(
                    mediaName: source.mediaName,
                    mediaSourceStart: 0,
                    duration: source.duration,
                    activityElapsedStart: activityElapsedStart,
                    overlayFileName: "\(name).mov",
                    overlaySourceStart: 0
                ))
            }
            return EditorPackagePlan(spans: spans, clips: manifestClips, sources: sources)

        case .fullActivity:
            let span = OverlayRenderSpan(
                name: fullActivityOverlayName,
                activityElapsedStart: 0,
                duration: activityDuration
            )
            let manifestClips = sources.map { source in
                EditorPackageManifest.Clip(
                    mediaName: source.mediaName,
                    mediaSourceStart: 0,
                    duration: source.duration,
                    activityElapsedStart: source.effectiveStartTime - fitStartTime,
                    overlayFileName: "\(fullActivityOverlayName).mov",
                    overlaySourceStart: source.effectiveStartTime - fitStartTime
                )
            }
            return EditorPackagePlan(spans: [span], clips: manifestClips, sources: sources)
        }
    }
}

/// File-name rules shared by the planner and the package writer.
enum EditorPackageNaming {
    /// Strips the extension and replaces path separators, dots, and other
    /// non-file-safe characters with single underscores.
    static func sanitizedBaseName(_ displayName: String) -> String {
        let withoutExtension = (displayName as NSString).deletingPathExtension
        var scalars: [Unicode.Scalar] = []
        var lastWasSeparator = false
        for scalar in withoutExtension.unicodeScalars {
            let isAllowed = CharacterSet.alphanumerics.contains(scalar)
                || scalar.value == 95 // "_"
                || scalar.value == 45 // "-"
            if isAllowed {
                scalars.append(scalar)
                lastWasSeparator = false
            } else if !lastWasSeparator {
                scalars.append(Unicode.Scalar(95))
                lastWasSeparator = true
            }
        }
        let trimmed = String(String.UnicodeScalarView(scalars))
            .trimmingCharacters(in: CharacterSet(charactersIn: "_-"))
        return trimmed.isEmpty ? "clip" : trimmed
    }

    /// Editor-facing document name: keeps spaces and case, removes only path
    /// separators and colons so the name is still a valid file name.
    static func safeDocumentBaseName(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Project" : cleaned
    }

    /// `base` plus `_overlay`, with `_2`, `_3`, … inserted before the suffix
    /// when a name (compared case-insensitively) was already used.
    static func uniqueOverlayName(base: String, usedNames: inout Set<String>) -> String {
        var candidate = "\(base)\(EditorPackagePlanner.overlayNameSuffix)"
        var index = 2
        while usedNames.contains(candidate.lowercased()) {
            candidate = "\(base)_\(index)\(EditorPackagePlanner.overlayNameSuffix)"
            index += 1
        }
        usedNames.insert(candidate.lowercased())
        return candidate
    }
}
