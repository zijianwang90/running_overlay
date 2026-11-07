#if canImport(CSkiaBridge)
import AppKit
import CoreGraphics
import CSkiaBridge
import Foundation

/// Rasterizes SF Symbols and decor icon assets once per (asset, size, tint)
/// and draws them through a cached `SkiaBridgeImage` handle. All work is
/// synchronous and local; no network or async asset loading happens during a
/// frame.
enum SkiaIconRasterCache {
    private final class BitmapHandle {
        let pointer: OpaquePointer?
        let pixelSize: CGSize

        init(pointer: OpaquePointer?, pixelSize: CGSize) {
            self.pointer = pointer
            self.pixelSize = pixelSize
        }

        deinit {
            if let pointer {
                skb_image_destroy(pointer)
            }
        }
    }

    /// `NSCache` is thread-safe internally; export and preview can rasterize
    /// icons from different threads. The count/cost caps bound memory when a
    /// user drags scale or color; keys quantize size so continuous drags reuse
    /// the bitmap for a whole pixel bucket instead of rasterizing every frame.
    nonisolated(unsafe) private static let cache: NSCache<NSString, BitmapHandle> = {
        let cache = NSCache<NSString, BitmapHandle>()
        cache.countLimit = 64
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()

    private static let rasterStep = 4.0

    private static func quantized(_ value: Double) -> Int {
        max(Int((value / rasterStep).rounded(.up)) * Int(rasterStep), 1)
    }

    static func draw(
        systemName: String,
        rect: CGRect,
        color: OverlayColor,
        opacity: Double,
        weight: NSFont.Weight = .medium,
        context: OpaquePointer
    ) {
        guard rect.width > 0, rect.height > 0, opacity > 0.001 else { return }
        let key = "symbol|\(systemName)|\(weight.rawValue)|"
            + "\(quantized(rect.width))x\(quantized(rect.height))|"
            + "\(color.red),\(color.green),\(color.blue)" as NSString
        guard let bitmap = bitmap(for: key, size: rect.size, draw: { ctx in
            drawSymbol(
                name: systemName,
                rect: CGRect(origin: .zero, size: rect.size),
                color: color,
                weight: weight,
                in: ctx
            )
        }) else {
            return
        }
        drawHandle(bitmap, rect: rect, opacity: opacity, context: context)
    }

    static func draw(
        asset: IconAsset,
        rect: CGRect,
        tint: OverlayColor,
        preserveSVGColors: Bool,
        contentMode: IconContentMode,
        opacity: Double,
        context: OpaquePointer
    ) {
        guard rect.width > 0, rect.height > 0, opacity > 0.001 else { return }
        let key = "asset|\(String(describing: asset))|"
            + "\(quantized(rect.width))x\(quantized(rect.height))|"
            + "\(tint.red),\(tint.green),\(tint.blue)|\(preserveSVGColors)|\(contentMode)" as NSString
        guard let bitmap = bitmap(for: key, size: rect.size, draw: { ctx in
            if case .sfSymbol(let name, let weight, let scale) = asset {
                // Draw the tinted symbol directly instead of compositing a
                // tint fill with `.destinationIn`: the fill leaves a faint
                // full-height line at the rasterized image's boundary, which
                // becomes visible when the icon is scaled up.
                drawAssetSymbol(
                    name: name,
                    weight: weight,
                    scale: scale,
                    rect: CGRect(origin: .zero, size: rect.size),
                    color: tint,
                    in: ctx
                )
                return
            }
            IconRenderer.draw(
                IconRenderRequest(
                    asset: asset,
                    rect: CGRect(origin: .zero, size: rect.size),
                    tint: NSColor(
                        red: tint.red,
                        green: tint.green,
                        blue: tint.blue,
                        alpha: tint.alpha
                    ),
                    preserveSVGColors: preserveSVGColors,
                    contentMode: contentMode
                ),
                in: ctx
            )
        }) else {
            return
        }
        drawHandle(bitmap, rect: rect, opacity: opacity, context: context)
    }

    private static func drawHandle(
        _ bitmap: BitmapHandle,
        rect: CGRect,
        opacity: Double,
        context: OpaquePointer
    ) {
        guard let pointer = bitmap.pointer else { return }
        skb_draw_image_handle(
            context,
            pointer,
            Float(rect.minX),
            Float(rect.minY),
            Float(rect.width),
            Float(rect.height),
            Float(opacity),
            0, 0, 0, 0
        )
    }

    private static func bitmap(
        for key: NSString,
        size: CGSize,
        draw: (CGContext) -> Void
    ) -> BitmapHandle? {
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let width = max(Int(size.width.rounded(.up)), 1)
        let height = max(Int(size.height.rounded(.up)), 1)
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
            draw(ctx)
            NSGraphicsContext.restoreGraphicsState()
            rendered = true
        }
        guard rendered else { return nil }
        let pointer = pixels.withUnsafeBufferPointer { buffer in
            skb_image_create(buffer.baseAddress, Int32(width), Int32(height))
        }
        let handle = BitmapHandle(
            pointer: pointer,
            pixelSize: CGSize(width: width, height: height)
        )
        cache.setObject(handle, forKey: key, cost: width * height * 4)
        return handle
    }

    /// Numeric overlay icon: `Image(systemName:).font(.system(size:weight:.medium))`
    /// inside an `iconSize × iconSize` frame. Component `symbol` nodes reuse it
    /// with their own weight.
    private static func drawSymbol(
        name: String,
        rect: CGRect,
        color: OverlayColor,
        weight: NSFont.Weight,
        in ctx: CGContext
    ) {
        let pointSize = rect.width
        guard let image = tintedSymbol(
            name: name,
            pointSize: pointSize,
            weight: weight,
            scale: nil,
            color: color
        ) else {
            return
        }
        let target = CGRect(
            x: rect.midX - image.size.width / 2,
            y: rect.midY - image.size.height / 2,
            width: image.size.width,
            height: image.size.height
        )
        image.draw(
            in: target,
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
    }

    /// Decor icon: mirrors `IconRenderer.drawSFSymbol`'s point size and
    /// aspect-fit placement, with a palette-tinted symbol image.
    private static func drawAssetSymbol(
        name: String,
        weight: SymbolWeight,
        scale: SymbolScale,
        rect: CGRect,
        color: OverlayColor,
        in ctx: CGContext
    ) {
        let pointSize = min(rect.width, rect.height) * 0.92
        guard let image = tintedSymbol(
            name: name,
            pointSize: pointSize,
            weight: weight.nsFontWeight,
            scale: scale.nsSymbolScale,
            color: color
        ) else {
            return
        }
        let target = IconRenderer.aspectFitRect(
            intrinsicSize: image.size,
            in: rect,
            mode: .fit
        )
        image.draw(
            in: target,
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
    }

    /// `NSImage` palette tinting keeps the symbol's own antialiased mask, so
    /// no fill/`.destinationIn` edge remains in the rasterized bitmap.
    private static func tintedSymbol(
        name: String,
        pointSize: Double,
        weight: NSFont.Weight,
        scale: NSImage.SymbolScale?,
        color: OverlayColor
    ) -> NSImage? {
        var configuration = NSImage.SymbolConfiguration(
            pointSize: pointSize,
            weight: weight
        )
        if let scale {
            configuration = configuration.applying(.init(scale: scale))
        }
        configuration = configuration.applying(
            .init(
                paletteColors: [
                    NSColor(
                        red: color.red,
                        green: color.green,
                        blue: color.blue,
                        alpha: color.alpha
                    )
                ]
            )
        )
        return NSImage(
            systemSymbolName: name,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(configuration)
    }
}
#endif
