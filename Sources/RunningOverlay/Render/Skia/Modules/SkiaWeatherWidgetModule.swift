#if canImport(CSkiaBridge)
import AppKit
import CSkiaBridge
import CoreGraphics
import Foundation

/// Skia drawing for the Weather Widget overlay.
///
/// `OverlayRenderModel.weatherWidgetLayout` supplies all content strings and
/// the card rect. This module reproduces the SwiftUI card: palette tokens,
/// card background, divider rules, metric slots, and text fitting. Images come
/// from `SkiaRenderAssets`.
enum SkiaWeatherWidgetModule {
    static func preloadAssets(
        elements: [OverlayElement],
        activity: ActivityTimeline,
        canvasSize: CGSize,
        into assets: SkiaRenderAssets
    ) {
        SkiaRenderAssets.preloadWeatherIcons(
            elements: elements,
            activity: activity,
            canvasSize: canvasSize,
            into: assets
        )
    }

    static func draw(
        _ element: OverlayElement,
        renderContext: OverlayRenderContext,
        context: OpaquePointer,
        assets: SkiaRenderAssets
    ) {
        let layout = OverlayRenderModel.weatherWidgetLayout(
            for: element,
            in: renderContext
        )
        let rect = layout.rect
        guard rect.width > 0, rect.height > 0 else { return }

        let usesOpacityLayer = element.opacity < 0.999
        if usesOpacityLayer {
            skb_begin_opacity_layer(
                context,
                Float(element.opacity),
                0, 0,
                Float(renderContext.canvasSize.width),
                Float(renderContext.canvasSize.height)
            )
        }
        defer {
            if usesOpacityLayer {
                skb_restore(context)
            }
        }

        drawSimpleCard(
            layout: layout,
            scale: rect.width / max(layout.style.width, 1),
            context: context,
            assets: assets
        )
    }

    // MARK: - Simple Card

    private static func drawSimpleCard(
        layout: WeatherWidgetRenderLayout,
        scale: Double,
        context: OpaquePointer,
        assets: SkiaRenderAssets
    ) {
        let style = layout.style
        let rect = layout.rect
        drawCardBackground(
            layout: layout,
            scale: scale,
            context: context
        )

        let leftX = rect.minX + 18 * scale
        let leftWidth = rect.width * 0.40
        let spacing = 7 * scale

        let condition = style.showConditionLabel
            ? fitted(
                layout.conditionLabel,
                style: style.conditionTextStyle,
                scale: scale,
                maxWidth: leftWidth,
                minScale: 0.72,
                assets: assets
            )
            : nil

        let iconFrameWidth = 82 * scale
        let iconFrameHeight = 54 * scale
        let iconSize = 58 * scale

        let leftTotal = (condition?.line.height ?? 0)
            + (condition != nil && style.showIcon ? spacing : 0)
            + (style.showIcon ? iconFrameHeight : 0)
        var leftY = rect.midY - leftTotal / 2

        if let condition {
            SkiaRouteWeatherText.draw(
                condition.line,
                font: condition.font,
                x: leftX,
                top: leftY,
                color: style.conditionTextStyle.color,
                context: context
            )
            leftY += condition.line.height + spacing
        }

        if style.showIcon {
            drawIcon(
                layout.condition,
                size: iconSize,
                centerX: leftX + 4 * scale + iconFrameWidth / 2,
                centerY: leftY + iconFrameHeight / 2,
                context: context,
                assets: assets
            )
        }

        let dividerX = rect.minX + leftWidth + 18 * scale
        let dividerWidth = max(1, style.dividerThickness * scale)
        if style.dividerEnabled {
            skb_fill_rect(
                context,
                Float(dividerX),
                Float(rect.minY + 18 * scale),
                Float(dividerWidth),
                Float(max(rect.height - 36 * scale, 0)),
                Float(style.dividerColor.red),
                Float(style.dividerColor.green),
                Float(style.dividerColor.blue),
                Float(style.dividerOpacity)
            )
        }

        let rightX = dividerX
            + (style.dividerEnabled ? dividerWidth : 0)
            + 16 * scale
        let rightWidth = max(rect.maxX - 18 * scale - rightX, 1)

        var entries: [TextEntry] = []
        if style.showLocation {
            entries.append(TextEntry(
                text: layout.locationText,
                style: style.locationTextStyle,
                minScale: 0.65
            ))
        }
        if style.showWeekday, !layout.weekdayText.isEmpty {
            entries.append(TextEntry(
                text: layout.weekdayText,
                style: style.slotTitleTextStyle,
                minScale: 1
            ))
        }
        entries.append(TextEntry(
            text: layout.temperatureFormatted,
            style: style.temperatureTextStyle,
            minScale: 0.72
        ))
        if let metric = layout.metricSlots.first {
            entries.append(TextEntry(
                text: inlineMetricText(metric),
                style: style.slotLabelTextStyle,
                minScale: 1
            ))
        }

        drawStack(
            entries,
            x: rightX,
            maxWidth: rightWidth,
            spacing: 3 * scale,
            centerY: rect.midY,
            scale: scale,
            context: context,
            assets: assets
        )
    }

