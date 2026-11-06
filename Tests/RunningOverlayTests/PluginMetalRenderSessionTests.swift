#if canImport(CSkiaBridge)
import AppKit
import Foundation
import Metal
import OverlayPluginCore
import Testing
@testable import RunningOverlay

@MainActor
@Suite(.serialized, .skiaSerialized)
struct PluginMetalRenderSessionTests {
    @Test(arguments: [SkiaGPUBackendKind.ganesh, .graphite])
    func persistentFramesMatchPreviewAndClearOutsideActivity(_ backend: SkiaGPUBackendKind) throws {
        guard enabled(backend) else { return }
        let (package, activity, layout) = try fixture()
        let device = try #require(MTLCreateSystemDefaultDevice())
        let queue = try #require(device.makeCommandQueue())
        let session = try PluginMetalRenderSession(package: package, device: device, commandQueue: queue, gpuBackend: backend)
        let preview = try #require(SkiaEasyRunRenderer(size: size, device: device, commandQueue: queue, gpuBackend: backend))
        preview.preloadAssets(layout: layout, activity: activity)
        let target = try texture(device)
        let mapping = try PluginTimeMapping(mediaSourceAnchor: PluginMediaTime(value: 300, timescale: 30), activityElapsedAnchor: 0, correctionSeconds: 0.5)
        var samples: [Int: Data] = [:]
        // All requests reuse one context and target, including outside ranges,
        // backwards seeks and a return after the transparent frame.
        for frame in [300, 450, 300, 0, 330, 999_999, 300] {
            let source = try PluginMediaTime(value: Int64(frame), timescale: 30)
            let elapsed = try session.render(into: target, mediaSourceTime: source, mapping: mapping)
            let actual = pixels(target)
            if let elapsed {
                preview.draw(layout: layout, activity: activity, elapsedTime: elapsed)
                let (base, stride) = try #require(preview.readPixels())
                #expect(stride == 640 * 4)
                let expected = Data(bytes: base, count: stride * 360)
                #expect(actual == expected)
                #expect(actual.contains { $0 != 0 })
                if let previous = samples[frame] { #expect(previous == actual) }
                samples[frame] = actual
            } else {
                #expect(actual.allSatisfy { $0 == 0 }, "Outside activity must erase the previous overlay")
            }
        }
        #expect(samples[300] != samples[450])
    }

    @Test func badTargetsAndTimesDoNotPoisonTheSession() throws {
        guard enabled(.selected) else { return }
        let (_, activity, layout) = try fixture()
        let device = try #require(MTLCreateSystemDefaultDevice())
        let queue = try #require(device.makeCommandQueue())
        let session = try SkiaMetalRenderSession(size: size, layout: layout, activity: activity, device: device, commandQueue: queue)
        let valid = try texture(device)
        try session.render(into: valid, activityElapsedTime: 1)
        let baseline = pixels(valid)
        let wrongSize = try texture(device, width: 320)
        let wrongFormat = try texture(device, format: .rgba16Float)
        let noRenderUsage = try texture(device, usage: [.shaderRead])
        for invalid in [wrongSize, wrongFormat, noRenderUsage] {
            #expect(throws: SkiaMetalSessionError.incompatibleTexture) {
                try session.render(into: invalid, activityElapsedTime: 1)
            }
        }
        for time in [Double.nan, .infinity, -.infinity] {
            #expect(throws: SkiaMetalSessionError.invalidSampleTime) {
                try session.render(into: valid, activityElapsedTime: time)
            }
        }
        #expect(pixels(valid) == baseline)
        try session.render(into: valid, activityElapsedTime: nil)
        #expect(pixels(valid).allSatisfy { $0 == 0 })
        try session.render(into: valid, activityElapsedTime: 1)
        #expect(pixels(valid) == baseline)
    }

    @Test func invalidCanvasIsRejectedBeforeRendererCreation() throws {
        guard enabled(.selected) else { return }
        let (_, activity, layout) = try fixture()
        let device = try #require(MTLCreateSystemDefaultDevice())
        let queue = try #require(device.makeCommandQueue())
        for invalid in [CGSize(width: 0, height: 360), CGSize(width: 640.5, height: 360), CGSize(width: CGFloat(Int32.max) + 1, height: 360), CGSize(width: CGFloat.infinity, height: 360)] {
            #expect(throws: SkiaMetalSessionError.invalidConfiguration) {
                try SkiaMetalRenderSession(size: invalid, layout: layout, activity: activity, device: device, commandQueue: queue)
            }
        }
    }

    @Test func hostTextureIsNotHeldByPersistentSession() throws {
        guard enabled(.selected) else { return }
        let (package, _, _) = try fixture()
        let device = try #require(MTLCreateSystemDefaultDevice())
        let queue = try #require(device.makeCommandQueue())
        let session = try PluginMetalRenderSession(package: package, device: device, commandQueue: queue)
        let mapping = try PluginTimeMapping(mediaSourceAnchor: PluginMediaTime(value: 0, timescale: 30), activityElapsedAnchor: 0)
        weak var borrowed: AnyObject?
        try autoreleasepool {
            let target = try texture(device)
            borrowed = target as AnyObject
            try session.render(into: target, mediaSourceTime: PluginMediaTime(value: 30, timescale: 30), mapping: mapping)
        }
        #expect(borrowed == nil, "A completed frame must detach its borrowed target")
        let next = try texture(device)
        try session.render(into: next, mediaSourceTime: PluginMediaTime(value: 60, timescale: 30), mapping: mapping)
        #expect(pixels(next).contains { $0 != 0 })
    }

    @Test func backgroundConcurrentRequestsAreSerializedWithoutMainActorHop() async throws {
        guard enabled(.selected) else { return }
        let (package, _, _) = try fixture()
        let device = try #require(MTLCreateSystemDefaultDevice())
        let queue = try #require(device.makeCommandQueue())
        let session = try PluginMetalRenderSession(package: package, device: device, commandQueue: queue)
        let mapping = try PluginTimeMapping(mediaSourceAnchor: PluginMediaTime(value: 0, timescale: 30), activityElapsedAnchor: 0)
        let frames = [90, 30, 0, 150, 30, 90]
        var expected: [Int: Data] = [:]
        for frame in Set(frames) {
            let target = try texture(device)
            try session.render(into: target, mediaSourceTime: PluginMediaTime(value: Int64(frame), timescale: 30), mapping: mapping)
            expected[frame] = pixels(target)
        }
        // Concurrent calls use distinct caller-owned textures. Each task reads
        // only its own target after the synchronous render call returns.
        let work = try frames.map { frame in (frame, Target(texture: try texture(device))) }
        try await withThrowingTaskGroup(of: (Int, Data).self) { group in
            for (frame, target) in work {
                group.addTask {
                    try session.render(into: target.texture, mediaSourceTime: PluginMediaTime(value: Int64(frame), timescale: 30), mapping: mapping)
                    return (frame, Self.readPixels(target.texture))
                }
            }
            for try await (frame, actual) in group { #expect(actual == expected[frame]) }
        }
    }

    @Test func sequenceCommandUsesOneSessionAndPreservesRequestOrder() async throws {
        guard enabled(.selected) else { return }
        let (package, _, _) = try fixture()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PluginSequence-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("activity.roplugin")
        try PluginDataPackageService.write(package, to: input)
        let output = directory.appendingPathComponent("frames")
        let command = try #require(try PluginDevelopmentCommand.parse(arguments: [
            "RunningOverlay", "--plugin-frames", input.path, "--plugin-output", output.path,
            "--plugin-source-values", "30,150,30,-1", "--plugin-source-timescale", "30",
            "--plugin-anchor-value", "0", "--plugin-anchor-timescale", "30", "--plugin-activity-anchor", "0"
        ]))
        #expect(try await PluginDevelopmentRunner.run(command) == output)
        let first = try Data(contentsOf: output.appendingPathComponent("frame-000.png"))
        #expect(first == (try Data(contentsOf: output.appendingPathComponent("frame-002.png"))))
        #expect(first != (try Data(contentsOf: output.appendingPathComponent("frame-001.png"))))
        let transparent = try #require(NSBitmapImageRep(data: Data(contentsOf: output.appendingPathComponent("frame-003.png"))))
        #expect(transparent.colorAt(x: 64, y: 100)?.alphaComponent == 0)
        await #expect(throws: PluginCoreError.self) { try await PluginDevelopmentRunner.run(command) }
    }

    @Test func concurrentInstancesKeepTemplateAndContextStateSeparate() async throws {
        guard enabled(.selected) else { return }
        let (_, activity, layout) = try fixture()
        let first = OverlayTemplate(name: "Time", layout: layout)
        var second = OverlayTemplate(name: "Heart Rate", layout: layout)
        second.elements[0].type = .heartRate
        let package = try PluginDataPackageService.make(activity: activity, templates: [first, second], canvasWidth: 640, canvasHeight: 360)
        let device = try #require(MTLCreateSystemDefaultDevice())
        let firstSession = try PluginMetalRenderSession(package: package, templateID: first.id, device: device, commandQueue: #require(device.makeCommandQueue()))
        let secondSession = try PluginMetalRenderSession(package: package, templateID: second.id, device: device, commandQueue: #require(device.makeCommandQueue()))
        let mapping = try PluginTimeMapping(mediaSourceAnchor: PluginMediaTime(value: 0, timescale: 30), activityElapsedAnchor: 0)
        let source = try PluginMediaTime(value: 120, timescale: 30)
        let firstTarget = Target(texture: try texture(device))
        let secondTarget = Target(texture: try texture(device))
        try firstSession.render(into: firstTarget.texture, mediaSourceTime: source, mapping: mapping)
        try secondSession.render(into: secondTarget.texture, mediaSourceTime: source, mapping: mapping)
        let firstPixels = pixels(firstTarget.texture)
        let secondPixels = pixels(secondTarget.texture)
        #expect(firstPixels != secondPixels)
        try await withThrowingTaskGroup(of: Bool.self) { group in
            for (session, target, expected) in [(firstSession, firstTarget, firstPixels), (secondSession, secondTarget, secondPixels)] {
                group.addTask {
                    for _ in 0..<4 {
                        try session.render(into: target.texture, mediaSourceTime: source, mapping: mapping)
                        guard Self.readPixels(target.texture) == expected else { return false }
                    }
                    return true
                }
            }
            for try await matches in group { #expect(matches) }
        }
    }

    private var size: CGSize { CGSize(width: 640, height: 360) }

    private func enabled(_ backend: SkiaGPUBackendKind) -> Bool {
        ProcessInfo.processInfo.environment["SKIA_GPU"] == "1"
            && (backend != .graphite || SkiaGPUBackendKind.defaultBackend == .graphite)
    }

    private func fixture() throws -> (PluginDataPackage, ActivityTimeline, OverlayLayout) {
        let activity = SkiaFullCompositionGoldenTests.workout()
        var style = OverlayStyle.default
        style.fontName = "Menlo"
        style.fontSize = 70
        let template = OverlayTemplate(name: "Session Metrics", elements: [
            OverlayTemplateElement(type: .elapsedTime, positionX: 0.1, positionY: 0.25, scale: 1, style: style)
        ])
        let package = try PluginDataPackageService.make(activity: activity, templates: [template], canvasWidth: 640, canvasHeight: 360)
        return (package, activity, template.layout)
    }

    private func texture(_ device: any MTLDevice, width: Int = 640, format: MTLPixelFormat = .bgra8Unorm, usage: MTLTextureUsage = [.renderTarget, .shaderRead]) throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: 360, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = usage
        return try #require(device.makeTexture(descriptor: descriptor))
    }

    private struct Target: @unchecked Sendable { let texture: any MTLTexture }

    private func pixels(_ texture: any MTLTexture) -> Data { Self.readPixels(texture) }

    nonisolated private static func readPixels(_ texture: any MTLTexture) -> Data {
        var data = Data(count: texture.width * texture.height * 4)
        data.withUnsafeMutableBytes { bytes in
            texture.getBytes(bytes.baseAddress!, bytesPerRow: texture.width * 4, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        }
        return data
    }
}
#endif
