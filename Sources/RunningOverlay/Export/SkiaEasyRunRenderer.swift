#if canImport(CSkiaBridge)
import AppKit
import CSkiaBridge
import CoreText
import Foundation
import Metal

/// Spike: draws the minimal-preset text elements of a template with Skia so the output can be
/// compared with `SwiftUIOverlayVideoExporter`. See ADR 0009.
enum SkiaGPUBackendKind: String, Sendable {
    case ganesh
    case graphite

    static var defaultBackend: Self {
        skb_graphite_available() != 0 ? .graphite : .ganesh
    }

    static var selected: Self {
        if let raw = ProcessInfo.processInfo.environment["RUNNING_OVERLAY_SKIA_BACKEND"],
           let backend = Self(rawValue: raw) { return backend }
        return defaultBackend
    }
}

final class SkiaEasyRunRenderer {
    private let context: OpaquePointer
    let size: CGSize
    private let metalDevice: MTLDevice?
    private let metalCommandQueue: MTLCommandQueue?
    private var iconCache: [String: IconBitmap] = [:]
    private var fontCache: [String: NSFont] = [:]
    private let intervalMaskCache = SkiaIntervalDraw.MaskCache()
    private lazy var chartsCanvas = SkiaChartsCanvas(context: context, size: size)
    private let renderAssets = SkiaRenderAssets()
    private var assetsPrepared = false
    /// Weather the host resolved for the activity location. Host-drawn weather
    /// components read it through the render context; components never fetch.
    var weatherPayload: WeatherPayload?
    /// Preview only: lets component draws publish their measured bounds so the
    /// selection/hit-test frame query does not resolve every component twice
    /// per update. Export never publishes, so a concurrent export cannot
    /// overwrite the preview's frame cache.
    var publishesPreviewFrames = false

    /// Chart-family modules with a real Skia port. Keep this in sync as Group
    /// D/E lands each renderer; unported types stay on the SwiftUI fallback.
    private static let portedChartTypes: Set<OverlayElementType> = [
        .distanceTimeline,
        .elevationChart
    ]

    /// Interval-family modules with a real Skia port. Keep this in sync as
    /// Group I lands each renderer; unported types stay on the SwiftUI fallback.
    private static let portedIntervalTypes: Set<OverlayElementType> = [
        .intervalHUDBar,
        .intervalTimeline,
        .zoneEdgeBar
    ]

    init?(size: CGSize) {
        guard let context = skb_create(Int32(size.width), Int32(size.height)) else { return nil }
        self.context = context
        self.size = size
        self.metalDevice = nil
        self.metalCommandQueue = nil
    }

    init?(
        size: CGSize,
        device: MTLDevice,
        commandQueue: MTLCommandQueue,
        offscreen: Bool = true,
        gpuBackend: SkiaGPUBackendKind = .selected
    ) {
        let devicePointer = Unmanaged.passUnretained(device as AnyObject).toOpaque()
        let queuePointer = Unmanaged.passUnretained(commandQueue as AnyObject).toOpaque()
        let context: OpaquePointer?
        switch gpuBackend {
        case .ganesh:
            context = offscreen
                ? skb_create_gpu(Int32(size.width), Int32(size.height), devicePointer, queuePointer)
                : skb_create_gpu_context(Int32(size.width), Int32(size.height), devicePointer, queuePointer)
        case .graphite:
            context = offscreen
                ? skb_create_graphite_gpu(Int32(size.width), Int32(size.height), devicePointer, queuePointer)
                : skb_create_graphite_gpu_context(Int32(size.width), Int32(size.height), devicePointer, queuePointer)
        }
        guard let context else { return nil }
        self.context = context
        self.size = size
        self.metalDevice = device
        self.metalCommandQueue = commandQueue
    }

    deinit {
        // Drain GPU work before the context and cached image handles go away.
        skb_flush(context, 1)
        renderAssets.releaseImages()
        skb_destroy(context)
    }

    /// Preloads route snapshots and weather assets. Call when the layout,
    /// activity, or available map snapshots change; it is safe to call
    /// repeatedly. Draw never performs AppKit, MapKit, network, or async work.
    func preloadAssets(
        layout: OverlayLayout,
        activity: ActivityTimeline,
        mapSnapshots: [MapSnapshotRequest: NSImage] = [:]
    ) {
        SkiaRouteMapModule.preloadAssets(
            elements: layout.elements,
            activity: activity,
            canvasSize: size,
            mapSnapshots: mapSnapshots,
            into: renderAssets
        )
        SkiaWeatherWidgetModule.preloadAssets(
            elements: layout.elements,
            activity: activity,
            canvasSize: size,
            into: renderAssets
        )
        assetsPrepared = true
    }

