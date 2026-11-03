#if canImport(CSkiaBridge)
import AppKit
import CSkiaBridge
import CoreGraphics
import Foundation

/// Skia port of `ZoneEdgeBarOverlayView`.
///
/// Geometry is consumed from `ZoneEdgeBarRenderLayout`; the zone-segment rects
/// come from `OverlayRenderModel.intervalZoneBarRects`. Marker placement math
/// is module-local for 1.0 because the SwiftUI view owns it today; it is
/// marked for lifting into `OverlayRenderModel` after lead review.
enum ZoneEdgeBarSkiaRenderer {
    static func draw(
        _ element: OverlayElement,
        layout: ZoneEdgeBarRenderLayout,
        context: OpaquePointer,
        maskCache: SkiaIntervalDraw.MaskCache
    ) {
        let style = layout.style
        let rect = layout.rect
        let barRect = layout.barRect
        let orientation = layout.orientation
        let crossThickness = orientation == .horizontal ? barRect.height : barRect.width
        let cornerRadius = min(max(style.cornerRadius * element.scale, 0), crossThickness / 2)
        let segments = layout.zoneSegments
        guard !segments.isEmpty else { return }

        let frames = OverlayRenderModel.intervalZoneSegmentFrames(
            segmentCount: segments.count,
            activeIndex: layout.activeZoneIndex,
            activeWidthShare: style.activeZoneWidthShare
        )
        let zoneRects = OverlayRenderModel.intervalZoneBarRects(
            frames: frames,
            segments: segments,
            barRect: barRect,
            activeIndex: layout.activeZoneIndex,
            activeThicknessScale: style.activeZoneHeightScale,
            segmentGap: style.zoneSegmentGap,
            elementScale: element.scale,
            orientation: orientation
        )
        guard !zoneRects.isEmpty else { return }
        let rectsByIndex = Dictionary(uniqueKeysWithValues: zoneRects.map { ($0.index, $0.rect) })
        let segmentsByIndex = Dictionary(uniqueKeysWithValues: segments.map { ($0.index, $0) })

        let shadowSigma = SkiaIntervalDraw.shadowSigma(element.style.shadowRadius)
        let markerPad = max(crossThickness * 3, 48)
        let drawBounds = rect.insetBy(
            dx: -(markerPad + shadowSigma * 3),
            dy: -(markerPad + shadowSigma * 3)
        )

        SkiaIntervalDraw.withElementOpacity(
            context,
            element: element,
            bounds: drawBounds
        ) {
            SkiaIntervalDraw.withShadowChain(
                context,
                shadows: element.style.shadowEnabled
                    ? [
                        .init(
                            radius: element.style.shadowRadius,
                            dx: element.style.shadowOffsetX,
                            dy: element.style.shadowOffsetY,
                            color: element.style.shadowColor,
                            alpha: element.style.shadowOpacity
                        )
                    ]
                    : [],
                bounds: drawBounds
            ) {
                drawGlow(
                    context,
                    style: style,
                    zoneRects: zoneRects,
                    segmentsByIndex: segmentsByIndex,
                    activeIndex: layout.activeZoneIndex,
                    cornerRadius: cornerRadius,
                    crossThickness: crossThickness
                )

                drawSegments(
                    context,
                    style: style,
                    zoneRects: zoneRects,
                    segmentsByIndex: segmentsByIndex,
                    activeIndex: layout.activeZoneIndex,
                    cornerRadius: cornerRadius
                )

                if style.borderEnabled, style.borderOpacity > 0, style.borderWidth > 0 {
                    SkiaIntervalDraw.strokeRoundRect(
                        context,
                        barRect,
                        radius: min(cornerRadius, crossThickness / 2),
                        lineWidth: max(style.borderWidth * element.scale, 0.5),
                        color: style.borderColor,
                        opacity: style.borderOpacity
                    )
                }

                let metrics = MarkerMetrics(
                    crossThickness: crossThickness,
                    elementScale: element.scale,
                    textStyle: layout.markerText,
                    showsValue: style.markerShowsValue
                )

                if let marker = layout.thresholdZoneMarker,
                   let zoneRect = rectsByIndex[marker.zoneIndex] {
                    drawThresholdMarker(
                        context,
                        marker: marker,
                        zoneRect: zoneRect,
                        layout: layout,
                        metrics: metrics
                    )
                }
                if let marker = layout.zoneMarker,
                   let zoneRect = rectsByIndex[marker.zoneIndex] {
                    drawCurrentMarker(
                        context,
                        marker: marker,
                        zoneRect: zoneRect,
                        layout: layout,
                        metrics: metrics
                    )
                }
            }
        }
    }

