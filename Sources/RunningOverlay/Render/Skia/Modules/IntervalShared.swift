#if canImport(CSkiaBridge)
import AppKit
import CSkiaBridge
import CoreGraphics
import CoreText
import Foundation

/// Shared drawing helpers for the Skia interval-family modules.
///
/// Geometry comes from `OverlayRenderModel`; this file only converts resolved
/// layout values into bridge calls. Text shaping is intentionally isolated in
/// `SkiaIntervalText` so it can be replaced by Group T's `SkiaTextComposer`
/// without touching module renderers.
enum SkiaIntervalDraw {
    // MARK: - Color

    static func rgba(_ color: OverlayColor, opacity: Double = 1) -> (Float, Float, Float, Float) {
        (
            Float(min(max(color.red, 0), 1)),
            Float(min(max(color.green, 0), 1)),
            Float(min(max(color.blue, 0), 1)),
            Float(min(max(color.alpha * opacity, 0), 1))
        )
    }

    // MARK: - Shapes

    static func fillRect(
        _ context: OpaquePointer,
        _ rect: CGRect,
        color: OverlayColor,
        opacity: Double = 1
    ) {
        let c = rgba(color, opacity: opacity)
        skb_fill_rect(
            context,
            Float(rect.minX), Float(rect.minY),
            Float(rect.width), Float(rect.height),
            c.0, c.1, c.2, c.3
        )
    }

    static func fillRoundRect(
        _ context: OpaquePointer,
        _ rect: CGRect,
        radius: Double,
        color: OverlayColor,
        opacity: Double = 1
    ) {
        guard rect.width > 0, rect.height > 0 else { return }
        let c = rgba(color, opacity: opacity)
        skb_fill_round_rect(
            context,
            Float(rect.minX), Float(rect.minY),
            Float(rect.width), Float(rect.height),
            Float(max(radius, 0)),
            c.0, c.1, c.2, c.3
        )
    }

    static func strokeRoundRect(
        _ context: OpaquePointer,
        _ rect: CGRect,
        radius: Double,
        lineWidth: Double,
        color: OverlayColor,
        opacity: Double = 1
    ) {
        guard rect.width > 0, rect.height > 0, lineWidth > 0 else { return }
        let c = rgba(color, opacity: opacity)
        skb_stroke_round_rect(
            context,
            Float(rect.minX), Float(rect.minY),
            Float(rect.width), Float(rect.height),
            Float(max(radius, 0)),
            Float(lineWidth),
            c.0, c.1, c.2, c.3
        )
    }

    static func fillCapsule(
        _ context: OpaquePointer,
        _ rect: CGRect,
        color: OverlayColor,
        opacity: Double = 1
    ) {
        fillRoundRect(
            context,
            rect,
            radius: min(rect.width, rect.height) / 2,
            color: color,
            opacity: opacity
        )
    }

    static func fillTriangle(
        _ context: OpaquePointer,
        _ a: CGPoint,
        _ b: CGPoint,
        _ c: CGPoint,
        color: OverlayColor,
        opacity: Double = 1
    ) {
        guard let path = skb_path_create() else { return }
        defer { skb_path_destroy(path) }
        skb_path_move_to(path, Float(a.x), Float(a.y))
        skb_path_line_to(path, Float(b.x), Float(b.y))
        skb_path_line_to(path, Float(c.x), Float(c.y))
        skb_path_close(path)
        let color = rgba(color, opacity: opacity)
        skb_draw_path(
            context, path,
            1,
            color.0, color.1, color.2, color.3,
            0, 0, 0, 0, 0
        )
    }

    // MARK: - Effects

    struct Shadow {
        var sigma: Double
        var dx: Double
        var dy: Double
        var color: OverlayColor
        var alpha: Double

