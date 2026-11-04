#if canImport(CSkiaBridge)
import AppKit
import Foundation

/// Composes every `OverlayTextPreset` into pixel-space lines, icons,
/// dividers, and strokes. Geometry mirrors `TextPresetOverlayView`; style
/// values come from `OverlayTextRenderLayout`, never re-derived here.
enum SkiaTextPresetDrawing {
    static func compose(
        element: OverlayElement,
        layout: OverlayTextRenderLayout,
        renderContext: OverlayRenderContext
    ) -> SkiaTextComposition {
        let palette = SkiaTextPalette(element: element, layout: layout)
        switch layout.preset {
        case .minimal:
            return composeMinimal(
                element: element,
                layout: layout,
                palette: palette,
                includeChrome: true
            )
        case .minimalLabel:
            return composeMinimal(
                element: element,
                layout: layout,
                palette: palette,
                includeChrome: false
            )
        case .pillBadge:
            return composePill(element: element, layout: layout, palette: palette)
        case .metricCard:
            return composeMetricCard(element: element, layout: layout, palette: palette)
        case .bigNumber:
            return composeBigNumber(element: element, layout: layout, palette: palette)
        case .splitLabel:
            return composeSplitLabel(element: element, layout: layout, palette: palette)
        case .neonGlow:
            return composeNeonGlow(element: element, layout: layout, palette: palette)
        case .racingStripe:
            return composeRacingStripe(element: element, layout: layout, palette: palette)
        case .editorial:
            return composeEditorial(element: element, layout: layout, palette: palette)
        case .digitalWatch:
            return composeDigitalWatch(element: element, layout: layout, palette: palette)
        case .sportWatch:
            return composeSportWatch(element: element, layout: layout, palette: palette)
        case .inlineGhost:
            return composeInlineGhost(element: element, layout: layout, palette: palette)
        case .accentBar:
            return composeAccentBar(element: element, layout: layout, palette: palette)
        case .sportNeon:
            return composeSportNeon(element: element, layout: layout, palette: palette)
        case .serifEditorial:
            return composeSerifEditorial(element: element, layout: layout, palette: palette)
        }
    }

    // MARK: - Minimal

    private static func composeMinimal(
        element: OverlayElement,
        layout: OverlayTextRenderLayout,
        palette: SkiaTextPalette,
        includeChrome: Bool
    ) -> SkiaTextComposition {
        let style = element.style
        let valueFont = SkiaTextComposer.font(
            family: style.fontName,
            size: layout.fontSize,
            weight: .semibold
        )
        let unitFont = SkiaTextComposer.font(
            family: layout.unitFontName,
            size: layout.unitFontSize,
            overlayWeight: layout.unitFontWeight
        )
        let labelFont = SkiaTextComposer.font(
            family: layout.labelFontName,
            size: layout.labelFontSize,
            overlayWeight: layout.labelFontWeight
        )
        let valueLine = SkiaTextComposer.makeLine(
            layout.components.value,
            font: valueFont,
            tracking: -layout.fontSize * 0.012
        )
        let unitLine = SkiaTextComposer.makeLine(
            layout.components.unit,
            font: unitFont,
            tracking: 0
        )
        let labelLine = SkiaTextComposer.makeLine(
            layout.components.label,
            font: labelFont,
            tracking: layout.labelFontSize * 0.10
        )

        let showLabel = showsLabel(element, layout)
        let showUnit = showsUnit(element, layout)
        let showIcon = layout.iconEnabled && !layout.iconSystemName.isEmpty
        let inlineUnit = showUnit
            && (layout.unitPosition == .leading || layout.unitPosition == .trailing)
        let sideLabel = showLabel
            && (layout.labelPosition == .leading || layout.labelPosition == .trailing)

        let labelWidth = showLabel ? labelLine.width : 0
        let unitWidth = showUnit ? unitLine.width : 0
        let clusterNatural = valueLine.width
            + (inlineUnit ? unitWidth + layout.unitSpacing : 0)
            + (sideLabel ? labelWidth + layout.labelSpacing : 0)
        let stackWidth = max(
            clusterNatural,
            showLabel && (layout.labelPosition == .top || layout.labelPosition == .bottom)
                ? labelWidth : 0,
            showUnit && layout.unitPosition == .bottom ? unitWidth : 0
        )

        let clusterHeight = max(valueLine.height, inlineUnit ? unitLine.height : 0)
        let sideLabelHeight = sideLabel ? labelLine.height : 0
        let rowHeight = max(clusterHeight, sideLabelHeight)

        var lines: [SkiaTextPlacedLine] = []
        var y = 0.0

        if showLabel && layout.labelPosition == .top {
            lines.append(
                placed(
                    labelLine,
                    x: hOffset(labelWidth, stackWidth, layout.labelTextAlignment),
                    y: y,
                    color: palette.label,
                    opacity: palette.labelOpacity
                )
            )
            y += labelLine.height + layout.labelSpacing
        }

        let labelAlignment = SkiaTextVerticalAlignment(layout.labelTextAlignment)
        let clusterY = sideLabel
            ? vOffset(clusterHeight, rowHeight, labelAlignment)
            : 0
        let clusterStart = sideLabel && layout.labelPosition == .leading
            ? labelWidth + layout.labelSpacing
            : 0
        let clusterEnd = sideLabel && layout.labelPosition == .trailing
            ? stackWidth - labelWidth - layout.labelSpacing
            : stackWidth

        if sideLabel {
            let labelX = layout.labelPosition == .leading
                ? 0
                : stackWidth - labelWidth
            lines.append(
                placed(
                    labelLine,
                    x: labelX,
                    y: y + vOffset(labelLine.height, rowHeight, labelAlignment),
                    color: palette.label,
                    opacity: palette.labelOpacity
                )
            )
        }

        let inlineAlignment = inlineUnit
            ? SkiaTextVerticalAlignment(layout.unitTextAlignment)
            : .middle
        let unitSlot = inlineUnit ? unitWidth + layout.unitSpacing : 0
        let valueSlotStart = clusterStart
            + (inlineUnit && layout.unitPosition == .leading ? unitSlot : 0)
        let valueSlotEnd = clusterEnd
            - (inlineUnit && layout.unitPosition == .trailing ? unitSlot : 0)
        let valueSlotWidth = max(valueSlotEnd - valueSlotStart, 0)
        let valueX = valueSlotStart + hOffset(
            valueLine.width,
            valueSlotWidth,
            layout.valueTextAlignment
        )
        lines.append(
            placed(
                valueLine,
                x: valueX,
                y: y + clusterY
                    + vOffset(valueLine.height, clusterHeight, inlineAlignment),
                color: palette.value,
                opacity: palette.valueOpacity
            )
        )
        if inlineUnit {
            let unitX = layout.unitPosition == .leading
                ? clusterStart
                : clusterEnd - unitWidth
            lines.append(
                placed(
                    unitLine,
                    x: unitX,
                    y: y + clusterY
                        + vOffset(unitLine.height, clusterHeight, inlineAlignment),
                    color: palette.unit,
                    opacity: palette.unitOpacity
                )
            )
        }
        y += rowHeight

        if showUnit && layout.unitPosition == .bottom {
            y += layout.unitSpacing
            lines.append(
                placed(
                    unitLine,
                    x: hOffset(unitWidth, stackWidth, layout.unitTextAlignment),
                    y: y,
                    color: palette.unit,
                    opacity: palette.unitOpacity
                )
            )
            y += unitLine.height
        }
        if showLabel && layout.labelPosition == .bottom {
            y += layout.labelSpacing
            lines.append(
                placed(
                    labelLine,
                    x: hOffset(labelWidth, stackWidth, layout.labelTextAlignment),
                    y: y,
                    color: palette.label,
                    opacity: palette.labelOpacity
                )
            )
            y += labelLine.height
        }

        var coreSize = CGSize(width: stackWidth, height: y)
        var icons: [SkiaTextPlacedIcon] = []

        if showIcon {
            let iconSize = layout.iconSize
            let iconH = SkiaTextHorizontalAlignment(layout.iconTextAlignment)
            let iconV = SkiaTextVerticalAlignment(layout.iconTextAlignment)
            var textOffset = CGPoint.zero
            let iconRect: CGRect
            switch layout.iconPosition {
            case .top:
                let coreWidth = max(stackWidth, iconSize)
                iconRect = CGRect(
                    x: hOffset(iconSize, coreWidth, iconH),
                    y: 0,
                    width: iconSize,
                    height: iconSize
                )
                textOffset = CGPoint(x: 0, y: iconSize + layout.iconSpacing)
                coreSize = CGSize(
                    width: coreWidth,
                    height: iconSize + layout.iconSpacing + y
                )
            case .bottom:
                let coreWidth = max(stackWidth, iconSize)
                iconRect = CGRect(
                    x: hOffset(iconSize, coreWidth, iconH),
                    y: y + layout.iconSpacing,
                    width: iconSize,
                    height: iconSize
                )
                coreSize = CGSize(
                    width: coreWidth,
                    height: y + layout.iconSpacing + iconSize
                )
            case .leading:
                let coreHeight = max(y, iconSize)
                iconRect = CGRect(
                    x: 0,
                    y: vOffset(iconSize, coreHeight, iconV),
                    width: iconSize,
                    height: iconSize
                )
                textOffset = CGPoint(
                    x: iconSize + layout.iconSpacing,
                    y: vOffset(y, coreHeight, iconV)
                )
                coreSize = CGSize(
                    width: iconSize + layout.iconSpacing + stackWidth,
                    height: coreHeight
                )
            case .trailing:
                let coreHeight = max(y, iconSize)
                iconRect = CGRect(
                    x: stackWidth + layout.iconSpacing,
                    y: vOffset(iconSize, coreHeight, iconV),
                    width: iconSize,
                    height: iconSize
                )
                textOffset = CGPoint(x: 0, y: vOffset(y, coreHeight, iconV))
                coreSize = CGSize(
                    width: stackWidth + layout.iconSpacing + iconSize,
                    height: coreHeight
                )
            }
            lines = lines.map { line in
                var line = line
                line.origin.x += textOffset.x
                line.origin.y += textOffset.y
                return line
            }
            icons = [
                SkiaTextPlacedIcon(
                    systemName: layout.iconSystemName,
                    rect: iconRect,
                    color: palette.icon,
                    opacity: palette.iconOpacity
                )
            ]
        }

        let hasBackground = includeChrome && element.style.backgroundEnabled
        let padX = hasBackground ? layout.horizontalPadding : 0
        let padY = hasBackground ? layout.verticalPadding : 0
        let innerWidth = max(coreSize.width, layout.minimumWidth)
        let innerHeight = max(coreSize.height, layout.minimumHeight)
        let paddedWidth = innerWidth + padX * 2
        let paddedHeight = innerHeight + padY * 2
        let finalWidth = max(paddedWidth, layout.minimumWidth)
        let finalHeight = max(paddedHeight, layout.minimumHeight)
        let backgroundRect = hasBackground
            ? CGRect(x: 0, y: 0, width: paddedWidth, height: paddedHeight)
            : nil

        return SkiaTextComposition(
            size: CGSize(width: finalWidth, height: finalHeight),
            backgroundRect: backgroundRect,
            backgroundCornerRadius: layout.cornerRadius,
            lines: shift(lines, dx: padX, dy: padY),
            icons: shift(icons, dx: padX, dy: padY),
            dividers: [],
            strokes: [],
            borderCornerRadius: layout.cornerRadius
        )
    }

