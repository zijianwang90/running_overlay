#if canImport(CSkiaBridge)
import AppKit
import CSkiaBridge
import CoreGraphics
import Foundation

/// Skia port of `IntervalCountdownOverlayView`.
enum IntervalCountdownSkiaRenderer {
    static func draw(
        _ element: OverlayElement,
        layout: IntervalCountdownRenderLayout,
        context: OpaquePointer,
        maskCache: SkiaIntervalDraw.MaskCache
    ) {
        let style = element.style
        let rect = layout.rect
        let padX = layout.backgroundPaddingX
        let padY = layout.backgroundPaddingY
        let backgroundRect = rect.insetBy(dx: -padX, dy: -padY)
        let backgroundRadius = min(
            max(layout.backgroundRadius, 0),
            min(backgroundRect.width, backgroundRect.height) / 2
        )

        let ringGlowRadius = layout.style.ringGlowEnabled
            ? max(layout.style.ringGlowIntensity * 28, 0)
            : 0
        let globalGlowRadius = style.glowEnabled
            ? max(style.glowIntensity * 34, 0)
            : 0
        let shadowSigma = SkiaIntervalDraw.shadowSigma(layout.shadowRadius)
        let bleed = max(ringGlowRadius, globalGlowRadius) * 3
            + max(shadowSigma * 3, 0)
            + max(padX, padY)
            + 24
        let drawBounds = rect.insetBy(dx: -bleed, dy: -bleed)

        SkiaIntervalDraw.withElementOpacity(context, element: element, bounds: drawBounds) {
            if style.backgroundEnabled {
                SkiaIntervalDraw.withShadowChain(
                    context,
                    shadows: elementShadow(element, layout: layout, isEnabled: true),
                    bounds: drawBounds
                ) {
                    SkiaIntervalDraw.fillRoundRect(
                        context,
                        backgroundRect,
                        radius: backgroundRadius,
                        color: style.backgroundColor,
                        opacity: style.backgroundOpacity
                    )
                }
                if style.borderEnabled {
                    SkiaIntervalDraw.strokeRoundRect(
                        context,
                        backgroundRect,
                        radius: backgroundRadius,
                        lineWidth: layout.borderWidth,
                        color: style.borderColor,
                        opacity: style.borderOpacity
                    )
                }
            }

            SkiaIntervalDraw.withShadowChain(
                context,
                shadows: elementShadow(
                    element,
                    layout: layout,
                    isEnabled: !style.backgroundEnabled
                ),
                bounds: drawBounds
            ) {
                SkiaIntervalDraw.withShadowChain(
                    context,
                    shadows: globalGlowShadows(element),
                    bounds: drawBounds
                ) {
                    drawRing(element, layout: layout, context: context)
                    drawText(element, layout: layout, context: context)
                }
            }
        }
    }

    // MARK: - Ring

    private static func drawRing(
        _ element: OverlayElement,
        layout: IntervalCountdownRenderLayout,
        context: OpaquePointer
    ) {
        let style = layout.style
        let cx = layout.rect.midX
        let cy = layout.rect.midY
        // SwiftUI pads the ring by `ringWidth` before stroking the inscribed
        // circle, so the path radius is half the padded view.
        let radius = max((layout.rect.width - layout.ringWidth * 2) / 2, 0)
        guard radius > 0 else { return }
        let cap: Int32 = style.roundedLineCap ? 1 : 0

        drawArc(
            context,
            center: CGPoint(x: cx, y: cy),
            radius: radius,
            startDegrees: 0,
            sweepDegrees: 360,
            lineWidth: layout.ringWidth,
            color: style.trackColor,
            opacity: style.trackOpacity,
            cap: cap
        )

        guard layout.progress > 0.0001 else { return }
        let clockwise = style.resolvedRingDirection == .clockwise
        let sweep = layout.progress * 360 * (clockwise ? 1 : -1)
        let progressPath = makeArc(
            center: CGPoint(x: cx, y: cy),
            radius: radius,
            startDegrees: -90,
            sweepDegrees: sweep
        )
        guard let path = progressPath else { return }
        defer { skb_path_destroy(path) }

        SkiaIntervalDraw.withShadowChain(
            context,
            shadows: ringGlowShadows(layout),
            bounds: CGRect(
                x: cx - radius,
                y: cy - radius,
                width: radius * 2,
                height: radius * 2
            ).insetBy(dx: -90, dy: -90)
        ) {
            strokePath(
                context,
                path,
                lineWidth: layout.ringWidth,
                color: layout.ringColor,
                opacity: 1,
                cap: cap
            )
        }
    }

