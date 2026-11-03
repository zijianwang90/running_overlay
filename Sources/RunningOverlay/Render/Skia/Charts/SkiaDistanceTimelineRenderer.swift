#if canImport(CSkiaBridge)
import CSkiaBridge
import AppKit
import CoreGraphics
import Foundation

/// Skia port of `DistanceTimelineOverlayView`. All geometry comes from
/// `OverlayDistanceTimelineRenderLayout`; this file only reproduces the
/// SwiftUI drawing order and styling.
enum SkiaDistanceTimelineRenderer {
    static func draw(
        canvas: SkiaChartsCanvas,
        element: OverlayElement,
        layout: OverlayDistanceTimelineRenderLayout
    ) {
        let style = layout.style
        let styleScale = layout.distanceTimelineStyleScale
        let fadeOpacity = style.fadeEnabled
            ? max(1 - style.fadeAmount * 0.35, 0.72)
            : 1
        let alpha = min(max(element.opacity * fadeOpacity, 0), 1)

        let statsRect = layout.distanceTimelineStatsBarRect()
        var backgroundRect = layout.distanceTimelineContentBounds().insetBy(
            dx: -element.style.backgroundPaddingX * styleScale,
            dy: -element.style.backgroundPaddingY * styleScale
        )
        if style.statsBar.visible,
           style.statsBar.inside,
           let statsRect {
            backgroundRect = backgroundRect.union(
                statsRect.insetBy(
                    dx: -element.style.backgroundPaddingX * styleScale,
                    dy: -element.style.backgroundPaddingY * styleScale
                )
            )
        }

        var effectBounds = layout.rect.union(
            layout.distanceTimelineContentBounds(axisPadding: 32)
        )
        if element.style.backgroundEnabled || element.style.borderEnabled {
            effectBounds = effectBounds.union(backgroundRect)
        }
        if let statsRect {
            effectBounds = effectBounds.union(statsRect)
        }

        var restores = 0
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
                cornerRadius: layout.cornerRadius,
                fadeEnabled: element.style.backgroundFadeOutEnabled,
                fadeAmount: element.style.backgroundFadeOutAmount,
                color: element.style.backgroundColor,
                opacity: element.style.backgroundOpacity
            )
        }

        if element.style.borderEnabled {
            canvas.strokeRoundedRect(
                backgroundRect,
                radius: layout.cornerRadius,
                width: element.style.borderWidth,
                color: element.style.borderColor,
                opacity: element.style.borderOpacity
            )
        }

        if let mediaRect = layout.mediaSlotRect {
            drawMediaSlot(
                canvas: canvas,
                element: element,
                layout: layout,
                rect: mediaRect
            )
        }

        if style.preset == .route, style.elevationProfileVisible {
            drawElevationProfile(
                canvas: canvas,
                layout: layout,
                color: style.fillColor,
                opacity: 0.16
            )
        }

        drawValueLayer(canvas: canvas, element: element, layout: layout)

        drawProgressLayer(
            canvas: canvas,
            element: element,
            layout: layout
        )

        if style.showAxisLabels || style.showDistancePoints {
            drawAxisLabels(canvas: canvas, layout: layout)
        }

        if style.markerDistanceLabelEnabled, style.currentMarkerEnabled {
            drawMarkerDistanceLabel(canvas: canvas, layout: layout)
        }

        if style.statsBar.visible, let statsRect {
            drawStatsBar(
                canvas: canvas,
                items: layout.statsBarItems,
                rect: statsRect,
                config: style.statsBar,
                styleScale: styleScale
            )
        }
    }

    // MARK: - Value layer

    private static func drawValueLayer(
        canvas: SkiaChartsCanvas,
        element: OverlayElement,
        layout: OverlayDistanceTimelineRenderLayout
    ) {
        let style = layout.style
        let content = layout.contentRect
        let spacing = style.labelValueSpacing * layout.distanceTimelineStyleScale

        var rowHeight = 0.0
        if style.showLabel {
            let labelLine = canvas.line(
                layout.label.uppercased(),
                font: canvas.font(
                    family: style.labelFontName,
                    size: layout.labelFontSize,
                    weight: style.labelFontWeight
                )
            )
            canvas.draw(
                labelLine,
                x: content.minX,
                baselineY: content.minY + labelLine.ascent,
                color: style.labelColor
            )
            rowHeight = labelLine.height
        }

        let valueTop = content.minY + rowHeight + spacing
        let valueFontSize = switch style.preset {
        case .lowerThird: layout.valueFontSize * 1.05
        case .sport: layout.valueFontSize * 1.12
        case .dense: layout.valueFontSize * 0.86
        default: layout.valueFontSize
        }
        let valueWeight: NSFont.Weight = switch style.preset {
        case .dense, .neon: .medium
        default: .bold
        }
        let valueColor = style.preset == .neon
            ? OverlayColor(red: 1, green: 1, blue: 1, alpha: 0.92)
            : element.style.foregroundColor

        var valueLine = TextLine(
            font: canvas.font(
                family: element.style.fontName,
                size: valueFontSize,
                weight: valueWeight
            ),
            glyphs: [],
            xPositions: [],
            width: 0,
            ascent: 0,
            descent: 0,
            leading: 0
        )
        var valueBaseline = valueTop

        if style.showValue {
            valueLine = canvas.line(
                layout.valueText,
                font: canvas.font(
                    family: element.style.fontName,
                    size: valueFontSize,
                    weight: valueWeight
                ),
                monospacedDigits: true
            )
            valueBaseline = valueTop + valueLine.ascent
            canvas.draw(
                valueLine,
                x: content.minX,
                baselineY: valueBaseline,
                color: valueColor
            )
        }

        guard !layout.customValues.isEmpty else { return }
        var x = content.minX
        if style.showValue {
            x += valueLine.width
                + style.customValuesGroupSpacing * layout.distanceTimelineStyleScale
        }
        let customFont = canvas.font(
            family: element.style.fontName,
            size: style.customValueFontSize * layout.distanceTimelineStyleScale,
            weight: NSFont.Weight.semibold
        )
        let customSpacing = style.customValueSpacing * layout.distanceTimelineStyleScale
        for item in layout.customValues {
            let text = item.value.isEmpty ? item.label : item.value
            let line = canvas.line(
                text,
                font: customFont,
                monospacedDigits: true
            )
            canvas.draw(
                line,
                x: x,
                baselineY: valueBaseline,
                color: style.customValueColor,
                opacity: style.customValueOpacity
            )
            x += line.width + customSpacing
        }
    }

    // MARK: - Progress

    private static func drawProgressLayer(
        canvas: SkiaChartsCanvas,
        element: OverlayElement,
        layout: OverlayDistanceTimelineRenderLayout
    ) {
        let style = layout.style
        let track = layout.trackRect
        let radius = track.height / 2
        let trackColor = element.style.foregroundColor.withAlpha(
            element.style.foregroundColor.alpha * style.trackOpacity
        )
        let accent = style.fillColor
        let labelColor = style.preset == .neon
            ? accent.withAlpha(accent.alpha * 0.86)
            : element.style.foregroundColor.withAlpha(
                element.style.foregroundColor.alpha * 0.64
            )

        canvas.fillRoundedRect(track, radius: radius, color: trackColor)

        if style.preset == .route {
            drawRoute(
                canvas: canvas,
                layout: layout,
                track: track,
                trackColor: trackColor,
                accent: accent
            )
        } else {
            let accentRect = CGRect(
                x: track.minX,
                y: track.minY,
                width: max(track.width * layout.progress, track.height),
                height: track.height
            )
            if style.glowEnabled {
                canvas.beginShadow(
                    sigma: track.height * 2.8,
                    dx: 0,
                    dy: 0,
                    bounds: accentRect,
                    color: accent,
                    opacity: 0.75
                )
                canvas.fillRoundedRect(accentRect, radius: radius, color: accent)
                canvas.restore()
            } else {
                canvas.fillRoundedRect(accentRect, radius: radius, color: accent)
            }
        }

        if style.tickMarksEnabled {
            let count = max(style.tickDensity, 2)
            for index in 0...count {
                let x = track.minX + track.width * Double(index) / Double(count)
                canvas.strokeLine(
                    from: CGPoint(x: x, y: track.minY - track.height * 0.45),
                    to: CGPoint(x: x, y: track.minY + track.height * 1.45),
                    width: 1,
                    color: labelColor,
                    opacity: 0.52
                )
            }
        }

        guard style.currentMarkerEnabled else { return }
        let markerPoint = markerPointInTrackLocal(layout: layout)
        let center = CGPoint(
            x: track.minX + markerPoint.x,
            y: track.minY + markerPoint.y
        )
        let multiplier = style.currentMarkerSizeMultiplier
        let markerSize: CGSize = switch style.currentMarkerStyle {
        case .dot:
            CGSize(
                width: track.height * 2.2 * multiplier,
                height: track.height * 2.2 * multiplier
            )
        case .pill:
            CGSize(
                width: track.height * 3.4 * multiplier,
                height: track.height * 1.75 * multiplier
            )
        case .triangle:
            CGSize(
                width: track.height * 2.6 * multiplier,
                height: track.height * 2.4 * multiplier
            )
        }
        let markerRect = CGRect(
            x: center.x - markerSize.width / 2,
            y: center.y - markerSize.height / 2,
            width: markerSize.width,
            height: markerSize.height
        )

        if style.glowEnabled {
            canvas.beginShadow(
                sigma: track.height * 2.3,
                dx: 0,
                dy: 0,
                bounds: markerRect,
                color: accent,
                opacity: 0.75
            )
        }
        switch style.currentMarkerStyle {
        case .dot:
            canvas.fillCircle(
                center: center,
                radius: markerSize.width / 2,
                color: style.currentMarkerColor
            )
        case .pill:
            canvas.fillRoundedRect(
                markerRect,
                radius: markerSize.height / 2,
                color: style.currentMarkerColor
            )
        case .triangle:
            if let path = skb_path_create() {
                skb_path_move_to(
                    path,
                    Float(markerRect.midX),
                    Float(markerRect.minY)
                )
                skb_path_line_to(
                    path,
                    Float(markerRect.maxX),
                    Float(markerRect.maxY)
                )
                skb_path_line_to(
                    path,
                    Float(markerRect.minX),
                    Float(markerRect.maxY)
                )
                skb_path_close(path)
                canvas.fillPath(path, color: style.currentMarkerColor)
                skb_path_destroy(path)
            }
        }
        if style.glowEnabled {
            canvas.restore()
        }
    }

    private static func markerPointInTrackLocal(
        layout: OverlayDistanceTimelineRenderLayout
    ) -> CGPoint {
        let track = layout.trackRect
        if layout.style.preset == .route {
            let point = layout.routeCurrentPoint
                ?? progressedRoutePoints(layout: layout).last
                ?? CGPoint(
                    x: track.minX + track.width * layout.progress,
                    y: track.midY
                )
            return CGPoint(x: point.x - track.minX, y: point.y - track.minY)
        }
        return CGPoint(
            x: max(track.width * layout.progress, 0),
            y: track.height * 0.5
        )
    }

    private static func progressedRoutePoints(
        layout: OverlayDistanceTimelineRenderLayout
    ) -> [CGPoint] {
        let track = layout.trackRect
        guard layout.routePoints.count > 1 else {
            return [
                CGPoint(x: track.minX, y: track.minY + track.height * 0.70),
                CGPoint(
                    x: track.minX + track.width * layout.progress,
                    y: track.minY + track.height * 0.36
                )
            ]
        }
        let targetCount = max(
            Int((Double(layout.routePoints.count - 1) * layout.progress)
                .rounded(.down)) + 1,
            1
        )
        var points = Array(
            layout.routePoints.prefix(min(targetCount, layout.routePoints.count))
        )
        if let current = layout.routeCurrentPoint, points.last != current {
            points.append(current)
        }
        return points
    }

    private static func drawRoute(
        canvas: SkiaChartsCanvas,
        layout: OverlayDistanceTimelineRenderLayout,
        track: CGRect,
        trackColor: OverlayColor,
        accent: OverlayColor
    ) {
        let width = max(track.height, 2)
        if layout.routePoints.isEmpty {
            if let path = skb_path_create() {
                skb_path_move_to(
                    path,
                    Float(track.minX),
                    Float(track.minY + track.height * 0.70)
                )
                skb_path_cubic_to(
                    path,
                    Float(track.minX + track.width * 0.25),
                    Float(track.minY - track.height * 0.4),
                    Float(track.minX + track.width * 0.58),
                    Float(track.minY + track.height * 1.6),
                    Float(track.minX + track.width * layout.progress),
                    Float(track.minY + track.height * 0.36)
                )
                canvas.strokePath(
                    path,
                    color: trackColor,
                    width: width,
                    cap: 1,
                    join: 1
                )
                skb_path_destroy(path)
            }
        } else if let path = polyline(layout.routePoints) {
            canvas.strokePath(
                path,
                color: trackColor,
                width: width,
                cap: 1,
                join: 1
            )
            skb_path_destroy(path)
        }

        if let path = polyline(progressedRoutePoints(layout: layout)) {
            canvas.strokePath(
                path,
                color: accent,
                width: width,
                cap: 1,
                join: 1
            )
            skb_path_destroy(path)
        }
    }

    private static func polyline(_ points: [CGPoint]) -> OpaquePointer? {
        guard points.count > 1, let path = skb_path_create() else { return nil }
        skb_path_move_to(path, Float(points[0].x), Float(points[0].y))
        for point in points.dropFirst() {
            skb_path_line_to(path, Float(point.x), Float(point.y))
        }
        return path
    }

    // MARK: - Elevation profile

    private static func drawElevationProfile(
        canvas: SkiaChartsCanvas,
        layout: OverlayDistanceTimelineRenderLayout,
        color: OverlayColor,
        opacity: Double
    ) {
        let samples = layout.elevationSamples
        guard samples.count > 1, let path = skb_path_create() else { return }
        let content = layout.contentRect
        let width = content.width
        let height = content.height * 0.30
        let originY = content.maxY - content.height * 0.37
        let minValue = samples.min() ?? 0
        let maxValue = samples.max() ?? minValue
        let range = max(maxValue - minValue, 1)

        skb_path_move_to(
            path,
            Float(content.minX),
            Float(originY + height)
        )
        for index in samples.indices {
            let x = width * Double(index) / Double(max(samples.count - 1, 1))
            let normalized = (samples[index] - minValue) / range
            let y = height - height * normalized
            skb_path_line_to(
                path,
                Float(content.minX + x),
                Float(originY + y)
            )
        }
        skb_path_line_to(
            path,
            Float(content.minX + width),
            Float(originY + height)
        )
        skb_path_close(path)
        canvas.fillPath(path, color: color, opacity: opacity)
        skb_path_destroy(path)
    }

    // MARK: - Axis labels

    private static func drawAxisLabels(
        canvas: SkiaChartsCanvas,
        layout: OverlayDistanceTimelineRenderLayout
    ) {
        let style = layout.style
        let track = layout.trackRect
        let textHeight = layout.unitFontSize * 1.3
        let font = canvas.font(
            family: style.axisLabelFontName,
            size: layout.unitFontSize,
            weight: style.axisLabelFontWeight
        )
        let axisColor = style.axisLabelColor

        if style.showAxisLabels {
            let gap = style.distancePointOffset * layout.distanceTimelineStyleScale
            let top = style.distanceTimelineAxisLabelTextTopY(
                trackRect: track,
                placement: style.axisEndpointLabelPlacement,
                scaledGap: gap,
                textLineHeight: textHeight
            )
            let startLine = canvas.line(layout.startText, font: font)
            let startBaseline = top
                + (textHeight - startLine.height) / 2
                + startLine.ascent
            canvas.draw(
                startLine,
                x: track.minX,
                baselineY: startBaseline,
                color: axisColor
            )
            let finishLine = canvas.line(layout.finishText, font: font)
            canvas.drawRightAligned(
                finishLine,
                rightX: track.maxX,
                bandTop: top,
                bandHeight: textHeight,
                color: axisColor
            )
        }

        if style.showDistancePoints, !layout.distancePointLabels.isEmpty {
            let gap = style.midpointAxisLabelOffset
                * layout.distanceTimelineStyleScale
            let top = style.distanceTimelineAxisLabelTextTopY(
                trackRect: track,
                placement: style.axisMidpointLabelPlacement,
                scaledGap: gap,
                textLineHeight: textHeight
            )
            let denominator = Double(layout.distancePointLabels.count + 1)
            for (index, label) in layout.distancePointLabels.enumerated() {
                let x = track.minX
                    + track.width * Double(index + 1) / denominator
                let line = canvas.line(
                    label,
                    font: font,
                    monospacedDigits: true
                )
                canvas.drawCentered(
                    line,
                    centerX: x,
                    bandTop: top,
                    bandHeight: textHeight,
                    color: axisColor
                )
            }
        }
    }

    private static func drawMarkerDistanceLabel(
        canvas: SkiaChartsCanvas,
        layout: OverlayDistanceTimelineRenderLayout
    ) {
        let style = layout.style
        let track = layout.trackRect
        let textHeight = layout.unitFontSize * 1.3
        let gap = style.markerDistanceLabelOffset
            * layout.distanceTimelineStyleScale
        let top = style.distanceTimelineAxisLabelTextTopY(
            trackRect: track,
            placement: style.markerDistanceLabelPlacement,
            scaledGap: gap,
            textLineHeight: textHeight
        )
        let markerLocal = markerPointInTrackLocal(layout: layout)
        let centerX = track.minX + markerLocal.x
        let line = canvas.line(
            layout.markerDistanceText,
            font: canvas.font(
                family: style.axisLabelFontName,
                size: layout.unitFontSize,
                weight: style.axisLabelFontWeight
            ),
            monospacedDigits: true
        )
        canvas.drawCentered(
            line,
            centerX: centerX,
            bandTop: top,
            bandHeight: textHeight,
            color: style.axisLabelColor
        )
    }

    // MARK: - Stats bar

    private static func drawStatsBar(
        canvas: SkiaChartsCanvas,
        items: [OverlayDistanceTimelineStatsBarItemLayout],
        rect: CGRect,
        config: DistanceTimelineStatsBarConfig,
        styleScale: Double
    ) {
        guard !items.isEmpty else { return }
        canvas.fillRoundedRect(
            rect,
            radius: config.cornerRadius,
            color: .black,
            opacity: config.backgroundOpacity
        )

        canvas.save()
        canvas.clipRoundedRect(rect, radius: config.cornerRadius)
        defer { canvas.restore() }

        let stacked = config.placement.isVertical
            || config.layoutMode == .stack
        let spacing = config.itemSpacing * styleScale
        let count = items.count
        let dividerColor = config.labelColor
        let spacingTotal = Double(max(2 * count - 2, 0)) * spacing

        if stacked {
            let dividerHeight = 1.0
            let fixed = Double(max(count - 1, 0)) * dividerHeight + spacingTotal
            let itemHeight = (rect.height - fixed) / Double(count)
            var cursor = rect.minY
            for (index, item) in items.enumerated() {
                let cell = CGRect(
                    x: rect.minX,
                    y: cursor,
                    width: rect.width,
                    height: itemHeight
                )
                drawStatsItem(
                    canvas: canvas,
                    item: item,
                    cell: cell,
                    config: config,
                    styleScale: styleScale
                )
                cursor += itemHeight
                if index < count - 1 {
                    cursor += spacing
                    if config.dividerOpacity > 0 {
                        canvas.fillRect(
                            CGRect(
                                x: rect.minX + 6,
                                y: cursor,
                                width: max(rect.width - 12, 0),
                                height: dividerHeight
                            ),
                            color: dividerColor,
                            opacity: config.dividerOpacity
                        )
                    }
                    cursor += dividerHeight + spacing
                }
            }
        } else {
            let dividerWidth = 13.0
            let fixed = Double(max(count - 1, 0)) * dividerWidth + spacingTotal
            let itemWidth = (rect.width - fixed) / Double(count)
            var cursor = rect.minX
            for (index, item) in items.enumerated() {
                let cell = CGRect(
                    x: cursor,
                    y: rect.minY,
                    width: itemWidth,
                    height: rect.height
                )
                drawStatsItem(
                    canvas: canvas,
                    item: item,
                    cell: cell,
                    config: config,
                    styleScale: styleScale
                )
                cursor += itemWidth
                if index < count - 1 {
                    cursor += spacing
                    if config.dividerOpacity > 0 {
                        canvas.fillRect(
                            CGRect(
                                x: cursor + 6,
                                y: rect.minY + 6,
                                width: 1,
                                height: max(rect.height - 12, 0)
                            ),
                            color: dividerColor,
                            opacity: config.dividerOpacity
                        )
                    }
                    cursor += dividerWidth + spacing
                }
            }
        }
    }

    private static func drawStatsItem(
        canvas: SkiaChartsCanvas,
        item: OverlayDistanceTimelineStatsBarItemLayout,
        cell: CGRect,
        config: DistanceTimelineStatsBarConfig,
        styleScale: Double
    ) {
        let valueText = item.value
            + (item.unit.isEmpty ? "" : " \(item.unit)")
        let valueLine = canvas.fittedLine(
            valueText,
            family: config.valueFontName,
            size: config.valueFontSize * styleScale,
            weight: SkiaChartsCanvas.nsWeight(config.valueFontWeight),
            maxWidth: cell.width,
            minScale: 0.7,
            monospacedDigits: true
        )
        let labelLine = canvas.fittedLine(
            item.label.uppercased(),
            family: config.labelFontName,
            size: config.labelFontSize * styleScale,
            weight: SkiaChartsCanvas.nsWeight(config.labelFontWeight),
            maxWidth: cell.width,
            minScale: 0.7
        )
        let totalHeight = valueLine.height + 1 + labelLine.height
        let top = cell.midY - totalHeight / 2
        canvas.drawCentered(
            valueLine,
            centerX: cell.midX,
            top: top,
            color: config.valueColor
        )
        canvas.drawCentered(
            labelLine,
            centerX: cell.midX,
            top: top + valueLine.height + 1,
            color: config.labelColor
        )
    }

    // MARK: - Media slot

    private static func drawMediaSlot(
        canvas: SkiaChartsCanvas,
        element: OverlayElement,
        layout: OverlayDistanceTimelineRenderLayout,
        rect: CGRect
    ) {
        let style = layout.style
        let slot = style.mediaSlot
        canvas.fillRoundedRect(
            rect,
            radius: rect.width * 0.28,
            color: style.fillColor,
            opacity: 0.18
        )

        let tintColor = slot.tintMode == .text
            ? element.style.foregroundColor
            : style.fillColor
        let pixelSize = CGSize(
            width: max(rect.width.rounded(), 1),
            height: max(rect.height.rounded(), 1)
        )
        let nsTint = SkiaChartsCanvas.nsColor(tintColor)

        if (slot.mode == .staticSVG || slot.mode == .animatedSVG),
           slot.hasEmbeddedSVG {
            let elapsed = slot.mode == .animatedSVG
                ? Int(layout.elapsedTime * 1000)
                : 0
            let key = "dt-svg|\(slot.svgSource.hashValue)|\(Int(pixelSize.width))x\(Int(pixelSize.height))|\(nsTint.hashValue)|\(elapsed)"
            if let handle = canvas.image(
                key: key,
                make: {
                    OverlayIconRenderer.image(
                        slot: slot,
                        size: CGSize(
                            width: pixelSize.width,
                            height: pixelSize.height
                        ),
                        elapsedTime: layout.elapsedTime,
                        tintColor: nsTint
                    )
                },
                pixelSize: pixelSize
            ) {
                canvas.drawImage(handle, in: rect)
            }
            return
        }

        let name = slot.systemImage.isEmpty
            ? style.mediaSystemImage
            : slot.systemImage
        guard !name.isEmpty else { return }
        let pointSize = rect.width * 0.48
        let key = "dt-symbol|\(name)|\(Int(pixelSize.width))x\(Int(pixelSize.height))|\(nsTint.hashValue)"
        if let handle = canvas.image(
            key: key,
            make: {
                let configuration = NSImage.SymbolConfiguration(
                    pointSize: pointSize,
                    weight: .semibold
                )
                return NSImage(
                    systemSymbolName: name,
                    accessibilityDescription: nil
                )?.withSymbolConfiguration(configuration)
            },
            pixelSize: pixelSize,
            tint: nsTint,
            scaleToFit: false
        ) {
            canvas.drawImage(handle, in: rect)
        }
    }
}

private extension OverlayColor {
    func withAlpha(_ alpha: Double) -> OverlayColor {
        OverlayColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
#endif
