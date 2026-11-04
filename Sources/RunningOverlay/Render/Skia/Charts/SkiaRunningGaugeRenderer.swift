#if canImport(CSkiaBridge)
import CSkiaBridge
import AppKit
import CoreGraphics
import Foundation

/// Skia port of `RunningGaugeOverlayView`.
enum SkiaRunningGaugeRenderer {
    static func draw(
        canvas: SkiaChartsCanvas,
        element: OverlayElement,
        layout: OverlayRunningGaugeRenderLayout
    ) {
        let style = layout.style
        let rect = layout.rect
        let diameter = layout.diameter
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = diameter / 2

        let effectBounds = rect.insetBy(
            dx: -max(layout.outerRingWidth, layout.progressRingWidth) - 4,
            dy: -max(layout.outerRingWidth, layout.progressRingWidth) - 4
        )

        var restores = 0
        let alpha = min(max(element.opacity, 0), 1)
        if alpha < 0.999 {
            canvas.beginOpacityLayer(alpha: alpha, bounds: effectBounds)
            restores += 1
        }
        restores += canvas.beginElementEffects(
            style: element.style,
            bounds: effectBounds
        )
        defer {
            for _ in 0..<restores {
                canvas.restore()
            }
        }

        canvas.fillCircle(
            center: center,
            radius: radius,
            color: style.dialBackgroundColor.withAlpha(
                style.dialBackgroundColor.alpha * style.dialBackgroundOpacity
            )
        )

        if style.glassEffectEnabled {
            let width = max(layout.outerRingWidth * 0.5, 1)
            let blurRadius = layout.outerRingWidth * 0.4
            let glassBounds = rect.insetBy(dx: -width, dy: -width)
            skb_begin_blur_layer(
                canvas.context,
                Float(blurRadius),
                Float(glassBounds.minX),
                Float(glassBounds.minY),
                Float(glassBounds.width),
                Float(glassBounds.height)
            )
            strokeCircle(
                canvas: canvas,
                center: center,
                radius: radius,
                width: width,
                color: OverlayColor(red: 1, green: 1, blue: 1, alpha: 0.18)
            )
            canvas.restore()
        }

        if style.outerRingEnabled {
            strokeCircle(
                canvas: canvas,
                center: center,
                radius: radius - layout.outerRingWidth / 2,
                width: layout.outerRingWidth,
                color: style.outerRingColor.withAlpha(
                    style.outerRingColor.alpha * style.outerRingOpacity
                )
            )
        }

        if style.tickMarksEnabled {
            drawTicks(canvas: canvas, style: style, layout: layout, center: center)
        }

        if style.progressRingEnabled {
            let inset = layout.outerRingWidth + layout.progressRingWidth + 2
            let ringRadius = max((diameter - inset * 2) / 2, 0)
            strokeCircle(
                canvas: canvas,
                center: center,
                radius: ringRadius,
                width: layout.progressRingWidth,
                color: style.progressTrackColor.withAlpha(
                    style.progressTrackColor.alpha * style.progressTrackOpacity
                )
            )
            if layout.progress > 0, let path = skb_path_create() {
                skb_path_add_arc(
                    path,
                    Float(center.x),
                    Float(center.y),
                    Float(ringRadius),
                    -90,
                    Float(360 * min(max(layout.progress, 0), 1)),
                    1
                )
                skb_draw_path(
                    canvas.context,
                    path,
                    0,
                    Float(style.progressColor.red),
                    Float(style.progressColor.green),
                    Float(style.progressColor.blue),
                    Float(style.progressColor.alpha),
                    Float(layout.progressRingWidth),
                    style.progressRoundedCaps ? 1 : 0,
                    1,
                    0,
                    0
                )
                skb_path_destroy(path)
            }
        }

        if style.dividerEnabled {
            drawDividers(canvas: canvas, style: style, layout: layout)
        }

        for region in layout.regions {
            drawRegion(
                canvas: canvas,
                style: style,
                region: region
            )
        }
    }

    // MARK: - Ring + ticks