    // MARK: - Bars

    private static func drawGlow(
        _ context: OpaquePointer,
        style: ZoneEdgeBarStyle,
        zoneRects: [IntervalZoneBarRect],
        segmentsByIndex: [Int: IntervalHUDBarZoneSegment],
        activeIndex: Int?,
        cornerRadius: Double,
        crossThickness: Double
    ) {
        guard style.glowEnabled,
              let activeIndex,
              let activeRect = zoneRects.first(where: { $0.index == activeIndex })?.rect,
              let activeSegment = segmentsByIndex[activeIndex] else { return }

        let radius = min(cornerRadius, activeRect.width / 2, activeRect.height / 2)
        let sigma = SkiaIntervalDraw.blurSigma(crossThickness * 1.6)
        SkiaIntervalDraw.withBlur(
            context,
            sigma: sigma,
            // SwiftUI's `.blur` is not clipped to the shape; give the layer
            // enough bleed room for the Gaussian tail.
            bounds: activeRect.insetBy(dx: -sigma * 3, dy: -sigma * 3)
        ) {
            SkiaIntervalDraw.fillRoundRect(
                context,
                activeRect,
                radius: radius,
                color: activeSegment.color,
                opacity: style.glowIntensity
            )
        }
    }

    private static func drawSegments(
        _ context: OpaquePointer,
        style: ZoneEdgeBarStyle,
        zoneRects: [IntervalZoneBarRect],
        segmentsByIndex: [Int: IntervalHUDBarZoneSegment],
        activeIndex: Int?,
        cornerRadius: Double
    ) {
        for zoneRect in zoneRects {
            guard let segment = segmentsByIndex[zoneRect.index] else { continue }
            let isActive = zoneRect.index == activeIndex
            SkiaIntervalDraw.fillRoundRect(
                context,
                zoneRect.rect,
                radius: min(cornerRadius, zoneRect.rect.width / 2, zoneRect.rect.height / 2),
                color: segment.color,
                opacity: isActive ? 1 : style.inactiveZoneOpacity
            )
        }
    }

    // MARK: - Markers

    private struct MarkerMetrics {
        var crossThickness: Double
        var elementScale: Double
        var textStyle: IntervalHUDBarTextStyle
        var showsValue: Bool

        var gap: Double { max(crossThickness * 0.35, 3) }
        var stackSpacing: Double { 2 }
        var pillHorizontalPadding: Double { 5 }
        var pillVerticalPadding: Double { 2 }
        var pillCornerRadius: Double { 4 }
        var thresholdLineLength: Double { max(crossThickness * 1.35, 10) }
        var thresholdLineThickness: Double { max(1.2 * elementScale, 1) }
        var thresholdTextSize: Double { max(textStyle.fontSize * 0.72, 7) }
        var currentTextSize: Double { max(textStyle.fontSize, 7) }

        func currentArrowSize(orientation: ZoneEdgeBarOrientation) -> CGSize {
            if orientation == .horizontal {
                return CGSize(
                    width: max(crossThickness * 1.35, 12),
                    height: max(crossThickness * 0.9, 8)
                )
            }
            return CGSize(
                width: max(crossThickness * 0.9, 8),
                height: max(crossThickness * 1.35, 12)
            )
        }