    // MARK: - Canonical presets

    private static func composePill(
        element: OverlayElement,
        layout: OverlayTextRenderLayout,
        palette: SkiaTextPalette
    ) -> SkiaTextComposition {
        let valueFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.fontSize * 0.92,
            weight: .bold
        )
        let unitFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.unitFontSize,
            weight: .medium
        )
        let labelFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.labelFontSize,
            weight: .medium
        )
        let valueLine = SkiaTextComposer.makeLine(
            layout.components.value,
            font: valueFont,
            tracking: -layout.fontSize * 0.009
        )
        let unitLine = SkiaTextComposer.makeLine(
            layout.components.unit,
            font: unitFont,
            tracking: 0
        )
        let labelLine = SkiaTextComposer.makeLine(
            layout.components.label.uppercased(),
            font: labelFont,
            tracking: layout.labelFontSize * 0.10
        )
        let showLabel = showsLabel(element, layout)
        let showUnit = showsUnit(element, layout)
        let spacing = layout.fontSize * 0.32

        var lines: [SkiaTextPlacedLine] = []
        var dividers: [SkiaTextDivider] = []
        var x = 0.0
        var contentHeight = 0.0
        let clusterSpacing = layout.fontSize * 0.14
        let cluster = baselineRow(
            value: valueLine,
            unit: showUnit ? unitLine : nil,
            spacing: clusterSpacing
        )
        let clusterWidth = showUnit
            ? cluster.unitX + unitLine.width
            : valueLine.width

        if showLabel {
            let rowHeight = max(labelLine.height, cluster.height)
            let labelY = vOffset(
                labelLine.height,
                rowHeight,
                SkiaTextVerticalAlignment(layout.labelTextAlignment)
            )
            let clusterY = vOffset(
                cluster.height,
                rowHeight,
                SkiaTextVerticalAlignment(layout.labelTextAlignment)
            )
            lines.append(
                placed(
                    labelLine,
                    x: x,
                    y: labelY,
                    color: palette.label,
                    opacity: palette.labelOpacity
                )
            )
            x += labelLine.width + spacing
            if layout.dividerEnabled {
                let width = max(layout.dividerThickness, 0)
                let height = layout.fontSize * 0.78
                dividers.append(
                    SkiaTextDivider(
                        rect: CGRect(
                            x: x,
                            y: vOffset(
                                height,
                                rowHeight,
                                SkiaTextVerticalAlignment(layout.labelTextAlignment)
                            ),
                            width: width,
                            height: height
                        ),
                        color: dividerColor(layout),
                        cornerRadius: 0
                    )
                )
                x += width + spacing
            }
            lines.append(
                placed(
                    valueLine,
                    x: x,
                    y: clusterY + cluster.valueY,
                    color: palette.value,
                    opacity: palette.valueOpacity
                )
            )
            if showUnit {
                lines.append(
                    placed(
                        unitLine,
                        x: x + cluster.unitX,
                        y: clusterY + cluster.unitY,
                        color: palette.unit,
                        opacity: palette.unitOpacity
                    )
                )
            }
            contentHeight = rowHeight
            x += clusterWidth
        } else {
            lines.append(
                placed(
                    valueLine,
                    x: 0,
                    y: cluster.valueY,
                    color: palette.value,
                    opacity: palette.valueOpacity
                )
            )
            if showUnit {
                lines.append(
                    placed(
                        unitLine,
                        x: cluster.unitX,
                        y: cluster.unitY,
                        color: palette.unit,
                        opacity: palette.unitOpacity
                    )
                )
            }
            contentHeight = cluster.height
            x = clusterWidth
        }

        let coreSize = CGSize(width: x, height: contentHeight)
        var composition = padded(
            element: element,
            layout: layout,
            coreSize: coreSize,
            lines: lines,
            dividers: dividers
        )
        composition.backgroundCornerRadius = min(
            composition.backgroundRect?.width ?? 0,
            composition.backgroundRect?.height ?? 0
        ) / 2
        if element.style.backgroundEnabled {
            composition.strokes.append(
                SkiaTextStroke(
                    rect: composition.backgroundRect ?? .zero,
                    cornerRadius: composition.backgroundCornerRadius,
                    width: 1,
                    color: palette.foreground.withOpacity(0.16)
                )
            )
        }
        return composition
    }

    private static func composeMetricCard(
        element: OverlayElement,
        layout: OverlayTextRenderLayout,
        palette: SkiaTextPalette
    ) -> SkiaTextComposition {
        let valueFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.fontSize,
            overlayWeight: element.style.fontWeight
        )
        let unitFont = SkiaTextComposer.font(
            family: layout.unitFontName,
            size: layout.unitFontSize,
            overlayWeight: layout.unitFontWeight
        )
        let labelFont = SkiaTextComposer.font(
            family: layout.labelFontName,
            size: layout.labelFontSize,
            overlayWeight: layout.labelFontWeight
        )
        let valueLine = SkiaTextComposer.makeLine(
            layout.components.value,
            font: valueFont,
            tracking: 0
        )
        let unitLine = SkiaTextComposer.makeLine(
            layout.components.unit,
            font: unitFont,
            tracking: 0
        )
        let labelLine = SkiaTextComposer.makeLine(
            layout.components.label,
            font: labelFont,
            tracking: 0
        )
        let showLabel = showsLabel(element, layout)
        let showUnit = showsUnit(element, layout)
        let spacing = layout.verticalPadding * 0.7
        let cluster = baselineRow(
            value: valueLine,
            unit: showUnit ? unitLine : nil,
            spacing: layout.horizontalPadding * 0.35
        )
        var lines: [SkiaTextPlacedLine] = []
        var y = 0.0
        if showLabel {
            lines.append(
                placed(
                    labelLine,
                    x: 0,
                    y: 0,
                    color: palette.label,
                    opacity: palette.labelOpacity
                )
            )
            y += labelLine.height + spacing
        }
        lines.append(
            placed(
                valueLine,
                x: 0,
                y: y + cluster.valueY,
                color: palette.value,
                opacity: palette.valueOpacity
            )
        )
        if showUnit {
            lines.append(
                placed(
                    unitLine,
                    x: cluster.unitX,
                    y: y + cluster.unitY,
                    color: palette.unit,
                    opacity: palette.unitOpacity
                )
            )
        }
        let coreWidth = max(
            showLabel ? labelLine.width : 0,
            cluster.unitX + (showUnit ? unitLine.width : 0)
        )
        let coreHeight = y + cluster.height
        return padded(
            element: element,
            layout: layout,
            coreSize: CGSize(width: coreWidth, height: coreHeight),
            lines: lines
        )
    }

    private static func composeBigNumber(
        element: OverlayElement,
        layout: OverlayTextRenderLayout,
        palette: SkiaTextPalette
    ) -> SkiaTextComposition {
        let valueFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.fontSize * 1.95,
            weight: .bold
        )
        let unitFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.unitFontSize * 1.25,
            weight: .bold
        )
        let labelFont = SkiaTextComposer.font(
            family: layout.labelFontName,
            size: layout.labelFontSize,
            overlayWeight: layout.labelFontWeight
        )
        let valueLine = SkiaTextComposer.makeLine(
            layout.components.value,
            font: valueFont,
            tracking: 0
        )
        let unitLine = SkiaTextComposer.makeLine(
            layout.components.unit,
            font: unitFont,
            tracking: 0
        )
        let labelLine = SkiaTextComposer.makeLine(
            layout.components.label,
            font: labelFont,
            tracking: layout.labelFontSize * 0.10
        )
        let showLabel = showsLabel(element, layout)
        let showUnit = showsUnit(element, layout)

        var lines: [SkiaTextPlacedLine] = []
        let stackWidth = max(
            valueLine.width,
            showUnit ? unitLine.width : 0
        )
        let stackHeight = valueLine.height + (showUnit ? unitLine.height : 0)
        let labelWidth = showLabel ? labelLine.width : 0

        switch layout.labelPosition {
        case .top, .bottom:
            let width = max(stackWidth, labelWidth)
            var y = 0.0
            if showLabel && layout.labelPosition == .top {
                lines.append(
                    placed(
                        labelLine,
                        x: hOffset(labelWidth, width, layout.labelTextAlignment),
                        y: 0,
                        color: palette.label,
                        opacity: palette.labelOpacity
                    )
                )
                y += labelLine.height + layout.labelSpacing
            }
            lines.append(
                placed(
                    valueLine,
                    x: hOffset(valueLine.width, width, layout.valueTextAlignment),
                    y: y,
                    color: palette.value,
                    opacity: palette.valueOpacity
                )
            )
            if showUnit {
                lines.append(
                    placed(
                        unitLine,
                        x: hOffset(unitLine.width, width, layout.unitTextAlignment),
                        y: y + valueLine.height,
                        color: palette.unit,
                        opacity: palette.unitOpacity
                    )
                )
            }
            y += stackHeight
            if showLabel && layout.labelPosition == .bottom {
                y += layout.labelSpacing
                lines.append(
                    placed(
                        labelLine,
                        x: hOffset(labelWidth, width, layout.labelTextAlignment),
                        y: y,
                        color: palette.label,
                        opacity: palette.labelOpacity
                    )
                )
                y += labelLine.height
            }
            return unpadded(
                layout: layout,
                coreSize: CGSize(width: width, height: y),
                lines: lines
            )
        case .leading, .trailing:
            let showsSideLabel = showLabel
            let rowHeight = max(showsSideLabel ? labelLine.height : 0, stackHeight)
            let labelAlignment = SkiaTextVerticalAlignment(layout.labelTextAlignment)
            let stackY = vOffset(stackHeight, rowHeight, labelAlignment)
            let labelY = vOffset(labelLine.height, rowHeight, labelAlignment)
            let labelX: Double
            let stackX: Double
            if layout.labelPosition == .leading {
                labelX = 0
                stackX = showsSideLabel ? labelWidth + layout.labelSpacing : 0
            } else {
                stackX = 0
                labelX = stackWidth + layout.labelSpacing
            }
            if showsSideLabel {
                lines.append(
                    placed(
                        labelLine,
                        x: labelX,
                        y: labelY,
                        color: palette.label,
                        opacity: palette.labelOpacity
                    )
                )
            }
            lines.append(
                placed(
                    valueLine,
                    x: stackX + hOffset(
                        valueLine.width,
                        stackWidth,
                        layout.valueTextAlignment
                    ),
                    y: stackY,
                    color: palette.value,
                    opacity: palette.valueOpacity
                )
            )
            if showUnit {
                lines.append(
                    placed(
                        unitLine,
                        x: stackX + hOffset(
                            unitLine.width,
                            stackWidth,
                            layout.unitTextAlignment
                        ),
                        y: stackY + valueLine.height,
                        color: palette.unit,
                        opacity: palette.unitOpacity
                    )
                )
            }
            let width = stackWidth
                + (showsSideLabel ? labelWidth + layout.labelSpacing : 0)
            return unpadded(
                layout: layout,
                coreSize: CGSize(width: width, height: rowHeight),
                lines: lines
            )
        }
    }

    private static func composeSplitLabel(
        element: OverlayElement,
        layout: OverlayTextRenderLayout,
        palette: SkiaTextPalette
    ) -> SkiaTextComposition {
        let valueFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.fontSize,
            weight: .bold
        )
        let unitFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.unitFontSize,
            weight: .medium
        )
        let labelFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.labelFontSize,
            weight: .semibold
        )
        let valueLine = SkiaTextComposer.makeLine(
            layout.components.value,
            font: valueFont,
            tracking: -layout.fontSize * 0.012
        )
        let unitLine = SkiaTextComposer.makeLine(
            layout.components.unit,
            font: unitFont,
            tracking: 0
        )
        let labelLine = SkiaTextComposer.makeLine(
            layout.components.label.uppercased(),
            font: labelFont,
            tracking: layout.labelFontSize * 0.18
        )
        let showLabel = showsLabel(element, layout)
        let showUnit = showsUnit(element, layout)
        let labelColor = element.style.labelColor.withOpacity(
            element.style.labelOpacity
        )
        let spacing = layout.fontSize * 0.10
        let dividerWidth = layout.fontSize * 2.4
        let dividerHeight = max(layout.dividerThickness, 0)

        let width = max(
            showLabel ? labelLine.width : 0,
            layout.dividerEnabled ? dividerWidth : 0,
            valueLine.width,
            showUnit ? unitLine.width : 0
        )
        var lines: [SkiaTextPlacedLine] = []
        var dividers: [SkiaTextDivider] = []
        var y = 0.0
        if showLabel {
            lines.append(
                placed(
                    labelLine,
                    x: hOffset(labelLine.width, width, layout.labelTextAlignment),
                    y: y,
                    color: labelColor,
                    opacity: 1
                )
            )
            y += labelLine.height + spacing
        }
        if layout.dividerEnabled {
            dividers.append(
                SkiaTextDivider(
                    rect: CGRect(
                        x: hOffset(dividerWidth, width, layout.valueTextAlignment),
                        y: y,
                        width: dividerWidth,
                        height: dividerHeight
                    ),
                    color: dividerColor(layout),
                    cornerRadius: 0
                )
            )
            y += dividerHeight + spacing
        }
        lines.append(
            placed(
                valueLine,
                x: hOffset(valueLine.width, width, layout.valueTextAlignment),
                y: y,
                color: palette.value,
                opacity: palette.valueOpacity
            )
        )
        y += valueLine.height
        if showUnit {
            y += spacing
            lines.append(
                placed(
                    unitLine,
                    x: hOffset(unitLine.width, width, layout.unitTextAlignment),
                    y: y,
                    color: palette.unit,
                    opacity: palette.unitOpacity
                )
            )
            y += unitLine.height
        }
        return unpadded(
            layout: layout,
            coreSize: CGSize(width: width, height: y),
            lines: lines,
            dividers: dividers
        )
    }

    private static func composeNeonGlow(
        element: OverlayElement,
        layout: OverlayTextRenderLayout,
        palette: SkiaTextPalette
    ) -> SkiaTextComposition {
        let valueFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.fontSize,
            weight: .bold
        )
        let unitFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.unitFontSize,
            weight: .semibold
        )
        let valueLine = SkiaTextComposer.makeLine(
            layout.components.value,
            font: valueFont,
            tracking: -layout.fontSize * 0.010
        )
        let unitLine = SkiaTextComposer.makeLine(
            layout.components.unit,
            font: unitFont,
            tracking: 0
        )
        let showUnit = showsUnit(element, layout)
        let cluster = baselineRow(
            value: valueLine,
            unit: showUnit ? unitLine : nil,
            spacing: layout.fontSize * 0.14
        )
        let accent = palette.accent
        let valueShadows = [
            SkiaShadowEntry(
                sigma: layout.fontSize * 0.34,
                dx: 0,
                dy: 0,
                color: accent,
                alpha: 0.80
            ),
            SkiaShadowEntry(
                sigma: layout.fontSize * 0.62,
                dx: 0,
                dy: 0,
                color: accent,
                alpha: 0.36
            )
        ]
        let unitShadows = [
            SkiaShadowEntry(
                sigma: layout.fontSize * 0.24,
                dx: 0,
                dy: 0,
                color: accent,
                alpha: 0.65
            )
        ]
        var lines = [
            placed(
                valueLine,
                x: 0,
                y: cluster.valueY,
                color: palette.value,
                opacity: palette.valueOpacity,
                shadows: valueShadows
            )
        ]
        if showUnit {
            lines.append(
                placed(
                    unitLine,
                    x: cluster.unitX,
                    y: cluster.unitY,
                    color: palette.unit,
                    opacity: palette.unitOpacity,
                    shadows: unitShadows
                )
            )
        }
        let width = showUnit
            ? cluster.unitX + unitLine.width
            : valueLine.width
        return unpadded(
            layout: layout,
            coreSize: CGSize(width: width, height: cluster.height),
            lines: lines
        )
    }

    private static func composeRacingStripe(
        element: OverlayElement,
        layout: OverlayTextRenderLayout,
        palette: SkiaTextPalette
    ) -> SkiaTextComposition {
        let valueFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.fontSize,
            weight: .bold
        )
        let unitFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.unitFontSize,
            weight: .medium
        )
        let labelFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.labelFontSize,
            weight: .bold
        )
        let valueLine = SkiaTextComposer.makeLine(
            layout.components.value,
            font: valueFont,
            tracking: -layout.fontSize * 0.010
        )
        let unitLine = SkiaTextComposer.makeLine(
            layout.components.unit,
            font: unitFont,
            tracking: 0
        )
        let labelLine = SkiaTextComposer.makeLine(
            layout.components.label.uppercased(),
            font: labelFont,
            tracking: layout.labelFontSize * 0.10
        )
        let showLabel = showsLabel(element, layout)
        let showUnit = showsUnit(element, layout)
        let spacing = layout.fontSize * 0.10
        let stripeWidth = layout.dividerEnabled
            ? max(layout.dividerThickness * 2.4, 4)
            : 0
        let stripeGap = layout.fontSize * 0.34
        let width = max(
            showLabel ? labelLine.width : 0,
            valueLine.width,
            showUnit ? unitLine.width : 0
        )
        var lines: [SkiaTextPlacedLine] = []
        var y = 0.0
        if showLabel {
            lines.append(
                placed(
                    labelLine,
                    x: 0,
                    y: y,
                    color: palette.label,
                    opacity: palette.labelOpacity
                )
            )
            y += labelLine.height + spacing
        }
        lines.append(
            placed(
                valueLine,
                x: 0,
                y: y,
                color: palette.value,
                opacity: palette.valueOpacity
            )
        )
        y += valueLine.height
        if showUnit {
            y += spacing
            lines.append(
                placed(
                    unitLine,
                    x: 0,
                    y: y,
                    color: palette.unit,
                    opacity: palette.unitOpacity
                )
            )
            y += unitLine.height
        }
        let coreSize = CGSize(
            width: width + stripeWidth + (layout.dividerEnabled ? stripeGap : 0),
            height: y
        )
        var composition = padded(
            element: element,
            layout: layout,
            coreSize: coreSize,
            lines: shift(
                lines,
                dx: stripeWidth + (layout.dividerEnabled ? stripeGap : 0),
                dy: 0
            )
        )
        if layout.dividerEnabled {
            composition.dividers.append(
                SkiaTextDivider(
                    rect: CGRect(
                        x: layout.horizontalPadding,
                        y: layout.verticalPadding,
                        width: stripeWidth,
                        height: y
                    ),
                    color: dividerColor(layout),
                    cornerRadius: 2
                )
            )
        }
        if element.style.backgroundEnabled,
           let background = composition.backgroundRect {
            composition.strokes.append(
                SkiaTextStroke(
                    rect: background,
                    cornerRadius: layout.cornerRadius,
                    width: 1,
                    color: palette.foreground.withOpacity(0.14)
                )
            )
        }
        return composition
    }

    private static func composeEditorial(
        element: OverlayElement,
        layout: OverlayTextRenderLayout,
        palette: SkiaTextPalette
    ) -> SkiaTextComposition {
        let valueFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.fontSize,
            weight: .heavy
        )
        let unitFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.unitFontSize,
            weight: .medium
        )
        let labelFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.labelFontSize,
            weight: .bold
        )
        let valueLine = SkiaTextComposer.makeLine(
            layout.components.value,
            font: valueFont,
            tracking: -layout.fontSize * 0.018
        )
        let unitLine = SkiaTextComposer.makeLine(
            layout.components.unit,
            font: unitFont,
            tracking: 0
        )
        let labelLine = SkiaTextComposer.makeLine(
            layout.components.label.uppercased(),
            font: labelFont,
            tracking: layout.labelFontSize * 0.18
        )
        let showLabel = showsLabel(element, layout)
        let showUnit = showsUnit(element, layout)
        let spacing = layout.fontSize * 0.04
        let dividerWidth = layout.fontSize * 2.2
        let dividerHeight = max(layout.dividerThickness, 0)
        let width = max(
            showLabel ? labelLine.width : 0,
            valueLine.width,
            showUnit ? unitLine.width : 0,
            layout.dividerEnabled ? dividerWidth : 0
        )
        var lines: [SkiaTextPlacedLine] = []
        var dividers: [SkiaTextDivider] = []
        var y = 0.0
        if showLabel {
            lines.append(
                placed(
                    labelLine,
                    x: 0,
                    y: y,
                    color: palette.label,
                    opacity: palette.labelOpacity
                )
            )
            y += labelLine.height + spacing
        }
        lines.append(
            placed(
                valueLine,
                x: 0,
                y: y,
                color: palette.value,
                opacity: palette.valueOpacity
            )
        )
        y += valueLine.height
        if showUnit {
            y += spacing
            lines.append(
                placed(
                    unitLine,
                    x: 0,
                    y: y,
                    color: palette.unit,
                    opacity: palette.unitOpacity
                )
            )
            y += unitLine.height
        }
        if layout.dividerEnabled {
            y += spacing + layout.fontSize * 0.04
            dividers.append(
                SkiaTextDivider(
                    rect: CGRect(
                        x: hOffset(dividerWidth, width, layout.valueTextAlignment),
                        y: y,
                        width: dividerWidth,
                        height: dividerHeight
                    ),
                    color: dividerColor(layout),
                    cornerRadius: 0
                )
            )
            y += dividerHeight
        }
        return unpadded(
            layout: layout,
            coreSize: CGSize(width: width, height: y),
            lines: lines,
            dividers: dividers
        )
    }

    private static func composeDigitalWatch(
        element: OverlayElement,
        layout: OverlayTextRenderLayout,
        palette: SkiaTextPalette
    ) -> SkiaTextComposition {
        // `.custom(PresetFontName.digitalWatch, ...)` resolves the PostScript
        // face directly; the family resolver would snap it back to Menlo
        // Regular and lose the bold weight.
        let digitalName = PresetFontName.digitalWatch
        let valueFont = NSFont(name: digitalName, size: layout.fontSize)
            ?? SkiaTextComposer.font(
                family: digitalName,
                size: layout.fontSize,
                weight: .regular
            )
        let unitFont = NSFont(name: digitalName, size: layout.unitFontSize)
            ?? SkiaTextComposer.font(
                family: digitalName,
                size: layout.unitFontSize,
                weight: .regular
            )
        let labelFont = NSFont(name: digitalName, size: layout.labelFontSize)
            ?? SkiaTextComposer.font(
                family: digitalName,
                size: layout.labelFontSize,
                weight: .regular
            )
        let valueLine = SkiaTextComposer.makeLine(
            layout.components.value,
            font: valueFont,
            tracking: layout.fontSize * 0.020
        )
        let unitLine = SkiaTextComposer.makeLine(
            layout.components.unit,
            font: unitFont,
            tracking: 0
        )
        let labelLine = SkiaTextComposer.makeLine(
            layout.components.label.uppercased(),
            font: labelFont,
            tracking: layout.labelFontSize * 0.18
        )
        let showLabel = showsLabel(element, layout)
        let showUnit = showsUnit(element, layout)
        let spacing = layout.fontSize * 0.10
        let accent = palette.accent
        let valueShadows = [
            SkiaShadowEntry(
                sigma: layout.fontSize * 0.18,
                dx: 0,
                dy: 0,
                color: accent,
                alpha: 0.85
            ),
            SkiaShadowEntry(
                sigma: layout.fontSize * 0.42,
                dx: 0,
                dy: 0,
                color: accent,
                alpha: 0.45
            )
        ]
        let unitShadows = [
            SkiaShadowEntry(
                sigma: layout.fontSize * 0.14,
                dx: 0,
                dy: 0,
                color: accent,
                alpha: 0.55
            )
        ]
        let cluster = baselineRow(
            value: valueLine,
            unit: showUnit ? unitLine : nil,
            spacing: layout.fontSize * 0.14
        )
        var lines: [SkiaTextPlacedLine] = []
        var y = 0.0
        if showLabel {
            lines.append(
                placed(
                    labelLine,
                    x: 0,
                    y: 0,
                    color: palette.label,
                    opacity: palette.labelOpacity
                )
            )
            y += labelLine.height + spacing
        }
        lines.append(
            placed(
                valueLine,
                x: 0,
                y: y + cluster.valueY,
                color: palette.value,
                opacity: palette.valueOpacity,
                shadows: valueShadows
            )
        )
        if showUnit {
            lines.append(
                placed(
                    unitLine,
                    x: cluster.unitX,
                    y: y + cluster.unitY,
                    color: palette.unit,
                    opacity: palette.unitOpacity,
                    shadows: unitShadows
                )
            )
        }
        let coreWidth = max(
            showLabel ? labelLine.width : 0,
            cluster.unitX + (showUnit ? unitLine.width : 0)
        )
        let coreHeight = y + cluster.height
        var composition = padded(
            element: element,
            layout: layout,
            coreSize: CGSize(width: coreWidth, height: coreHeight),
            lines: lines
        )
        if let background = composition.backgroundRect {
            composition.strokes.append(
                SkiaTextStroke(
                    rect: background,
                    cornerRadius: layout.cornerRadius,
                    width: 1,
                    color: accent.withOpacity(0.70)
                )
            )
        }
        return composition
    }

    // MARK: - Deprecated presets

    private static func composeSportWatch(
        element: OverlayElement,
        layout: OverlayTextRenderLayout,
        palette: SkiaTextPalette
    ) -> SkiaTextComposition {
        let valueFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.fontSize,
            overlayWeight: element.style.fontWeight
        )
        let unitFont = SkiaTextComposer.font(
            family: layout.labelFontName,
            size: layout.labelFontSize,
            weight: .bold
        )
        let labelFont = SkiaTextComposer.font(
            family: layout.labelFontName,
            size: layout.labelFontSize,
            weight: .bold
        )
        let valueLine = SkiaTextComposer.makeLine(
            layout.components.value,
            font: valueFont,
            tracking: 0
        )
        let unitLine = SkiaTextComposer.makeLine(
            layout.components.unit,
            font: unitFont,
            tracking: 0
        )
        let labelLine = SkiaTextComposer.makeLine(
            layout.components.shortLabel,
            font: labelFont,
            tracking: 0
        )
        let showLabel = showsLabel(element, layout)
        let showUnit = showsUnit(element, layout)
        let spacing = layout.verticalPadding * 0.65
        let dividerWidth = layout.fontSize * 2.7
        let dividerHeight = max(layout.dividerThickness, 1)
        let width = max(
            layout.fontSize * 3.2,
            showLabel ? labelLine.width : 0,
            valueLine.width,
            showUnit ? unitLine.width : 0,
            dividerWidth
        )
        // `divider` is always present in the SwiftUI hierarchy; when disabled
        // it renders clear but still reserves its row.
        let dividerTint = layout.dividerEnabled
            ? dividerColor(layout)
            : OverlayColor(red: 0, green: 0, blue: 0, alpha: 0)
        var lines: [SkiaTextPlacedLine] = []
        var dividers: [SkiaTextDivider] = []
        var y = 0.0
        if showLabel {
            lines.append(
                placed(
                    labelLine,
                    x: hOffset(labelLine.width, width, SkiaTextHorizontalAlignment.center),
                    y: 0,
                    color: palette.label,
                    opacity: palette.labelOpacity
                )
            )
            y += labelLine.height + spacing
        }
        dividers.append(
            SkiaTextDivider(
                rect: CGRect(
                    x: hOffset(dividerWidth, width, SkiaTextHorizontalAlignment.center),
                    y: y,
                    width: dividerWidth,
                    height: dividerHeight
                ),
                color: dividerTint,
                cornerRadius: 0
            )
        )
        y += dividerHeight + spacing
        lines.append(
            placed(
                valueLine,
                x: hOffset(valueLine.width, width, SkiaTextHorizontalAlignment.center),
                y: y,
                color: palette.value,
                opacity: palette.valueOpacity
            )
        )
        y += valueLine.height + spacing
        dividers.append(
            SkiaTextDivider(
                rect: CGRect(
                    x: hOffset(dividerWidth, width, SkiaTextHorizontalAlignment.center),
                    y: y,
                    width: dividerWidth,
                    height: dividerHeight
                ),
                color: dividerTint,
                cornerRadius: 0
            )
        )
        y += dividerHeight
        if showUnit {
            y += spacing
            lines.append(
                placed(
                    unitLine,
                    x: hOffset(unitLine.width, width, SkiaTextHorizontalAlignment.center),
                    y: y,
                    color: palette.unit,
                    opacity: palette.unitOpacity
                )
            )
            y += unitLine.height
        }
        var composition = padded(
            element: element,
            layout: layout,
            coreSize: CGSize(width: width, height: y),
            lines: lines,
            dividers: dividers
        )
        if let background = composition.backgroundRect {
            composition.strokes.append(
                SkiaTextStroke(
                    rect: background,
                    cornerRadius: layout.cornerRadius,
                    width: max(layout.fontSize / 28, 1),
                    color: palette.foreground.withOpacity(0.35)
                )
            )
        }
        return composition
    }

    private static func composeInlineGhost(
        element: OverlayElement,
        layout: OverlayTextRenderLayout,
        palette: SkiaTextPalette
    ) -> SkiaTextComposition {
        let valueFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.fontSize,
            weight: .light
        )
        let unitFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.unitFontSize,
            weight: .regular
        )
        let labelFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.labelFontSize,
            weight: .regular
        )
        let valueLine = SkiaTextComposer.makeLine(
            layout.components.value,
            font: valueFont,
            tracking: -layout.fontSize * 0.02
        )
        let unitLine = SkiaTextComposer.makeLine(
            layout.components.unit,
            font: unitFont,
            tracking: 0
        )
        let labelLine = SkiaTextComposer.makeLine(
            layout.components.label.uppercased(),
            font: labelFont,
            tracking: layout.labelFontSize * 0.12
        )
        let showLabel = showsLabel(element, layout)
        let showUnit = showsUnit(element, layout)
        let spacing = layout.fontSize * 0.06
        let cluster = baselineRow(
            value: valueLine,
            unit: showUnit ? unitLine : nil,
            spacing: layout.fontSize * 0.18
        )
        let labelColor = palette.heartRateZoneActive
            ? palette.label
            : palette.foreground.withOpacity(0.28)
        let valueColor = palette.heartRateZoneActive
            ? palette.value
            : palette.value.withOpacity(0.88)
        let unitColor = palette.heartRateZoneActive
            ? palette.unit
            : palette.foreground.withOpacity(0.30)
        var lines: [SkiaTextPlacedLine] = []
        var y = 0.0
        if showLabel {
            lines.append(
                placed(
                    labelLine,
                    x: 0,
                    y: 0,
                    color: labelColor,
                    opacity: 1
                )
            )
            y += labelLine.height + spacing
        }
        lines.append(
            placed(
                valueLine,
                x: 0,
                y: y + cluster.valueY,
                color: valueColor,
                opacity: palette.valueOpacity
            )
        )
        if showUnit {
            lines.append(
                placed(
                    unitLine,
                    x: cluster.unitX,
                    y: y + cluster.unitY,
                    color: unitColor,
                    opacity: palette.unitOpacity
                )
            )
        }
        let width = max(
            showLabel ? labelLine.width : 0,
            cluster.unitX + (showUnit ? unitLine.width : 0)
        )
        return unpadded(
            layout: layout,
            coreSize: CGSize(width: width, height: y + cluster.height),
            lines: lines
        )
    }

    private static func composeAccentBar(
        element: OverlayElement,
        layout: OverlayTextRenderLayout,
        palette: SkiaTextPalette
    ) -> SkiaTextComposition {
        let valueFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.fontSize,
            weight: .bold
        )
        let unitFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.unitFontSize,
            weight: .regular
        )
        let labelFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.labelFontSize,
            weight: .regular
        )
        let valueLine = SkiaTextComposer.makeLine(
            layout.components.value,
            font: valueFont,
            tracking: -layout.fontSize * 0.05
        )
        let unitLine = SkiaTextComposer.makeLine(
            layout.components.unit,
            font: unitFont,
            tracking: 0
        )
        let labelLine = SkiaTextComposer.makeLine(
            layout.components.label.uppercased(),
            font: labelFont,
            tracking: layout.labelFontSize * 0.12
        )
        let showLabel = showsLabel(element, layout)
        let showUnit = showsUnit(element, layout)
        let barWidth = max(layout.fontSize * 0.083, 1.5)
        let barHeight = layout.fontSize * 1.55
        let barRadius = max(layout.fontSize * 0.06, 1)
        let spacing = layout.fontSize * 0.33
        let textSpacing = layout.fontSize * 0.06
        let textWidth = max(
            showLabel ? labelLine.width : 0,
            valueLine.width,
            showUnit ? unitLine.width : 0
        )
        let textHeight = (showLabel ? labelLine.height + textSpacing : 0)
            + valueLine.height
            + (showUnit ? textSpacing + unitLine.height : 0)
        let rowHeight = max(barHeight, textHeight)
        let labelColor = palette.heartRateZoneActive
            ? palette.label
            : palette.foreground.withOpacity(0.32)
        let unitColor = palette.heartRateZoneActive
            ? palette.unit
            : palette.foreground.withOpacity(0.38)
        var lines: [SkiaTextPlacedLine] = []
        var y = vOffset(textHeight, rowHeight, .middle)
        let textX = barWidth + spacing
        if showLabel {
            lines.append(
                placed(
                    labelLine,
                    x: textX,
                    y: y,
                    color: labelColor,
                    opacity: 1
                )
            )
            y += labelLine.height + textSpacing
        }
        lines.append(
            placed(
                valueLine,
                x: textX,
                y: y,
                color: palette.value,
                opacity: palette.valueOpacity
            )
        )
        y += valueLine.height
        if showUnit {
            y += textSpacing
            lines.append(
                placed(
                    unitLine,
                    x: textX,
                    y: y,
                    color: unitColor,
                    opacity: palette.unitOpacity
                )
            )
        }
        var composition = unpadded(
            layout: layout,
            coreSize: CGSize(width: barWidth + spacing + textWidth, height: rowHeight),
            lines: lines
        )
        composition.dividers.append(
            SkiaTextDivider(
                rect: CGRect(
                    x: 0,
                    y: vOffset(barHeight, rowHeight, .middle),
                    width: barWidth,
                    height: barHeight
                ),
                color: palette.accent,
                cornerRadius: barRadius
            )
        )
        return composition
    }

    private static func composeSportNeon(
        element: OverlayElement,
        layout: OverlayTextRenderLayout,
        palette: SkiaTextPalette
    ) -> SkiaTextComposition {
        let valueFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.fontSize,
            weight: .heavy
        )
        let unitFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.unitFontSize,
            weight: .regular
        )
        let labelFont = SkiaTextComposer.font(
            family: element.style.fontName,
            size: layout.labelFontSize,
            weight: .bold
        )
        let valueLine = SkiaTextComposer.makeLine(
            layout.components.value,
            font: valueFont,
            tracking: -layout.fontSize * 0.06
        )
        let unitLine = SkiaTextComposer.makeLine(
            layout.components.unit,
            font: unitFont,
            tracking: 0
        )
        let labelLine = SkiaTextComposer.makeLine(
            layout.components.label.uppercased(),
            font: labelFont,
            tracking: layout.labelFontSize * 0.16
        )
        let showLabel = showsLabel(element, layout)
        let showUnit = showsUnit(element, layout)
        let spacing = layout.fontSize * 0.05
        let ruleWidth = layout.fontSize * 0.6
        let dotDiameter = max(layout.fontSize * 0.14, 4)
        let unitRowSpacing = layout.fontSize * 0.18
        let labelColor = palette.heartRateZoneActive
            ? palette.label
            : palette.accent
        let unitColor = palette.heartRateZoneActive
            ? palette.unit
            : palette.foreground.withOpacity(0.35)
        let unitRowWidth = ruleWidth + unitRowSpacing + dotDiameter
            + unitRowSpacing + (showUnit ? unitLine.width : 0)
        let unitRowHeight = max(unitLine.height, dotDiameter)
        var lines: [SkiaTextPlacedLine] = []
        var dividers: [SkiaTextDivider] = []
        var y = 0.0
        if showLabel {
            lines.append(
                placed(
                    labelLine,
                    x: 0,
                    y: 0,
                    color: labelColor,
                    opacity: 1
                )
            )
            y += labelLine.height + spacing
        }
        lines.append(
            placed(
                valueLine,
                x: 0,
                y: y,
                color: palette.value,
                opacity: palette.valueOpacity
            )
        )
        y += valueLine.height
        if showUnit {
            y += spacing
            let rowY = y
            dividers.append(
                SkiaTextDivider(
                    rect: CGRect(
                        x: 0,
                        y: rowY + vOffset(0.5, unitRowHeight, .middle),
                        width: ruleWidth,
                        height: 0.5
                    ),
                    color: palette.foreground.withOpacity(0.10),
                    cornerRadius: 0
                )
            )
            dividers.append(
                SkiaTextDivider(
                    rect: CGRect(
                        x: ruleWidth + unitRowSpacing,
                        y: rowY + vOffset(dotDiameter, unitRowHeight, .middle),
                        width: dotDiameter,
                        height: dotDiameter
                    ),
                    color: palette.accent,
                    cornerRadius: dotDiameter / 2
                )
            )
            lines.append(
                placed(
                    unitLine,
                    x: ruleWidth + unitRowSpacing + dotDiameter + unitRowSpacing,
                    y: rowY + vOffset(unitLine.height, unitRowHeight, .middle),
                    color: unitColor,
                    opacity: palette.unitOpacity
                )
            )
            y += unitRowHeight
        }
        let width = max(
            showLabel ? labelLine.width : 0,
            valueLine.width,
            showUnit ? unitRowWidth : 0
        )
        return unpadded(
            layout: layout,
            coreSize: CGSize(width: width, height: y),
            lines: lines,
            dividers: dividers
        )
    }

    private static func composeSerifEditorial(
        element: OverlayElement,
        layout: OverlayTextRenderLayout,
        palette: SkiaTextPalette
    ) -> SkiaTextComposition {
        // `.custom("Georgia", ...)` resolves the PostScript face directly.
        let valueFont = NSFont(name: "Georgia", size: layout.fontSize)
            ?? SkiaTextComposer.font(
                family: "Georgia",
                size: layout.fontSize,
                weight: .regular
            )
        let unitFont = NSFont.systemFont(ofSize: layout.unitFontSize)
        let labelFont = NSFont.systemFont(ofSize: layout.labelFontSize)
        let valueLine = SkiaTextComposer.makeLine(
            layout.components.value,
            font: valueFont,
            tracking: -layout.fontSize * 0.01
        )
        let unitLine = SkiaTextComposer.makeLine(
            layout.components.unit,
            font: unitFont,
            tracking: layout.unitFontSize * 0.1
        )
        let labelLine = SkiaTextComposer.makeLine(
            layout.components.label.uppercased(),
            font: labelFont,
            tracking: layout.labelFontSize * 0.2
        )
        let showLabel = showsLabel(element, layout)
        let showUnit = showsUnit(element, layout)
        let spacing = layout.fontSize * 0.05
        let ruleWidth = layout.fontSize * 0.78
        let rulePadding = layout.fontSize * 0.18
        let labelColor = palette.heartRateZoneActive
            ? palette.label
            : palette.foreground.withOpacity(0.30)
        let unitColor = palette.heartRateZoneActive
            ? palette.unit
            : palette.foreground.withOpacity(0.28)
        let width = max(
            showLabel ? labelLine.width : 0,
            valueLine.width,
            showUnit ? max(ruleWidth, unitLine.width) : 0
        )
        var lines: [SkiaTextPlacedLine] = []
        var dividers: [SkiaTextDivider] = []
        var y = 0.0
        if showLabel {
            lines.append(
                placed(
                    labelLine,
                    x: hOffset(labelLine.width, width, SkiaTextHorizontalAlignment.center),
                    y: 0,
                    color: labelColor,
                    opacity: 1
                )
            )
            y += labelLine.height + spacing
        }
        lines.append(
            placed(
                valueLine,
                x: hOffset(valueLine.width, width, SkiaTextHorizontalAlignment.center),
                y: y,
                color: palette.value,
                opacity: palette.valueOpacity
            )
        )
        y += valueLine.height
        if showUnit {
            y += spacing
            dividers.append(
                SkiaTextDivider(
                    rect: CGRect(
                        x: hOffset(ruleWidth, width, SkiaTextHorizontalAlignment.center),
                        y: y + rulePadding,
                        width: ruleWidth,
                        height: 0.5
                    ),
                    color: palette.foreground.withOpacity(0.20),
                    cornerRadius: 0
                )
            )
            y += rulePadding * 2 + 0.5 + spacing
            lines.append(
                placed(
                    unitLine,
                    x: hOffset(unitLine.width, width, SkiaTextHorizontalAlignment.center),
                    y: y,
                    color: unitColor,
                    opacity: palette.unitOpacity
                )
            )
            y += unitLine.height
        }
        return unpadded(
            layout: layout,
            coreSize: CGSize(width: width, height: y),
            lines: lines,
            dividers: dividers
        )
    }

    // MARK: - Helpers

    private struct BaselineRow {
        var valueY: Double
        var unitX: Double
        var unitY: Double
        var height: Double
    }

    private static func baselineRow(
        value: SkiaTextLine,
        unit: SkiaTextLine?,
        spacing: Double
    ) -> BaselineRow {
        guard let unit else {
            return BaselineRow(
                valueY: 0,
                unitX: 0,
                unitY: 0,
                height: value.height
            )
        }
        let baseline = max(value.ascent, unit.ascent)
        let descent = max(value.descent, unit.descent)
        let leading = max(value.leading, unit.leading)
        return BaselineRow(
            valueY: baseline - value.ascent,
            unitX: value.width + spacing,
            unitY: baseline - unit.ascent,
            height: baseline + descent + leading
        )
    }

    private static func showsLabel(
        _ element: OverlayElement,
        _ layout: OverlayTextRenderLayout
    ) -> Bool {
        element.style.showLabel && !layout.components.label.isEmpty
    }

    private static func showsUnit(
        _ element: OverlayElement,
        _ layout: OverlayTextRenderLayout
    ) -> Bool {
        element.style.showUnit && !layout.components.unit.isEmpty
    }

    private static func placed(
        _ line: SkiaTextLine,
        x: Double,
        y: Double,
        color: OverlayColor,
        opacity: Double,
        shadows: [SkiaShadowEntry] = []
    ) -> SkiaTextPlacedLine {
        SkiaTextPlacedLine(
            line: line,
            origin: CGPoint(x: x, y: y),
            color: color,
            opacity: opacity,
            shadows: shadows
        )
    }

    private static func hOffset(
        _ child: Double,
        _ parent: Double,
        _ alignment: OverlayTextAlignment
    ) -> Double {
        SkiaTextComposer.horizontalOffset(
            child: child,
            parent: parent,
            alignment: SkiaTextHorizontalAlignment(alignment)
        )
    }

    private static func hOffset(
        _ child: Double,
        _ parent: Double,
        _ alignment: SkiaTextHorizontalAlignment
    ) -> Double {
        SkiaTextComposer.horizontalOffset(
            child: child,
            parent: parent,
            alignment: alignment
        )
    }

    private static func vOffset(
        _ child: Double,
        _ parent: Double,
        _ alignment: SkiaTextVerticalAlignment
    ) -> Double {
        SkiaTextComposer.verticalOffset(
            child: child,
            parent: parent,
            alignment: alignment
        )
    }

    private static func dividerColor(
        _ layout: OverlayTextRenderLayout
    ) -> OverlayColor {
        layout.dividerColor.withOpacity(layout.dividerOpacity)
    }

    private static func padded(
        element: OverlayElement,
        layout: OverlayTextRenderLayout,
        coreSize: CGSize,
        lines: [SkiaTextPlacedLine],
        dividers: [SkiaTextDivider] = []
    ) -> SkiaTextComposition {
        let padX = layout.horizontalPadding
        let padY = layout.verticalPadding
        let paddedWidth = coreSize.width + padX * 2
        let paddedHeight = coreSize.height + padY * 2
        let finalWidth = max(paddedWidth, layout.minimumWidth)
        let finalHeight = max(paddedHeight, layout.minimumHeight)
        // Presets that pad unconditionally still need the padded rect for
        // always-on overlays (e.g. digitalWatch's accent stroke). The renderer
        // only fills it when `backgroundEnabled` is set.
        let background = CGRect(
            x: 0,
            y: 0,
            width: paddedWidth,
            height: paddedHeight
        )
        return SkiaTextComposition(
            size: CGSize(width: finalWidth, height: finalHeight),
            backgroundRect: background,
            backgroundCornerRadius: layout.cornerRadius,
            lines: shift(lines, dx: padX, dy: padY),
            icons: [],
            dividers: shift(dividers, dx: padX, dy: padY),
            strokes: [],
            borderCornerRadius: layout.cornerRadius
        )
    }

    private static func unpadded(
        layout: OverlayTextRenderLayout,
        coreSize: CGSize,
        lines: [SkiaTextPlacedLine],
        dividers: [SkiaTextDivider] = []
    ) -> SkiaTextComposition {
        SkiaTextComposition(
            size: CGSize(
                width: max(coreSize.width, layout.minimumWidth),
                height: max(coreSize.height, layout.minimumHeight)
            ),
            backgroundRect: nil,
            backgroundCornerRadius: layout.cornerRadius,
            lines: lines,
            icons: [],
            dividers: dividers,
            strokes: [],
            borderCornerRadius: layout.cornerRadius
        )
    }

    private static func shift(
        _ lines: [SkiaTextPlacedLine],
        dx: Double,
        dy: Double
    ) -> [SkiaTextPlacedLine] {
        lines.map { line in
            var line = line
            line.origin.x += dx
            line.origin.y += dy
            return line
        }
    }

    private static func shift(
        _ icons: [SkiaTextPlacedIcon],
        dx: Double,
        dy: Double
    ) -> [SkiaTextPlacedIcon] {
        icons.map { icon in
            var icon = icon
            icon.rect.origin.x += dx
            icon.rect.origin.y += dy
            return icon
        }
    }

    private static func shift(
        _ dividers: [SkiaTextDivider],
        dx: Double,
        dy: Double
    ) -> [SkiaTextDivider] {
        dividers.map { divider in
            var divider = divider
            divider.rect.origin.x += dx
            divider.rect.origin.y += dy
            return divider
        }
    }
}
#endif
