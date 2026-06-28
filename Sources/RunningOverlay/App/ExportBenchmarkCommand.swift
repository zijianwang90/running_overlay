import Foundation

struct ExportBenchmarkCommand: Equatable {
    var snapshotURL: URL
    var outputDirectory: URL?

    static func parse(arguments: [String] = CommandLine.arguments) throws -> ExportBenchmarkCommand? {
        var snapshotPath: String?
        var outputPath: String?
        var index = 1

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--benchmark-export":
                index += 1
                guard index < arguments.count else {
                    throw ExportBenchmarkError.missingValue(argument)
                }
                snapshotPath = arguments[index]
            case "--benchmark-output":
                index += 1
                guard index < arguments.count else {
                    throw ExportBenchmarkError.missingValue(argument)
                }
                outputPath = arguments[index]
            default:
                break
            }
            index += 1
        }

        guard let snapshotPath else {
            return nil
        }

        return ExportBenchmarkCommand(
            snapshotURL: resolvedURL(for: snapshotPath),
            outputDirectory: outputPath.map(resolvedURL(for:))
        )
    }

    private static func resolvedURL(for path: String) -> URL {
        let expanded = NSString(string: path).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded)
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(expanded)
    }
}

enum ExportBenchmarkError: LocalizedError {
    case missingValue(String)
    case noSegments

    var errorDescription: String? {
        switch self {
        case .missingValue(let argument):
            "Missing value for \(argument)."
        case .noSegments:
            "Snapshot does not contain timeline clips that can be exported."
        }
    }
}

enum ExportBenchmarkRunner {
    static func run(_ command: ExportBenchmarkCommand) async throws -> URL {
        let snapshot = try loadSnapshot(from: command.snapshotURL)
        let outputDirectory = try command.outputDirectory ?? defaultOutputDirectory()
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let segments = snapshot.timeline.tracks.flatMap(\.clips).compactMap { clip -> OverlayExportSegment? in
            guard let mediaItemID = clip.mediaItemID,
                  let mediaItem = snapshot.mediaItems.first(where: { $0.id == mediaItemID }) else {
                return nil
            }
            return OverlayExportSegment(
                startTime: clip.effectiveStartTime,
                duration: clip.duration,
                sourceFileName: mediaItem.displayName
            )
        }
        guard !segments.isEmpty else {
            throw ExportBenchmarkError.noSegments
        }

        let job = OverlayExportJob(
            destinationURL: outputDirectory,
            settings: snapshot.settings,
            activity: snapshot.activity,
            overlayLayout: OverlayLayout(elements: snapshot.overlayElements.map(\.overlayElement)),
            fitStartTime: snapshot.timeline.fitStartTime,
            segments: segments
        )

        print("[RunningOverlayBenchmark] snapshot=\(command.snapshotURL.path)")
        print("[RunningOverlayBenchmark] output=\(outputDirectory.path)")
        print("[RunningOverlayBenchmark] segments=\(segments.count)")
        try await SwiftUIOverlayVideoExporter.export(job: job) { progress in
            let percent = Int((progress.segmentProgress * 100).rounded())
            print("[RunningOverlayBenchmark] \(progress.message) \(percent)%")
        }
        print("[RunningOverlayBenchmark] completed")
        return outputDirectory
    }

    private static func loadSnapshot(from url: URL) throws -> ProjectPerformanceSnapshot {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ProjectPerformanceSnapshot.self, from: data)
    }

    private static func defaultOutputDirectory() throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let stamp = formatter.string(from: Date())
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("running_overlay_benchmark_\(stamp)", isDirectory: true)
    }
}

/// Headless A/B benchmark driven by a real FIT file and a `.rotemplate`.
/// Exports a transparent overlay MOV for a chosen activity window twice —
/// once with the elevation chart static fill cache disabled (baseline) and once
/// enabled — into sibling folders for timing and visual comparison.
struct ElevationBenchmarkCommand: Equatable {
    var fitURL: URL
    var templateURL: URL
    var startSeconds: TimeInterval
    var durationSeconds: TimeInterval
    var outputDirectory: URL?