    // MARK: - Card background

    private struct Tokens {
        var start: OverlayColor
        var end: OverlayColor
        var strokeColor: OverlayColor
        var strokeOpacity: Double
        var shadowAlpha: Double
        var hasBackground: Bool
    }

    private static func drawCardBackground(
        layout: WeatherWidgetRenderLayout,
        scale: Double,
        context: OpaquePointer,
        cardRect: CGRect? = nil
    ) {
        let style = layout.style
        let tokens = tokens(for: style)
        guard tokens.hasBackground else { return }

        let rect = cardRect ?? layout.rect
        let radius = style.cardCornerRadius * scale
        let shadowSigma = max(4, layout.rect.width * 0.025)
        let shadowY = max(2, layout.rect.height * 0.04)
        let shadow = tokens.shadowAlpha > 0

        if shadow {
            skb_begin_shadow_layer(
                context,
                Float(shadowSigma),
                0, Float(shadowY),
                Float(rect.minX),
                Float(rect.minY),
                Float(rect.width),
                Float(rect.height),
                0, 0, 0, Float(tokens.shadowAlpha)
            )
        }

        skb_fill_diagonal_gradient_round_rect(
            context,
            Float(rect.minX),
            Float(rect.minY),
            Float(rect.width),
            Float(rect.height),
            Float(radius),
            Float(tokens.start.red),
            Float(tokens.start.green),
            Float(tokens.start.blue),
            Float(style.cardBackgroundOpacity),
            Float(tokens.end.red),
            Float(tokens.end.green),
            Float(tokens.end.blue),
            Float(style.cardBackgroundOpacity)
        )

        if tokens.strokeOpacity > 0 {
            skb_stroke_round_rect(
                context,
                Float(rect.minX),
                Float(rect.minY),
                Float(rect.width),
                Float(rect.height),
                Float(radius),
                Float(max(1, scale)),
                Float(tokens.strokeColor.red),
                Float(tokens.strokeColor.green),
                Float(tokens.strokeColor.blue),
                Float(tokens.strokeOpacity)
            )
        }

        if shadow {
            skb_restore(context)
        }
    }

