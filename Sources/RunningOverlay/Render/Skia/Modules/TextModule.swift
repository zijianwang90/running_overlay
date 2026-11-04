#if canImport(CSkiaBridge)
import AppKit
import CSkiaBridge
import Foundation

struct SkiaTextPlacedLine {
    var line: SkiaTextLine
    var origin: CGPoint
    var color: OverlayColor
    var opacity: Double
    /// Per-line shadow chain (neonGlow / digitalWatch accent glows). Entries
    /// are innermost first, matching SwiftUI's `.shadow` modifier order.
    var shadows: [SkiaShadowEntry] = []
}

struct SkiaTextPlacedIcon {
    var systemName: String
    var rect: CGRect
    var color: OverlayColor
    var opacity: Double
}

struct SkiaTextDivider {
    var rect: CGRect
    var color: OverlayColor
    var cornerRadius: Double
}

struct SkiaTextStroke {
    var rect: CGRect
    var cornerRadius: Double
    var width: Double
    var color: OverlayColor
}

/// Resolved colors for one text element. Keeps the HR-zone override rules in
/// one place so every preset draws the same role color.
struct SkiaTextPalette {
    var value: OverlayColor
    var valueOpacity: Double
    var label: OverlayColor
    var labelOpacity: Double
    var unit: OverlayColor
    var unitOpacity: Double
    var icon: OverlayColor
    var iconOpacity: Double
    var foreground: OverlayColor
    var accent: OverlayColor
    var divider: OverlayColor
    var dividerOpacity: Double
    var heartRateZoneActive: Bool

    init(element: OverlayElement, layout: OverlayTextRenderLayout) {
        let style = element.style
        let zone = layout.dynamicHeartRateZoneColor
        heartRateZoneActive = zone != nil
            && (layout.valueColorsFollowHeartRateZones
                || layout.labelColorsFollowHeartRateZones
                || layout.unitColorsFollowHeartRateZones)
        value = layout.valueColorsFollowHeartRateZones
            ? (zone ?? style.valueColor)
            : style.valueColor
        valueOpacity = style.valueOpacity
        label = layout.labelColorsFollowHeartRateZones
            ? (zone ?? style.labelColor)
            : style.labelColor
        labelOpacity = style.labelOpacity
        unit = layout.unitColorsFollowHeartRateZones
            ? (zone ?? style.unitColor)
            : style.unitColor
        unitOpacity = style.unitOpacity
        icon = layout.iconColorsFollowHeartRateZones
            ? (zone ?? layout.iconColor)
            : layout.iconColor
        iconOpacity = layout.iconOpacity
        foreground = style.foregroundColor
        accent = style.accentColor
        divider = layout.dividerColor
        dividerOpacity = layout.dividerOpacity
    }
}

/// Pixel composition for one text element, relative to the element's
/// top-left origin.
struct SkiaTextComposition {
    var size: CGSize
    var backgroundRect: CGRect?
    var backgroundCornerRadius: Double
    var lines: [SkiaTextPlacedLine]
    var icons: [SkiaTextPlacedIcon]
    var dividers: [SkiaTextDivider]
    var strokes: [SkiaTextStroke]
    var borderCornerRadius: Double
}

/// Group T entry point. The lead's renderer dispatch calls this for numeric
/// text overlays and decor elements.
enum SkiaTextModule {
    static func supports(_ element: OverlayElement) -> Bool {
        element.type.isNumericOverlay || element.type.isDecorOverlay
    }

    @discardableResult
    static func draw(
        element: OverlayElement,
        context: OpaquePointer,
        canvasSize: CGSize,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval
    ) -> Bool {
        guard element.isVisible else { return false }
        let renderContext = OverlayRenderContext(
            canvasSize: canvasSize,
            activity: activity,
            elapsedTime: elapsedTime
        )

        if element.type.isDecorOverlay {
            SkiaDecorDrawing.draw(
                element: element,
                context: context,
                renderContext: renderContext
            )
            return true
        }

        guard element.type.isNumericOverlay else { return false }
        let layout = OverlayRenderModel.textLayout(for: element, in: renderContext)
        draw(
            element: element,
            layout: layout,
            context: context,
            renderContext: renderContext
        )
        return true
    }

    /// Draws with an explicit layout. Production callers get the layout from
    /// `OverlayRenderModel.textLayout`; golden tests use this seam to exercise
    /// presets that the model currently forces to `.minimal`.
    static func draw(
        element: OverlayElement,
        layout: OverlayTextRenderLayout,
        context: OpaquePointer,
        renderContext: OverlayRenderContext
    ) {
        let composition = SkiaTextPresetDrawing.compose(
            element: element,
            layout: layout,
            renderContext: renderContext
        )
        let origin = CGPoint(
            x: renderContext.canvasSize.width * element.position.x,
            y: renderContext.canvasSize.height * element.position.y
        )
        let bounds = CGRect(origin: origin, size: composition.size)
        SkiaTextEffects.withElementLayers(
            element: element,
            bounds: bounds,
            context: context
        ) {
            draw(
                composition: composition,
                element: element,
                origin: origin,
                context: context
            )
        }
    }

