#if canImport(CSkiaBridge)
import AppKit
import CSkiaBridge
import CoreGraphics
import Foundation

/// Skia drawing for the Weather Widget overlay.
///
/// `OverlayRenderModel.weatherWidgetLayout` supplies all content strings and
/// the card rect. This module reproduces the five SwiftUI presets: palette
/// tokens, card background, divider rules, metric slots, and per-preset text
/// fitting. Images come from `SkiaRenderAssets`.
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

        let scale = rect.width / max(layout.style.width, 1)
        switch layout.style.preset {
        case .simpleCard:
            drawSimpleCard(
                layout: layout,
                scale: scale,
                context: context,
                assets: assets
            )
        case .compactStrip:
            drawCompactStrip(
                layout: layout,
                scale: scale,
                context: context,
                assets: assets
            )
        case .forecastTile:
            drawForecastTile(
                layout: layout,
                scale: scale,
                context: context,
                assets: assets
            )
        case .minimalText:
            drawMinimalText(
                layout: layout,
                scale: scale,
                context: context,
                assets: assets
            )
        case .dashboardBar:
            drawDashboardBar(
                layout: layout,
                scale: scale,
                context: context,
                assets: assets
            )
        }
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

    // MARK: - Compact Strip

    private static func drawCompactStrip(
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

        let spacing = 10 * scale
        let iconSize = 34 * scale
        let available = rect.width - 32 * scale

        var secondary: [(WeatherTextStyle, FittedText)] = []
        if style.showConditionLabel {
            secondary.append((
                style.conditionTextStyle,
                fitted(
                    layout.conditionLabel,
                    style: style.conditionTextStyle,
                    scale: scale,
                    maxWidth: available,
                    minScale: 1,
                    assets: assets
                )
            ))
        }
        if style.showLocation, !layout.locationText.isEmpty {
            secondary.append((
                style.locationTextStyle,
                fitted(
                    layout.locationText,
                    style: style.locationTextStyle,
                    scale: scale,
                    maxWidth: available,
                    minScale: 1,
                    assets: assets
                )
            ))
        }
        let secondaryWidth = secondary.map(\.1.line.width).max() ?? 0
        let secondaryHeight = secondary.reduce(0) { $0 + $1.1.line.height }
            + (secondary.count > 1 ? Double(secondary.count - 1) * scale : 0)

        let childCount = (style.showIcon ? 1 : 0) + 1 + (secondary.isEmpty ? 0 : 1) + 1
        let gaps = Double(max(childCount - 1, 0)) * spacing
        let fixedWidth = (style.showIcon ? iconSize : 0)
            + secondaryWidth
            + gaps
        let temperatureMax = max(available - fixedWidth, 1)
        let temperature = fitted(
            layout.temperatureFormatted,
            style: style.temperatureTextStyle,
            scale: scale,
            maxWidth: temperatureMax,
            minScale: 0.75,
            assets: assets
        )

        var x = rect.minX + 16 * scale
        if style.showIcon {
            drawIcon(
                layout.condition,
                size: iconSize,
                centerX: x + iconSize / 2,
                centerY: rect.midY,
                context: context,
                assets: assets
            )
            x += iconSize + spacing
        }

        SkiaRouteWeatherText.draw(
            temperature.line,
            font: temperature.font,
            x: x,
            top: rect.midY - temperature.line.height / 2,
            color: style.temperatureTextStyle.color,
            context: context
        )
        x += temperature.line.width + spacing

        if !secondary.isEmpty {
            var y = rect.midY - secondaryHeight / 2
            for (textStyle, text) in secondary {
                SkiaRouteWeatherText.draw(
                    text.line,
                    font: text.font,
                    x: x,
                    top: y,
                    color: textStyle.color,
                    context: context
                )
                y += text.line.height + scale
            }
        }
    }

    // MARK: - Forecast Tile

    private static func drawForecastTile(
        layout: WeatherWidgetRenderLayout,
        scale: Double,
        context: OpaquePointer,
        assets: SkiaRenderAssets
    ) {
        let style = layout.style
        let rect = layout.rect
        let horizontalPadding = 12 * scale
        let contentWidth = rect.width - horizontalPadding * 2
        let dividerThickness = max(1, style.dividerThickness * scale)

        let metricsWidth = rect.width - 40 * scale
        let metricCount = layout.metricSlots.count
        let metricSpacing = 7 * scale
        let metricGaps = Double(max(metricCount - 1, 0))
            * (metricSpacing + 1)
        let metricCellWidth = metricCount > 0
            ? max((metricsWidth - metricGaps) / Double(metricCount), 1)
            : 0

        func makeTexts(forceMinScale: Bool) -> ForecastTexts {
            let location = style.showLocation
                ? fitted(
                    layout.locationText,
                    style: style.locationTextStyle,
                    scale: scale,
                    maxWidth: contentWidth,
                    minScale: 0.68,
                    assets: assets,
                    forceMinScale: forceMinScale
                )
                : nil
            let weekday = style.showWeekday && !layout.weekdayText.isEmpty
                ? fitted(
                    layout.weekdayText,
                    style: style.slotTitleTextStyle,
                    scale: scale,
                    maxWidth: contentWidth,
                    minScale: 1,
                    assets: assets,
                    forceMinScale: forceMinScale
                )
                : nil
            let temperature = fitted(
                layout.temperatureFormatted,
                style: style.temperatureTextStyle,
                scale: scale,
                maxWidth: contentWidth,
                minScale: 0.72,
                assets: assets,
                forceMinScale: forceMinScale
            )
            let metrics = layout.metricSlots.map { metric in
                fitted(
                    inlineMetricText(metric),
                    style: style.slotLabelTextStyle,
                    scale: scale,
                    maxWidth: metricCellWidth,
                    minScale: 0.75,
                    assets: assets,
                    forceMinScale: forceMinScale
                )
            }
            return ForecastTexts(
                location: location,
                weekday: weekday,
                temperature: temperature,
                metrics: metrics
            )
        }

        func metricsRowHeight(_ texts: ForecastTexts) -> Double {
            // Metric dividers are 18pt tall in the SwiftUI HStack.
            let textHeight = texts.metrics.map(\.line.height).max() ?? 0
            let dividerHeight = style.dividerEnabled && texts.metrics.count > 1
                ? 18 * scale
                : 0
            return max(textHeight, dividerHeight)
        }

        func contentHeight(_ texts: ForecastTexts, metricsRow: Double) -> Double {
            var height = 0.0
            if let location = texts.location {
                height += 15 * scale + location.line.height
            }
            if let weekday = texts.weekday {
                height += 2 * scale + weekday.line.height
            }
            height += style.dividerEnabled
                ? 8 * scale + dividerThickness + 7 * scale
                : 5 * scale
            if style.showIcon { height += 58 * scale }
            height += 4 * scale + texts.temperature.line.height
            height += style.dividerEnabled
                ? 7 * scale + dividerThickness + 8 * scale
                : 5 * scale
            height += metricsRow
            height += 14 * scale
            return height
        }

        var texts = makeTexts(forceMinScale: false)
        var metricsRow = metricsRowHeight(texts)
        var height = contentHeight(texts, metricsRow: metricsRow)

        // SwiftUI's VStack hugs its intrinsic height. When the text content is
        // taller than `layout.rect`, SwiftUI collapses every text that has a
        // `minimumScaleFactor` to that minimum, then centers the overflow.
        if height > rect.height {
            texts = makeTexts(forceMinScale: true)
            metricsRow = metricsRowHeight(texts)
            height = contentHeight(texts, metricsRow: metricsRow)
        }

        let cardRect = CGRect(
            x: rect.minX,
            y: rect.midY - height / 2,
            width: rect.width,
            height: height
        )
        drawCardBackground(
            layout: layout,
            scale: scale,
            context: context,
            cardRect: cardRect
        )

        var y = cardRect.minY

        if let location = texts.location {
            SkiaRouteWeatherText.drawCentered(
                location.line,
                font: location.font,
                centerX: rect.midX,
                top: y + 15 * scale,
                color: style.locationTextStyle.color,
                context: context
            )
            y += 15 * scale + location.line.height
        }
        if let weekday = texts.weekday {
            SkiaRouteWeatherText.drawCentered(
                weekday.line,
                font: weekday.font,
                centerX: rect.midX,
                top: y + 2 * scale,
                color: style.slotTitleTextStyle.color,
                context: context
            )
            y += 2 * scale + weekday.line.height
        }

        if style.dividerEnabled {
            drawHorizontalDivider(
                x: rect.minX + horizontalPadding + 8 * scale,
                width: rect.width - (horizontalPadding + 8 * scale) * 2,
                y: y + 8 * scale,
                thickness: dividerThickness,
                style: style,
                context: context
            )
            y += 8 * scale + dividerThickness + 7 * scale
        } else {
            y += 5 * scale
        }

        if style.showIcon {
            drawIcon(
                layout.condition,
                size: 54 * scale,
                centerX: rect.midX,
                centerY: y + 29 * scale,
                context: context,
                assets: assets
            )
            y += 58 * scale
        }

        SkiaRouteWeatherText.drawCentered(
            texts.temperature.line,
            font: texts.temperature.font,
            centerX: rect.midX,
            top: y + 4 * scale,
            color: style.temperatureTextStyle.color,
            context: context
        )
        y += 4 * scale + texts.temperature.line.height

        if style.dividerEnabled {
            drawHorizontalDivider(
                x: rect.minX + horizontalPadding + 8 * scale,
                width: rect.width - (horizontalPadding + 8 * scale) * 2,
                y: y + 7 * scale,
                thickness: dividerThickness,
                style: style,
                context: context
            )
            y += 7 * scale + dividerThickness + 8 * scale
        } else {
            y += 5 * scale
        }

        let rowTop = y
        var x = rect.minX + 20 * scale
        for (index, text) in texts.metrics.enumerated() {
            let cell = CGRect(
                x: x,
                y: rowTop,
                width: metricCellWidth,
                height: metricsRow
            )
            SkiaRouteWeatherText.drawCentered(
                text.line,
                font: text.font,
                centerX: cell.midX,
                top: cell.midY - text.line.height / 2,
                color: style.slotLabelTextStyle.color,
                context: context
            )
            x += metricCellWidth + metricSpacing
            if index < texts.metrics.count - 1 {
                skb_fill_rect(
                    context,
                    Float(x),
                    Float(rowTop + (metricsRow - 18 * scale) / 2),
                    Float(1),
                    Float(18 * scale),
                    Float(style.dividerColor.red),
                    Float(style.dividerColor.green),
                    Float(style.dividerColor.blue),
                    Float(style.dividerOpacity)
                )
                x += 1 + metricSpacing
            }
        }
    }

    // MARK: - Minimal Text

    private static func drawMinimalText(
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

        // SwiftUI applies `weatherReadabilityShadow` to the whole minimal-text
        // widget: black 0.55, radius 8, y 2.
        skb_begin_shadow_layer(
            context,
            8,
            0, 2,
            Float(rect.minX),
            Float(rect.minY),
            Float(rect.width),
            Float(rect.height),
            0, 0, 0, 0.55
        )
        defer { skb_restore(context) }

        let x = rect.minX + 4 * scale
        let maxWidth = rect.width - 8 * scale
        let spacing = 4 * scale

        let location = style.showLocation
            ? fitted(
                layout.locationText,
                style: style.locationTextStyle,
                scale: scale,
                maxWidth: maxWidth,
                minScale: 0.7,
                assets: assets
            )
            : nil
        let temperature = fitted(
            layout.temperatureFormatted,
            style: style.temperatureTextStyle,
            scale: scale,
            maxWidth: maxWidth,
            minScale: 0.7,
            assets: assets
        )
        let condition = style.showConditionLabel
            ? fitted(
                layout.conditionLabel,
                style: style.conditionTextStyle,
                scale: scale,
                maxWidth: maxWidth,
                minScale: 1,
                assets: assets
            )
            : nil

        let iconSize = 30 * scale
        let rowHeight = max(temperature.line.height, style.showIcon ? iconSize : 0)
        let rowSpacing = style.showIcon ? 7 * scale : 0

        var totalHeight = rowHeight
        if let location { totalHeight += location.line.height + spacing }
        if let condition { totalHeight += condition.line.height + spacing }

        var y = rect.midY - totalHeight / 2
        if let location {
            SkiaRouteWeatherText.draw(
                location.line,
                font: location.font,
                x: x,
                top: y,
                color: style.locationTextStyle.color,
                context: context
            )
            y += location.line.height + spacing
        }

        SkiaRouteWeatherText.draw(
            temperature.line,
            font: temperature.font,
            x: x,
            top: y + (rowHeight - temperature.line.height) / 2,
            color: style.temperatureTextStyle.color,
            context: context
        )
        if style.showIcon {
            drawIcon(
                layout.condition,
                size: iconSize,
                centerX: x + temperature.line.width + rowSpacing + iconSize / 2,
                centerY: y + rowHeight / 2,
                context: context,
                assets: assets
            )
        }
        y += rowHeight + spacing

        if let condition {
            SkiaRouteWeatherText.draw(
                condition.line,
                font: condition.font,
                x: x,
                top: y,
                color: style.conditionTextStyle.color,
                context: context
            )
        }
    }

    // MARK: - Dashboard Bar

    private static func drawDashboardBar(
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

        let leftWidth = rect.width * 0.27
        let leftSpacing = 3 * scale
        var leftEntries: [TextEntry] = []
        if style.showLocation {
            leftEntries.append(TextEntry(
                text: layout.locationText,
                style: style.locationTextStyle,
                minScale: 0.62
            ))
        }
        if style.showConditionLabel {
            leftEntries.append(TextEntry(
                text: layout.conditionLabel,
                style: style.conditionTextStyle,
                minScale: 1
            ))
        }

        var leftY = rect.midY - stackHeight(
            leftEntries,
            spacing: leftSpacing,
            scale: scale,
            assets: assets
        ) / 2
        for entry in leftEntries {
            let text = fitted(
                entry.text,
                style: entry.style,
                scale: scale,
                maxWidth: leftWidth,
                minScale: entry.minScale,
                assets: assets
            )
            SkiaRouteWeatherText.draw(
                text.line,
                font: text.font,
                x: rect.minX + 20 * scale,
                top: leftY,
                color: entry.style.color,
                context: context
            )
            leftY += text.line.height + leftSpacing
        }

        var x = rect.minX + 20 * scale + leftWidth + 16 * scale
        if style.showIcon {
            let iconSize = 44 * scale
            drawIcon(
                layout.condition,
                size: iconSize,
                centerX: x + iconSize / 2,
                centerY: rect.midY,
                context: context,
                assets: assets
            )
            x += iconSize + 16 * scale
        }

        let temperature = fitted(
            layout.temperatureFormatted,
            style: style.temperatureTextStyle,
            scale: scale,
            maxWidth: max(rect.maxX - 20 * scale - x, 1),
            minScale: 0.72,
            assets: assets
        )
        SkiaRouteWeatherText.draw(
            temperature.line,
            font: temperature.font,
            x: x,
            top: rect.midY - temperature.line.height / 2,
            color: style.temperatureTextStyle.color,
            context: context
        )

        let chipWidth = 68 * scale
        let chipHeight = 58 * scale
        let chipSpacing = style.slotSpacing * scale
        let chipCount = layout.metricSlots.count
        let chipsWidth = Double(chipCount) * chipWidth
            + Double(max(chipCount - 1, 0)) * chipSpacing
        var chipX = max(rect.maxX - 20 * scale - chipsWidth, x)

        for metric in layout.metricSlots {
            let chipRect = CGRect(
                x: chipX,
                y: rect.midY - chipHeight / 2,
                width: chipWidth,
                height: chipHeight
            )
            skb_fill_round_rect(
                context,
                Float(chipRect.minX),
                Float(chipRect.minY),
                Float(chipRect.width),
                Float(chipRect.height),
                Float(8 * scale),
                Float(style.slotBackgroundColor.red),
                Float(style.slotBackgroundColor.green),
                Float(style.slotBackgroundColor.blue),
                Float(style.slotBackgroundOpacity)
            )

            let contentWidth = chipWidth - 16 * scale
            let label = fitted(
                metric.label,
                style: style.slotTitleTextStyle,
                scale: scale,
                maxWidth: contentWidth,
                minScale: 0.68,
                assets: assets
            )
            let value = fitted(
                metric.value,
                style: style.slotLabelTextStyle,
                scale: scale,
                maxWidth: contentWidth,
                minScale: 0.58,
                assets: assets
            )
            let totalHeight = label.line.height + 4 * scale + value.line.height
            var y = chipRect.midY - totalHeight / 2
            SkiaRouteWeatherText.drawCentered(
                label.line,
                font: label.font,
                centerX: chipRect.midX,
                top: y,
                color: style.slotTitleTextStyle.color,
                context: context
            )
            y += label.line.height + 4 * scale
            SkiaRouteWeatherText.drawCentered(
                value.line,
                font: value.font,
                centerX: chipRect.midX,
                top: y,
                color: style.slotLabelTextStyle.color,
                context: context
            )

            chipX += chipWidth + chipSpacing
        }
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
        let palette = style.palette == .presetDefault
            ? defaultPalette(for: style.preset)
            : style.palette
        switch palette {
        case .blueGlass:
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
        case .presetDefault:
            // Unreachable: presetDefault resolves before this switch.
            return Tokens(
                start: OverlayColor(red: 0, green: 0, blue: 0, alpha: 0),
                end: OverlayColor(red: 0, green: 0, blue: 0, alpha: 0),
                strokeColor: OverlayColor(red: 0, green: 0, blue: 0, alpha: 0),
                strokeOpacity: 0,
                shadowAlpha: 0,
                hasBackground: false
            )
        }
    }

    private static func defaultPalette(
        for preset: WeatherWidgetPreset
    ) -> WeatherWidgetPalette {
        switch preset {
        case .simpleCard: .blueGlass
        case .compactStrip: .lightGlass
        case .forecastTile: .graphite
        case .minimalText: .minimalWhite
        case .dashboardBar: .graphite
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

    private struct ForecastTexts {
        var location: FittedText?
        var weekday: FittedText?
        var temperature: FittedText
        var metrics: [FittedText]
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

    private static func stackHeight(
        _ entries: [TextEntry],
        spacing: Double,
        scale: Double,
        assets: SkiaRenderAssets
    ) -> Double {
        guard !entries.isEmpty else { return 0 }
        let heights = entries.map { entry in
            fitted(
                entry.text,
                style: entry.style,
                scale: scale,
                maxWidth: .greatestFiniteMagnitude,
                minScale: entry.minScale,
                assets: assets
            ).line.height
        }
        return heights.reduce(0, +) + Double(heights.count - 1) * spacing
    }

    private static func drawHorizontalDivider(
        x: Double,
        width: Double,
        y: Double,
        thickness: Double,
        style: WeatherWidgetStyle,
        context: OpaquePointer
    ) {
        skb_fill_rect(
            context,
            Float(x),
            Float(y),
            Float(max(width, 0)),
            Float(thickness),
            Float(style.dividerColor.red),
            Float(style.dividerColor.green),
            Float(style.dividerColor.blue),
            Float(style.dividerOpacity)
        )
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