    private static func tokens(for style: WeatherWidgetStyle) -> Tokens {
        switch style.palette {
        case .blueGlass, .presetDefault:
            return Tokens(
                start: OverlayColor(red: 0.38, green: 0.68, blue: 1.0, alpha: 1),
                end: OverlayColor(red: 0.22, green: 0.50, blue: 0.92, alpha: 1),
                strokeColor: .white,
                strokeOpacity: 0.18,
                shadowAlpha: 0.22,
                hasBackground: true
            )
        case .lightGlass:
            return Tokens(
                start: OverlayColor(red: 0.96, green: 0.98, blue: 1.0, alpha: 1),
                end: OverlayColor(red: 0.82, green: 0.91, blue: 1.0, alpha: 1),
                strokeColor: OverlayColor(red: 0.42, green: 0.64, blue: 0.90, alpha: 1),
                strokeOpacity: 0.26,
                shadowAlpha: 0.12,
                hasBackground: true
            )
        case .graphite:
            return Tokens(
                start: OverlayColor(red: 0.07, green: 0.10, blue: 0.15, alpha: 1),
                end: OverlayColor(red: 0.13, green: 0.20, blue: 0.28, alpha: 1),
                strokeColor: .white,
                strokeOpacity: 0.16,
                shadowAlpha: 0.25,
                hasBackground: true
            )
        case .minimalWhite:
            let clear = OverlayColor(red: 0, green: 0, blue: 0, alpha: 0)
            return Tokens(
                start: clear,
                end: clear,
                strokeColor: clear,
                strokeOpacity: 0,
                shadowAlpha: 0.45,
                hasBackground: false
            )
        }
    }

    // MARK: - Shared drawing helpers

    private struct TextEntry {
        var text: String
        var style: WeatherTextStyle
        var minScale: Double
    }

    private struct FittedText {
        var font: NSFont
        var line: SkiaRouteWeatherText.Line
    }

    private static func fitted(
        _ text: String,
        style: WeatherTextStyle,
        scale: Double,
        maxWidth: Double,
        minScale: Double,
        assets: SkiaRenderAssets,
        forceMinScale: Bool = false
    ) -> FittedText {
        let baseSize = max(1, style.fontSize * scale)
        if forceMinScale {
            let size = max(baseSize * minScale, 1)
            let font = assets.font(
                family: style.fontName,
                size: size,
                weight: weight(style.fontWeight)
            )
            let fitted = SkiaRouteWeatherText.fittedLine(
                text,
                font: font,
                maxWidth: maxWidth,
                minScale: 1
            )
            return FittedText(font: fitted.font, line: fitted.line)
        }
        let font = assets.font(
            family: style.fontName,
            size: baseSize,
            weight: weight(style.fontWeight)
        )
        let fitted = SkiaRouteWeatherText.fittedLine(
            text,
            font: font,
            maxWidth: maxWidth,
            minScale: minScale
        )
        return FittedText(font: fitted.font, line: fitted.line)
    }

    private static func drawStack(
        _ entries: [TextEntry],
        x: Double,
        maxWidth: Double,
        spacing: Double,
        centerY: Double,
        scale: Double,
        context: OpaquePointer,
        assets: SkiaRenderAssets
    ) {
        guard !entries.isEmpty else { return }
        let lines = entries.map { entry in
            (
                entry.style,
                fitted(
                    entry.text,
                    style: entry.style,
                    scale: scale,
                    maxWidth: maxWidth,
                    minScale: entry.minScale,
                    assets: assets
                )
            )
        }
        let totalHeight = lines.reduce(0) { $0 + $1.1.line.height }
            + Double(lines.count - 1) * spacing
        var y = centerY - totalHeight / 2
        for (textStyle, text) in lines {
            SkiaRouteWeatherText.draw(
                text.line,
                font: text.font,
                x: x,
                top: y,
                color: textStyle.color,
                context: context
            )
            y += text.line.height + spacing
        }
    }

    private static func drawIcon(
        _ condition: WeatherCondition,
        size: Double,
        centerX: Double,
        centerY: Double,
        context: OpaquePointer,
        assets: SkiaRenderAssets
    ) {
        let pixelSize = max(Int(size.rounded(.up)), 1)
        let key = SkiaRenderAssets.ImageSource.weatherIcon(
            condition,
            pixelSize: pixelSize
        )
        guard let image = assets.image(for: key) else { return }
        skb_draw_image_handle(
            context,
            image,
            Float(centerX - size / 2),
            Float(centerY - size / 2),
            Float(size),
            Float(size),
            1,
            0, 0, 0, 0
        )
    }

    private static func inlineMetricText(_ metric: WeatherMetricSlotRender) -> String {
        metric.kind == .feelsLike
            ? "\(metric.label) \(metric.value)"
            : metric.value
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