    private static func drawArc(
        _ context: OpaquePointer,
        center: CGPoint,
        radius: Double,
        startDegrees: Double,
        sweepDegrees: Double,
        lineWidth: Double,
        color: OverlayColor,
        opacity: Double,
        cap: Int32
    ) {
        guard let path = makeArc(
            center: center,
            radius: radius,
            startDegrees: startDegrees,
            sweepDegrees: sweepDegrees
        ) else { return }
        defer { skb_path_destroy(path) }
        strokePath(
            context,
            path,
            lineWidth: lineWidth,
            color: color,
            opacity: opacity,
            cap: cap
        )
    }

    private static func makeArc(
        center: CGPoint,
        radius: Double,
        startDegrees: Double,
        sweepDegrees: Double
    ) -> OpaquePointer? {
        guard let path = skb_path_create() else { return nil }
        skb_path_add_arc(
            path,
            Float(center.x),
            Float(center.y),
            Float(radius),
            Float(startDegrees),
            Float(sweepDegrees),
            1
        )
        return path
    }

    private static func strokePath(
        _ context: OpaquePointer,
        _ path: OpaquePointer,
        lineWidth: Double,
        color: OverlayColor,
        opacity: Double,
        cap: Int32
    ) {
        let c = SkiaIntervalDraw.rgba(color, opacity: opacity)
        skb_draw_path(
            context,
            path,
            0,
            c.0, c.1, c.2, c.3,
            Float(lineWidth),
            cap,
            1,
            0,
            0
        )
    }

    // MARK: - Text

    private static func drawText(
        _ element: OverlayElement,
        layout: IntervalCountdownRenderLayout,
        context: OpaquePointer
    ) {
        let rows = makeRows(layout: layout, elementScale: element.scale)
        guard !rows.isEmpty else { return }
        let textRect = CGRect(
            x: layout.rect.midX - layout.innerDiameter / 2,
            y: layout.rect.midY - layout.innerDiameter / 2,
            width: layout.innerDiameter,
            height: layout.innerDiameter
        )
        SkiaIntervalText.drawRows(
            rows,
            rect: textRect,
            spacing: max(2 * element.scale, 1),
            context: context
        )
    }

    private static func makeRows(
        layout: IntervalCountdownRenderLayout,
        elementScale: Double
    ) -> [SkiaIntervalText.Row] {
        var rows: [SkiaIntervalText.Row] = []
        let phase = item(.phase, in: layout)
        let rep = item(.rep, in: layout)

        if let helper = item(.helper, in: layout) {
            rows.append(.init(
                items: [rowItem(helper, uppercase: true)],
                spacing: 0
            ))
        }
        if phase != nil || rep != nil {
            var items: [SkiaIntervalText.RowItem] = []
            if let phase {
                items.append(rowItem(phase, uppercase: true))
            }
            if let rep {
                items.append(rowItem(rep, uppercase: false))
            }
            rows.append(.init(
                items: items,
                spacing: max(5 * elementScale, 2)
            ))
        }
        if let countdown = item(.countdown, in: layout) {
            var converted = rowItem(countdown, uppercase: false)
            converted.minimumScaleFactor = 0.62
            converted.verticalPadding = max(2 * elementScale, 1)
            rows.append(.init(items: [converted], spacing: 0))
        }
        if let caption = item(.caption, in: layout) {
            rows.append(.init(
                items: [rowItem(caption, uppercase: false)],
                spacing: 0
            ))
        }
        return rows
    }

    private static func item(
        _ role: IntervalCountdownTextRole,
        in layout: IntervalCountdownRenderLayout
    ) -> IntervalCountdownRenderLayout.TextItem? {
        layout.textItems.first { $0.role == role }
    }

    private static func rowItem(
        _ item: IntervalCountdownRenderLayout.TextItem,
        uppercase: Bool
    ) -> SkiaIntervalText.RowItem {
        let font = SkiaIntervalText.font(
            family: item.style.fontName,
            size: item.fontSize,
            weight: item.style.fontWeight,
            monospacedDigits: item.role == .countdown
        )
        return SkiaIntervalText.RowItem(
            text: uppercase ? item.text.uppercased() : item.text,
            font: font,
            color: item.color,
            minimumScaleFactor: 0.64
        )
    }

