import Foundation
import Testing
@testable import RunningOverlay

@MainActor
struct OverlayTemplateTests {
    @Test func saveOverlayTemplatePersistsLayout() throws {
        let storeURL = temporaryTemplateURL()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let project = ProjectDocument(overlayTemplateStore: OverlayTemplateStore(fileURL: storeURL))
        project.addOverlayElement(.heartRate)
        let elementID = try #require(project.overlayLayout.elements.first?.id)
        project.moveOverlay(elementID, to: CGPoint(x: 0.2, y: 0.8))
        project.setOverlayScale(elementID, scale: 1.5)
        project.setOverlayForegroundColor(elementID, color: .cyan)
        project.setOverlayTextPreset(elementID, textPreset: .sportWatch)
        project.setOverlayGaugePreset(elementID, gaugePreset: .techFuture)
        project.saveOverlayTemplate(named: "Race Layout")

        let loadedProject = ProjectDocument(overlayTemplateStore: OverlayTemplateStore(fileURL: storeURL))
        let template = try #require(loadedProject.overlayTemplates.first)

        #expect(template.schemaVersion == 2)
        #expect(template.name == "Race Layout")
        #expect(template.referenceResolution == OverlayTemplateResolution(width: 1920, height: 1080))
        #expect(template.elements.count == 1)
        #expect(template.elements[0].type == .heartRate)
        #expect(template.elements[0].positionX == 0.2)
        #expect(template.elements[0].positionY == 0.8)
        #expect(template.elements[0].scale == 1.5)
        #expect(template.elements[0].style.foregroundColor == .cyan)
        #expect(template.elements[0].style.textPreset == .sportWatch)
        #expect(template.elements[0].style.gaugePreset == .techFuture)
    }

    @Test func overlayStyleDecodesLegacyTemplatesWithDefaultStylePresets() throws {
        let json = """
        {
          "fontName": "SF Pro",
          "fontSize": 28,
          "fontWeight": "semibold",
          "foregroundColor": { "red": 1, "green": 1, "blue": 1, "alpha": 1 },
          "backgroundOpacity": 0.22,
          "shadowOpacity": 0.35,
          "shadowRadius": 4
        }
        """

        let style = try JSONDecoder().decode(OverlayStyle.self, from: Data(json.utf8))

        #expect(style.textPreset == .minimal)
        #expect(style.gaugePreset == .minimalSport)
        #expect(style.distanceTimeline.preset == .minimal)
    }

    @Test func intervalHUDBarStyleDecodesOlderFieldsWithDefaults() throws {
        let json = """
        {
          "width": 640,
          "height": 108,
          "bottomBarMode": "lapProgress",
          "progressMode": "time",
          "hrDropMode": "bpm",
          "metricSlots": [
            { "metric": "heartRateZone" },
            { "metric": "heartRate" },
            { "metric": "pace" },
            { "metric": "hrDrop" }
          ],
          "phaseColorFallback": { "red": 1, "green": 0.38, "blue": 0.14, "alpha": 1 },
          "trackColor": { "red": 1, "green": 1, "blue": 1, "alpha": 1 },
          "trackOpacity": 0.14
        }
        """

        let style = try JSONDecoder().decode(IntervalHUDBarStyle.self, from: Data(json.utf8))

        #expect(style.width == 640)
        #expect(style.height == 108)
        #expect(style.bottomBarEnabled == true)
        #expect(style.remainingPrimary == .time)
        #expect(style.showsRep == true)
        #expect(style.showsPhase == true)
        #expect(style.showsRemaining == true)
        #expect(style.showsZone == true)
        #expect(style.zoneDisplayMode == .hrDropAtRest)
        #expect(style.metricSlots.map(\.metric) == [.heartRate, .pace])
        #expect(style.metricSlots.map(\.unitOption) == [.bpm, .paceMetric])
        #expect(style.metricSlots.allSatisfy { $0.id.uuidString.isEmpty == false })
        #expect(style.bottomBarSpacing == IntervalHUDBarStyle.default.bottomBarSpacing)
        #expect(style.activeZoneWidthShare == IntervalHUDBarStyle.default.activeZoneWidthShare)
        #expect(style.inactiveZoneOpacity == IntervalHUDBarStyle.default.inactiveZoneOpacity)
        #expect(style.zoneMarkerEnabled == IntervalHUDBarStyle.default.zoneMarkerEnabled)
        #expect(style.zoneMarkerPosition == IntervalHUDBarStyle.default.zoneMarkerPosition)
        #expect(style.zoneMarkerShowsValue == IntervalHUDBarStyle.default.zoneMarkerShowsValue)
        #expect(style.labelText == IntervalHUDBarStyle.default.labelText)
        #expect(style.metricUnitText == IntervalHUDBarStyle.default.metricUnitText)
    }