    static func supports(_ element: OverlayElement) -> Bool {
        element.type == .distanceTimeline
            || element.type == .routeMap
            || element.type == .weatherWidget
            || portedChartTypes.contains(element.type)
            || portedIntervalTypes.contains(element.type)
            || element.type == .component
    }

    /// Records the draw commands without reading pixels back.
    func draw(layout: OverlayLayout, activity: ActivityTimeline, elapsedTime: TimeInterval) {
        skb_clear(context)
        if !assetsPrepared {
            preloadAssets(layout: layout, activity: activity)
        }
        let renderContext = OverlayRenderContext(
            canvasSize: size,
            activity: activity,
            elapsedTime: elapsedTime,
            renderAssets: renderAssets,
            weatherPayload: weatherPayload
        )
        for element in layout.elements where element.isVisible && Self.supports(element) {
            if element.type == .component {
                OverlayComponentSkiaRenderer.draw(
                    element,
                    renderContext: renderContext,
                    context: context,
                    publishesPreviewFrame: publishesPreviewFrames
                )
                continue
            }
            if Self.portedChartTypes.contains(element.type) {
                SkiaChartsModule.draw(
                    element,
                    renderContext: renderContext,
                    canvas: chartsCanvas
                )
                continue
            }
            if Self.portedIntervalTypes.contains(element.type) {
                SkiaIntervalModules.draw(
                    element,
                    in: renderContext,
                    skiaContext: context,
                    maskCache: intervalMaskCache
                )
                continue
            }
            switch element.type {
            case .distanceTimeline:
                drawDistanceTimeline(element, renderContext: renderContext)
            case .routeMap:
                SkiaRouteMapModule.draw(
                    element,
                    renderContext: renderContext,
                    context: context,
                    assets: renderAssets
                )
            case .weatherWidget:
                SkiaWeatherWidgetModule.draw(
                    element,
                    renderContext: renderContext,
                    context: context,
                    assets: renderAssets
                )
            default:
                // Every supported type is handled above. A new type added to
                // `supports` without a draw case must fail loudly rather than
                // silently fall back to the legacy text drawing.
                assertionFailure("Unhandled Skia overlay type: \(element.type.rawValue)")
            }
        }
    }

    /// Renders supported elements; returns premultiplied BGRA pixels (borrowed,
    /// valid until next render), or `nil` if readback fails.
    func render(layout: OverlayLayout, activity: ActivityTimeline, elapsedTime: TimeInterval) -> (UnsafePointer<UInt8>, Int)? {
        draw(layout: layout, activity: activity, elapsedTime: elapsedTime)
        var rowBytes = 0
        guard let base = skb_pixels(context, &rowBytes) else { return nil }
        return (base, rowBytes)
    }

    /// Wraps an external texture (for example a CVPixelBuffer-backed
    /// MTLTexture) as the render target. The texture must stay alive until the
    /// next flush.
    func wrap(texture: MTLTexture) -> Bool {
        skb_wrap_texture(
            context,
            Int32(size.width),
            Int32(size.height),
            Unmanaged.passUnretained(texture as AnyObject).toOpaque()
        ) != 0
    }

    /// Submits pending draw commands. `sync` waits for the GPU to finish.
    @discardableResult
    func flush(sync: Bool) -> Bool {
        skb_flush(context, sync ? 1 : 0)
        return skb_gpu_succeeded(context) != 0
    }

    /// Flushes, waits, and reads the surface back into CPU memory.
    func readPixels() -> (UnsafePointer<UInt8>, Int)? {
        var rowBytes = 0
        guard let base = skb_read_pixels(context, &rowBytes) else { return nil }
        return (base, rowBytes)
    }

    // MARK: - Route map

