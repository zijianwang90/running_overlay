#if canImport(CSkiaBridge)
import AppKit
import CSkiaBridge
import CoreGraphics
import Foundation

/// Skia port of `IntervalWorkSummaryOverlayView`.
///
/// Continuous rounded corners are approximated with circular corners; the
/// frozen bridge has no squircle path primitive yet.
enum IntervalWorkSummarySkiaRenderer {
    static func draw(
        _ element: OverlayElement,
        layout: IntervalWorkSummaryRenderLayout,
        context: OpaquePointer,
        maskCache: SkiaIntervalDraw.MaskCache
    ) {
        guard layout.isVisible else { return }
        let style = element.style
        let rect = layout.rect
        let shadowSigma = SkiaIntervalDraw.shadowSigma(layout.shadowRadius)
        let glowRadius = style.glowEnabled
            ? 18 + style.glowIntensity * 28
            : 0
        let bleed = max(shadowSigma * 3, glowRadius * 3)
            + max(layout.backgroundRadius, 0)
            + 24
        let drawBounds = rect.insetBy(dx: -bleed, dy: -bleed)

        SkiaIntervalDraw.withElementOpacity(context, element: element, bounds: drawBounds) {
            if style.backgroundEnabled {
                SkiaIntervalDraw.withShadowChain(
                    context,
                    shadows: shadows(element, layout: layout, isEnabled: true),
                    bounds: drawBounds
                ) {
                    SkiaIntervalDraw.fillRoundRect(
                        context,
                        rect,
                        radius: layout.backgroundRadius,
                        color: style.backgroundColor,
                        opacity: style.backgroundOpacity
                    )
                }
                if style.borderEnabled {
                    SkiaIntervalDraw.strokeRoundRect(
                        context,
                        rect,
                        radius: layout.backgroundRadius,
                        lineWidth: layout.borderWidth,
                        color: style.borderColor,
                        opacity: style.borderOpacity
                    )
                }
            }

            SkiaIntervalDraw.withShadowChain(
                context,
                shadows: shadows(
                    element,
                    layout: layout,
                    isEnabled: !style.backgroundEnabled
                ),
                bounds: drawBounds
            ) {
                SkiaIntervalDraw.withShadowChain(
                    context,
                    shadows: glowShadows(element),
                    bounds: drawBounds
                ) {
                    drawContent(element, layout: layout, context: context)
                }
            }
        }
    }

    // MARK: - Content

    private static func drawContent(
        _ element: OverlayElement,
        layout: IntervalWorkSummaryRenderLayout,
        context: OpaquePointer
    ) {
        let contentRect = layout.rect.insetBy(
            dx: layout.backgroundPaddingX,
            dy: layout.backgroundPaddingY
        )
        guard contentRect.width > 0, contentRect.height > 0 else { return }

        let hasSecondary = !layout.secondaryItems.isEmpty

        var componentLine: (font: NSFont, line: SkiaIntervalText.Line, color: OverlayColor)?
        if let label = componentLabel(layout) {
            let fitted = SkiaIntervalText.fitted(
                label.text,
                font: label.font,
                maxWidth: contentRect.width,
                minimumScaleFactor: 1
            )
            componentLine = (fitted.font, fitted.line, label.color)
        }
        let componentHeight = componentLine.map { $0.line.height + 8 } ?? 0

        let primaryHeight = primaryGroupHeight(layout: layout, width: contentRect.width)
        let secondaryHeight = secondaryGroupHeight(layout: layout, width: contentRect.width)

        let fixedHeight = componentHeight
            + primaryHeight
            + (hasSecondary ? secondaryHeight : 0)
        let available = max(contentRect.height - fixedHeight, 0)
        var spacer1 = 0.0
        var spacer2 = 0.0
        var spacer3 = 0.0
        if hasSecondary {
            let share = available / 3
            if share >= 12 {
                spacer1 = share
                spacer2 = share
                spacer3 = share
            } else {
                spacer2 = 12
                spacer1 = max((available - 12) / 2, 0)
                spacer3 = spacer1
            }
        } else {
            spacer1 = available / 2
            spacer2 = available / 2
        }

        var y = contentRect.minY
        if let componentLine {
            drawComponentLabel(
                componentLine,
                alignment: layout.style.resolvedComponentLabelAlignment,
                rect: CGRect(
                    x: contentRect.minX,
                    y: y,
                    width: contentRect.width,
                    height: componentLine.line.height
                ),
                context: context
            )
            y += componentHeight
        }

        y += spacer1
        drawPrimaryGroup(
            layout: layout,
            rect: CGRect(
                x: contentRect.minX,
                y: y,
                width: contentRect.width,
                height: primaryHeight
            ),
            context: context
        )
        y += primaryHeight

        if hasSecondary {
            y += spacer2
            drawSecondaryGroup(
                layout: layout,
                rect: CGRect(
                    x: contentRect.minX,
                    y: y,
                    width: contentRect.width,
                    height: secondaryHeight
                ),
                context: context
            )
        }
    }