        func currentMarkerHeight(showsValue: Bool) -> Double {
            max(crossThickness * 0.9, 8)
                + (showsValue ? max(textStyle.fontSize, 9) + 8 : 0)
        }

        func currentMarkerWidth(showsValue: Bool) -> Double {
            max(crossThickness * 0.9, 8) + (showsValue ? 84 : 0)
        }
    }

    private static func currentAnchor(
        marker: IntervalHUDBarZoneMarker,
        zoneRect: CGRect,
        layout: ZoneEdgeBarRenderLayout,
        metrics: MarkerMetrics
    ) -> CGPoint {
        let barRect = layout.barRect
        if layout.orientation == .horizontal {
            let x = zoneRect.minX + zoneRect.width * marker.fractionInZone
            switch layout.markerSide {
            case .above:
                return CGPoint(x: x, y: barRect.minY - metrics.currentMarkerHeight(showsValue: metrics.showsValue) / 2 - metrics.gap)
            case .below:
                return CGPoint(x: x, y: barRect.maxY + metrics.currentMarkerHeight(showsValue: metrics.showsValue) / 2 + metrics.gap)
            case .leading, .trailing:
                return CGPoint(x: x, y: barRect.midY)
            }
        }

        let y = zoneRect.maxY - zoneRect.height * marker.fractionInZone
        switch layout.markerSide {
        case .leading:
            return CGPoint(x: barRect.minX - metrics.currentMarkerWidth(showsValue: metrics.showsValue) / 2 - metrics.gap, y: y)
        case .trailing:
            return CGPoint(x: barRect.maxX + metrics.currentMarkerWidth(showsValue: metrics.showsValue) / 2 + metrics.gap, y: y)
        case .above, .below:
            return CGPoint(x: barRect.midX, y: y)
        }
    }

