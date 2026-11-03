#if canImport(CSkiaBridge)
import AppKit
import CSkiaBridge
import CoreGraphics
import Foundation

/// Skia port of `IntervalHUDBarOverlayView`.
///
/// The vertical content layout and cell/divider distribution still live in the
/// SwiftUI view. They are mirrored here module-locally and marked for a
/// follow-up lift into `OverlayRenderModel`; the zone-segment rects already
/// come from the shared helper.
enum IntervalHUDBarSkiaRenderer {
    static func draw(
        _ element: OverlayElement,
        layout: IntervalHUDBarRenderLayout,
        context: OpaquePointer,
        maskCache: SkiaIntervalDraw.MaskCache
    ) {
        let style = element.style
        let rect = layout.rect
        let padX = layout.backgroundPaddingX
        let padY = layout.backgroundPaddingY
        let backgroundRect = rect.insetBy(dx: -padX, dy: -padY)
        let shadowSigma = SkiaIntervalDraw.shadowSigma(style.shadowRadius)
        let bleed = max(padX, padY)
            + max(layout.barHeight * 4, 48)
            + max(shadowSigma * 3, 0)
            + 24
        let drawBounds = rect.insetBy(dx: -bleed, dy: -bleed)

        let vertical = verticalLayout(element: element, layout: layout)
        let horizontalPadding = rect.width * 0.035
        let contentWidth = max(rect.width - horizontalPadding * 2, 1)
        let hasBottomBar = style.intervalHUDBar.bottomBarEnabled
            && style.intervalHUDBar.bottomBarMode != .none
        let bottomBarRect = CGRect(
            x: rect.minX + horizontalPadding,
            y: rect.minY + vertical.topPadding
                + vertical.mainContentHeight
                + vertical.spacing,
            width: contentWidth,
            height: layout.barHeight
        )
        let cellsRect = CGRect(
            x: rect.minX + horizontalPadding,
            y: rect.minY + vertical.topPadding,
            width: contentWidth,
            height: vertical.mainContentHeight
        )

        SkiaIntervalDraw.withElementOpacity(context, element: element, bounds: drawBounds) {
            if style.backgroundEnabled {
                SkiaIntervalDraw.withShadowChain(
                    context,
                    shadows: layeredShadows(element, isEnabled: true),
                    bounds: drawBounds
                ) {
                    // TODO(Group T / materials): `backgroundBlurRadius` material
                    // blur has no bridge primitive; fade and color are drawn.
                    SkiaIntervalDraw.fillFeatheredBackground(
                        context,
                        rect: backgroundRect,
                        cornerRadius: layout.backgroundRadius,
                        color: style.backgroundColor,
                        opacity: style.backgroundOpacity,
                        fadeEnabled: style.backgroundFadeOutEnabled,
                        fadeAmount: style.backgroundFadeOutAmount,
                        maskCache: maskCache
                    )
                }
            }

            SkiaIntervalDraw.withShadowChain(
                context,
                shadows: layeredShadows(
                    element,
                    isEnabled: !style.backgroundEnabled && !style.borderEnabled
                ),
                bounds: drawBounds
            ) {
                drawCells(
                    element,
                    layout: layout,
                    rect: cellsRect,
                    context: context
                )
                if hasBottomBar {
                    drawBottomBar(
                        element,
                        layout: layout,
                        barRect: bottomBarRect,
                        context: context
                    )
                }
            }

            if style.borderEnabled {
                SkiaIntervalDraw.strokeRoundRect(
                    context,
                    backgroundRect,
                    radius: layout.backgroundRadius,
                    lineWidth: layout.borderWidth,
                    color: style.borderColor,
                    opacity: style.borderOpacity
                )
            }
        }
    }

    // MARK: - Vertical layout

    private struct VerticalLayout {
        var topPadding: Double
        var bottomPadding: Double
        var spacing: Double
        var mainContentHeight: Double
    }

