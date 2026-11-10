#if canImport(CSkiaBridge)
import CoreGraphics
import CSkiaBridge
import Foundation
import ImageIO

/// Decodes component image assets once per asset digest and keeps the
/// resulting `SkiaBridgeImage` handle for reuse across frames.
///
/// Preview and export can resolve components from different threads, so the
/// cache uses `NSCache` (internally thread-safe). Decoding is synchronous and
/// local; no network or async work happens during a frame.
enum OverlayComponentImageCache {
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

    nonisolated(unsafe) private static let cache: NSCache<NSString, BitmapHandle> = {
        let cache = NSCache<NSString, BitmapHandle>()
        cache.countLimit = 32
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    /// Longest decoded edge. Component frames are design units and rarely need
    /// more; the cap bounds memory for oversized imported images.
    private static let maximumPixelEdge = 4096

    static func draw(
        assetPath: String,
        assets: [String: Data],
        rect: CGRect,
        fit: OverlayComponentImageFit,
        opacity: Double,
        context: OpaquePointer
    ) {
        guard rect.width > 0.5, rect.height > 0.5, opacity > 0.001,
              let data = assets[assetPath] else {
            return
        }
        let key = OverlayComponentDigest.sha256(of: data) as NSString
        guard let bitmap = bitmap(for: key, data: data),
              let pointer = bitmap.pointer else {
            return
        }
        let destination = destinationRect(
            intrinsic: bitmap.pixelSize,
            in: rect,
            fit: fit
        )
        skb_draw_image_handle(
            context,
            pointer,
            Float(destination.minX),
            Float(destination.minY),
            Float(destination.width),
            Float(destination.height),
            Float(opacity),
            0, 0, 0, 0
        )
    }

    private static func destinationRect(
        intrinsic: CGSize,
        in rect: CGRect,
        fit: OverlayComponentImageFit
    ) -> CGRect {
        guard intrinsic.width > 0, intrinsic.height > 0 else { return rect }
        let horizontal = rect.width / intrinsic.width
        let vertical = rect.height / intrinsic.height
        let scale = fit == .fill ? max(horizontal, vertical) : min(horizontal, vertical)
        let size = CGSize(width: intrinsic.width * scale, height: intrinsic.height * scale)
        return CGRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private static func bitmap(for key: NSString, data: Data) -> BitmapHandle? {
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        let longest = max(width, height)
        let divisor = longest > maximumPixelEdge
            ? Double(longest) / Double(maximumPixelEdge)
            : 1
        let pixelWidth = max(Int((Double(width) / divisor).rounded()), 1)
        let pixelHeight = max(Int((Double(height) / divisor).rounded()), 1)
        guard let pointer = SkiaRenderAssets.imageHandle(
            from: image,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            alphaFromLuminance: false
        ) else {
            return nil
        }
        let handle = BitmapHandle(
            pointer: pointer,
            pixelSize: CGSize(width: pixelWidth, height: pixelHeight)
        )
        cache.setObject(handle, forKey: key, cost: pixelWidth * pixelHeight * 4)
        return handle
    }

    /// Test hook: drops decoded images.
    static func clearCache() {
        cache.removeAllObjects()
    }
}
#endif