    static func draw(
        composition: SkiaTextComposition,
        element: OverlayElement,
        origin: CGPoint,
        context: OpaquePointer
    ) {
        if let background = composition.backgroundRect {
            SkiaTextEffects.drawBackground(
                element: element,
                rect: background.offsetBy(dx: origin.x, dy: origin.y),
                cornerRadius: composition.backgroundCornerRadius,
                context: context
            )
        }

        for icon in composition.icons {
            SkiaIconRasterCache.draw(
                systemName: icon.systemName,
                rect: icon.rect.offsetBy(dx: origin.x, dy: origin.y),
                color: icon.color,
                opacity: icon.opacity,
                context: context
            )
        }

        for divider in composition.dividers {
            let rect = divider.rect.offsetBy(dx: origin.x, dy: origin.y)
            if divider.cornerRadius > 0 {
                skb_fill_round_rect(
                    context,
                    Float(rect.minX),
                    Float(rect.minY),
                    Float(rect.width),
                    Float(rect.height),
                    Float(divider.cornerRadius),
                    Float(divider.color.red),
                    Float(divider.color.green),
                    Float(divider.color.blue),
                    Float(divider.color.alpha)
                )
            } else {
                skb_fill_rect(
                    context,
                    Float(rect.minX),
                    Float(rect.minY),
                    Float(rect.width),
                    Float(rect.height),
                    Float(divider.color.red),
                    Float(divider.color.green),
                    Float(divider.color.blue),
                    Float(divider.color.alpha)
                )
            }
        }

        for line in composition.lines {
            let lineOrigin = CGPoint(
                x: origin.x + line.origin.x,
                y: origin.y + line.origin.y
            )
            if line.shadows.isEmpty {
                SkiaTextComposer.draw(
                    line.line,
                    context: context,
                    origin: lineOrigin,
                    color: line.color,
                    opacity: line.opacity
                )
            } else {
                let bounds = CGRect(
                    x: lineOrigin.x,
                    y: lineOrigin.y,
                    width: max(line.line.width, 1),
                    height: max(line.line.height, 1)
                )
                let padding = SkiaTextEffects.effectPadding(
                    entries: line.shadows
                )
                let layerBounds = bounds.insetBy(dx: -padding, dy: -padding)
                let sigmas = line.shadows.map { Float($0.sigma) }
                let dxs = line.shadows.map { Float($0.dx) }
                let dys = line.shadows.map { Float($0.dy) }
                var rgba: [Float] = []
                rgba.reserveCapacity(line.shadows.count * 4)
                for shadow in line.shadows {
                    rgba.append(Float(shadow.color.red))
                    rgba.append(Float(shadow.color.green))
                    rgba.append(Float(shadow.color.blue))
                    rgba.append(Float(shadow.alpha * shadow.color.alpha))
                }
                sigmas.withUnsafeBufferPointer { sigmas in
                    dxs.withUnsafeBufferPointer { dxs in
                        dys.withUnsafeBufferPointer { dys in
                            rgba.withUnsafeBufferPointer { rgba in
                                skb_begin_shadow_chain(
                                    context,
                                    Int32(line.shadows.count),
                                    sigmas.baseAddress,
                                    dxs.baseAddress,
                                    dys.baseAddress,
                                    rgba.baseAddress,
                                    Float(layerBounds.minX),
                                    Float(layerBounds.minY),
                                    Float(layerBounds.width),
                                    Float(layerBounds.height)
                                )
                            }
                        }
                    }
                }
                SkiaTextComposer.draw(
                    line.line,
                    context: context,
                    origin: lineOrigin,
                    color: line.color,
                    opacity: line.opacity
                )
                skb_restore(context)
            }
        }

        for stroke in composition.strokes {
            let rect = stroke.rect.offsetBy(dx: origin.x, dy: origin.y)
            skb_stroke_round_rect(
                context,
                Float(rect.minX),
                Float(rect.minY),
                Float(rect.width),
                Float(rect.height),
                Float(stroke.cornerRadius),
                Float(stroke.width),
                Float(stroke.color.red),
                Float(stroke.color.green),
                Float(stroke.color.blue),
                Float(stroke.color.alpha)
            )
        }

        SkiaTextEffects.drawBorder(
            element: element,
            bounds: CGRect(origin: origin, size: composition.size),
            cornerRadius: composition.borderCornerRadius,
            context: context
        )
    }
}
#endif
