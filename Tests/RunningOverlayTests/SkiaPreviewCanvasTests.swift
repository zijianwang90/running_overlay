#if DEBUG && canImport(CSkiaBridge)
import AppKit
import CoreGraphics
import Foundation
import Metal
import QuartzCore
import Testing
@testable import RunningOverlay

/// Phase A preview-host tests: prove the Easy Run template reaches a real
/// `CAMetalDrawable` through `SkiaEasyRunRenderer` and measure frame pacing at
/// 1080p and 4K.
@MainActor
@Suite(.serialized) struct SkiaPreviewCanvasTests {
    // MARK: - Presentation

    @Test func drawablePresentationProducesFrames() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            Issue.record("No Metal device available")
            return
        }

        let view = try Self.makeView(size: Self.hd1080)
        // `configure` renders one frame while paused.
        let baseline = view.presentedFrameCount
        var sizes = Set<CGSize>()
        for _ in 0..<10 {
            let stats = try #require(view.renderFrame())
            sizes.insert(stats.drawableSize)
        }

        #expect(view.presentedFrameCount == baseline + 10)
        #expect(sizes == [Self.hd1080])
    }

    @Test func drawableFrameContainsRenderedPixels1080p() throws {
        try Self.expectRenderedPixels(size: Self.hd1080)
    }

    @Test func drawableFrameContainsRenderedPixels4K() throws {
        try Self.expectRenderedPixels(size: Self.uhd4K)
    }

    // MARK: - Frame pacing

    @Test func framePacing1080p() throws {
        try Self.measurePacing(size: Self.hd1080, frames: 60)
    }

    @Test func framePacing4K() throws {
        try Self.measurePacing(size: Self.uhd4K, frames: 30)
    }

    // MARK: - Layer configuration

    @Test func layerIsTransparentAndDrawableSized() throws {
        let view = SkiaPreviewMetalView(frame: CGRect(x: 0, y: 0, width: 480, height: 270))

        #expect(view.metalLayer.isOpaque == false)
        #expect(view.metalLayer.pixelFormat == .bgra8Unorm)
        #expect(view.metalLayer.framebufferOnly == false)
        #expect(view.metalLayer.drawableSize == Self.hd1080)
    }

    // MARK: - SwiftUI fallback boundary

    /// Skia preview keeps SwiftUI views only for modules the renderer has not
    /// ported. This pins the current boundary so a module port cannot silently
    /// double-draw or disappear from preview.
    @Test func skiaPreviewKeepsSwiftUIFallbackOnlyForUnportedModules() {
        let expectedFallback: Set<OverlayElementType> = [
            .elevationChart,
            .intervalHUDBar,
            .intervalWorkSummary,
        ]

        for type in OverlayElementType.allCases {
            let element = OverlayElement(
                type: type,
                position: CGPoint(x: 0.5, y: 0.5),
                scale: 1,
                style: .default
            )
            #expect(
                PreviewSwiftUIFallback.isRequired(for: element) == expectedFallback.contains(type),
                "\(type.rawValue): port it to Skia or update the fallback set"
            )
        }
    }

    /// The shared preview/export renderer must actually dispatch the ported
    /// modules, not merely report support for them.
    @Test func sharedRendererDrawsPortedModules() throws {
        let types: [OverlayElementType] = [
            .heartRate,
            .decorSolidColor,
            .distanceTimeline,
            .runningGauge,
            .routeMap,
            .weatherWidget,
            .intervalTimeline,
            .intervalCountdown,
            .zoneEdgeBar,
        ]

        for type in types {
            let element = OverlayElement(
                type: type,
                position: CGPoint(x: 0.5, y: 0.5),
                scale: 1,
                style: .default
            )
            #expect(SkiaEasyRunRenderer.supports(element), "\(type.rawValue) not dispatched")

            let renderer = try #require(SkiaEasyRunRenderer(size: Self.hd1080))
            let layout = OverlayLayout(elements: [element])
            let (pixels, rowBytes) = renderer.render(
                layout: layout,
                activity: Self.activity,
                elapsedTime: 12
            )

            var nonEmptySamples = 0
            makeSampleLoop: for y in stride(from: 0, to: Int(Self.hd1080.height), by: 16) {
                for x in stride(from: 0, to: Int(Self.hd1080.width), by: 16) {
                    let alpha = pixels[y * rowBytes + x * 4 + 3]
                    if alpha > 0 {
                        nonEmptySamples += 1
                        break makeSampleLoop
                    }
                }
            }
            #expect(nonEmptySamples > 0, "\(type.rawValue) drew no pixels")
        }
    }

    // MARK: - Display link

    @Test func displayLinkDrivesFramesInAWindow() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            Issue.record("No Metal device available")
            return
        }

        _ = NSApplication.shared
        let view = SkiaPreviewMetalView(frame: CGRect(x: 0, y: 0, width: 480, height: 270))
        view.configure(
            layout: try Self.easyRunLayout(),
            activity: Self.activity,
            elapsedTime: 12,
            canvasSize: Self.hd1080,
            isPaused: false
        )

        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 480, height: 270),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = view
        window.alphaValue = 0
        window.ignoresMouseEvents = true
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }

        let deadline = Date().addingTimeInterval(1.0)
        while Date() < deadline && view.presentedFrameCount < 3 {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }

        #expect(view.presentedFrameCount >= 3)
    }

    // MARK: - Helpers

    private static let hd1080 = CGSize(width: 1920, height: 1080)
    private static let uhd4K = CGSize(width: 3840, height: 2160)

    private static func makeView(size: CGSize) throws -> SkiaPreviewMetalView {
        let view = SkiaPreviewMetalView(frame: CGRect(x: 0, y: 0, width: 480, height: 270))
        view.configure(
            layout: try easyRunLayout(),
            activity: activity,
            elapsedTime: 12,
            canvasSize: size,
            isPaused: true
        )
        return view
    }

    private static func expectRenderedPixels(size: CGSize) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            Issue.record("No Metal device available")
            return
        }

        let view = try makeView(size: size)
        let width = Int(size.width)
        let height = Int(size.height)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        let texture = try #require(device.makeTexture(descriptor: descriptor))

        #expect(view.renderIntoTexture(texture))

        let rowBytes = width * 4
        var pixels = [UInt8](repeating: 0, count: rowBytes * height)
        texture.getBytes(
            &pixels,
            bytesPerRow: rowBytes,
            from: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0
        )

        // Premultiplied BGRA: the alpha byte is at offset 3. The Easy Run
        // template must paint a meaningful number of non-transparent pixels.
        let opaquePixels = stride(from: 3, to: pixels.count, by: 4)
            .reduce(into: 0) { count, index in
                if pixels[index] > 8 { count += 1 }
            }
        #expect(opaquePixels > 1_000)
    }

    private static func measurePacing(size: CGSize, frames: Int) throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            Issue.record("No Metal device available")
            return
        }

        let view = try makeView(size: size)
        for _ in 0..<5 {
            _ = view.renderFrame()
        }
        view.waitForGPU()

        var stats: [SkiaPreviewFrameStats] = []
        let totalStart = CACurrentMediaTime()
        for _ in 0..<frames {
            autoreleasepool {
                if let frame = view.renderFrame() {
                    stats.append(frame)
                }
            }
        }
        view.waitForGPU()
        let totalSeconds = CACurrentMediaTime() - totalStart

        let count = max(stats.count, 1)
        let averageCPU = stats.map(\.cpuMilliseconds).reduce(0, +) / Double(count)
        let maxCPU = stats.map(\.cpuMilliseconds).max() ?? 0
        let averageTotal = totalSeconds / Double(frames) * 1000
        let achievedFPS = Double(frames) / totalSeconds

        print(
            "SKIA-PREVIEW-PACING \(Int(size.width))x\(Int(size.height)) "
                + "frames=\(frames) "
                + "avgCPU=\(Self.fmt(averageCPU))ms "
                + "maxCPU=\(Self.fmt(maxCPU))ms "
                + "avgTotal=\(Self.fmt(averageTotal))ms "
                + "fps=\(Self.fmt(achievedFPS))"
        )

        #expect(stats.count == frames)
        // Generous ceiling: catches a hung or accidentally synchronous host
        // without failing when other agents/CI jobs saturate the GPU. Run with
        // `SKIA_PREVIEW_STRICT_PACING=1` on an idle machine for the 30 fps gate
        // (`averageTotal` includes the nextDrawable wait).
        #expect(averageCPU < 250)
        if ProcessInfo.processInfo.environment["SKIA_PREVIEW_STRICT_PACING"] == "1" {
            #expect(averageCPU < 33.3)
            #expect(averageTotal < 33.3)
            #expect(achievedFPS >= 30)
        }
    }

    private static func easyRunLayout() throws -> OverlayLayout {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/RunningOverlay/Resources/Templates/EasyRun.rotemplate")
        let template = try JSONDecoder().decode(OverlayTemplate.self, from: Data(contentsOf: url))
        var layout = template.layout
        layout.elements = layout.elements.filter(SkiaEasyRunRenderer.supports)
        // Keep the frame deterministic and offline; the Skia spike draws the
        // local grid when the MapKit background is disabled.
        for index in layout.elements.indices where layout.elements[index].type == .routeMap {
            layout.elements[index].style.routeMapBackgroundStyle = .none
        }
        return layout
    }

    private static let activity: ActivityTimeline = {
        let start = Date(timeIntervalSince1970: 1_735_689_600)
        let records = stride(from: 0.0, through: 60, by: 1).map { t in
            ActivityRecord(
                elapsedTime: t,
                timestamp: start.addingTimeInterval(t),
                distanceMeters: t * 3.3,
                heartRate: 130 + Int(t / 3),
                paceSecondsPerKilometer: 300,
                elevationMeters: 20 + t / 10,
                cadence: 176,
                powerWatts: 250,
                calories: t / 4,
                latitude: 40.75 + 0.0006 * sin(t / 8),
                longitude: -73.99 + 0.0008 * cos(t / 8)
            )
        }
        return ActivityTimeline(
            startDate: start,
            duration: 60,
            distanceMeters: 200,
            records: records,
            laps: []
        )
    }()

    private static func fmt(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}
#endif