    private static func verticalLayout(
        element: OverlayElement,
        layout: IntervalHUDBarRenderLayout
    ) -> VerticalLayout {
        let style = layout.style
        let basis = max(layout.baseHeight, 1)
        let hasBottomBar = style.bottomBarEnabled && style.bottomBarMode != .none
        let desiredTop = basis * 0.06
        let desiredBottom = basis * 0.12
        let minimumTop = max(basis * 0.025, 2)
        let minimumBottom = max(basis * 0.025, 2)
        let spacing = hasBottomBar ? layout.bottomBarSpacing : 0
        let maxTextStack = max(
            layout.primaryValueText.fontSize + layout.labelText.fontSize + 4,
            layout.phaseText.fontSize + layout.phaseDetailText.fontSize + 3,
            layout.metricValueText.fontSize
                + max(layout.labelText.fontSize, layout.metricUnitText.fontSize) + 4
        )
        let minimumContent = max(
            basis * 0.30,
            min(maxTextStack + 4, basis * 0.58)
        )
        let bottomHeight = hasBottomBar ? layout.barHeight : 0
        let desiredTotal = desiredTop + minimumContent + bottomHeight + desiredBottom

        var top = desiredTop
        var bottom = desiredBottom
        if hasBottomBar, desiredTotal > basis {
            let availablePadding = basis - minimumContent - bottomHeight
            if availablePadding >= minimumTop + minimumBottom {
                let desiredPadding = max(desiredTop + desiredBottom, 1)
                let topShare = desiredTop / desiredPadding
                top = max(minimumTop, availablePadding * topShare)
                bottom = max(minimumBottom, availablePadding - top)
            } else {
                top = minimumTop
                bottom = minimumBottom
            }
        }

        let availableHeight = max(layout.rect.height - top - bottom, 1)
        let mainContentHeight = hasBottomBar
            ? max(availableHeight - bottomHeight - spacing, 1)
            : availableHeight
        return VerticalLayout(
            topPadding: top,
            bottomPadding: bottom,
            spacing: spacing,
            mainContentHeight: mainContentHeight
        )
    }

    // MARK: - Cells

    private enum Cell {
        case rep
        case phase
        case remaining
        case metric(IntervalHUDBarMetricItem)
    }

    private static func cells(layout: IntervalHUDBarRenderLayout) -> [Cell] {
        let style = layout.style
        var output: [Cell] = []
        if style.showsRep {
            output.append(.rep)
        }
        if style.showsPhase {
            output.append(.phase)
        }
        if style.showsRemaining {
            output.append(.remaining)
        }
        if let zoneItem = layout.zoneItem {
            output.append(.metric(zoneItem))
        }
        output.append(contentsOf: layout.metricItems.map { .metric($0) })
        return output
    }

    private static func drawCells(
        _ element: OverlayElement,
        layout: IntervalHUDBarRenderLayout,
        rect: CGRect,
        context: OpaquePointer
    ) {
        let items = cells(layout: layout)
        guard !items.isEmpty else { return }
        let style = element.style
        let dividerPadding = layout.rect.width * 0.025
        let dividerOccupied = layout.dividerThickness + dividerPadding * 2
        let dividerCount = max(items.count - 1, 0)
        let totalDivider = dividerOccupied * Double(dividerCount)
        let cellWidth = max((rect.width - totalDivider) / Double(items.count), 1)

        var x = rect.minX
        for (index, cell) in items.enumerated() {
            if index > 0 {
                let lineX = x + dividerPadding
                if style.dividerEnabled {
                    SkiaIntervalDraw.fillRect(
                        context,
                        CGRect(
                            x: lineX,
                            y: rect.midY - layout.baseHeight * 0.24,
                            width: layout.dividerThickness,
                            height: layout.baseHeight * 0.48
                        ),
                        color: style.dividerColor,
                        opacity: style.dividerOpacity
                    )
                }
                x += dividerOccupied
            }
            drawCell(
                element,
                cell: cell,
                layout: layout,
                rect: CGRect(
                    x: x,
                    y: rect.minY,
                    width: cellWidth,
                    height: rect.height
                ),
                context: context
            )
            x += cellWidth
        }
    }

