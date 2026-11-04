#if canImport(CSkiaBridge)
import CSkiaBridge
import AppKit
import CoreGraphics
import Foundation

/// Skia port of `ElevationChartOverlayView` (full export visibility).
enum SkiaElevationChartRenderer {
    static func draw(
        canvas: SkiaChartsCanvas,
        element: OverlayElement,
        layout: OverlayElevationChartRenderLayout
    ) {
        let style = layout.style
        let card = layout.rect
        let padX = element.style.backgroundPaddingX * element.scale
        let padY = element.style.backgroundPaddingY * element.scale
        let backgroundRect = card.insetBy(dx: -padX, dy: -padY)
        let backgroundRadius = element.style.backgroundRadius * element.scale

        var effectBounds = card.union(backgroundRect)
        if let statsBar = layout.statsBarLayout {
            effectBounds = effectBounds.union(
                statsBar.rect.offsetBy(dx: card.minX, dy: card.minY)
            )
        }
        effectBounds = effectBounds.insetBy(dx: -16, dy: -16)

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

        if element.style.backgroundEnabled {
            canvas.drawFeatheredBackground(
                rect: backgroundRect,
                cornerRadius: backgroundRadius,
                fadeEnabled: element.style.backgroundFadeOutEnabled,
                fadeAmount: element.style.backgroundFadeOutAmount,
                color: element.style.backgroundColor,
                opacity: element.style.backgroundOpacity
            )
        }

        if element.style.borderEnabled {
            canvas.strokeRoundedRect(
                backgroundRect,
                radius: backgroundRadius,
                width: element.style.borderWidth,
                color: element.style.borderColor,
                opacity: element.style.borderOpacity
            )
        }

        let contentLeft = card.minX + layout.horizontalPadding
        let contentWidth = max(card.width - layout.horizontalPadding * 2, 1)
        var chartTop = card.minY + layout.verticalPadding
        if style.bigNumbersEnabled {
            let rowHeight = drawBigNumbers(
                canvas: canvas,
                element: element,
                layout: layout,
                left: contentLeft,
                width: contentWidth,
                top: chartTop
            )
            chartTop += rowHeight + layout.verticalPadding
        }

        let chartRect = CGRect(
            x: contentLeft,
            y: chartTop,
            width: contentWidth,
            height: layout.chartHeight
        )
        drawChart(
            canvas: canvas,
            element: element,
            layout: layout,
            chartRect: chartRect
        )

        if let statsBar = layout.statsBarLayout {
            SkiaStatsBar.draw(
                canvas: canvas,
                items: statsBar.items,
                rect: statsBar.rect.offsetBy(dx: card.minX, dy: card.minY),
                stacked: statsBar.stacked,
                itemSpacing: statsBar.itemSpacing,
                dividerOpacity: statsBar.dividerOpacity,
                cornerRadius: statsBar.cornerRadius,
                backgroundOpacity: statsBar.backgroundOpacity,
                valueFontName: statsBar.valueFontName,
                valueFontSize: statsBar.valueFontSize,
                valueFontWeight: statsBar.valueFontWeight,
                valueColor: statsBar.valueColor,
                labelFontName: statsBar.labelFontName,
                labelFontSize: statsBar.labelFontSize,
                labelFontWeight: statsBar.labelFontWeight,
                labelColor: statsBar.labelColor
            )
        }
    }

    // MARK: - Big numbers

