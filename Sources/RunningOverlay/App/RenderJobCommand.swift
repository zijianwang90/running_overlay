import Foundation

/// `--render-job <path>` headless render request (ADR 0013, Layer 0).
struct RenderJobCommand: Equatable {
    var jobURL: URL
    /// Overrides the default per-user render cache.
    var cacheDirectory: URL?
    /// False when `--no-render-cache` was passed; span movies always render.
    var usesCache = true

    static func parse(arguments: [String] = CommandLine.arguments) throws -> RenderJobCommand? {
        var jobPath: String?
        var cachePath: String?
        var usesCache = true
        var index = 1

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--render-job":
                index += 1
                guard index < arguments.count else {
                    throw RenderJobError.missingValue(argument)
                }
                jobPath = arguments[index]
            case "--render-cache":
                index += 1
                guard index < arguments.count else {
                    throw RenderJobError.missingValue(argument)
                }
                cachePath = arguments[index]
            case "--no-render-cache":
                usesCache = false
            default:
                break
            }
            index += 1
        }

        guard let jobPath else {
            return nil
        }

        return RenderJobCommand(
            jobURL: resolvedURL(for: jobPath),
            cacheDirectory: cachePath.map(resolvedURL(for:)),
            usesCache: usesCache
        )
    }

    private static func resolvedURL(for path: String) -> URL {
        let expanded = NSString(string: path).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded).standardizedFileURL
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(expanded)
            .standardizedFileURL
    }
}

/// Result record written next to the rendered movies. File names only, never
/// absolute paths, so the record can move with its output folder.
struct RenderJobResult: Codable, Equatable {
    static let currentSchemaVersion = 1
    static let fileName = "render-result.json"

    var schemaVersion: Int = RenderJobResult.currentSchemaVersion
    var rendererVersion: String
    var template: OverlayTemplateManifest
    var activityHash: String
    var spans: [Span]

    struct Span: Codable, Equatable {
        var name: String
        var fileName: String
        var cacheKey: String
        var reusedCache: Bool
        var activityElapsedStart: TimeInterval
        var duration: TimeInterval
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, rendererVersion, template, activityHash, spans
    }
}

enum RenderJobRunner {
    /// Loads and resolves a job, renders it through `OverlayRenderService`, and
    /// writes `render-result.json` into the output directory.
    @MainActor
    static func run(_ command: RenderJobCommand) async throws -> URL {
        let job = try OverlayRenderJobResolver.load(jobURL: command.jobURL)
        let jobDirectory = command.jobURL.deletingLastPathComponent()
        let resolved = try OverlayRenderJobResolver.resolve(job, jobDirectory: jobDirectory)

        let cache: OverlayRenderCache?
        if !command.usesCache {
            cache = nil
        } else if let cacheDirectory = command.cacheDirectory {
            cache = OverlayRenderCache(directoryURL: cacheDirectory)
        } else {
            cache = .defaultCache()
        }

        print("[RenderJob] job=\(command.jobURL.lastPathComponent)")
        print("[RenderJob] renderer=\(OverlayRendererVersion.current) spans=\(job.spans.count) output=\(resolved.outputDirectory.path)")
        print("[RenderJob] activityHash=\(resolved.input.activityHash) cache=\(cache?.directoryURL.path ?? "disabled")")

        let rendered = try await OverlayRenderService.render(
            input: resolved.input,
            output: job.output,
            outputDirectory: resolved.outputDirectory,
            spans: job.spans,
            cache: cache,
            progress: { progress in
                guard progress.segmentProgress >= 1 else { return }
                print("[RenderJob] \(progress.message) 100%")
            }
        )

        for item in rendered {
            let status = item.reusedCache ? "cache-hit" : "rendered"
            print("[RenderJob] span=\(item.span.name) file=\(item.fileURL.lastPathComponent) elapsed=\(item.span.activityElapsedStart) duration=\(item.span.duration) \(status)")
        }

        let result = RenderJobResult(
            rendererVersion: OverlayRendererVersion.current,
            template: try OverlayTemplateManifest(template: resolved.input.template),
            activityHash: resolved.input.activityHash,
            spans: rendered.map { item in
                RenderJobResult.Span(
                    name: item.span.name,
                    fileName: item.fileURL.lastPathComponent,
                    cacheKey: item.cacheKey,
                    reusedCache: item.reusedCache,
                    activityElapsedStart: item.span.activityElapsedStart,
                    duration: item.span.duration
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        let resultURL = resolved.outputDirectory.appendingPathComponent(RenderJobResult.fileName)
        try encoder.encode(result).write(to: resultURL, options: .atomic)
        print("[RenderJob] result=\(resultURL.path)")
        return resolved.outputDirectory
    }
}
