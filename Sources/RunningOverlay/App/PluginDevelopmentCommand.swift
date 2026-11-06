import Foundation
#if SWIFT_PACKAGE
import OverlayPluginCore
#endif

/// Developer-only preparation and frame probes. The separate diagnostic
/// carrier has passed local FxPlug host smoke checks; runtime package
/// selection and production installation remain outside this command.
enum PluginDevelopmentCommand: Equatable {
    case prepare(jobURL: URL, outputURL: URL)
    case frame(packageURL: URL, outputURL: URL, templateID: UUID?, sourceTime: PluginMediaTime, mapping: PluginTimeMapping)
    case sequence(packageURL: URL, outputDirectory: URL, templateID: UUID?, sourceTimes: [PluginMediaTime], mapping: PluginTimeMapping)

    static func parse(arguments: [String] = CommandLine.arguments) throws -> PluginDevelopmentCommand? {
        let arguments = Array(arguments.dropFirst())
        let isPrepare = arguments.contains("--prepare-plugin-package")
        let isSequence = arguments.contains("--plugin-frames")
        let isFrame = arguments.contains("--plugin-frame") || isSequence
        guard isPrepare || isFrame else { return nil }
        guard isPrepare != isFrame else { throw PluginCoreError.invalidPackage("select one plugin command") }
        guard !(isSequence && arguments.contains("--plugin-frame")) else {
            throw PluginCoreError.invalidPackage("select one plugin frame mode")
        }
        guard !arguments.contains(where: { ["--render-job", "--benchmark-export", "--benchmark-elevation", "--benchmark-template-segments"].contains($0) }) else {
            throw PluginCoreError.invalidPackage("plugin commands cannot be combined with other headless commands")
        }
        let allowed: Set<String> = isPrepare
            ? ["--prepare-plugin-package", "--plugin-output"]
            : [isSequence ? "--plugin-frames" : "--plugin-frame", "--plugin-output", "--plugin-template", isSequence ? "--plugin-source-values" : "--plugin-source-value", "--plugin-source-timescale", "--plugin-anchor-value", "--plugin-anchor-timescale", "--plugin-activity-anchor", "--plugin-offset"]
        var options: [String: String] = [:]
        var index = 0
        while index < arguments.count {
            let key = arguments[index]
            guard allowed.contains(key), options[key] == nil else {
                throw PluginCoreError.invalidPackage("unknown or repeated argument \(key)")
            }
            index += 1
            guard index < arguments.count, !arguments[index].hasPrefix("--") else {
                throw RenderJobError.missingValue(key)
            }
            options[key] = arguments[index]
            index += 1
        }
        func required(_ key: String) throws -> String {
            guard let value = options[key], !value.isEmpty else { throw RenderJobError.missingValue(key) }
            return value
        }
        func url(_ key: String) throws -> URL {
            OverlayRenderJobResolver.resolvedURL(try required(key), relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        }
        let outputURL = try url("--plugin-output")
        if isPrepare {
            return .prepare(jobURL: try url("--prepare-plugin-package"), outputURL: outputURL)
        }
        func mediaTime(value: String, scale: String) throws -> PluginMediaTime {
            guard let ticks = Int64(try required(value)), let timescale = Int32(try required(scale)) else {
                throw PluginCoreError.invalidTime
            }
            return try PluginMediaTime(value: ticks, timescale: timescale)
        }
        guard let activityAnchor = Double(try required("--plugin-activity-anchor")),
              let correction = Double(options["--plugin-offset"] ?? "0") else { throw PluginCoreError.invalidTime }
        let templateID: UUID?
        if let value = options["--plugin-template"] {
            guard let id = UUID(uuidString: value) else { throw PluginCoreError.invalidPackage("invalid template ID") }
            templateID = id
        } else {
            templateID = nil
        }
        let mapping = try PluginTimeMapping(
            mediaSourceAnchor: mediaTime(value: "--plugin-anchor-value", scale: "--plugin-anchor-timescale"),
            activityElapsedAnchor: activityAnchor, correctionSeconds: correction
        )
        if isSequence {
            let values = try required("--plugin-source-values").split(separator: ",", omittingEmptySubsequences: false)
            guard (1...256).contains(values.count),
                  let scale = Int32(try required("--plugin-source-timescale")) else { throw PluginCoreError.invalidTime }
            let times = try values.map { value in
                guard let ticks = Int64(value) else { throw PluginCoreError.invalidTime }
                return try PluginMediaTime(value: ticks, timescale: scale)
            }
            return .sequence(packageURL: try url("--plugin-frames"), outputDirectory: outputURL, templateID: templateID, sourceTimes: times, mapping: mapping)
        }
        return try .frame(
            packageURL: url("--plugin-frame"), outputURL: outputURL, templateID: templateID,
            sourceTime: mediaTime(value: "--plugin-source-value", scale: "--plugin-source-timescale"),
            mapping: mapping
        )
    }
}

enum PluginDevelopmentRunner {
    @MainActor
    static func run(_ command: PluginDevelopmentCommand) async throws -> URL {
        switch command {
        case .prepare(let jobURL, let outputURL):
            let job = try OverlayRenderJobResolver.load(jobURL: jobURL)
            let resolved = try OverlayRenderJobResolver.resolve(job, jobDirectory: jobURL.deletingLastPathComponent())
            let package = try PluginDataPackageService.make(
                activity: resolved.input.activity, templates: [resolved.input.template],
                canvasWidth: job.output.width, canvasHeight: job.output.height
            )
            try PluginDataPackageService.write(package, to: outputURL)
            print("[PluginProbe] prepared \(outputURL.path) template=\(package.templates[0].id)")
            return outputURL
        case .frame(let packageURL, let outputURL, let templateID, let sourceTime, let mapping):
            let package = try PluginDataPackageService.load(from: packageURL)
            let input = try PluginDataPackageService.resolve(package, templateID: templateID)
            try PluginDataPackageService.validateFrameCapabilities(input.template)
            guard let elapsed = try mapping.activityElapsedTime(forMediaSourceTime: sourceTime, activityDuration: input.activity.duration) else {
                throw PluginCoreError.invalidPackage("requested frame is outside the activity; the host must composite transparent output")
            }
            #if canImport(CSkiaBridge)
            let probe = try PluginMetalFrameProbe(package: package, templateID: templateID)
            try probe.exportFramePNG(sourceTime: sourceTime, mapping: mapping, to: outputURL)
            #else
            throw OverlayRendererBackendError.unavailable(.skia)
            #endif
            print("[PluginProbe] frame=\(outputURL.path) activityElapsed=\(elapsed) renderer=skia")
            return outputURL
        case .sequence(let packageURL, let outputDirectory, let templateID, let sourceTimes, let mapping):
            guard (1...256).contains(sourceTimes.count) else { throw PluginCoreError.invalidTime }
            #if canImport(CSkiaBridge)
            let package = try PluginDataPackageService.load(from: packageURL)
            let probe = try PluginMetalFrameProbe(package: package, templateID: templateID)
            // A fresh directory avoids overwriting earlier probe evidence.
            guard !FileManager.default.fileExists(atPath: outputDirectory.path) else {
                throw PluginCoreError.invalidPackage("frame sequence destination already exists")
            }
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: false)
            for (index, time) in sourceTimes.enumerated() {
                let file = outputDirectory.appendingPathComponent(String(format: "frame-%03d.png", index))
                let elapsed = try probe.exportFramePNG(sourceTime: time, mapping: mapping, to: file)
                print("[PluginProbe] frame=\(file.lastPathComponent) activityElapsed=\(elapsed.map(String.init(describing:)) ?? "transparent") renderer=skia")
            }
            return outputDirectory
            #else
            throw OverlayRendererBackendError.unavailable(.skia)
            #endif
        }
    }
}
