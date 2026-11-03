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
    /// icons from different threads.
    nonisolated(unsafe) private static let cache = NSCache<NSString, BitmapHandle>()

    static func draw(
        systemName: String,
        rect: CGRect,
        color: OverlayColor,
        opacity: Double,
        context: OpaquePointer
    ) {
        guard rect.width > 0, rect.height > 0, opacity > 0.001 else { return }
        let key = "symbol|\(systemName)|\(rect.width)x\(rect.height)|\(color.red),\(color.green),\(color.blue)" as NSString
        guard let bitmap = bitmap(for: key, size: rect.size, draw: { ctx in
            drawSymbol(
                name: systemName,
                rect: CGRect(origin: .zero, size: rect.size),
                color: color,
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
        let key = "asset|\(String(describing: asset))|\(rect.width)x\(rect.height)|"
            + "\(tint.red),\(tint.green),\(tint.blue)|\(preserveSVGColors)|\(contentMode)" as NSString
        guard let bitmap = bitmap(for: key, size: rect.size, draw: { ctx in
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
        cache.setObject(handle, forKey: key)
        return handle
    }

    /// Numeric overlay icon: `Image(systemName:).font(.system(size:weight:.medium))`
    /// inside an `iconSize × iconSize` frame.
    private static func drawSymbol(
        name: String,
        rect: CGRect,
        color: OverlayColor,
        in ctx: CGContext
    ) {
        let pointSize = rect.width
        let configuration = NSImage.SymbolConfiguration(
            pointSize: pointSize,
            weight: .medium
        )
        guard let base = NSImage(
            systemSymbolName: name,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(configuration) else {
            return
        }
        let tinted = NSImage(size: base.size, flipped: false) { drawRect in
            NSColor(
                red: color.red,
                green: color.green,
                blue: color.blue,
                alpha: 1
            ).set()
            drawRect.fill()
            base.draw(
                in: drawRect,
                from: .zero,
                operation: .destinationIn,
                fraction: 1
            )
            return true
        }
        let target = CGRect(
            x: rect.midX - base.size.width / 2,
            y: rect.midY - base.size.height / 2,
            width: base.size.width,
            height: base.size.height
        )
        tinted.draw(
            in: target,
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
    }
}
#endif
