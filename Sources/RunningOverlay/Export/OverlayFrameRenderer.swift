import AppKit
import CoreVideo
import Foundation

struct OverlayFrameRenderRequest {
    var size: CGSize
    var layout: OverlayLayout
    var activity: ActivityTimeline
    var elapsedTime: TimeInterval
    var renderGuides: Bool
    var flipVerticallyAfterRender = false
}

enum OverlayFrameRenderError: LocalizedError {
    case cannotCreateBitmapContext
    case cannotCreatePNGData
    case cannotCreatePixelBufferContext

    var errorDescription: String? {
        switch self {
        case .cannotCreateBitmapContext:
            "Could not create a bitmap context for overlay frame rendering."
        case .cannotCreatePNGData:
            "Could not create PNG data from the rendered overlay frame."
        case .cannotCreatePixelBufferContext:
            "Could not create a pixel buffer context for overlay frame rendering."
        }
    }
}

struct OverlayFrameRenderer {
    fileprivate static let textSupersamplingScale = 2.0

    static func renderPNG(to url: URL, request: OverlayFrameRenderRequest) throws {
        var cache = OverlayRenderCache()
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(request.size.width),
            pixelsHigh: Int(request.size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext else {
            throw OverlayFrameRenderError.cannotCreateBitmapContext
        }

        drawFrame(in: context, request: request, cache: &cache)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw OverlayFrameRenderError.cannotCreatePNGData
        }
        try data.write(to: url)
    }

    static func render(pixelBuffer: CVPixelBuffer, request: OverlayFrameRenderRequest, cache: inout OverlayRenderCache) throws {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: Int(request.size.width),
            height: Int(request.size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            throw OverlayFrameRenderError.cannotCreatePixelBufferContext
        }

        drawFrame(in: context, request: request, cache: &cache)
        if request.flipVerticallyAfterRender {
            flipPixelBufferRowsVertically(pixelBuffer)
        }
    }

    private static func drawFrame(in context: CGContext, request: OverlayFrameRenderRequest, cache: inout OverlayRenderCache) {
        context.clear(CGRect(origin: .zero, size: request.size))

        let previousContext = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        defer { NSGraphicsContext.current = previousContext }

        if request.renderGuides {
            renderSafetyGuides(canvasSize: request.size)
        }

        for element in request.layout.elements {
            let renderContext = OverlayRenderContext(canvasSize: request.size, activity: request.activity, elapsedTime: request.elapsedTime)
            renderElement(element, renderContext: renderContext, cache: &cache)
        }
    }

    private static func renderElement(
        _ element: OverlayElement,
        renderContext: OverlayRenderContext,
        cache: inout OverlayRenderCache
    ) {
        switch element.type {
        case .distanceTimeline:
            renderDistanceTimeline(element, renderContext: renderContext, cache: &cache)
        case .elevationChart:
            renderElevationChart(element, renderContext: renderContext, cache: &cache)
        case .runningGauge:
            renderRunningGauge(element, renderContext: renderContext)
        case .routeMap:
            renderRouteMap(element, renderContext: renderContext)
        default:
            renderTextElement(element, renderContext: renderContext, cache: &cache)
        }
    }

    private static func renderTextElement(_ element: OverlayElement, renderContext: OverlayRenderContext, cache: inout OverlayRenderCache) {
        let renderLayout = OverlayRenderModel.textLayout(for: element, in: renderContext)
        guard renderLayout.preset == .minimal else {
            renderPresetTextElement(element, renderLayout: renderLayout, renderContext: renderContext)
            return
        }

        let layout = cache.textLayout(for: element, text: renderLayout.value, fontSize: renderLayout.fontSize, shadowRadius: renderLayout.shadowRadius, shadowOffsetY: renderLayout.shadowOffsetY)
        let textSize = layout.size
        let rect = OverlayRenderModel.centeredRect(
            for: element,
            contentSize: CGSize(width: renderLayout.horizontalPadding * 2, height: renderLayout.verticalPadding * 2),
            textSize: textSize,
            context: renderContext
        )

        drawSupersampledText(
            renderLayout.value,
            for: element,
            fontSize: renderLayout.fontSize,
            shadowRadius: renderLayout.shadowRadius,
            shadowOffsetY: renderLayout.shadowOffsetY,
            in: rect,
            textRect: CGRect(
                x: renderLayout.horizontalPadding,
                y: renderLayout.verticalPadding,
                width: rect.width - renderLayout.horizontalPadding * 2,
                height: rect.height - renderLayout.verticalPadding * 2
            ),
            backgroundCornerRadius: renderLayout.cornerRadius
        )
    }