    @Test func distanceTimelineIconSlotPersistsEmbeddedSVG() throws {
        var style = OverlayStyle.default
        style.distanceTimeline = .preset(.sport)
        style.distanceTimeline.mediaSlot.mode = .animatedSVG
        style.distanceTimeline.mediaSlot.assetName = "runner.svg"
        style.distanceTimeline.mediaSlot.svgSource = "<svg viewBox=\"0 0 24 24\"><path d=\"M2 12 L22 12\" stroke=\"currentColor\"/></svg>"

        let data = try JSONEncoder().encode(style)
        let decoded = try JSONDecoder().decode(OverlayStyle.self, from: data)

        #expect(decoded.distanceTimeline.mediaSlot.mode == .animatedSVG)
        #expect(decoded.distanceTimeline.mediaSlot.assetName == "runner.svg")
        #expect(decoded.distanceTimeline.mediaSlot.svgSource.contains("<path"))
    }

    @Test func weatherWidgetStyleRoundTripsNewFields() throws {
        var style = OverlayStyle.default
        style.weatherWidget = .preset(.dashboardBar)
        style.weatherWidget.conditionLabelOverride = "小雨"
        style.weatherWidget.humiditySuffix = "RH"
        style.weatherWidget.humidityMetricLabel = "湿度"
        style.weatherWidget.windMetricLabel = "風"
        style.weatherWidget.feelsLikeMetricLabel = "体感"
        style.weatherWidget.palette = .lightGlass
        style.weatherWidget.showIcon = false
        style.weatherWidget.metricSlots = [.none, .wind, .highLow]
        style.weatherWidget.dividerEnabled = false
        style.weatherWidget.dividerColor = .cyan
        style.weatherWidget.dividerThickness = 3
        style.weatherWidget.dividerOpacity = 0.42
        style.weatherWidget.cachedWeather = WeatherPayload(
            condition: .rain,
            temperatureCelsius: 13,
            humidity: 87,
            highTemperatureCelsius: 16,
            lowTemperatureCelsius: 11,
            windKph: 9,
            feelsLikeCelsius: 12,
            resolvedLocation: "大阪, 日本",
            sourceDate: Date(timeIntervalSince1970: 1_000)
        )

        let data = try JSONEncoder().encode(style)
        let decoded = try JSONDecoder().decode(OverlayStyle.self, from: data)

        #expect(decoded.weatherWidget.conditionLabelOverride == "小雨")
        #expect(decoded.weatherWidget.humidityMetricLabel == "湿度")
        #expect(decoded.weatherWidget.windMetricLabel == "風")
        #expect(decoded.weatherWidget.feelsLikeMetricLabel == "体感")
        #expect(decoded.weatherWidget.palette == .lightGlass)
        #expect(decoded.weatherWidget.showIcon == false)
        #expect(decoded.weatherWidget.metricSlots == [.none, .wind, .highLow])
        #expect(decoded.weatherWidget.dividerEnabled == false)
        #expect(decoded.weatherWidget.dividerColor == .cyan)
        #expect(decoded.weatherWidget.dividerThickness == 3)
        #expect(decoded.weatherWidget.dividerOpacity == 0.42)
        #expect(decoded.weatherWidget.cachedWeather?.resolvedLocation == "大阪, 日本")
    }