        init(
            radius: Double,
            dx: Double,
            dy: Double,
            color: OverlayColor,
            alpha: Double
        ) {
            self.sigma = SkiaIntervalDraw.shadowSigma(radius)
            self.dx = dx
            self.dy = dy
            self.color = color
            self.alpha = alpha
        }

        init(sigma: Double, dx: Double, dy: Double, color: OverlayColor, alpha: Double) {
            self.sigma = sigma
            self.dx = dx
            self.dy = dy
            self.color = color
            self.alpha = alpha
        }
    }

    /// SwiftUI `shadow(radius:)` to Skia Gaussian sigma. Calibrated against
    /// the interval goldens through an environment override so goldens can be
    /// reviewed without changing production defaults.
    static func shadowSigma(_ radius: Double) -> Double {
        let factor = ProcessInfo.processInfo.environment["SKIA_INTERVAL_SHADOW_SIGMA_FACTOR"]
            .flatMap(Double.init) ?? 1.0
        return max(radius * factor, 0)
    }

    /// SwiftUI `blur(radius:)` to Skia Gaussian sigma.
    static func blurSigma(_ radius: Double) -> Double {
        let factor = ProcessInfo.processInfo.environment["SKIA_INTERVAL_BLUR_SIGMA_FACTOR"]
            .flatMap(Double.init) ?? 0.5
        return max(radius * factor, 0)
    }

    /// Runs `draw` inside a shadow group. Entries are ordered innermost first,
    /// matching SwiftUI's stacked `.shadow` modifiers.
    static func withShadowChain(
        _ context: OpaquePointer,
        shadows: [Shadow],
        bounds: CGRect,
        draw: () -> Void
    ) {
        let active = shadows.filter { $0.alpha > 0.0001 && $0.sigma >= 0 }
        if active.isEmpty {
            skb_save(context)
        } else {
            var sigmas: [Float] = []
            var dxs: [Float] = []
            var dys: [Float] = []
            var rgba: [Float] = []
            for shadow in active {
                sigmas.append(Float(shadow.sigma))
                dxs.append(Float(shadow.dx))
                dys.append(Float(shadow.dy))
                rgba.append(contentsOf: [
                    Float(shadow.color.red),
                    Float(shadow.color.green),
                    Float(shadow.color.blue),
                    Float(min(max(shadow.alpha, 0), 1))
                ])
            }
            sigmas.withUnsafeBufferPointer { sigmas in
                dxs.withUnsafeBufferPointer { dxs in
                    dys.withUnsafeBufferPointer { dys in
                        rgba.withUnsafeBufferPointer { rgba in
                            skb_begin_shadow_chain(
                                context,
                                Int32(active.count),
                                sigmas.baseAddress,
                                dxs.baseAddress,
                                dys.baseAddress,
                                rgba.baseAddress,
                                Float(bounds.minX),
                                Float(bounds.minY),
                                Float(bounds.width),
                                Float(bounds.height)
                            )
                        }
                    }
                }
            }
        }
        draw()
        skb_restore(context)
    }

    /// Runs `draw` inside a blur group.
    static func withBlur(
        _ context: OpaquePointer,
        sigma: Double,
        bounds: CGRect,
        draw: () -> Void
    ) {
        guard sigma > 0.0001 else {
            draw()
            return
        }
        skb_begin_blur_layer(
            context,
            Float(sigma),
            Float(bounds.minX), Float(bounds.minY),
            Float(bounds.width), Float(bounds.height)
        )
        draw()
        skb_restore(context)
    }

    /// Applies the whole-module `element.opacity` through a group layer.
    static func withElementOpacity(
        _ context: OpaquePointer,
        element: OverlayElement,
        bounds: CGRect,
        draw: () -> Void
    ) {
        let alpha = min(max(element.opacity, 0), 1)
        guard alpha < 0.999 else {
            draw()
            return
        }
        let expanded = bounds.insetBy(dx: -max(bounds.width * 0.5, 64), dy: -max(bounds.height * 0.5, 64))
        skb_begin_opacity_layer(
            context,
            Float(alpha),
            Float(expanded.minX), Float(expanded.minY),
            Float(expanded.width), Float(expanded.height)
        )
        draw()
        skb_restore(context)
    }

