import AppKit
import Foundation
import OverlayPluginCore
import Testing
@testable import RunningOverlay

@MainActor
@Suite(.serialized, .skiaSerialized)
struct PluginDevelopmentTests {
    @Test func packagePreservesActivitySubsecondsAndTemplateSelection() throws {
        let activity = try activity()
        let first = template(.heartRate)
        let second = template(.elapsedTime)
        let package = try PluginDataPackageService.make(activity: activity, templates: [first, second], canvasWidth: 640, canvasHeight: 360)
        let input = try PluginDataPackageService.resolve(PluginDataPackageCodec.decode(PluginDataPackageCodec.encode(package)), templateID: second.id)
        #expect(input.activity == activity)
        #expect(input.template == second)
        #expect(throws: PluginCoreError.self) { try PluginDataPackageService.resolve(package, templateID: UUID()) }
    }

    @Test func packageMovesWithoutOriginalActivityOrTemplate() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.roplugin")
        let moved = root.appendingPathComponent("moved.roplugin")
        let package = try makePackage()
        try PluginDataPackageService.write(package, to: source)
        try FileManager.default.moveItem(at: source, to: moved)
        let input = try PluginDataPackageService.resolve(PluginDataPackageService.load(from: moved))
        #expect(input.activity.duration > 0)
        #expect(input.template.id == package.templates[0].id)
    }

    @Test func writingNeverReplacesExistingPackage() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("existing.roplugin")
        try Data("original".utf8).write(to: url)
        #expect(throws: (any Error).self) { try PluginDataPackageService.write(makePackage(), to: url) }
        #expect(try Data(contentsOf: url) == Data("original".utf8))
    }

    @Test(arguments: [OverlayElementType.routeMap, .weatherWidget, .decorIcon])
    func frameSpikeRejectsUnpreparedResources(_ type: OverlayElementType) {
        #expect(throws: PluginCoreError.self) { try PluginDataPackageService.validateFrameCapabilities(template(type)) }
    }

    @Test func frameSpikeDoesNotDropHiddenUnsupportedElements() {
        var unsupported = template(.routeMap)
        unsupported.elements[0].isVisible = false
        #expect(throws: PluginCoreError.self) { try PluginDataPackageService.validateFrameCapabilities(unsupported) }
    }

    @Test func templateMetadataAndFutureDomainSchemaAreValidated() throws {
        let valid = try makePackage()
        let resource = valid.templates[0].resource
        let mismatch = PluginDataPackage(rendererVersion: OverlayRendererVersion.current, canvasWidth: 640, canvasHeight: 360, activity: valid.activity, templates: [PluginPackageTemplate(id: UUID(), name: "Mismatch", resource: resource)])
        #expect(throws: PluginCoreError.self) { try PluginDataPackageService.resolve(mismatch) }
        let future = PluginDataPackage(rendererVersion: OverlayRendererVersion.current, canvasWidth: 640, canvasHeight: 360, activity: PluginPackageResource(schemaVersion: 99, data: valid.activity.data), templates: valid.templates)
        #expect(throws: PluginCoreError.self) { try PluginDataPackageService.resolve(future) }
    }

    @Test func invalidActivityCannotEnterPackage() throws {
        var invalid = try activity()
        invalid.records.reverse()
        #expect(throws: PluginCoreError.self) { try PluginDataPackageService.make(activity: invalid, templates: [template(.heartRate)], canvasWidth: 640, canvasHeight: 360) }
    }

    @Test func commandParserRequiresExplicitTimeDomainsAndRejectsAmbiguity() throws {
        let command = try #require(try PluginDevelopmentCommand.parse(arguments: frameArguments()))
        guard case .frame(_, _, _, let time, let mapping) = command else {
            Issue.record("Expected frame command")
            return
        }
        #expect(time.value == 300)
        #expect(try mapping.activityElapsedTime(forMediaSourceTime: time, activityDuration: 100) == 10)
        #expect(try PluginDevelopmentCommand.parse(arguments: ["RunningOverlay"]) == nil)
        #expect(throws: RenderJobError.self) { try PluginDevelopmentCommand.parse(arguments: ["RunningOverlay", "--prepare-plugin-package"]) }
        #expect(throws: PluginCoreError.self) { try HeadlessBenchmarkCommand.parse(arguments: frameArguments() + ["--render-job", "job.json"]) }
        #expect(throws: PluginCoreError.self) { try PluginDevelopmentCommand.parse(arguments: frameArguments() + ["--plugin-source-value", "0"]) }
        #expect(throws: PluginCoreError.self) { try PluginDevelopmentCommand.parse(arguments: frameArguments() + ["--plugin-offset", "nan"]) }
        #expect(throws: PluginCoreError.self) { try PluginDevelopmentCommand.parse(arguments: frameArguments() + ["--plugin-template", "not-a-uuid"]) }
    }

    @Test func prepareRunsThroughHeadlessRouterAndDoesNotRenderMovies() async throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let activityURL = root.appendingPathComponent("activity.json")
        let templateURL = root.appendingPathComponent("template.rotemplate")
        try OverlayRenderJobResolver.writeActivitySnapshot(activity(), to: activityURL)
        try OverlayTemplateStore().exportTemplate(template(.heartRate), to: templateURL)
        let job = OverlayRenderJob(
            activity: .activitySnapshot(path: "activity.json"), template: .templateFile(path: "template.rotemplate"),
            output: OverlayRenderJobOutput(directory: "unused", settings: ProjectSettings()), spans: []
        )
        let jobURL = root.appendingPathComponent("job.json")
        try JSONEncoder().encode(job).write(to: jobURL)
        let output = root.appendingPathComponent("run.roplugin")
        let command = try #require(try HeadlessBenchmarkCommand.parse(arguments: ["RunningOverlay", "--prepare-plugin-package", jobURL.path, "--plugin-output", output.path]))
        guard case .pluginDevelopment(let pluginCommand) = command else {
            Issue.record("Expected plugin headless command")
            return
        }
        #expect(try await PluginDevelopmentRunner.run(pluginCommand) == output)
        try FileManager.default.removeItem(at: activityURL)
        try FileManager.default.removeItem(at: templateURL)
        #expect(try PluginDataPackageService.resolve(PluginDataPackageService.load(from: output)).activity.duration > 0)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("unused").path))
    }

    @Test func sequenceParserPreservesRationalRequestOrderAndRejectsInvalidLists() throws {
        var arguments = frameArguments().map { value in
            switch value {
            case "--plugin-frame": "--plugin-frames"
            case "--plugin-source-value": "--plugin-source-values"
            case "300": "30,90,30,-1"
            default: value
            }
        }
        let command = try #require(try PluginDevelopmentCommand.parse(arguments: arguments))
        guard case .sequence(_, _, _, let times, _) = command else {
            Issue.record("Expected sequence command")
            return
        }
        #expect(times.map(\.value) == [30, 90, 30, -1])
        #expect(times.allSatisfy { $0.timescale == 30 })
        #expect(throws: PluginCoreError.self) {
            try PluginDevelopmentCommand.parse(arguments: arguments + ["--plugin-frame", "other.roplugin"])
        }
        let valuesIndex = try #require(arguments.firstIndex(of: "--plugin-source-values")) + 1
        for invalid in ["30,", "1,,2", "nan", String(repeating: "1,", count: 256) + "1"] {
            arguments[valuesIndex] = invalid
            #expect(throws: PluginCoreError.self) { try PluginDevelopmentCommand.parse(arguments: arguments) }
        }
    }

    @Test func outsideActivityDoesNotProduceAClampedFrame() async throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let packageURL = root.appendingPathComponent("run.roplugin")
        let output = root.appendingPathComponent("outside.png")
        try PluginDataPackageService.write(makePackage(), to: packageURL)
        let mapping = try PluginTimeMapping(mediaSourceAnchor: PluginMediaTime(value: 0, timescale: 30), activityElapsedAnchor: -2)
        await #expect(throws: PluginCoreError.self) {
            try await PluginDevelopmentRunner.run(.frame(packageURL: packageURL, outputURL: output, templateID: nil, sourceTime: PluginMediaTime(value: 0, timescale: 30), mapping: mapping))
        }
        #expect(!FileManager.default.fileExists(atPath: output.path))
    }

    #if !canImport(CSkiaBridge)
    @Test func sdkFreeFrameProbeFailsWithoutUsingSwiftUIFallback() async throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let packageURL = root.appendingPathComponent("run.roplugin")
        let output = root.appendingPathComponent("frame.png")
        try PluginDataPackageService.write(makePackage(), to: packageURL)
        let mapping = try PluginTimeMapping(mediaSourceAnchor: PluginMediaTime(value: 0, timescale: 30), activityElapsedAnchor: 0)
        await #expect(throws: OverlayRendererBackendError.self) {
            try await PluginDevelopmentRunner.run(.frame(packageURL: packageURL, outputURL: output, templateID: nil, sourceTime: PluginMediaTime(value: 0, timescale: 30), mapping: mapping))
        }
        #expect(!FileManager.default.fileExists(atPath: output.path))
        let sequenceOutput = root.appendingPathComponent("frames")
        await #expect(throws: OverlayRendererBackendError.self) {
            try await PluginDevelopmentRunner.run(.sequence(packageURL: packageURL, outputDirectory: sequenceOutput, templateID: nil, sourceTimes: [PluginMediaTime(value: 0, timescale: 30)], mapping: mapping))
        }
        #expect(!FileManager.default.fileExists(atPath: sequenceOutput.path))
    }
    #endif

    #if canImport(CSkiaBridge)
    @Test func pluginFramesMatchDirectSkiaFramesAcrossSeekAndCorrection() async throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let package = try makePackage()
        let packageURL = root.appendingPathComponent("run.roplugin")
        try PluginDataPackageService.write(package, to: packageURL)
        let input = try PluginDataPackageService.resolve(package)
        let mapping = try PluginTimeMapping(mediaSourceAnchor: PluginMediaTime(value: 30, timescale: 30), activityElapsedAnchor: 1, correctionSeconds: 0.5)
        var images: [Int: Data] = [:]
        for (index, frame) in [30, 90, 30, 60].enumerated() {
            let output = root.appendingPathComponent("plugin-\(index).png")
            let expected = root.appendingPathComponent("direct-\(index).png")
            let source = try PluginMediaTime(value: Int64(frame), timescale: 30)
            let elapsed = try #require(try mapping.activityElapsedTime(forMediaSourceTime: source, activityDuration: input.activity.duration))
            _ = try await PluginDevelopmentRunner.run(.frame(packageURL: packageURL, outputURL: output, templateID: nil, sourceTime: source, mapping: mapping))
            try await SwiftUIOverlayVideoExporter.exportFramePNG(overlayLayout: input.template.layout, activity: input.activity, elapsedTime: elapsed, size: CGSize(width: 640, height: 360), outputURL: expected, backend: .skia)
            let actual = try bitmapBytes(output)
            #expect(actual == (try bitmapBytes(expected)))
            if let previous = images[frame] { #expect(previous == actual) }
            images[frame] = actual
        }
        #expect(images[30] != images[90])
    }

    private func bitmapBytes(_ url: URL) throws -> Data {
        let image = try #require(NSBitmapImageRep(data: Data(contentsOf: url)))
        let bytes = try #require(image.bitmapData)
        #expect(image.pixelsWide == 640 && image.pixelsHigh == 360)
        let data = Data(bytes: bytes, count: image.bytesPerRow * image.pixelsHigh)
        #expect(data.contains { $0 != 0 })
        return data
    }
    #endif

    private func makePackage() throws -> PluginDataPackage {
        try PluginDataPackageService.make(activity: activity(), templates: [template(.elapsedTime)], canvasWidth: 640, canvasHeight: 360)
    }

    private func activity() throws -> ActivityTimeline {
        let fixture = try #require(Bundle.module.url(forResource: "synthetic-run", withExtension: "fit", subdirectory: "Fixtures/Activities"))
        var activity = try ActivityFileParser.parse(url: fixture)
        activity.startDate = activity.startDate.addingTimeInterval(0.125)
        for index in activity.records.indices {
            activity.records[index].timestamp = activity.records[index].timestamp.addingTimeInterval(0.125)
        }
        return activity
    }

    private func template(_ type: OverlayElementType) -> OverlayTemplate {
        var style = OverlayStyle.default
        style.fontName = "Menlo"
        style.fontSize = 60
        return OverlayTemplate(name: type.rawValue, elements: [OverlayTemplateElement(type: type, positionX: 0.1, positionY: 0.2, scale: 1, style: style)])
    }

    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PluginTests-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func frameArguments() -> [String] {
        ["RunningOverlay", "--plugin-frame", "run.roplugin", "--plugin-output", "frame.png", "--plugin-source-value", "300", "--plugin-source-timescale", "30", "--plugin-anchor-value", "0", "--plugin-anchor-timescale", "30", "--plugin-activity-anchor", "0"]
    }
}