    private static func drawBigNumbers(
        canvas: SkiaChartsCanvas,
        element: OverlayElement,
        layout: OverlayElevationChartRenderLayout,
        left: Double,
        width: Double,
        top: Double
    ) -> Double {
        let style = layout.style
        let value = canvas.line(
            layout.bigNumberText.value,
            font: canvas.font(
                family: style.bigNumberFontName,
                size: layout.valueFontSize,
                weight: SkiaChartsCanvas.nsWeight(style.bigNumberFontWeight)
            ),
            monospacedDigits: true
        )
        let unit = canvas.line(
            layout.bigNumberText.unit,
            font: canvas.font(
                family: style.bigNumberFontName,
                size: layout.unitFontSize,
                weight: SkiaChartsCanvas.nsWeight(style.bigNumberFontWeight)
            )
        )
        let label = canvas.line(
            layout.bigNumberText.shortLabel,
            font: canvas.font(
                family: style.bigNumberFontName,
                size: layout.labelFontSize,
                weight: NSFont.Weight.medium
            )
        )

        let totalWidth = value.width + 5 + unit.width + 5 + 2 + label.width
        var x = left + (width - totalWidth) / 2
        let maxAscent = max(value.ascent, unit.ascent, label.ascent)
        let baseline = top + maxAscent

        canvas.draw(
            value,
            x: x,
            baselineY: baseline,
            color: element.style.foregroundColor
        )
        x += value.width + 5
        canvas.draw(
            unit,
            x: x,
            baselineY: baseline,
            color: element.style.foregroundColor,
            opacity: 0.86
        )
        x += unit.width + 5 + 2
        canvas.draw(
            label,
            x: x,
            baselineY: baseline,
            color: element.style.foregroundColor,
            opacity: 0.62
        )

        return max(value.height, unit.height, label.height)
    }

    // MARK: - Chart

    private static func drawChart(
        canvas: SkiaChartsCanvas,
        element: OverlayElement,
        layout: OverlayElevationChartRenderLayout,
        chartRect: CGRect
    ) {
        let style = layout.style
        let size = chartRect.size
        let points = chartPoints(
            samples: layout.samples,
            size: size
        ).map {
            CGPoint(x: chartRect.minX + $0.x, y: chartRect.minY + $0.y)
        }

        if style.gridEnabled {
            for fraction in [0.25, 0.5, 0.75] {
                let y = chartRect.minY + size.height * fraction
                canvas.strokeLine(
                    from: CGPoint(x: chartRect.minX, y: y),
                    to: CGPoint(x: chartRect.maxX, y: y),
                    width: 1,
                    color: .white,
                    opacity: 0.14
                )
            }
        }

        if style.axisLineEnabled {
            canvas.strokeLine(
                from: CGPoint(x: chartRect.minX, y: chartRect.minY),
                to: CGPoint(x: chartRect.minX, y: chartRect.maxY),
                width: 1,
                color: element.style.foregroundColor,
                opacity: 0.22
            )
        }

        if style.fillEnabled, style.chartStyle == .area {
            drawFills(
                canvas: canvas,
                style: style,
                layout: layout,
                chartRect: chartRect,
                points: points
            )
        }

        if let linePath = chartPath(
            points: points,
            chartRect: chartRect,
            smoothing: style.smoothingEnabled
        ) {
            if style.glowEnabled {
                let glowBounds = chartRect.insetBy(dx: -12, dy: -12)
                skb_begin_blur_layer(
                    canvas.context,
                    5.0,
                    Float(glowBounds.minX),
                    Float(glowBounds.minY),
                    Float(glowBounds.width),
                    Float(glowBounds.height)
                )
                strokeChartPath(
                    canvas: canvas,
                    path: linePath,
                    color: style.lineColor,
                    opacity: style.glowOpacity,
                    width: layout.lineWidth + 7
                )
                canvas.restore()
            }
            strokeChartPath(
                canvas: canvas,
                path: linePath,
                color: style.lineColor,
                opacity: style.lineOpacity,
                width: layout.lineWidth
            )
            skb_path_destroy(linePath)
        }

        if style.currentMarkerEnabled {
            drawMarker(
                canvas: canvas,
                element: element,
                layout: layout,
                chartRect: chartRect,
                points: points
            )
        }

        if style.axisLabelsEnabled {
            drawAxisLabels(
                canvas: canvas,
                element: element,
                layout: layout,
                chartRect: chartRect
            )
        }
    }