    private static func drawCurrentMarker(
        _ context: OpaquePointer,
        marker: IntervalHUDBarZoneMarker,
        zoneRect: CGRect,
        layout: ZoneEdgeBarRenderLayout,
        metrics: MarkerMetrics
    ) {
        let anchor = currentAnchor(marker: marker, zoneRect: zoneRect, layout: layout, metrics: metrics)
        let arrow = metrics.currentArrowSize(orientation: layout.orientation)
        let textFont = SkiaIntervalText.font(
            family: metrics.textStyle.fontName,
            size: metrics.currentTextSize,
            weight: metrics.textStyle.fontWeight,
            monospacedDigits: true
        )
        let textLine = SkiaIntervalText.makeLine(marker.valueText, font: textFont)
        let pillSize = CGSize(
            width: textLine.width + metrics.pillHorizontalPadding * 2,
            height: textLine.height + metrics.pillVerticalPadding * 2
        )

        if layout.orientation == .horizontal {
            var items: [(rect: CGRect, isPill: Bool)] = []
            var totalHeight = arrow.height
            var itemCount = 1
            let showsPillAbove = layout.markerSide == .above && metrics.showsValue
            let showsPillBelow = layout.markerSide == .below && metrics.showsValue
            if showsPillAbove {
                totalHeight += pillSize.height
                itemCount += 1
            }
            if showsPillBelow {
                totalHeight += pillSize.height
                itemCount += 1
            }
            totalHeight += metrics.stackSpacing * Double(max(itemCount - 1, 0))
            var top = anchor.y - totalHeight / 2

            if showsPillAbove {
                items.append((
                    CGRect(
                        x: anchor.x - pillSize.width / 2,
                        y: top,
                        width: pillSize.width,
                        height: pillSize.height
                    ),
                    true
                ))
                top += pillSize.height + metrics.stackSpacing
            }
            items.append((
                CGRect(
                    x: anchor.x - arrow.width / 2,
                    y: top,
                    width: arrow.width,
                    height: arrow.height
                ),
                false
            ))
            top += arrow.height + metrics.stackSpacing
            if showsPillBelow {
                items.append((
                    CGRect(
                        x: anchor.x - pillSize.width / 2,
                        y: top,
                        width: pillSize.width,
                        height: pillSize.height
                    ),
                    true
                ))
            }

            for item in items {
                if item.isPill {
                    drawPill(
                        context,
                        text: marker.valueText,
                        rect: item.rect,
                        font: textFont,
                        line: textLine,
                        color: marker.color,
                        metrics: metrics
                    )
                } else {
                    let rect = item.rect
                    if layout.markerSide == .above {
                        SkiaIntervalDraw.fillTriangle(
                            context,
                            CGPoint(x: rect.minX, y: rect.minY),
                            CGPoint(x: rect.maxX, y: rect.minY),
                            CGPoint(x: rect.midX, y: rect.maxY),
                            color: marker.color
                        )
                    } else {
                        SkiaIntervalDraw.fillTriangle(
                            context,
                            CGPoint(x: rect.midX, y: rect.minY),
                            CGPoint(x: rect.maxX, y: rect.maxY),
                            CGPoint(x: rect.minX, y: rect.maxY),
                            color: marker.color
                        )
                    }
                }
            }
            return
        }

        var totalWidth = arrow.width
        var itemCount = 1
        let showsPillLeading = layout.markerSide == .leading && metrics.showsValue
        let showsPillTrailing = layout.markerSide == .trailing && metrics.showsValue
        if showsPillLeading {
            totalWidth += pillSize.width
            itemCount += 1
        }
        if showsPillTrailing {
            totalWidth += pillSize.width
            itemCount += 1
        }
        totalWidth += metrics.stackSpacing * Double(max(itemCount - 1, 0))
        var left = anchor.x - totalWidth / 2

        if showsPillLeading {
            let rect = CGRect(x: left, y: anchor.y - pillSize.height / 2, width: pillSize.width, height: pillSize.height)
            drawPill(
                context,
                text: marker.valueText,
                rect: rect,
                font: textFont,
                line: textLine,
                color: marker.color,
                metrics: metrics
            )
            left += pillSize.width + metrics.stackSpacing
        }

        let triangleRect = CGRect(
            x: left,
            y: anchor.y - arrow.height / 2,
            width: arrow.width,
            height: arrow.height
        )
        if layout.markerSide == .leading {
            SkiaIntervalDraw.fillTriangle(
                context,
                CGPoint(x: triangleRect.maxX, y: triangleRect.midY),
                CGPoint(x: triangleRect.minX, y: triangleRect.minY),
                CGPoint(x: triangleRect.minX, y: triangleRect.maxY),
                color: marker.color
            )
        } else {
            SkiaIntervalDraw.fillTriangle(
                context,
                CGPoint(x: triangleRect.minX, y: triangleRect.midY),
                CGPoint(x: triangleRect.maxX, y: triangleRect.minY),
                CGPoint(x: triangleRect.maxX, y: triangleRect.maxY),
                color: marker.color
            )
        }
        left += arrow.width + metrics.stackSpacing

        if showsPillTrailing {
            let rect = CGRect(x: left, y: anchor.y - pillSize.height / 2, width: pillSize.width, height: pillSize.height)
            drawPill(
                context,
                text: marker.valueText,
                rect: rect,
                font: textFont,
                line: textLine,
                color: marker.color,
                metrics: metrics
            )
        }
    }

    private static func drawPill(
        _ context: OpaquePointer,
        text: String,
        rect: CGRect,
        font: NSFont,
        line: SkiaIntervalText.Line,
        color: OverlayColor,
        metrics: MarkerMetrics
    ) {
        SkiaIntervalDraw.fillRoundRect(
            context,
            rect,
            radius: metrics.pillCornerRadius,
            color: .black,
            opacity: 0.55
        )
        let textRect = rect.insetBy(
            dx: metrics.pillHorizontalPadding,
            dy: metrics.pillVerticalPadding
        )
        let x = textRect.midX - line.width / 2
        let baselineY = textRect.midY - line.height / 2 + line.ascent
        SkiaIntervalText.draw(
            line,
            font: font,
            x: x,
            baselineY: baselineY,
            color: color,
            opacity: 1,
            context: context
        )
    }