    private static func componentLabel(
        _ layout: IntervalWorkSummaryRenderLayout
    ) -> (text: String, font: NSFont, color: OverlayColor)? {
        guard let item = layout.textItems[.componentLabel],
              item.style.isVisible,
              !layout.componentLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return (
            layout.componentLabel.uppercased(),
            font(item, scale: 1),
            item.color
        )
    }

    private static func drawComponentLabel(
        _ line: (font: NSFont, line: SkiaIntervalText.Line, color: OverlayColor),
        alignment: OverlayTextAlignment,
        rect: CGRect,
        context: OpaquePointer
    ) {
        let x: Double
        switch alignment {
        case .leading: x = rect.minX
        case .center: x = rect.midX - line.line.width / 2
        case .trailing: x = rect.maxX - line.line.width
        }
        SkiaIntervalText.draw(
            line.line,
            font: line.font,
            x: x,
            baselineY: rect.midY - line.line.height / 2 + line.line.ascent,
            color: line.color,
            opacity: 1,
            context: context
        )
    }

    // MARK: - Primary

    private static func primaryGroupHeight(
        layout: IntervalWorkSummaryRenderLayout,
        width: Double
    ) -> Double {
        guard let valueStyle = layout.textItems[.primaryValue] else { return 0 }
        var height = SkiaIntervalText.rowHeight(
            primaryValueRow(layout: layout, valueStyle: valueStyle),
            maxWidth: width
        )
        if primaryLabelVisible(layout) {
            height += 5 + SkiaIntervalText.rowHeight(
                primaryLabelRow(layout: layout),
                maxWidth: width
            )
        }
        return height
    }

    private static func drawPrimaryGroup(
        layout: IntervalWorkSummaryRenderLayout,
        rect: CGRect,
        context: OpaquePointer
    ) {
        guard let valueStyle = layout.textItems[.primaryValue] else { return }
        var y = rect.minY
        let row = primaryValueRow(layout: layout, valueStyle: valueStyle)
        let height = SkiaIntervalText.rowHeight(row, maxWidth: rect.width)
        drawRow(
            row,
            rect: CGRect(x: rect.minX, y: y, width: rect.width, height: height),
            context: context
        )
        y += height
        if primaryLabelVisible(layout) {
            y += 5
            let label = primaryLabelRow(layout: layout)
            let labelHeight = SkiaIntervalText.rowHeight(label, maxWidth: rect.width)
            drawRow(
                label,
                rect: CGRect(x: rect.minX, y: y, width: rect.width, height: labelHeight),
                context: context
            )
        }
    }

    private static func primaryValueRow(
        layout: IntervalWorkSummaryRenderLayout,
        valueStyle: IntervalWorkSummaryRenderLayout.TextItem
    ) -> SkiaIntervalText.Row {
        var items: [SkiaIntervalText.RowItem] = [
            .init(
                text: layout.primary.value,
                font: font(valueStyle, scale: 1, monospacedDigits: true),
                color: valueStyle.color,
                minimumScaleFactor: 0.55
            )
        ]
        if !layout.primary.unit.isEmpty {
            items.append(.init(
                text: layout.primary.unit,
                font: font(valueStyle, scale: 0.34),
                color: valueStyle.color,
                opacity: 0.9,
                minimumScaleFactor: 1
            ))
        }
        return .init(items: items, spacing: 7, alignment: .firstTextBaseline)
    }