    private static func drawCell(
        _ element: OverlayElement,
        cell: Cell,
        layout: IntervalHUDBarRenderLayout,
        rect: CGRect,
        context: OpaquePointer
    ) {
        switch cell {
        case .rep:
            drawRows(
                element,
                layout: layout,
                rect: rect,
                spacing: 4,
                rows: [
                    textRow(
                        element,
                        text: "REP",
                        style: layout.labelText,
                        color: element.style.labelColor,
                        opacity: 0.66,
                        minimumScaleFactor: 0.70
                    ),
                    textRow(
                        element,
                        text: layout.repText,
                        style: layout.primaryValueText,
                        sizeScale: 0.86,
                        color: element.style.foregroundColor,
                        minimumScaleFactor: 0.70,
                        monospacedDigits: true
                    )
                ],
                context: context
            )
        case .phase:
            drawRows(
                element,
                layout: layout,
                rect: rect,
                spacing: 3,
                rows: [
                    textRow(
                        element,
                        text: layout.phaseLabel,
                        style: layout.phaseText,
                        color: layout.phaseColor,
                        minimumScaleFactor: 0.72,
                        monospacedDigits: true
                    ),
                    textRow(
                        element,
                        text: layout.phaseDetail,
                        style: layout.phaseDetailText,
                        color: element.style.foregroundColor,
                        opacity: 0.88,
                        minimumScaleFactor: 0.72,
                        monospacedDigits: true
                    )
                ],
                context: context
            )
        case .remaining:
            drawRows(
                element,
                layout: layout,
                rect: rect,
                spacing: 3,
                rows: [
                    textRow(
                        element,
                        text: layout.remainingPrimaryText,
                        style: layout.primaryValueText,
                        color: element.style.foregroundColor,
                        minimumScaleFactor: 0.70,
                        monospacedDigits: true
                    ),
                    SkiaIntervalText.Row(
                        items: [
                            rowItem(
                                element,
                                text: layout.remainingPrimaryLabel,
                                style: layout.labelText,
                                color: element.style.labelColor,
                                opacity: 0.72,
                                minimumScaleFactor: 0.70
                            ),
                            rowItem(
                                element,
                                text: layout.remainingSecondaryText,
                                style: layout.metricUnitText,
                                color: element.style.labelColor,
                                opacity: 0.72,
                                minimumScaleFactor: 0.70,
                                monospacedDigits: true
                            )
                        ],
                        spacing: 6
                    )
                ],
                context: context
            )
        case .metric(let item):
            var metricItems: [SkiaIntervalText.RowItem] = [
                rowItem(
                    element,
                    text: item.value,
                    style: layout.metricValueText,
                    color: item.accentColor ?? element.style.foregroundColor,
                    minimumScaleFactor: 0.68,
                    monospacedDigits: true
                )
            ]
            if !item.unit.isEmpty {
                metricItems.append(rowItem(
                    element,
                    text: item.unit,
                    style: layout.metricUnitText,
                    color: element.style.unitColor,
                    opacity: 0.76,
                    minimumScaleFactor: 0.68
                ))
            }
            drawRows(
                element,
                layout: layout,
                rect: rect,
                spacing: 4,
                rows: [
                    textRow(
                        element,
                        text: item.label,
                        style: layout.labelText,
                        color: element.style.labelColor,
                        opacity: 0.66,
                        minimumScaleFactor: 1
                    ),
                    SkiaIntervalText.Row(
                        items: metricItems,
                        spacing: 3,
                        alignment: .firstTextBaseline
                    )
                ],
                context: context
            )
        }
    }

    private static func textRow(
        _ element: OverlayElement,
        text: String,
        style: IntervalHUDBarTextStyle,
        sizeScale: Double = 1,
        color: OverlayColor,
        opacity: Double = 1,
        minimumScaleFactor: Double,
        monospacedDigits: Bool = false
    ) -> SkiaIntervalText.Row {
        SkiaIntervalText.Row(
            items: [
                rowItem(
                    element,
                    text: text,
                    style: style,
                    sizeScale: sizeScale,
                    color: color,
                    opacity: opacity,
                    minimumScaleFactor: minimumScaleFactor,
                    monospacedDigits: monospacedDigits
                )
            ],
            spacing: 0
        )
    }