    private static func renderPresetTextElement(
        _ element: OverlayElement,
        renderLayout: OverlayTextRenderLayout,
        renderContext: OverlayRenderContext
    ) {
        let colors = TextPresetColors(
            foreground: NSColor(element.style.foregroundColor),
            background: NSColor.black.withAlphaComponent(element.style.backgroundOpacity),
            accent: NSColor.controlAccentColor
        )
        let rect = presetTextRect(for: element, renderLayout: renderLayout, renderContext: renderContext)

        switch renderLayout.preset {
        case .minimal:
            return
        case .pillBadge:
            drawRoundedRect(rect, color: colors.background, cornerRadius: rect.height / 2)
            let label = renderLayout.components.shortLabel
            let labelSize = textSize(label, for: element, fontSize: renderLayout.labelFontSize, shadowRadius: renderLayout.shadowRadius, shadowOffsetY: renderLayout.shadowOffsetY)
            let valueSize = textSize(renderLayout.components.value, for: element, fontSize: renderLayout.fontSize, shadowRadius: renderLayout.shadowRadius, shadowOffsetY: renderLayout.shadowOffsetY)
            let dividerX = rect.minX + renderLayout.horizontalPadding + labelSize.width + renderLayout.horizontalPadding * 0.65
            drawText(label, for: element, fontSize: renderLayout.labelFontSize, in: CGRect(x: rect.minX + renderLayout.horizontalPadding, y: rect.midY - labelSize.height / 2, width: labelSize.width, height: labelSize.height), renderLayout: renderLayout)
            drawRoundedRect(CGRect(x: dividerX, y: rect.midY - renderLayout.fontSize * 0.45, width: max(renderContext.scaled(1), 1), height: renderLayout.fontSize * 0.9), color: colors.foreground.withAlphaComponent(0.32), cornerRadius: 0)
            drawText(renderLayout.components.value, for: element, fontSize: renderLayout.fontSize, in: CGRect(x: dividerX + renderLayout.horizontalPadding * 0.65, y: rect.midY - valueSize.height / 2, width: valueSize.width, height: valueSize.height), renderLayout: renderLayout)
            drawText(renderLayout.components.unit, for: element, fontSize: renderLayout.unitFontSize, in: CGRect(x: rect.maxX - renderLayout.horizontalPadding - textSize(renderLayout.components.unit, for: element, fontSize: renderLayout.unitFontSize, shadowRadius: renderLayout.shadowRadius, shadowOffsetY: renderLayout.shadowOffsetY).width, y: rect.midY - renderLayout.unitFontSize * 0.48, width: rect.width, height: renderLayout.unitFontSize * 1.25), renderLayout: renderLayout)
        case .metricCard:
            drawRoundedRect(rect, color: colors.background, cornerRadius: renderLayout.cornerRadius)
            drawText(renderLayout.components.label, for: element, fontSize: renderLayout.labelFontSize, in: CGRect(x: rect.minX + renderLayout.horizontalPadding, y: rect.minY + renderLayout.verticalPadding, width: rect.width, height: renderLayout.labelFontSize * 1.25), renderLayout: renderLayout)
            let baselineY = rect.minY + renderLayout.verticalPadding + renderLayout.labelFontSize * 1.35
            drawText(renderLayout.components.value, for: element, fontSize: renderLayout.fontSize, in: CGRect(x: rect.minX + renderLayout.horizontalPadding, y: baselineY, width: rect.width, height: renderLayout.fontSize * 1.25), renderLayout: renderLayout)
            let valueWidth = textSize(renderLayout.components.value, for: element, fontSize: renderLayout.fontSize, shadowRadius: renderLayout.shadowRadius, shadowOffsetY: renderLayout.shadowOffsetY).width
            drawText(renderLayout.components.unit, for: element, fontSize: renderLayout.unitFontSize, in: CGRect(x: rect.minX + renderLayout.horizontalPadding + valueWidth + renderLayout.horizontalPadding * 0.35, y: baselineY + renderLayout.fontSize * 0.28, width: rect.width, height: renderLayout.unitFontSize * 1.25), renderLayout: renderLayout)
        case .bigNumber:
            let valueFontSize = renderLayout.fontSize * 1.95
            drawText(renderLayout.components.value, for: element, fontSize: valueFontSize, in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: valueFontSize * 1.08), renderLayout: renderLayout)
            drawText(renderLayout.components.unit, for: element, fontSize: renderLayout.unitFontSize * 1.25, in: CGRect(x: rect.minX, y: rect.maxY - renderLayout.unitFontSize * 1.55, width: rect.width, height: renderLayout.unitFontSize * 1.45), renderLayout: renderLayout, alignment: .center)
        case .sportWatch:
            drawRoundedRect(rect, color: colors.background, cornerRadius: renderLayout.cornerRadius)
            strokeRoundedRect(rect, color: colors.foreground.withAlphaComponent(0.35), cornerRadius: renderLayout.cornerRadius, lineWidth: max(renderLayout.fontSize / 28, 1))
            drawText(renderLayout.components.shortLabel, for: element, fontSize: renderLayout.labelFontSize, in: CGRect(x: rect.minX, y: rect.minY + renderLayout.verticalPadding, width: rect.width, height: renderLayout.labelFontSize * 1.25), renderLayout: renderLayout, alignment: .center)
            drawRoundedRect(CGRect(x: rect.minX + renderLayout.horizontalPadding, y: rect.minY + renderLayout.verticalPadding + renderLayout.labelFontSize * 1.45, width: rect.width - renderLayout.horizontalPadding * 2, height: max(renderLayout.fontSize / 26, 1)), color: colors.foreground.withAlphaComponent(0.28), cornerRadius: 0)
            drawText(renderLayout.components.value, for: element, fontSize: renderLayout.fontSize, in: CGRect(x: rect.minX, y: rect.midY - renderLayout.fontSize * 0.55, width: rect.width, height: renderLayout.fontSize * 1.25), renderLayout: renderLayout, alignment: .center)
            drawRoundedRect(CGRect(x: rect.minX + renderLayout.horizontalPadding, y: rect.maxY - renderLayout.verticalPadding - renderLayout.labelFontSize * 1.55, width: rect.width - renderLayout.horizontalPadding * 2, height: max(renderLayout.fontSize / 26, 1)), color: colors.foreground.withAlphaComponent(0.28), cornerRadius: 0)
            drawText(renderLayout.components.unit, for: element, fontSize: renderLayout.labelFontSize, in: CGRect(x: rect.minX, y: rect.maxY - renderLayout.verticalPadding - renderLayout.labelFontSize * 1.2, width: rect.width, height: renderLayout.labelFontSize * 1.25), renderLayout: renderLayout, alignment: .center)
        case .splitLabel:
            let label = renderLayout.components.shortLabel.map(String.init).joined(separator: " ")
            drawText(label, for: element, fontSize: renderLayout.labelFontSize, in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: renderLayout.labelFontSize * 1.35), renderLayout: renderLayout)
            drawRoundedRect(CGRect(x: rect.minX, y: rect.minY + renderLayout.labelFontSize * 1.55, width: renderLayout.fontSize * 3.5, height: max(renderLayout.fontSize / 18, 2)), color: colors.accent, cornerRadius: 0)
            let valueFontSize = renderLayout.fontSize * 1.45
            drawText(renderLayout.components.value, for: element, fontSize: valueFontSize, in: CGRect(x: rect.minX, y: rect.minY + renderLayout.labelFontSize * 1.85, width: rect.width, height: valueFontSize * 1.18), renderLayout: renderLayout)
            let valueWidth = textSize(renderLayout.components.value, for: element, fontSize: valueFontSize, shadowRadius: renderLayout.shadowRadius, shadowOffsetY: renderLayout.shadowOffsetY).width
            drawText(renderLayout.components.unit, for: element, fontSize: renderLayout.unitFontSize, in: CGRect(x: rect.minX + valueWidth + renderLayout.horizontalPadding * 0.65, y: rect.minY + renderLayout.labelFontSize * 1.85 + valueFontSize * 0.35, width: rect.width, height: renderLayout.unitFontSize * 1.25), renderLayout: renderLayout)
        }
    }

    private static func renderDistanceTimeline(
        _ element: OverlayElement,
        renderContext: OverlayRenderContext,
        cache: inout OverlayRenderCache
    ) {
        let renderLayout = OverlayRenderModel.distanceTimelineLayout(for: element, in: renderContext)
        drawRoundedBackground(renderLayout.rect, element: element, cornerRadius: renderLayout.cornerRadius)

        let labelLayout = cache.textLayout(
            for: element,
            text: renderLayout.label,
            fontSize: renderLayout.labelFontSize,
            shadowRadius: renderContext.scaled(element.style.shadowRadius),
            shadowOffsetY: renderContext.scaled(2)
        )
        let labelRect = CGRect(
            x: renderLayout.rect.minX + renderLayout.horizontalPadding,
            y: renderLayout.rect.minY + renderLayout.verticalPadding,
            width: renderLayout.rect.width - renderLayout.horizontalPadding * 2,
            height: labelLayout.size.height
        )
        drawSupersampledText(
            renderLayout.label,
            for: element,
            fontSize: renderLayout.labelFontSize,
            shadowRadius: renderContext.scaled(element.style.shadowRadius),
            shadowOffsetY: renderContext.scaled(2),
            in: labelRect,
            textRect: CGRect(origin: .zero, size: labelRect.size)
        )

        let trackRect = CGRect(
            x: renderLayout.rect.minX + renderLayout.horizontalPadding,
            y: renderLayout.rect.maxY - renderLayout.verticalPadding - renderLayout.trackHeight,
            width: renderLayout.rect.width - renderLayout.horizontalPadding * 2,
            height: renderLayout.trackHeight
        )
        drawCapsule(trackRect, color: NSColor(element.style.foregroundColor).withAlphaComponent(0.25))
        drawCapsule(
            CGRect(x: trackRect.minX, y: trackRect.minY, width: trackRect.width * renderLayout.progress, height: trackRect.height),
            color: NSColor(element.style.foregroundColor)
        )
    }

    private static func renderElevationChart(
        _ element: OverlayElement,
        renderContext: OverlayRenderContext,
        cache: inout OverlayRenderCache
    ) {
        let renderLayout = OverlayRenderModel.elevationChartLayout(for: element, in: renderContext)
        drawRoundedBackground(renderLayout.rect, element: element, cornerRadius: renderLayout.cornerRadius)

        let labelLayout = cache.textLayout(
            for: element,
            text: renderLayout.label,
            fontSize: renderLayout.labelFontSize,
            shadowRadius: renderContext.scaled(element.style.shadowRadius),
            shadowOffsetY: renderContext.scaled(2)
        )
        let labelRect = CGRect(
            x: renderLayout.rect.minX + renderLayout.horizontalPadding,
            y: renderLayout.rect.minY + renderLayout.verticalPadding,
            width: renderLayout.rect.width - renderLayout.horizontalPadding * 2,
            height: labelLayout.size.height
        )
        drawSupersampledText(
            renderLayout.label,
            for: element,
            fontSize: renderLayout.labelFontSize,
            shadowRadius: renderContext.scaled(element.style.shadowRadius),
            shadowOffsetY: renderContext.scaled(2),
            in: labelRect,
            textRect: CGRect(origin: .zero, size: labelRect.size)
        )

        let chartRect = CGRect(
            x: renderLayout.rect.minX + renderLayout.horizontalPadding,
            y: renderLayout.rect.maxY - renderLayout.verticalPadding - renderLayout.chartHeight,
            width: renderLayout.rect.width - renderLayout.horizontalPadding * 2,
            height: renderLayout.chartHeight
        )
        drawElevationPath(samples: renderLayout.samples, in: chartRect, color: NSColor(element.style.foregroundColor).withAlphaComponent(0.85), lineWidth: renderLayout.lineWidth)
        NSColor(element.style.foregroundColor).withAlphaComponent(0.45).setFill()
        NSBezierPath(
            rect: CGRect(
                x: chartRect.minX + chartRect.width * renderLayout.progress,
                y: chartRect.minY,
                width: max(renderContext.scaled(2), 1),
                height: chartRect.height
            )
        ).fill()
    }

    private static func renderRunningGauge(_ element: OverlayElement, renderContext: OverlayRenderContext) {
        let layout = OverlayRenderModel.runningGaugeLayout(for: element, in: renderContext)
        let accent = NSColor(element.style.foregroundColor)
        let rect = layout.rect
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2
        let backgroundOpacity = max(element.style.backgroundOpacity, gaugeMinimumBackgroundOpacity(for: layout.preset))

        NSColor.black.withAlphaComponent(backgroundOpacity).setFill()
        NSBezierPath(ovalIn: rect).fill()

        if layout.preset == .trailAdventure {
            accent.withAlphaComponent(0.10).setStroke()
            let path = NSBezierPath(ovalIn: rect.insetBy(dx: layout.ringWidth * 1.25, dy: layout.ringWidth * 1.25))
            path.lineWidth = layout.ringWidth * 3.2
            path.stroke()
        }

        strokeCircle(center: center, radius: radius - layout.ringWidth * 2.3, color: NSColor.white.withAlphaComponent(layout.preset == .highContrast ? 0.78 : 0.26), lineWidth: layout.ringWidth)
        strokeArc(
            center: center,
            radius: radius - layout.ringWidth * 2.3,
            startAngle: -90,
            endAngle: -90 + 360 * layout.progress,
            color: accent,
            lineWidth: layout.ringWidth
        )

        drawGaugeTicks(
            center: center,
            radius: radius - layout.ringWidth * 4.2,
            tickCount: layout.preset == .retroDigital ? 48 : 36,
            tickLength: layout.tickLength,
            lineWidth: max(layout.dividerWidth, 1),
            color: gaugeTickColor(for: layout.preset, accent: accent)
        )
        drawGaugeDividers(in: rect.insetBy(dx: rect.width * 0.18, dy: rect.height * 0.18), lineWidth: layout.dividerWidth, color: NSColor.white.withAlphaComponent(layout.preset == .retroDigital ? 0.20 : 0.16))

        let labelColor = gaugeLabelColor(for: layout.preset, accent: accent)
        let valueColor = gaugeValueColor(for: layout.preset, accent: accent)
        drawGaugeMetric(
            layout.distance,
            element: element,
            rect: CGRect(x: rect.minX + rect.width * 0.26, y: rect.minY + rect.height * 0.18, width: rect.width * 0.48, height: rect.height * 0.24),
            valueFontSize: layout.primaryFontSize,
            labelFontSize: layout.labelFontSize,
            unitFontSize: layout.unitFontSize,
            valueColor: valueColor,
            labelColor: labelColor
        )
        drawGaugeMetric(
            layout.elapsedTime,
            element: element,
            rect: CGRect(x: rect.minX + rect.width * 0.14, y: rect.minY + rect.height * 0.48, width: rect.width * 0.34, height: rect.height * 0.20),
            valueFontSize: layout.secondaryFontSize,
            labelFontSize: layout.labelFontSize,
            unitFontSize: layout.unitFontSize,
            valueColor: valueColor,
            labelColor: labelColor
        )
        drawGaugeMetric(
            layout.pace,
            element: element,
            rect: CGRect(x: rect.minX + rect.width * 0.52, y: rect.minY + rect.height * 0.48, width: rect.width * 0.34, height: rect.height * 0.20),
            valueFontSize: layout.secondaryFontSize,
            labelFontSize: layout.labelFontSize,
            unitFontSize: layout.unitFontSize,
            valueColor: valueColor,
            labelColor: labelColor
        )
        drawGaugeMetric(
            layout.heartRate,
            element: element,
            rect: CGRect(x: rect.minX + rect.width * 0.31, y: rect.minY + rect.height * 0.70, width: rect.width * 0.38, height: rect.height * 0.18),
            valueFontSize: layout.secondaryFontSize * 1.02,
            labelFontSize: layout.labelFontSize,
            unitFontSize: layout.unitFontSize,
            valueColor: valueColor,
            labelColor: labelColor
        )
    }

    private static func renderRouteMap(_ element: OverlayElement, renderContext: OverlayRenderContext) {
        let layout = OverlayRenderModel.routeMapLayout(for: element, in: renderContext)
        let accent = NSColor(element.style.foregroundColor)
        let backgroundOpacity: Double = switch layout.preset {
        case .mapKit: max(element.style.backgroundOpacity, 0.72)
        case .glow: max(element.style.backgroundOpacity, 0.34)
        default: element.style.backgroundOpacity
        }

        let clipMask = RouteMapMaskRenderer.makeCGMask(
            size: layout.rect.size,
            shape: layout.shape,
            cornerRadius: layout.cornerRadius,
            edgeFade: layout.edgeFade,
            fadeAmount: layout.fadeAmount
        )

        if let cgContext = NSGraphicsContext.current?.cgContext, let clipMask {
            cgContext.saveGState()
            cgContext.clip(to: layout.rect, mask: clipMask)
            drawRouteMapContent(element: element, layout: layout, accent: accent, backgroundOpacity: backgroundOpacity)
            cgContext.restoreGState()
        } else {
            NSGraphicsContext.saveGraphicsState()
            RouteMapMaskRenderer.shapePath(shape: layout.shape, rect: layout.rect, cornerRadius: layout.cornerRadius).addClip()
            drawRouteMapContent(element: element, layout: layout, accent: accent, backgroundOpacity: backgroundOpacity)
            NSGraphicsContext.restoreGraphicsState()
        }

        strokeRouteMapBorder(layout: layout, isSelected: false)
    }

    private static func drawRouteMapContent(
        element: OverlayElement,
        layout: OverlayRouteMapRenderLayout,
        accent: NSColor,
        backgroundOpacity: Double
    ) {
        NSColor.black.withAlphaComponent(backgroundOpacity).setFill()
        RouteMapMaskRenderer.shapePath(shape: layout.shape, rect: layout.rect, cornerRadius: layout.cornerRadius).fill()

        if layout.preset == .mapKit || element.style.routeMapBackgroundStyle != .none {
            drawMapGrid(in: layout.rect, style: element.style.routeMapBackgroundStyle)
        }

        let points = layout.projectedPoints
        guard points.count > 1 else {
            drawPlainText(
                "NO GPS",
                element: element,
                fontSize: max(layout.rect.width * 0.09, 10),
                color: accent.withAlphaComponent(0.72),
                rect: layout.rect,
                alignment: .center,
                weight: .semibold
            )
            return
        }

        let shadowPath = routePath(points: points)
        NSColor.black.withAlphaComponent(0.55).setStroke()
        shadowPath.lineWidth = layout.lineWidth + 3
        shadowPath.lineCapStyle = .round
        shadowPath.lineJoinStyle = .round
        shadowPath.stroke()

        if layout.preset == .glow {
            let glowPath = routePath(points: points)
            accent.withAlphaComponent(0.42).setStroke()
            glowPath.lineWidth = layout.lineWidth * 2.5
            glowPath.lineCapStyle = .round
            glowPath.lineJoinStyle = .round
            glowPath.stroke()
        }

        strokeRoutePath(points: points, layout: layout, element: element, accent: accent)

        drawRouteMarker(points.first, color: .systemGreen, lineWidth: layout.lineWidth, style: element.style.routeMapStartMarkerStyle)
        drawRouteMarker(points.last, color: .systemRed, lineWidth: layout.lineWidth, style: element.style.routeMapEndMarkerStyle)
        drawRouteMarker(layout.projectedCurrentPoint, color: accent, lineWidth: layout.lineWidth * 1.18)

        if element.style.routeMapLegendVisible {
            drawRouteLegend(layout: layout, element: element)
        }
    }

    private static func strokeRouteMapBorder(layout: OverlayRouteMapRenderLayout, isSelected: Bool) {
        let border = RouteMapMaskRenderer.shapePath(shape: layout.shape, rect: layout.rect, cornerRadius: layout.cornerRadius)
        (isSelected ? NSColor.controlAccentColor.withAlphaComponent(0.85) : NSColor.white.withAlphaComponent(0.16)).setStroke()
        border.lineWidth = isSelected ? 2 : 1
        border.stroke()
    }

    private static func routePath(points: [CGPoint]) -> NSBezierPath {
        let path = NSBezierPath()
        guard let first = points.first else {
            return path
        }
        path.move(to: first)
        for point in points.dropFirst() {
            path.line(to: point)
        }
        return path
    }

    private static func routeColor(for preset: OverlayRouteMapPreset, element: OverlayElement, accent: NSColor) -> NSColor {
        if element.style.routeMapColorMode == .gradient || preset == .gradient {
            return NSColor(element.style.routeMapGradientMiddle)
        }
        return accent
    }

    private static func strokeRoutePath(
        points: [CGPoint],
        layout: OverlayRouteMapRenderLayout,
        element: OverlayElement,
        accent: NSColor
    ) {
        guard points.count > 1 else {
            return
        }

        if element.style.routeMapColorMode == .gradient || layout.preset == .gradient {
            let start = NSColor(element.style.routeMapGradientStart)
            let middle = NSColor(element.style.routeMapGradientMiddle)
            let end = NSColor(element.style.routeMapGradientEnd)
            let segments = max(points.count - 1, 1)
            for index in 0..<segments {
                let progress = Double(index) / Double(segments)
                gradientColor(progress: progress, start: start, middle: middle, end: end).setStroke()
                let path = NSBezierPath()
                path.move(to: points[index])
                path.line(to: points[index + 1])
                path.lineWidth = layout.lineWidth
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.stroke()
            }
            return
        }

        let path = routePath(points: points)
        routeColor(for: layout.preset, element: element, accent: accent).setStroke()
        path.lineWidth = layout.lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    private static func gradientColor(progress: Double, start: NSColor, middle: NSColor, end: NSColor) -> NSColor {
        if progress <= 0.5 {
            return interpolateColor(start, middle, t: progress / 0.5)
        }
        return interpolateColor(middle, end, t: (progress - 0.5) / 0.5)
    }

    private static func interpolateColor(_ lhs: NSColor, _ rhs: NSColor, t: Double) -> NSColor {
        let clamped = min(max(t, 0), 1)
        let a = lhs.usingColorSpace(.deviceRGB) ?? lhs
        let b = rhs.usingColorSpace(.deviceRGB) ?? rhs
        let red = a.redComponent + (b.redComponent - a.redComponent) * clamped
        let green = a.greenComponent + (b.greenComponent - a.greenComponent) * clamped
        let blue = a.blueComponent + (b.blueComponent - a.blueComponent) * clamped
        let alpha = a.alphaComponent + (b.alphaComponent - a.alphaComponent) * clamped
        return NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    private static func drawRouteMarker(_ point: CGPoint?, color: NSColor, lineWidth: Double, style: OverlayRouteMapMarkerStyle = .dot) {
        guard let point else {
            return
        }
        let path: NSBezierPath
        switch style {
        case .hidden:
            return
        case .dot:
            let diameter = lineWidth * 2.7
            let rect = CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2, width: diameter, height: diameter)
            path = NSBezierPath(ovalIn: rect)
        case .pin:
            let width = lineWidth * 2.9
            let height = lineWidth * 3.5
            let rect = CGRect(x: point.x - width / 2, y: point.y - height / 2, width: width, height: height)
            path = routePinPath(in: rect)
        case .flag:
            let side = lineWidth * 3
            let rect = CGRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side)
            path = routeFlagPath(in: rect)
        }

        color.setFill()
        path.fill()
        NSColor.white.setStroke()
        path.lineWidth = max(lineWidth * 0.35, 1)
        path.stroke()
    }

    private static func routePinPath(in rect: CGRect) -> NSBezierPath {
        let path = NSBezierPath()
        let radius = min(rect.width, rect.height) * 0.34
        let center = CGPoint(x: rect.midX, y: rect.minY + radius + 1)
        path.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.line(to: CGPoint(x: rect.midX - radius * 0.72, y: rect.midY))
        path.line(to: CGPoint(x: rect.midX + radius * 0.72, y: rect.midY))
        path.close()
        return path
    }

    private static func routeFlagPath(in rect: CGRect) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.maxY))
        path.line(to: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.15))
        path.line(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.24))
        path.line(to: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.50))
        path.line(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.62))
        path.line(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.62))
        path.line(to: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.50))
        path.close()
        return path
    }

    private static func drawMapGrid(in rect: CGRect, style: OverlayRouteMapBackgroundStyle) {
        let path = NSBezierPath()
        let step = max(rect.width / 6, 18)
        var x = rect.minX + step
        while x < rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.line(to: CGPoint(x: x, y: rect.maxY))
            x += step
        }
        var y = rect.minY + step
        while y < rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.line(to: CGPoint(x: rect.maxX, y: y))
            y += step
        }
        switch style {
        case .light:
            NSColor.black.withAlphaComponent(0.10).setStroke()
        case .terrain:
            NSColor.systemGreen.withAlphaComponent(0.18).setStroke()
        case .satellite:
            NSColor.white.withAlphaComponent(0.06).setStroke()
        case .none, .dark:
            NSColor.white.withAlphaComponent(0.08).setStroke()
        }
        path.lineWidth = 1
        path.stroke()
    }

    private static func drawRouteLegend(layout: OverlayRouteMapRenderLayout, element: OverlayElement) {
        let legendRect = CGRect(
            x: layout.rect.minX + 10,
            y: layout.rect.maxY - 62,
            width: min(layout.rect.width * 0.45, 120),
            height: 52
        )
        drawRoundedRect(legendRect, color: NSColor.black.withAlphaComponent(0.42), cornerRadius: 7)

        drawLegendItem(color: .systemGreen, text: "Start", rect: CGRect(x: legendRect.minX + 8, y: legendRect.minY + 6, width: legendRect.width - 16, height: 12), element: element, fontSize: max(layout.lineWidth * 1.55, 9))
        drawLegendItem(color: .systemRed, text: "Finish", rect: CGRect(x: legendRect.minX + 8, y: legendRect.minY + 19, width: legendRect.width - 16, height: 12), element: element, fontSize: max(layout.lineWidth * 1.55, 9))
        if element.style.routeMapLegendMode == .startFinishDistance {
            drawPlainText(
                String(format: "%.2f km", (layout.geometry?.distanceMeters ?? 0) / 1000),
                element: element,
                fontSize: max(layout.lineWidth * 2, 10),
                color: NSColor.white.withAlphaComponent(0.9),
                rect: CGRect(x: legendRect.minX + 8, y: legendRect.minY + 32, width: legendRect.width - 16, height: 12),
                alignment: .left,
                weight: .semibold
            )
        } else if element.style.routeMapLegendMode == .gradientBand {
            drawGradientBand(
                rect: CGRect(x: legendRect.minX + 8, y: legendRect.minY + 35, width: min(72, legendRect.width - 16), height: 7),
                start: NSColor(element.style.routeMapGradientStart),
                middle: NSColor(element.style.routeMapGradientMiddle),
                end: NSColor(element.style.routeMapGradientEnd)
            )
        }
    }

    private static func drawGradientBand(rect: CGRect, start: NSColor, middle: NSColor, end: NSColor) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }
        let colors = [start.cgColor, middle.cgColor, end.cgColor] as CFArray
        let locations: [CGFloat] = [0, 0.5, 1]
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) else {
            return
        }
        context.saveGState()
        let path = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        path.addClip()
        context.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.midY), end: CGPoint(x: rect.maxX, y: rect.midY), options: [])
        context.restoreGState()
    }

    private static func drawLegendItem(color: NSColor, text: String, rect: CGRect, element: OverlayElement, fontSize: Double) {
        let dotRect = CGRect(x: rect.minX, y: rect.minY + 2, width: 7, height: 7)
        color.setFill()
        NSBezierPath(ovalIn: dotRect).fill()
        drawPlainText(
            text,
            element: element,
            fontSize: fontSize,
            color: NSColor.white.withAlphaComponent(0.85),
            rect: CGRect(x: rect.minX + 11, y: rect.minY, width: rect.width - 11, height: rect.height),
            alignment: .left,
            weight: .regular
        )
    }

    private static func presetTextRect(for element: OverlayElement, renderLayout: OverlayTextRenderLayout, renderContext: OverlayRenderContext) -> CGRect {
        let labelSize = textSize(renderLayout.components.label, for: element, fontSize: renderLayout.labelFontSize, shadowRadius: renderLayout.shadowRadius, shadowOffsetY: renderLayout.shadowOffsetY)
        let shortLabelSize = textSize(renderLayout.components.shortLabel, for: element, fontSize: renderLayout.labelFontSize, shadowRadius: renderLayout.shadowRadius, shadowOffsetY: renderLayout.shadowOffsetY)
        let spacedLabelSize = textSize(renderLayout.components.shortLabel.map(String.init).joined(separator: " "), for: element, fontSize: renderLayout.labelFontSize, shadowRadius: renderLayout.shadowRadius, shadowOffsetY: renderLayout.shadowOffsetY)
        let valueSize = textSize(renderLayout.components.value, for: element, fontSize: renderLayout.fontSize, shadowRadius: renderLayout.shadowRadius, shadowOffsetY: renderLayout.shadowOffsetY)
        let unitSize = textSize(renderLayout.components.unit, for: element, fontSize: renderLayout.unitFontSize, shadowRadius: renderLayout.shadowRadius, shadowOffsetY: renderLayout.shadowOffsetY)

        let size: CGSize
        switch renderLayout.preset {
        case .minimal:
            size = CGSize(width: valueSize.width + unitSize.width + renderLayout.horizontalPadding * 2.45, height: max(valueSize.height, unitSize.height) + renderLayout.verticalPadding * 2)
        case .pillBadge:
            size = CGSize(
                width: shortLabelSize.width + valueSize.width + unitSize.width + renderLayout.horizontalPadding * 4.3 + max(renderContext.scaled(1), 1),
                height: max(valueSize.height, shortLabelSize.height) + renderLayout.verticalPadding * 2
            )
        case .metricCard:
            size = CGSize(
                width: max(labelSize.width, valueSize.width + unitSize.width + renderLayout.horizontalPadding * 0.35) + renderLayout.horizontalPadding * 2,
                height: labelSize.height + valueSize.height + renderLayout.verticalPadding * 2.75
            )
        case .bigNumber:
            let bigValueSize = textSize(renderLayout.components.value, for: element, fontSize: renderLayout.fontSize * 1.95, shadowRadius: renderLayout.shadowRadius, shadowOffsetY: renderLayout.shadowOffsetY)
            let bigUnitSize = textSize(renderLayout.components.unit, for: element, fontSize: renderLayout.unitFontSize * 1.25, shadowRadius: renderLayout.shadowRadius, shadowOffsetY: renderLayout.shadowOffsetY)
            size = CGSize(width: max(bigValueSize.width, bigUnitSize.width), height: bigValueSize.height + bigUnitSize.height * 0.95)
        case .sportWatch:
            size = CGSize(
                width: max(valueSize.width + renderLayout.horizontalPadding * 2, renderLayout.fontSize * 3.2),
                height: shortLabelSize.height + valueSize.height + unitSize.height + renderLayout.verticalPadding * 4
            )
        case .splitLabel:
            let bigValueSize = textSize(renderLayout.components.value, for: element, fontSize: renderLayout.fontSize * 1.45, shadowRadius: renderLayout.shadowRadius, shadowOffsetY: renderLayout.shadowOffsetY)
            size = CGSize(
                width: max(spacedLabelSize.width, bigValueSize.width + unitSize.width + renderLayout.horizontalPadding * 0.65, renderLayout.fontSize * 3.5),
                height: spacedLabelSize.height + bigValueSize.height + renderLayout.verticalPadding * 2.2
            )
        }

        return CGRect(
            x: renderContext.canvasSize.width * element.position.x - size.width / 2,
            y: renderContext.canvasSize.height * element.position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    fileprivate static func textAttributes(for element: OverlayElement, fontSize: Double, shadowRadius: Double, shadowOffsetY: Double) -> [NSAttributedString.Key: Any] {
        let font = NSFont(name: element.style.fontName, size: fontSize) ?? .systemFont(ofSize: fontSize, weight: nsFontWeight(element.style.fontWeight))
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(element.style.foregroundColor)
        ]
        if element.style.shadowEnabled, element.style.shadowOpacity > 0 {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(element.style.shadowOpacity)
            shadow.shadowBlurRadius = shadowRadius
            shadow.shadowOffset = CGSize(width: element.style.shadowOffsetX, height: shadowOffsetY)
            attributes[.shadow] = shadow
        }
        return attributes
    }

    private static func textSize(_ text: String, for element: OverlayElement, fontSize: Double, shadowRadius: Double, shadowOffsetY: Double) -> CGSize {
        NSAttributedString(
            string: text,
            attributes: textAttributes(for: element, fontSize: fontSize, shadowRadius: shadowRadius, shadowOffsetY: shadowOffsetY)
        ).size()
    }

    private static func drawText(
        _ text: String,
        for element: OverlayElement,
        fontSize: Double,
        in rect: CGRect,
        renderLayout: OverlayTextRenderLayout,
        alignment: NSTextAlignment = .left
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        var attributes = textAttributes(
            for: element,
            fontSize: fontSize,
            shadowRadius: renderLayout.shadowRadius,
            shadowOffsetY: renderLayout.shadowOffsetY
        )
        attributes[.paragraphStyle] = paragraphStyle
        NSAttributedString(string: text, attributes: attributes).draw(in: rect)
    }

    private static func drawSupersampledText(
        _ text: String,
        for element: OverlayElement,
        fontSize: Double,
        shadowRadius: Double,
        shadowOffsetY: Double,
        in rect: CGRect,
        textRect: CGRect,
        backgroundCornerRadius: Double? = nil
    ) {
        let scale = textSupersamplingScale
        let pixelWidth = max(Int(ceil(rect.width * scale)), 1)
        let pixelHeight = max(Int(ceil(rect.height * scale)), 1)

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let offscreenCGContext = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext else {
            drawRoundedBackgroundIfNeeded(rect, element: element, cornerRadius: backgroundCornerRadius)
            NSAttributedString(
                string: text,
                attributes: textAttributes(for: element, fontSize: fontSize, shadowRadius: shadowRadius, shadowOffsetY: shadowOffsetY)
            ).draw(
                in: CGRect(
                    x: rect.minX + textRect.minX,
                    y: rect.minY + textRect.minY,
                    width: textRect.width,
                    height: textRect.height
                )
            )
            return
        }

        offscreenCGContext.clear(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        let previousContext = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: offscreenCGContext, flipped: true)

        if let backgroundCornerRadius {
            let baseColor = NSColor(element.style.backgroundColor)
            let opacity = element.style.backgroundEnabled ? element.style.backgroundOpacity : 0
            baseColor.withAlphaComponent(opacity).setFill()
            NSBezierPath(
                roundedRect: CGRect(x: 0, y: 0, width: rect.width * scale, height: rect.height * scale),
                xRadius: backgroundCornerRadius * scale,
                yRadius: backgroundCornerRadius * scale
            ).fill()
        }

        NSAttributedString(
            string: text,
            attributes: textAttributes(
                for: element,
                fontSize: fontSize * scale,
                shadowRadius: shadowRadius * scale,
                shadowOffsetY: shadowOffsetY * scale
            )
        ).draw(
            in: CGRect(
                x: textRect.minX * scale,
                y: textRect.minY * scale,
                width: textRect.width * scale,
                height: textRect.height * scale
            )
        )
        NSGraphicsContext.current = previousContext

        guard let cgImage = bitmap.cgImage else {
            return
        }

        let image = NSImage(cgImage: cgImage, size: rect.size)
        let currentContext = previousContext
        let previousInterpolation = currentContext?.imageInterpolation
        currentContext?.imageInterpolation = .high
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        if let previousInterpolation {
            currentContext?.imageInterpolation = previousInterpolation
        }
    }

    private static func drawRoundedBackgroundIfNeeded(_ rect: CGRect, element: OverlayElement, cornerRadius: Double?) {
        guard let cornerRadius else {
            return
        }

        drawRoundedBackground(rect, element: element, cornerRadius: cornerRadius)
    }

    private static func nsFontWeight(_ weight: OverlayFontWeight) -> NSFont.Weight {
        switch weight {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }

    private static func drawRoundedBackground(_ rect: CGRect, element: OverlayElement, cornerRadius: Double) {
        let baseColor = NSColor(element.style.backgroundColor)
        let opacity = element.style.backgroundEnabled ? element.style.backgroundOpacity : 0
        baseColor.withAlphaComponent(opacity).setFill()
        NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).fill()
    }

    private static func drawRoundedRect(_ rect: CGRect, color: NSColor, cornerRadius: Double) {
        color.setFill()
        NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).fill()
    }

    private static func strokeRoundedRect(_ rect: CGRect, color: NSColor, cornerRadius: Double, lineWidth: Double) {
        color.setStroke()
        let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        path.lineWidth = lineWidth
        path.stroke()
    }

    private static func drawCapsule(_ rect: CGRect, color: NSColor) {
        color.setFill()
        NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2).fill()
    }

    private static func drawElevationPath(samples: [Double], in rect: CGRect, color: NSColor, lineWidth: Double) {
        let path = NSBezierPath()
        guard samples.count > 1 else {
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.line(to: CGPoint(x: rect.maxX, y: rect.midY))
            color.setStroke()
            path.lineWidth = lineWidth
            path.stroke()
            return
        }

        let minValue = samples.min() ?? 0
        let maxValue = samples.max() ?? minValue
        let range = max(maxValue - minValue, 1)

        for index in samples.indices {
            let x = rect.minX + rect.width * Double(index) / Double(max(samples.count - 1, 1))
            let normalized = (samples[index] - minValue) / range
            let y = rect.maxY - rect.height * normalized
            if index == samples.startIndex {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.line(to: CGPoint(x: x, y: y))
            }
        }

        color.setStroke()
        path.lineWidth = lineWidth
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.stroke()
    }

    private static func drawGaugeMetric(
        _ metric: OverlayValueComponents,
        element: OverlayElement,
        rect: CGRect,
        valueFontSize: Double,
        labelFontSize: Double,
        unitFontSize: Double,
        valueColor: NSColor,
        labelColor: NSColor
    ) {
        let label = metric.shortLabel == "HR" ? "HEART RATE" : metric.label.uppercased()
        drawPlainText(
            label,
            element: element,
            fontSize: labelFontSize,
            color: labelColor,
            rect: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: labelFontSize * 1.25),
            alignment: .center,
            weight: .medium
        )

        let valueText = metric.unit.isEmpty ? metric.value : "\(metric.value) \(metric.unit)"
        drawPlainText(
            valueText,
            element: element,
            fontSize: valueFontSize,
            color: valueColor,
            rect: CGRect(x: rect.minX, y: rect.minY + labelFontSize * 1.05, width: rect.width, height: valueFontSize * 1.25),
            alignment: .center,
            weight: .bold
        )
    }

    private static func drawGaugeDividers(in rect: CGRect, lineWidth: Double, color: NSColor) {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.44))
        path.line(to: CGPoint(x: rect.minX + rect.width * 0.82, y: rect.minY + rect.height * 0.44))
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.44))
        path.line(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.72))
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.minY + rect.height * 0.72))
        path.line(to: CGPoint(x: rect.minX + rect.width * 0.75, y: rect.minY + rect.height * 0.72))
        color.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }

    private static func drawGaugeTicks(center: CGPoint, radius: Double, tickCount: Int, tickLength: Double, lineWidth: Double, color: NSColor) {
        for index in 0..<tickCount {
            let angle = Double(index) / Double(tickCount) * 2 * Double.pi - Double.pi / 2
            let major = index.isMultiple(of: 3)
            let length = major ? tickLength : tickLength * 0.55
            let outer = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            let inner = CGPoint(x: center.x + cos(angle) * (radius - length), y: center.y + sin(angle) * (radius - length))
            let path = NSBezierPath()
            path.move(to: inner)
            path.line(to: outer)
            color.withAlphaComponent(major ? color.alphaComponent : color.alphaComponent * 0.46).setStroke()
            path.lineWidth = lineWidth
            path.stroke()
        }
    }

    private static func strokeCircle(center: CGPoint, radius: Double, color: NSColor, lineWidth: Double) {
        color.setStroke()
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        let path = NSBezierPath(ovalIn: rect)
        path.lineWidth = lineWidth
        path.stroke()
    }

    private static func strokeArc(center: CGPoint, radius: Double, startAngle: Double, endAngle: Double, color: NSColor, lineWidth: Double) {
        color.setStroke()
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.stroke()
    }

    private static func drawPlainText(
        _ text: String,
        element: OverlayElement,
        fontSize: Double,
        color: NSColor,
        rect: CGRect,
        alignment: NSTextAlignment,
        weight: NSFont.Weight
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        let font = NSFont(name: element.style.fontName, size: fontSize) ?? .systemFont(ofSize: fontSize, weight: weight)
        NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle
            ]
        ).draw(in: rect)
    }

    private static func gaugeMinimumBackgroundOpacity(for preset: OverlayGaugePreset) -> Double {
        switch preset {
        case .minimalSport: 0.58
        case .highContrast: 0.82
        case .trailAdventure: 0.74
        case .techFuture: 0.76
        case .retroDigital: 0.78
        }
    }

    private static func gaugeValueColor(for preset: OverlayGaugePreset, accent: NSColor) -> NSColor {
        switch preset {
        case .trailAdventure:
            accent.withAlphaComponent(0.92)
        case .retroDigital:
            accent.withAlphaComponent(0.82)
        default:
            .white
        }
    }

    private static func gaugeLabelColor(for preset: OverlayGaugePreset, accent: NSColor) -> NSColor {
        switch preset {
        case .highContrast:
            accent
        case .techFuture:
            accent.withAlphaComponent(0.9)
        default:
            NSColor.white.withAlphaComponent(0.72)
        }
    }

    private static func gaugeTickColor(for preset: OverlayGaugePreset, accent: NSColor) -> NSColor {
        switch preset {
        case .highContrast:
            NSColor.white.withAlphaComponent(0.92)
        default:
            accent.withAlphaComponent(0.78)
        }
    }

    private static func renderSafetyGuides(canvasSize: CGSize) {
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        drawGuideRect(canvasRect.insetBy(dx: canvasRect.width * 0.05, dy: canvasRect.height * 0.05), color: NSColor.white.withAlphaComponent(0.58), lineWidth: max(canvasSize.width / 640, 1))
        drawGuideRect(canvasRect.insetBy(dx: canvasRect.width * 0.10, dy: canvasRect.height * 0.10), color: NSColor.white.withAlphaComponent(0.36), lineWidth: max(canvasSize.width / 960, 1))

        let centerPath = NSBezierPath()
        centerPath.move(to: CGPoint(x: canvasRect.midX, y: canvasRect.minY))
        centerPath.line(to: CGPoint(x: canvasRect.midX, y: canvasRect.maxY))
        centerPath.move(to: CGPoint(x: canvasRect.minX, y: canvasRect.midY))
        centerPath.line(to: CGPoint(x: canvasRect.maxX, y: canvasRect.midY))
        NSColor.white.withAlphaComponent(0.24).setStroke()
        centerPath.lineWidth = max(canvasSize.width / 1280, 1)
        centerPath.stroke()
    }

    private static func drawGuideRect(_ rect: CGRect, color: NSColor, lineWidth: Double) {
        color.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = lineWidth
        path.stroke()
    }

    private static func flipPixelBufferRowsVertically(_ pixelBuffer: CVPixelBuffer) {
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return
        }

        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard height > 1, bytesPerRow > 0 else {
            return
        }

        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        var scratch = [UInt8](repeating: 0, count: bytesPerRow)

        for row in 0..<(height / 2) {
            let topOffset = row * bytesPerRow
            let bottomOffset = (height - row - 1) * bytesPerRow
            scratch.withUnsafeMutableBytes { scratchPointer in
                guard let scratchBase = scratchPointer.baseAddress else {
                    return
                }
                memcpy(scratchBase, buffer.advanced(by: topOffset), bytesPerRow)
                memcpy(buffer.advanced(by: topOffset), buffer.advanced(by: bottomOffset), bytesPerRow)
                memcpy(buffer.advanced(by: bottomOffset), scratchBase, bytesPerRow)
            }
        }
    }
}

