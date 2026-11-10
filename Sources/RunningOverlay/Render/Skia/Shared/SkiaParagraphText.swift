#if canImport(CSkiaBridge)
import AppKit
import CoreGraphics
import CSkiaBridge
import Foundation

/// AppKit paragraph rasterization for component richText.
///
/// AppKit reproduces multiline layout, paragraph alignment, line spacing,
/// tracking, and the scaled stroke layer without needing a glyph-stroke
/// primitive. Tracking is an extra glyph advance in pixels.
struct SkiaParagraphTextLayout {
    var size: CGSize
    var content: String
    var font: NSFont
    var alignment: NSTextAlignment
    var lineHeight: Double
    var tracking: Double
    var color: OverlayColor
    var gradient: OverlayComponentResolvedTextGradient?
    var strokeWidth: Double
    var strokeColor: OverlayColor
    var autoFit: Bool
}

enum SkiaParagraphTextRasterCache {
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
    /// paragraph text from different threads. Exact keys preserve deterministic
    /// output across scale changes; count and cost limits bound retained memory.
    nonisolated(unsafe) private static let cache: NSCache<NSString, Bitmap> = {
        let cache = NSCache<NSString, Bitmap>()
        cache.countLimit = 32
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()

    static func bitmap(for layout: SkiaParagraphTextLayout) -> Bitmap? {
        guard !layout.content.isEmpty, layout.size.width.isFinite, layout.size.height.isFinite,
              layout.size.width > 0, layout.size.height > 0,
              layout.size.width <= 16384, layout.size.height <= 16384,
              layout.size.width * layout.size.height <= 16_777_216 else { return nil }
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
        _ layout: SkiaParagraphTextLayout,
        in ctx: CGContext,
        width: Double,
        height: Double
    ) {
        let fontSize = fittedFontSize(for: layout, width: width, height: height)
        let attributed = attributedText(layout, fontSize: fontSize)

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
            let scale = 1 + layout.strokeWidth / max(fontSize, 1) * 0.5
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

        if let gradient = layout.gradient {
            // Isolate the glyph mask so the gradient does not recolor stroke.
            ctx.saveGState()
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            attributed.draw(in: drawRect)
            ctx.setBlendMode(.sourceIn)
            let colors = gradient.stops.map { nsColor($0.color).cgColor } as CFArray
            let locations = gradient.stops.map { CGFloat($0.offset) }
            if let paint = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
                ctx.drawLinearGradient(
                    paint,
                    start: CGPoint(x: gradient.from.x, y: height - gradient.from.y),
                    end: CGPoint(x: gradient.to.x, y: height - gradient.to.y),
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
            }
            ctx.endTransparencyLayer()
            ctx.restoreGState()
        } else {
            attributed.draw(in: drawRect)
        }
    }

    private static func attributedText(_ layout: SkiaParagraphTextLayout, fontSize: Double) -> NSAttributedString {
        let font = NSFont(descriptor: layout.font.fontDescriptor, size: fontSize) ?? layout.font
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = layout.alignment
        paragraph.lineSpacing = max(0, (layout.lineHeight - 1) * fontSize)
        return NSAttributedString(string: layout.content, attributes: [
            .font: font,
            .foregroundColor: nsColor(layout.gradient == nil ? layout.color : .white),
            .paragraphStyle: paragraph,
            .kern: layout.tracking * fontSize / max(layout.font.pointSize, 1)
        ])
    }

    /// Bounded shrink-only search. AppKit measures wrapping and font leading
    /// using the same attributes as the final draw.
    static func fittedFontSize(for layout: SkiaParagraphTextLayout, width: Double, height: Double) -> Double {
        let requested = layout.font.pointSize
        guard layout.autoFit else { return requested }
        func fits(_ size: Double) -> Bool {
            let text = attributedText(layout, fontSize: size)
            let bounds = text.boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            return ceil(bounds.height) <= height && ceil(bounds.width) <= width
        }
        guard !fits(requested) else { return requested }
        var low = min(1, requested)
        var high = requested
        for _ in 0..<12 {
            let mid = (low + high) / 2
            if fits(mid) { low = mid } else { high = mid }
        }
        return low
    }

    private static func nsColor(_ color: OverlayColor) -> NSColor {
        NSColor(
            red: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha
        )
    }

    private static func cacheKey(for layout: SkiaParagraphTextLayout) -> String {
        // Exact metrics keep output independent of which preview scale first
        // populated the cache. NSCache's cost and count limits bound retention.
        String(reflecting: [
            layout.content, layout.font.fontName, "\(layout.font.pointSize)",
            "\(layout.font.fontDescriptor.symbolicTraits.rawValue)",
            "\(layout.size.width)", "\(layout.size.height)", "\(layout.alignment.rawValue)",
            "\(layout.lineHeight)", "\(layout.tracking)", String(reflecting: layout.color),
            String(reflecting: layout.gradient), "\(layout.strokeWidth)",
            String(reflecting: layout.strokeColor), "\(layout.autoFit)"
        ])
    }
}

#endif