    private func drawRouteMap(_ element: OverlayElement, renderContext: OverlayRenderContext) {
        let layout = OverlayRenderModel.routeMapLayout(for: element, in: renderContext)
        let rect = layout.rect
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2

        beginShadowChain(element, bounds: rect, includeGlow: false)

        skb_save(context)
        if layout.shape == .circle {
            skb_clip_circle(context, Float(center.x), Float(center.y), Float(radius))
        } else {
            skb_clip_round_rect(
                context, Float(rect.minX), Float(rect.minY), Float(rect.width), Float(rect.height),
                Float(layout.cornerRadius)
            )
        }

        if element.style.routeMapBackgroundStyle != .none {
            let step = max(rect.width / 6, 18)
            var x = rect.minX + step
            while x < rect.maxX {
                skb_stroke_line(
                    context, Float(x), Float(rect.minY), Float(x), Float(rect.maxY), 1,
                    1, 1, 1, 0.08
                )
                x += step
            }
            var y = rect.minY + step
            while y < rect.maxY {
                skb_stroke_line(
                    context, Float(rect.minX), Float(y), Float(rect.maxX), Float(y), 1,
                    1, 1, 1, 0.08
                )
                y += step
            }
        }

        let points = layout.projectedPoints
        if points.isEmpty {
            let font = cachedFont(
                family: element.style.fontName,
                size: max(rect.width * 0.09, 10),
                weight: .semibold
            )
            let line = Self.makeLine("NO GPS", font: font, tracking: 0)
            drawTextLine(
                "NO GPS", font: font, tracking: 0,
                x: center.x - line.width / 2,
                top: center.y - (line.ascent + line.descent) / 2,
                color: element.style.foregroundColor,
                opacity: 0.72
            )
        } else {
            let coordinates = points.flatMap { [Float($0.x), Float($0.y)] }
            skb_stroke_polyline(
                context, coordinates, Int32(points.count), Float(layout.lineWidth + 3),
                0, 0, 0, 0.55
            )
            if layout.glowEnabled {
                skb_begin_blur_layer(
                    context, Float(layout.glowRadius),
                    Float(rect.minX), Float(rect.minY), Float(rect.width), Float(rect.height)
                )
                skb_stroke_polyline(
                    context, coordinates, Int32(points.count), Float(layout.lineWidth * 2.3),
                    Float(element.style.foregroundColor.red), Float(element.style.foregroundColor.green),
                    Float(element.style.foregroundColor.blue), 0.55
                )
                skb_restore(context)
            }
            skb_stroke_polyline(
                context, coordinates, Int32(points.count), Float(layout.lineWidth),
                Float(element.style.foregroundColor.red), Float(element.style.foregroundColor.green),
                Float(element.style.foregroundColor.blue), 1
            )

            if element.style.routeMapStartMarkerStyle != .hidden, let start = points.first {
                drawRouteMarker(start, color: element.style.routeMapStartMarkerColor, layout: layout)
            }
            if element.style.routeMapEndMarkerStyle != .hidden, let end = points.last {
                drawRouteMarker(end, color: element.style.routeMapEndMarkerColor, layout: layout)
            }
            if element.style.routeMapRunnerMarkerStyle != .hidden,
               let current = layout.projectedCurrentPoint {
                drawRouteMarker(
                    current,
                    color: element.style.routeMapRunnerDotColor,
                    layout: layout,
                    sizeMultiplier: 1.18
                )
            }
        }

        skb_restore(context)

        if element.style.borderEnabled {
            skb_stroke_round_rect(
                context, Float(rect.minX), Float(rect.minY), Float(rect.width), Float(rect.height),
                Float(rect.width / 2), Float(element.style.borderWidth * element.scale),
                Float(element.style.borderColor.red), Float(element.style.borderColor.green),
                Float(element.style.borderColor.blue), Float(element.style.borderOpacity)
            )
        }

        skb_restore(context)
    }

    private func drawRouteMarker(
        _ point: CGPoint,
        color: OverlayColor,
        layout: OverlayRouteMapRenderLayout,
        sizeMultiplier: Double = 1
    ) {
        let diameter = layout.lineWidth * 2.7 * sizeMultiplier
        skb_fill_circle(
            context, Float(point.x), Float(point.y), Float(diameter / 2),
            Float(color.red), Float(color.green), Float(color.blue), Float(color.alpha)
        )
        skb_stroke_round_rect(
            context,
            Float(point.x - diameter / 2), Float(point.y - diameter / 2),
            Float(diameter), Float(diameter), Float(diameter / 2),
            Float(max(layout.lineWidth * 0.45, 1)),
            1, 1, 1, 1
        )
    }

    // MARK: - Weather widget

