#if canImport(CSkiaBridge)
import AppKit
import CoreGraphics
import CSkiaBridge
import Foundation

extension OverlayColor {
    /// Returns the color with its alpha multiplied by `opacity`. Mirrors
    /// SwiftUI's `Color(...).opacity(...)` without changing RGB.
    func withOpacity(_ opacity: Double) -> OverlayColor {
        var copy = self
        copy.alpha *= opacity
        return copy
    }
}

struct SkiaShadowEntry {
    var sigma: Double
    var dx: Double
    var dy: Double
    var color: OverlayColor
    var alpha: Double
}

/// Element-level effects shared by text and decor modules.
///
/// SwiftUI applies the preset's background, content, and border first, then
/// the glow and layered shadow, then the host applies `element.opacity`. This
/// helper reproduces that order with `skb_begin_shadow_chain` and
/// `skb_begin_opacity_layer`.
enum SkiaTextEffects {
    static func withElementLayers(
        element: OverlayElement,
        bounds: CGRect,
        context: OpaquePointer,
        entries: [SkiaShadowEntry]? = nil,
        _ body: () -> Void
    ) {
        let opacity = element.opacity
        let entries = entries ?? shadowEntries(for: element)
        let padding = effectPadding(entries: entries)
        let layerBounds = bounds.insetBy(dx: -padding, dy: -padding)

        if opacity < 0.999 {
            skb_begin_opacity_layer(
                context,
                Float(opacity),
                Float(layerBounds.minX),
                Float(layerBounds.minY),
                Float(layerBounds.width),
                Float(layerBounds.height)
            )
        }

        if entries.isEmpty {
            skb_save(context)
        } else {
            let sigmas = entries.map { Float($0.sigma) }
            let dxs = entries.map { Float($0.dx) }
            let dys = entries.map { Float($0.dy) }
            var rgba: [Float] = []
            rgba.reserveCapacity(entries.count * 4)
            for entry in entries {
                rgba.append(Float(entry.color.red))
                rgba.append(Float(entry.color.green))
                rgba.append(Float(entry.color.blue))
                rgba.append(Float(entry.alpha * entry.color.alpha))
            }
            sigmas.withUnsafeBufferPointer { sigmas in
                dxs.withUnsafeBufferPointer { dxs in
                    dys.withUnsafeBufferPointer { dys in
                        rgba.withUnsafeBufferPointer { rgba in
                            skb_begin_shadow_chain(
                                context,
                                Int32(entries.count),
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
        }

        body()

        skb_restore(context)
        if opacity < 0.999 {
            skb_restore(context)
        }
    }

    /// Matches `overlayForegroundEffects`: glow is applied before the layered
    /// shadow, so glow entries are innermost.
    static func shadowEntries(for element: OverlayElement) -> [SkiaShadowEntry] {
        let style = element.style
        var entries: [SkiaShadowEntry] = []

        if style.glowEnabled {
            let intensity = style.glowIntensity
            entries.append(
                SkiaShadowEntry(
                    sigma: max(intensity * 18, 0),
                    dx: 0,
                    dy: 0,
                    color: style.glowColor,
                    alpha: intensity * 0.72
                )
            )
            entries.append(
                SkiaShadowEntry(
                    sigma: max(intensity * 34, 0),
                    dx: 0,
                    dy: 0,
                    color: style.glowColor,
                    alpha: intensity * 0.35
                )
            )
        }

        if style.shadowEnabled, style.shadowOpacity > 0 {
            let radius = style.shadowRadius
            let opacity = style.shadowOpacity
            let thickness = style.shadowThickness
            entries.append(
                SkiaShadowEntry(
                    sigma: radius,
                    dx: style.shadowOffsetX,
                    dy: style.shadowOffsetY,
                    color: style.shadowColor,
                    alpha: opacity
                )
            )
            if thickness > 1 {
                entries.append(
                    SkiaShadowEntry(
                        sigma: radius * 0.72,
                        dx: style.shadowOffsetX,
                        dy: style.shadowOffsetY,
                        color: style.shadowColor,
                        alpha: opacity * (thickness - 1) * 0.32
                    )
                )
            }
            if thickness > 2 {
                entries.append(
                    SkiaShadowEntry(
                        sigma: radius * 0.48,
                        dx: style.shadowOffsetX,
                        dy: style.shadowOffsetY,
                        color: style.shadowColor,
                        alpha: opacity * (thickness - 2) * 0.22
                    )
                )
            }
        }

        return entries.filter { $0.alpha > 0.0001 && $0.sigma >= 0 }
    }

    static func effectPadding(entries: [SkiaShadowEntry]) -> Double {
        entries.reduce(0) { result, entry in
            max(
                result,
                entry.sigma * 3 + max(abs(entry.dx), abs(entry.dy))
            )
        }
    }

    static func drawBorder(
        element: OverlayElement,
        bounds: CGRect,
        cornerRadius: Double,
        context: OpaquePointer
    ) {
        guard element.style.borderEnabled else { return }
        let color = element.style.borderColor
        skb_stroke_round_rect(
            context,
            Float(bounds.minX),
            Float(bounds.minY),
            Float(bounds.width),
            Float(bounds.height),
            Float(cornerRadius),
            Float(element.style.borderWidth),
            Float(color.red),
            Float(color.green),
            Float(color.blue),
            Float(color.alpha * element.style.borderOpacity)
        )
    }

    /// Solid or feathered background fill.
    ///
    /// `backgroundFadeOutEnabled` uses the same distance-field mask as the
    /// SwiftUI view. `backgroundBlurRadius` has no backdrop in export; the
    /// SwiftUI oracle falls back to a near-white material fill on a
    /// transparent canvas, reproduced here with the measured alpha curve.
    static func drawBackground(
        element: OverlayElement,
        rect: CGRect,
        cornerRadius: Double,
        context: OpaquePointer
    ) {
        guard element.style.backgroundEnabled else { return }
        let style = element.style
        let color = style.backgroundColor
        let opacity = style.backgroundOpacity
        let fadeEnabled = style.backgroundFadeOutEnabled
            && style.backgroundFadeOutAmount > 0.001

        if fadeEnabled {
            guard let mask = maskImage(
                size: rect.size,
                cornerRadius: cornerRadius,
                fadeAmount: style.backgroundFadeOutAmount
            ) else {
                return
            }
            skb_save(context)
            drawBackgroundFills(
                color: color,
                opacity: opacity,
                blurRadius: style.backgroundBlurRadius,
                rect: rect,
                cornerRadius: cornerRadius,
                context: context
            )
            // NSCache may evict its entry at any time. Keep the owning handle
            // alive through the bridge draw rather than borrowing a raw pointer.
            withExtendedLifetime(mask) {
                skb_draw_image_dst_in(
                    context,
                    mask.pointer,
                    Float(rect.minX),
                    Float(rect.minY),
                    Float(rect.width),
                    Float(rect.height)
                )
            }
            skb_restore(context)
        } else {
            drawBackgroundFills(
                color: color,
                opacity: opacity,
                blurRadius: style.backgroundBlurRadius,
                rect: rect,
                cornerRadius: cornerRadius,
                context: context
            )
        }
    }

    private static func drawBackgroundFills(
        color: OverlayColor,
        opacity: Double,
        blurRadius: Double,
        rect: CGRect,
        cornerRadius: Double,
        context: OpaquePointer
    ) {
        if blurRadius > 0.01 {
            let materialOpacity = min(max(blurRadius / 24, 0), 1)
            // Measured ImageRenderer fallback: .ultraThinMaterial over a
            // transparent canvas resolves to a near-white fill (~244/255) and
            // this alpha curve as `.opacity(0…1)` increases. The curve is
            // sampled from the shipping oracle at 1/24 steps and interpolated.
            let alpha = materialFallbackAlpha(for: materialOpacity)
            skb_fill_round_rect(
                context,
                Float(rect.minX),
                Float(rect.minY),
                Float(rect.width),
                Float(rect.height),
                Float(cornerRadius),
                Float(Self.materialFallbackRed),
                Float(Self.materialFallbackRed),
                Float(Self.materialFallbackRed),
                Float(alpha)
            )
        }
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
            Float(color.alpha * opacity)
        )
    }

    /// Measured from `ImageRenderer` on a transparent canvas. Dark-appearance
    /// material fallback is documented as a known divergence; export does not
    /// set a color scheme.
    private static let materialFallbackRed = 244.0 / 255.0

    /// Alpha of the `.ultraThinMaterial` fallback for opacity steps of 1/24,
    /// measured from the SwiftUI oracle (indices 0…24, index = opacity * 24).
    /// Values above 16/24 are opaque.
    private static let materialFallbackAlphas: [Double] = [
        0,
        32.0 / 255.0,
        61.0 / 255.0,
        89.0 / 255.0,
        114.0 / 255.0,
        137.0 / 255.0,
        158.0 / 255.0,
        177.0 / 255.0,
        193.0 / 255.0,
        207.0 / 255.0,
        220.0 / 255.0,
        231.0 / 255.0,
        240.0 / 255.0,
        246.0 / 255.0,
        251.0 / 255.0,
        254.0 / 255.0,
        1
    ]

    private static func materialFallbackAlpha(for opacity: Double) -> Double {
        let clamped = min(max(opacity, 0), 1)
        let scaled = clamped * 24
        let lower = min(Int(scaled), 16)
        let upper = min(lower + 1, 16)
        let fraction = scaled - Double(lower)
        return materialFallbackAlphas[lower]
            + (materialFallbackAlphas[upper] - materialFallbackAlphas[lower])
                * fraction
    }

    // MARK: - Feathered mask cache

    final class MaskHandle {
        let pointer: OpaquePointer

        init(pointer: OpaquePointer) {
            self.pointer = pointer
        }

        deinit { skb_image_destroy(pointer) }
    }

    /// `NSCache` is thread-safe internally; export and preview can build
    /// masks from different threads.
    nonisolated(unsafe) private static let maskCache = NSCache<NSString, MaskHandle>()

    /// Eviction releases cache ownership; active draws retain their own handle.
    static func removeCachedMasks() {
        maskCache.removeAllObjects()
    }

    static func maskImage(
        size: CGSize,
        cornerRadius: Double,
        fadeAmount: Double
    ) -> MaskHandle? {
        let width = max(Int(size.width.rounded(.up)), 1)
        let height = max(Int(size.height.rounded(.up)), 1)
        let key = "\(width)|\(height)|\(cornerRadius)|\(fadeAmount)" as NSString
        if let cached = maskCache.object(forKey: key) {
            return cached
        }
        guard let cgMask = OverlayFeatherMaskRenderer.makeCGMask(
            size: size,
            cornerRadius: cornerRadius,
            fadeAmount: fadeAmount
        ), let data = cgMask.dataProvider?.data,
            let bytes = CFDataGetBytePtr(data),
            CFDataGetLength(data) >= width * height
        else {
            return nil
        }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for index in 0..<(width * height) {
            let alpha = bytes[index]
            // White premultiplied by the mask alpha.
            pixels[index * 4] = alpha
            pixels[index * 4 + 1] = alpha
            pixels[index * 4 + 2] = alpha
            pixels[index * 4 + 3] = alpha
        }

        guard let pointer = pixels.withUnsafeBufferPointer({ buffer in
            skb_image_create(buffer.baseAddress, Int32(width), Int32(height))
        }) else { return nil }
        let handle = MaskHandle(pointer: pointer)
        maskCache.setObject(handle, forKey: key)
        return handle
    }
}
#endif