    private static func primaryLabelVisible(
        _ layout: IntervalWorkSummaryRenderLayout
    ) -> Bool {
        guard let item = layout.textItems[.primaryLabel],
              item.style.isVisible,
              layout.primary.labelVisible
        else { return false }
        return true
    }

    private static func primaryLabelRow(
        layout: IntervalWorkSummaryRenderLayout
    ) -> SkiaIntervalText.Row {
        let item = layout.textItems[.primaryLabel]!
        return singleRow(layout.primary.label, style: item)
    }

    // MARK: - Secondary

    private static func dividerWidth(
        _ layout: IntervalWorkSummaryRenderLayout
    ) -> Double {
        layout.style.dividerEnabled
            ? max(layout.style.dividerWidth, 0.5)
            : 0
    }

    private static func secondaryGroupHeight(
        layout: IntervalWorkSummaryRenderLayout,
        width: Double
    ) -> Double {
        let count = layout.secondaryItems.count
        guard count > 0 else { return 0 }
        let dividerWidth = dividerWidth(layout)
        let itemWidth = max(
            (width - dividerWidth * Double(max(count - 1, 0))) / Double(count),
            1
        )
        var height = 0.0
        for item in layout.secondaryItems {
            height = max(
                height,
                secondaryItemHeight(
                    item,
                    layout: layout,
                    width: max(itemWidth - 16, 1)
                )
            )
        }
        // The dividers are children of SwiftUI's HStack, so they set the row
        // height when taller than the text stack.
        if count > 1, layout.style.dividerEnabled {
            height = max(height, layout.rect.height * 0.26)
        }
        return height
    }

    private static func drawSecondaryGroup(
        layout: IntervalWorkSummaryRenderLayout,
        rect: CGRect,
        context: OpaquePointer
    ) {
        let count = layout.secondaryItems.count
        guard count > 0 else { return }
        let dividerWidth = dividerWidth(layout)
        let itemWidth = max(
            (rect.width - dividerWidth * Double(max(count - 1, 0))) / Double(count),
            1
        )

        var x = rect.minX
        for (index, item) in layout.secondaryItems.enumerated() {
            if index > 0 {
                SkiaIntervalDraw.fillRect(
                    context,
                    CGRect(
                        x: x,
                        y: rect.midY - layout.rect.height * 0.13,
                        width: dividerWidth,
                        height: layout.rect.height * 0.26
                    ),
                    color: layout.style.dividerColor,
                    opacity: layout.style.dividerOpacity
                )
                x += dividerWidth
            }
            drawSecondaryItem(
                item,
                layout: layout,
                rect: CGRect(x: x, y: rect.minY, width: itemWidth, height: rect.height),
                context: context
            )
            x += itemWidth
        }
    }

    private static func secondaryItemHeight(
        _ item: IntervalWorkSummaryMetricItem,
        layout: IntervalWorkSummaryRenderLayout,
        width: Double
    ) -> Double {
        var height = 0.0
        if let valueStyle = layout.textItems[.secondaryValue] {
            height = SkiaIntervalText.rowHeight(
                secondaryValueRow(item, valueStyle: valueStyle),
                maxWidth: width
            )
        }
        if let labelStyle = layout.textItems[.secondaryLabel],
           labelStyle.style.isVisible,
           item.labelVisible {
            if height > 0 {
                height += 4
            }
            height += SkiaIntervalText.rowHeight(
                singleRow(item.label, style: labelStyle),
                maxWidth: width
            )
        }
        return height
    }