    private static func rowItem(
        _ element: OverlayElement,
        text: String,
        style: IntervalHUDBarTextStyle,
        sizeScale: Double = 1,
        color: OverlayColor,
        opacity: Double = 1,
        minimumScaleFactor: Double,
        monospacedDigits: Bool = false
    ) -> SkiaIntervalText.RowItem {
        SkiaIntervalText.RowItem(
            text: text,
            font: SkiaIntervalText.font(
                family: style.fontName,
                size: style.fontSize * sizeScale,
                weight: style.fontWeight,
                monospacedDigits: monospacedDigits
            ),
            color: color,
            opacity: opacity,
            minimumScaleFactor: minimumScaleFactor
        )
    }

    private static func drawRows(
        _ element: OverlayElement,
        layout: IntervalHUDBarRenderLayout,
        rect: CGRect,
        spacing: Double,
        rows: [SkiaIntervalText.Row],
        context: OpaquePointer
    ) {
        SkiaIntervalText.drawRows(
            rows,
            rect: rect,
            spacing: spacing,
            context: context
        )
    }

    // MARK: - Bottom bar

    private static func drawBottomBar(
        _ element: OverlayElement,
        layout: IntervalHUDBarRenderLayout,
        barRect: CGRect,
        context: OpaquePointer
    ) {
        let style = layout.style
        let cornerRadius = min(
            layout.bottomBarCornerRadius,
            barRect.height / 2
        )
        switch style.bottomBarMode {
        case .none:
            return
        case .lapProgress:
            SkiaIntervalDraw.fillRoundRect(
                context,
                barRect,
                radius: cornerRadius,
                color: style.trackColor,
                opacity: style.trackOpacity
            )
            let progressWidth = max(
                barRect.width * layout.progress,
                layout.progress > 0 ? barRect.height : 0
            )
            if progressWidth > 0 {
                let fillRect = CGRect(
                    x: barRect.minX,
                    y: barRect.minY,
                    width: min(progressWidth, barRect.width),
                    height: barRect.height
                )
                SkiaIntervalDraw.withShadowChain(
                    context,
                    shadows: style.bottomBarGlowEnabled
                        ? [.init(
                            radius: layout.barHeight * 1.2,
                            dx: 0,
                            dy: 0,
                            color: layout.phaseColor,
                            alpha: style.bottomBarGlowIntensity
                        )]
                        : [],
                    bounds: fillRect.insetBy(dx: -layout.barHeight * 2, dy: -layout.barHeight * 2)
                ) {
                    SkiaIntervalDraw.fillRoundRect(
                        context,
                        fillRect,
                        radius: min(cornerRadius, fillRect.width / 2),
                        color: layout.phaseColor
                    )
                }
            }
            drawBottomBarBorder(element, layout: layout, barRect: barRect, radius: cornerRadius, context: context)
        case .heartRateZones, .paceZones:
            let frames = OverlayRenderModel.intervalZoneSegmentFrames(
                segmentCount: layout.zoneSegments.count,
                activeIndex: layout.bottomBarActiveZoneIndex,
                activeWidthShare: style.activeZoneWidthShare
            )
            let zoneRects = OverlayRenderModel.intervalZoneBarRects(
                frames: frames,
                segments: layout.zoneSegments,
                barRect: barRect,
                activeIndex: layout.bottomBarActiveZoneIndex,
                activeThicknessScale: style.activeZoneHeightScale,
                segmentGap: style.zoneSegmentGap,
                elementScale: element.scale,
                orientation: .horizontal
            )
            let segmentsByIndex = Dictionary(
                uniqueKeysWithValues: layout.zoneSegments.map { ($0.index, $0) }
            )

            if style.bottomBarGlowEnabled,
               let activeIndex = layout.bottomBarActiveZoneIndex,
               let activeRect = zoneRects.first(where: { $0.index == activeIndex })?.rect,
               let activeSegment = segmentsByIndex[activeIndex] {
                let sigma = SkiaIntervalDraw.blurSigma(layout.barHeight * 1.6)
                SkiaIntervalDraw.withBlur(
                    context,
                    sigma: sigma,
                    bounds: activeRect.insetBy(dx: -sigma * 3, dy: -sigma * 3)
                ) {
                    SkiaIntervalDraw.fillRoundRect(
                        context,
                        activeRect,
                        radius: min(cornerRadius, activeRect.height / 2, activeRect.width / 2),
                        color: activeSegment.color,
                        opacity: style.bottomBarGlowIntensity
                    )
                }
            }

            for zoneRect in zoneRects {
                guard let segment = segmentsByIndex[zoneRect.index] else { continue }
                let isActive = zoneRect.index == layout.bottomBarActiveZoneIndex
                SkiaIntervalDraw.fillRoundRect(
                    context,
                    zoneRect.rect,
                    radius: min(
                        cornerRadius,
                        zoneRect.rect.height / 2,
                        zoneRect.rect.width / 2
                    ),
                    color: segment.color,
                    opacity: isActive ? 1 : style.inactiveZoneOpacity
                )
            }

            drawBottomBarBorder(element, layout: layout, barRect: barRect, radius: cornerRadius, context: context)

            let rectsByIndex = Dictionary(
                uniqueKeysWithValues: zoneRects.map { ($0.index, $0.rect) }
            )
            if let marker = layout.thresholdZoneMarker,
               let zoneRect = rectsByIndex[marker.zoneIndex] {
                drawThresholdMarker(
                    element,
                    marker: marker,
                    zoneRect: zoneRect,
                    barRect: barRect,
                    layout: layout,
                    context: context
                )
            }
            if let marker = layout.zoneMarker,
               let zoneRect = rectsByIndex[marker.zoneIndex] {
                drawCurrentMarker(
                    element,
                    marker: marker,
                    zoneRect: zoneRect,
                    barRect: barRect,
                    layout: layout,
                    context: context
                )
            }
        }
    }