    private static func drawFills(
        canvas: SkiaChartsCanvas,
        style: ElevationChartStyle,
        layout: OverlayElevationChartRenderLayout,
        chartRect: CGRect,
        points: [CGPoint]
    ) {
        guard let areaPath = areaPath(points: points, chartRect: chartRect) else {
            return
        }
        let bounds = areaBounds(points: points, chartRect: chartRect)

        func fill(_ start: OverlayColor, _ end: OverlayColor) {
            let alpha0 = start.alpha * style.fillOpacity
            let alpha1 = end.alpha * max(style.fillOpacity * 0.15, 0.04)
            // SwiftUI interpolates gradient colors with premultiplied alpha;
            // Skia's default gradient interpolates unpremultiplied. Emit
            // intermediate stops to reproduce the premultiplied ramp.
            let stopCount = 16
            var stops: [Float] = []
            stops.reserveCapacity((stopCount + 1) * 5)
            for index in 0...stopCount {
                let t = Double(index) / Double(stopCount)
                let alpha = alpha0 + (alpha1 - alpha0) * t
                let red = (
                    (1 - t) * start.red * alpha0
                        + t * end.red * alpha1
                ) / max(alpha, 0.0001)
                let green = (
                    (1 - t) * start.green * alpha0
                        + t * end.green * alpha1
                ) / max(alpha, 0.0001)
                let blue = (
                    (1 - t) * start.blue * alpha0
                        + t * end.blue * alpha1
                ) / max(alpha, 0.0001)
                stops.append(Float(t))
                stops.append(Float(red))
                stops.append(Float(green))
                stops.append(Float(blue))
                stops.append(Float(alpha))
            }
            stops.withUnsafeMutableBufferPointer { buffer in
                skb_draw_path_gradient(
                    canvas.context,
                    areaPath,
                    1,
                    0,
                    1,
                    1,
                    buffer.baseAddress,
                    Int32(stopCount + 1),
                    Float(chartRect.midX),
                    Float(bounds.minY),
                    Float(chartRect.midX),
                    Float(bounds.maxY)
                )
            }
        }

        if style.dualAreaEnabled {
            fill(style.upperFillColor, style.fillEndColor)
            let progress = min(max(layout.progress, 0), 1)
            let maskX = chartRect.minX + chartRect.width * progress
            canvas.save()
            canvas.clipRect(
                CGRect(
                    x: maskX,
                    y: chartRect.minY,
                    width: chartRect.maxX - maskX,
                    height: chartRect.height
                )
            )
            fill(style.lowerFillColor, style.fillEndColor)
            canvas.restore()
        } else {
            fill(style.fillStartColor, style.fillEndColor)
        }
        skb_path_destroy(areaPath)
    }

    private static func chartPoints(
        samples: [Double],
        size: CGSize
    ) -> [CGPoint] {
        guard !samples.isEmpty else { return [] }
        let minValue = samples.min() ?? 0
        let maxValue = samples.max() ?? minValue
        let range = max(maxValue - minValue, 1)
        return samples.indices.map { index in
            let x = size.width * Double(index)
                / Double(max(samples.count - 1, 1))
            let y = size.height
                - size.height * (samples[index] - minValue) / range
            return CGPoint(x: x, y: y)
        }
    }

    private static func chartPath(
        points: [CGPoint],
        chartRect: CGRect,
        smoothing: Bool
    ) -> OpaquePointer? {
        guard let path = skb_path_create() else { return nil }
        guard points.count > 1 else {
            skb_path_move_to(
                path,
                Float(chartRect.minX),
                Float(chartRect.midY)
            )
            skb_path_line_to(
                path,
                Float(chartRect.maxX),
                Float(chartRect.midY)
            )
            return path
        }

        skb_path_move_to(path, Float(points[0].x), Float(points[0].y))
        guard smoothing, points.count > 2 else {
            for point in points.dropFirst() {
                skb_path_line_to(path, Float(point.x), Float(point.y))
            }
            return path
        }

        for index in 0..<(points.count - 1) {
            let start = points[index]
            let end = points[index + 1]
            let previous = index > 0 ? points[index - 1] : start
            let next = index + 2 < points.count ? points[index + 2] : end
            skb_path_cubic_to(
                path,
                Float(start.x + (end.x - previous.x) / 6),
                Float(start.y + (end.y - previous.y) / 6),
                Float(end.x - (next.x - start.x) / 6),
                Float(end.y - (next.y - start.y) / 6),
                Float(end.x),
                Float(end.y)
            )
        }
        return path
    }

