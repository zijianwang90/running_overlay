import Foundation
import Testing
@testable import RunningOverlay

struct OverlayComponentWeatherWidgetTests {
    static func data() throws -> Data {
        let item = try #require(OverlayComponentLibraryItem.chartComponents.first {
            $0.resourceName == "weather-widget"
        })
        return try #require(OverlayComponentLibrary.data(for: item))
    }

    @Test func bundledDefinitionResolves() throws {
        let package = try OverlayComponentLoader.load(data: Self.data())
        let activity = OverlayComponentWeatherWidgetParityTests.activity()
        let data = OverlayComponentActivityData(
            activity: activity, elapsedTime: 90, zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720), elementScale: 1
        )
        let result = OverlayComponentResolver(definition: package.definition)
            .resolve(parameters: [:], data: data)
        #expect(result.diagnostics.isEmpty, "\(result.diagnostics)")
        #expect(package.definition.id == "studio.weather-widget")
        #expect(!result.nodes.isEmpty)
    }

    @Test func presetSizeFollowsPresetUnlessOverridden() throws {
        let package = try OverlayComponentLoader.load(data: Self.data())
        let data = OverlayComponentActivityData(
            activity: OverlayComponentWeatherWidgetParityTests.activity(),
            elapsedTime: 90, zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720), elementScale: 1
        )
        func frame(_ parameters: [String: OverlayComponentValue]) throws -> CGRect {
            let result = OverlayComponentResolver(definition: package.definition)
                .resolve(parameters: parameters, data: data)
            let node = try #require(result.nodes.first)
            guard case let .weatherWidget(frame, _) = node else {
                Issue.record("expected a weather node")
                return .zero
            }
            return frame
        }
        #expect(try frame([:]) == CGRect(x: 0, y: 0, width: 300, height: 110))
        #expect(
            try frame(["preset": .string("compactStrip")])
                == CGRect(x: 0, y: 0, width: 220, height: 56)
        )
        #expect(
            try frame([
                "usePresetSize": .boolean(false),
                "componentWidth": .number(400),
                "componentHeight": .number(140)
            ]) == CGRect(x: 0, y: 0, width: 400, height: 140)
        )
    }

    @Test func manualSourceIgnoresHostSnapshot() throws {
        let package = try OverlayComponentLoader.load(data: Self.data())
        let payload = WeatherPayload(
            condition: .rain, temperatureCelsius: 8, humidity: 94,
            highTemperatureCelsius: 11, lowTemperatureCelsius: 5,
            windKph: 18, feelsLikeCelsius: 4, resolvedLocation: "Shanghai",
            sourceDate: nil
        )
        let data = OverlayComponentActivityData(
            activity: OverlayComponentWeatherWidgetParityTests.activity(),
            elapsedTime: 90, zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720), elementScale: 1,
            weatherPayload: payload
        )
        func style(_ parameters: [String: OverlayComponentValue]) throws -> WeatherWidgetStyle {
            let result = OverlayComponentResolver(definition: package.definition)
                .resolve(parameters: parameters, data: data)
            let node = try #require(result.nodes.first)
            guard case let .weatherWidget(_, style) = node else {
                Issue.record("expected a weather node")
                return .preset(.simpleCard)
            }
            return style
        }
        let host = try style(["dataSource": .string("openMeteo")])
        #expect(host.dataSource == .openMeteo)
        #expect(host.cachedWeather == payload)

        let manual = try style(["dataSource": .string("manual")])
        #expect(manual.dataSource == .manual)
        #expect(manual.cachedWeather == nil)
    }

    @Test func hostSnapshotFeedsWeatherCurrent() throws {
        let payload = WeatherPayload(
            condition: .rain, temperatureCelsius: 8, humidity: 94,
            highTemperatureCelsius: 11, lowTemperatureCelsius: 5,
            windKph: 18, feelsLikeCelsius: 4, resolvedLocation: "Shanghai",
            sourceDate: nil
        )
        let data = OverlayComponentActivityData(
            activity: OverlayComponentWeatherWidgetParityTests.activity(),
            elapsedTime: 90, zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720), elementScale: 1,
            weatherPayload: payload
        )
        guard case .record(let record) = data.signal(path: "weather.current") else {
            Issue.record("weather.current should be a record")
            return
        }
        #expect(record["condition"] == .string("rain"))
        #expect(record["temperatureC"] == .number(8))
        #expect(record["humidity"] == .number(94))
        #expect(record["icon"] == .string(WeatherCondition.rain.sfSymbolName))
    }
}