    // MARK: - Feathered background

    /// Caches the distance-field mask images used by `OverlayFeatheredBackground`.
    final class MaskCache {
        private struct Key: Hashable {
            var width: Int
            var height: Int
            var radius: Double
            var fade: Double
        }

        private var images: [Key: OpaquePointer] = [:]

        deinit {
            for image in images.values {
                skb_image_destroy(image)
            }
        }

        func mask(size: CGSize, cornerRadius: Double, fadeAmount: Double) -> OpaquePointer? {
            let width = max(Int(size.width.rounded(.up)), 1)
            let height = max(Int(size.height.rounded(.up)), 1)
            let key = Key(width: width, height: height, radius: cornerRadius, fade: fadeAmount)
            if let cached = images[key] {
                return cached
            }
            guard let mask = Self.makeMaskImage(
                width: width,
                height: height,
                cornerRadius: cornerRadius,
                fadeAmount: fadeAmount
            ) else { return nil }
            images[key] = mask
            return mask
        }

        private static func makeMaskImage(
            width: Int,
            height: Int,
            cornerRadius: Double,
            fadeAmount: Double
        ) -> OpaquePointer? {
            guard let cgMask = OverlayFeatherMaskRenderer.makeCGMask(
                size: CGSize(width: width, height: height),
                cornerRadius: cornerRadius,
                fadeAmount: fadeAmount
            ) else { return nil }

            var gray = [UInt8](repeating: 0, count: width * height)
            let grayOK = gray.withUnsafeMutableBytes { raw -> Bool in
                guard let base = raw.baseAddress,
                      let bitmap = CGContext(
                        data: base,
                        width: width,
                        height: height,
                        bitsPerComponent: 8,
                        bytesPerRow: width,
                        space: CGColorSpaceCreateDeviceGray(),
                        bitmapInfo: CGImageAlphaInfo.none.rawValue
                      ) else { return false }
                bitmap.draw(
                    cgMask,
                    in: CGRect(x: 0, y: 0, width: width, height: height)
                )
                return true
            }
            guard grayOK else { return nil }

            // `skb_image_create` expects premultiplied BGRA. For a white mask,
            // premultiplied RGB equals alpha.
            var bgra = [UInt8](repeating: 0, count: width * height * 4)
            for index in 0..<(width * height) {
                let alpha = gray[index]
                let offset = index * 4
                bgra[offset] = alpha
                bgra[offset + 1] = alpha
                bgra[offset + 2] = alpha
                bgra[offset + 3] = alpha
            }
            return bgra.withUnsafeBufferPointer { buffer in
                skb_image_create(buffer.baseAddress, Int32(width), Int32(height))
            }
        }
    }

    /// Draws the same feathered rounded background as
    /// `OverlayFeatheredBackground` without material blur.
    static func fillFeatheredBackground(
        _ context: OpaquePointer,
        rect: CGRect,
        cornerRadius: Double,
        color: OverlayColor,
        opacity: Double,
        fadeEnabled: Bool,
        fadeAmount: Double,
        maskCache: MaskCache
    ) {
        guard rect.width > 1, rect.height > 1 else { return }
        if fadeEnabled,
           fadeAmount > 0.001,
           let mask = maskCache.mask(
                size: rect.size,
                cornerRadius: cornerRadius,
                fadeAmount: fadeAmount
           ) {
            // Isolate the destination-in blend in a layer so it only affects
            // this background, not the rest of the frame.
            skb_begin_opacity_layer(
                context,
                1,
                Float(rect.minX), Float(rect.minY),
                Float(rect.width), Float(rect.height)
            )
            fillRoundRect(
                context,
                rect,
                radius: cornerRadius,
                color: color,
                opacity: opacity
            )
            skb_draw_image_dst_in(
                context,
                mask,
                Float(rect.minX), Float(rect.minY),
                Float(rect.width), Float(rect.height)
            )
            skb_restore(context)
        } else {
            fillRoundRect(
                context,
                rect,
                radius: cornerRadius,
                color: color,
                opacity: opacity
            )
        }
    }
}

