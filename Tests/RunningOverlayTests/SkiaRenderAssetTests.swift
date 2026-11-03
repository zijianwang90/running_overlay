#if canImport(CSkiaBridge)
import AppKit
import CoreGraphics
import CSkiaBridge
import Foundation
import Testing
@testable import RunningOverlay

@Suite(.serialized)
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