    private static func drawBottomBarBorder(
        _ element: OverlayElement,
        layout: IntervalHUDBarRenderLayout,
        barRect: CGRect,
        radius: Double,
        context: OpaquePointer
    ) {
        let style = layout.style
        guard style.bottomBarBorderEnabled,
              style.bottomBarBorderWidth > 0,
              style.bottomBarBorderOpacity > 0 else { return }
        SkiaIntervalDraw.strokeRoundRect(
            context,
            barRect,
            radius: radius,
            lineWidth: layout.bottomBarBorderWidth,
            color: style.bottomBarBorderColor,
            opacity: style.bottomBarBorderOpacity
        )
    }

    // MARK: - Zone markers

    private static func drawThresholdMarker(
        _ element: OverlayElement,
        marker: IntervalHUDBarZoneMarker,
        zoneRect: CGRect,
        barRect: CGRect,
        layout: IntervalHUDBarRenderLayout,
        context: OpaquePointer
    ) {
        let metrics = IntervalHUDBarZoneMarkerMetrics.threshold(
            barHeight: layout.barHeight,
            markerScale: element.scale,
            textStyle: layout.metricUnitText
        )
        let font = SkiaIntervalText.font(
            family: layout.metricUnitText.fontName,
            size: metrics.valueFontSize,
            weight: layout.metricUnitText.fontWeight,
            monospacedDigits: false
        )
        let line = SkiaIntervalText.makeLine(marker.valueText, font: font)
        let formulaLabelHeight = metrics.valueFontSize + 4
        let formulaHeight = metrics.thresholdLineHeight + metrics.stackSpacing + formulaLabelHeight
        let centerY = barRect.minY
            + layout.barHeight / 2
            - metrics.thresholdLineHeight / 2
            + formulaHeight / 2
        let centerX = zoneRect.minX + zoneRect.width * marker.fractionInZone
        let actualHeight = metrics.thresholdLineHeight + metrics.stackSpacing + line.height
        let top = centerY - actualHeight / 2

        SkiaIntervalDraw.fillCapsule(
            context,
            CGRect(
                x: centerX - metrics.thresholdLineWidth / 2,
                y: top,
                width: metrics.thresholdLineWidth,
                height: metrics.thresholdLineHeight
            ),
            color: marker.color,
            opacity: 0.78
        )
        let textTop = top + metrics.thresholdLineHeight + metrics.stackSpacing
        SkiaIntervalText.draw(
            line,
            font: font,
            x: centerX - line.width / 2,
            baselineY: textTop + line.ascent,
            color: marker.color,
            opacity: 0.78,
            context: context
        )
    }