    @Test func weatherWidgetStyleDecodesLegacyWeatherFieldsWithDefaults() throws {
        let json = """
        {
          "weatherWidget": {
            "preset": "simpleCard",
            "dataSource": "manual",
            "manualCondition": "rain",
            "manualTemperatureCelsius": 13,
            "manualHumidity": 87,
            "manualHigh": 16,
            "manualLow": 11,
            "manualWind": 9,
            "manualFeelsLike": 12,
            "temperatureUnit": "celsius",
            "locationText": "大阪, 日本",
            "showLocation": true,
            "showWeekday": true,
            "showHumidity": true,
            "showHighLow": false,
            "showWind": false,
            "showFeelsLike": false,
            "cardBackgroundColor": { "red": 0, "green": 0, "blue": 0, "alpha": 1 },
            "cardBackgroundOpacity": 0.6,
            "cardCornerRadius": 10,
            "iconSize": 36,
            "showConditionLabel": true,
            "width": 300,
            "height": 110
          }
        }
        """

        let decoded = try JSONDecoder().decode(OverlayStyle.self, from: Data(json.utf8))

        #expect(decoded.weatherWidget.conditionLabelOverride == "")
        #expect(decoded.weatherWidget.humiditySuffix == "RH")
        #expect(decoded.weatherWidget.humidityMetricLabel == "RH")
        #expect(decoded.weatherWidget.palette == .blueGlass)
        #expect(decoded.weatherWidget.showIcon == true)
        #expect(decoded.weatherWidget.metricSlots == [.humidity])
        #expect(decoded.weatherWidget.dividerEnabled == true)
        #expect(decoded.weatherWidget.dividerColor == .white)
        #expect(decoded.weatherWidget.dividerThickness == 1)
        #expect(decoded.weatherWidget.dividerOpacity == 0.34)
    }

    @Test func applyWeatherWidgetPresetPreservesContentAndCachedData() throws {
        let project = ProjectDocument(overlayTemplateStore: OverlayTemplateStore(fileURL: temporaryTemplateURL()))
        project.addOverlayElement(.weatherWidget)
        let id = try #require(project.overlayLayout.elements.first?.id)
        project.mutateWeatherWidgetStyle(id) { style in
            style.manualCondition = .snow
            style.manualTemperatureCelsius = -2
            style.conditionLabelOverride = "Snow"
            style.locationText = "Sapporo, Japan"
            style.showIcon = false
            style.metricSlots = [.wind]
            style.dividerEnabled = false
            style.dividerColor = .yellow
            style.dividerThickness = 4
            style.dividerOpacity = 0.5
            style.cachedWeather = WeatherPayload(
                condition: .snow,
                temperatureCelsius: -2,
                humidity: 80,
                highTemperatureCelsius: 0,
                lowTemperatureCelsius: -6,
                windKph: 12,
                feelsLikeCelsius: -5,
                resolvedLocation: "Sapporo, Japan",
                sourceDate: nil
            )
        }

        project.applyWeatherWidgetPreset(id, preset: .dashboardBar)
        let updated = try #require(project.overlayLayout.elements.first?.style.weatherWidget)

        #expect(updated.preset == .dashboardBar)
        #expect(updated.manualCondition == .snow)
        #expect(updated.manualTemperatureCelsius == -2)
        #expect(updated.conditionLabelOverride == "Snow")
        #expect(updated.locationText == "Sapporo, Japan")
        #expect(updated.showIcon == false)
        #expect(updated.metricSlots == [.wind, .wind, .feelsLike])
        #expect(updated.dividerEnabled == false)
        #expect(updated.dividerColor == .yellow)
        #expect(updated.dividerThickness == 4)
        #expect(updated.dividerOpacity == 0.5)
        #expect(updated.cachedWeather?.condition == .snow)
        #expect(abs(updated.width - Double(WeatherWidgetPreset.dashboardBar.defaultSize.width)) < 0.001)
    }

