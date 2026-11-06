import Foundation
#if SWIFT_PACKAGE
import OverlayPluginCore
#endif

/// Studio's domain-model boundary around the host-independent wire protocol.
/// A plugin never needs the original FIT, a video URL, or a Studio project.
enum PluginDataPackageService {
    static func make(
        activity: ActivityTimeline,
        templates: [OverlayTemplate],
        canvasWidth: Int,
        canvasHeight: Int
    ) throws -> PluginDataPackage {
        try validateActivity(activity)
        let activityEncoder = JSONEncoder()
        activityEncoder.outputFormatting = [.sortedKeys]
        // Unlike the legacy render-job snapshot, preserve subsecond dates.
        activityEncoder.dateEncodingStrategy = .millisecondsSince1970
        let templateEncoder = JSONEncoder()
        templateEncoder.outputFormatting = [.sortedKeys]
        let package = PluginDataPackage(
            rendererVersion: OverlayRendererVersion.current,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            activity: PluginPackageResource(schemaVersion: 1, data: try activityEncoder.encode(activity)),
            templates: try templates.map { template in
                guard (1...2).contains(template.schemaVersion) else {
                    throw PluginCoreError.invalidPackage("unsupported template schema \(template.schemaVersion)")
                }
                return PluginPackageTemplate(
                    id: template.id, name: template.name,
                    resource: PluginPackageResource(
                        schemaVersion: template.schemaVersion,
                        data: try templateEncoder.encode(template)
                    )
                )
            }
        )
        try PluginDataPackageCodec.validate(package)
        return package
    }

    static func write(_ package: PluginDataPackage, to url: URL) throws {
        let data = try PluginDataPackageCodec.encode(package)
        // Do not replace a package implicitly; host instances may reference it.
        try data.write(to: url, options: .withoutOverwriting)
    }

    static func load(from url: URL) throws -> PluginDataPackage {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= PluginDataPackageCodec.maximumFileSize else { throw PluginCoreError.packageTooLarge }
        return try PluginDataPackageCodec.decode(Data(contentsOf: url))
    }

    static func resolve(
        _ package: PluginDataPackage,
        templateID: UUID? = nil
    ) throws -> (activity: ActivityTimeline, template: OverlayTemplate) {
        try PluginDataPackageCodec.validate(package)
        guard package.rendererVersion == OverlayRendererVersion.current else {
            throw PluginCoreError.invalidPackage("renderer version \(package.rendererVersion) requires a matching reader")
        }
        guard package.activity.schemaVersion == 1 else {
            throw PluginCoreError.invalidPackage("unsupported activity snapshot schema")
        }
        let selected = templateID.flatMap { id in package.templates.first { $0.id == id } }
        guard let entry = templateID == nil ? package.templates.first : selected else {
            throw PluginCoreError.invalidPackage("requested template is missing")
        }
        guard (1...2).contains(entry.resource.schemaVersion) else {
            throw PluginCoreError.invalidPackage("unsupported template schema")
        }
        let activityDecoder = JSONDecoder()
        activityDecoder.dateDecodingStrategy = .millisecondsSince1970
        let activity = try activityDecoder.decode(ActivityTimeline.self, from: package.activity.data)
        try validateActivity(activity)
        let template = try JSONDecoder().decode(OverlayTemplate.self, from: entry.resource.data)
        guard template.id == entry.id, template.name == entry.name,
              template.schemaVersion == entry.resource.schemaVersion else {
            throw PluginCoreError.invalidPackage("template metadata does not match its payload")
        }
        return (activity, template)
    }

    /// The first frame spike deliberately has no map/weather/asset-store
    /// dependencies. Reject these explicitly rather than drawing substitutes.
    static func validateFrameCapabilities(_ template: OverlayTemplate) throws {
        guard template.assets.isEmpty,
              template.elements.contains(where: \.isVisible),
              template.elements.allSatisfy({ $0.type.isNumericOverlay || $0.type == .decorSolidColor }) else {
            throw PluginCoreError.invalidPackage(
                "the frame spike supports numeric overlays and solid-color decor only; maps, weather and user resources need preparation"
            )
        }
    }

    private static func validateActivity(_ activity: ActivityTimeline) throws {
        guard activity.duration.isFinite, activity.duration > 0,
              activity.startDate.timeIntervalSince1970.isFinite,
              !activity.records.isEmpty,
              activity.records.allSatisfy({ $0.elapsedTime.isFinite && $0.elapsedTime >= 0 && $0.elapsedTime <= activity.duration }),
              zip(activity.records, activity.records.dropFirst()).allSatisfy({ $0.elapsedTime <= $1.elapsedTime }) else {
            throw PluginCoreError.invalidPackage("activity needs ordered records within a positive duration")
        }
    }
}
