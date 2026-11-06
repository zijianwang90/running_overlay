import Foundation

/// Resolved, in-memory inputs of a render (ADR 0013). The app builds one from
/// the open project; `--render-job` builds one from the files a job names.
struct OverlayRenderInput {
    var activity: ActivityTimeline
    var activityHash: String
    var template: OverlayTemplate
    var templateHash: String

    init(activity: ActivityTimeline, template: OverlayTemplate) throws {
        self.activity = activity
        self.template = template
        activityHash = try OverlayRenderContentHash.activity(activity)
        templateHash = try OverlayRenderContentHash.template(template)
    }
}

struct OverlayRenderedSpan: Equatable {
    var span: OverlayRenderSpan
    var cacheKey: String
    var fileURL: URL
    var reusedCache: Bool
}

/// Content-addressed store of rendered span movies keyed by
/// `OverlayRenderContentHash.spanCacheKey`.
struct OverlayRenderCache {
    var directoryURL: URL

    static func defaultCache() -> OverlayRenderCache {
        let baseURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return OverlayRenderCache(directoryURL: baseURL
            .appendingPathComponent("RunningOverlay", isDirectory: true)
            .appendingPathComponent("RenderCache", isDirectory: true))
    }

    func movieURL(forKey key: String) -> URL {
        directoryURL.appendingPathComponent("\(key).mov")
    }

    func cachedMovie(forKey key: String) -> URL? {
        let url = movieURL(forKey: key)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func store(_ movieURL: URL, forKey key: String) throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let destination = self.movieURL(forKey: key)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.copyItem(at: movieURL, to: destination)
    }
}

enum OverlayRenderServiceError: LocalizedError, Equatable {
    case noSpans
    case invalidSpan(String)
    case missingRenderedMovie(String)

    var errorDescription: String? {
        switch self {
        case .noSpans:
            "The render job has no spans."
        case .invalidSpan(let name):
            "Span \"\(name)\" needs a positive duration and a non-empty name without dots or slashes."
        case .missingRenderedMovie(let name):
            "The exporter did not produce a movie for span \(name)."
        }
    }
}

/// The single headless render path shared by the `--render-job` command and
/// the Export for Editor package. It always drives
/// `SwiftUIOverlayVideoExporter`, so editor overlays match app exports.
enum OverlayRenderService {
    /// Renders each span to `<outputDirectory>/<span.name>.mov`, reusing cached
    /// movies when `cache` is set. Existing files with those names are replaced.
    @MainActor
    static func render(
        input: OverlayRenderInput,
        output: OverlayRenderJobOutput,
        outputDirectory: URL,
        spans: [OverlayRenderSpan],
        cache: OverlayRenderCache?,
        progress: @escaping @MainActor (OverlayExportProgress) -> Void = { _ in }
    ) async throws -> [OverlayRenderedSpan] {
        guard !spans.isEmpty else {
            throw OverlayRenderServiceError.noSpans
        }
        // Names become file names verbatim; the exporter strips extensions,
        // so dots and path separators are rejected.
        for span in spans where span.duration <= 0 || span.name.isEmpty
            || span.name.contains(".") || span.name.contains("/") {
            throw OverlayRenderServiceError.invalidSpan(span.name)
        }

        let fileManager = FileManager.default
        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        var results: [OverlayRenderedSpan] = []
        var pending: [(span: OverlayRenderSpan, key: String)] = []
        for span in spans {
            let key = try OverlayRenderContentHash.spanCacheKey(
                activityHash: input.activityHash,
                templateHash: input.templateHash,
                output: output,
                span: span
            )
            let destination = outputDirectory.appendingPathComponent("\(span.name).mov")
            if let cached = cache?.cachedMovie(forKey: key) {
                try? fileManager.removeItem(at: destination)
                try fileManager.copyItem(at: cached, to: destination)
                results.append(OverlayRenderedSpan(span: span, cacheKey: key, fileURL: destination, reusedCache: true))
            } else {
                pending.append((span, key))
            }
        }

        if !pending.isEmpty {
            // The exporter names movies after the segment and may write
            // profiles, so render into a scratch directory and move only
            // the movies into place.
            let scratchURL = fileManager.temporaryDirectory
                .appendingPathComponent("RunningOverlayRender-\(UUID().uuidString)", isDirectory: true)
            defer { try? fileManager.removeItem(at: scratchURL) }

            // Time domains: spans are activity elapsed seconds, so the
            // project-time origin (`fitStartTime`) is zero and each segment
            // starts at its activity elapsed time.
            let job = OverlayExportJob(
                destinationURL: scratchURL,
                settings: makeSettings(output),
                activity: input.activity,
                overlayLayout: input.template.layout,
                fitStartTime: 0,
                segments: pending.map { item in
                    OverlayExportSegment(
                        startTime: item.span.activityElapsedStart,
                        duration: item.span.duration,
                        sourceFileName: item.span.name
                    )
                }
            )
            try await SwiftUIOverlayVideoExporter.export(job: job, progress: progress)

            let produced = try fileManager.contentsOfDirectory(at: scratchURL, includingPropertiesForKeys: nil)
            for item in pending {
                let candidates = ["\(item.span.name)_skia_overlay.mov", "\(item.span.name)_swiftui_overlay.mov"]
                guard let movieURL = produced.first(where: { candidates.contains($0.lastPathComponent) }) else {
                    throw OverlayRenderServiceError.missingRenderedMovie(item.span.name)
                }
                try cache?.store(movieURL, forKey: item.key)
                let destination = outputDirectory.appendingPathComponent("\(item.span.name).mov")
                try? fileManager.removeItem(at: destination)
                try fileManager.moveItem(at: movieURL, to: destination)
                results.append(OverlayRenderedSpan(span: item.span, cacheKey: item.key, fileURL: destination, reusedCache: false))
            }
        }

        return spans.compactMap { span in results.first(where: { $0.span == span }) }
    }

    static func makeSettings(_ output: OverlayRenderJobOutput) -> ProjectSettings {
        var settings = ProjectSettings()
        settings.resolution = ProjectResolution.presets.first(where: {
            $0.width == output.width && $0.height == output.height
        }) ?? ProjectResolution(
            id: "\(output.width)x\(output.height)",
            label: "\(output.width) x \(output.height)",
            width: output.width,
            height: output.height
        )
        settings.frameRate = output.frameRate
        settings.layerDataFrameRate = output.layerDataFrameRate
        settings.exportCodec = output.codec
        settings.bitrateMbps = output.bitrateMbps
        return settings
    }
}
