import Foundation

/// Resolves the declarative inputs a `--render-job` file names into the
/// in-memory values `OverlayRenderService` renders (ADR 0013).
///
/// Relative paths in a job resolve against the job file's directory; absolute
/// paths and `~` are honoured as written.
enum OverlayRenderJobResolver {
    /// Decodes a job file and rejects schema versions this build cannot run.
    static func load(jobURL: URL) throws -> OverlayRenderJob {
        let data = try Data(contentsOf: jobURL)
        let decoder = JSONDecoder()

        // Check the version before the full decode so a newer file reports a
        // clear error instead of an arbitrary missing-key failure.
        let header = try decoder.decode(SchemaHeader.self, from: data)
        guard header.schemaVersion >= 1,
              header.schemaVersion <= OverlayRenderJob.currentSchemaVersion else {
            throw RenderJobError.unsupportedSchemaVersion(header.schemaVersion)
        }
        return try decoder.decode(OverlayRenderJob.self, from: data)
    }

    /// Loads the activity and template a job names and resolves its output
    /// directory. `jobDirectory` is the folder containing the job file.
    static func resolve(
        _ job: OverlayRenderJob,
        jobDirectory: URL
    ) throws -> (input: OverlayRenderInput, outputDirectory: URL) {
        let activity: ActivityTimeline
        switch job.activity {
        case .activityFile(let path):
            activity = try ActivityFileParser.parse(url: resolvedURL(path, relativeTo: jobDirectory))
        case .activitySnapshot(let path):
            activity = try loadActivitySnapshot(from: resolvedURL(path, relativeTo: jobDirectory))
        }

        let template: OverlayTemplate
        switch job.template {
        case .templateFile(let path):
            template = try OverlayTemplateStore().loadTemplateFile(from: resolvedURL(path, relativeTo: jobDirectory))
        case .builtIn(let id):
            guard let builtIn = BuiltInOverlayTemplate.all.first(where: { $0.id == id }) else {
                throw RenderJobError.unknownBuiltInTemplate(id)
            }
            template = try builtIn.loadResourceTemplate()
        }

        return (
            try OverlayRenderInput(activity: activity, template: template),
            resolvedURL(job.output.directory, relativeTo: jobDirectory)
        )
    }

    /// Decodes an app-written `ActivityTimeline` snapshot. The project file
    /// format stores dates as ISO 8601, so snapshots use the same strategy.
    static func loadActivitySnapshot(from url: URL) throws -> ActivityTimeline {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ActivityTimeline.self, from: Data(contentsOf: url))
    }

    /// Writes an `ActivityTimeline` snapshot the `activitySnapshot` job source
    /// can read back. Preserves in-app edits such as the workout structure
    /// selection.
    static func writeActivitySnapshot(_ activity: ActivityTimeline, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(activity).write(to: url, options: .atomic)
    }

    /// Resolves a job path. Relative paths resolve against `directory`;
    /// absolute and `~`-prefixed paths are used as written.
    static func resolvedURL(_ path: String, relativeTo directory: URL) -> URL {
        let expanded = NSString(string: path).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded).standardizedFileURL
        }
        return directory.appendingPathComponent(expanded).standardizedFileURL
    }

    private struct SchemaHeader: Decodable {
        var schemaVersion: Int
    }
}

enum RenderJobError: LocalizedError, Equatable {
    case missingValue(String)
    case unsupportedSchemaVersion(Int)
    case unknownBuiltInTemplate(String)

    var errorDescription: String? {
        switch self {
        case .missingValue(let argument):
            "Missing value for \(argument)."
        case .unsupportedSchemaVersion(let version):
            "Render job schema version \(version) is not supported; this build supports 1 through \(OverlayRenderJob.currentSchemaVersion)."
        case .unknownBuiltInTemplate(let id):
            "Unknown built-in template \"\(id)\"."
        }
    }
}
