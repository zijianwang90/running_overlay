#if canImport(CSkiaBridge)
import AppKit
import CSkiaBridge
import CoreGraphics
import Foundation

/// Immutable, preloaded image/font assets for the Skia module renderers.
///
/// Every image is rasterized into a bridge-owned `SkiaBridgeImage` handle
/// before the frame loop. The draw path only performs dictionary lookups, so
/// no AppKit work, network access, or async work happens during a frame.
///
/// Usage:
/// 1. Create one store per render session (export clip, preview host, test).
/// 2. Preload map snapshots, weather icons, and fade masks through the
///    `register*` methods.
/// 3. Pass the store to the module `draw` calls.
/// 4. Call `releaseImages()` before destroying the bridge context (CPU
///    handles are independent, but this keeps the lifetime contract simple).
final class SkiaRenderAssets {
    struct RGBAKey: Hashable {
        var red: UInt8
        var green: UInt8
        var blue: UInt8
        var alpha: UInt8

        init(_ color: OverlayColor) {
            red = UInt8((min(max(color.red, 0), 1) * 255).rounded())
            green = UInt8((min(max(color.green, 0), 1) * 255).rounded())
            blue = UInt8((min(max(color.blue, 0), 1) * 255).rounded())
            alpha = UInt8((min(max(color.alpha, 0), 1) * 255).rounded())
        }
    }

    enum ImageSource: Hashable {
        /// Keyed by the snapshot request (bounds + point size + style) plus the
        /// rounded canvas pixel size, per the bridge-freeze decisions.
        case mapSnapshot(MapSnapshotRequest, pixelWidth: Int, pixelHeight: Int)
        /// Bundled weather PNG, colors preserved.
        case weatherIcon(WeatherCondition, pixelSize: Int)
        /// SF Symbol rasterized with a tint at a fixed pixel size.
        case symbol(
            name: String,
            pointSize: Int,
            weight: Int,
            color: RGBAKey,
            pixelSize: Int
        )
        /// Fade mask built from `RouteMapMaskRenderer`; alpha = luminance.
        case routeMask(
            shape: OverlayRouteMapShape,
            cornerRadius: Int,
            edgeFade: OverlayRouteMapEdgeFade,
            fadeAmountMilli: Int,
            pixelWidth: Int,
            pixelHeight: Int
        )

        /// Asset families are evicted independently so a route-map preload pass
        /// never drops weather icons (and vice versa).
        enum Family: Hashable {
            case routeMap
            case weatherIcon
            case symbol
        }

        var family: Family {
            switch self {
            case .mapSnapshot, .routeMask: .routeMap
            case .weatherIcon: .weatherIcon
            case .symbol: .symbol
            }
        }
    }

    private struct FontKey: Hashable {
        var family: String
        var sizeMilli: Int
        var weight: Double
    }

    private var images: [ImageSource: OpaquePointer] = [:]
    private var fonts: [FontKey: NSFont] = [:]

    deinit {
        releaseImages()
    }

    /// Destroys every cached image handle. Safe to call more than once.
    func releaseImages() {
        for handle in images.values {
            skb_image_destroy(handle)
        }
        images.removeAll()
    }

    /// Drops cached images in `family` that `current` does not contain and
    /// destroys their bridge handles. Other families are untouched, so route
    /// and weather preload passes can replace their own generations
    /// independently.
    func removeImages(notIn current: Set<ImageSource>, family: ImageSource.Family) {
        let stale = images.keys.filter { $0.family == family && !current.contains($0) }
        for key in stale {
            guard let handle = images.removeValue(forKey: key) else { continue }
            skb_image_destroy(handle)
        }
    }

    func image(for source: ImageSource) -> OpaquePointer? {
        images[source]
    }

    func font(family: String, size: Double, weight: NSFont.Weight) -> NSFont {
        let key = FontKey(
            family: family,
            sizeMilli: Int((max(size, 1) * 1000).rounded()),
            weight: Double(weight.rawValue)
        )
        if let cached = fonts[key] {
            return cached
        }
        let font = OverlayFontResolver.appKitFont(
            family: family,
            size: max(size, 1),
            weight: weight
        )
        fonts[key] = font
        return font
    }

    // MARK: - Registration

