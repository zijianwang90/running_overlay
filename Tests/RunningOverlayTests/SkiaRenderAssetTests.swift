#if canImport(CSkiaBridge)
import AppKit
import CoreGraphics
import CSkiaBridge
import Foundation
import Testing
@testable import RunningOverlay

@Suite(.serialized, .skiaSerialized)
struct SkiaRenderAssetTests {
    private static let canvas = CGSize(width: 1280, height: 720)

    @Test func routeSnapshotAndMaskRegistration() throws {
        try OverlayPreferenceFixtures.withDefaults {
            let activity = SkiaRouteWeatherGoldenTests.activity()
            let context = OverlayRenderContext(
                canvasSize: Self.canvas,
                activity: activity,
                elapsedTime: 30
            )
            var style = OverlayStyle.default
            style.routeMapBackgroundStyle = .dark
            style.backgroundFadeOutEnabled = true
            style.backgroundFadeOutAmount = 0.34
            let element = OverlayElement(
                type: .routeMap,
                position: CGPoint(x: 0.5, y: 0.5),
                scale: 1,
                style: style
            )
            let layout = OverlayRenderModel.routeMapLayout(for: element, in: context)
            let request = try #require(
                RouteMapSnapshotRequestBuilder.request(for: element, layout: layout)
            )

            let snapshot = NSImage(
                size: NSSize(width: layout.rect.width, height: layout.rect.height),
                flipped: false
            ) { rect in
                NSColor.systemTeal.setFill()
                rect.fill()
                return true
            }

            let assets = SkiaRenderAssets()
            SkiaRenderAssets.preloadRouteMaps(
                elements: [element],
                activity: activity,
                canvasSize: Self.canvas,
                mapSnapshots: [request: snapshot],
                into: assets
            )
            defer { assets.releaseImages() }

            let snapshotKey = SkiaRenderAssets.ImageSource.mapSnapshot(
                request,
                pixelWidth: Int(layout.rect.width.rounded()),
                pixelHeight: Int(layout.rect.height.rounded())
            )
            #expect(assets.image(for: snapshotKey) != nil)

            let maskKey = SkiaRenderAssets.ImageSource.routeMask(
                shape: layout.shape,
                cornerRadius: Int(layout.cornerRadius.rounded()),
                edgeFade: layout.edgeFade,
                fadeAmountMilli: Int((layout.fadeAmount * 1000).rounded()),
                pixelWidth: Int(layout.rect.width.rounded(.up)),
                pixelHeight: Int(layout.rect.height.rounded(.up))
            )
            #expect(assets.image(for: maskKey) != nil)
        }
    }

    @Test func weatherIconsPreloadAllPresets() throws {
        try OverlayPreferenceFixtures.withDefaults {
            let activity = SkiaRouteWeatherGoldenTests.activity()
            let elements = WeatherWidgetPreset.allCases.map { preset in
                var style = OverlayStyle.default
                style.weatherWidget = .preset(preset)
                return OverlayElement(
                    type: .weatherWidget,
                    position: CGPoint(x: 0.5, y: 0.5),
                    scale: 1,
                    style: style
                )
            }

            let assets = SkiaRenderAssets()
            SkiaWeatherWidgetModule.preloadAssets(
                elements: elements,
                activity: activity,
                canvasSize: Self.canvas,
                into: assets
            )
            defer { assets.releaseImages() }

            let context = OverlayRenderContext(
                canvasSize: Self.canvas,
                activity: activity,
                elapsedTime: 0
            )
            for element in elements {
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
                let key = SkiaRenderAssets.ImageSource.weatherIcon(
                    layout.condition,
                    pixelSize: Int((designSize * scale).rounded(.up))
                )
                #expect(
                    assets.image(for: key) != nil,
                    "missing icon for \(layout.style.preset.rawValue)"
                )
            }
        }
    }

    @Test func symbolRegistrationHonorsTintAndSize() throws {
        let assets = SkiaRenderAssets()
        defer { assets.releaseImages() }

        let tint = OverlayColor(red: 1, green: 0.5, blue: 0.25, alpha: 1)
        assets.registerSymbol(
            name: "sun.max.fill",
            pointSize: 24,
            weight: .semibold,
            color: tint,
            pixelSize: 48
        )
        let key = SkiaRenderAssets.ImageSource.symbol(
            name: "sun.max.fill",
            pointSize: 2400,
            weight: 300,
            color: SkiaRenderAssets.RGBAKey(tint),
            pixelSize: 48
        )
        #expect(assets.image(for: key) != nil)

        // A different tint must be a different cache entry.
        let otherTint = OverlayColor(red: 0, green: 0.5, blue: 1, alpha: 1)
        let otherKey = SkiaRenderAssets.ImageSource.symbol(
            name: "sun.max.fill",
            pointSize: 2400,
            weight: 300,
            color: SkiaRenderAssets.RGBAKey(otherTint),
            pixelSize: 48
        )
        #expect(assets.image(for: otherKey) == nil)
    }

    @Test func mapSnapshotDrawsIntoMapContent() throws {
        try OverlayPreferenceFixtures.withDefaults {
            let activity = SkiaRouteWeatherGoldenTests.activity()
            var style = OverlayStyle.default
            style.routeMapBackgroundStyle = .dark
            style.backgroundEnabled = false
            style.shadowEnabled = false
            style.borderEnabled = false
            let element = OverlayElement(
                type: .routeMap,
                position: CGPoint(x: 0.5, y: 0.5),
                scale: 1,
                style: style
            )
            let renderContext = OverlayRenderContext(
                canvasSize: Self.canvas,
                activity: activity,
                elapsedTime: 30
            )
            let layout = OverlayRenderModel.routeMapLayout(
                for: element,
                in: renderContext
            )
            let request = try #require(
                RouteMapSnapshotRequestBuilder.request(for: element, layout: layout)
            )

            let snapshot = NSImage(
                size: NSSize(width: layout.rect.width, height: layout.rect.height),
                flipped: false
            ) { rect in
                NSColor.magenta.setFill()
                rect.fill()
                return true
            }

            let assets = SkiaRenderAssets()
            SkiaRenderAssets.preloadRouteMaps(
                elements: [element],
                activity: activity,
                canvasSize: Self.canvas,
                mapSnapshots: [request: snapshot],
                into: assets
            )
            defer { assets.releaseImages() }

            let skiaContext = try #require(
                skb_create(Int32(Self.canvas.width), Int32(Self.canvas.height))
            )
            defer { skb_destroy(skiaContext) }
            skb_clear(skiaContext)
            SkiaRouteMapModule.draw(
                element,
                renderContext: renderContext,
                context: skiaContext,
                assets: assets
            )

            var rowBytes = 0
            let base = try #require(skb_pixels(skiaContext, &rowBytes))
            // BGRA little-endian; sample the empty top-left of the map.
            let x = Int(layout.rect.minX + 30)
            let y = Int(layout.rect.minY + 30)
            let index = y * rowBytes + x * 4
            let blue = base[index]
            let green = base[index + 1]
            let red = base[index + 2]
            let alpha = base[index + 3]
            // `skb_pixels` is premultiplied BGRA. The snapshot is drawn at
            // `layout.mapOpacity`, so magenta becomes R=G=B-alpha.
            #expect(red > 160 && green < 10 && blue > 160 && alpha > 160)
            #expect(red == alpha && blue == alpha)
        }
    }

    @Test func preloadGenerationEvictsStaleImagesByFamily() throws {
        try OverlayPreferenceFixtures.withDefaults {
            let activity = SkiaRouteWeatherGoldenTests.activity()
            let context = OverlayRenderContext(
                canvasSize: Self.canvas,
                activity: activity,
                elapsedTime: 30
            )
            let assets = SkiaRenderAssets()
            defer { assets.releaseImages() }

            var routeStyle = OverlayStyle.default
            routeStyle.routeMapBackgroundStyle = .dark
            routeStyle.routeMapWidth = 420
            routeStyle.routeMapHeight = 300
            routeStyle.backgroundEnabled = true
            routeStyle.backgroundFadeOutEnabled = true
            routeStyle.backgroundFadeOutAmount = 0.34
            var routeElement = OverlayElement(
                type: .routeMap,
                position: CGPoint(x: 0.5, y: 0.5),
                scale: 1,
                style: routeStyle
            )

            let firstRouteLayout = OverlayRenderModel.routeMapLayout(
                for: routeElement,
                in: context
            )
            let firstRequest = try #require(
                RouteMapSnapshotRequestBuilder.request(
                    for: routeElement,
                    layout: firstRouteLayout
                )
            )
            let firstSnapshotKey = Self.snapshotKey(
                firstRequest,
                firstRouteLayout
            )
            let firstMaskKey = Self.maskKey(firstRouteLayout)
            SkiaRenderAssets.preloadRouteMaps(
                elements: [routeElement],
                activity: activity,
                canvasSize: Self.canvas,
                mapSnapshots: [
                    firstRequest: Self.solidImage(
                        size: firstRouteLayout.rect.size
                    )
                ],
                into: assets
            )
            #expect(assets.image(for: firstSnapshotKey) != nil)
            #expect(assets.image(for: firstMaskKey) != nil)

            var weatherStyle = OverlayStyle.default
            weatherStyle.weatherWidget = .preset(.simpleCard)
            var weatherElement = OverlayElement(
                type: .weatherWidget,
                position: CGPoint(x: 0.5, y: 0.5),
                scale: 1,
                style: weatherStyle
            )
            let firstWeatherLayout = OverlayRenderModel.weatherWidgetLayout(
                for: weatherElement,
                in: context
            )
            let firstIconKey = Self.weatherIconKey(firstWeatherLayout)
            SkiaWeatherWidgetModule.preloadAssets(
                elements: [weatherElement],
                activity: activity,
                canvasSize: Self.canvas,
                into: assets
            )
            #expect(assets.image(for: firstIconKey) != nil)
            // The weather pass must not evict route assets.
            #expect(assets.image(for: firstSnapshotKey) != nil)
            #expect(assets.image(for: firstMaskKey) != nil)

            // Resize and re-fade the route map: the old snapshot and mask
            // handles must be replaced, not retained alongside the new ones.
            routeStyle.routeMapWidth = 520
            routeStyle.backgroundFadeOutAmount = 0.55
            routeStyle.routeMapBackgroundStyle = .light
            routeElement.style = routeStyle
            let secondRouteLayout = OverlayRenderModel.routeMapLayout(
                for: routeElement,
                in: context
            )
            let secondRequest = try #require(
                RouteMapSnapshotRequestBuilder.request(
                    for: routeElement,
                    layout: secondRouteLayout
                )
            )
            let secondSnapshotKey = Self.snapshotKey(
                secondRequest,
                secondRouteLayout
            )
            let secondMaskKey = Self.maskKey(secondRouteLayout)
            #expect(secondSnapshotKey != firstSnapshotKey)
            #expect(secondMaskKey != firstMaskKey)
            SkiaRenderAssets.preloadRouteMaps(
                elements: [routeElement],
                activity: activity,
                canvasSize: Self.canvas,
                mapSnapshots: [
                    secondRequest: Self.solidImage(
                        size: secondRouteLayout.rect.size
                    )
                ],
                into: assets
            )
            #expect(assets.image(for: firstSnapshotKey) == nil)
            #expect(assets.image(for: firstMaskKey) == nil)
            #expect(assets.image(for: secondSnapshotKey) != nil)
            #expect(assets.image(for: secondMaskKey) != nil)
            #expect(assets.image(for: firstIconKey) != nil)

            // Change the weather preset and scale: only the old weather icon
            // goes, and route assets stay valid.
            weatherStyle.weatherWidget = .preset(.compactStrip)
            weatherElement.style = weatherStyle
            weatherElement.scale = 1.5
            let secondWeatherLayout = OverlayRenderModel.weatherWidgetLayout(
                for: weatherElement,
                in: context
            )
            let secondIconKey = Self.weatherIconKey(secondWeatherLayout)
            #expect(secondIconKey != firstIconKey)
            SkiaWeatherWidgetModule.preloadAssets(
                elements: [weatherElement],
                activity: activity,
                canvasSize: Self.canvas,
                into: assets
            )
            #expect(assets.image(for: firstIconKey) == nil)
            #expect(assets.image(for: secondIconKey) != nil)
            #expect(assets.image(for: secondSnapshotKey) != nil)
            #expect(assets.image(for: secondMaskKey) != nil)
        }
    }

    private static func snapshotKey(
        _ request: MapSnapshotRequest,
        _ layout: OverlayRouteMapRenderLayout
    ) -> SkiaRenderAssets.ImageSource {
        .mapSnapshot(
            request,
            pixelWidth: max(Int(layout.rect.width.rounded()), 1),
            pixelHeight: max(Int(layout.rect.height.rounded()), 1)
        )
    }

    private static func maskKey(
        _ layout: OverlayRouteMapRenderLayout
    ) -> SkiaRenderAssets.ImageSource {
        .routeMask(
            shape: layout.shape,
            cornerRadius: Int(layout.cornerRadius.rounded()),
            edgeFade: layout.edgeFade,
            fadeAmountMilli: Int((layout.fadeAmount * 1000).rounded()),
            pixelWidth: max(Int(layout.rect.width.rounded(.up)), 1),
            pixelHeight: max(Int(layout.rect.height.rounded(.up)), 1)
        )
    }

    private static func weatherIconKey(
        _ layout: WeatherWidgetRenderLayout
    ) -> SkiaRenderAssets.ImageSource {
        let scale = layout.rect.width / max(layout.style.width, 1)
        let designSize: Double
        switch layout.style.preset {
        case .simpleCard: designSize = 58
        case .compactStrip: designSize = 34
        case .forecastTile: designSize = 54
        case .minimalText: designSize = 30
        case .dashboardBar: designSize = 44
        }
        return .weatherIcon(
            layout.condition,
            pixelSize: Int((designSize * scale).rounded(.up))
        )
    }

    private static func solidImage(
        size: CGSize,
        color: NSColor = .systemTeal
    ) -> NSImage {
        NSImage(
            size: NSSize(width: size.width, height: size.height),
            flipped: false
        ) { rect in
            color.setFill()
            rect.fill()
            return true
        }
    }

    @Test func fontCacheReusesInstances() {
        let assets = SkiaRenderAssets()
        let first = assets.font(family: "Menlo", size: 18, weight: .semibold)
        let second = assets.font(family: "Menlo", size: 18, weight: .semibold)
        let third = assets.font(family: "Menlo", size: 18, weight: .regular)
        #expect(first === second)
        #expect(first.fontName != third.fontName)
    }
}
#endif