    private static func strokeCircle(
        canvas: SkiaChartsCanvas,
        center: CGPoint,
        radius: Double,
        width: Double,
        color: OverlayColor
    ) {
        guard radius > 0, let path = skb_path_create() else { return }
        skb_path_add_arc(
            path,
            Float(center.x),
            Float(center.y),
            Float(radius),
            0,
            360,
            1
        )
        skb_draw_path(
            canvas.context,
            path,
            0,
            Float(color.red),
            Float(color.green),
            Float(color.blue),
            Float(color.alpha),
            Float(width),
            0,
            1,
            0,
            0
        )
        skb_path_destroy(path)
    }

    private static func drawTicks(
        canvas: SkiaChartsCanvas,
        style: RunningGaugeStyle,
        layout: OverlayRunningGaugeRenderLayout,
        center: CGPoint
    ) {
        let count = max(style.tickCount, 6)
        let majorEvery = max(style.majorTickEvery, 1)
        let width = max(style.dividerWidth, 1)
        let side = max(
            layout.diameter - 2 * (layout.outerRingWidth + 2),
            1
        )
        let tickRadius = side / 2
        for index in 0..<count {
            let isMajor = index.isMultiple(of: majorEvery)
            let length = isMajor
                ? layout.majorTickLength
                : layout.tickLength
            let angle = Double(index) / Double(count) * 2 * .pi
            let offsetY = -tickRadius + length / 2
            let cosA = cos(angle)
            let sinA = sin(angle)

            func rotated(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(
                    x: center.x + x * cosA - y * sinA,
                    y: center.y + x * sinA + y * cosA
                )
            }

            let corners = [
                rotated(-width / 2, offsetY - length / 2),
                rotated(width / 2, offsetY - length / 2),
                rotated(width / 2, offsetY + length / 2),
                rotated(-width / 2, offsetY + length / 2)
            ]
            guard let path = skb_path_create() else { return }
            skb_path_move_to(path, Float(corners[0].x), Float(corners[0].y))
            for corner in corners.dropFirst() {
                skb_path_line_to(path, Float(corner.x), Float(corner.y))
            }
            skb_path_close(path)
            canvas.fillPath(
                path,
                color: style.tickColor,
                opacity: isMajor ? style.majorTickOpacity : style.tickOpacity
            )
            skb_path_destroy(path)
        }    }

    private static func drawDividers(
        canvas: SkiaChartsCanvas,
        style: RunningGaugeStyle,
        layout: OverlayRunningGaugeRenderLayout
    ) {
        let diameter = layout.diameter
        let safeFraction = layout.safeRadius / max(diameter / 2, 1)
        let safeSide = diameter * safeFraction
        let originX = layout.rect.minX + (diameter - safeSide) / 2
        let originY = layout.rect.minY + (diameter - safeSide) / 2
        let segments = RunningGaugeLayoutEngine.dividerSegments(
            for: style.layoutPreset
        )
        let color = style.dividerColor.withAlpha(
            style.dividerColor.alpha * style.dividerOpacity
        )
        let width = max(style.dividerWidth, 1)
        for (start, end) in segments {
            canvas.strokeLine(
                from: CGPoint(
                    x: originX + start.x * safeSide,
                    y: originY + start.y * safeSide
                ),
                to: CGPoint(
                    x: originX + end.x * safeSide,
                    y: originY + end.y * safeSide
                ),
                width: width,
                color: color
            )
        }
    }

    // MARK: - Regions