    static func parse(arguments: [String] = CommandLine.arguments) throws -> ElevationBenchmarkCommand? {
        var fitPath: String?
        var templatePath: String?
        var outputPath: String?
        var start: TimeInterval = 0
        var duration: TimeInterval = 50
        var index = 1

        while index < arguments.count {
            let argument = arguments[index]
            func value() throws -> String {
                index += 1
                guard index < arguments.count else {
                    throw ExportBenchmarkError.missingValue(argument)
                }
                return arguments[index]
            }
            switch argument {
            case "--benchmark-elevation":
                fitPath = try value()
            case "--template":
                templatePath = try value()
            case "--benchmark-output":
                outputPath = try value()
            case "--start":
                start = Double(try value()) ?? 0
            case "--duration":
                duration = Double(try value()) ?? 50
            default:
                break
            }
            index += 1
        }

        guard let fitPath, let templatePath else {
            return nil
        }
        return ElevationBenchmarkCommand(
            fitURL: resolvedURL(for: fitPath),
            templateURL: resolvedURL(for: templatePath),
            startSeconds: max(0, start),
            durationSeconds: max(1, duration),
            outputDirectory: outputPath.map(resolvedURL(for:))
        )
    }

    private static func resolvedURL(for path: String) -> URL {
        let expanded = NSString(string: path).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded)
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(expanded)
    }
}

enum ElevationBenchmarkRunner {
    private struct RunResult {
        var label: String
        var wallClock: TimeInterval
        var profile: OverlayExportProfile?
    }

    @MainActor
    static func run(_ command: ElevationBenchmarkCommand) async throws -> URL {
        let activity = try FitFileParser.parse(url: command.fitURL)
        let template = try OverlayTemplateStore().loadTemplateFile(from: command.templateURL)
        let elements = template.layout.elements
        let elevationCount = elements.filter { $0.type == .elevationChart }.count

        var settings = ProjectSettings()
        settings.exportCodec = .hevcWithAlpha
        if let reference = template.referenceResolution,
           let match = ProjectResolution.presets.first(where: { $0.width == reference.width && $0.height == reference.height }) {
            settings.resolution = match
        }

        let outputDirectory = try command.outputDirectory ?? defaultOutputDirectory()
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let effectiveDuration = min(command.durationSeconds, max(activity.duration - command.startSeconds, 1))
        let segment = OverlayExportSegment(
            startTime: 0,
            duration: effectiveDuration,
            sourceFileName: "elevation_benchmark"
        )

        let plan = ExportRenderPlan(
            overlays: elements,
            canvasSize: CGSize(width: settings.resolution.width, height: settings.resolution.height),
            activity: activity
        )

        print("[ElevationBenchmark] fit=\(command.fitURL.lastPathComponent) activityDuration=\(Int(activity.duration))s")
        print("[ElevationBenchmark] template=\(template.name) elements=\(elements.count) elevationCharts=\(elevationCount)")
        print("[ElevationBenchmark] resolution=\(settings.resolution.width)x\(settings.resolution.height) fps=\(settings.frameRate.value) layerDataFps=\(settings.layerDataFrameRate.value) codec=\(settings.exportCodec)")
        print("[ElevationBenchmark] renderPath=\(plan.renderPath.rawValue) overlayRenderAreaRatio=\(String(format: "%.2f", plan.overlayRenderAreaRatio)) maxIndividualAreaRatio=\(String(format: "%.2f", plan.maxIndividualOverlayAreaRatio))")
        print("[ElevationBenchmark] window start=\(Int(command.startSeconds))s duration=\(Int(effectiveDuration))s output=\(outputDirectory.path)")

        let baseline = try await exportRun(
            label: "baseline_no_cache",
            cacheEnabled: false,
            activity: activity,
            elements: elements,
            settings: settings,
            segment: segment,
            fitStartTime: command.startSeconds,
            parent: outputDirectory
        )
        let cached = try await exportRun(
            label: "cached",
            cacheEnabled: true,
            activity: activity,
            elements: elements,
            settings: settings,
            segment: segment,
            fitStartTime: command.startSeconds,
            parent: outputDirectory
        )

        let summary = summaryText(baseline: baseline, cached: cached, elevationCount: elevationCount, plan: plan)
        let summaryURL = outputDirectory.appendingPathComponent("benchmark_summary.txt")
        try Data(summary.utf8).write(to: summaryURL)
        print(summary)
        return outputDirectory
    }

