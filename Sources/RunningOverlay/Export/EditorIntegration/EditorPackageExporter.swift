import AVFoundation
import Foundation

/// Everything the app-side package exporter needs from the open project.
struct EditorPackageExportRequest {
    var activity: ActivityTimeline
    var settings: ProjectSettings
    var timeline: TimelineModel
    var mediaItems: [MediaItem]
    var overlayLayout: OverlayLayout
    /// Template name recorded in the manifest.
    var templateName: String
    var projectName: String
    var mode: EditorPackageMode
    /// Editor the package is prepared for. Changes guidance only.
    var target: EditorTarget = .other
    /// Keep the project timeline's empty stretches as gaps. The full-activity
    /// layout always preserves them so its single overlay stays aligned.
    var keepsTimelinePositions: Bool = false
}

/// What an editor package export produced, including the guidance to show.
struct EditorPackageExportResult {
    var packageURL: URL
    var guide: EditorImportGuide
}

enum EditorPackageExportError: LocalizedError, Equatable {
    case noActivity
    case noMediaClips

    var errorDescription: String? {
        switch self {
        case .noActivity:
            "Import a FIT or GPX file before exporting an editor package."
        case .noMediaClips:
            "Add at least one video clip with a media file before exporting an editor package."
        }
    }
}

/// Writes a Layer 1 Export for Editor package (ADR 0013): alpha movies,
/// `manifest.json`, and an FCPXML timeline.
@MainActor
enum EditorPackageExporter {
    static func plannedSpans(for request: EditorPackageExportRequest) -> [OverlayRenderSpan] {
        makePlan(for: request).spans
    }

