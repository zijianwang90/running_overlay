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
}
#endif