    /// Registers a MapKit snapshot for a route layout. `request` must be the
    /// value produced by `RouteMapSnapshotRequestBuilder` for the same layout.
    /// Returns the cache key so preload passes can retain the current
    /// generation.
    @discardableResult
    func registerMapSnapshot(
        _ image: NSImage,
        for request: MapSnapshotRequest,
        pixelSize: CGSize
    ) -> ImageSource {
        let width = max(Int(pixelSize.width.rounded()), 1)
        let height = max(Int(pixelSize.height.rounded()), 1)
        let key = ImageSource.mapSnapshot(
            request,
            pixelWidth: width,
            pixelHeight: height
        )
        guard images[key] == nil else { return key }
        register(image: image, pixelWidth: width, pixelHeight: height, for: key)
        return key
    }

    @discardableResult
    func registerWeatherIcon(_ condition: WeatherCondition, pixelSize: Int) -> ImageSource {
        let side = max(pixelSize, 1)
        let key = ImageSource.weatherIcon(condition, pixelSize: side)
        guard images[key] == nil,
              let image = IconAssetResolver.bundledImage(name: condition.bundledImageName)
        else { return key }
        register(image: image, pixelWidth: side, pixelHeight: side, for: key)
        return key
    }

    func registerSymbol(
        name: String,
        pointSize: Double,
        weight: NSFont.Weight,
        color: OverlayColor,
        pixelSize: Int
    ) {
        let side = max(pixelSize, 1)
        let key = ImageSource.symbol(
            name: name,
            pointSize: Int((max(pointSize, 1) * 100).rounded()),
            weight: Int((weight.rawValue * 1000).rounded()),
            color: RGBAKey(color),
            pixelSize: side
        )
        guard images[key] == nil,
              let image = Self.symbolImage(
                name: name,
                pointSize: pointSize,
                weight: weight,
                color: color
              )
        else { return }
        register(image: image, pixelWidth: side, pixelHeight: side, for: key)
    }

    /// Builds the route edge-fade mask once and stores it as an alpha mask.
    /// `fadeAmount` is quantized to 0.001 for the cache key. Returns the cache
    /// key so preload passes can retain the current generation.
    @discardableResult
    func registerRouteMask(
        shape: OverlayRouteMapShape,
        cornerRadius: Double,
        edgeFade: OverlayRouteMapEdgeFade,
        fadeAmount: Double,
        pixelSize: CGSize
    ) -> ImageSource {
        let width = max(Int(pixelSize.width.rounded(.up)), 1)
        let height = max(Int(pixelSize.height.rounded(.up)), 1)
        let key = ImageSource.routeMask(
            shape: shape,
            cornerRadius: Int(cornerRadius.rounded()),
            edgeFade: edgeFade,
            fadeAmountMilli: Int((fadeAmount * 1000).rounded()),
            pixelWidth: width,
            pixelHeight: height
        )
        guard images[key] == nil,
              let mask = RouteMapMaskRenderer.makeCGMask(
                size: CGSize(width: width, height: height),
                shape: shape,
                cornerRadius: cornerRadius,
                edgeFade: edgeFade,
                fadeAmount: fadeAmount
              ),
              let handle = Self.imageHandle(
                from: mask,
                pixelWidth: width,
                pixelHeight: height,
                alphaFromLuminance: true
              )
        else { return key }
        images[key] = handle
        return key
    }

    // MARK: - Rasterization

    private func register(
        image: NSImage,
        pixelWidth: Int,
        pixelHeight: Int,
        for key: ImageSource
    ) {
        guard let handle = Self.imageHandle(
            from: image,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight
        ) else { return }
        images[key] = handle
    }

