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
