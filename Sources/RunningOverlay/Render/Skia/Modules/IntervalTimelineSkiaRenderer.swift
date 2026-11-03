#if canImport(CSkiaBridge)
import AppKit
import CSkiaBridge
import CoreGraphics
import Foundation

/// Skia port of `IntervalTimelineOverlayView`.
///
/// All geometry comes from `OverlayRenderModel.intervalTimelineLayout`; this
/// file only maps the resolved layout into bridge calls.
enum IntervalTimelineSkiaRenderer {
    static func draw(
        _ element: OverlayElement,
        layout: IntervalTimelineRenderLayout,
        context: OpaquePointer,
        maskCache: SkiaIntervalDraw.MaskCache
    ) {
        let style = element.style
        let padX = style.backgroundPaddingX * element.scale
        let padY = style.backgroundPaddingY * element.scale
        let backgroundRect = layout.rect.insetBy(dx: -padX, dy: -padY)
        let shadowSigma = SkiaIntervalDraw.shadowSigma(style.shadowRadius)
        let shadowPad = max(padX, padY) + shadowSigma * 3
        let drawBounds = layout.rect.insetBy(dx: -shadowPad, dy: -shadowPad)

        SkiaIntervalDraw.withElementOpacity(
            context,
            element: element,
            bounds: drawBounds
        ) {
            if style.backgroundEnabled {
                SkiaIntervalDraw.withShadowChain(
                    context,
                    shadows: style.shadowEnabled
                        ? [shadow(for: element)]
                        : [],
                    bounds: drawBounds
                ) {
                    // TODO(Group T / materials): `OverlayFeatheredBackground`
                    // also applies `backgroundBlurRadius` material blur. The
                    // bridge has no backdrop-blur primitive yet; the fade mask
                    // and color are drawn here, the material blur is not.
                    SkiaIntervalDraw.fillFeatheredBackground(
                        context,
                        rect: backgroundRect,
                        cornerRadius: layout.cornerRadius,
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
                shadows: !style.backgroundEnabled && style.shadowEnabled
                    ? [shadow(for: element)]
                    : [],
                bounds: drawBounds
            ) {
                if style.borderEnabled {
                    SkiaIntervalDraw.strokeRoundRect(
                        context,
                        backgroundRect,
                        radius: layout.cornerRadius,
                        lineWidth: layout.borderWidth,
                        color: style.borderColor,
                        opacity: style.borderOpacity
                    )
                }

                for segment in layout.segments {
                    drawSegment(
                        element,
                        segment: segment,
                        layout: layout,
                        context: context
                    )
                }

                drawOverflowHints(element, layout: layout, context: context)

                if layout.style.markerEnabled {
                    drawMarker(element, layout: layout, context: context)
                }
            }
        }
    }

    // MARK: - Segments

    private static func drawSegment(
        _ element: OverlayElement,
        segment: IntervalTimelineSegmentLayout,
        layout: IntervalTimelineRenderLayout,
        context: OpaquePointer
    ) {
        let rect = segment.rect
        guard rect.width > 0, rect.height > 0 else { return }
        let radius = min(layout.segmentCornerRadius, rect.width / 2, rect.height / 2)

        SkiaIntervalDraw.withShadowChain(
            context,
            shadows: segment.isCurrent
                ? [.init(
                    radius: 10 * element.scale,
                    dx: 0,
                    dy: 0,
                    color: segment.color,
                    alpha: 0.45
                )]
                : [],
            bounds: rect.insetBy(dx: -12 * element.scale, dy: -12 * element.scale)
        ) {
            SkiaIntervalDraw.fillRoundRect(
                context,
                rect,
                radius: radius,
                color: segment.color,
                opacity: segment.opacity
            )

            if segment.isCurrent, layout.style.currentProgressEnabled {
                let progressWidth = rect.width * layout.currentProgress
                if progressWidth > 0 {
                    SkiaIntervalDraw.fillRoundRect(
                        context,
                        CGRect(x: rect.minX, y: rect.minY, width: progressWidth, height: rect.height),
                        radius: min(layout.segmentCornerRadius, progressWidth / 2, rect.height / 2),
                        color: .white,
                        opacity: 0.30
                    )
                }
            }

            if segment.isCurrent {
                SkiaIntervalDraw.strokeRoundRect(
                    context,
                    rect,
                    radius: radius,
                    lineWidth: layout.currentSegmentBorderWidth,
                    color: .white,
                    opacity: 0.74
                )
            }
        }

        drawSegmentText(element, segment: segment, layout: layout, context: context)
    }

    private static func drawSegmentText(
        _ element: OverlayElement,
        segment: IntervalTimelineSegmentLayout,
        layout: IntervalTimelineRenderLayout,
        context: OpaquePointer
    ) {
        let padding = 4 * element.scale
        let textRect = segment.rect.insetBy(dx: padding, dy: 0)
        guard textRect.width > 0 else { return }

        var lines: [SkiaIntervalText.StackLine] = []
        if segment.isCurrent, let repText = layout.repText {
            lines.append(.init(
                text: repText,
                font: SkiaIntervalText.font(
                    family: element.style.fontName,
                    size: max(layout.durationFontSize * 0.82, 8),
                    weight: .semibold,
                    monospacedDigits: false
                ),
                color: .white,
                opacity: 0.78,
                minimumScaleFactor: 0.7,
                monospacedDigits: false
            ))
        }

        for (offset, text) in segment.labelLines.enumerated() {
            let size: Double
            if offset == 0 {
                size = segment.isCurrent ? layout.labelFontSize * 1.08 : layout.labelFontSize
            } else {
                size = layout.durationFontSize
            }
            lines.append(.init(
                text: text,
                font: SkiaIntervalText.font(
                    family: element.style.fontName,
                    size: size,
                    weight: offset == 0 ? .bold : .semibold,
                    monospacedDigits: true
                ),
                color: .white,
                opacity: offset == 0 ? 0.96 : 0.86,
                minimumScaleFactor: 0.64,
                monospacedDigits: true
            ))
        }

        SkiaIntervalText.drawStack(
            lines,
            rect: textRect,
            spacing: 1 * element.scale,
            context: context
        )
    }

    // MARK: - Overflow hints

    private static func drawOverflowHints(
        _ element: OverlayElement,
        layout: IntervalTimelineRenderLayout,
        context: OpaquePointer
    ) {
        guard layout.style.overflowHintEnabled else { return }
        let font = SkiaIntervalText.font(
            family: element.style.fontName,
            size: layout.labelFontSize * 0.95,
            weight: .bold,
            monospacedDigits: false
        )
        let line = SkiaIntervalText.makeLine("···", font: font)
        let y = layout.contentRect.midY - line.height / 2 + line.ascent

        if layout.leftOverflowCount > 0 {
            let x = layout.rect.minX + layout.overflowEllipsisInset
            SkiaIntervalText.draw(
                line,
                font: font,
                x: x - line.width / 2,
                baselineY: y,
                color: element.style.foregroundColor,
                opacity: 0.50,
                context: context
            )
        }
        if layout.rightOverflowCount > 0 {
            let x = layout.rect.maxX - layout.overflowEllipsisInset
            SkiaIntervalText.draw(
                line,
                font: font,
                x: x - line.width / 2,
                baselineY: y,
                color: element.style.foregroundColor,
                opacity: 0.50,
                context: context
            )
        }
    }

    // MARK: - Marker

    private static func drawMarker(
        _ element: OverlayElement,
        layout: IntervalTimelineRenderLayout,
        context: OpaquePointer
    ) {
        let markerColor = layout.style.markerColor
        let triangleRect = CGRect(
            x: layout.markerX - layout.markerTriangleWidth / 2,
            y: layout.markerTopY,
            width: layout.markerTriangleWidth,
            height: layout.markerTriangleHeight
        )
        SkiaIntervalDraw.fillTriangle(
            context,
            CGPoint(x: triangleRect.midX, y: triangleRect.minY),
            CGPoint(x: triangleRect.maxX, y: triangleRect.maxY),
            CGPoint(x: triangleRect.minX, y: triangleRect.maxY),
            color: markerColor,
            opacity: 0.92
        )

        guard layout.style.markerLabelEnabled else { return }
        let labelTop = layout.markerTopY + layout.markerTriangleHeight + layout.markerStackSpacing
        let family = layout.style.markerFontName.isEmpty
            ? element.style.fontName
            : layout.style.markerFontName
        let font = SkiaIntervalText.font(
            family: family,
            size: layout.markerFontSize,
            weight: layout.style.markerFontWeight,
            monospacedDigits: false
        )
        // The SwiftUI view constrains the label by height only and lets the
        // text size itself horizontally, so `markerLabelWidth` is intentionally
        // not used as a truncation box here.
        let line = SkiaIntervalText.makeLine(layout.markerLabel, font: font)
        let baselineY = labelTop + layout.markerLabelHeight / 2 - line.height / 2 + line.ascent
        SkiaIntervalText.draw(
            line,
            font: font,
            x: layout.markerX - line.width / 2,
            baselineY: baselineY,
            color: markerColor,
            opacity: 0.88,
            context: context
        )
    }

    // MARK: - Helpers

    private static func shadow(for element: OverlayElement) -> SkiaIntervalDraw.Shadow {
        .init(
            radius: element.style.shadowRadius,
            dx: element.style.shadowOffsetX,
            dy: element.style.shadowOffsetY,
            color: element.style.shadowColor,
            alpha: element.style.shadowOpacity
        )
    }
}
#endif