    private static func drawCurrentMarker(
        _ element: OverlayElement,
        marker: IntervalHUDBarZoneMarker,
        zoneRect: CGRect,
        barRect: CGRect,
        layout: IntervalHUDBarRenderLayout,
        context: OpaquePointer
    ) {
        let style = layout.style
        let metrics = IntervalHUDBarZoneMarkerMetrics.current(
            barHeight: layout.barHeight,
            markerPosition: style.zoneMarkerPosition,
            textStyle: layout.metricUnitText
        )
        let above = style.zoneMarkerPosition == .above
        let showsValue = style.zoneMarkerShowsValue
        let font = SkiaIntervalText.font(
            family: layout.metricUnitText.fontName,
            size: metrics.valueFontSize,
            weight: layout.metricUnitText.fontWeight,
            monospacedDigits: true
        )
        let line = SkiaIntervalText.makeLine(marker.valueText, font: font)
        let pillSize = CGSize(
            width: line.width + metrics.valueHorizontalPadding * 2,
            height: line.height + metrics.valueVerticalPadding * 2
        )

        let formulaValueHeight = showsValue ? metrics.valueFontSize + 4 : 0
        let formulaHeight = metrics.arrowHeight
            + formulaValueHeight
            + (showsValue ? metrics.stackSpacing : 0)
        let centerY = above
            ? barRect.minY - metrics.gap - formulaHeight / 2
            : barRect.maxY + metrics.gap + formulaHeight / 2
        let centerX = zoneRect.minX + zoneRect.width * marker.fractionInZone

        let actualValueHeight = showsValue ? pillSize.height : 0
        let actualSpacing = showsValue ? metrics.stackSpacing : 0
        let actualHeight = metrics.arrowHeight + actualValueHeight + actualSpacing
        var top = centerY - actualHeight / 2

        func drawTriangle(_ rect: CGRect) {
            if above {
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

        func drawValue(_ rect: CGRect) {
            SkiaIntervalDraw.fillRoundRect(
                context,
                rect,
                radius: metrics.valueCornerRadius,
                color: .black,
                opacity: 0.55
            )
            SkiaIntervalText.draw(
                line,
                font: font,
                x: rect.midX - line.width / 2,
                baselineY: rect.midY - line.height / 2 + line.ascent,
                color: marker.color,
                opacity: 1,
                context: context
            )
        }

        var cursor = top
        if above {
            if showsValue {
                drawValue(CGRect(
                    x: centerX - pillSize.width / 2,
                    y: cursor,
                    width: pillSize.width,
                    height: pillSize.height
                ))
                cursor += pillSize.height + metrics.stackSpacing
            }
            drawTriangle(CGRect(
                x: centerX - metrics.arrowWidth / 2,
                y: cursor,
                width: metrics.arrowWidth,
                height: metrics.arrowHeight
            ))
        } else {
            drawTriangle(CGRect(
                x: centerX - metrics.arrowWidth / 2,
                y: cursor,
                width: metrics.arrowWidth,
                height: metrics.arrowHeight
            ))
            cursor += metrics.arrowHeight + metrics.stackSpacing
            if showsValue {
                drawValue(CGRect(
                    x: centerX - pillSize.width / 2,
                    y: cursor,
                    width: pillSize.width,
                    height: pillSize.height
                ))
            }
        }
    }

    // MARK: - Effects

    private static func layeredShadows(
        _ element: OverlayElement,
        isEnabled: Bool
    ) -> [SkiaIntervalDraw.Shadow] {
        let style = element.style
        guard isEnabled, style.shadowEnabled else { return [] }
        let thickness = style.shadowThickness
        return [
            .init(
                radius: style.shadowRadius,
                dx: style.shadowOffsetX,
                dy: style.shadowOffsetY,
                color: style.shadowColor,
                alpha: style.shadowOpacity
            ),
            .init(
                radius: style.shadowRadius * 0.72,
                dx: style.shadowOffsetX,
                dy: style.shadowOffsetY,
                color: style.shadowColor,
                alpha: style.shadowOpacity * max(thickness - 1, 0) * 0.32
            ),
            .init(
                radius: style.shadowRadius * 0.48,
                dx: style.shadowOffsetX,
                dy: style.shadowOffsetY,
                color: style.shadowColor,
                alpha: style.shadowOpacity * max(thickness - 2, 0) * 0.22
            )
        ]
    }
}
#endif
