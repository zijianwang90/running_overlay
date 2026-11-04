#if canImport(CSkiaBridge)
import AppKit
import CoreGraphics
import CSkiaBridge
import Foundation
import Testing
@testable import RunningOverlay

/// Route map and weather widget parity goldens against the SwiftUI export
/// oracle. Scenes avoid MapKit by using `routeMapBackgroundStyle = .none`;
/// snapshot injection is covered by a separate test.
@Suite(.serialized, .skiaSerialized)
struct SkiaRouteWeatherGoldenTests {
    private static let canvas = CGSize(width: 1280, height: 720)

    // MARK: - Route Map

    @Test func routeMapSolidSquare() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            let element = routeElement { style in
                style.routeMapBackgroundStyle = .none
                style.shadowEnabled = false
                style.borderEnabled = false
                style.backgroundEnabled = true
                style.backgroundColor = OverlayColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1)
                style.backgroundOpacity = 0.85
            }
            try await assertParity(
                element: element,
                elapsedTime: 30,
                label: "route-solid-square"
            )
        }
    }

    @Test func routeMapBorderShadowGlow() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            let element = routeElement { style in
                style.routeMapBackgroundStyle = .none
                style.backgroundEnabled = true
                style.backgroundColor = .black
                style.backgroundOpacity = 0.6
                style.borderEnabled = true
                style.borderWidth = 2
                style.borderColor = .white
                style.borderOpacity = 0.7
                style.shadowEnabled = true
                style.shadowOpacity = 0.5
                style.shadowRadius = 8
                style.glowEnabled = true
                style.glowIntensity = 0.6
                style.foregroundColor = .cyan
            }
            try await assertParity(
                element: element,
                elapsedTime: 30,
                label: "route-border-shadow-glow"
            )
        }
    }

    @Test func routeMapGradient() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            let element = routeElement { style in
                style.routeMapBackgroundStyle = .none
                style.shadowEnabled = false
                style.routeMapColorMode = .gradient
                style.routeMapGradientStart = .green
                style.routeMapGradientMiddle = .yellow
                style.routeMapGradientEnd = .red
            }
            try await assertParity(
                element: element,
                elapsedTime: 30,
                label: "route-gradient"
            )
        }
    }

    /// The route's gradient resolves against the map content rect, not the
    /// tight route bounds. A near-vertical route makes the two interpretations
    /// produce visibly different colors, so this golden fails if the endpoints
    /// regress to the path bounds.
    @Test func routeGradientSpace() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            let element = routeElement { style in
                style.routeMapBackgroundStyle = .none
                style.shadowEnabled = false
                style.routeMapColorMode = .gradient
                style.routeMapGradientStart = .green
                style.routeMapGradientMiddle = .yellow
                style.routeMapGradientEnd = .red
            }
            let narrow = Self.activity(points: [
                (0, 40.7500, -73.9900),
                (10, 40.7520, -73.9899),
                (20, 40.7550, -73.9900),
                (30, 40.7580, -73.9899),
                (40, 40.7600, -73.9900),
                (50, 40.7620, -73.9899),
                (60, 40.7650, -73.9900),
            ])
            try await assertParity(
                element: element,
                activity: narrow,
                elapsedTime: 30,
                label: "route-gradient-space"
            )
        }
    }

    @Test func routeMapFadeOut() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            let element = routeElement { style in
                style.routeMapBackgroundStyle = .none
                style.shadowEnabled = false
                style.backgroundEnabled = true
                style.backgroundColor = OverlayColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 1)
                style.backgroundOpacity = 0.9
                style.backgroundFadeOutEnabled = true
                style.backgroundFadeOutAmount = 0.34
            }
            try await assertParity(
                element: element,
                elapsedTime: 30,
                label: "route-fade"
            )
        }
    }

    @Test func routeMapCircle() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            let element = routeElement { style in
                style.routeMapBackgroundStyle = .none
                style.routeMapShape = .circle
                style.shadowEnabled = false
                style.backgroundEnabled = true
                style.backgroundColor = .black
                style.backgroundOpacity = 0.55
                style.borderEnabled = true
                style.borderOpacity = 0.5
            }
            try await assertParity(
                element: element,
                elapsedTime: 30,
                label: "route-circle"
            )
        }
    }

    @Test func routeMapStatsBarOutside() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            let element = routeElement { style in
                style.routeMapBackgroundStyle = .none
                style.shadowEnabled = false
                style.routeMapStatsBar.visible = true
                style.routeMapStatsBar.placement = .bottomAttached
                style.routeMapStatsBar.inside = false
                style.routeMapStatsBar.height = 64
                style.routeMapStatsBar.slots = [
                    RouteMapStatsBarSlot(metric: .distance, visible: true, customLabel: ""),
                    RouteMapStatsBarSlot(metric: .pace, visible: true, customLabel: ""),
                    RouteMapStatsBarSlot(metric: .elapsedTime, visible: true, customLabel: ""),
                    RouteMapStatsBarSlot(metric: .heartRate, visible: false, customLabel: ""),
                ]
            }
            try await assertParity(
                element: element,
                elapsedTime: 30,
                label: "route-stats-outside"
            )
        }
    }

    @Test func routeMapStatsBarInside() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            let element = routeElement { style in
                style.routeMapBackgroundStyle = .none
                style.shadowEnabled = false
                style.backgroundEnabled = true
                style.backgroundColor = .black
                style.backgroundOpacity = 0.5
                style.routeMapStatsBar.visible = true
                style.routeMapStatsBar.placement = .insideBottom
                style.routeMapStatsBar.inside = true
                style.routeMapStatsBar.height = 48
                style.routeMapStatsBar.slots = [
                    RouteMapStatsBarSlot(metric: .distance, visible: true, customLabel: ""),
                    RouteMapStatsBarSlot(metric: .progress, visible: true, customLabel: "Done"),
                ]
            }
            try await assertParity(
                element: element,
                elapsedTime: 30,
                label: "route-stats-inside"
            )
        }
    }

    @Test func routeMapNoGPS() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            let element = routeElement { style in
                style.routeMapBackgroundStyle = .none
                style.shadowEnabled = false
                style.backgroundEnabled = true
                style.backgroundColor = .black
                style.backgroundOpacity = 0.5
            }
            let empty = ActivityTimeline(
                startDate: Date(timeIntervalSince1970: 1_735_689_600),
                duration: 60,
                distanceMeters: 0,
                records: [],
                laps: []
            )
            try await assertParity(
                element: element,
                activity: empty,
                elapsedTime: 0,
                label: "route-no-gps"
            )
        }
    }

    // MARK: - Weather Widget

    @Test(arguments: WeatherWidgetPreset.allCases)
    func weatherPresets(_ preset: WeatherWidgetPreset) async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            var style = OverlayStyle.default
            style.fontName = "Menlo"
            style.weatherWidget = pinnedWeather(.preset(preset))
            let element = OverlayElement(
                type: .weatherWidget,
                position: CGPoint(x: 0.5, y: 0.5),
                scale: 1,
                style: style
            )
            try await assertParity(
                element: element,
                elapsedTime: 0,
                label: "weather-\(preset.rawValue)"
            )
        }
    }

    @Test(arguments: [
        WeatherWidgetPalette.blueGlass,
        .lightGlass,
        .graphite,
        .minimalWhite,
    ])
    func weatherPalettes(_ palette: WeatherWidgetPalette) async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            var widget = WeatherWidgetStyle.preset(.simpleCard)
            widget.palette = palette
            var style = OverlayStyle.default
            style.fontName = "Menlo"
            style.weatherWidget = pinnedWeather(widget)
            let element = OverlayElement(
                type: .weatherWidget,
                position: CGPoint(x: 0.5, y: 0.5),
                scale: 1,
                style: style
            )
            try await assertParity(
                element: element,
                elapsedTime: 0,
                label: "weather-palette-\(palette.rawValue)"
            )
        }
    }

    @Test func weatherFahrenheitPayload() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            var widget = WeatherWidgetStyle.preset(.simpleCard)
            widget.temperatureUnit = .fahrenheit
            widget.cachedWeather = WeatherPayload(
                condition: .snow,
                temperatureCelsius: 12.4,
                humidity: 81,
                highTemperatureCelsius: 15.2,
                lowTemperatureCelsius: 9.8,
                windKph: 14,
                feelsLikeCelsius: 10.6,
                resolvedLocation: "Berlin",
                sourceDate: Date(timeIntervalSince1970: 1_735_689_600)
            )
            var style = OverlayStyle.default
            style.fontName = "Menlo"
            style.weatherWidget = pinnedWeather(widget)
            let element = OverlayElement(
                type: .weatherWidget,
                position: CGPoint(x: 0.5, y: 0.5),
                scale: 1,
                style: style
            )
            try await assertParity(
                element: element,
                elapsedTime: 0,
                label: "weather-fahrenheit-snow"
            )
        }
    }

    @Test func weatherSimpleCardWithPayload() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            var widget = WeatherWidgetStyle.preset(.simpleCard)
            widget.dataSource = .openMeteo
            widget.cachedWeather = WeatherPayload(
                condition: .rain,
                temperatureCelsius: 12.4,
                humidity: 81,
                highTemperatureCelsius: 15.2,
                lowTemperatureCelsius: 9.8,
                windKph: 14,
                feelsLikeCelsius: 10.6,
                resolvedLocation: "Berlin",
                sourceDate: Date(timeIntervalSince1970: 1_735_689_600)
            )
            widget.locationText = "Berlin"
            var style = OverlayStyle.default
            style.fontName = "Menlo"
            style.weatherWidget = pinnedWeather(widget)
            let element = OverlayElement(
                type: .weatherWidget,
                position: CGPoint(x: 0.5, y: 0.5),
                scale: 1,
                style: style
            )
            try await assertParity(
                element: element,
                elapsedTime: 0,
                label: "weather-payload-rain"
            )
        }
    }

    // MARK: - Helpers

    private func routeElement(
        configure: (inout OverlayStyle) -> Void
    ) -> OverlayElement {
        var style = OverlayStyle.default
        style.fontName = "Menlo"
        style.routeMapStatsBar.valueFontName = "Menlo"
        style.routeMapStatsBar.labelFontName = "Menlo"
        configure(&style)
        return OverlayElement(
            type: .routeMap,
            position: CGPoint(x: 0.5, y: 0.5),
            scale: 1,
            style: style
        )
    }

    private func pinnedWeather(_ widget: WeatherWidgetStyle) -> WeatherWidgetStyle {
        var widget = widget
        widget.locationTextStyle.fontName = "Menlo"
        widget.conditionTextStyle.fontName = "Menlo"
        widget.temperatureTextStyle.fontName = "Menlo"
        widget.slotTitleTextStyle.fontName = "Menlo"
        widget.slotLabelTextStyle.fontName = "Menlo"
        return widget
    }

    private func assertParity(
        element: OverlayElement,
        activity: ActivityTimeline? = nil,
        elapsedTime: TimeInterval,
        label: String
    ) async throws {
        let size = Self.canvas
        let activity = activity ?? Self.activity()

        let reference = try await SwiftUIOverlayVideoExporter.renderFrameCGImage(
            overlayLayout: OverlayLayout(elements: [element]),
            activity: activity,
            elapsedTime: elapsedTime,
            size: size
        )
        let candidate = try Self.renderSkia(
            element: element,
            activity: activity,
            elapsedTime: elapsedTime,
            size: size
        )

        let metrics = try Self.compare(
            reference: reference,
            candidate: candidate,
            size: size,
            label: label
        )
        print(metrics.description)
        #expect(metrics.changedRatio <= 0.10, "\(label): \(metrics)")
        #expect(metrics.meanDelta <= 8.0, "\(label): \(metrics)")
    }

    static func renderSkia(
        element: OverlayElement,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        size: CGSize
    ) throws -> CGImage {
        guard let context = skb_create(Int32(size.width), Int32(size.height)) else {
            throw OverlayRendererBackendError.unavailable(.skia)
        }
        let assets = SkiaRenderAssets()
        defer {
            assets.releaseImages()
            skb_destroy(context)
        }
        skb_clear(context)
        let renderContext = OverlayRenderContext(
            canvasSize: size,
            activity: activity,
            elapsedTime: elapsedTime
        )

        switch element.type {
        case .routeMap:
            SkiaRouteMapModule.preloadAssets(
                elements: [element],
                activity: activity,
                canvasSize: size,
                mapSnapshots: [:],
                into: assets
            )
            SkiaRouteMapModule.draw(
                element,
                renderContext: renderContext,
                context: context,
                assets: assets
            )
        case .weatherWidget:
            SkiaWeatherWidgetModule.preloadAssets(
                elements: [element],
                activity: activity,
                canvasSize: size,
                into: assets
            )
            SkiaWeatherWidgetModule.draw(
                element,
                renderContext: renderContext,
                context: context,
                assets: assets
            )
        default:
            throw OverlayRendererBackendError.cannotCreateImage
        }

        var rowBytes = 0
        guard let base = skb_pixels(context, &rowBytes) else {
            throw OverlayRendererBackendError.cannotCreateImage
        }
        let data = Data(bytes: base, count: rowBytes * Int(size.height))
        guard let provider = CGDataProvider(data: data as CFData),
              let image = CGImage(
                  width: Int(size.width),
                  height: Int(size.height),
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: rowBytes,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(
                      rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue
                          | CGBitmapInfo.byteOrder32Little.rawValue
                  ),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent
              ) else {
            throw OverlayRendererBackendError.cannotCreateImage
        }
        return image
    }

    static func compare(
        reference: CGImage,
        candidate: CGImage,
        size: CGSize,
        label: String
    ) throws -> GoldenFrameMetrics {
        let width = Int(size.width)
        let height = Int(size.height)
        let referencePixels = try rgbaPixels(reference, width: width, height: height)
        let candidatePixels = try rgbaPixels(candidate, width: width, height: height)

        var changed = 0
        var maxDelta = 0
        var totalDelta = 0
        var diffBox = CGRect.null
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                var pixelDelta = 0
                for channel in 0..<4 {
                    pixelDelta += abs(
                        Int(referencePixels[index + channel])
                            - Int(candidatePixels[index + channel])
                    )
                }
                if pixelDelta > 8 {
                    changed += 1
                    diffBox = diffBox.union(CGRect(x: x, y: y, width: 1, height: 1))
                }
                maxDelta = max(maxDelta, pixelDelta)
                totalDelta += pixelDelta
            }
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("skia-route-weather", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let referenceURL = directory.appendingPathComponent("\(label)-swiftui.png")
        let candidateURL = directory.appendingPathComponent("\(label)-skia.png")
        try writePNG(reference, to: referenceURL)
        try writePNG(candidate, to: candidateURL)

        let totalPixels = width * height
        return GoldenFrameMetrics(
            label: label,
            changedPixels: changed,
            totalPixels: totalPixels,
            meanDelta: totalPixels > 0
                ? Double(totalDelta) / Double(totalPixels * 4)
                : 0,
            maxDelta: maxDelta,
            diffBox: diffBox,
            referenceURL: referenceURL,
            candidateURL: candidateURL
        )
    }

    static func rgbaPixels(
        _ image: CGImage,
        width: Int,
        height: Int
    ) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let bitmapInfo = CGBitmapInfo(
            rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        )
        try bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo.rawValue
            ) else {
                throw GoldenFrameError.cannotCreateContext
            }
            context.draw(
                image,
                in: CGRect(x: 0, y: 0, width: width, height: height)
            )
        }
        return bytes
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw GoldenFrameError.cannotCreatePNG
        }
        try data.write(to: url)
    }

    static func activity(
        points: [(TimeInterval, Double, Double)] = [
            (0, 40.7500, -73.9900),
            (10, 40.7520, -73.9860),
            (20, 40.7550, -73.9820),
            (30, 40.7580, -73.9840),
            (40, 40.7600, -73.9800),
            (50, 40.7620, -73.9760),
            (60, 40.7650, -73.9720),
        ]
    ) -> ActivityTimeline {
        let start = Date(timeIntervalSince1970: 1_735_689_600)
        let records = points.map { elapsed, latitude, longitude in
            ActivityRecord(
                elapsedTime: elapsed,
                timestamp: start.addingTimeInterval(elapsed),
                distanceMeters: elapsed * 3.3,
                heartRate: 130 + Int(elapsed / 3),
                paceSecondsPerKilometer: 300,
                elevationMeters: 20 + elapsed / 10,
                cadence: 176,
                powerWatts: 250,
                calories: elapsed / 4,
                latitude: latitude,
                longitude: longitude
            )
        }
        return ActivityTimeline(
            startDate: start,
            duration: 60,
            distanceMeters: 200,
            records: records,
            laps: []
        )
    }
}
#endif