    @MainActor
    private static func exportRun(
        label: String,
        cacheEnabled: Bool,
        activity: ActivityTimeline,
        elements: [OverlayElement],
        settings: ProjectSettings,
        segment: OverlayExportSegment,
        fitStartTime: TimeInterval,
        parent: URL
    ) async throws -> RunResult {
        let destination = parent.appendingPathComponent(label, isDirectory: true)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        ExportRenderPlan.elevationChartStaticFillCacheEnabled = cacheEnabled
        defer { ExportRenderPlan.elevationChartStaticFillCacheEnabled = true }

        let job = OverlayExportJob(
            destinationURL: destination,
            settings: settings,
            activity: activity,
            overlayLayout: OverlayLayout(elements: elements),
            fitStartTime: fitStartTime,
            segments: [segment]
        )

        print("[ElevationBenchmark] >>> run \(label) (cache=\(cacheEnabled))")
        let startedAt = Date()
        try await SwiftUIOverlayVideoExporter.export(job: job) { progress in
            let percent = Int((progress.segmentProgress * 100).rounded())
            if percent % 25 == 0 {
                print("[ElevationBenchmark] \(label) \(percent)%")
            }
        }
        let wallClock = Date().timeIntervalSince(startedAt)
        let profile = loadNewestProfile(in: destination)
        print("[ElevationBenchmark] <<< run \(label) wallClock=\(String(format: "%.2f", wallClock))s renderPath=\(profile?.renderPath.rawValue ?? "unknown")")
        return RunResult(label: label, wallClock: wallClock, profile: profile)
    }

    private static func summaryText(
        baseline: RunResult,
        cached: RunResult,
        elevationCount: Int,
        plan: ExportRenderPlan
    ) -> String {
        var lines: [String] = []
        lines.append("Elevation Chart Export Static-Fill Cache Benchmark")
        lines.append("==================================================")
        lines.append("Elevation charts in template: \(elevationCount)")
        lines.append("Planned renderPath: \(plan.renderPath.rawValue)")
        lines.append("overlayRenderAreaRatio: \(String(format: "%.3f", plan.overlayRenderAreaRatio))")
        lines.append("maxIndividualOverlayAreaRatio: \(String(format: "%.3f", plan.maxIndividualOverlayAreaRatio))")
        lines.append("")
        for run in [baseline, cached] {
            lines.append("[\(run.label)]")
            lines.append("  wallClock          : \(String(format: "%.3f", run.wallClock)) s")
            if let p = run.profile {
                lines.append("  renderPath         : \(p.renderPath.rawValue)")
                lines.append("  totalFrames        : \(p.totalFrameCount)")
                lines.append("  renderedFrames     : \(p.renderedFrameCount)")
                lines.append("  reusedFrames       : \(p.reusedFrameCount)")
                lines.append("  imageRenderDuration: \(String(format: "%.3f", p.imageRenderDuration)) s")
                lines.append("  pixelBufferDraw    : \(String(format: "%.3f", p.pixelBufferDrawDuration)) s")
                lines.append("  staticRenderDur    : \(String(format: "%.3f", p.staticRenderDuration)) s")
                lines.append("  overlayRenderCount : \(p.overlayRenderCount)")
                lines.append("  totalDuration      : \(String(format: "%.3f", p.totalDuration)) s")
            } else {
                lines.append("  (no profile written)")
            }
            lines.append("")
        }
        if cached.wallClock > 0 {
            let speedup = baseline.wallClock / cached.wallClock
            lines.append("Wall-clock speedup (baseline / cached): \(String(format: "%.2f", speedup))x")
        }
        if let bp = baseline.profile, let cp = cached.profile, cp.imageRenderDuration > 0 {
            let renderSpeedup = bp.imageRenderDuration / cp.imageRenderDuration
            lines.append("imageRenderDuration speedup          : \(String(format: "%.2f", renderSpeedup))x")
            if cp.renderPath != .perOverlay {
                lines.append("")
                lines.append("NOTE: renderPath is '\(cp.renderPath.rawValue)', not 'perOverlay'.")
                lines.append("      Elevation chart static-fill cache only engages on perOverlay.")
            }
        }
        lines.append("")
        lines.append("Open 'cached/elevation_benchmark_swiftui_overlay.mov' to inspect the visual output.")
        return lines.joined(separator: "\n")
    }

    private static func loadNewestProfile(in directory: URL) -> OverlayExportProfile? {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else {
            return nil
        }
        let profiles = contents.filter { $0.lastPathComponent.hasPrefix("export_profile_") && $0.pathExtension == "json" }
        guard let newest = profiles.sorted(by: { lhs, rhs in
            let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return l > r
        }).first else {
            return nil
        }
        guard let data = try? Data(contentsOf: newest) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(OverlayExportProfile.self, from: data)
    }

    private static func defaultOutputDirectory() throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let stamp = formatter.string(from: Date())
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("elevation_benchmark_\(stamp)", isDirectory: true)
    }
}