    static func imageHandle(
        from image: NSImage,
        pixelWidth: Int,
        pixelHeight: Int
    ) -> OpaquePointer? {
        let width = max(pixelWidth, 1)
        let height = max(pixelHeight, 1)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        var rendered = false
        pixels.withUnsafeMutableBytes { raw in
            guard let bitmap = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue
            ) else { return }
            bitmap.interpolationQuality = .high
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(
                cgContext: bitmap,
                flipped: false
            )
            image.draw(
                in: CGRect(x: 0, y: 0, width: width, height: height),
                from: .zero,
                operation: .sourceOver,
                fraction: 1
            )
            NSGraphicsContext.restoreGraphicsState()
            rendered = true
        }
        guard rendered else { return nil }
        return pixels.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return nil }
            return skb_image_create(base, Int32(width), Int32(height))
        }
    }

    static func imageHandle(
        from cgImage: CGImage,
        pixelWidth: Int,
        pixelHeight: Int,
        alphaFromLuminance: Bool
    ) -> OpaquePointer? {
        let width = max(pixelWidth, 1)
        let height = max(pixelHeight, 1)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        var rendered = false
        pixels.withUnsafeMutableBytes { raw in
            guard let bitmap = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue
            ) else { return }
            bitmap.interpolationQuality = .high
            bitmap.draw(
                cgImage,
                in: CGRect(x: 0, y: 0, width: width, height: height)
            )
            rendered = true
        }
        guard rendered else { return nil }

        if alphaFromLuminance {
            // The mask image is grayscale. Convert each pixel to premultiplied
            // BGRA whose alpha (and color) equals the luminance value.
            var index = 0
            while index < pixels.count {
                let gray = pixels[index + 2] // R in BGRA little-endian
                pixels[index] = gray
                pixels[index + 1] = gray
                pixels[index + 2] = gray
                pixels[index + 3] = gray
                index += 4
            }
        }

        return pixels.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return nil }
            return skb_image_create(base, Int32(width), Int32(height))
        }
    }

    private static func symbolImage(
        name: String,
        pointSize: Double,
        weight: NSFont.Weight,
        color: OverlayColor
    ) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(
            pointSize: max(pointSize, 1),
            weight: weight
        )
        guard let base = NSImage(
            systemSymbolName: name,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(configuration) else {
            return nil
        }
        return NSImage(size: base.size, flipped: false) { drawRect in
            NSColor(
                srgbRed: color.red,
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
    }
}

// MARK: - Preloading

extension SkiaRenderAssets {
    /// Preloads everything the route modules need for a frame: map snapshots
    /// and edge-fade masks. `mapSnapshots` is supplied by the host (MapKit
    /// loader or test fixture); no network work happens here.
    static func preloadRouteMaps(
        elements: [OverlayElement],
        activity: ActivityTimeline,
        canvasSize: CGSize,
        mapSnapshots: [MapSnapshotRequest: NSImage],
        into assets: SkiaRenderAssets
    ) {
        let context = OverlayRenderContext(
            canvasSize: canvasSize,
            activity: activity,
            elapsedTime: 0
        )
        var current: Set<ImageSource> = []
        for element in elements where element.type == .routeMap && element.isVisible {
            let layout = OverlayRenderModel.routeMapLayout(for: element, in: context)
            let pixelSize = CGSize(
                width: layout.rect.width.rounded(),
                height: layout.rect.height.rounded()
            )

            if let request = RouteMapSnapshotRequestBuilder.request(
                for: element,
                layout: layout
            ), let image = mapSnapshots[request] {
                current.insert(assets.registerMapSnapshot(
                    image,
                    for: request,
                    pixelSize: pixelSize
                ))
            }

            if layout.edgeFade == .fadeOut, layout.fadeAmount > 0.001 {
                current.insert(assets.registerRouteMask(
                    shape: layout.shape,
                    cornerRadius: layout.cornerRadius,
                    edgeFade: layout.edgeFade,
                    fadeAmount: layout.fadeAmount,
                    pixelSize: layout.rect.size
                ))
            }
        }
        // Replace the previous generation instead of accumulating handles for
        // every size/style/fade value the element has had.
        assets.removeImages(notIn: current, family: .routeMap)
    }

    /// Preloads the bundled weather icon for every visible weather widget at
    /// the pixel size that preset renders. Conditions are static per project
    /// snapshot, so this can run once per export clip.
    static func preloadWeatherIcons(
        elements: [OverlayElement],
        activity: ActivityTimeline,
        canvasSize: CGSize,
        into assets: SkiaRenderAssets
    ) {
        let context = OverlayRenderContext(
            canvasSize: canvasSize,
            activity: activity,
            elapsedTime: 0
        )
        var current: Set<ImageSource> = []
        for element in elements where element.type == .weatherWidget && element.isVisible {
            let layout = OverlayRenderModel.weatherWidgetLayout(
                for: element,
                in: context
            )
            let scale = layout.rect.width / max(layout.style.width, 1)
            let designSize: Double
            switch layout.style.preset {
            case .simpleCard: designSize = 58
            case .compactStrip: designSize = 34
            case .forecastTile: designSize = 54
            case .minimalText: designSize = 30
            case .dashboardBar: designSize = 44
            }
            current.insert(assets.registerWeatherIcon(
                layout.condition,
                pixelSize: Int((designSize * scale).rounded(.up))
            ))
        }
        assets.removeImages(notIn: current, family: .weatherIcon)
    }
}
#endif
