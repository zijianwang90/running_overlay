#if canImport(CSkiaBridge)
import Foundation
import Testing
@testable import RunningOverlay

/// Sizes the 4K export gap between the shipping SwiftUI exporter and the
/// zero-copy GPU path in `SkiaGPUExportBenchmarkTests`.
@Suite(.serialized) struct Skia4KExportBenchmarkTests {
    @Test func productionSwiftUIExport4KProRes() async throws {
        try await Self.run(resolution: .uhd4k, label: "CPU-4K")
    }

    @Test func productionSwiftUIExport1080ProRes() async throws {
        try await Self.run(resolution: .hd1080, label: "CPU-1080")
    }

    private static func run(
        resolution: ProjectResolution,
        label: String
    ) async throws {
        let activity = try Self.syntheticActivity()
        let layout = try SkiaGPUSpikeTests.easyRunLayout()
        var settings = ProjectSettings()
        settings.resolution = resolution
        settings.frameRate = .fps30
        settings.layerDataFrameRate = .fps5
        settings.exportCodec = .proRes4444
        settings.bitrateMbps = 100

        let destination = URL(
            fileURLWithPath: "/tmp/skia-cpu-export-\(resolution.id)"
        )
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.createDirectory(
            at: destination,
            withIntermediateDirectories: true
        )

        let segments = (0..<10).map {
            OverlayExportSegment(
                startTime: Double($0) * 5,
                duration: 5,
                sourceFileName: "clip_\($0).mov"
            )
        }
        let job = OverlayExportJob(
            destinationURL: destination,
            settings: settings,
            activity: activity,
            overlayLayout: layout,
            segments: segments,
            writesProfile: true
        )

        let start = ContinuousClock.now
        try await SwiftUIOverlayVideoExporter.export(job: job) { _ in }
        let total = Self.seconds(ContinuousClock.now - start)

        let profileURL = try #require(
            try FileManager.default.contentsOfDirectory(
                at: destination,
                includingPropertiesForKeys: nil
            ).first { $0.pathExtension == "json" }
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let profile = try decoder.decode(
            OverlayExportProfile.self,
            from: Data(contentsOf: profileURL)
        )

        print(
            "\(label) codec=proRes4444 total=\(Self.fmt(total))s "
                + "profileTotal=\(Self.fmt(profile.totalDuration))s "
                + "render=\(Self.fmt(profile.imageRenderDuration))s "
                + "draw=\(Self.fmt(profile.pixelBufferDrawDuration))s "
                + "staticRender=\(Self.fmt(profile.staticRenderDuration))s "
                + "dynamicRender=\(Self.fmt(profile.dynamicRenderDuration))s "
                + "append=\(Self.fmt(profile.appendDuration))s "
                + "wait=\(Self.fmt(profile.writerWaitDuration))s "
                + "rendered=\(profile.renderedFrameCount)/\(profile.totalFrameCount) "
                + "path=\(profile.renderPath.rawValue)"
        )

        #expect(profile.totalFrameCount == 1500)
        #expect(total > 0)
    }

    private static func syntheticActivity() throws -> ActivityTimeline {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Tests/RunningOverlayTests/Fixtures/Activities/synthetic-run.fit")
        return try FitFileParser.parse(url: url)
    }

    private static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds)
            + Double(duration.components.attoseconds) / 1e18
    }

    private static func fmt(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}
#endif