    private func drawWeatherWidget(_ element: OverlayElement, renderContext: OverlayRenderContext) {
        let layout = OverlayRenderModel.weatherWidgetLayout(for: element, in: renderContext)
        let style = layout.style
        guard style.preset == .simpleCard else { return }
        let rect = layout.rect
        let scale = rect.width / max(style.width, 1)
        let cornerRadius = style.cardCornerRadius * rect.width / max(style.width, 1)
        let opacity = element.opacity

        let shadowRadius = max(4, rect.width * 0.025)
        let shadowOffsetY = max(2, rect.height * 0.04)
        skb_begin_shadow_layer(
            context, Float(shadowRadius), 0, Float(shadowOffsetY),
            Float(rect.minX), Float(rect.minY), Float(rect.width), Float(rect.height),
            0, 0, 0, Float(0.22 * opacity)
        )
        skb_fill_diagonal_gradient_round_rect(
            context,
            Float(rect.minX), Float(rect.minY), Float(rect.width), Float(rect.height),
            Float(cornerRadius),
            0.38, 0.68, 1.0, Float(style.cardBackgroundOpacity * opacity),
            0.22, 0.50, 0.92, Float(style.cardBackgroundOpacity * opacity)
        )
        let strokeWidth = max(1, rect.width / max(style.width, 1))
        skb_stroke_round_rect(
            context,
            Float(rect.minX + strokeWidth / 2), Float(rect.minY + strokeWidth / 2),
            Float(rect.width - strokeWidth), Float(rect.height - strokeWidth),
            Float(max(cornerRadius - strokeWidth / 2, 0)),
            Float(strokeWidth),
            1, 1, 1, Float(0.18 * opacity)
        )
        skb_restore(context)

        skb_save(context)
        skb_clip_round_rect(
            context, Float(rect.minX), Float(rect.minY), Float(rect.width), Float(rect.height),
            Float(cornerRadius)
        )

        let leftX = rect.minX + 18 * scale
        let leftWidth = rect.width * 0.40
        let conditionHeight = min(
            max(style.conditionTextStyle.fontSize * 1.35, 12) * scale,
            rect.height * 0.42
        )

        if style.showConditionLabel {
            let font = cachedFont(
                family: style.conditionTextStyle.fontName,
                size: style.conditionTextStyle.fontSize * scale,
                weight: Self.weight(style.conditionTextStyle.fontWeight)
            )
            let line = Self.makeLine(layout.conditionLabel, font: font, tracking: 0)
            drawTextLine(
                layout.conditionLabel, font: font, tracking: 0,
                x: leftX,
                top: rect.minY + (conditionHeight - (line.ascent + line.descent + line.leading)) / 2,
                color: style.conditionTextStyle.color,
                opacity: opacity
            )
        }

        if style.showIcon {
            let labelHeight = style.showConditionLabel ? conditionHeight : 0
            let availableHeight = max(0, rect.height - labelHeight - 6 * scale)
            let iconSide = min(58 * scale, availableHeight)
            let iconX = leftX + (leftWidth - iconSide) / 2
            let iconY = rect.minY + labelHeight + (availableHeight - iconSide) / 2
            if let icon = Self.rasterizeBundledImage(
                name: layout.condition.bundledImageName,
                pixelSize: CGSize(width: iconSide, height: iconSide)
            ) {
                skb_draw_image(
                    context, icon.pixels, Int32(icon.width), Int32(icon.height),
                    Float(iconX), Float(iconY), Float(iconSide), Float(iconSide),
                    Float(opacity), 0, 0, 0, 0
                )
            }
        }

        let leftTotal = leftWidth + 18 * scale
        let dividerWidth = max(1, style.dividerThickness * scale)
        if style.dividerEnabled {
            skb_fill_rect(
                context,
                Float(rect.minX + leftTotal), Float(rect.minY + 18 * scale),
                Float(dividerWidth), Float(rect.height - 36 * scale),
                Float(style.dividerColor.red), Float(style.dividerColor.green),
                Float(style.dividerColor.blue), Float(style.dividerOpacity * opacity)
            )
        }

        var entries: [(String, WeatherTextStyle)] = []
        if style.showLocation {
            entries.append((layout.locationText, style.locationTextStyle))
        }
        if style.showWeekday, !layout.weekdayText.isEmpty {
            entries.append((layout.weekdayText, style.slotTitleTextStyle))
        }
        entries.append((layout.temperatureFormatted, style.temperatureTextStyle))
        if let metric = layout.metricSlots.first {
            entries.append((metric.value, style.slotLabelTextStyle))
        }

        var lines: [(String, NSFont, LineData, OverlayColor)] = []
        var totalHeight = 0.0
        for (text, textStyle) in entries {
            let font = cachedFont(
                family: textStyle.fontName,
                size: textStyle.fontSize * scale,
                weight: Self.weight(textStyle.fontWeight)
            )
            let line = Self.makeLine(text, font: font, tracking: 0)
            totalHeight += line.ascent + line.descent + line.leading
            lines.append((text, font, line, textStyle.color))
        }
        totalHeight += 3 * scale * Double(max(entries.count - 1, 0))

        let rightX = rect.minX + leftTotal + dividerWidth + 16 * scale
        var top = rect.midY - totalHeight / 2
        for (text, font, line, color) in lines {
            drawTextLine(
                text, font: font, tracking: 0,
                x: rightX, top: top, color: color, opacity: opacity
            )
            top += line.ascent + line.descent + line.leading + 3 * scale
        }

        skb_restore(context)
    }

