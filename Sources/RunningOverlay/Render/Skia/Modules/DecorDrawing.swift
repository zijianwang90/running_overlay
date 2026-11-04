#if canImport(CSkiaBridge)
import AppKit
import CoreGraphics
import CSkiaBridge
import Foundation

/// Decor Solid Color, Decor Icon, and Decor Text.
enum SkiaDecorDrawing {
    static func draw(
        element: OverlayElement,
        context: OpaquePointer,
        renderContext: OverlayRenderContext
    ) {
        switch element.type {
        case .decorSolidColor:
            drawSolidColor(element, context: context, renderContext: renderContext)
        case .decorIcon:
            drawIcon(element, context: context, renderContext: renderContext)
        case .decorText:
            drawText(element, context: context, renderContext: renderContext)
        default:
            break
        }
    }

    // MARK: - Solid color

    private static func drawSolidColor(
        _ element: OverlayElement,
        context: OpaquePointer,
        renderContext: OverlayRenderContext
    ) {
        let layout = OverlayRenderModel.decorSolidColorLayout(
            for: element,
            in: renderContext
        )
        let origin = centeredOrigin(
            for: element,
            size: layout.size,
            renderContext: renderContext
        )
        let rect = CGRect(origin: origin, size: layout.size)

        SkiaTextEffects.withElementLayers(
            element: element,
            bounds: rect,
            context: context,
            entries: decorShadowEntries(for: element)
        ) {
            fillShape(
                layout.shape,
                rect: rect,
                cornerRadius: layout.cornerRadius,
                color: layout.fillColor,
                context: context
            )
            if element.style.borderEnabled {
                strokeShape(
                    layout.shape,
                    rect: rect,
                    cornerRadius: layout.cornerRadius,
                    width: element.style.borderWidth,
                    color: element.style.borderColor.withOpacity(
                        element.style.borderOpacity
                    ),
                    context: context
                )
            }
        }
    }

    // MARK: - Icon

    private static func drawIcon(
        _ element: OverlayElement,
        context: OpaquePointer,
        renderContext: OverlayRenderContext
    ) {
        let layout = OverlayRenderModel.decorIconLayout(
            for: element,
            in: renderContext
        )
        let origin = centeredOrigin(
            for: element,
            size: layout.size,
            renderContext: renderContext
        )
        let rect = CGRect(origin: origin, size: layout.size)

        SkiaTextEffects.withElementLayers(
            element: element,
            bounds: rect,
            context: context,
            entries: decorShadowEntries(for: element)
        ) {
            SkiaIconRasterCache.draw(
                asset: layout.iconAsset,
                rect: rect,
                tint: layout.iconTint,
                preserveSVGColors: layout.iconPreserveSVGColors,
                contentMode: layout.iconContentMode,
                opacity: 1,
                context: context
            )
            if element.style.borderEnabled {
                skb_stroke_round_rect(
                    context,
                    Float(rect.minX),
                    Float(rect.minY),
                    Float(rect.width),
                    Float(rect.height),
                    0,
                    Float(element.style.borderWidth),
                    Float(element.style.borderColor.red),
                    Float(element.style.borderColor.green),
                    Float(element.style.borderColor.blue),
                    Float(
                        element.style.borderColor.alpha
                            * element.style.borderOpacity
                    )
                )
            }
        }
    }

    // MARK: - Text

    private static func drawText(
        _ element: OverlayElement,
        context: OpaquePointer,
        renderContext: OverlayRenderContext
    ) {
        let layout = OverlayRenderModel.decorTextLayout(
            for: element,
            in: renderContext
        )
        let origin = centeredOrigin(
            for: element,
            size: layout.size,
            renderContext: renderContext
        )
        let rect = CGRect(origin: origin, size: layout.size)

        SkiaTextEffects.withElementLayers(
            element: element,
            bounds: rect,
            context: context,
            entries: decorShadowEntries(for: element)
        ) {
            if let bitmap = DecorTextRasterCache.bitmap(for: layout),
               let pointer = bitmap.pointer {
                skb_draw_image_handle(
                    context,
                    pointer,
                    Float(rect.minX),
                    Float(rect.minY),
                    Float(rect.width),
                    Float(rect.height),
                    1,
                    0, 0, 0, 0
                )
            }
            if element.style.borderEnabled {
                skb_stroke_round_rect(
                    context,
                    Float(rect.minX),
                    Float(rect.minY),
                    Float(rect.width),
                    Float(rect.height),
                    0,
                    Float(element.style.borderWidth),
                    Float(element.style.borderColor.red),
                    Float(element.style.borderColor.green),
                    Float(element.style.borderColor.blue),
                    Float(
                        element.style.borderColor.alpha
                            * element.style.borderOpacity
                    )
                )
            }
        }
    }

    // MARK: - Geometry