    private static func areaPath(
        points: [CGPoint],
        chartRect: CGRect
    ) -> OpaquePointer? {
        guard let path = chartPath(
            points: points,
            chartRect: chartRect,
            smoothing: true
        ) else {
            return nil
        }
        skb_path_line_to(path, Float(chartRect.maxX), Float(chartRect.maxY))
        skb_path_line_to(path, Float(chartRect.minX), Float(chartRect.maxY))
        skb_path_close(path)
        return path
    }

    private static func areaBounds(
        points: [CGPoint],
        chartRect: CGRect
    ) -> CGRect {
        CGRect(
            x: chartRect.minX,
            y: chartRect.minY,
            width: chartRect.width,
            height: chartRect.height
        )
    }

    private static func strokeChartPath(
        canvas: SkiaChartsCanvas,
        path: OpaquePointer,
        color: OverlayColor,
        opacity: Double,
        width: Double
    ) {
        skb_draw_path(
            canvas.context,
            path,
            0,
            Float(color.red),
            Float(color.green),
            Float(color.blue),
            Float(color.alpha * opacity),
            Float(width),
            1,
            1,
            0,
            0
        )
    }

    // MARK: - Marker

    private static func drawMarker(
        canvas: SkiaChartsCanvas,
        element: OverlayElement,
        layout: OverlayElevationChartRenderLayout,
        chartRect: CGRect,
        points: [CGPoint]
    ) {
        let style = layout.style
        let point = chartPoint(
            at: layout.progress,
            points: points,
            chartRect: chartRect
        )

        if style.markerPlayheadLineEnabled, !style.bigNumbersEnabled,
           point.x - chartRect.minX > 1.5 {
            if let path = skb_path_create() {
                skb_path_move_to(
                    path,
                    Float(point.x),
                    Float(chartRect.minY)
                )
                skb_path_line_to(
                    path,
                    Float(point.x),
                    Float(chartRect.maxY)
                )
                skb_draw_path(
                    canvas.context,
                    path,
                    0,
                    1,
                    1,
                    1,
                    0.28,
                    1,
                    0,
                    0,
                    3,
                    4
                )
                skb_path_destroy(path)
            }
        }

        let haloRadius = layout.markerHaloSize / 2
        let haloRect = CGRect(
            x: point.x - haloRadius,
            y: point.y - haloRadius,
            width: layout.markerHaloSize,
            height: layout.markerHaloSize
        )
        if layout.markerGlowBlurRadius > 0 {
            let blurBounds = haloRect.insetBy(
                dx: -layout.markerGlowBlurRadius * 2,
                dy: -layout.markerGlowBlurRadius * 2
            )
            skb_begin_blur_layer(
                canvas.context,
                Float(layout.markerGlowBlurRadius),
                Float(blurBounds.minX),
                Float(blurBounds.minY),
                Float(blurBounds.width),
                Float(blurBounds.height)
            )
            canvas.fillCircle(
                center: point,
                radius: haloRadius,
                color: style.markerColor.withAlpha(
                    style.markerColor.alpha * 0.24
                )
            )
            canvas.restore()
        } else {
            canvas.fillCircle(
                center: point,
                radius: haloRadius,
                color: style.markerColor.withAlpha(
                    style.markerColor.alpha * 0.24
                )
            )
        }

        canvas.fillCircle(
            center: point,
            radius: layout.markerDotSize / 2,
            color: style.markerColor
        )

        if let ring = skb_path_create() {
            skb_path_add_arc(
                ring,
                Float(point.x),
                Float(point.y),
                Float(
                    max(
                        layout.markerRingSize - layout.markerRingStrokeWidth,
                        0
                    ) / 2
                ),
                0,
                360,
                1
            )
            skb_draw_path(
                canvas.context,
                ring,
                0,
                1,
                1,
                1,
                0.95,
                Float(layout.markerRingStrokeWidth),
                0,
                1,
                0,
                0
            )
            skb_path_destroy(ring)
        }

        if style.markerLabelEnabled {
            drawMarkerLabel(
                canvas: canvas,
                element: element,
                layout: layout,
                chartRect: chartRect,
                point: point
            )
        }
    }