// MARK: - Text

/// Minimal single-line / vertical-stack text drawing for the interval modules.
///
/// TODO(Group T): replace this with `SkiaTextComposer` when it is published.
/// This helper deliberately exposes only shaping, fitting, and vertical
/// stacking so the swap is mechanical.
enum SkiaIntervalText {
    struct Line {
        var glyphs: [CGGlyph]
        var xPositions: [Float]
        var width: Double
        var ascent: Double
        var descent: Double
        var leading: Double

        var height: Double { ascent + descent + leading }
    }

    struct StackLine {
        var text: String
        var font: NSFont
        var color: OverlayColor
        var opacity: Double
        var minimumScaleFactor: Double
        var monospacedDigits: Bool
    }

    static func font(
        family: String,
        size: Double,
        weight: OverlayFontWeight,
        monospacedDigits: Bool
    ) -> NSFont {
        var font = OverlayFontResolver.appKitFont(
            family: family,
            size: size,
            weight: nsWeight(weight)
        )
        if monospacedDigits {
            let descriptor = font.fontDescriptor.addingAttributes([
                .featureSettings: [
                    [
                        NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
                        NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector
                    ]
                ]
            ])
            if let monoFont = NSFont(descriptor: descriptor, size: size) {
                font = monoFont
            }
        }
        return font
    }