#if canImport(CSkiaBridge)
@Suite(.serialized, .skiaSerialized)
struct OverlayComponentWeatherWidgetParityTests {
    static func activity() -> ActivityTimeline {
        let start = Date(timeIntervalSince1970: 1_735_689_600)
        var records: [ActivityRecord] = []
        var t: TimeInterval = 0
        while t <= 600 {
            records.append(ActivityRecord(
                elapsedTime: t, timestamp: start.addingTimeInterval(t),
                distanceMeters: t * 3.2, heartRate: 148,
                paceSecondsPerKilometer: 312, elevationMeters: 20,
                cadence: 176, powerWatts: 245, calories: t / 4,
                temperatureCelsius: 17
            ))
            t += 1
        }
        return ActivityTimeline(
            startDate: start, duration: 600, distanceMeters: 1920,
            records: records,
            laps: [LapRecord(
                lapIndex: 0, startElapsedTime: 0, endElapsedTime: 600,
                startDistanceMeters: 0, totalDistanceMeters: 1920,
                totalElapsedTime: 600, avgPaceSecondsPerKm: 312,
                avgHeartRate: 152, maxHeartRate: 160, avgCadenceSPM: 176,
                avgPowerWatts: 245, totalAscent: 30, kind: .active
            )]
        )
    }

    private static func style(
        preset: WeatherWidgetPreset = .simpleCard,
        condition: WeatherCondition = .sunny,
        temperature: Double = 13,
        humidity: Double = 87,
        high: Double = 16,
        low: Double = 11,
        wind: Double = 12,
        feelsLike: Double = 21,
        unit: WeatherTemperatureUnit = .celsius,
        useFIT: Bool = false,
        showLocation: Bool = true,
        showWeekday: Bool = true,
        showHumidity: Bool = true,
        showHighLow: Bool = false,
        showWind: Bool = false,
        showFeelsLike: Bool = false,
        showIcon: Bool = true,
        showConditionLabel: Bool = true,
        cardOpacity: Double = 0.92,
        cardRadius: Double = 10,
        divider: Bool = true,
        palette: WeatherWidgetPalette = .blueGlass,
        location: String = "",
        cached: WeatherPayload? = nil,
        dataSource: WeatherDataSource = .manual
    ) -> WeatherWidgetStyle {
        var style = WeatherWidgetStyle.preset(preset)
        style.dataSource = dataSource
        style.cachedWeather = cached
        style.manualCondition = condition
        style.manualTemperatureCelsius = temperature
        style.manualHumidity = humidity
        style.manualHigh = high
        style.manualLow = low
        style.manualWind = wind
        style.manualFeelsLike = feelsLike
        style.temperatureUnit = unit
        style.useFITTemperature = useFIT
        style.locationText = location
        style.showLocation = showLocation
        style.showWeekday = showWeekday
        style.showHumidity = showHumidity
        style.showHighLow = showHighLow
        style.showWind = showWind
        style.showFeelsLike = showFeelsLike
        style.showIcon = showIcon
        style.showConditionLabel = showConditionLabel
        style.cardBackgroundOpacity = cardOpacity
        style.cardCornerRadius = cardRadius
        style.dividerEnabled = divider
        style.palette = palette
        var slots: [WeatherMetricSlotValue] = []
        if showHumidity { slots.append(.humidity) }
        if showHighLow { slots.append(.highLow) }
        if showWind { slots.append(.wind) }
        if showFeelsLike { slots.append(.feelsLike) }
        style.metricSlots = slots.isEmpty ? preset.defaultMetricSlots : slots
        return style
    }