    private static func drawMarkerLabel(
        canvas: SkiaChartsCanvas,
        element: OverlayElement,
        layout: OverlayElevationChartRenderLayout,
        chartRect: CGRect,
        point: CGPoint
    ) {
        let text = layout.label.replacingOccurrences(
            of: "Elevation ",
            with: ""
        )
        let line = canvas.line(
            text,
            font: canvas.font(
                family: element.style.fontName,
                size: max(layout.labelFontSize * 0.92, 10),
                weight: NSFont.Weight.semibold
            ),
            monospacedDigits: true
        )
        let boxSize = CGSize(
            width: line.width + 16,
            height: line.height + 10
        )
        let centerX = min(
            max(point.x, chartRect.minX + 28),
            chartRect.maxX - 28
        )
        let centerY = max(point.y - 25, chartRect.minY + 12)
        let box = CGRect(
            x: centerX - boxSize.width / 2,
            y: centerY - boxSize.height / 2,
            width: boxSize.width,
            height: boxSize.height
        )

        canvas.fillRoundedRect(
            box,
            radius: 7,
            color: .black,
            opacity: 0.68
        )
        canvas.strokeRoundedRect(
            box,
            radius: 7,
            width: 1,
            color: .white,
            opacity: 0.16
        )
        canvas.draw(
            line,
            x: box.midX - line.width / 2,
            baselineY: box.minY
                + (box.height - line.height) / 2
                + line.ascent,
            color: .white
        )
    }

    private static func chartPoint(
        at progress: Double,
        points: [CGPoint],
        chartRect: CGRect
    ) -> CGPoint {
        guard !points.isEmpty else {
            return CGPoint(
                x: chartRect.minX + chartRect.width * progress,
                y: chartRect.midY
            )
        }
        let index = min(
            max(
                Int((Double(points.count - 1) * progress).rounded()),
                0
            ),
            points.count - 1
        )
        return points[index]
    }

    // MARK: - Axis labels

    private static func drawAxisLabels(
        canvas: SkiaChartsCanvas,
        element: OverlayElement,
        layout: OverlayElevationChartRenderLayout,
        chartRect: CGRect
    ) {
        let minValue = layout.samples.min() ?? 0
        let maxValue = layout.samples.max() ?? minValue
        let font = canvas.font(
            family: element.style.fontName,
            size: max(layout.labelFontSize * 0.78, 8),
            weight: NSFont.Weight.medium
        )
        let color = element.style.foregroundColor

        func draw(_ text: String, centerX: Double, centerY: Double) {
            let line = canvas.line(text, font: font)
            canvas.draw(
                line,
                x: centerX - line.width / 2,
                baselineY: centerY - line.height / 2 + line.ascent,
                color: color,
                opacity: 0.58
            )
        }

        draw(
            "\(Int(maxValue.rounded()))",
            centerX: chartRect.minX + 14,
            centerY: chartRect.minY + 8
        )
        draw(
            "\(Int(minValue.rounded()))",
            centerX: chartRect.minX + 10,
            centerY: chartRect.maxY - 8
        )
        draw(
            "m",
            centerX: chartRect.maxX - 10,
            centerY: chartRect.minY + 8
        )
    }
}

private extension OverlayColor {
    func withAlpha(_ alpha: Double) -> OverlayColor {
        OverlayColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
#endif