    private static func rasterizeBundledImage(name: String, pixelSize: CGSize) -> IconBitmap? {
        guard let image = IconAssetResolver.bundledImage(name: name) else { return nil }
        let width = max(Int(ceil(pixelSize.width)), 1)
        let height = max(Int(ceil(pixelSize.height)), 1)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        var rendered = false
        pixels.withUnsafeMutableBytes { raw in
            guard let bitmap = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue
            ) else { return }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: bitmap, flipped: false)
            image.draw(
                in: CGRect(x: 0, y: 0, width: width, height: height),
                from: .zero,
                operation: .sourceOver,
                fraction: 1
            )
            NSGraphicsContext.restoreGraphicsState()
            rendered = true
        }
        guard rendered else { return nil }
        return IconBitmap(
            pixels: pixels,
            width: width,
            height: height,
            size: CGSize(width: width, height: height)
        )
    }

    /// Pushes one layer whose content is composited with SwiftUI's chained shadow order.
    /// Entries are added innermost first: the first `.shadow` modifier sits closest to the
    /// content, and each later modifier draws outside the previous one.
    private func beginShadowChain(
        _ element: OverlayElement,
        bounds: CGRect,
        includeGlow: Bool,
        sigmaFactor: Double = 1.0
    ) {
        let style = element.style
        var sigmas: [Float] = []
        var dxs: [Float] = []
        var dys: [Float] = []
        var rgba: [Float] = []

        func add(
            _ sigma: Double,
            _ dx: Double,
            _ dy: Double,
            _ color: OverlayColor,
            _ alpha: Double
        ) {
            guard alpha > 0, sigma >= 0 else { return }
            sigmas.append(Float(sigma))
            dxs.append(Float(dx))
            dys.append(Float(dy))
            rgba.append(contentsOf: [
                Float(color.red), Float(color.green), Float(color.blue), Float(alpha)
            ])
        }

        if includeGlow, style.glowEnabled {
            let intensity = style.glowIntensity
            add(max(intensity * 18, 0), 0, 0, style.glowColor, intensity * 0.72)
            add(max(intensity * 34, 0), 0, 0, style.glowColor, intensity * 0.35)
        }
        if style.shadowEnabled, style.shadowOpacity > 0 {
            let radius = style.shadowRadius * sigmaFactor
            let opacity = style.shadowOpacity
            let thickness = style.shadowThickness
            add(radius, style.shadowOffsetX, style.shadowOffsetY, style.shadowColor, opacity)
            if thickness > 1 {
                add(
                    radius * 0.72, style.shadowOffsetX, style.shadowOffsetY, style.shadowColor,
                    opacity * max(thickness - 1, 0) * 0.32
                )
            }
            if thickness > 2 {
                add(
                    radius * 0.48, style.shadowOffsetX, style.shadowOffsetY, style.shadowColor,
                    opacity * max(thickness - 2, 0) * 0.22
                )
            }
        }

        guard !sigmas.isEmpty else {
            skb_save(context)
            return
        }
        sigmas.withUnsafeBufferPointer { sigmas in
            dxs.withUnsafeBufferPointer { dxs in
                dys.withUnsafeBufferPointer { dys in
                    rgba.withUnsafeBufferPointer { rgba in
                        skb_begin_shadow_chain(
                            context,
                            Int32(sigmas.count),
                            sigmas.baseAddress,
                            dxs.baseAddress,
                            dys.baseAddress,
                            rgba.baseAddress,
                            Float(bounds.minX),
                            Float(bounds.minY),
                            Float(bounds.width),
                            Float(bounds.height)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Distance timeline

    private func drawDistanceTimeline(_ element: OverlayElement, renderContext: OverlayRenderContext) {
        let layout = OverlayRenderModel.distanceTimelineLayout(for: element, in: renderContext)
        let style = layout.style
        let styleScale = layout.rect.width / max(style.width, 1)
        let foreground = element.style.foregroundColor
        let track = layout.trackRect
        let valueTop = layout.contentRect.minY + scaled(style.labelValueSpacing, scale: styleScale)
        let axisGap = max(
            style.showAxisLabels ? scaled(style.distancePointOffset, scale: styleScale) : 0,
            style.showDistancePoints ? scaled(style.midpointAxisLabelOffset, scale: styleScale) : 0
        )
        let contentTop = min(layout.rect.minY, valueTop)
        let contentBottom = max(
            layout.rect.maxY,
            track.maxY + axisGap + layout.unitFontSize * 1.3
        )
        let bounds = CGRect(
            x: layout.rect.minX,
            y: contentTop,
            width: layout.rect.width,
            height: contentBottom - contentTop
        )
        let shadowSigmaFactor = ProcessInfo.processInfo.environment["SKIA_DT_SIGMA_FACTOR"]
            .flatMap(Double.init) ?? 1.0
        // Nested layers are much faster than a chained image filter in Skia's raster backend.
        // SwiftUI applies each later shadow outside the previous one, so push the outermost
        // layer first and draw the content last.
        var layerCount = 0
        if element.style.shadowEnabled, element.style.shadowOpacity > 0 {
            let radius = element.style.shadowRadius * shadowSigmaFactor
            let opacity = element.style.shadowOpacity
            let thickness = element.style.shadowThickness
            let shadow = element.style.shadowColor
            let dx = Float(element.style.shadowOffsetX)
            let dy = Float(element.style.shadowOffsetY)
            if thickness > 2 {
                skb_begin_shadow_layer(
                    context, Float(radius * 0.48), dx, dy,
                    Float(bounds.minX), Float(bounds.minY), Float(bounds.width), Float(bounds.height),
                    Float(shadow.red), Float(shadow.green), Float(shadow.blue),
                    Float(opacity * max(thickness - 2, 0) * 0.22)
                )
                layerCount += 1
            }
            if thickness > 1 {
                skb_begin_shadow_layer(
                    context, Float(radius * 0.72), dx, dy,
                    Float(bounds.minX), Float(bounds.minY), Float(bounds.width), Float(bounds.height),
                    Float(shadow.red), Float(shadow.green), Float(shadow.blue),
                    Float(opacity * max(thickness - 1, 0) * 0.32)
                )
                layerCount += 1
            }
            skb_begin_shadow_layer(
                context, Float(radius), dx, dy,
                Float(bounds.minX), Float(bounds.minY), Float(bounds.width), Float(bounds.height),
                Float(shadow.red), Float(shadow.green), Float(shadow.blue), Float(opacity)
            )
            layerCount += 1
        }
        if element.style.glowEnabled {
            let intensity = element.style.glowIntensity
            let glow = element.style.glowColor
            skb_begin_shadow_layer(
                context, Float(max(intensity * 34, 0)), 0, 0,
                Float(bounds.minX), Float(bounds.minY), Float(bounds.width), Float(bounds.height),
                Float(glow.red), Float(glow.green), Float(glow.blue), Float(intensity * 0.35)
            )
            layerCount += 1
            skb_begin_shadow_layer(
                context, Float(max(intensity * 18, 0)), 0, 0,
                Float(bounds.minX), Float(bounds.minY), Float(bounds.width), Float(bounds.height),
                Float(glow.red), Float(glow.green), Float(glow.blue), Float(intensity * 0.72)
            )
            layerCount += 1
        }

        let valueFont = cachedFont(family: element.style.fontName, size: layout.valueFontSize, weight: .bold)
        drawTextLine(
            layout.valueText,
            font: valueFont,
            tracking: 0,
            x: layout.contentRect.minX,
            top: layout.contentRect.minY + scaled(style.labelValueSpacing, scale: styleScale),
            color: foreground,
            opacity: element.opacity
        )

        let trackRadius = track.height / 2
        skb_fill_round_rect(
            context, Float(track.minX), Float(track.minY), Float(track.width), Float(track.height),
            Float(trackRadius),
            Float(foreground.red), Float(foreground.green), Float(foreground.blue),
            Float(foreground.alpha * style.trackOpacity)
        )

        let progressWidth = max(track.width * layout.progress, track.height)
        let accent = style.fillColor
        // SwiftUI's shadow radius maps to roughly half the Gaussian sigma Skia uses for
        // the progress and marker glow.
        let glowSigmaFactor = ProcessInfo.processInfo.environment["SKIA_DT_GLOW_SIGMA_FACTOR"]
            .flatMap(Double.init) ?? 0.5
        if style.glowEnabled {
            skb_begin_shadow_layer(
                context, Float(track.height * 2.8 * glowSigmaFactor), 0, 0,
                Float(track.minX), Float(track.minY), Float(progressWidth), Float(track.height),
                Float(accent.red), Float(accent.green), Float(accent.blue), 0.75
            )
        }
        skb_fill_round_rect(
            context, Float(track.minX), Float(track.minY), Float(progressWidth), Float(track.height),
            Float(trackRadius),
            Float(accent.red), Float(accent.green), Float(accent.blue), Float(accent.alpha)
        )
        if style.glowEnabled {
            skb_restore(context)
        }

        if style.tickMarksEnabled {
            let tickCount = max(style.tickDensity, 2)
            for index in 0...tickCount {
                let x = track.minX + track.width * Double(index) / Double(tickCount)
                skb_stroke_line(
                    context,
                    Float(x), Float(track.minY - track.height * 0.45),
                    Float(x), Float(track.minY + track.height * 1.45),
                    1,
                    Float(foreground.red), Float(foreground.green), Float(foreground.blue),
                    Float(foreground.alpha * 0.64 * 0.52)
                )
            }
        }

        if style.currentMarkerEnabled {
            let markerSize = track.height * 2.2 * style.currentMarkerSizeMultiplier
            let marker = style.currentMarkerColor
            let centerX = track.minX + track.width * layout.progress
            let centerY = track.midY
            if style.glowEnabled {
                skb_begin_shadow_layer(
                    context, Float(track.height * 2.3 * glowSigmaFactor), 0, 0,
                    Float(centerX - markerSize / 2), Float(centerY - markerSize / 2),
                    Float(markerSize), Float(markerSize),
                    Float(accent.red), Float(accent.green), Float(accent.blue), 0.75
                )
            }
            skb_fill_circle(
                context,
                Float(centerX),
                Float(centerY),
                Float(markerSize / 2),
                Float(marker.red), Float(marker.green), Float(marker.blue), Float(marker.alpha)
            )
            if style.glowEnabled {
                skb_restore(context)
            }
        }

        if style.showAxisLabels || style.showDistancePoints {
            let axisFont = cachedFont(
                family: style.axisLabelFontName,
                size: layout.unitFontSize,
                weight: Self.weight(style.axisLabelFontWeight)
            )
            let textHeight = layout.unitFontSize * 1.3
            let axisColor = style.axisLabelColor
            if style.showAxisLabels {
                let top = axisLabelTop(
                    placement: style.axisEndpointLabelPlacement,
                    track: track,
                    gap: scaled(style.distancePointOffset, scale: styleScale),
                    textHeight: textHeight
                )
                drawTextLine(
                    layout.startText, font: axisFont, tracking: 0,
                    x: track.minX, top: top, color: axisColor, opacity: 1
                )
                let finishWidth = Self.measure(layout.finishText, font: axisFont, tracking: 0).width
                drawTextLine(
                    layout.finishText, font: axisFont, tracking: 0,
                    x: track.maxX - finishWidth, top: top, color: axisColor, opacity: 1
                )
            }
            if style.showDistancePoints, !layout.distancePointLabels.isEmpty {
                let top = axisLabelTop(
                    placement: style.axisMidpointLabelPlacement,
                    track: track,
                    gap: scaled(style.midpointAxisLabelOffset, scale: styleScale),
                    textHeight: textHeight
                )
                let denominator = Double(layout.distancePointLabels.count + 1)
                for (index, label) in layout.distancePointLabels.enumerated() {
                    let centerX = track.minX + track.width * Double(index + 1) / denominator
                    let width = Self.measure(label, font: axisFont, tracking: 0).width
                    drawTextLine(
                        label, font: axisFont, tracking: 0,
                        x: centerX - width / 2, top: top, color: axisColor, opacity: 1
                    )
                }
            }
        }

        for _ in 0..<layerCount {
            skb_restore(context)
        }
    }

    private func axisLabelTop(
        placement: DistanceTimelineAxisLabelTrackPlacement,
        track: CGRect,
        gap: Double,
        textHeight: Double
    ) -> Double {
        switch placement {
        case .below: track.maxY + gap
        case .above: track.minY - gap - textHeight
        }
    }

    private func scaled(_ value: Double, scale: Double) -> Double {
        value * scale
    }

    private func drawTextLine(
        _ text: String,
        font: NSFont,
        tracking: Double,
        x: Double,
        top: Double,
        color: OverlayColor,
        opacity: Double
    ) {
        let line = Self.makeLine(text, font: font, tracking: tracking)
        drawGlyphs(
            line,
            font: font,
            x: x,
            baselineY: top + line.ascent,
            color: color,
            opacity: opacity,
            shadow: ShadowParameters(sigma: 0, offsetX: 0, offsetY: 0, alpha: 0)
        )
    }

    private static func measure(_ text: String, font: NSFont, tracking: Double) -> LineData {
        makeLine(text, font: font, tracking: tracking)
    }

    // MARK: - Drawing

    private struct ShadowParameters {
        var sigma: Double
        var offsetX: Double
        var offsetY: Double
        var alpha: Double
    }

    private func drawGlyphs(
        _ line: LineData,
        font: NSFont,
        x: Double,
        baselineY: Double,
        color: OverlayColor,
        opacity: Double,
        shadow: ShadowParameters
    ) {
        guard !line.glyphs.isEmpty else { return }
        line.glyphs.withUnsafeBufferPointer { glyphs in
            line.xPositions.withUnsafeBufferPointer { positions in
                skb_draw_glyphs(
                    context,
                    Unmanaged.passUnretained(font).toOpaque(),
                    glyphs.baseAddress,
                    positions.baseAddress,
                    Int32(line.glyphs.count),
                    Float(x),
                    Float(baselineY),
                    Float(color.red),
                    Float(color.green),
                    Float(color.blue),
                    Float(color.alpha * opacity),
                    Float(shadow.sigma),
                    Float(shadow.offsetX),
                    Float(shadow.offsetY),
                    Float(shadow.alpha)
                )
            }
        }
    }

    private struct IconBitmap {
        var pixels: [UInt8]
        var width: Int
        var height: Int
        var size: CGSize
    }

    private func drawIcon(
        name: String,
        rect: CGRect,
        color: OverlayColor,
        opacity: Double,
        shadow: ShadowParameters
    ) {
        let pointSize = rect.width
        let key = "\(name)|\(pointSize)|\(color.red),\(color.green),\(color.blue)"
        let bitmap: IconBitmap
        if let cached = iconCache[key] {
            bitmap = cached
        } else {
            guard let rendered = Self.rasterizeIcon(name: name, pointSize: pointSize, color: color) else {
                return
            }
            iconCache[key] = rendered
            bitmap = rendered
        }
        let drawX = rect.midX - bitmap.size.width / 2
        let drawY = rect.midY - bitmap.size.height / 2
        bitmap.pixels.withUnsafeBufferPointer { buffer in
            skb_draw_image(
                context,
                buffer.baseAddress,
                Int32(bitmap.width),
                Int32(bitmap.height),
                Float(drawX),
                Float(drawY),
                Float(bitmap.size.width),
                Float(bitmap.size.height),
                Float(opacity),
                Float(shadow.sigma),
                Float(shadow.offsetX),
                Float(shadow.offsetY),
                Float(shadow.alpha)
            )
        }
    }

    private static func rasterizeIcon(
        name: String,
        pointSize: Double,
        color: OverlayColor
    ) -> IconBitmap? {
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else { return nil }
        let tinted = NSImage(size: base.size, flipped: false) { drawRect in
            NSColor(
                red: color.red,
                green: color.green,
                blue: color.blue,
                alpha: 1
            ).set()
            drawRect.fill()
            base.draw(in: drawRect, from: .zero, operation: .destinationIn, fraction: 1)
            return true
        }
        let width = max(Int(ceil(base.size.width)), 1)
        let height = max(Int(ceil(base.size.height)), 1)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { raw in
            guard let bitmap = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue
            ) else { return }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: bitmap, flipped: false)
            tinted.draw(in: CGRect(x: 0, y: 0, width: base.size.width, height: base.size.height))
            NSGraphicsContext.restoreGraphicsState()
        }
        return IconBitmap(pixels: pixels, width: width, height: height, size: base.size)
    }

    private func cachedFont(family: String, size: Double, weight: NSFont.Weight) -> NSFont {
        let key = "\(family)|\(size)|\(weight.rawValue)"
        if let cached = fontCache[key] {
            return cached
        }
        let font = OverlayFontResolver.appKitFont(family: family, size: size, weight: weight)
        fontCache[key] = font
        return font
    }

    // MARK: - Layout helpers

    private struct LineData {
        var glyphs: [CGGlyph]
        var xPositions: [Float]
        var width: Double
        var ascent: Double
        var descent: Double
        var leading: Double
    }

    private static func makeLine(_ text: String, font: NSFont, tracking: Double) -> LineData {
        var attributes: [NSAttributedString.Key: Any] = [.font: font]
        if tracking != 0 {
            attributes[.kern] = tracking
        }
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: attributes)
        )
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)

        var glyphs: [CGGlyph] = []
        var xPositions: [Float] = []
        if let runs = CTLineGetGlyphRuns(line) as? [CTRun] {
            for run in runs {
                let count = CTRunGetGlyphCount(run)
                guard count > 0 else { continue }
                var runGlyphs = [CGGlyph](repeating: 0, count: count)
                var runPositions = [CGPoint](repeating: .zero, count: count)
                let range = CFRange(location: 0, length: count)
                CTRunGetGlyphs(run, range, &runGlyphs)
                CTRunGetPositions(run, range, &runPositions)
                glyphs.append(contentsOf: runGlyphs)
                xPositions.append(contentsOf: runPositions.map { Float($0.x) })
            }
        }
        return LineData(
            glyphs: glyphs,
            xPositions: xPositions,
            width: width,
            ascent: ascent,
            descent: descent,
            leading: leading
        )
    }

    private func resolvedColor(
        _ color: OverlayColor,
        followsZones: Bool,
        base: OverlayColor?
    ) -> OverlayColor {
        if followsZones, let base {
            return base
        }
        return color
    }

    private static func weight(_ weight: OverlayFontWeight) -> NSFont.Weight {
        switch weight {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }
}
#endif