    private static func colorHex(_ color: OverlayColor) -> String {
        let red = Int((color.red * 255).rounded())
        let green = Int((color.green * 255).rounded())
        let blue = Int((color.blue * 255).rounded())
        if color.alpha < 0.999 {
            let alpha = Int((color.alpha * 255).rounded())
            return String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
        }
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    private static func textParameters(
        _ style: WeatherTextStyle, prefix: String,
        into result: inout [String: OverlayJSONValue]
    ) {
        result["\(prefix)FontSize"] = .number(style.fontSize)
        result["\(prefix)FontWeight"] = .string(style.fontWeight.rawValue)
        result["\(prefix)Color"] = .string(colorHex(style.color))
    }

    private static func parameters(_ style: WeatherWidgetStyle) -> [String: OverlayJSONValue] {
        var result: [String: OverlayJSONValue] = [
            "usePresetSize": .boolean(false),
            "componentWidth": .number(style.width),
            "componentHeight": .number(style.height),
            "preset": .string(style.preset.rawValue),
            "condition": .string(style.manualCondition.rawValue),
            "temperatureC": .number(style.manualTemperatureCelsius),
            "humidity": .number(style.manualHumidity),
            "highC": .number(style.manualHigh),
            "lowC": .number(style.manualLow),
            "windKph": .number(style.manualWind),
            "feelsLikeC": .number(style.manualFeelsLike),
            "temperatureUnit": .string(style.temperatureUnit.rawValue),
            "useActivityTemperature": .boolean(style.useFITTemperature),
            "locationText": .string(style.locationText),
            "showLocation": .boolean(style.showLocation),
            "showWeekday": .boolean(style.showWeekday),
            "showHumidity": .boolean(style.showHumidity),
            "showHighLow": .boolean(style.showHighLow),
            "showWind": .boolean(style.showWind),
            "showFeelsLike": .boolean(style.showFeelsLike),
            "showIcon": .boolean(style.showIcon),
            "showConditionLabel": .boolean(style.showConditionLabel),
            "conditionLabelOverride": .string(style.conditionLabelOverride),
            "humiditySuffix": .string(style.humiditySuffix),
            "humidityMetricLabel": .string(style.humidityMetricLabel),
            "windMetricLabel": .string(style.windMetricLabel),
            "feelsLikeMetricLabel": .string(style.feelsLikeMetricLabel),
            "cardBackgroundColor": .string(colorHex(style.cardBackgroundColor)),
            "cardBackgroundOpacity": .number(style.cardBackgroundOpacity),
            "cardCornerRadius": .number(style.cardCornerRadius),
            "dividerEnabled": .boolean(style.dividerEnabled),
            "dividerColor": .string(colorHex(style.dividerColor)),
            "dividerThickness": .number(style.dividerThickness),
            "dividerOpacity": .number(style.dividerOpacity),
            "palette": .string(style.palette.rawValue),
            "iconSize": .number(style.iconSize),
            "slotBackgroundColor": .string(colorHex(style.slotBackgroundColor)),
            "slotBackgroundOpacity": .number(style.slotBackgroundOpacity),
            "slotSpacing": .number(style.slotSpacing),
            "fontFamily": .string(style.locationTextStyle.fontName)
        ]
        textParameters(style.locationTextStyle, prefix: "location", into: &result)
        textParameters(style.conditionTextStyle, prefix: "condition", into: &result)
        textParameters(style.temperatureTextStyle, prefix: "temperature", into: &result)
        textParameters(style.slotTitleTextStyle, prefix: "slotTitle", into: &result)
        textParameters(style.slotLabelTextStyle, prefix: "slotLabel", into: &result)
        return result
    }

    @Test func weatherWidgetMatchesNative() throws {
        try OverlayPreferenceFixtures.withDefaults {
            let reference = try OverlayComponentReference(
                definitionData: OverlayComponentWeatherWidgetTests.data(), source: .bundled
            )
            let activity = Self.activity()
            let canvas = CGSize(width: 1280, height: 720)
            let snapshot = WeatherPayload(
                condition: .cloudy, temperatureCelsius: 9, humidity: 71,
                highTemperatureCelsius: 12, lowTemperatureCelsius: 6,
                windKph: 22, feelsLikeCelsius: 6,
                resolvedLocation: "Shanghai", sourceDate: nil
            )
            let cases: [(String, WeatherWidgetStyle, Double, TimeInterval)] = [
                ("simple-card", Self.style(location: "Shanghai"), 1, 90),
                ("compact-strip", Self.style(preset: .compactStrip, location: "Shanghai"), 1, 90),
                ("forecast-tile", Self.style(preset: .forecastTile, location: "Shanghai"), 1, 90),
                ("minimal-text", Self.style(preset: .minimalText, location: "Shanghai"), 1, 90),
                ("dashboard-bar", Self.style(preset: .dashboardBar, location: "Shanghai"), 1, 90),
                ("rain", Self.style(condition: .rain, location: "Shanghai"), 1, 90),
                ("no-icon", Self.style(showIcon: false, location: "Shanghai"), 1, 90),
                ("no-condition", Self.style(showConditionLabel: false, location: "Shanghai"), 1, 90),
                ("no-location", Self.style(showLocation: false), 1, 90),
                ("no-weekday", Self.style(showWeekday: false, location: "Shanghai"), 1, 90),
                ("fahrenheit", Self.style(unit: .fahrenheit, location: "Shanghai"), 1, 90),
                ("palette-graphite", Self.style(palette: .graphite, location: "Shanghai"), 1, 90),
                ("all-metrics", Self.style(
                    showHighLow: true, showWind: true, showFeelsLike: true,
                    location: "Shanghai"
                ), 1, 90),
                ("flat-card", Self.style(
                    preset: .forecastTile, cardOpacity: 0, cardRadius: 0,
                    divider: false, location: "Shanghai"
                ), 1, 90),
                ("activity-temperature", Self.style(useFIT: true, location: "Shanghai"), 1, 90),
                ("host-snapshot", Self.style(
                    condition: .sunny, temperature: 13, location: "",
                    cached: snapshot, dataSource: .openMeteo
                ), 1, 90),
                ("scaled", Self.style(location: "Shanghai"), 1.5, 90),
                ("late", Self.style(location: "Shanghai"), 1, 420)
            ]
            for (label, style, elementScale, time) in cases {
                let native = OverlayElement(
                    type: .weatherWidget, position: CGPoint(x: 0.5, y: 0.5),
                    scale: elementScale, style: {
                        var hostStyle = OverlayStyle.default
                        // Native weather modules draw their own card shadow and
                        // ignore element-level effects; keep the host layer off
                        // so both paths composite the same pixels.
                        hostStyle.shadowEnabled = false
                        hostStyle.glowEnabled = false
                        hostStyle.weatherWidget = style
                        return hostStyle
                    }()
                )
                let context = OverlayRenderContext(
                    canvasSize: canvas, activity: activity, elapsedTime: time
                )
                let layout = OverlayRenderModel.weatherWidgetLayout(for: native, in: context)
                let component = OverlayElement(
                    type: .component,
                    position: CGPoint(
                        x: layout.rect.minX / canvas.width,
                        y: layout.rect.minY / canvas.height
                    ),
                    scale: elementScale,
                    style: native.style,
                    component: OverlayComponentInstance(
                        reference: reference,
                        parameters: Self.parameters(style)
                    )
                )
                let frame = try #require(
                    OverlayComponentSkiaRenderer.frame(for: component, renderContext: context)
                )
                #expect(abs(frame.width - layout.rect.width) < 0.5, "\(label) width")
                #expect(abs(frame.height - layout.rect.height) < 0.5, "\(label) height")
                // The component clip ends at the card bounds, so the module's
                // own soft card shadow is trimmed to an alpha-only fringe on
                // the widest graphite preset.
                let ratio = label == "scaled" ? 0.005
                    : (label == "dashboard-bar" ? 0.01 : 0.0035)
                try NativeComponentParityHarness.assertParity(
                    label: "weather-\(label)",
                    native: OverlayLayout(elements: [native]),
                    component: OverlayLayout(elements: [component]),
                    activity: activity,
                    elapsedTime: time,
                    size: canvas,
                    thresholds: .init(
                        channelTolerance: 2,
                        maximumChangedPixelRatio: ratio,
                        maximumChannelDelta: 80,
                        maximumMeanChannelDelta: 0.13
                    )
                )
            }
        }
    }
}
#endif
