import CryptoKit
import Foundation

/// Version of the overlay pixel output. Bump it whenever a renderer change
/// alters exported pixels, so cached editor renders are invalidated (ADR 0013).
enum OverlayRendererVersion {
    static let current = "skia-1"
}

/// Declarative, Codable headless render request (ADR 0013). Editor carriers
/// and the `--render-job` command line both produce one; the app resolves it
/// into an `OverlayExportJob` for the shared Skia exporter.
///
/// Relative paths resolve against the directory that contains the job file.
struct OverlayRenderJob: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int = OverlayRenderJob.currentSchemaVersion
    var activity: OverlayRenderJobActivitySource
    var template: OverlayRenderJobTemplateSource
    var output: OverlayRenderJobOutput
    var spans: [OverlayRenderSpan]
}

enum OverlayRenderJobActivitySource: Codable, Equatable {
    /// A FIT or GPX file parsed as-is.
    case activityFile(path: String)
    /// A JSON-encoded `ActivityTimeline` written by the app, which preserves
    /// in-app edits such as the workout structure selection.
    case activitySnapshot(path: String)
}

enum OverlayRenderJobTemplateSource: Codable, Equatable {
    /// A `.rotemplate` file.
    case templateFile(path: String)
    /// A `BuiltInOverlayTemplate.id`, such as `easyRun`.
    case builtIn(id: String)
}

struct OverlayRenderJobOutput: Codable, Equatable {
    var directory: String
    var width: Int
    var height: Int
    /// `ProjectFrameRate.id`, for example `29.97`.
    var frameRateID: String
    /// `ProjectLayerDataFrameRate.id`, for example `5`.
    var layerDataFrameRateID: String
    var codec: ProjectExportCodec
    var bitrateMbps: Double
}

/// One output movie covering a contiguous range of the activity.
///
/// Time domain: `activityElapsedStart` is activity elapsed seconds (0 is the
/// first FIT record). It is not media source time and not project timeline
/// time; carriers convert clip ranges with the anchor recorded in the package
/// manifest before writing a span.
struct OverlayRenderSpan: Codable, Equatable {
    /// Output movie base name without extension.
    var name: String
    var activityElapsedStart: TimeInterval
    var duration: TimeInterval
}

extension OverlayRenderJobOutput {
    var frameRate: ProjectFrameRate {
        ProjectFrameRate.presets.first(where: { $0.id == frameRateID }) ?? .fps30
    }

    var layerDataFrameRate: ProjectLayerDataFrameRate {
        ProjectLayerDataFrameRate.presets.first(where: { $0.id == layerDataFrameRateID }) ?? .fps5
    }

    init(directory: String, settings: ProjectSettings) {
        self.init(
            directory: directory,
            width: settings.resolution.width,
            height: settings.resolution.height,
            frameRateID: settings.frameRate.id,
            layerDataFrameRateID: settings.layerDataFrameRate.id,
            codec: settings.exportCodec,
            bitrateMbps: settings.bitrateMbps
        )
    }
}

/// Deterministic SHA-256 hashes of render inputs (ADR 0013).
enum OverlayRenderContentHash {
    static func hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Hashes only what affects pixels: elements and embedded assets. Name,
    /// identifier, and timestamps are excluded so renaming or re-saving a
    /// template keeps cached renders valid.
    static func template(_ template: OverlayTemplate) throws -> String {
        struct Content: Encodable {
            var schemaVersion: Int
            var referenceResolution: OverlayTemplateResolution?
            var elements: [OverlayTemplateElement]
            var assets: [TemplateAsset]
        }
        return hex(of: try canonicalJSON(Content(
            schemaVersion: template.schemaVersion,
            referenceResolution: template.referenceResolution,
            elements: template.elements,
            assets: template.assets
        )))
    }

    static func activity(_ activity: ActivityTimeline) throws -> String {
        hex(of: try canonicalJSON(activity))
    }

    /// Cache key of one span's output movie. Two renders with equal keys
    /// produce the same pixels, so a cached movie can be reused.
    static func spanCacheKey(
        activityHash: String,
        templateHash: String,
        output: OverlayRenderJobOutput,
        span: OverlayRenderSpan,
        rendererVersion: String = OverlayRendererVersion.current
    ) throws -> String {
        struct Key: Encodable {
            var rendererVersion: String
            var jobSchemaVersion: Int
            var activityHash: String
            var templateHash: String
            var width: Int
            var height: Int
            var frameRateID: String
            var layerDataFrameRateID: String
            var codec: ProjectExportCodec
            var bitrateMbps: Double
            var activityElapsedStart: TimeInterval
            var duration: TimeInterval
        }
        return hex(of: try canonicalJSON(Key(
            rendererVersion: rendererVersion,
            jobSchemaVersion: OverlayRenderJob.currentSchemaVersion,
            activityHash: activityHash,
            templateHash: templateHash,
            width: output.width,
            height: output.height,
            frameRateID: output.frameRateID,
            layerDataFrameRateID: output.layerDataFrameRateID,
            codec: output.codec,
            bitrateMbps: output.bitrateMbps,
            activityElapsedStart: span.activityElapsedStart,
            duration: span.duration
        )))
    }

    static func canonicalJSON<Value: Encodable>(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }
}

/// Template capability and version record published with every render, so
/// carriers can show which template and renderer produced an overlay and
/// detect when a cached render is stale.
struct OverlayTemplateManifest: Codable, Equatable {
    var templateID: UUID
    var name: String
    var templateSchemaVersion: Int
    var contentHash: String
    var rendererVersion: String
    var referenceWidth: Int?
    var referenceHeight: Int?
    /// Sorted, de-duplicated `OverlayElementType` raw values.
    var elementTypes: [String]

    init(template: OverlayTemplate, rendererVersion: String = OverlayRendererVersion.current) throws {
        templateID = template.id
        name = template.name
        templateSchemaVersion = template.schemaVersion
        contentHash = try OverlayRenderContentHash.template(template)
        self.rendererVersion = rendererVersion
        referenceWidth = template.referenceResolution?.width
        referenceHeight = template.referenceResolution?.height
        elementTypes = Array(Set(template.elements.map { $0.type.rawValue })).sorted()
    }
}