    @Test func applyOverlayTemplateIsUndoable() throws {
        let storeURL = temporaryTemplateURL()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let project = ProjectDocument(overlayTemplateStore: OverlayTemplateStore(fileURL: storeURL))
        project.addOverlayElement(.pace)
        let originalID = try #require(project.overlayLayout.elements.first?.id)

        let template = OverlayTemplate(
            name: "Minimal",
            elements: [
                OverlayTemplateElement(
                    type: .distance,
                    positionX: 0.1,
                    positionY: 0.2,
                    scale: 2,
                    style: .default
                )
            ]
        )
        project.overlayTemplates = [template]

        project.applyOverlayTemplate(template.id)
        #expect(project.overlayLayout.elements.count == 1)
        #expect(project.overlayLayout.elements[0].type == .distance)
        #expect(project.overlayLayout.elements[0].id != originalID)

        project.undo()
        #expect(project.overlayLayout.elements.count == 1)
        #expect(project.overlayLayout.elements[0].type == .pace)
        #expect(project.overlayLayout.elements[0].id == originalID)
    }

    @Test func templatePoolManagementActionsPersist() throws {
        let storeURL = temporaryTemplateURL()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let project = ProjectDocument(overlayTemplateStore: OverlayTemplateStore(fileURL: storeURL))
        project.addOverlayElement(.distance)

        project.saveCurrentOverlayTemplateWithGeneratedName()
        let saved = try #require(project.overlayTemplates.first)
        #expect(saved.name == "Template")

        project.renameOverlayTemplate(saved.id, to: "Long Run")
        #expect(project.overlayTemplates.first?.name == "Long Run")

        project.duplicateOverlayTemplate(saved.id)
        #expect(project.overlayTemplates.count == 2)
        #expect(project.overlayTemplates[0].name == "Long Run Copy")

        let loadedProject = ProjectDocument(overlayTemplateStore: OverlayTemplateStore(fileURL: storeURL))
        #expect(loadedProject.overlayTemplates.map(\.name) == ["Long Run Copy", "Long Run"])
    }

    @Test func builtInOverlayTemplateReplacesLayoutAndIsUndoable() throws {
        let storeURL = temporaryTemplateURL()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let project = ProjectDocument(overlayTemplateStore: OverlayTemplateStore(fileURL: storeURL))
        project.addOverlayElement(.pace)
        let originalID = try #require(project.overlayLayout.elements.first?.id)
        let race = try #require(BuiltInOverlayTemplate.all.first { $0.id == "race" })

        project.applyBuiltInOverlayTemplate(race)
        #expect(project.overlayLayout.elements.map(\.type) == [.distanceTimeline, .runningGauge, .routeMap, .pace])
        #expect(project.overlayLayout.elements.first?.id != originalID)
        #expect(project.selection == .none)

        project.undo()
        #expect(project.overlayLayout.elements.count == 1)
        #expect(project.overlayLayout.elements[0].type == .pace)
        #expect(project.overlayLayout.elements[0].id == originalID)
    }

    @Test func easyRunBuiltInTemplateLoadsBundledTemplateFile() throws {
        let storeURL = temporaryTemplateURL()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let project = ProjectDocument(overlayTemplateStore: OverlayTemplateStore(fileURL: storeURL))
        project.addOverlayElement(.elapsedTime)
        let easyRun = try #require(BuiltInOverlayTemplate.all.first { $0.id == "easyRun" })

        project.applyBuiltInOverlayTemplate(easyRun)

        #expect(project.overlayLayout.elements.map(\.type) == [.pace, .heartRate, .cadence, .routeMap, .distanceTimeline])
        #expect(project.overlayLayout.elements.first?.position.x == 0.2102358908061998)
        #expect(project.overlayLayout.elements.first?.position.y == 0.9049159976211716)
        #expect(project.overlayLayout.elements.first?.style.textPreset == .splitLabel)
    }

    private func temporaryTemplateURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("RunningOverlayTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("OverlayTemplates.json")
    }
}