    private static func centeredOrigin(
        for element: OverlayElement,
        size: CGSize,
        renderContext: OverlayRenderContext
    ) -> CGPoint {
        CGPoint(
            x: renderContext.canvasSize.width * element.position.x - size.width / 2,
            y: renderContext.canvasSize.height * element.position.y - size.height / 2
        )
    }

    private static func fillShape(
        _ shape: DecorShape,
        rect: CGRect,
        cornerRadius: Double,
        color: OverlayColor,
        context: OpaquePointer
    ) {
        switch shape {
        case .rectangle:
            skb_fill_rect(
                context,
                Float(rect.minX),
                Float(rect.minY),
                Float(rect.width),
                Float(rect.height),
                Float(color.red),
                Float(color.green),
                Float(color.blue),
                Float(color.alpha)
            )
        case .roundedRectangle:
            skb_fill_round_rect(
                context,
                Float(rect.minX),
                Float(rect.minY),
                Float(rect.width),
                Float(rect.height),
                Float(cornerRadius),
                Float(color.red),
                Float(color.green),
                Float(color.blue),
                Float(color.alpha)
            )
        case .circle:
            skb_fill_circle(
                context,
                Float(rect.midX),
                Float(rect.midY),
                Float(min(rect.width, rect.height) / 2),
                Float(color.red),
                Float(color.green),
                Float(color.blue),
                Float(color.alpha)
            )
        case .capsule:
            skb_fill_round_rect(
                context,
                Float(rect.minX),
                Float(rect.minY),
                Float(rect.width),
                Float(rect.height),
                Float(min(rect.width, rect.height) / 2),
                Float(color.red),
                Float(color.green),
                Float(color.blue),
                Float(color.alpha)
            )
        }
    }

    private static func strokeShape(
        _ shape: DecorShape,
        rect: CGRect,
        cornerRadius: Double,
        width: Double,
        color: OverlayColor,
        context: OpaquePointer
    ) {
        let radius: Double
        switch shape {
        case .rectangle:
            radius = 0
        case .roundedRectangle:
            radius = cornerRadius
        case .circle, .capsule:
            radius = min(rect.width, rect.height) / 2
        }
        skb_stroke_round_rect(
            context,
            Float(rect.minX),
            Float(rect.minY),
            Float(rect.width),
            Float(rect.height),
            Float(radius),
            Float(width),
            Float(color.red),
            Float(color.green),
            Float(color.blue),
            Float(color.alpha)
        )
    }

    /// Decor views apply two glow shadows and one shadow (no thickness chain).
    private static func decorShadowEntries(
        for element: OverlayElement
    ) -> [SkiaShadowEntry] {
        let style = element.style
        var entries: [SkiaShadowEntry] = []
        if style.glowEnabled {
            entries.append(
                SkiaShadowEntry(
                    sigma: max(style.glowIntensity * 18, 0),
                    dx: 0,
                    dy: 0,
                    color: style.glowColor,
                    alpha: style.glowIntensity * 0.72
                )
            )
            entries.append(
                SkiaShadowEntry(
                    sigma: max(style.glowIntensity * 34, 0),
                    dx: 0,
                    dy: 0,
                    color: style.glowColor,
                    alpha: style.glowIntensity * 0.35
                )
            )
        }
        if style.shadowEnabled, style.shadowOpacity > 0 {
            entries.append(
                SkiaShadowEntry(
                    sigma: style.shadowRadius,
                    dx: style.shadowOffsetX,
                    dy: style.shadowOffsetY,
                    color: style.shadowColor,
                    alpha: style.shadowOpacity
                )
            )
        }
        return entries.filter { $0.alpha > 0.0001 && $0.sigma >= 0 }
    }
}

// MARK: - Decor text raster cache

/// D5: rasterize decor text through AppKit into a cached BGRA image. This
/// reproduces SwiftUI's multiline layout, paragraph alignment, line spacing,
/// tracking, and the scaled stroke layer without needing a glyph-stroke
/// primitive.
private enum DecorTextRasterCache {
    final class Bitmap {
        let pointer: OpaquePointer?

        init(pointer: OpaquePointer?) {
            self.pointer = pointer
        }

        deinit {
            if let pointer {
                skb_image_destroy(pointer)
            }
        }
    }