    static func makeLine(_ text: String, font: NSFont, tracking: Double = 0) -> Line {
        var attributes: [NSAttributedString.Key: Any] = [.font: font]
        if tracking != 0 {
            attributes[.kern] = tracking
        }
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: attributes)
        )
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)

        var glyphs: [CGGlyph] = []
        var xPositions: [Float] = []
        if let runs = CTLineGetGlyphRuns(line) as? [CTRun] {
            for run in runs {
                let count = CTRunGetGlyphCount(run)
                guard count > 0 else { continue }
                var runGlyphs = [CGGlyph](repeating: 0, count: count)
                var runPositions = [CGPoint](repeating: .zero, count: count)
                let range = CFRange(location: 0, length: count)
                CTRunGetGlyphs(run, range, &runGlyphs)
                CTRunGetPositions(run, range, &runPositions)
                glyphs.append(contentsOf: runGlyphs)
                xPositions.append(contentsOf: runPositions.map { Float($0.x) })
            }
        }
        return Line(
            glyphs: glyphs,
            xPositions: xPositions,
            width: width,
            ascent: ascent,
            descent: descent,
            leading: leading
        )
    }

    static func draw(
        _ line: Line,
        font: NSFont,
        x: Double,
        baselineY: Double,
        color: OverlayColor,
        opacity: Double,
        context: OpaquePointer
    ) {
        guard !line.glyphs.isEmpty else { return }
        let c = SkiaIntervalDraw.rgba(color, opacity: opacity)
        line.glyphs.withUnsafeBufferPointer { glyphs in
            line.xPositions.withUnsafeBufferPointer { positions in
                skb_draw_glyphs(
                    context,
                    Unmanaged.passUnretained(font).toOpaque(),
                    glyphs.baseAddress,
                    positions.baseAddress,
                    Int32(line.glyphs.count),
                    Float(x),
                    Float(baselineY),
                    c.0, c.1, c.2, c.3,
                    0, 0, 0, 0
                )
            }
        }
    }

    enum Alignment {
        case leading
        case center
        case trailing
    }

    /// Shrinks then truncates one line to fit `maxWidth`.
    static func fitted(
        _ text: String,
        font: NSFont,
        maxWidth: Double,
        minimumScaleFactor: Double
    ) -> (text: String, font: NSFont, line: Line) {
        guard !text.isEmpty, maxWidth > 0 else {
            return (text, font, makeLine(text, font: font))
        }
        var line = makeLine(text, font: font)
        var drawFont = font
        var drawText = text
        if line.width > maxWidth, line.width > 0 {
            let scale = max(min(max(maxWidth / line.width, minimumScaleFactor), 1), 0.01)
            if scale < 1 {
                drawFont = NSFont(
                    descriptor: font.fontDescriptor,
                    size: font.pointSize * CGFloat(scale)
                ) ?? font
                line = makeLine(text, font: drawFont)
            }
        }
        if line.width > maxWidth {
            drawText = truncate(text, font: drawFont, maxWidth: maxWidth)
            line = makeLine(drawText, font: drawFont)
        }
        return (drawText, drawFont, line)
    }

    /// Draws one line inside `rect`, shrinking or truncating to fit the width.
    static func drawFitting(
        _ text: String,
        font: NSFont,
        color: OverlayColor,
        opacity: Double,
        rect: CGRect,
        alignment: Alignment,
        minimumScaleFactor: Double,
        monospacedDigits: Bool,
        context: OpaquePointer
    ) {
        guard !text.isEmpty, rect.width > 0 else { return }
        let fitted = fitted(
            text,
            font: font,
            maxWidth: rect.width,
            minimumScaleFactor: minimumScaleFactor
        )
        let x: Double
        switch alignment {
        case .leading: x = rect.minX
        case .center: x = rect.midX - fitted.line.width / 2
        case .trailing: x = rect.maxX - fitted.line.width
        }
        let baselineY = rect.midY - fitted.line.height / 2 + fitted.line.ascent
        draw(
            fitted.line,
            font: fitted.font,
            x: x,
            baselineY: baselineY,
            color: color,
            opacity: opacity,
            context: context
        )
    }

    /// Draws a centered vertical stack of lines inside `rect`.
    static func drawStack(
        _ lines: [StackLine],
        rect: CGRect,
        spacing: Double,
        context: OpaquePointer
    ) {
        guard !lines.isEmpty, rect.width > 0 else { return }

        struct Measured {
            var text: String
            var font: NSFont
            var line: Line
            var color: OverlayColor
            var opacity: Double
        }

        var measured: [Measured] = []
        for item in lines where !item.text.isEmpty {
            let fitted = fitted(
                item.text,
                font: item.font,
                maxWidth: rect.width,
                minimumScaleFactor: item.minimumScaleFactor
            )
            measured.append(Measured(
                text: fitted.text,
                font: fitted.font,
                line: fitted.line,
                color: item.color,
                opacity: item.opacity
            ))
        }
        guard !measured.isEmpty else { return }

        let totalHeight = measured.reduce(0) { $0 + $1.line.height }
            + spacing * Double(max(measured.count - 1, 0))
        var top = rect.midY - totalHeight / 2
        for item in measured {
            let x = rect.midX - item.line.width / 2
            let baselineY = top + item.line.ascent
            draw(
                item.line,
                font: item.font,
                x: x,
                baselineY: baselineY,
                color: item.color,
                opacity: item.opacity,
                context: context
            )
            top += item.line.height + spacing
        }
    }

    private static func truncate(_ text: String, font: NSFont, maxWidth: Double) -> String {
        guard !text.isEmpty else { return text }
        let ellipsis = "…"
        var characters = Array(text)
        while !characters.isEmpty {
            characters.removeLast()
            let candidate = String(characters) + ellipsis
            if makeLine(candidate, font: font).width <= maxWidth {
                return candidate
            }
        }
        return ellipsis
    }

    static func nsWeight(_ weight: OverlayFontWeight) -> NSFont.Weight {
        switch weight {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }
}
#endif
