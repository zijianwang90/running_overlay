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
        if request.flipVerticallyAfterRender {
            flipBitmapRowsVertically(bitmap)
        }
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

        for element in request.layout.elements where element.isVisible {
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
        case .lapList:
            renderLapList(element, renderContext: renderContext)
        case .lapCard:
            renderLapCard(element, renderContext: renderContext)
        case .lapLive:
            renderLapLive(element, renderContext: renderContext)
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
            accent: NSColor(element.style.accentColor)
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
            drawRoundedRect(CGRect(x: rect.minX, y: rect.minY + renderLayout.labelFontSize * 1.55, width: renderLayout.fontSize * 3.5, height: max(renderLayout.fontSize / 18, 2)), color: NSColor(element.style.accentColor), cornerRadius: 0)
            let valueFontSize = renderLayout.fontSize * 1.45
            drawText(renderLayout.components.value, for: element, fontSize: valueFontSize, in: CGRect(x: rect.minX, y: rect.minY + renderLayout.labelFontSize * 1.85, width: rect.width, height: valueFontSize * 1.18), renderLayout: renderLayout)
            let valueWidth = textSize(renderLayout.components.value, for: element, fontSize: valueFontSize, shadowRadius: renderLayout.shadowRadius, shadowOffsetY: renderLayout.shadowOffsetY).width
            drawText(renderLayout.components.unit, for: element, fontSize: renderLayout.unitFontSize, in: CGRect(x: rect.minX + valueWidth + renderLayout.horizontalPadding * 0.65, y: rect.minY + renderLayout.labelFontSize * 1.85 + valueFontSize * 0.35, width: rect.width, height: renderLayout.unitFontSize * 1.25), renderLayout: renderLayout)
        case .minimalLabel:
            renderMinimalLabel(element: element, renderLayout: renderLayout, rect: rect, colors: colors)
        case .neonGlow:
            renderNeonGlow(element: element, renderLayout: renderLayout, rect: rect, colors: colors)
        case .racingStripe:
            renderRacingStripe(element: element, renderLayout: renderLayout, rect: rect, colors: colors)
        case .editorial:
            renderEditorial(element: element, renderLayout: renderLayout, rect: rect, colors: colors)
        case .digitalWatch:
            renderDigitalWatch(element: element, renderLayout: renderLayout, rect: rect, colors: colors)
        case .inlineGhost:
            renderInlineGhost(element: element, renderLayout: renderLayout, rect: rect, colors: colors)
        case .accentBar:
            renderAccentBar(element: element, renderLayout: renderLayout, rect: rect, colors: colors)
        case .sportNeon:
            renderSportNeon(element: element, renderLayout: renderLayout, rect: rect, colors: colors)
        case .serifEditorial:
            renderSerifEditorial(element: element, renderLayout: renderLayout, rect: rect, colors: colors)
        }
    }

    private static func renderMinimalLabel(
        element: OverlayElement,
        renderLayout: OverlayTextRenderLayout,
        rect: CGRect,
        colors: TextPresetColors
    ) {
        let foreground = colors.foreground
        var cursorY = rect.maxY
        if element.style.showLabel, !renderLayout.components.label.isEmpty {
            cursorY -= renderLayout.labelFontSize * 1.4
            drawText(
                renderLayout.components.label.uppercased(),
                for: element,
                fontSize: renderLayout.labelFontSize,
                in: CGRect(x: rect.minX, y: cursorY, width: rect.width, height: renderLayout.labelFontSize * 1.25),
                renderLayout: renderLayout,
                color: foreground.withAlphaComponent(0.72)
            )
        }
        cursorY -= renderLayout.fontSize * 1.10
        let valueWidth = textSize(renderLayout.components.value, for: element, fontSize: renderLayout.fontSize, shadowRadius: renderLayout.shadowRadius, shadowOffsetY: renderLayout.shadowOffsetY).width
        drawText(
            renderLayout.components.value,
            for: element,
            fontSize: renderLayout.fontSize,
            in: CGRect(x: rect.minX, y: cursorY, width: rect.width, height: renderLayout.fontSize * 1.25),
            renderLayout: renderLayout,
            color: foreground
        )
        if element.style.showUnit, !renderLayout.components.unit.isEmpty {
            drawText(
                renderLayout.components.unit,
                for: element,
                fontSize: renderLayout.unitFontSize,
                in: CGRect(x: rect.minX + valueWidth + renderLayout.fontSize * 0.16, y: cursorY + renderLayout.fontSize * 0.42, width: rect.width, height: renderLayout.unitFontSize * 1.25),
                renderLayout: renderLayout,
                color: foreground.withAlphaComponent(0.92)
            )
        }
    }

    private static func renderNeonGlow(
        element: OverlayElement,
        renderLayout: OverlayTextRenderLayout,
        rect: CGRect,
        colors: TextPresetColors
    ) {
        let accent = NSColor(element.style.accentColor)
        let valueWidth = textSize(renderLayout.components.value, for: element, fontSize: renderLayout.fontSize, shadowRadius: renderLayout.shadowRadius, shadowOffsetY: renderLayout.shadowOffsetY).width
        let valueRect = CGRect(x: rect.minX, y: rect.maxY - renderLayout.fontSize * 1.15, width: rect.width, height: renderLayout.fontSize * 1.25)
        // Glow halo: stamp the value behind itself in accent color so the
        // existing shadow attributes produce a soft halo.
        drawText(
            renderLayout.components.value,
            for: element,
            fontSize: renderLayout.fontSize,
            in: valueRect,
            renderLayout: renderLayout,
            color: accent.withAlphaComponent(0.55)
        )
        drawText(
            renderLayout.components.value,
            for: element,
            fontSize: renderLayout.fontSize,
            in: valueRect,
            renderLayout: renderLayout,
            color: colors.foreground
        )
        if element.style.showUnit, !renderLayout.components.unit.isEmpty {
            drawText(
                renderLayout.components.unit,
                for: element,
                fontSize: renderLayout.unitFontSize,
                in: CGRect(x: rect.minX + valueWidth + renderLayout.fontSize * 0.16, y: valueRect.minY + renderLayout.fontSize * 0.35, width: rect.width, height: renderLayout.unitFontSize * 1.25),
                renderLayout: renderLayout,
                color: accent.withAlphaComponent(0.95)
            )
        }
    }

    private static func renderRacingStripe(
        element: OverlayElement,
        renderLayout: OverlayTextRenderLayout,
        rect: CGRect,
        colors: TextPresetColors
    ) {
        drawRoundedRect(rect, color: colors.background, cornerRadius: renderLayout.cornerRadius)
        strokeRoundedRect(rect, color: colors.foreground.withAlphaComponent(0.14), cornerRadius: renderLayout.cornerRadius, lineWidth: 1)
        let stripeWidth = max(renderLayout.fontSize * 0.12, 4)
        let stripeRect = CGRect(
            x: rect.minX + renderLayout.horizontalPadding,
            y: rect.minY + renderLayout.verticalPadding,
            width: stripeWidth,
            height: rect.height - renderLayout.verticalPadding * 2
        )
        drawRoundedRect(stripeRect, color: NSColor(element.style.accentColor), cornerRadius: 2)
        let textOriginX = stripeRect.maxX + renderLayout.fontSize * 0.34
        let labelY = rect.minY + renderLayout.verticalPadding
        if element.style.showLabel, !renderLayout.components.label.isEmpty {
            drawText(
                renderLayout.components.label.uppercased(),
                for: element,
                fontSize: renderLayout.labelFontSize,
                in: CGRect(x: textOriginX, y: labelY, width: rect.width, height: renderLayout.labelFontSize * 1.25),
                renderLayout: renderLayout,
                color: colors.foreground
            )
        }
        let valueY = labelY + renderLayout.labelFontSize * 1.40
        let valueWidth = textSize(renderLayout.components.value, for: element, fontSize: renderLayout.fontSize, shadowRadius: renderLayout.shadowRadius, shadowOffsetY: renderLayout.shadowOffsetY).width
        drawText(
            renderLayout.components.value,
            for: element,
            fontSize: renderLayout.fontSize,
            in: CGRect(x: textOriginX, y: valueY, width: rect.width, height: renderLayout.fontSize * 1.25),
            renderLayout: renderLayout
        )
        if element.style.showUnit, !renderLayout.components.unit.isEmpty {
            drawText(
                renderLayout.components.unit,
                for: element,
                fontSize: renderLayout.unitFontSize,
                in: CGRect(x: textOriginX + valueWidth + renderLayout.fontSize * 0.16, y: valueY + renderLayout.fontSize * 0.32, width: rect.width, height: renderLayout.unitFontSize * 1.25),
                renderLayout: renderLayout,
                color: colors.foreground.withAlphaComponent(0.92)
            )
        }
    }

    private static func renderEditorial(
        element: OverlayElement,
        renderLayout: OverlayTextRenderLayout,
        rect: CGRect,
        colors: TextPresetColors
    ) {
        let accent = NSColor(element.style.accentColor)
        var cursorY = rect.minY
        if element.style.showLabel, !renderLayout.components.label.isEmpty {
            drawText(
                renderLayout.components.label.uppercased(),
                for: element,
                fontSize: renderLayout.labelFontSize,
                in: CGRect(x: rect.minX, y: cursorY, width: rect.width, height: renderLayout.labelFontSize * 1.25),
                renderLayout: renderLayout,
                color: accent
            )
            cursorY += renderLayout.labelFontSize * 1.45
        }
        let valueWidth = textSize(renderLayout.components.value, for: element, fontSize: renderLayout.fontSize, shadowRadius: renderLayout.shadowRadius, shadowOffsetY: renderLayout.shadowOffsetY).width
        drawText(
            renderLayout.components.value,
            for: element,
            fontSize: renderLayout.fontSize,
            in: CGRect(x: rect.minX, y: cursorY, width: rect.width, height: renderLayout.fontSize * 1.18),
            renderLayout: renderLayout
        )
        if element.style.showUnit, !renderLayout.components.unit.isEmpty {
            drawText(
                renderLayout.components.unit,
                for: element,
                fontSize: renderLayout.unitFontSize,
                in: CGRect(x: rect.minX + valueWidth + renderLayout.fontSize * 0.10, y: cursorY + renderLayout.fontSize * 0.30, width: rect.width, height: renderLayout.unitFontSize * 1.25),
                renderLayout: renderLayout,
                color: colors.foreground.withAlphaComponent(0.92)
            )
        }
        cursorY += renderLayout.fontSize * 1.15
        drawRoundedRect(
            CGRect(x: rect.minX, y: cursorY + renderLayout.fontSize * 0.04, width: renderLayout.fontSize * 2.2, height: 3),
            color: accent,
            cornerRadius: 0
        )
    }

    private static func renderDigitalWatch(
        element: OverlayElement,
        renderLayout: OverlayTextRenderLayout,
        rect: CGRect,
        colors: TextPresetColors
    ) {
        let accent = NSColor(element.style.accentColor)
        drawRoundedRect(rect, color: colors.background, cornerRadius: renderLayout.cornerRadius)
        strokeRoundedRect(rect, color: accent.withAlphaComponent(0.70), cornerRadius: renderLayout.cornerRadius, lineWidth: 1)
        var cursorY = rect.minY + renderLayout.verticalPadding
        if element.style.showLabel, !renderLayout.components.label.isEmpty {
            drawText(
                renderLayout.components.label.uppercased(),
                for: element,
                fontSize: renderLayout.labelFontSize,
                in: CGRect(x: rect.minX + renderLayout.horizontalPadding, y: cursorY, width: rect.width, height: renderLayout.labelFontSize * 1.25),
                renderLayout: renderLayout,
                color: accent.withAlphaComponent(0.90)
            )
            cursorY += renderLayout.labelFontSize * 1.40
        }
        let valueWidth = textSize(renderLayout.components.value, for: element, fontSize: renderLayout.fontSize, shadowRadius: renderLayout.shadowRadius, shadowOffsetY: renderLayout.shadowOffsetY).width
        drawText(
            renderLayout.components.value,
            for: element,
            fontSize: renderLayout.fontSize,
            in: CGRect(x: rect.minX + renderLayout.horizontalPadding, y: cursorY, width: rect.width, height: renderLayout.fontSize * 1.25),
            renderLayout: renderLayout,
            color: accent
        )
        if element.style.showUnit, !renderLayout.components.unit.isEmpty {
            drawText(
                renderLayout.components.unit,
                for: element,
                fontSize: renderLayout.unitFontSize,
                in: CGRect(x: rect.minX + renderLayout.horizontalPadding + valueWidth + renderLayout.fontSize * 0.14, y: cursorY + renderLayout.fontSize * 0.32, width: rect.width, height: renderLayout.unitFontSize * 1.25),
                renderLayout: renderLayout,
                color: accent.withAlphaComponent(0.95)
            )
        }
    }

    private static func renderInlineGhost(
        element: OverlayElement,
        renderLayout: OverlayTextRenderLayout,
        rect: CGRect,
        colors: TextPresetColors
    ) {
        let foreground = colors.foreground
        var cursorY = rect.maxY
        if element.style.showLabel, !renderLayout.components.label.isEmpty {
            cursorY -= renderLayout.labelFontSize * 1.2
            drawText(
                renderLayout.components.label.uppercased(),
                for: element,
                fontSize: renderLayout.labelFontSize,
                in: CGRect(x: rect.minX, y: cursorY, width: rect.width, height: renderLayout.labelFontSize * 1.25),
                renderLayout: renderLayout,
                color: foreground.withAlphaComponent(0.28)
            )
        }
        cursorY -= renderLayout.fontSize * 1.05
        let valueWidth = textSize(renderLayout.components.value, for: element, fontSize: renderLayout.fontSize, shadowRadius: renderLayout.shadowRadius, shadowOffsetY: renderLayout.shadowOffsetY).width
        drawText(
            renderLayout.components.value,
            for: element,
            fontSize: renderLayout.fontSize,
            in: CGRect(x: rect.minX, y: cursorY, width: rect.width, height: renderLayout.fontSize * 1.25),
            renderLayout: renderLayout,
            color: foreground.withAlphaComponent(0.88)
        )
        if element.style.showUnit, !renderLayout.components.unit.isEmpty {
            drawText(
                renderLayout.components.unit,
                for: element,
                fontSize: renderLayout.unitFontSize,
                in: CGRect(x: rect.minX + valueWidth + renderLayout.fontSize * 0.18, y: cursorY + renderLayout.fontSize * 0.62, width: rect.width, height: renderLayout.unitFontSize * 1.25),
                renderLayout: renderLayout,
                color: foreground.withAlphaComponent(0.30)
            )
        }
    }

    private static func renderAccentBar(
        element: OverlayElement,
        renderLayout: OverlayTextRenderLayout,
        rect: CGRect,
        colors: TextPresetColors
    ) {
        let foreground = colors.foreground
        let accent = NSColor(element.style.accentColor)
        let barWidth = max(renderLayout.fontSize * 0.083, 1.5)
        let barHeight = renderLayout.fontSize * 1.55
        let barRect = CGRect(
            x: rect.minX,
            y: rect.midY - barHeight / 2,
            width: barWidth,
            height: barHeight
        )
        drawRoundedRect(barRect, color: accent, cornerRadius: max(renderLayout.fontSize * 0.06, 1))

        let textX = rect.minX + barWidth + renderLayout.fontSize * 0.33
        var cursorY = rect.maxY
        if element.style.showLabel, !renderLayout.components.label.isEmpty {
            cursorY -= renderLayout.labelFontSize * 1.2
            drawText(
                renderLayout.components.label.uppercased(),
                for: element,
                fontSize: renderLayout.labelFontSize,
                in: CGRect(x: textX, y: cursorY, width: rect.width, height: renderLayout.labelFontSize * 1.25),
                renderLayout: renderLayout,
                color: foreground.withAlphaComponent(0.32)
            )
        }
        cursorY -= renderLayout.fontSize * 1.05
        drawText(
            renderLayout.components.value,
            for: element,
            fontSize: renderLayout.fontSize,
            in: CGRect(x: textX, y: cursorY, width: rect.width, height: renderLayout.fontSize * 1.25),
            renderLayout: renderLayout,
            color: foreground
        )
        if element.style.showUnit, !renderLayout.components.unit.isEmpty {
            cursorY -= renderLayout.unitFontSize * 1.25
            drawText(
                renderLayout.components.unit,
                for: element,
                fontSize: renderLayout.unitFontSize,
                in: CGRect(x: textX, y: cursorY, width: rect.width, height: renderLayout.unitFontSize * 1.25),
                renderLayout: renderLayout,
                color: foreground.withAlphaComponent(0.38)
            )
        }
    }

    private static func renderSportNeon(
        element: OverlayElement,
        renderLayout: OverlayTextRenderLayout,
        rect: CGRect,
        colors: TextPresetColors
    ) {
        let foreground = colors.foreground
        let accent = NSColor(element.style.accentColor)
        var cursorY = rect.maxY
        if element.style.showLabel, !renderLayout.components.label.isEmpty {
            cursorY -= renderLayout.labelFontSize * 1.25
            drawText(
                renderLayout.components.label.uppercased(),
                for: element,
                fontSize: renderLayout.labelFontSize,
                in: CGRect(x: rect.minX, y: cursorY, width: rect.width, height: renderLayout.labelFontSize * 1.3),
                renderLayout: renderLayout,
                color: accent
            )
        }
        cursorY -= renderLayout.fontSize * 1.05
        drawText(
            renderLayout.components.value,
            for: element,
            fontSize: renderLayout.fontSize,
            in: CGRect(x: rect.minX, y: cursorY, width: rect.width, height: renderLayout.fontSize * 1.25),
            renderLayout: renderLayout,
            color: foreground
        )
        if element.style.showUnit, !renderLayout.components.unit.isEmpty {
            cursorY -= renderLayout.unitFontSize * 1.6
            let separatorWidth = renderLayout.fontSize * 0.6
            drawRoundedRect(
                CGRect(x: rect.minX, y: cursorY + renderLayout.unitFontSize * 0.6, width: separatorWidth, height: 0.5),
                color: foreground.withAlphaComponent(0.10),
                cornerRadius: 0
            )
            let dotSize = max(renderLayout.fontSize * 0.14, 4)
            let dotX = rect.minX + separatorWidth + renderLayout.fontSize * 0.18
            drawRoundedRect(
                CGRect(x: dotX, y: cursorY + renderLayout.unitFontSize * 0.45, width: dotSize, height: dotSize),
                color: accent,
                cornerRadius: dotSize / 2
            )
            drawText(
                renderLayout.components.unit,
                for: element,
                fontSize: renderLayout.unitFontSize,
                in: CGRect(x: dotX + dotSize + renderLayout.fontSize * 0.18, y: cursorY, width: rect.width, height: renderLayout.unitFontSize * 1.25),
                renderLayout: renderLayout,
                color: foreground.withAlphaComponent(0.35)
            )
        }
    }

    private static func renderSerifEditorial(
        element: OverlayElement,
        renderLayout: OverlayTextRenderLayout,
        rect: CGRect,
        colors: TextPresetColors
    ) {
        let foreground = colors.foreground
        var cursorY = rect.maxY
        if element.style.showLabel, !renderLayout.components.label.isEmpty {
            cursorY -= renderLayout.labelFontSize * 1.25
            drawText(
                renderLayout.components.label.uppercased(),
                for: element,
                fontSize: renderLayout.labelFontSize,
                in: CGRect(x: rect.minX, y: cursorY, width: rect.width, height: renderLayout.labelFontSize * 1.3),
                renderLayout: renderLayout,
                color: foreground.withAlphaComponent(0.30),
                alignment: .center
            )
        }
        cursorY -= renderLayout.fontSize * 1.05
        drawText(
            renderLayout.components.value,
            for: element,
            fontSize: renderLayout.fontSize,
            in: CGRect(x: rect.minX, y: cursorY, width: rect.width, height: renderLayout.fontSize * 1.25),
            renderLayout: renderLayout,
            color: foreground.withAlphaComponent(0.92),
            alignment: .center
        )
        if element.style.showUnit, !renderLayout.components.unit.isEmpty {
            let ruleWidth = renderLayout.fontSize * 0.78
            cursorY -= renderLayout.fontSize * 0.18
            drawRoundedRect(
                CGRect(x: rect.midX - ruleWidth / 2, y: cursorY, width: ruleWidth, height: 0.5),
                color: foreground.withAlphaComponent(0.20),
                cornerRadius: 0
            )
            cursorY -= renderLayout.unitFontSize * 1.4
            drawText(
                renderLayout.components.unit,
                for: element,
                fontSize: renderLayout.unitFontSize,
                in: CGRect(x: rect.minX, y: cursorY, width: rect.width, height: renderLayout.unitFontSize * 1.3),
                renderLayout: renderLayout,
                color: foreground.withAlphaComponent(0.28),
                alignment: .center
            )
        }
    }

    private static func renderDistanceTimeline(
        _ element: OverlayElement,
        renderContext: OverlayRenderContext,
        cache: inout OverlayRenderCache
    ) {
        let renderLayout = OverlayRenderModel.distanceTimelineLayout(for: element, in: renderContext)
        let style = renderLayout.style
        let accent = NSColor(style.fillColor)
        let foreground = NSColor(element.style.foregroundColor)
        let backgroundRect = distanceTimelineBackgroundRect(renderLayout)

        if style.backgroundEnabled {
            drawRoundedRect(backgroundRect, color: NSColor(style.backgroundColor).withAlphaComponent(style.backgroundOpacity), cornerRadius: renderLayout.cornerRadius)
        }
        if style.borderEnabled {
            strokeRoundedRect(
                backgroundRect,
                color: NSColor(style.borderColor).withAlphaComponent(style.borderOpacity),
                cornerRadius: renderLayout.cornerRadius,
                lineWidth: renderLayout.borderWidth
            )
        }

        if let mediaRect = renderLayout.mediaSlotRect {
            drawRoundedRect(mediaRect, color: accent.withAlphaComponent(0.18), cornerRadius: mediaRect.width * 0.28)
            let slot = style.mediaSlot
            if (slot.mode == .staticSVG || slot.mode == .animatedSVG), slot.hasEmbeddedSVG {
                let tint = slot.tintMode == .text ? foreground : accent
                OverlayIconRenderer.draw(
                    slot: slot,
                    in: mediaRect.insetBy(dx: mediaRect.width * 0.12, dy: mediaRect.height * 0.12),
                    elapsedTime: renderLayout.elapsedTime,
                    tintColor: tint
                )
            } else {
                drawPlainText(
                    "􀜤",
                    element: element,
                    fontSize: mediaRect.width * 0.48,
                    color: slot.tintMode == .text ? foreground : accent,
                    rect: mediaRect.insetBy(dx: mediaRect.width * 0.20, dy: mediaRect.height * 0.18),
                    alignment: .center,
                    weight: .semibold
                )
            }
        }

        if style.preset == .route, style.elevationProfileVisible {
            drawDistanceTimelineElevationProfile(renderLayout, color: accent.withAlphaComponent(0.16))
        }

        drawDistanceTimelineText(renderLayout, element: element, foreground: foreground, accent: accent)
        drawDistanceTimelineTrack(renderLayout, foreground: foreground, accent: accent)

        if style.showAxisLabels || style.showDistancePoints {
            drawDistanceTimelineAxisLabels(renderLayout, element: element, foreground: foreground)
        }

        if style.statsBar.visible {
            drawDistanceTimelineStatsBar(renderLayout, element: element, foreground: foreground, accent: accent)
        }
    }

    private static func drawDistanceTimelineText(
        _ layout: OverlayDistanceTimelineRenderLayout,
        element: OverlayElement,
        foreground: NSColor,
        accent: NSColor
    ) {
        let content = layout.contentRect
        if layout.style.showLabel {
            drawPlainText(
                layout.label.uppercased(),
                element: element,
                fontSize: layout.labelFontSize,
                color: foreground.withAlphaComponent(layout.style.preset == .neon ? 0.86 : 0.64),
                rect: CGRect(x: content.minX, y: content.minY, width: content.width * 0.62, height: layout.labelFontSize * 1.3),
                alignment: .left,
                weight: .medium
            )
        }
        let valueScale: Double
        switch layout.style.preset {
        case .lowerThird: valueScale = 1.05
        case .sport: valueScale = 1.12
        case .dense: valueScale = 0.86
        default: valueScale = 1
        }
        let valueY = content.minY + (layout.style.showLabel ? layout.labelFontSize * 1.05 : 0)
        var inlineX = content.minX
        let scale = distanceTimelineStyleScale(layout)
        if layout.style.showValue {
            let valueFont = layout.valueFontSize * valueScale
            drawPlainText(
                layout.valueText,
                element: element,
                fontSize: valueFont,
                color: layout.style.preset == .neon ? NSColor.white.withAlphaComponent(0.92) : foreground,
                rect: CGRect(x: content.minX, y: valueY, width: content.width, height: valueFont * 1.35),
                alignment: .left,
                weight: layout.style.preset == .dense || layout.style.preset == .neon ? .medium : .bold
            )
            inlineX += textSize(layout.valueText, for: element, fontSize: valueFont, shadowRadius: 0, shadowOffsetY: 0).width + layout.style.customValuesGroupSpacing * scale
        }
        if !layout.customValues.isEmpty {
            for item in layout.customValues {
                let text = item.value.isEmpty ? item.label : item.value
                let fontSize = layout.style.customValueFontSize * scale
                let width = textSize(text, for: element, fontSize: fontSize, shadowRadius: 0, shadowOffsetY: 0).width
                drawPlainText(
                    text,
                    element: element,
                    fontSize: fontSize,
                    color: NSColor(layout.style.customValueColor).withAlphaComponent(layout.style.customValueOpacity),
                    rect: CGRect(x: inlineX, y: valueY + max(layout.valueFontSize * valueScale - fontSize, 0) * 0.35, width: width + 8, height: fontSize * 1.3),
                    alignment: .left,
                    weight: .semibold
                )
                inlineX += width + layout.style.customValueSpacing * scale
            }
        }
    }

    private static func drawDistanceTimelineTrack(
        _ layout: OverlayDistanceTimelineRenderLayout,
        foreground: NSColor,
        accent: NSColor
    ) {
        let track = layout.trackRect
        drawCapsule(track, color: foreground.withAlphaComponent(layout.style.trackOpacity))
        if layout.style.preset == .route {
            let fullRoutePath = distanceTimelineRoutePath(points: layout.routePoints, fallbackTrack: track, progress: 1)
            foreground.withAlphaComponent(layout.style.trackOpacity).setStroke()
            fullRoutePath.lineWidth = max(track.height, 2)
            fullRoutePath.lineCapStyle = .round
            fullRoutePath.lineJoinStyle = .round
            fullRoutePath.stroke()

            let path = distanceTimelineRoutePath(
                points: progressedDistanceTimelineRoutePoints(layout),
                fallbackTrack: track,
                progress: layout.progress
            )
            accent.setStroke()
            path.lineWidth = max(track.height, 2)
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        } else {
            drawCapsule(CGRect(x: track.minX, y: track.minY, width: max(track.width * layout.progress, track.height), height: track.height), color: accent)
        }
        if layout.style.tickMarksEnabled {
            drawDistanceTimelineTicks(track, count: max(layout.style.tickDensity, 2), color: foreground.withAlphaComponent(0.52))
        }
        if layout.style.currentMarkerEnabled {
            let markerSize = track.height * 2.2
            let markerCenter: CGPoint
            if layout.style.preset == .route {
                markerCenter = layout.routeCurrentPoint ?? progressedDistanceTimelineRoutePoints(layout).last ?? CGPoint(x: track.minX + track.width * layout.progress, y: track.midY)
            } else {
                markerCenter = CGPoint(x: track.minX + track.width * layout.progress, y: track.midY)
            }
            NSColor.black.withAlphaComponent(0.38).setFill()
            NSBezierPath(ovalIn: CGRect(x: markerCenter.x - markerSize / 2, y: markerCenter.y - markerSize / 2, width: markerSize, height: markerSize)).fill()
            accent.setFill()
            NSBezierPath(ovalIn: CGRect(x: markerCenter.x - markerSize * 0.36, y: markerCenter.y - markerSize * 0.36, width: markerSize * 0.72, height: markerSize * 0.72)).fill()
        }
    }

    private static func progressedDistanceTimelineRoutePoints(_ layout: OverlayDistanceTimelineRenderLayout) -> [CGPoint] {
        guard layout.routePoints.count > 1 else {
            return []
        }
        let targetCount = max(Int((Double(layout.routePoints.count - 1) * layout.progress).rounded(.down)) + 1, 1)
        var points = Array(layout.routePoints.prefix(min(targetCount, layout.routePoints.count)))
        if let current = layout.routeCurrentPoint, points.last != current {
            points.append(current)
        }
        return points
    }

    private static func distanceTimelineRoutePath(points: [CGPoint], fallbackTrack track: CGRect, progress: Double) -> NSBezierPath {
        let path = NSBezierPath()
        guard let first = points.first else {
            path.move(to: CGPoint(x: track.minX, y: track.minY + track.height * 0.70))
            path.curve(
                to: CGPoint(x: track.minX + track.width * progress, y: track.minY + track.height * 0.36),
                controlPoint1: CGPoint(x: track.minX + track.width * 0.25, y: track.minY - track.height * 0.4),
                controlPoint2: CGPoint(x: track.minX + track.width * 0.58, y: track.minY + track.height * 1.6)
            )
            return path
        }
        path.move(to: first)
        for point in points.dropFirst() {
            path.line(to: point)
        }
        return path
    }

    private static func drawDistanceTimelineAxisLabels(_ layout: OverlayDistanceTimelineRenderLayout, element: OverlayElement, foreground: NSColor) {
        let color = foreground.withAlphaComponent(0.58)
        let fontSize = layout.unitFontSize
        if layout.style.showAxisLabels {
            let y = layout.trackRect.maxY + layout.style.distancePointOffset * distanceTimelineStyleScale(layout)
            drawPlainText(layout.startText, element: element, fontSize: fontSize, color: color, rect: CGRect(x: layout.trackRect.minX, y: y, width: layout.trackRect.width / 2, height: fontSize * 1.3), alignment: .left, weight: .medium)
            drawPlainText(layout.finishText, element: element, fontSize: fontSize, color: color, rect: CGRect(x: layout.trackRect.midX, y: y, width: layout.trackRect.width / 2, height: fontSize * 1.3), alignment: .right, weight: .medium)
        }
        if layout.style.showDistancePoints {
            let denominator = Double(layout.distancePointLabels.count + 1)
            let y = layout.trackRect.maxY + layout.style.distancePointOffset * distanceTimelineStyleScale(layout)
            for (index, label) in layout.distancePointLabels.enumerated() {
                let centerX = layout.trackRect.minX + layout.trackRect.width * Double(index + 1) / denominator
                drawPlainText(label, element: element, fontSize: fontSize, color: color, rect: CGRect(x: centerX - 45, y: y, width: 90, height: fontSize * 1.3), alignment: .center, weight: .medium)
            }
        }
    }

    private static func drawDistanceTimelineStatsBar(_ layout: OverlayDistanceTimelineRenderLayout, element: OverlayElement, foreground: NSColor, accent: NSColor) {
        guard !layout.statsBarItems.isEmpty else { return }
        let config = layout.style.statsBar
        let rect = distanceTimelineStatsBarRect(layout, config: config)
        drawSharedStatsBar(
            rect: rect,
            items: layout.statsBarItems,
            valueFontName: config.valueFontName,
            valueFontSize: config.valueFontSize * distanceTimelineStyleScale(layout),
            valueFontWeight: config.valueFontWeight,
            valueColor: NSColor(config.valueColor),
            labelFontName: config.labelFontName,
            labelFontSize: config.labelFontSize * distanceTimelineStyleScale(layout),
            labelFontWeight: config.labelFontWeight,
            labelColor: NSColor(config.labelColor),
            backgroundOpacity: config.backgroundOpacity,
            cornerRadius: config.cornerRadius,
            dividerOpacity: config.dividerOpacity,
            itemSpacing: config.itemSpacing * distanceTimelineStyleScale(layout),
            stacked: config.placement.isVertical || config.layoutMode == .stack
        )
    }

    private static func drawDistanceTimelineStatsBarItem(
        _ item: OverlayDistanceTimelineStatsBarItemLayout,
        element: OverlayElement,
        foreground: NSColor,
        accent: NSColor,
        layout: OverlayDistanceTimelineRenderLayout,
        rect: CGRect
    ) {
        drawPlainText(
            item.value + (item.unit.isEmpty ? "" : " \(item.unit)"),
            element: element,
            fontSize: layout.percentFontSize,
            color: accent,
            rect: CGRect(x: rect.minX, y: rect.minY + rect.height * 0.18, width: rect.width, height: layout.percentFontSize * 1.25),
            alignment: .center,
            weight: .semibold
        )
        drawPlainText(
            item.label.uppercased(),
            element: element,
            fontSize: max(layout.unitFontSize * 0.72, 7),
            color: foreground.withAlphaComponent(0.58),
            rect: CGRect(x: rect.minX, y: rect.minY + rect.height * 0.58, width: rect.width, height: layout.unitFontSize),
            alignment: .center,
            weight: .medium
        )
    }

    private static func distanceTimelineStatsBarRect(_ layout: OverlayDistanceTimelineRenderLayout, config: DistanceTimelineStatsBarConfig) -> CGRect {
        let scale = distanceTimelineStyleScale(layout)
        let baseHeight = config.height * scale
        let autoWidth = config.placement.isVertical ? max(min(config.height * scale, layout.rect.width * 0.34), distanceTimelineStatsBarMinimumVerticalWidth(layout)) : layout.rect.width
        let width = config.width > 0 ? min(config.width * scale, layout.rect.width * 1.4) : autoWidth
        let height = config.placement.isVertical ? max(baseHeight, distanceTimelineStatsBarMinimumVerticalHeight(layout)) : baseHeight
        let offsetX = config.offsetX * scale
        let offsetY = config.offsetY * scale
        let centeredX = layout.rect.minX + (layout.rect.width - width) / 2 + offsetX
        if config.inside {
            switch config.placement {
            case .topAttached, .insideTop:
                let paddingY = layout.style.paddingY * scale
                let naturalY = layout.rect.minY + paddingY + offsetY
                let safeY = layout.trackRect.minY - height - offsetY
                return CGRect(x: centeredX, y: min(naturalY, max(safeY, layout.rect.minY + paddingY)), width: width, height: height)
            case .bottomAttached, .insideBottom:
                let paddingY = layout.style.paddingY * scale
                let naturalY = layout.rect.maxY - height - paddingY - offsetY
                let safeY = layout.trackRect.maxY + offsetY
                return CGRect(x: centeredX, y: max(naturalY, safeY), width: width, height: height)
            case .leftAttached:
                return CGRect(x: layout.rect.minX + layout.style.paddingX * scale + offsetX, y: layout.rect.minY + (layout.rect.height - height) / 2 + offsetY, width: width, height: height)
            case .rightAttached:
                return CGRect(x: layout.rect.maxX - width - layout.style.paddingX * scale - offsetX, y: layout.rect.minY + (layout.rect.height - height) / 2 + offsetY, width: width, height: height)
            }
        }
        switch config.placement {
        case .topAttached, .insideTop:
            return CGRect(x: centeredX, y: layout.rect.minY - height - offsetY, width: width, height: height)
        case .bottomAttached, .insideBottom:
            return CGRect(x: centeredX, y: layout.rect.maxY + offsetY, width: width, height: height)
        case .leftAttached:
            return CGRect(x: layout.rect.minX - width - offsetX, y: layout.rect.minY + (layout.rect.height - height) / 2 + offsetY, width: width, height: height)
        case .rightAttached:
            return CGRect(x: layout.rect.maxX + offsetX, y: layout.rect.minY + (layout.rect.height - height) / 2 + offsetY, width: width, height: height)
        }
    }

    private static func distanceTimelineStyleScale(_ layout: OverlayDistanceTimelineRenderLayout) -> Double {
        layout.rect.width / max(layout.style.width, 1)
    }

    private static func distanceTimelineStatsBarMinimumVerticalHeight(_ layout: OverlayDistanceTimelineRenderLayout) -> Double {
        let count = max(layout.statsBarItems.count, 1)
        let gap = layout.style.statsBar.itemSpacing * distanceTimelineStyleScale(layout)
        let rowHeight = layout.percentFontSize * 1.25 + max(layout.unitFontSize * 0.72, 7) + 8 * distanceTimelineStyleScale(layout)
        return Double(count) * rowHeight + Double(max(count - 1, 0)) * gap
    }

    private static func distanceTimelineStatsBarMinimumVerticalWidth(_ layout: OverlayDistanceTimelineRenderLayout) -> Double {
        let valueFont = layout.percentFontSize
        let labelFont = max(layout.unitFontSize * 0.72, 7)
        let maxValueWidth = layout.statsBarItems.map {
            Double(($0.value + ($0.unit.isEmpty ? "" : " \($0.unit)")).count) * valueFont * 0.62
        }.max() ?? 0
        let maxLabelWidth = layout.statsBarItems.map {
            Double($0.label.uppercased().count) * labelFont * 0.58
        }.max() ?? 0
        return max(maxValueWidth, maxLabelWidth) + 20 * distanceTimelineStyleScale(layout)
    }

    private static func distanceTimelineBackgroundRect(_ layout: OverlayDistanceTimelineRenderLayout) -> CGRect {
        var rect = layout.rect
        let scale = distanceTimelineStyleScale(layout)
        let pad = 6 * scale
        if layout.style.showAxisLabels || layout.style.showDistancePoints {
            let y = layout.trackRect.maxY + layout.style.distancePointOffset * scale
            let labels = CGRect(
                x: layout.rect.minX,
                y: y - layout.unitFontSize * 0.85,
                width: layout.rect.width,
                height: layout.unitFontSize * 1.7
            ).insetBy(dx: -pad, dy: -pad * 0.5)
            rect = rect.union(labels)
        }
        if layout.style.statsBar.visible,
           layout.style.statsBar.inside,
           !layout.statsBarItems.isEmpty {
            let statsRect = distanceTimelineStatsBarRect(layout, config: layout.style.statsBar)
            rect = rect.union(statsRect.insetBy(dx: -pad, dy: -pad))
        }
        return rect
    }

    private static func drawDistanceTimelineTicks(_ track: CGRect, count: Int, color: NSColor) {
        color.setStroke()
        let path = NSBezierPath()
        for index in 0...count {
            let x = track.minX + track.width * Double(index) / Double(max(count, 1))
            path.move(to: CGPoint(x: x, y: track.minY - track.height * 0.45))
            path.line(to: CGPoint(x: x, y: track.maxY + track.height * 0.45))
        }
        path.lineWidth = 1
        path.stroke()
    }

    private static func drawDistanceTimelineElevationProfile(_ layout: OverlayDistanceTimelineRenderLayout, color: NSColor) {
        let samples = layout.elevationSamples
        guard samples.count > 1 else { return }
        let profileRect = CGRect(
            x: layout.contentRect.minX,
            y: layout.contentRect.maxY - layout.contentRect.height * 0.36,
            width: layout.contentRect.width,
            height: layout.contentRect.height * 0.30
        )
        let minValue = samples.min() ?? 0
        let maxValue = samples.max() ?? minValue
        let range = max(maxValue - minValue, 1)
        let path = NSBezierPath()
        path.move(to: CGPoint(x: profileRect.minX, y: profileRect.maxY))
        for index in samples.indices {
            let x = profileRect.minX + profileRect.width * Double(index) / Double(max(samples.count - 1, 1))
            let normalized = (samples[index] - minValue) / range
            let y = profileRect.maxY - profileRect.height * normalized
            path.line(to: CGPoint(x: x, y: y))
        }
        path.line(to: CGPoint(x: profileRect.maxX, y: profileRect.maxY))
        path.close()
        color.setFill()
        path.fill()
    }

    private static func renderElevationChart(
        _ element: OverlayElement,
        renderContext: OverlayRenderContext,
        cache: inout OverlayRenderCache
    ) {
        let renderLayout = OverlayRenderModel.elevationChartLayout(for: element, in: renderContext)
        let style = renderLayout.style
        if style.backgroundEnabled {
            drawRoundedRect(
                renderLayout.rect,
                color: NSColor(style.backgroundColor).withAlphaComponent(style.backgroundOpacity),
                cornerRadius: renderLayout.cornerRadius
            )
            if style.borderEnabled {
                let border = NSBezierPath(roundedRect: renderLayout.rect.insetBy(dx: 0.5, dy: 0.5), xRadius: renderLayout.cornerRadius, yRadius: renderLayout.cornerRadius)
                border.lineWidth = 1
                NSColor.white.withAlphaComponent(style.borderOpacity).setStroke()
                border.stroke()
            }
        }

        let chartRect = CGRect(
            x: renderLayout.rect.minX + renderLayout.horizontalPadding,
            y: renderLayout.rect.maxY - renderLayout.verticalPadding - renderLayout.chartHeight - (style.statsBar.visible ? renderContext.scaled(style.statsBar.height * element.scale + 8) : 0),
            width: renderLayout.rect.width - renderLayout.horizontalPadding * 2,
            height: renderLayout.chartHeight
        )

        if style.bigNumbersEnabled {
            let value = renderLayout.bigNumberText.value + (renderLayout.bigNumberText.unit.isEmpty ? "" : " \(renderLayout.bigNumberText.unit)")
            drawGaugePlainText(
                value,
                fontName: element.style.fontName,
                fontSize: renderLayout.valueFontSize,
                color: NSColor(element.style.foregroundColor),
                rect: CGRect(x: renderLayout.rect.minX, y: renderLayout.rect.minY + renderLayout.verticalPadding, width: renderLayout.rect.width, height: renderLayout.valueFontSize * 1.2),
                alignment: .center,
                weight: .semibold,
                monospacedDigits: true
            )
            drawGaugePlainText(
                renderLayout.bigNumberText.shortLabel,
                fontName: element.style.fontName,
                fontSize: renderLayout.labelFontSize,
                color: NSColor(element.style.foregroundColor).withAlphaComponent(0.62),
                rect: CGRect(x: renderLayout.rect.minX, y: renderLayout.rect.minY + renderLayout.verticalPadding + renderLayout.valueFontSize * 1.05, width: renderLayout.rect.width, height: renderLayout.labelFontSize * 1.4),
                alignment: .center,
                weight: .medium,
                monospacedDigits: false
            )
        }

        if style.gridEnabled {
            for fraction in [0.25, 0.5, 0.75] {
                let y = chartRect.minY + chartRect.height * fraction
                drawLine(from: CGPoint(x: chartRect.minX, y: y), to: CGPoint(x: chartRect.maxX, y: y), color: NSColor.white.withAlphaComponent(0.14), lineWidth: 1)
            }
        }
        if style.fillEnabled, style.chartStyle == .area {
            drawElevationArea(samples: renderLayout.samples, in: chartRect, color: NSColor(style.dualAreaEnabled ? style.upperFillColor : style.fillStartColor).withAlphaComponent(style.fillOpacity))
        }
        drawElevationPath(samples: renderLayout.samples, in: chartRect, color: NSColor(style.lineColor).withAlphaComponent(style.lineOpacity), lineWidth: renderLayout.lineWidth)

        if style.currentMarkerEnabled {
            let marker = elevationMarkerPoint(samples: renderLayout.samples, progress: renderLayout.progress, in: chartRect)
            drawLine(from: CGPoint(x: marker.x, y: chartRect.minY), to: CGPoint(x: marker.x, y: chartRect.maxY), color: NSColor.white.withAlphaComponent(0.28), lineWidth: 1)
            NSColor(style.markerColor).setFill()
            NSBezierPath(ovalIn: CGRect(x: marker.x - 5, y: marker.y - 5, width: 10, height: 10)).fill()
            NSColor.white.withAlphaComponent(0.9).setStroke()
            let ring = NSBezierPath(ovalIn: CGRect(x: marker.x - 6, y: marker.y - 6, width: 12, height: 12))
            ring.lineWidth = 2
            ring.stroke()
        }

        if style.statsBar.visible, !renderLayout.statsBarItems.isEmpty {
            let statsRect = CGRect(
                x: renderLayout.rect.minX + renderLayout.horizontalPadding,
                y: renderLayout.rect.maxY - renderLayout.verticalPadding - renderContext.scaled(style.statsBar.height * element.scale),
                width: renderLayout.rect.width - renderLayout.horizontalPadding * 2,
                height: renderContext.scaled(style.statsBar.height * element.scale)
            )
            drawSharedStatsBar(
                rect: statsRect,
                items: renderLayout.statsBarItems,
                valueFontName: style.statsBar.valueFontName,
                valueFontSize: renderContext.scaled(style.statsBar.valueFontSize * element.scale),
                valueFontWeight: style.statsBar.valueFontWeight,
                valueColor: NSColor(style.statsBar.valueColor),
                labelFontName: style.statsBar.labelFontName,
                labelFontSize: renderContext.scaled(style.statsBar.labelFontSize * element.scale),
                labelFontWeight: style.statsBar.labelFontWeight,
                labelColor: NSColor(style.statsBar.labelColor),
                backgroundOpacity: style.statsBar.backgroundOpacity,
                cornerRadius: style.statsBar.cornerRadius,
                dividerOpacity: style.statsBar.dividerOpacity,
                itemSpacing: style.statsBar.itemSpacing,
                stacked: style.statsBar.placement.isVertical || style.statsBar.layoutMode == .stack
            )
        }
    }

    private static func renderLapList(_ element: OverlayElement, renderContext: OverlayRenderContext) {
        let layout = OverlayRenderModel.lapListLayout(for: element, in: renderContext)
        let fgColor = NSColor(element.style.foregroundColor)

        for row in layout.rows {
            let bg = NSColor.black.withAlphaComponent(layout.backgroundOpacity * row.rowOpacity)
            let path = NSBezierPath(roundedRect: row.rowRect, xRadius: layout.rowCornerRadius, yRadius: layout.rowCornerRadius)
            bg.setFill()
            path.fill()

            if layout.progressBarEnabled && row.progressFraction > 0 {
                let barWidth = row.rowRect.width * row.progressFraction
                let barRect = CGRect(x: row.rowRect.minX, y: row.rowRect.minY, width: barWidth, height: row.rowRect.height)
                let progressBg = NSColor(layout.progressColor).withAlphaComponent(layout.progressOpacity * row.rowOpacity)
                let barPath = NSBezierPath(roundedRect: barRect, xRadius: layout.rowCornerRadius, yRadius: layout.rowCornerRadius)
                progressBg.setFill()
                barPath.fill()
            }

            if row.isCurrent {
                let borderColor = fgColor.withAlphaComponent(0.55 * row.rowOpacity)
                let borderPath = NSBezierPath(roundedRect: row.rowRect.insetBy(dx: 0.5, dy: 0.5), xRadius: layout.rowCornerRadius, yRadius: layout.rowCornerRadius)
                borderPath.lineWidth = 1
                borderColor.setStroke()
                borderPath.stroke()
            }

            let textColor = fgColor.withAlphaComponent(row.rowOpacity)
            let padding: Double = layout.rowHeight * 0.25
            let contentRect = row.rowRect.insetBy(dx: padding, dy: 0)
            let columnCount = row.columnTexts.count
            guard columnCount > 0 else { continue }
            let colWidth = contentRect.width / Double(columnCount)

            for (i, text) in row.columnTexts.enumerated() {
                let colRect = CGRect(
                    x: contentRect.minX + Double(i) * colWidth,
                    y: contentRect.minY,
                    width: colWidth,
                    height: contentRect.height
                )
                let font = NSFont(name: element.style.fontName, size: layout.fontSize)
                    ?? .systemFont(ofSize: layout.fontSize, weight: nsFontWeight(element.style.fontWeight))
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: textColor
                ]
                let str = NSAttributedString(string: text, attributes: attrs)
                let strSize = str.size()
                let textX = i == 0 ? colRect.minX : colRect.midX - strSize.width / 2
                let textY = colRect.midY - strSize.height / 2
                str.draw(at: CGPoint(x: textX, y: textY))
            }
        }
    }

    private static func renderLapCard(_ element: OverlayElement, renderContext: OverlayRenderContext) {
        let layout = OverlayRenderModel.lapCardLayout(for: element, in: renderContext)
        let fgColor = NSColor(element.style.foregroundColor)
        let bg = NSColor.black.withAlphaComponent(layout.backgroundOpacity)
        let cardPath = NSBezierPath(roundedRect: layout.rect, xRadius: layout.cornerRadius, yRadius: layout.cornerRadius)
        bg.setFill()
        cardPath.fill()

        let font = NSFont(name: element.style.fontName, size: layout.fontSize)
            ?? .systemFont(ofSize: layout.fontSize, weight: nsFontWeight(element.style.fontWeight))
        let smallFont = NSFont(name: element.style.fontName, size: layout.fontSize * 0.78)
            ?? .systemFont(ofSize: layout.fontSize * 0.78)

        var curY = layout.rect.minY + layout.verticalPadding

        // Header
        let headerAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: fgColor]
        let headerStr = NSAttributedString(string: layout.headerText, attributes: headerAttrs)
        headerStr.draw(at: CGPoint(x: layout.rect.minX + layout.horizontalPadding, y: curY))
        curY += layout.headerHeight

        // Stat rows
        for (label, value) in layout.columnRows {
            let labelAttrs: [NSAttributedString.Key: Any] = [.font: smallFont, .foregroundColor: fgColor.withAlphaComponent(0.6)]
            let valueAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: fgColor]
            let labelStr = NSAttributedString(string: label, attributes: labelAttrs)
            let valueStr = NSAttributedString(string: value, attributes: valueAttrs)
            let rowY = curY + (layout.rowHeight - layout.fontSize) / 2
            labelStr.draw(at: CGPoint(x: layout.rect.minX + layout.horizontalPadding, y: rowY))
            let valueSize = valueStr.size()
            valueStr.draw(at: CGPoint(x: layout.rect.maxX - layout.horizontalPadding - valueSize.width, y: rowY))
            curY += layout.rowHeight
        }

        // Recovery section
        if layout.showRecoverySection {
            curY += layout.dividerHeight / 2
            let divRect = CGRect(x: layout.rect.minX + layout.horizontalPadding, y: curY,
                                 width: layout.rect.width - layout.horizontalPadding * 2, height: 1)
            NSColor(element.style.foregroundColor).withAlphaComponent(0.25).setFill()
            NSBezierPath(rect: divRect).fill()
            curY += layout.dividerHeight / 2

            let recHeaderAttrs: [NSAttributedString.Key: Any] = [.font: smallFont, .foregroundColor: fgColor.withAlphaComponent(0.55)]
            NSAttributedString(string: "Recovery", attributes: recHeaderAttrs)
                .draw(at: CGPoint(x: layout.rect.minX + layout.horizontalPadding, y: curY))
            curY += layout.recoveryHeaderHeight

            for (label, value) in layout.recoveryRows {
                let labelAttrs: [NSAttributedString.Key: Any] = [.font: smallFont, .foregroundColor: fgColor.withAlphaComponent(0.6)]
                let valueAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(element.style.accentColor)]
                let labelStr = NSAttributedString(string: label, attributes: labelAttrs)
                let valueStr = NSAttributedString(string: value, attributes: valueAttrs)
                let rowY = curY + (layout.rowHeight - layout.fontSize) / 2
                labelStr.draw(at: CGPoint(x: layout.rect.minX + layout.horizontalPadding, y: rowY))
                let valueSize = valueStr.size()
                valueStr.draw(at: CGPoint(x: layout.rect.maxX - layout.horizontalPadding - valueSize.width, y: rowY))
                curY += layout.rowHeight
            }

            if let progress = layout.recoveryProgress, progress > 0 {
                let barH = layout.fontSize * 0.4
                let barRect = CGRect(x: layout.rect.minX + layout.horizontalPadding, y: curY,
                                     width: (layout.rect.width - layout.horizontalPadding * 2) * progress, height: barH)
                NSColor(layout.progressColor).withAlphaComponent(0.55).setFill()
                NSBezierPath(roundedRect: barRect, xRadius: barH / 2, yRadius: barH / 2).fill()
            }
        }
    }

    private static func renderLapLive(_ element: OverlayElement, renderContext: OverlayRenderContext) {
        let layout = OverlayRenderModel.lapLiveLayout(for: element, in: renderContext)
        guard !layout.isHidden else { return }

        let fgColor = NSColor(element.style.foregroundColor)
        let accentColor = NSColor(element.style.accentColor)
        let bg = NSColor.black.withAlphaComponent(layout.backgroundOpacity)
        let cardPath = NSBezierPath(roundedRect: layout.rect, xRadius: layout.cornerRadius, yRadius: layout.cornerRadius)
        bg.setFill()
        cardPath.fill()

        let font = NSFont(name: element.style.fontName, size: layout.fontSize)
            ?? .systemFont(ofSize: layout.fontSize, weight: nsFontWeight(element.style.fontWeight))
        let smallFont = NSFont(name: element.style.fontName, size: layout.fontSize * 0.78)
            ?? .systemFont(ofSize: layout.fontSize * 0.78)

        var curY = layout.rect.minY + layout.verticalPadding

        // Header
        let headerAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: fgColor]
        NSAttributedString(string: layout.headerText, attributes: headerAttrs)
            .draw(at: CGPoint(x: layout.rect.minX + layout.horizontalPadding, y: curY))
        curY += layout.headerHeight

        // Progress bar
        if layout.showProgressBar && layout.progressFraction > 0 {
            let trackRect = CGRect(x: layout.rect.minX, y: curY,
                                   width: layout.rect.width, height: layout.progressBarHeight)
            NSColor.black.withAlphaComponent(0.3).setFill()
            NSBezierPath(rect: trackRect).fill()
            let fillRect = CGRect(x: trackRect.minX, y: trackRect.minY,
                                  width: trackRect.width * layout.progressFraction, height: trackRect.height)
            NSColor(layout.progressColor).withAlphaComponent(layout.progressOpacity).setFill()
            NSBezierPath(rect: fillRect).fill()
            curY += layout.progressBarHeight
        }

        // Active metric rows
        for (label, value) in layout.metricRows {
            let labelAttrs: [NSAttributedString.Key: Any] = [.font: smallFont, .foregroundColor: fgColor.withAlphaComponent(0.6)]
            let valueAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: fgColor]
            let labelStr = NSAttributedString(string: label, attributes: labelAttrs)
            let valueStr = NSAttributedString(string: value, attributes: valueAttrs)
            let rowY = curY + (layout.rowHeight - layout.fontSize) / 2
            labelStr.draw(at: CGPoint(x: layout.rect.minX + layout.horizontalPadding, y: rowY))
            let vSize = valueStr.size()
            valueStr.draw(at: CGPoint(x: layout.rect.maxX - layout.horizontalPadding - vSize.width, y: rowY))
            curY += layout.rowHeight
        }

        // Recovery section (rest mode)
        if layout.isRestMode && !layout.recoveryRows.isEmpty {
            if layout.recoveryHeaderHeight > 0 {
                let recHeaderAttrs: [NSAttributedString.Key: Any] = [.font: smallFont, .foregroundColor: fgColor.withAlphaComponent(0.55)]
                NSAttributedString(string: "Recovery", attributes: recHeaderAttrs)
                    .draw(at: CGPoint(x: layout.rect.minX + layout.horizontalPadding, y: curY))
                curY += layout.recoveryHeaderHeight
            }
            for (label, value) in layout.recoveryRows {
                let labelAttrs: [NSAttributedString.Key: Any] = [.font: smallFont, .foregroundColor: fgColor.withAlphaComponent(0.6)]
                let valueAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: accentColor]
                let labelStr = NSAttributedString(string: label, attributes: labelAttrs)
                let valueStr = NSAttributedString(string: value, attributes: valueAttrs)
                let rowY = curY + (layout.rowHeight - layout.fontSize) / 2
                labelStr.draw(at: CGPoint(x: layout.rect.minX + layout.horizontalPadding, y: rowY))
                let vSize = valueStr.size()
                valueStr.draw(at: CGPoint(x: layout.rect.maxX - layout.horizontalPadding - vSize.width, y: rowY))
                curY += layout.rowHeight
            }

            if let progress = layout.recoveryProgress, progress > 0 {
                let barH = layout.fontSize * 0.35
                let barRect = CGRect(x: layout.rect.minX + layout.horizontalPadding, y: curY,
                                     width: (layout.rect.width - layout.horizontalPadding * 2) * progress, height: barH)
                NSColor(layout.progressColor).withAlphaComponent(0.55).setFill()
                NSBezierPath(roundedRect: barRect, xRadius: barH / 2, yRadius: barH / 2).fill()
            }
        }
    }

    private static func renderRunningGauge(_ element: OverlayElement, renderContext: OverlayRenderContext) {
        let layout = OverlayRenderModel.runningGaugeLayout(for: element, in: renderContext)
        let style = layout.style
        let rect = layout.rect
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2

        // Dial background
        NSColor(style.dialBackgroundColor).withAlphaComponent(style.dialBackgroundOpacity).setFill()
        NSBezierPath(ovalIn: rect).fill()

        // Outer ring
        if style.outerRingEnabled {
            strokeCircle(
                center: center,
                radius: radius - layout.outerRingWidth / 2,
                color: NSColor(style.outerRingColor).withAlphaComponent(style.outerRingOpacity),
                lineWidth: layout.outerRingWidth
            )
        }

        // Tick marks
        if style.tickMarksEnabled {
            drawGaugeTicks(
                center: center,
                radius: radius - layout.outerRingWidth - layout.tickLength * 0.6,
                tickCount: max(style.tickCount, 6),
                majorEvery: max(style.majorTickEvery, 1),
                tickLength: layout.tickLength,
                majorTickLength: layout.majorTickLength,
                lineWidth: max(style.dividerWidth, 1),
                color: NSColor(style.tickColor),
                tickAlpha: style.tickOpacity,
                majorAlpha: style.majorTickOpacity
            )
        }

        // Progress ring
        if style.progressRingEnabled {
            let ringRadius = radius - layout.outerRingWidth - layout.progressRingWidth - 2
            strokeCircle(
                center: center,
                radius: ringRadius,
                color: NSColor(style.progressTrackColor).withAlphaComponent(style.progressTrackOpacity),
                lineWidth: layout.progressRingWidth
            )
            strokeArc(
                center: center,
                radius: ringRadius,
                startAngle: -90,
                endAngle: -90 + 360 * layout.progress,
                color: NSColor(style.progressColor),
                lineWidth: layout.progressRingWidth
            )
        }

        // Dividers
        if style.dividerEnabled {
            drawGaugeDividers(
                style: style,
                gaugeRect: rect,
                lineWidth: max(style.dividerWidth, 1),
                safeRadius: layout.safeRadius
            )
        }

        // Data regions
        for region in layout.regions {
            drawGaugeRegion(region, style: style)
        }
    }

    private static func drawGaugeRegion(
        _ region: OverlayRunningGaugeRegionLayout,
        style: RunningGaugeStyle
    ) {
        let config = region.config
        let label = config.customLabel.isEmpty ? config.metric.compactLabel : config.customLabel.uppercased()
        let valueColor = NSColor(config.valueColor ?? style.primaryTextColor)
        let labelColor = NSColor(config.labelColor ?? style.secondaryTextColor).withAlphaComponent(0.78)
        let unitColor = labelColor

        var cursorY = region.rect.minY
        if config.showLabel {
            let labelRect = CGRect(
                x: region.rect.minX,
                y: cursorY,
                width: region.rect.width,
                height: region.labelFontSize * 1.40
            )
            drawGaugePlainText(
                label,
                fontName: style.fontName,
                fontSize: region.labelFontSize,
                color: labelColor,
                rect: labelRect,
                alignment: .center,
                weight: nsFontWeight(config.labelWeight),
                monospacedDigits: style.monospacedDigits
            )
            cursorY += region.labelFontSize * 1.10
        }

        let valueText = region.components.value
        let valueRect = CGRect(
            x: region.rect.minX,
            y: cursorY,
            width: region.rect.width,
            height: region.valueFontSize * 1.30
        )
        drawGaugePlainText(
            valueText,
            fontName: style.fontName,
            fontSize: region.valueFontSize,
            color: valueColor,
            rect: valueRect,
            alignment: .center,
            weight: nsFontWeight(config.valueWeight),
            monospacedDigits: style.monospacedDigits
        )

        if config.showUnit, !region.components.unit.isEmpty {
            let unitRect = CGRect(
                x: region.rect.minX,
                y: cursorY + region.valueFontSize * 1.05,
                width: region.rect.width,
                height: region.unitFontSize * 1.30
            )
            drawGaugePlainText(
                region.components.unit,
                fontName: style.fontName,
                fontSize: region.unitFontSize,
                color: unitColor,
                rect: unitRect,
                alignment: .center,
                weight: .medium,
                monospacedDigits: style.monospacedDigits
            )
        }
    }

    private static func drawGaugePlainText(
        _ text: String,
        fontName: String,
        fontSize: Double,
        color: NSColor,
        rect: CGRect,
        alignment: NSTextAlignment,
        weight: NSFont.Weight,
        monospacedDigits: Bool
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        var font = NSFont(name: fontName, size: fontSize) ?? .systemFont(ofSize: fontSize, weight: weight)
        if monospacedDigits {
            font = NSFontManager.shared.font(withFamily: font.familyName ?? font.fontName,
                                             traits: [], weight: 5, size: fontSize) ?? font
            // monospaced digits feature
            let descriptor = font.fontDescriptor.addingAttributes([
                .featureSettings: [
                    [
                        NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
                        NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector
                    ]
                ]
            ])
            if let monoFont = NSFont(descriptor: descriptor, size: fontSize) {
                font = monoFont
            }
        }
        NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle
            ]
        ).draw(in: rect)
    }

    private static func nsFontWeight(_ weight: OverlayFontWeight) -> NSFont.Weight {
        switch weight {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }

    private static func renderRouteMap(_ element: OverlayElement, renderContext: OverlayRenderContext) {
        let layout = OverlayRenderModel.routeMapLayout(for: element, in: renderContext)
        let accent = NSColor(element.style.foregroundColor)
        let backgroundOpacity: Double = switch layout.preset {
        case .glow: max(element.style.backgroundOpacity, 0.34)
        default:
            element.style.routeMapBackgroundStyle == .none
                ? element.style.backgroundOpacity
                : max(element.style.backgroundOpacity, 0.72)
        }

        let shouldUseFadeMask = layout.edgeFade == .fadeOut && layout.fadeAmount > 0.001
        let clipMask = shouldUseFadeMask ? RouteMapMaskRenderer.makeCGMask(
            size: layout.rect.size,
            shape: layout.shape,
            cornerRadius: layout.cornerRadius,
            edgeFade: layout.edgeFade,
            fadeAmount: layout.fadeAmount
        ) : nil

        if let cgContext = NSGraphicsContext.current?.cgContext, let clipMask, shouldUseFadeMask {
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

        if let statsBar = layout.statsBarLayout {
            drawRouteMapStatsBar(layout: statsBar)
        }
    }

    private static func drawRouteMapStatsBar(layout: OverlayRouteMapStatsBarLayout) {
        guard !layout.items.isEmpty else { return }

        if layout.isInside {
            NSGraphicsContext.saveGraphicsState()
            RouteMapMaskRenderer.shapePath(
                shape: layout.containerShape,
                rect: layout.containerRect,
                cornerRadius: layout.containerCornerRadius
            ).addClip()
        }

        let sharedItems = layout.items.map {
            OverlayDistanceTimelineStatsBarItemLayout(label: $0.label, value: $0.value, unit: $0.unit)
        }
        drawSharedStatsBar(
            rect: layout.rect,
            items: sharedItems,
            valueFontName: layout.valueFontName,
            valueFontSize: layout.valueFontSize,
            valueFontWeight: layout.valueFontWeight,
            valueColor: NSColor(layout.valueColor),
            labelFontName: layout.labelFontName,
            labelFontSize: layout.labelFontSize,
            labelFontWeight: layout.labelFontWeight,
            labelColor: NSColor(layout.labelColor),
            backgroundOpacity: layout.backgroundOpacity,
            cornerRadius: layout.cornerRadius,
            dividerOpacity: layout.dividerOpacity,
            itemSpacing: layout.itemSpacing,
            stacked: layout.placement.isVertical || layout.layoutMode == .stack
        )
        if layout.isInside {
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    private static func drawSharedStatsBar(
        rect: CGRect,
        items: [OverlayDistanceTimelineStatsBarItemLayout],
        valueFontName: String,
        valueFontSize: Double,
        valueFontWeight: OverlayFontWeight,
        valueColor: NSColor,
        labelFontName: String,
        labelFontSize: Double,
        labelFontWeight: OverlayFontWeight,
        labelColor: NSColor,
        backgroundOpacity: Double,
        cornerRadius: Double,
        dividerOpacity: Double,
        itemSpacing: Double,
        stacked: Bool
    ) {
        guard !items.isEmpty else { return }
        drawRoundedRect(rect, color: NSColor.black.withAlphaComponent(backgroundOpacity), cornerRadius: cornerRadius)
        let gap = max(itemSpacing, 0)
        if stacked {
            let slotHeight = (rect.height - gap * Double(max(items.count - 1, 0))) / Double(items.count)
            for (index, item) in items.enumerated() {
                let y = rect.minY + Double(index) * (slotHeight + gap)
                if index > 0, dividerOpacity > 0 {
                    drawLine(from: CGPoint(x: rect.minX + 6, y: y - gap / 2), to: CGPoint(x: rect.maxX - 6, y: y - gap / 2), color: labelColor.withAlphaComponent(dividerOpacity), lineWidth: 1)
                }
                drawSharedStatsBarItem(
                    item,
                    valueFontName: valueFontName,
                    valueFontWeight: valueFontWeight,
                    valueColor: valueColor,
                    labelFontName: labelFontName,
                    labelFontWeight: labelFontWeight,
                    labelColor: labelColor,
                    valueFontSize: valueFontSize,
                    labelFontSize: labelFontSize,
                    rect: CGRect(x: rect.minX, y: y, width: rect.width, height: slotHeight)
                )
            }
        } else {
            let slotWidth = (rect.width - gap * Double(max(items.count - 1, 0))) / Double(items.count)
            for (index, item) in items.enumerated() {
                let x = rect.minX + Double(index) * (slotWidth + gap)
                if index > 0, dividerOpacity > 0 {
                    drawLine(from: CGPoint(x: x - gap / 2, y: rect.minY + 6), to: CGPoint(x: x - gap / 2, y: rect.maxY - 6), color: labelColor.withAlphaComponent(dividerOpacity), lineWidth: 1)
                }
                drawSharedStatsBarItem(
                    item,
                    valueFontName: valueFontName,
                    valueFontWeight: valueFontWeight,
                    valueColor: valueColor,
                    labelFontName: labelFontName,
                    labelFontWeight: labelFontWeight,
                    labelColor: labelColor,
                    valueFontSize: valueFontSize,
                    labelFontSize: labelFontSize,
                    rect: CGRect(x: x, y: rect.minY, width: slotWidth, height: rect.height)
                )
            }
        }
    }

    private static func drawSharedStatsBarItem(
        _ item: OverlayDistanceTimelineStatsBarItemLayout,
        valueFontName: String,
        valueFontWeight: OverlayFontWeight,
        valueColor: NSColor,
        labelFontName: String,
        labelFontWeight: OverlayFontWeight,
        labelColor: NSColor,
        valueFontSize: Double,
        labelFontSize: Double,
        rect: CGRect
    ) {
        drawGaugePlainText(item.value + (item.unit.isEmpty ? "" : " \(item.unit)"),
                           fontName: valueFontName, fontSize: valueFontSize,
                           color: valueColor,
                           rect: CGRect(x: rect.minX, y: rect.minY + rect.height * 0.18, width: rect.width, height: valueFontSize * 1.25),
                           alignment: .center, weight: nsFontWeight(valueFontWeight), monospacedDigits: true)
        drawGaugePlainText(item.label.uppercased(),
                           fontName: labelFontName, fontSize: labelFontSize,
                           color: labelColor,
                           rect: CGRect(x: rect.minX, y: rect.minY + rect.height * 0.58, width: rect.width, height: labelFontSize * 1.2),
                           alignment: .center, weight: nsFontWeight(labelFontWeight), monospacedDigits: false)
    }

    private static func drawStatsBarVerticalStack(layout: OverlayRouteMapStatsBarLayout) {
        let items = layout.items
        guard !items.isEmpty else { return }

        let gap = max(layout.itemSpacing, 0)
        let rowH = (layout.rect.height - gap * Double(max(items.count - 1, 0))) / Double(items.count)
        guard rowH > 1 else { return }

        // Reuse the column renderer per vertical cell so typography stays consistent.
        let vFS = rowH * 0.34
        let uFS = rowH * 0.20
        let lFS = rowH * 0.18

        for (i, item) in items.enumerated() {
            let y = layout.rect.minY + Double(i) * (rowH + gap)
            let cell = CGRect(x: layout.rect.minX, y: y, width: layout.rect.width, height: rowH)
            drawStatsColumn(item: item, cell: cell, fontName: layout.fontName, vFS: vFS, uFS: uFS, lFS: lFS)

            if i < items.count - 1 {
                NSColor.white.withAlphaComponent(layout.dividerOpacity).setFill()
                NSBezierPath(rect: CGRect(
                    x: layout.rect.minX + layout.rect.width * 0.08,
                    y: cell.maxY + gap * 0.5 - 0.5,
                    width: layout.rect.width * 0.84,
                    height: 1
                )).fill()
            }
        }
    }

    // MARK: - Stats bar layout modes

    private static func drawStatsBarEqualColumns(layout: OverlayRouteMapStatsBarLayout) {
        let n = Double(layout.items.count)
        guard n > 0 else { return }
        let gap = max(layout.itemSpacing, 0)
        let cellW = (layout.rect.width - gap * max(n - 1, 0)) / n
        let H = layout.rect.height
        for (i, item) in layout.items.enumerated() {
            let x = layout.rect.minX + Double(i) * (cellW + gap)
            let cell = CGRect(x: x, y: layout.rect.minY, width: cellW, height: H)
            drawStatsColumn(item: item, cell: cell, fontName: layout.fontName,
                            vFS: H * 0.38, uFS: H * 0.22, lFS: H * 0.20)
            if i < layout.items.count - 1 {
                drawStatsVerticalDivider(x: cell.maxX, barRect: layout.rect, opacity: layout.dividerOpacity)
            }
        }
    }

    private static func drawStatsBarEmphasis(layout: OverlayRouteMapStatsBarLayout) {
        guard !layout.items.isEmpty else { return }
        let gap = max(layout.itemSpacing, 0)
        let H = layout.rect.height
        let firstW = max((layout.rect.width - gap) * 0.38, 1)
        let firstCell = CGRect(x: layout.rect.minX, y: layout.rect.minY, width: firstW, height: H)
        drawStatsColumn(item: layout.items[0], cell: firstCell, fontName: layout.fontName,
                        vFS: H * 0.46, uFS: H * 0.26, lFS: H * 0.20)
        if layout.items.count > 1 {
            drawStatsVerticalDivider(x: firstCell.maxX, barRect: layout.rect, opacity: layout.dividerOpacity)
            let rest = Array(layout.items.dropFirst())
            let restGapCount = Double(max(rest.count - 1, 0))
            let cellW = (layout.rect.width - firstW - gap - (gap * restGapCount)) / Double(rest.count)
            for (i, item) in rest.enumerated() {
                let x = firstCell.maxX + gap + Double(i) * (cellW + gap)
                let cell = CGRect(x: x, y: layout.rect.minY, width: cellW, height: H)
                drawStatsColumn(item: item, cell: cell, fontName: layout.fontName,
                                vFS: H * 0.33, uFS: H * 0.19, lFS: H * 0.17)
                if i < rest.count - 1 {
                    drawStatsVerticalDivider(x: cell.maxX, barRect: layout.rect, opacity: layout.dividerOpacity)
                }
            }
        }
    }

    private static func drawStatsBarGrid2x2(layout: OverlayRouteMapStatsBarLayout) {
        let items = layout.items
        guard !items.isEmpty else { return }
        if items.count < 3 { drawStatsBarEqualColumns(layout: layout); return }
        let H = layout.rect.height
        let rowH = H * 0.5
        let col0W = layout.rect.width * 0.5
        let col1W = layout.rect.width - col0W
        let vFS = rowH * 0.40, uFS = rowH * 0.22, lFS = rowH * 0.18
        // Row 0
        let r0y = layout.rect.minY
        let cell00 = CGRect(x: layout.rect.minX, y: r0y, width: col0W, height: rowH)
        let cell01 = CGRect(x: layout.rect.minX + col0W, y: r0y, width: col1W, height: rowH)
        drawStatsColumn(item: items[0], cell: cell00, fontName: layout.fontName, vFS: vFS, uFS: uFS, lFS: lFS)
        drawStatsVerticalDivider(x: cell00.maxX, barRect: layout.rect, opacity: layout.dividerOpacity)
        drawStatsColumn(item: items[1], cell: cell01, fontName: layout.fontName, vFS: vFS, uFS: uFS, lFS: lFS)
        // Horizontal divider
        NSColor.white.withAlphaComponent(layout.dividerOpacity).setFill()
        NSBezierPath(rect: CGRect(x: layout.rect.minX + layout.rect.width * 0.05, y: r0y + rowH - 0.5,
                                   width: layout.rect.width * 0.90, height: 1)).fill()
        // Row 1
        let r1y = r0y + rowH
        if items.count == 3 {
            drawStatsColumn(item: items[2], cell: CGRect(x: layout.rect.minX, y: r1y, width: layout.rect.width, height: rowH),
                            fontName: layout.fontName, vFS: vFS, uFS: uFS, lFS: lFS)
        } else {
            let cell10 = CGRect(x: layout.rect.minX, y: r1y, width: col0W, height: rowH)
            let cell11 = CGRect(x: layout.rect.minX + col0W, y: r1y, width: col1W, height: rowH)
            drawStatsColumn(item: items[2], cell: cell10, fontName: layout.fontName, vFS: vFS, uFS: uFS, lFS: lFS)
            drawStatsVerticalDivider(x: cell10.maxX, barRect: layout.rect, opacity: layout.dividerOpacity)
            drawStatsColumn(item: items[3], cell: cell11, fontName: layout.fontName, vFS: vFS, uFS: uFS, lFS: lFS)
        }
    }

    private static func drawStatsBarStack(layout: OverlayRouteMapStatsBarLayout) {
        let items = layout.items
        guard !items.isEmpty else { return }
        let gap = max(layout.itemSpacing, 0)
        let rowH = (layout.rect.height - gap * Double(max(items.count - 1, 0))) / Double(items.count)
        let H = layout.rect.height
        let vFS = min(rowH * 0.42, H * 0.28)
        let lFS = min(rowH * 0.28, H * 0.18)
        let labelW = layout.rect.width * 0.32
        let valueW = layout.rect.width - labelW
        for (i, item) in items.enumerated() {
            let rowY = layout.rect.minY + Double(i) * (rowH + gap)
            let rowRect = CGRect(x: layout.rect.minX, y: rowY, width: layout.rect.width, height: rowH)
            let labelRect = CGRect(x: rowRect.minX + 6, y: rowRect.minY, width: labelW - 6, height: rowH)
            let inlineText = item.unit.isEmpty ? item.value : "\(item.value) \(item.unit)"
            let valueRect = CGRect(x: rowRect.minX + labelW, y: rowRect.minY, width: valueW - 6, height: rowH)
            drawGaugePlainText(item.label.uppercased(), fontName: layout.fontName, fontSize: lFS,
                               color: NSColor.white.withAlphaComponent(0.50), rect: labelRect,
                               alignment: .left, weight: .medium, monospacedDigits: false)
            drawGaugePlainText(inlineText, fontName: layout.fontName, fontSize: vFS,
                               color: .white, rect: valueRect, alignment: .right, weight: .semibold, monospacedDigits: false)
            if i < items.count - 1 {
                NSColor.white.withAlphaComponent(layout.dividerOpacity).setFill()
                NSBezierPath(rect: CGRect(x: layout.rect.minX + layout.rect.width * 0.05, y: rowRect.maxY - 0.5,
                                           width: layout.rect.width * 0.90, height: 1)).fill()
            }
        }
    }

    private static func drawStatsBarCompact(layout: OverlayRouteMapStatsBarLayout) {
        let n = Double(layout.items.count)
        guard n > 0 else { return }
        let gap = max(layout.itemSpacing, 0)
        let cellW = (layout.rect.width - gap * max(n - 1, 0)) / n
        let H = layout.rect.height
        let vFS = H * 0.34, uFS = H * 0.20, lFS = H * 0.16
        for (i, item) in layout.items.enumerated() {
            let x = layout.rect.minX + Double(i) * (cellW + gap)
            let cell = CGRect(x: x, y: layout.rect.minY, width: cellW, height: H)
            let midY = cell.minY + cell.height * 0.14
            let valRect  = CGRect(x: cell.minX, y: midY, width: cellW * 0.58, height: vFS * 1.3)
            let unitRect = CGRect(x: cell.minX + cellW * 0.58, y: midY + vFS * 0.18, width: cellW * 0.36, height: vFS * 1.3)
            let lblRect  = CGRect(x: cell.minX, y: cell.maxY - lFS * 1.4, width: cellW, height: lFS * 1.3)
            drawGaugePlainText(item.value, fontName: layout.fontName, fontSize: vFS,
                               color: .white, rect: valRect, alignment: .right, weight: .semibold, monospacedDigits: false)
            if !item.unit.isEmpty {
                drawGaugePlainText(item.unit, fontName: layout.fontName, fontSize: uFS,
                                   color: NSColor.white.withAlphaComponent(0.65), rect: unitRect,
                                   alignment: .left, weight: .medium, monospacedDigits: false)
            }
            drawGaugePlainText(item.label.uppercased(), fontName: layout.fontName, fontSize: lFS,
                               color: NSColor.white.withAlphaComponent(0.45), rect: lblRect,
                               alignment: .center, weight: .medium, monospacedDigits: false)
            if i < layout.items.count - 1 {
                drawStatsVerticalDivider(x: cell.maxX, barRect: layout.rect, opacity: layout.dividerOpacity)
            }
        }
    }

    // MARK: - Stats bar drawing helpers

    private static func drawStatsColumn(
        item: OverlayRouteMapStatsBarItemLayout,
        cell: CGRect, fontName: String,
        vFS: Double, uFS: Double, lFS: Double
    ) {
        let valueY = cell.minY + cell.height * 0.12
        let valueRect = CGRect(x: cell.minX, y: valueY, width: cell.width, height: vFS * 1.30)
        let unitRect  = CGRect(x: cell.minX, y: valueY + vFS * 1.05, width: cell.width, height: uFS * 1.30)
        let labelRect = CGRect(x: cell.minX, y: cell.maxY - lFS * 1.40, width: cell.width, height: lFS * 1.30)
        drawGaugePlainText(item.value, fontName: fontName, fontSize: vFS,
                           color: .white, rect: valueRect, alignment: .center, weight: .semibold, monospacedDigits: false)
        if !item.unit.isEmpty {
            drawGaugePlainText(item.unit, fontName: fontName, fontSize: uFS,
                               color: NSColor.white.withAlphaComponent(0.70), rect: unitRect,
                               alignment: .center, weight: .medium, monospacedDigits: false)
        }
        drawGaugePlainText(item.label.uppercased(), fontName: fontName, fontSize: lFS,
                           color: NSColor.white.withAlphaComponent(0.50), rect: labelRect,
                           alignment: .center, weight: .medium, monospacedDigits: false)
    }

    private static func drawStatsVerticalDivider(x: Double, barRect: CGRect, opacity: Double) {
        NSColor.white.withAlphaComponent(opacity).setFill()
        NSBezierPath(rect: CGRect(
            x: x - 0.5, y: barRect.minY + barRect.height * 0.15,
            width: 1, height: barRect.height * 0.70
        )).fill()
    }

    private static func drawRouteMapContent(
        element: OverlayElement,
        layout: OverlayRouteMapRenderLayout,
        accent: NSColor,
        backgroundOpacity: Double
    ) {
        NSColor.black.withAlphaComponent(backgroundOpacity).setFill()
        RouteMapMaskRenderer.shapePath(shape: layout.shape, rect: layout.rect, cornerRadius: layout.cornerRadius).fill()

        if element.style.routeMapBackgroundStyle != .none {
            drawMapGrid(in: layout.rect, style: element.style.routeMapBackgroundStyle, opacity: layout.mapOpacity)
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
        drawRouteMarker(layout.projectedCurrentPoint, color: NSColor(element.style.routeMapRunnerDotColor), lineWidth: layout.lineWidth * 1.18)

    }

    private static func strokeRouteMapBorder(layout: OverlayRouteMapRenderLayout, isSelected: Bool) {
        guard isSelected || layout.borderVisible else { return }
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

    private static func drawMapGrid(in rect: CGRect, style: OverlayRouteMapBackgroundStyle, opacity: Double) {
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
        let dimmer = max(min(opacity, 1), 0)
        switch style {
        case .light:
            NSColor.black.withAlphaComponent(0.10 * dimmer).setStroke()
        case .terrain:
            NSColor.systemGreen.withAlphaComponent(0.18 * dimmer).setStroke()
        case .satellite:
            NSColor.white.withAlphaComponent(0.06 * dimmer).setStroke()
        case .none, .dark:
            NSColor.white.withAlphaComponent(0.08 * dimmer).setStroke()
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
        case .inlineGhost:
            let labelHeight = element.style.showLabel ? labelSize.height + renderLayout.fontSize * 0.06 : 0
            let unitWidth = element.style.showUnit ? unitSize.width + renderLayout.fontSize * 0.18 : 0
            size = CGSize(
                width: valueSize.width + unitWidth,
                height: labelHeight + valueSize.height
            )
        case .accentBar:
            let barWidth = max(renderLayout.fontSize * 0.083, 1.5) + renderLayout.fontSize * 0.33
            let labelHeight = element.style.showLabel ? labelSize.height : 0
            let unitHeight = element.style.showUnit ? unitSize.height : 0
            let textHeight = labelHeight + valueSize.height + unitHeight
            size = CGSize(
                width: barWidth + max(labelSize.width, valueSize.width, unitSize.width),
                height: max(textHeight, renderLayout.fontSize * 1.55)
            )
        case .sportNeon:
            let labelHeight = element.style.showLabel ? labelSize.height : 0
            let unitHeight = element.style.showUnit ? max(unitSize.height, renderLayout.fontSize * 0.14) + renderLayout.unitFontSize * 0.6 : 0
            size = CGSize(
                width: max(valueSize.width, labelSize.width, unitSize.width + renderLayout.fontSize * 1.0),
                height: labelHeight + valueSize.height + unitHeight
            )
        case .serifEditorial:
            let labelHeight = element.style.showLabel ? labelSize.height : 0
            let unitHeight = element.style.showUnit ? unitSize.height + renderLayout.fontSize * 0.36 : 0
            size = CGSize(
                width: max(valueSize.width, labelSize.width, renderLayout.fontSize * 0.78, unitSize.width),
                height: labelHeight + valueSize.height + unitHeight
            )
        case .minimalLabel:
            let labelHeight = element.style.showLabel ? labelSize.height + renderLayout.fontSize * 0.10 : 0
            let unitWidth = element.style.showUnit ? unitSize.width + renderLayout.fontSize * 0.16 : 0
            size = CGSize(
                width: valueSize.width + unitWidth,
                height: labelHeight + valueSize.height
            )
        case .neonGlow:
            let unitWidth = element.style.showUnit ? unitSize.width + renderLayout.fontSize * 0.16 : 0
            size = CGSize(
                width: valueSize.width + unitWidth + renderLayout.fontSize * 0.8,
                height: valueSize.height + renderLayout.fontSize * 0.4
            )
        case .racingStripe:
            let stripeWidth = max(renderLayout.fontSize * 0.12, 4) + renderLayout.fontSize * 0.34
            let labelHeight = element.style.showLabel ? labelSize.height + renderLayout.fontSize * 0.10 : 0
            let unitWidth = element.style.showUnit ? unitSize.width + renderLayout.fontSize * 0.16 : 0
            size = CGSize(
                width: stripeWidth + max(labelSize.width, valueSize.width + unitWidth) + renderLayout.horizontalPadding * 2,
                height: labelHeight + valueSize.height + renderLayout.verticalPadding * 2
            )
        case .editorial:
            let labelHeight = element.style.showLabel ? labelSize.height + renderLayout.fontSize * 0.10 : 0
            let unitWidth = element.style.showUnit ? unitSize.width + renderLayout.fontSize * 0.10 : 0
            size = CGSize(
                width: max(labelSize.width, valueSize.width + unitWidth, renderLayout.fontSize * 2.2),
                height: labelHeight + valueSize.height + renderLayout.fontSize * 0.30
            )
        case .digitalWatch:
            let labelHeight = element.style.showLabel ? labelSize.height + renderLayout.fontSize * 0.10 : 0
            let unitWidth = element.style.showUnit ? unitSize.width + renderLayout.fontSize * 0.14 : 0
            size = CGSize(
                width: max(labelSize.width, valueSize.width + unitWidth) + renderLayout.horizontalPadding * 2,
                height: labelHeight + valueSize.height + renderLayout.verticalPadding * 2
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
        color: NSColor? = nil,
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
        if let color {
            attributes[.foregroundColor] = color
        }
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

    private static func drawLine(from start: CGPoint, to end: CGPoint, color: NSColor, lineWidth: Double) {
        color.setStroke()
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
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

    private static func drawElevationArea(samples: [Double], in rect: CGRect, color: NSColor) {
        let path = NSBezierPath()
        guard samples.count > 1 else { return }

        let minValue = samples.min() ?? 0
        let maxValue = samples.max() ?? minValue
        let range = max(maxValue - minValue, 1)

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for index in samples.indices {
            let x = rect.minX + rect.width * Double(index) / Double(max(samples.count - 1, 1))
            let normalized = (samples[index] - minValue) / range
            let y = rect.maxY - rect.height * normalized
            path.line(to: CGPoint(x: x, y: y))
        }
        path.line(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.close()
        color.setFill()
        path.fill()
    }

    private static func elevationMarkerPoint(samples: [Double], progress: Double, in rect: CGRect) -> CGPoint {
        guard !samples.isEmpty else {
            return CGPoint(x: rect.minX + rect.width * progress, y: rect.midY)
        }
        let index = min(max(Int((Double(samples.count - 1) * progress).rounded()), 0), samples.count - 1)
        let minValue = samples.min() ?? 0
        let maxValue = samples.max() ?? minValue
        let range = max(maxValue - minValue, 1)
        let x = rect.minX + rect.width * Double(index) / Double(max(samples.count - 1, 1))
        let y = rect.maxY - rect.height * ((samples[index] - minValue) / range)
        return CGPoint(x: x, y: y)
    }

    private static func drawGaugeDividers(
        style: RunningGaugeStyle,
        gaugeRect: CGRect,
        lineWidth: Double,
        safeRadius: Double
    ) {
        let center = CGPoint(x: gaugeRect.midX, y: gaugeRect.midY)
        let safeBounds = CGRect(
            x: center.x - safeRadius,
            y: center.y - safeRadius,
            width: safeRadius * 2,
            height: safeRadius * 2
        )
        let segments = RunningGaugeLayoutEngine.dividerSegments(for: style.layoutPreset)
        let path = NSBezierPath()
        for (start, end) in segments {
            let p0 = CGPoint(
                x: safeBounds.minX + start.x * safeBounds.width,
                y: safeBounds.minY + start.y * safeBounds.height
            )
            let p1 = CGPoint(
                x: safeBounds.minX + end.x * safeBounds.width,
                y: safeBounds.minY + end.y * safeBounds.height
            )
            path.move(to: p0)
            path.line(to: p1)
        }
        NSColor(style.dividerColor).withAlphaComponent(style.dividerOpacity).setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }

    private static func drawGaugeTicks(
        center: CGPoint,
        radius: Double,
        tickCount: Int,
        majorEvery: Int,
        tickLength: Double,
        majorTickLength: Double,
        lineWidth: Double,
        color: NSColor,
        tickAlpha: Double,
        majorAlpha: Double
    ) {
        for index in 0..<tickCount {
            let angle = Double(index) / Double(tickCount) * 2 * Double.pi - Double.pi / 2
            let isMajor = index.isMultiple(of: majorEvery)
            let length = isMajor ? majorTickLength : tickLength
            let outer = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            let inner = CGPoint(x: center.x + cos(angle) * (radius - length), y: center.y + sin(angle) * (radius - length))
            let path = NSBezierPath()
            path.move(to: inner)
            path.line(to: outer)
            color.withAlphaComponent(isMajor ? majorAlpha : tickAlpha).setStroke()
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

        let buffer = baseAddress
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

    private static func flipBitmapRowsVertically(_ bitmap: NSBitmapImageRep) {
        guard let baseAddress = bitmap.bitmapData else {
            return
        }

        let height = bitmap.pixelsHigh
        let bytesPerRow = bitmap.bytesPerRow
        guard height > 1, bytesPerRow > 0 else {
            return
        }

        let buffer = baseAddress
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