    /// `NSCache` is thread-safe internally; export and preview can rasterize
    /// decor text from different threads. Keys quantize the scale-dependent
    /// metrics so a continuous scale drag reuses one bitmap per bucket instead
    /// of rasterizing every frame; the caps bound retained memory.
    nonisolated(unsafe) private static let cache: NSCache<NSString, Bitmap> = {
        let cache = NSCache<NSString, Bitmap>()
        cache.countLimit = 32
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()

    private static let sizeStep = 4.0
    private static let fontSizeStep = 1.0
    private static let metricStep = 0.5

    /// Bucket index, not a rounded value: `Int(step)` would truncate a
    /// fractional step (0.5) to zero and collapse every metric into one key.
    private static func quantized(_ value: Double, step: Double) -> Int {
        max(Int((value / step).rounded(.up)), 1)
    }

    /// Tracking can be negative, so round to the nearest bucket and keep the
    /// sign instead of clamping at 1.
    private static func quantizedSigned(_ value: Double, step: Double) -> Int {
        Int((value / step).rounded())
    }

    static func bitmap(for layout: DecorTextRenderLayout) -> Bitmap? {
        let key = cacheKey(for: layout) as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let width = max(Int(layout.size.width.rounded(.up)), 1)
        let height = max(Int(layout.size.height.rounded(.up)), 1)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        var rendered = false
        pixels.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue
            ) else {
                return
            }
            ctx.clear(CGRect(x: 0, y: 0, width: width, height: height))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(
                cgContext: ctx,
                flipped: false
            )
            draw(layout, in: ctx, width: Double(width), height: Double(height))
            NSGraphicsContext.restoreGraphicsState()
            rendered = true
        }
        guard rendered else { return nil }
        let pointer = pixels.withUnsafeBufferPointer { buffer in
            skb_image_create(buffer.baseAddress, Int32(width), Int32(height))
        }
        let bitmap = Bitmap(pointer: pointer)
        cache.setObject(
            bitmap,
            forKey: key,
            cost: width * height * 4
        )
        return bitmap
    }

    private static func draw(
        _ layout: DecorTextRenderLayout,
        in ctx: CGContext,
        width: Double,
        height: Double
    ) {
        let font = resolvedFont(layout)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = nsAlignment(layout.alignment)
        paragraph.lineSpacing = max(0, (layout.lineHeight - 1) * layout.fontSize)

        let tracking = layout.letterSpacing / max(layout.fontSize, 1)
        let fillColor = nsColor(layout.fillMode)
        let attributed = NSAttributedString(
            string: layout.content,
            attributes: [
                .font: font,
                .foregroundColor: fillColor,
                .paragraphStyle: paragraph,
                .kern: tracking
            ]
        )

        let measured = attributed.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let textHeight = max(ceil(measured.height), 1)
        let drawRect = CGRect(
            x: 0,
            y: (height - textHeight) / 2,
            width: width,
            height: textHeight
        )

        if layout.strokeWidth > 0 {
            let scale = 1 + layout.strokeWidth / max(layout.fontSize, 1) * 0.5
            var strokeAttributes = attributed.attributes(
                at: 0,
                effectiveRange: nil
            )
            strokeAttributes[.foregroundColor] = nsColor(layout.strokeColor)
            let strokeText = NSAttributedString(
                string: layout.content,
                attributes: strokeAttributes
            )
            ctx.saveGState()
            ctx.translateBy(x: width / 2, y: height / 2)
            ctx.scaleBy(x: scale, y: scale)
            ctx.translateBy(x: -width / 2, y: -height / 2)
            strokeText.draw(in: drawRect)
            ctx.restoreGState()
        }

        attributed.draw(in: drawRect)
    }

    private static func resolvedFont(_ layout: DecorTextRenderLayout) -> NSFont {
        switch layout.font {
        case .bundled(let name):
            return NSFont(name: name, size: layout.fontSize)
                ?? NSFont.systemFont(ofSize: layout.fontSize)
        case .system(let family):
            return OverlayFontResolver.appKitFont(
                family: family,
                size: layout.fontSize,
                weight: .regular
            )
        case .userAsset:
            return NSFont.systemFont(ofSize: layout.fontSize)
        }
    }

    private static func nsAlignment(_ alignment: DecorTextAlignment) -> NSTextAlignment {
        switch alignment {
        case .leading: .left
        case .center: .center
        case .trailing: .right
        }
    }

    private static func nsColor(_ fill: DecorTextFill) -> NSColor {
        switch fill {
        case .solid(let color):
            return nsColor(color)
        case .gradient:
            // Phase F6 placeholder in the SwiftUI view: gradient fill is white.
            return .white
        }
    }

    private static func nsColor(_ color: OverlayColor) -> NSColor {
        NSColor(
            red: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha
        )
    }

    private static func cacheKey(for layout: DecorTextRenderLayout) -> String {
        "\(layout.content)|\(String(describing: layout.font))|"
            + "\(quantized(layout.fontSize, step: fontSizeStep))|"
            + "\(layout.alignment)|\(layout.lineHeight)|"
            + "\(quantizedSigned(layout.letterSpacing, step: metricStep))|"
            + "\(fillKey(layout.fillMode))|"
            + "\(quantized(layout.strokeWidth, step: metricStep))|"
            + "\(String(describing: layout.strokeColor))|"
            + "\(quantized(layout.size.width, step: sizeStep))x"
            + "\(quantized(layout.size.height, step: sizeStep))"
    }

    private static func fillKey(_ fill: DecorTextFill) -> String {
        switch fill {
        case .solid(let color):
            return "solid:\(color.red),\(color.green),\(color.blue),\(color.alpha)"
        case .gradient:
            return "gradient"
        }
    }
}

#endif