    private static func drawRegion(
        canvas: SkiaChartsCanvas,
        style: RunningGaugeStyle,
        region: OverlayRunningGaugeRegionLayout
    ) {
        let config = region.config
        let rect = region.rect
        let spacing = max(region.unitFontSize * 0.10, 1)
        let monospacedDigits = style.monospacedDigits

        let labelText = config.customLabel.isEmpty
            ? config.metric.compactLabel
            : config.customLabel.uppercased()
        let labelColor = (config.labelColor ?? style.secondaryTextColor)
            .withAlpha(
                (config.labelColor ?? style.secondaryTextColor).alpha * 0.78
            )
        let valueColor = config.valueColor ?? style.primaryTextColor

        var labelLine: TextLine? = config.showLabel
            ? canvas.fittedLine(
                labelText,
                family: style.fontName,
                size: region.labelFontSize,
                weight: SkiaChartsCanvas.nsWeight(config.labelWeight),
                maxWidth: rect.width,
                minScale: 0.6,
                monospacedDigits: monospacedDigits
            )
            : nil

        var valueLine = canvas.fittedLine(
            region.components.value,
            family: style.fontName,
            size: region.valueFontSize,
            weight: SkiaChartsCanvas.nsWeight(config.valueWeight),
            maxWidth: rect.width,
            minScale: 0.5,
            monospacedDigits: monospacedDigits
        )

        let unitLine: TextLine? = config.showUnit
            && !region.components.unit.isEmpty
            ? canvas.line(
                region.components.unit,
                font: canvas.font(
                    family: style.fontName,
                    size: region.unitFontSize,
                    weight: NSFont.Weight.medium
                ),
                monospacedDigits: monospacedDigits
            )
            : nil

        var totalHeight = (labelLine?.height ?? 0)
            + spacing
            + valueLine.height
            + (unitLine == nil ? 0 : spacing + (unitLine?.height ?? 0))

        // A VStack whose ideal height exceeds its fixed region frame compresses
        // its most flexible child first. Text with `minimumScaleFactor` shrinks
        // uniformly, so absorb the deficit in the value, then the label.
        if totalHeight > rect.height {
            var deficit = totalHeight - rect.height

            let valueNominalHeight = valueLine.height
            let valueReduction = min(deficit, valueNominalHeight * 0.5)
            if valueReduction > 0.01, valueNominalHeight > 0 {
                let scale = 1 - valueReduction / valueNominalHeight
                valueLine = canvas.fittedLine(
                    region.components.value,
                    family: style.fontName,
                    size: valueLine.font.pointSize * scale,
                    weight: SkiaChartsCanvas.nsWeight(config.valueWeight),
                    maxWidth: rect.width,
                    minScale: 0.5,
                    monospacedDigits: monospacedDigits
                )
                deficit -= valueNominalHeight - valueLine.height
            }

            if deficit > 0.01, let currentLabel = labelLine {
                let labelNominalHeight = currentLabel.height
                let labelReduction = min(deficit, labelNominalHeight * 0.4)
                if labelReduction > 0.01, labelNominalHeight > 0 {
                    let scale = 1 - labelReduction / labelNominalHeight
                    labelLine = canvas.fittedLine(
                        labelText,
                        family: style.fontName,
                        size: currentLabel.font.pointSize * scale,
                        weight: SkiaChartsCanvas.nsWeight(config.labelWeight),
                        maxWidth: rect.width,
                        minScale: 0.6,
                        monospacedDigits: monospacedDigits
                    )
                }
            }

            totalHeight = (labelLine?.height ?? 0)
                + spacing
                + valueLine.height
                + (unitLine == nil ? 0 : spacing + (unitLine?.height ?? 0))
        }
        var top = rect.midY - totalHeight / 2

        if let labelLine {
            canvas.drawCentered(
                labelLine,
                centerX: rect.midX,
                top: top,
                color: labelColor
            )
            top += labelLine.height + spacing
        }

        if style.glowEnabled, style.glowRadius > 0 {
            let valueRect = CGRect(
                x: rect.midX - valueLine.width / 2,
                y: top,
                width: valueLine.width,
                height: valueLine.height
            )
            canvas.beginShadow(
                sigma: style.glowRadius * 0.5,
                dx: 0,
                dy: 0,
                bounds: valueRect,
                color: style.glowColor,
                opacity: style.glowOpacity
            )
            canvas.drawCentered(
                valueLine,
                centerX: rect.midX,
                top: top,
                color: valueColor
            )
            canvas.restore()
        } else {
            canvas.drawCentered(
                valueLine,
                centerX: rect.midX,
                top: top,
                color: valueColor
            )
        }
        top += valueLine.height + spacing

        if let unitLine {
            canvas.drawCentered(
                unitLine,
                centerX: rect.midX,
                top: top,
                color: labelColor
            )
        }
    }
}

private extension OverlayColor {
    func withAlpha(_ alpha: Double) -> OverlayColor {
        OverlayColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
#endif