    /// Creates the unique `<ProjectName> Editor Package` folder inside
    /// `directoryURL` and returns it.
    static func packageDirectory(in directoryURL: URL, projectName: String) -> URL {
        let base = packageBaseName(projectName)
        var candidate = directoryURL.appendingPathComponent(base, isDirectory: true)
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directoryURL.appendingPathComponent("\(base) \(index)", isDirectory: true)
            index += 1
        }
        return candidate
    }

    @discardableResult
    static func export(
        request: EditorPackageExportRequest,
        to directoryURL: URL,
        progress: @escaping @MainActor (OverlayExportProgress) -> Void = { _ in }
    ) async throws -> EditorPackageExportResult {
        guard request.activity.duration > 0 else {
            throw EditorPackageExportError.noActivity
        }

        let plan = makePlan(for: request)
        if request.mode == .perClip && plan.spans.isEmpty {
            throw EditorPackageExportError.noMediaClips
        }

        let packageURL = packageDirectory(in: directoryURL, projectName: request.projectName)
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)

        let output = OverlayRenderJobOutput(directory: ".", settings: request.settings)
        let template = OverlayTemplate(
            name: request.templateName,
            layout: request.overlayLayout,
            referenceResolution: OverlayTemplateResolution(
                width: request.settings.resolution.width,
                height: request.settings.resolution.height
            )
        )
        let input = try OverlayRenderInput(activity: request.activity, template: template)

        let renderedSpans = try await OverlayRenderService.render(
            input: input,
            output: output,
            outputDirectory: packageURL,
            spans: plan.spans,
            cache: .defaultCache(),
            progress: progress
        )

        let overlays = renderedSpans.map { rendered in
            EditorPackageManifest.Overlay(
                fileName: "\(rendered.span.name).mov",
                cacheKey: rendered.cacheKey,
                activityElapsedStart: rendered.span.activityElapsedStart,
                duration: rendered.span.duration
            )
        }
        let manifest = EditorPackageManifest(
            createdAt: Date(),
            activity: EditorPackageManifest.Activity(
                startDate: request.activity.startDate,
                duration: request.activity.duration,
                contentHash: input.activityHash
            ),
            template: try OverlayTemplateManifest(template: template),
            output: output,
            mode: request.mode,
            overlays: overlays,
            clips: plan.clips
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(
            to: packageURL.appendingPathComponent(EditorPackageManifest.fileName),
            options: .atomic
        )

        let preservesTimelinePositions = request.keepsTimelinePositions
            || request.mode == .fullActivity

        var mediaInfo: [URL: EditorPackageSourceMediaInfo] = [:]
        var probedURLs: Set<URL> = []
        for source in plan.sources {
            guard let url = source.mediaURL, probedURLs.insert(url).inserted else { continue }
            if let info = await EditorPackageMediaProbe.info(for: url) {
                mediaInfo[url] = info
            }
        }

        let timelineClips: [EditorPackageTimelineClip] = zip(plan.sources, plan.clips).compactMap { source, clip in
            guard let url = source.mediaURL else { return nil }
            return EditorPackageTimelineClip(
                mediaName: clip.mediaName,
                mediaURL: url,
                duration: clip.duration,
                overlayFileName: clip.overlayFileName,
                overlaySourceStart: clip.overlaySourceStart,
                startTime: source.effectiveStartTime,
                trackIndex: source.trackIndex
            )
        }
        let timelineOverlays = overlays.map { overlay in
            EditorPackageTimelineOverlay(
                fileName: overlay.fileName,
                fileURL: packageURL.appendingPathComponent(overlay.fileName),
                duration: overlay.duration
            )
        }

        let writer = FCPXMLTimelineWriter(
            projectName: request.projectName,
            frameRate: request.settings.frameRate,
            canvasWidth: request.settings.resolution.width,
            canvasHeight: request.settings.resolution.height,
            overlays: timelineOverlays,
            clips: timelineClips,
            mediaInfo: mediaInfo,
            preservesTimelinePositions: preservesTimelinePositions
        )
        let fcpxmlName = "\(EditorPackageNaming.safeDocumentBaseName(request.projectName)).fcpxml"
        try writer.xmlString().write(
            to: packageURL.appendingPathComponent(fcpxmlName),
            atomically: true,
            encoding: .utf8
        )

        let guide = EditorImportGuide(
            editor: request.target,
            projectName: request.projectName,
            packageURL: packageURL,
            fcpxmlFileName: fcpxmlName,
            overlayFileNames: overlays.map { ($0.fileName as NSString).deletingPathExtension },
            frameRateID: request.settings.frameRate.id,
            mode: request.mode,
            codec: request.settings.exportCodec,
            keepsTimelinePositions: preservesTimelinePositions
        )
        try guide.importInstructionsText().write(
            to: packageURL.appendingPathComponent(EditorImportGuideText.fileName),
            atomically: true,
            encoding: .utf8
        )

        return EditorPackageExportResult(packageURL: packageURL, guide: guide)
    }

    private static func makePlan(for request: EditorPackageExportRequest) -> EditorPackagePlan {
        var sourceClips: [EditorPackageSourceClip] = []
        for (trackIndex, track) in request.timeline.tracks.enumerated() {
            for (clipIndex, clip) in track.clips.enumerated() {
                guard let mediaItemID = clip.mediaItemID,
                      let mediaItem = request.mediaItems.first(where: { $0.id == mediaItemID }) else {
                    continue
                }
                sourceClips.append(EditorPackageSourceClip(
                    mediaName: mediaItem.displayName,
                    mediaURL: mediaItem.fileURL,
                    effectiveStartTime: clip.effectiveStartTime,
                    duration: clip.duration,
                    trackIndex: trackIndex,
                    clipIndex: clipIndex
                ))
            }
        }
        return EditorPackagePlanner.plan(
            clips: sourceClips,
            fitStartTime: request.timeline.fitStartTime,
            activityDuration: request.activity.duration,
            mode: request.mode
        )
    }

    private static func packageBaseName(_ projectName: String) -> String {
        var name = projectName
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            name = "Project"
        }
        return "\(name) Editor Package"
    }
}

/// Reads the source media properties FCPXML wants from AVFoundation. Failures
/// return nil so a package export never fails because of a probe.
enum EditorPackageMediaProbe {
    static func info(for url: URL) async -> EditorPackageSourceMediaInfo? {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let asset = AVURLAsset(url: url)
        do {
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            guard let track = videoTracks.first else { return nil }

            let naturalSize = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            let transformedSize = naturalSize.applying(transform)
            let width = Int(abs(transformedSize.width).rounded())
            let height = Int(abs(transformedSize.height).rounded())
            guard width > 0, height > 0 else { return nil }

            let nominalFrameRate = try await track.load(.nominalFrameRate)
            let duration = try await asset.load(.duration)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)

            return EditorPackageSourceMediaInfo(
                width: width,
                height: height,
                frameRate: nominalFrameRate > 0 ? Double(nominalFrameRate) : 30,
                hasAudio: !audioTracks.isEmpty,
                duration: duration.isNumeric ? duration.seconds : 0
            )
        } catch {
            return nil
        }
    }
}