    // MARK: - Effects

    private static func elementShadow(
        _ element: OverlayElement,
        layout: IntervalCountdownRenderLayout,
        isEnabled: Bool
    ) -> [SkiaIntervalDraw.Shadow] {
        let style = element.style
        guard isEnabled, style.shadowEnabled else { return [] }
        let thickness = style.shadowThickness
        return [
            .init(
                radius: layout.shadowRadius,
                dx: layout.shadowOffsetX,
                dy: layout.shadowOffsetY,
                color: style.shadowColor,
                alpha: style.shadowOpacity
            ),
            .init(
                radius: layout.shadowRadius * 0.72,
                dx: layout.shadowOffsetX,
                dy: layout.shadowOffsetY,
                color: style.shadowColor,
                alpha: style.shadowOpacity * max(thickness - 1, 0) * 0.32
            ),
            .init(
                radius: layout.shadowRadius * 0.48,
                dx: layout.shadowOffsetX,
                dy: layout.shadowOffsetY,
                color: style.shadowColor,
                alpha: style.shadowOpacity * max(thickness - 2, 0) * 0.22
            )
        ]
    }

    /// Ring and element glows use the same SwiftUI radius/alpha mapping as the
    /// rest of the interval family. The remaining `effects` residual is a
    /// kernel-shape difference: scaling this pair up by 1.8 improves that
    /// variant but over-brightens the default countdown, so the mapping stays
    /// neutral until `SkiaTextEffects` owns element glows. `SKIA_INTERVAL_*`
    /// overrides remain available for re-calibration.
    private static var ringGlowSigmaScale: Double {
        (ProcessInfo.processInfo.environment["SKIA_INTERVAL_RING_GLOW_SIGMA_SCALE"]
            .flatMap(Double.init) ?? 1)
    }

    private static var globalGlowSigmaScale: Double {
        (ProcessInfo.processInfo.environment["SKIA_INTERVAL_GLOBAL_GLOW_SIGMA_SCALE"]
            .flatMap(Double.init) ?? 1)
    }

    private static var ringGlowAlphaScale: Double {
        (ProcessInfo.processInfo.environment["SKIA_INTERVAL_RING_GLOW_ALPHA_SCALE"]
            .flatMap(Double.init) ?? 1)
    }

    private static var globalGlowAlphaScale: Double {
        (ProcessInfo.processInfo.environment["SKIA_INTERVAL_GLOBAL_GLOW_ALPHA_SCALE"]
            .flatMap(Double.init) ?? 1)
    }

    private static func ringGlowShadows(
        _ layout: IntervalCountdownRenderLayout
    ) -> [SkiaIntervalDraw.Shadow] {
        guard layout.style.ringGlowEnabled else { return [] }
        let intensity = layout.style.ringGlowIntensity
        return [
            .init(
                radius: max(intensity * 16, 0) * ringGlowSigmaScale,
                dx: 0,
                dy: 0,
                color: layout.ringColor,
                alpha: intensity * 0.70 * ringGlowAlphaScale
            ),
            .init(
                radius: max(intensity * 28, 0) * ringGlowSigmaScale,
                dx: 0,
                dy: 0,
                color: layout.ringColor,
                alpha: intensity * 0.35 * ringGlowAlphaScale
            )
        ]
    }

    private static func globalGlowShadows(
        _ element: OverlayElement
    ) -> [SkiaIntervalDraw.Shadow] {
        let style = element.style
        guard style.glowEnabled else { return [] }
        return [
            .init(
                radius: max(style.glowIntensity * 18, 0) * globalGlowSigmaScale,
                dx: 0,
                dy: 0,
                color: style.glowColor,
                alpha: style.glowIntensity * 0.72 * globalGlowAlphaScale
            ),
            .init(
                radius: max(style.glowIntensity * 34, 0) * globalGlowSigmaScale,
                dx: 0,
                dy: 0,
                color: style.glowColor,
                alpha: style.glowIntensity * 0.35 * globalGlowAlphaScale
            )
        ]
    }
}
#endif