struct OverlayRenderCache {
    private var textLayouts: [TextLayoutKey: TextLayout] = [:]

    fileprivate mutating func textLayout(for element: OverlayElement, text: String, fontSize: Double, shadowRadius: Double, shadowOffsetY: Double) -> TextLayout {
        let key = TextLayoutKey(
            text: text,
            fontName: element.style.fontName,
            fontSize: fontSize,
            fontWeight: element.style.fontWeight,
            foregroundColor: element.style.foregroundColor,
            shadowOpacity: element.style.shadowOpacity,
            shadowRadius: shadowRadius,
            shadowOffsetY: shadowOffsetY
        )
        if let cached = textLayouts[key] {
            return cached
        }

        let attributedString = NSAttributedString(
            string: text,
            attributes: OverlayFrameRenderer.textAttributes(for: element, fontSize: fontSize, shadowRadius: shadowRadius, shadowOffsetY: shadowOffsetY)
        )
        let layout = TextLayout(attributedString: attributedString, size: attributedString.size())
        textLayouts[key] = layout
        return layout
    }
}

private struct TextLayout {
    var attributedString: NSAttributedString
    var size: CGSize
}

private struct TextPresetColors {
    var foreground: NSColor
    var background: NSColor
    var accent: NSColor
}

private struct TextLayoutKey: Hashable {
    var text: String
    var fontName: String
    var fontSize: Double
    var fontWeight: OverlayFontWeight
    var foregroundColor: OverlayColor
    var shadowOpacity: Double
    var shadowRadius: Double
    var shadowOffsetY: Double
}

private extension NSColor {
    convenience init(_ color: OverlayColor) {
        self.init(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }
}
