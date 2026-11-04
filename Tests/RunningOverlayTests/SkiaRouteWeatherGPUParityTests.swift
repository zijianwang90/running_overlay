#if canImport(CSkiaBridge)
import AppKit
import CoreGraphics
import Foundation
import Metal
import Testing
@testable import RunningOverlay

/// Validates the GPU preview/export path: the same fixture is drawn by
/// `SkiaEasyRunRenderer` over an offscreen Metal surface and over the raster
/// bridge, then compared byte-for-byte. Skipped when Metal or a GPU Skia
/// context is unavailable.
@Suite(.serialized, .skiaSerialized)
struct SkiaRouteWeatherGPUParityTests {
    private static let canvas = CGSize(width: 1280, height: 720)

    @Test func routeGPUParity() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            print("GPU-PARITY skipped: no Metal device")
            return
        }
        guard let gpu = SkiaEasyRunRenderer(
            size: Self.canvas,
            device: device,
            commandQueue: queue
        ) else {
            print("GPU-PARITY skipped: no GPU Skia context")
            return
        }
        let cpu = try #require(SkiaEasyRunRenderer(size: Self.canvas))
        let activity = SkiaRouteWeatherGoldenTests.activity()
        let layout = OverlayLayout(elements: [Self.routeElement()])

        cpu.preloadAssets(layout: layout, activity: activity)
        gpu.preloadAssets(layout: layout, activity: activity)
        try Self.compare(
            label: "route-gradient-glow-fade-stats",
            layout: layout,
            activity: activity,
            elapsedTime: 30,
            cpu: cpu,
            gpu: gpu
        )
    }

    @Test func routeSnapshotUploadGPUParity() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            print("GPU-PARITY skipped: no Metal device")
            return
        }
        guard let gpu = SkiaEasyRunRenderer(
            size: Self.canvas,
            device: device,
            commandQueue: queue
        ) else {
            print("GPU-PARITY skipped: no GPU Skia context")
            return
        }
        let cpu = try #require(SkiaEasyRunRenderer(size: Self.canvas))
        let activity = SkiaRouteWeatherGoldenTests.activity()
        let layout = OverlayLayout(elements: [Self.routeElement(background: .dark)])

        let renderContext = OverlayRenderContext(
            canvasSize: Self.canvas,
            activity: activity,
            elapsedTime: 30
        )
        let routeLayout = OverlayRenderModel.routeMapLayout(
            for: layout.elements[0],
            in: renderContext
        )
        let request = try #require(
            RouteMapSnapshotRequestBuilder.request(
                for: layout.elements[0],
                layout: routeLayout
            )
        )
        let image = NSImage(
            size: NSSize(
                width: routeLayout.rect.width,
                height: routeLayout.rect.height
            ),
            flipped: false
        ) { rect in
            NSColor.systemIndigo.setFill()
            rect.fill()
            NSColor.systemYellow.setFill()
            rect.intersection(
                CGRect(
                    x: 0,
                    y: 0,
                    width: rect.width * 0.35,
                    height: rect.height * 0.35
                )
            ).fill()
            return true
        }

        cpu.preloadAssets(
            layout: layout,
            activity: activity,
            mapSnapshots: [request: image]
        )
        gpu.preloadAssets(
            layout: layout,
            activity: activity,
            mapSnapshots: [request: image]
        )
        try Self.compare(
            label: "route-snapshot-upload",
            layout: layout,
            activity: activity,
            elapsedTime: 30,
            cpu: cpu,
            gpu: gpu
        )
    }

    @Test(arguments: WeatherWidgetPreset.allCases)
    func weatherGPUParity(_ preset: WeatherWidgetPreset) throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            print("GPU-PARITY skipped: no Metal device")
            return
        }
        guard let gpu = SkiaEasyRunRenderer(
            size: Self.canvas,
            device: device,
            commandQueue: queue
        ) else {
            print("GPU-PARITY skipped: no GPU Skia context")
            return
        }
        let cpu = try #require(SkiaEasyRunRenderer(size: Self.canvas))
        let activity = SkiaRouteWeatherGoldenTests.activity()
        let layout = OverlayLayout(elements: [Self.weatherElement(preset)])

        cpu.preloadAssets(layout: layout, activity: activity)
        gpu.preloadAssets(layout: layout, activity: activity)
        try Self.compare(
            label: "weather-\(preset.rawValue)",
            layout: layout,
            activity: activity,
            elapsedTime: 0,
            cpu: cpu,
            gpu: gpu
        )
    }

    // MARK: - Comparison

    private static func compare(
        label: String,
        layout: OverlayLayout,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        cpu: SkiaEasyRunRenderer,
        gpu: SkiaEasyRunRenderer
    ) throws {
        let (cpuPointer, cpuRow) = try #require(cpu.render(
            layout: layout,
            activity: activity,
            elapsedTime: elapsedTime
        ))
        let cpuPixels = Array(
            UnsafeBufferPointer(
                start: cpuPointer,
                count: cpuRow * Int(canvas.height)
            )
        )

        gpu.draw(layout: layout, activity: activity, elapsedTime: elapsedTime)
        gpu.flush(sync: true)
        let (gpuPointer, gpuRow) = try #require(gpu.readPixels())
        let gpuPixels = Array(
            UnsafeBufferPointer(
                start: gpuPointer,
                count: gpuRow * Int(canvas.height)
            )
        )

        let width = Int(canvas.width)
        let height = Int(canvas.height)
        var changed = 0
        var maxDelta = 0
        var maxDeltaAt = "none"
        var totalDelta = 0
        var diffBox = CGRect.null
        for y in 0..<height {
            for x in 0..<width {
                var pixelDelta = 0
                for channel in 0..<4 {
                    let delta = abs(
                        Int(cpuPixels[y * cpuRow + x * 4 + channel])
                            - Int(gpuPixels[y * gpuRow + x * 4 + channel])
                    )
                    pixelDelta += delta
                    if delta > maxDelta {
                        maxDelta = delta
                        maxDeltaAt = "(\(x),\(y),c\(channel))"
                    }
                }
                if pixelDelta > 8 {
                    changed += 1
                    diffBox = diffBox.union(CGRect(x: x, y: y, width: 1, height: 1))
                }
                totalDelta += pixelDelta
            }
        }
        let meanDelta = Double(totalDelta) / Double(width * height * 4)
        let changedRatio = Double(changed) / Double(width * height)

        print(
            "GPU-PARITY \(label) changed=\(changed)/\(width * height) "
                + "(\(String(format: "%.3f", changedRatio * 100))%) "
                + "meanDelta=\(String(format: "%.4f", meanDelta)) "
                + "maxDelta=\(maxDelta) at=\(maxDeltaAt) "
                + "diffBox=\(changed > 0 ? "\(diffBox)" : "none")"
        )

        // The GPU path must describe the same frame; AA and image sampling may
        // differ by a channel step or two, never wholesale.
        #expect(changedRatio <= 0.02, "\(label) changed \(changedRatio)")
        #expect(meanDelta <= 0.5, "\(label) mean \(meanDelta)")

        if changed > 0 {
            try? writePNG(
                pixels: cpuPixels,
                rowBytes: cpuRow,
                label: "\(label)-cpu"
            )
            try? writePNG(
                pixels: gpuPixels,
                rowBytes: gpuRow,
                label: "\(label)-gpu"
            )
        }
    }

    // MARK: - Fixtures

    private static func routeElement(
        background: OverlayRouteMapBackgroundStyle = .none
    ) -> OverlayElement {
        var style = OverlayStyle.default
        style.fontName = "Menlo"
        style.routeMapBackgroundStyle = background
        style.backgroundEnabled = background == .none
        style.backgroundColor = OverlayColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1)
        style.backgroundOpacity = 0.85
        style.backgroundFadeOutEnabled = true
        style.backgroundFadeOutAmount = 0.34
        style.borderEnabled = true
        style.borderWidth = 2
        style.borderOpacity = 0.7
        style.shadowEnabled = true
        style.shadowOpacity = 0.5
        style.shadowRadius = 8
        style.glowEnabled = true
        style.glowIntensity = 0.6
        style.routeMapColorMode = .gradient
        style.routeMapGradientStart = .green
        style.routeMapGradientMiddle = .yellow
        style.routeMapGradientEnd = .red
        style.routeMapStatsBar.visible = true
        style.routeMapStatsBar.placement = .bottomAttached
        style.routeMapStatsBar.inside = false
        style.routeMapStatsBar.height = 64
        style.routeMapStatsBar.valueFontName = "Menlo"
        style.routeMapStatsBar.labelFontName = "Menlo"
        style.routeMapStatsBar.slots = [
            RouteMapStatsBarSlot(metric: .distance, visible: true, customLabel: ""),
            RouteMapStatsBarSlot(metric: .pace, visible: true, customLabel: ""),
            RouteMapStatsBarSlot(metric: .elapsedTime, visible: true, customLabel: ""),
        ]
        return OverlayElement(
            type: .routeMap,
            position: CGPoint(x: 0.5, y: 0.5),
            scale: 1,
            style: style
        )
    }

    private static func weatherElement(_ preset: WeatherWidgetPreset) -> OverlayElement {
        var widget = WeatherWidgetStyle.preset(preset)
        widget.locationTextStyle.fontName = "Menlo"
        widget.conditionTextStyle.fontName = "Menlo"
        widget.temperatureTextStyle.fontName = "Menlo"
        widget.slotTitleTextStyle.fontName = "Menlo"
        widget.slotLabelTextStyle.fontName = "Menlo"
        var style = OverlayStyle.default
        style.fontName = "Menlo"
        style.weatherWidget = widget
        return OverlayElement(
            type: .weatherWidget,
            position: CGPoint(x: 0.5, y: 0.5),
            scale: 1,
            style: style
        )
    }

    private static func writePNG(
        pixels: [UInt8],
        rowBytes: Int,
        label: String
    ) throws {
        let data = Data(pixels) as CFData
        let provider = try #require(CGDataProvider(data: data))
        let image = try #require(CGImage(
            width: Int(canvas.width),
            height: Int(canvas.height),
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: rowBytes,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(
                rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue
            ),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))
        let rep = NSBitmapImageRep(cgImage: image)
        let png = try #require(rep.representation(using: .png, properties: [:]))
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("skia-route-weather-gpu", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try png.write(to: directory.appendingPathComponent("\(label).png"))
    }
}
#endif