    private static func drawSecondaryItem(
        _ item: IntervalWorkSummaryMetricItem,
        layout: IntervalWorkSummaryRenderLayout,
        rect: CGRect,
        context: OpaquePointer
    ) {
        let textRect = rect.insetBy(dx: 8, dy: 0)
        guard textRect.width > 0 else { return }
        let contentHeight = secondaryItemHeight(
            item,
            layout: layout,
            width: textRect.width
        )
        var y = rect.midY - contentHeight / 2

        if let valueStyle = layout.textItems[.secondaryValue] {
            let row = secondaryValueRow(item, valueStyle: valueStyle)
            let height = SkiaIntervalText.rowHeight(row, maxWidth: textRect.width)
            drawRow(
                row,
                rect: CGRect(
                    x: textRect.minX,
                    y: y,
                    width: textRect.width,
                    height: height
                ),
                context: context
            )
            y += height
        }
        if let labelStyle = layout.textItems[.secondaryLabel],
           labelStyle.style.isVisible,
           item.labelVisible {
            if y > rect.midY - contentHeight / 2 {
                y += 4
            }
            let row = singleRow(item.label, style: labelStyle)
            let height = SkiaIntervalText.rowHeight(row, maxWidth: textRect.width)
            drawRow(
                row,
                rect: CGRect(
                    x: textRect.minX,
                    y: y,
                    width: textRect.width,
                    height: height
                ),
                context: context
            )
        }
    }

    private static func secondaryValueRow(
        _ item: IntervalWorkSummaryMetricItem,
        valueStyle: IntervalWorkSummaryRenderLayout.TextItem
    ) -> SkiaIntervalText.Row {
        var items: [SkiaIntervalText.RowItem] = [
            .init(
                text: item.value,
                font: font(valueStyle, scale: 1, monospacedDigits: true),
                color: valueStyle.color,
                minimumScaleFactor: 0.55
            )
        ]
        if !item.unit.isEmpty {
            items.append(.init(
                text: item.unit,
                font: font(valueStyle, scale: 0.38),
                color: valueStyle.color,
                opacity: 0.9,
                minimumScaleFactor: 1
            ))
        }
        return .init(items: items, spacing: 4, alignment: .firstTextBaseline)
    }

    private static func singleRow(
        _ text: String,
        style: IntervalWorkSummaryRenderLayout.TextItem
    ) -> SkiaIntervalText.Row {
        .init(
            items: [
                .init(
                    text: text,
                    font: font(style, scale: 1),
                    color: style.color,
                    minimumScaleFactor: 1
                )
            ],
            spacing: 0
        )
    }

    private static func font(
        _ item: IntervalWorkSummaryRenderLayout.TextItem,
        scale: Double,
        monospacedDigits: Bool = false
    ) -> NSFont {
        SkiaIntervalText.font(
            family: item.style.fontName,
            size: max(item.fontSize * scale, 6),
            weight: item.style.fontWeight,
            monospacedDigits: monospacedDigits
        )
    }

    private static func drawRow(
        _ row: SkiaIntervalText.Row,
        rect: CGRect,
        context: OpaquePointer
    ) {
        SkiaIntervalText.drawRows(
            [row],
            rect: rect,
            spacing: 0,
            context: context
        )
    }

    // MARK: - Effects

    private static func shadows(
        _ element: OverlayElement,
        layout: IntervalWorkSummaryRenderLayout,
        isEnabled: Bool
    ) -> [SkiaIntervalDraw.Shadow] {
        let style = element.style
        guard isEnabled, style.shadowEnabled else { return [] }
        return [
            .init(
                radius: layout.shadowRadius,
                dx: layout.shadowOffsetX,
                dy: layout.shadowOffsetY,
                color: style.shadowColor,
                alpha: style.shadowOpacity
            ),
            .init(
                radius: layout.shadowRadius * 1.8,
                dx: layout.shadowOffsetX,
                dy: layout.shadowOffsetY * 1.3,
                color: style.shadowColor,
                alpha: style.shadowOpacity * max(style.shadowThickness - 1, 0) * 0.32
            )
        ]
    }

    private static func glowShadows(
        _ element: OverlayElement
    ) -> [SkiaIntervalDraw.Shadow] {
        let style = element.style
        guard style.glowEnabled else { return [] }
        return [
            .init(
                radius: 9 + style.glowIntensity * 18,
                dx: 0,
                dy: 0,
                color: style.glowColor,
                alpha: style.glowIntensity * 0.72
            ),
            .init(
                radius: 18 + style.glowIntensity * 28,
                dx: 0,
                dy: 0,
                color: style.glowColor,
                alpha: style.glowIntensity * 0.35
            )
        ]
    }
}
#endif