    private static func drawThresholdMarker(
        _ context: OpaquePointer,
        marker: IntervalHUDBarZoneMarker,
        zoneRect: CGRect,
        layout: ZoneEdgeBarRenderLayout,
        metrics: MarkerMetrics
    ) {
        let barRect = layout.barRect
        let textFont = SkiaIntervalText.font(
            family: metrics.textStyle.fontName,
            size: metrics.thresholdTextSize,
            weight: metrics.textStyle.fontWeight,
            monospacedDigits: true
        )
        let line = SkiaIntervalText.makeLine(marker.valueText, font: textFont)
        let labelAndSpacing = metrics.thresholdTextSize + 6
        let color = marker.color

        if layout.orientation == .horizontal {
            let anchorX = zoneRect.minX + zoneRect.width * marker.fractionInZone
            let offset = layout.markerSide == .above ? -labelAndSpacing / 2 : labelAndSpacing / 2
            let totalHeight = line.height + metrics.stackSpacing + metrics.thresholdLineLength
            var top = barRect.midY + offset - totalHeight / 2
            let textAbove = layout.markerSide == .above

            if textAbove {
                drawThresholdText(
                    context,
                    line: line,
                    font: textFont,
                    centerX: anchorX,
                    top: top,
                    color: color
                )
                top += line.height + metrics.stackSpacing
            }

            SkiaIntervalDraw.fillCapsule(
                context,
                CGRect(
                    x: anchorX - metrics.thresholdLineThickness / 2,
                    y: top,
                    width: metrics.thresholdLineThickness,
                    height: metrics.thresholdLineLength
                ),
                color: color,
                opacity: 0.78
            )
            top += metrics.thresholdLineLength + metrics.stackSpacing

            if !textAbove {
                drawThresholdText(
                    context,
                    line: line,
                    font: textFont,
                    centerX: anchorX,
                    top: top,
                    color: color
                )
            }
            return
        }

        let anchorY = zoneRect.maxY - zoneRect.height * marker.fractionInZone
        let offset = layout.markerSide == .leading ? -labelAndSpacing / 2 : labelAndSpacing / 2
        let totalWidth = line.width + metrics.stackSpacing + metrics.thresholdLineLength
        var left = barRect.midX + offset - totalWidth / 2
        let textLeading = layout.markerSide == .leading

        if textLeading {
            drawThresholdText(
                context,
                line: line,
                font: textFont,
                left: left,
                centerY: anchorY,
                color: color
            )
            left += line.width + metrics.stackSpacing
        }

        SkiaIntervalDraw.fillCapsule(
            context,
            CGRect(
                x: left,
                y: anchorY - metrics.thresholdLineThickness / 2,
                width: metrics.thresholdLineLength,
                height: metrics.thresholdLineThickness
            ),
            color: color,
            opacity: 0.78
        )
        left += metrics.thresholdLineLength + metrics.stackSpacing

        if !textLeading {
            drawThresholdText(
                context,
                line: line,
                font: textFont,
                left: left,
                centerY: anchorY,
                color: color
            )
        }
    }

    private static func drawThresholdText(
        _ context: OpaquePointer,
        line: SkiaIntervalText.Line,
        font: NSFont,
        centerX: Double,
        top: Double,
        color: OverlayColor
    ) {
        SkiaIntervalText.draw(
            line,
            font: font,
            x: centerX - line.width / 2,
            baselineY: top + line.ascent,
            color: color,
            opacity: 0.78,
            context: context
        )
    }

    private static func drawThresholdText(
        _ context: OpaquePointer,
        line: SkiaIntervalText.Line,
        font: NSFont,
        left: Double,
        centerY: Double,
        color: OverlayColor
    ) {
        SkiaIntervalText.draw(
            line,
            font: font,
            x: left,
            baselineY: centerY - line.height / 2 + line.ascent,
            color: color,
            opacity: 0.78,
            context: context
        )
    }
}
#endif
