import Foundation
import Testing
@testable import RunningOverlay

struct OverlayRenderModelTests {
    @Test func scalesTextLayoutFromReferenceCanvas() {
        let element = OverlayElement(type: .heartRate, position: CGPoint(x: 0.25, y: 0.75), scale: 1, style: .default)
        let context = OverlayRenderContext(
            canvasSize: CGSize(width: 1920, height: 1080),
            activity: sampleActivity(),
            elapsedTime: 5
        )

        let layout = OverlayRenderModel.textLayout(for: element, in: context)

        #expect(layout.value == "110 bpm")
        #expect(layout.fontSize == 42)
        #expect(layout.horizontalPadding == 15)
        #expect(layout.verticalPadding == 9)
        #expect(layout.iconSystemName == "heart")
    }

    @Test func numericOverlayMinimumSizeScalesWithCanvasAndElement() {
        var style = OverlayStyle.default
        style.numericMinWidth = 120
        style.numericMinHeight = 44
        let element = OverlayElement(type: .heartRate, position: CGPoint(x: 0.5, y: 0.5), scale: 1.25, style: style)
        let context = OverlayRenderContext(
            canvasSize: CGSize(width: 1920, height: 1080),
            activity: sampleActivity(),
            elapsedTime: 5
        )

        let layout = OverlayRenderModel.textLayout(for: element, in: context)

        #expect(layout.minimumWidth == 225)
        #expect(layout.minimumHeight == 82.5)
    }

    @Test func numericOverlayForcesMinimalStyleAndDisablesDivider() {
        var style = OverlayStyle.default
        style.textPreset = .splitLabel
        style.dividerEnabled = true
        style.dividerThickness = 4
        let element = OverlayElement(type: .pace, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: style)
        let context = OverlayRenderContext(
            canvasSize: OverlayRenderContext.referenceCanvasSize,
            activity: sampleActivity(),
            elapsedTime: 5
        )

        let layout = OverlayRenderModel.textLayout(for: element, in: context)

        #expect(layout.preset == .minimal)
        #expect(layout.dividerEnabled == false)
    }

    @Test func numericOverlayIconLayoutScalesFromStyle() {
        var style = OverlayStyle.default
        style.iconEnabled = true
        style.iconSystemName = "bolt"
        style.iconPosition = .top
        style.iconTextAlignment = .trailing
        style.iconSize = 24
        style.iconSpacing = 6
        style.iconColor = .yellow
        style.iconOpacity = 0.65
        let element = OverlayElement(type: .power, position: CGPoint(x: 0.5, y: 0.5), scale: 1.25, style: style)
        let context = OverlayRenderContext(
            canvasSize: CGSize(width: 1920, height: 1080),
            activity: sampleActivity(),
            elapsedTime: 5
        )

        let layout = OverlayRenderModel.textLayout(for: element, in: context)

        #expect(layout.iconEnabled)
        #expect(layout.iconSystemName == "bolt")
        #expect(layout.iconPosition == .top)
        #expect(layout.iconTextAlignment == .trailing)
        #expect(layout.iconSize == 45)
        #expect(layout.iconSpacing == 11.25)
        #expect(layout.iconColor == .yellow)
        #expect(layout.iconOpacity == 0.65)
    }

    @Test func distanceTimelineLayoutUsesSharedProgressAndGeometry() {
        let element = OverlayElement(type: .distanceTimeline, position: CGPoint(x: 0.5, y: 0.25), scale: 1, style: .default)
        let context = OverlayRenderContext(
            canvasSize: OverlayRenderContext.referenceCanvasSize,
            activity: sampleActivity(),
            elapsedTime: 5
        )

        let layout = OverlayRenderModel.distanceTimelineLayout(for: element, in: context)

        #expect(layout.label == "Distance")
        #expect(layout.valueText == "0.05 / 0.10 km")
        #expect(layout.progress == 0.5)
        #expect(layout.style.preset == .minimal)
        #expect(layout.rect.width == 280)
        #expect(layout.rect.height == 68)
        #expect(layout.rect.midX == 640)
        #expect(layout.rect.midY == 180)
        #expect(layout.trackRect.width == 252)
        #expect(layout.trackRect.height == 6)
    }

    @Test func distanceTimelineDistanceAxisLabelModeFormatsOriginWithUnit() {
        var style = OverlayStyle.default
        style.distanceTimeline.axisLabelMode = .distance
        let element = OverlayElement(type: .distanceTimeline, position: CGPoint(x: 0.5, y: 0.25), scale: 1, style: style)
        let context = OverlayRenderContext(
            canvasSize: OverlayRenderContext.referenceCanvasSize,
            activity: sampleActivity(),
            elapsedTime: 5
        )

        let layout = OverlayRenderModel.distanceTimelineLayout(for: element, in: context)

        #expect(layout.startText == "0 km")
        #expect(layout.finishText == "0.10 km")
        #expect(layout.markerDistanceText == "0.05 km")
    }

    @Test func distanceTimelineAxisLabelTrackPlacementComputesTextTopY() {
        let style = DistanceTimelineStyle.default
        let track = CGRect(x: 0, y: 50, width: 100, height: 6)
        let gap: CGFloat = 4
        let textH: CGFloat = 13
        #expect(style.distanceTimelineAxisLabelTextTopY(trackRect: track, placement: .below, scaledGap: gap, textLineHeight: textH) == track.maxY + gap)
        #expect(style.distanceTimelineAxisLabelTextTopY(trackRect: track, placement: .above, scaledGap: gap, textLineHeight: textH) == track.minY - gap - textH)
    }

    @Test func distanceTimelinePresetLayoutIncludesSportMediaSlotAndRouteElevation() {
        var sportStyle = OverlayStyle.default
        sportStyle.distanceTimeline = .preset(.sport)
        let sportElement = OverlayElement(type: .distanceTimeline, position: CGPoint(x: 0.5, y: 0.25), scale: 1, style: sportStyle)
        let context = OverlayRenderContext(canvasSize: OverlayRenderContext.referenceCanvasSize, activity: sampleActivity(), elapsedTime: 5)

        let sportLayout = OverlayRenderModel.distanceTimelineLayout(for: sportElement, in: context)

        #expect(sportLayout.style.preset == .sport)
        #expect(sportLayout.mediaSlotRect != nil)
        #expect(sportLayout.style.showPercent)

        var routeStyle = OverlayStyle.default
        routeStyle.distanceTimeline = .preset(.route)
        let routeElement = OverlayElement(type: .distanceTimeline, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: routeStyle)

        let routeLayout = OverlayRenderModel.distanceTimelineLayout(for: routeElement, in: context)

        #expect(routeLayout.style.preset == .route)
        #expect(routeLayout.style.elevationProfileVisible)
        #expect(routeLayout.elevationSamples == [100, 110])
    }

    @Test func distanceTimelineRoutePresetProjectsGpsRouteWhenAvailable() throws {
        var style = OverlayStyle.default
        style.distanceTimeline = .preset(.route)
        let element = OverlayElement(type: .distanceTimeline, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: style)
        let context = OverlayRenderContext(
            canvasSize: OverlayRenderContext.referenceCanvasSize,
            activity: sampleRouteActivity(),
            elapsedTime: 5
        )

        let layout = OverlayRenderModel.distanceTimelineLayout(for: element, in: context)

        #expect(layout.routePoints.count == 3)
        let current = try #require(layout.routeCurrentPoint)
        let bounds = layout.contentRect.insetBy(dx: -1, dy: -1)
        for point in layout.routePoints {
            #expect(bounds.contains(point))
        }
        #expect(bounds.contains(current))
    }

    @Test func elevationChartLayoutCarriesSamplesAndProgress() {
        let element = OverlayElement(type: .elevationChart, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: .default)
        let context = OverlayRenderContext(
            canvasSize: OverlayRenderContext.referenceCanvasSize,
            activity: sampleActivity(),
            elapsedTime: 5
        )

        let layout = OverlayRenderModel.elevationChartLayout(for: element, in: context)

        #expect(layout.label == "Elevation 105 m")
        #expect(layout.progress == 0.5)
        #expect(layout.samples == [100, 110])
        #expect(layout.style.preset == .gradientArea)
        #expect(layout.statsBarItems.count == 3)
        #expect(layout.chartHeight == 78)
    }

    @Test func elevationChartSmoothingSoftensQuantizedStairStepsAndPreservesEndpoints() {
        let samples = [100.0, 100, 100, 110, 110, 110]

        let smoothed = OverlayRenderModel.smoothedElevationChartSamples(samples)

        #expect(smoothed.first == samples.first)
        #expect(smoothed.last == samples.last)
        #expect(smoothed != samples)
        #expect(smoothed[2] > samples[2])
        #expect(smoothed[3] < samples[3])
    }

    @Test func runningGaugeLayoutCarriesCoreMetricsAndProgress() {
        let element = OverlayElement(type: .runningGauge, position: CGPoint(x: 0.4, y: 0.6), scale: 1, style: .default)
        let context = OverlayRenderContext(
            canvasSize: OverlayRenderContext.referenceCanvasSize,
            activity: sampleActivity(),
            elapsedTime: 5
        )

        let layout = OverlayRenderModel.runningGaugeLayout(for: element, in: context)

        // Default style preset is `.roadRun` whose layout preset is
        // `.topTwoMiddleBottom`. Verify the canonical four regions land in
        // the right slots with expected metric values bound.
        let regions = Dictionary(uniqueKeysWithValues: layout.regions.map { ($0.config.region, $0) })
        #expect(regions[.top]?.components.value == "0.05")
        #expect(regions[.middleLeft]?.components.value == "--'--\"")
        #expect(regions[.middleRight]?.components.value == "00:00:05")
        #expect(regions[.bottom]?.components.value == "110")
        #expect(layout.progress == 0.5)
        #expect(layout.rect.width == 300)
        #expect(layout.rect.midX == 512)
        #expect(layout.rect.midY == 432)
        #expect(layout.style.layoutPreset == .topTwoMiddleBottom)
        #expect(layout.style.stylePreset == .roadRun)
    }

    @Test func weatherWidgetLayoutHonorsFITManualAndOpenMeteoSources() {
        var style = OverlayStyle.default
        style.weatherWidget = .preset(.simpleCard)
        style.weatherWidget.dataSource = .fitTemperature
        style.weatherWidget.manualTemperatureCelsius = 13
        style.weatherWidget.manualCondition = .rain
        style.weatherWidget.locationText = "大阪, 日本"
        style.weatherWidget.cachedWeather = WeatherPayload(
            condition: .sunny,
            temperatureCelsius: 30,
            humidity: 10,
            highTemperatureCelsius: 31,
            lowTemperatureCelsius: 25,
            windKph: 4,
            feelsLikeCelsius: 32,
            resolvedLocation: "Cached",
            sourceDate: nil
        )
        let element = OverlayElement(type: .weatherWidget, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: style)
        let context = OverlayRenderContext(canvasSize: OverlayRenderContext.referenceCanvasSize, activity: sampleWeatherActivity(), elapsedTime: 5)

        let fitLayout = OverlayRenderModel.weatherWidgetLayout(for: element, in: context)
        #expect(fitLayout.temperatureFormatted == "15°C")
        #expect(fitLayout.condition == .rain)
        #expect(fitLayout.locationText == "大阪, 日本")
        #expect(fitLayout.conditionLabel == "雨")

        var manualStyle = style
        manualStyle.weatherWidget.dataSource = .manual
        let manualElement = OverlayElement(type: .weatherWidget, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: manualStyle)
        let manualLayout = OverlayRenderModel.weatherWidgetLayout(for: manualElement, in: context)
        #expect(manualLayout.temperatureFormatted == "13°C")
        #expect(manualLayout.condition == .rain)

        var apiStyle = style
        apiStyle.weatherWidget.dataSource = .openMeteo
        apiStyle.weatherWidget.metricSlots = [.humidity]
        let apiElement = OverlayElement(type: .weatherWidget, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: apiStyle)
        let apiLayout = OverlayRenderModel.weatherWidgetLayout(for: apiElement, in: context)
        #expect(apiLayout.temperatureFormatted == "30°C")
        #expect(apiLayout.condition == .sunny)
        #expect(apiLayout.humidityFormatted == "10%")
        #expect(apiLayout.windFormatted == "4 km/h")
        #expect(apiLayout.metricSlots.map(\.kind) == [.humidity])
        #expect(apiLayout.metricSlots.map(\.value) == ["10% RH"])

        apiStyle.weatherWidget.metricSlots = [.none]
        let hiddenSlotElement = OverlayElement(type: .weatherWidget, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: apiStyle)
        let hiddenSlotLayout = OverlayRenderModel.weatherWidgetLayout(for: hiddenSlotElement, in: context)
        #expect(hiddenSlotLayout.metricSlots.isEmpty)
    }

    @Test func weatherWidgetLayoutUsesOverridesAndFahrenheitFormatting() {
        var style = OverlayStyle.default
        style.weatherWidget = .preset(.dashboardBar)
        style.weatherWidget.dataSource = .manual
        style.weatherWidget.manualTemperatureCelsius = 10
        style.weatherWidget.manualFeelsLike = 5
        style.weatherWidget.temperatureUnit = .fahrenheit
        style.weatherWidget.conditionLabelOverride = "Shower"
        style.weatherWidget.humiditySuffix = "%"
        let element = OverlayElement(type: .weatherWidget, position: CGPoint(x: 0.25, y: 0.75), scale: 2, style: style)
        let context = OverlayRenderContext(canvasSize: OverlayRenderContext.referenceCanvasSize, activity: sampleWeatherActivity(), elapsedTime: 5)

        let layout = OverlayRenderModel.weatherWidgetLayout(for: element, in: context)

        #expect(layout.temperatureFormatted == "50°F")
        #expect(layout.feelsLikeFormatted == "41°F")
        #expect(layout.conditionLabel == "Shower")
        #expect(abs(Double(layout.rect.width) - style.weatherWidget.width * 2) < 0.001)
        #expect(layout.rect.midX == 320)
        #expect(layout.rect.midY == 540)
    }

    @Test func routeMapLayoutProjectsGpsRouteAndCurrentPoint() {
        var style = OverlayStyle.default
        style.routeMapPreset = .glow
        let element = OverlayElement(type: .routeMap, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: style)
        let context = OverlayRenderContext(
            canvasSize: OverlayRenderContext.referenceCanvasSize,
            activity: sampleRouteActivity(),
            elapsedTime: 5
        )

        let layout = OverlayRenderModel.routeMapLayout(for: element, in: context)

        #expect(layout.geometry?.points.count == 3)
        #expect(layout.projectedPoints.count == 3)
        #expect(layout.projectedCurrentPoint != nil)
        #expect(layout.progress == 0.5)
        // Default container size moved to 320 × 240 (4:3) so the user can
        // resize either axis independently. Square shape is no longer
        // forced to 1:1 — see `OverlayStyle.routeMapWidth/Height`.
        #expect(layout.rect.width == 320)
        #expect(layout.rect.height == 240)
        // Centering fix: every projected point and the current point must
        // stay inside `contentRect` (so the rendered stroke stays inside
        // the visible map box). We expand by a 1pt tolerance to absorb
        // double-precision rounding at the bounds where a point sits
        // exactly on the edge.
        let tolerance: CGFloat = 1
        let bounds = layout.contentRect.insetBy(dx: -tolerance, dy: -tolerance)
        for point in layout.projectedPoints {
            #expect(bounds.contains(point))
        }
        if let current = layout.projectedCurrentPoint {
            #expect(bounds.contains(current))
        }
    }

    @Test func routeMapSnapshotRequestUsesSharedLayoutInputs() throws {
        var style = OverlayStyle.default
        style.routeMapPreset = .gradient
        style.routeMapBackgroundStyle = .satellite
        let element = OverlayElement(type: .routeMap, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: style)
        let context = OverlayRenderContext(
            canvasSize: OverlayRenderContext.referenceCanvasSize,
            activity: sampleRouteActivity(),
            elapsedTime: 0
        )
        let layout = OverlayRenderModel.routeMapLayout(for: element, in: context)

        let request = try #require(RouteMapSnapshotRequestBuilder.request(for: element, layout: layout))

        #expect(request.bounds == layout.geometry?.bounds)
        #expect(request.size == layout.rect.size)
        #expect(request.style == .gradient)
        #expect(request.backgroundStyle == .satellite)
    }

    @MainActor
    @Test func intervalHUDBarLayoutUsesLapsZonesAndRecoveryDrop() throws {
        let prefs = HeartRateZonePreferences.shared
        let oldCount = prefs.zoneCount
        let oldZones = prefs.zones
        let oldThresholdHR = prefs.thresholdHR
        let oldThresholdPace = prefs.thresholdPaceSecPerKm
        defer {
            prefs.zoneCount = oldCount
            prefs.zones = oldZones
            prefs.thresholdHR = oldThresholdHR
            prefs.thresholdPaceSecPerKm = oldThresholdPace
        }
        prefs.zoneCount = .five
        prefs.zones = [
            HeartRateZone(),
            HeartRateZone(minHR: 120, maxHR: 139),
            HeartRateZone(minHR: 140, maxHR: 160),
            HeartRateZone(minHR: 161, maxHR: 180),
            HeartRateZone(minHR: 181, maxHR: 200),
            HeartRateZone()
        ]
        prefs.thresholdHR = 170

        var style = OverlayStyle.default
        style.intervalHUDBar.bottomBarMode = .heartRateZones
        style.intervalHUDBar.hrDropMode = .percent
        style.intervalHUDBar.remainingPrimary = .distance
        style.intervalHUDBar.metricSlots.append(IntervalHUDBarMetricSlot(metric: .pace))
        let element = OverlayElement(type: .intervalHUDBar, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: style)
        let workContext = OverlayRenderContext(
            canvasSize: OverlayRenderContext.referenceCanvasSize,
            activity: sampleIntervalActivity(),
            elapsedTime: 50
        )
        let restContext = OverlayRenderContext(
            canvasSize: OverlayRenderContext.referenceCanvasSize,
            activity: sampleIntervalActivity(),
            elapsedTime: 130
        )

        let workLayout = OverlayRenderModel.intervalHUDBarLayout(for: element, in: workContext)
        #expect(workLayout.phaseLabel == "WORK")
        #expect(workLayout.repText == "1 / 2")
        #expect(workLayout.remainingTimeText == "0:50")
        #expect(workLayout.remainingPrimaryLabel == "LEFT")
        #expect(workLayout.remainingPrimaryText == "100 m")
        #expect(workLayout.metricItems.filter { $0.metric == .pace }.count == 2)
        #expect(workLayout.progress == 0.5)
        #expect(workLayout.bottomBarActiveZoneIndex == 3)
        #expect(workLayout.zoneMarker?.zoneIndex == 3)
        #expect(workLayout.zoneMarker?.valueText == "170 bpm")
        #expect(abs((workLayout.zoneMarker?.fractionInZone ?? 0) - (9.0 / 19.0)) < 0.0001)
        #expect(workLayout.thresholdZoneMarker?.zoneIndex == 3)
        #expect(workLayout.thresholdZoneMarker?.valueText == "T")

        let restLayout = OverlayRenderModel.intervalHUDBarLayout(for: element, in: restContext)
        #expect(restLayout.phaseLabel == "REST")
        #expect(restLayout.activeZoneIndex == 2)
        #expect(restLayout.zoneSegments.count == 5)
        #expect(restLayout.zoneItem?.metric == .hrDrop)
        #expect(restLayout.zoneItem?.value == "17")
        #expect(restLayout.zoneItem?.unit == "%")
    }

    @MainActor
    @Test func intervalHUDBarPaceMarkerSkipsZeroAndShowsThresholdMarker() throws {
        let prefs = HeartRateZonePreferences.shared
        let oldCount = prefs.zoneCount
        let oldZones = prefs.zones
        let oldThresholdHR = prefs.thresholdHR
        let oldThresholdPace = prefs.thresholdPaceSecPerKm
        defer {
            prefs.zoneCount = oldCount
            prefs.zones = oldZones
            prefs.thresholdHR = oldThresholdHR
            prefs.thresholdPaceSecPerKm = oldThresholdPace
        }
        prefs.zoneCount = .five
        prefs.zones = [
            HeartRateZone(minPaceSecPerKm: 400, maxPaceSecPerKm: 600),
            HeartRateZone(minPaceSecPerKm: 330, maxPaceSecPerKm: 399),
            HeartRateZone(minPaceSecPerKm: 280, maxPaceSecPerKm: 329),
            HeartRateZone(minPaceSecPerKm: 240, maxPaceSecPerKm: 279),
            HeartRateZone(minPaceSecPerKm: 180, maxPaceSecPerKm: 239),
            HeartRateZone()
        ]
        prefs.thresholdPaceSecPerKm = 250

        var style = OverlayStyle.default
        style.intervalHUDBar.bottomBarMode = .paceZones
        let element = OverlayElement(type: .intervalHUDBar, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: style)
        let context = OverlayRenderContext(
            canvasSize: OverlayRenderContext.referenceCanvasSize,
            activity: zeroPaceIntervalActivity(),
            elapsedTime: 50
        )

        let layout = OverlayRenderModel.intervalHUDBarLayout(for: element, in: context)

        #expect(layout.bottomBarActiveZoneIndex == nil)
        #expect(layout.zoneMarker == nil)
        #expect(layout.thresholdZoneMarker?.zoneIndex == 3)
        #expect(layout.thresholdZoneMarker?.valueText == "T")

        style.intervalHUDBar.thresholdZoneMarkerEnabled = false
        let disabledElement = OverlayElement(type: .intervalHUDBar, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: style)
        let disabledLayout = OverlayRenderModel.intervalHUDBarLayout(for: disabledElement, in: context)
        #expect(disabledLayout.thresholdZoneMarker == nil)
    }

    @Test func intervalHUDBarZoneSegmentFramesSupportActiveZoneEmphasis() {
        let equalFrames = OverlayRenderModel.intervalZoneSegmentFrames(
            segmentCount: 5,
            activeIndex: 2,
            activeWidthShare: 0
        )
        #expect(equalFrames.count == 5)
        #expect(equalFrames.allSatisfy { abs($0.width - 0.2) < 0.0001 })

        let emphasizedFrames = OverlayRenderModel.intervalZoneSegmentFrames(
            segmentCount: 5,
            activeIndex: 2,
            activeWidthShare: 0.5
        )
        #expect(emphasizedFrames[2].start == 0.25)
        #expect(emphasizedFrames[2].width == 0.5)
        #expect(emphasizedFrames[0].width == 0.125)
        #expect(emphasizedFrames[4].start == 0.875)

        let sixZoneFrames = OverlayRenderModel.intervalZoneSegmentFrames(
            segmentCount: 6,
            activeIndex: 5,
            activeWidthShare: 0.5
        )
        #expect(sixZoneFrames[5].start == 0.5)
        #expect(sixZoneFrames[5].width == 0.5)

        let fallbackFrames = OverlayRenderModel.intervalZoneSegmentFrames(
            segmentCount: 5,
            activeIndex: nil,
            activeWidthShare: 0.5
        )
        #expect(fallbackFrames.allSatisfy { abs($0.width - 0.2) < 0.0001 })
    }

    @Test func intervalHUDBarMetricsHonorPerSlotUnitOptions() {
        var style = OverlayStyle.default
        style.intervalHUDBar.metricSlots = [
            IntervalHUDBarMetricSlot(metric: .pace, unitOption: .paceImperial),
            IntervalHUDBarMetricSlot(metric: .distance, unitOption: .distanceMiles)
        ]
        let element = OverlayElement(type: .intervalHUDBar, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: style)
        let context = OverlayRenderContext(
            canvasSize: OverlayRenderContext.referenceCanvasSize,
            activity: sampleIntervalActivity(),
            elapsedTime: 50
        )

        let layout = OverlayRenderModel.intervalHUDBarLayout(for: element, in: context)

        let pace = layout.metricItems.first { $0.metric == .pace }
        #expect(pace?.value == "6'42\"")
        #expect(pace?.unit == "/mi")

        let distance = layout.metricItems.first { $0.metric == .distance }
        #expect(distance?.value == "0.06")
        #expect(distance?.unit == "mi")
    }

    @Test func intervalHUDBarMetricsIncludeAllNumericOverlayTypes() {
        let intervalMetricTypes = Set(IntervalHUDBarMetric.numericCases.compactMap(\.elementType))
        let numericTypes = Set(OverlayElementType.allCases.filter { $0.isNumericOverlay && $0 != .heartRateZone })

        #expect(intervalMetricTypes == numericTypes)
        #expect(!IntervalHUDBarMetric.numericCases.contains(.heartRateZone))
        #expect(!IntervalHUDBarMetric.numericCases.contains(.hrDrop))
    }

    @Test func intervalTimelineCentersCurrentLapAndSummarizesOverflow() {
        var style = OverlayStyle.default
        style.intervalTimeline.mode = .centeredWindow
        style.intervalTimeline.visibleNeighbors = 2
        style.intervalTimeline.primaryLabelMode = .kind
        let element = OverlayElement(type: .intervalTimeline, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: style)
        let context = OverlayRenderContext(
            canvasSize: OverlayRenderContext.referenceCanvasSize,
            activity: repeatedIntervalActivity(repCount: 25),
            elapsedTime: 30 + 13 * 120 + 35
        )

        let layout = OverlayRenderModel.intervalTimelineLayout(for: element, in: context)

        #expect(layout.segments.count == 5)
        #expect(layout.leftOverflowCount > 0)
        #expect(layout.rightOverflowCount > 0)
        let current = layout.segments.first { $0.isCurrent }
        #expect(current?.kind == .active)
        #expect(current?.label == "1min")
        #expect(layout.repText == "Rep 14 / 25")
        if let current {
            #expect(abs(current.rect.midX - layout.markerX) > 0)
            #expect(current.rect.height > (layout.segments.first { !$0.isCurrent }?.rect.height ?? 0))
        }
    }

    @Test func intervalTimelineFullScheduleShowsAllSmallWorkouts() {
        var style = OverlayStyle.default
        style.intervalTimeline.mode = .fullSchedule
        style.intervalTimeline.maxFullSegments = 12
        let element = OverlayElement(type: .intervalTimeline, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: style)
        let context = OverlayRenderContext(
            canvasSize: OverlayRenderContext.referenceCanvasSize,
            activity: sampleIntervalActivity(),
            elapsedTime: 130
        )

        let layout = OverlayRenderModel.intervalTimelineLayout(for: element, in: context)

        #expect(layout.segments.count == 3)
        #expect(layout.leftOverflowCount == 0)
        #expect(layout.rightOverflowCount == 0)
        #expect(layout.segments.map(\.kind) == [.active, .rest, .active])
        #expect(layout.segments.first(where: \.isCurrent)?.kind == .rest)
    }

    @Test func intervalTimelineMarkerToggleDoesNotMoveRailOrSegments() throws {
        var enabledStyle = OverlayStyle.default
        enabledStyle.intervalTimeline.mode = .centeredWindow
        enabledStyle.intervalTimeline.visibleNeighbors = 2
        enabledStyle.intervalTimeline.markerEnabled = true

        var disabledStyle = enabledStyle
        disabledStyle.intervalTimeline.markerEnabled = false

        let enabledElement = OverlayElement(type: .intervalTimeline, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: enabledStyle)
        let disabledElement = OverlayElement(type: .intervalTimeline, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: disabledStyle)
        let context = OverlayRenderContext(
            canvasSize: OverlayRenderContext.referenceCanvasSize,
            activity: repeatedIntervalActivity(repCount: 25),
            elapsedTime: 30 + 13 * 120 + 35
        )

        let enabledLayout = OverlayRenderModel.intervalTimelineLayout(for: enabledElement, in: context)
        let disabledLayout = OverlayRenderModel.intervalTimelineLayout(for: disabledElement, in: context)

        #expect(enabledLayout.contentRect == disabledLayout.contentRect)
        #expect(enabledLayout.markerTopY == disabledLayout.markerTopY)
        let enabledFirstRect = try #require(enabledLayout.segments.first?.rect)
        let disabledFirstRect = try #require(disabledLayout.segments.first?.rect)
        #expect(enabledFirstRect == disabledFirstRect)
    }

    @Test func intervalTimelineReservesEdgeContextWhenOverflowPillsAreHidden() {
        var style = OverlayStyle.default
        style.intervalTimeline.mode = .centeredWindow
        style.intervalTimeline.visibleNeighbors = 2
        style.intervalTimeline.overflowPillsEnabled = false
        let element = OverlayElement(type: .intervalTimeline, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: style)
        let context = OverlayRenderContext(
            canvasSize: OverlayRenderContext.referenceCanvasSize,
            activity: repeatedIntervalActivity(repCount: 25),
            elapsedTime: 30 + 13 * 120 + 35
        )

        let layout = OverlayRenderModel.intervalTimelineLayout(for: element, in: context)

        #expect(layout.leftOverflowCount > 0)
        #expect(layout.rightOverflowCount > 0)
        #expect(layout.segments.first?.rect.minX ?? 0 > layout.contentRect.minX + 44)
        #expect(layout.segments.last?.rect.maxX ?? 0 < layout.contentRect.maxX - 44)
    }

    @Test func intervalTimelineOverflowPillClustersDoNotOverlapSegments() {
        var style = OverlayStyle.default
        style.intervalTimeline.mode = .centeredWindow
        style.intervalTimeline.visibleNeighbors = 2
        style.intervalTimeline.overflowPillsEnabled = true
        let element = OverlayElement(type: .intervalTimeline, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: style)
        let context = OverlayRenderContext(
            canvasSize: OverlayRenderContext.referenceCanvasSize,
            activity: repeatedIntervalActivity(repCount: 25),
            elapsedTime: 30 + 13 * 120 + 35
        )

        let layout = OverlayRenderModel.intervalTimelineLayout(for: element, in: context)

        #expect(layout.leftOverflowCount > 0)
        #expect(layout.rightOverflowCount > 0)
        #expect(layout.segments.first?.rect.minX ?? 0 >= layout.contentRect.minX + 70)
        #expect(layout.segments.last?.rect.maxX ?? 0 <= layout.contentRect.maxX - 70)
    }

    @Test func intervalTimelineMarkerLaneKeepsMarkerInsideBackground() {
        var style = OverlayStyle.default
        style.intervalTimeline.mode = .centeredWindow
        style.intervalTimeline.visibleNeighbors = 3
        style.intervalTimeline.markerEnabled = true
        style.intervalTimeline.markerFontSize = 14
        let element = OverlayElement(type: .intervalTimeline, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: style)
        let context = OverlayRenderContext(
            canvasSize: OverlayRenderContext.referenceCanvasSize,
            activity: repeatedIntervalActivity(repCount: 25),
            elapsedTime: 30 + 13 * 120 + 35
        )

        let layout = OverlayRenderModel.intervalTimelineLayout(for: element, in: context)
        let markerBottom = layout.markerTopY + layout.markerTriangleHeight + 2 * element.scale + layout.markerLabelHeight

        let currentSegmentBottom = layout.segments.first(where: \.isCurrent).map { $0.rect.maxY } ?? layout.contentRect.maxY
        #expect(layout.markerTopY > currentSegmentBottom)
        #expect(markerBottom < layout.rect.maxY - 1)
    }

    @Test func intervalTimelineStyleDecodesOlderRailAndMarkerFieldsWithDefaults() throws {
        let data = Data("""
        {
          "width": 780,
          "height": 64,
          "mode": "centeredWindow",
          "visibleNeighbors": 3,
          "maxFullSegments": 12,
          "segmentHeight": 30,
          "currentSegmentHeightScale": 1.35,
          "minSegmentWidth": 54,
          "segmentGap": 4,
          "edgeFadeEnabled": true,
          "currentProgressEnabled": true,
          "markerEnabled": true,
          "markerLabel": "NOW",
          "markerPosition": "liveProgress",
          "primaryLabelMode": "distance",
          "durationLabelsEnabled": true,
          "repCounterEnabled": true,
          "overflowPillsEnabled": true,
          "railEnabled": true,
          "railSpacing": 5
        }
        """.utf8)

        let style = try JSONDecoder().decode(IntervalTimelineStyle.self, from: data)

        #expect(style.markerColor == .white)
        #expect(style.markerFontSize == IntervalTimelineStyle.default.markerFontSize)
        #expect(style.overflowPillsEnabled == true)
    }

    @MainActor
    @Test func overlayFrameRendererWritesRunningGaugePNG() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let outputURL = directory.appendingPathComponent("running-gauge.png")
        let layout = OverlayLayout(elements: [
            OverlayElement(type: .runningGauge, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: .default)
        ])
        try OverlayFrameRenderer.renderPNG(
            to: outputURL,
            request: OverlayFrameRenderRequest(
                size: CGSize(width: 640, height: 360),
                layout: layout,
                activity: ProjectDocument.calibrationActivity(),
                elapsedTime: 1.5,
                renderGuides: false
            )
        )

        let data = try Data(contentsOf: outputURL)
        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
        #expect(data.count > 100)
    }

    @MainActor
    @Test func overlayFrameRendererWritesRouteMapPNG() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        var style = OverlayStyle.default
        style.routeMapPreset = .glow
        style.foregroundColor = .cyan
        let outputURL = directory.appendingPathComponent("route-map.png")
        let layout = OverlayLayout(elements: [
            OverlayElement(type: .routeMap, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: style)
        ])
        try OverlayFrameRenderer.renderPNG(
            to: outputURL,
            request: OverlayFrameRenderRequest(
                size: CGSize(width: 640, height: 360),
                layout: layout,
                activity: sampleRouteActivity(),
                elapsedTime: 5,
                renderGuides: false
            )
        )

        let data = try Data(contentsOf: outputURL)
        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
        #expect(data.count > 100)
    }

    @MainActor
    @Test func overlayFrameRendererWritesDistanceTimelineAnimatedSVGSlotPNG() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        var style = OverlayStyle.default
        style.distanceTimeline = .preset(.sport)
        style.distanceTimeline.mediaSlot.mode = .animatedSVG
        style.distanceTimeline.mediaSlot.svgSource = """
        <svg viewBox="0 0 24 24">
          <animateTransform attributeName="transform" type="rotate" from="0" to="360" dur="2s" repeatCount="indefinite"/>
          <path d="M12 3 L15 12 L12 21 L9 12 Z" fill="currentColor"/>
        </svg>
        """
        style.distanceTimeline.mediaSlot.assetName = "pulse.svg"
        style.distanceTimeline.mediaSlot.animationDuration = 2

        let outputURL = directory.appendingPathComponent("distance-timeline-svg.png")
        let layout = OverlayLayout(elements: [
            OverlayElement(type: .distanceTimeline, position: CGPoint(x: 0.5, y: 0.5), scale: 1, style: style)
        ])
        try OverlayFrameRenderer.renderPNG(
            to: outputURL,
            request: OverlayFrameRenderRequest(
                size: CGSize(width: 640, height: 360),
                layout: layout,
                activity: ProjectDocument.calibrationActivity(),
                elapsedTime: 1.0,
                renderGuides: false
            )
        )

        let data = try Data(contentsOf: outputURL)
        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
        #expect(data.count > 100)
    }

    @Test func activityTimelineInterpolatesRoutePoint() throws {
        let point = try #require(sampleRouteActivity().routePoint(at: 5))

        #expect(point.elapsedTime == 5)
        #expect(abs(point.latitude - 40.7525) < 0.0001)
        #expect(abs(point.longitude - -73.9835) < 0.0001)
        #expect(point.heartRate == 120)
    }

    @MainActor
    @Test func calibrationOverlayLayoutCoversReferencePositions() {
        let layout = ProjectDocument.calibrationOverlayLayout()

        #expect(layout.elements.map(\.type) == [.distanceTimeline, .elevationChart, .heartRate, .distance, .pace, .elapsedTime])
        #expect(layout.elements.allSatisfy { element in
            element.position.x >= 0 && element.position.x <= 1 && element.position.y >= 0 && element.position.y <= 1
        })
    }

    @MainActor
    @Test func calibrationActivityProvidesRenderableData() {
        let activity = ProjectDocument.calibrationActivity()

        #expect(activity.duration == 3)
        #expect(activity.distanceMeters == 750)
        #expect(activity.heartRate(at: 1.5) == 160)
        #expect(activity.elevation(at: 1.5) == 112)
    }

    @MainActor
    @Test func overlayFrameRendererWritesCalibrationPNG() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let outputURL = directory.appendingPathComponent("frame.png")
        try OverlayFrameRenderer.renderPNG(
            to: outputURL,
            request: OverlayFrameRenderRequest(
                size: CGSize(width: 320, height: 180),
                layout: ProjectDocument.calibrationOverlayLayout(),
                activity: ProjectDocument.calibrationActivity(),
                elapsedTime: 1.5,
                renderGuides: true
            )
        )

        let data = try Data(contentsOf: outputURL)
        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
        #expect(data.count > 100)
    }

    private func sampleActivity() -> ActivityTimeline {
        let startDate = Date(timeIntervalSince1970: 1_000)
        return ActivityTimeline(
            startDate: startDate,
            duration: 10,
            distanceMeters: 100,
            records: [
                ActivityRecord(
                    elapsedTime: 0,
                    timestamp: startDate,
                    distanceMeters: 0,
                    heartRate: 100,
                    paceSecondsPerKilometer: nil,
                    elevationMeters: 100,
                    cadence: nil,
                    powerWatts: nil,
                    calories: nil
                ),
                ActivityRecord(
                    elapsedTime: 10,
                    timestamp: startDate.addingTimeInterval(10),
                    distanceMeters: 100,
                    heartRate: 120,
                    paceSecondsPerKilometer: nil,
                    elevationMeters: 110,
                    cadence: nil,
                    powerWatts: nil,
                    calories: nil
                )
            ],
            laps: []
        )
    }

    private func sampleRouteActivity() -> ActivityTimeline {
        let startDate = Date(timeIntervalSince1970: 2_000)
        return ActivityTimeline(
            startDate: startDate,
            duration: 10,
            distanceMeters: 1000,
            records: [
                ActivityRecord(
                    elapsedTime: 0,
                    timestamp: startDate,
                    distanceMeters: 0,
                    heartRate: 100,
                    paceSecondsPerKilometer: 300,
                    elevationMeters: 10,
                    cadence: nil,
                    powerWatts: nil,
                    calories: nil,
                    latitude: 40.7500,
                    longitude: -73.9850
                ),
                ActivityRecord(
                    elapsedTime: 5,
                    timestamp: startDate.addingTimeInterval(5),
                    distanceMeters: 500,
                    heartRate: 120,
                    paceSecondsPerKilometer: 280,
                    elevationMeters: 14,
                    cadence: nil,
                    powerWatts: nil,
                    calories: nil,
                    latitude: 40.7525,
                    longitude: -73.9835
                ),
                ActivityRecord(
                    elapsedTime: 10,
                    timestamp: startDate.addingTimeInterval(10),
                    distanceMeters: 1000,
                    heartRate: 140,
                    paceSecondsPerKilometer: 260,
                    elevationMeters: 18,
                    cadence: nil,
                    powerWatts: nil,
                    calories: nil,
                    latitude: 40.7550,
                    longitude: -73.9800
                )
            ],
            laps: []
        )
    }

    private func sampleIntervalActivity() -> ActivityTimeline {
        let startDate = Date(timeIntervalSince1970: 3_000)
        return ActivityTimeline(
            startDate: startDate,
            duration: 260,
            distanceMeters: 520,
            records: [
                ActivityRecord(elapsedTime: 0, timestamp: startDate, distanceMeters: 0, heartRate: 130, paceSecondsPerKilometer: 300, elevationMeters: nil, cadence: nil, powerWatts: 230, calories: nil),
                ActivityRecord(elapsedTime: 50, timestamp: startDate.addingTimeInterval(50), distanceMeters: 100, heartRate: 170, paceSecondsPerKilometer: 250, elevationMeters: nil, cadence: nil, powerWatts: 280, calories: nil),
                ActivityRecord(elapsedTime: 100, timestamp: startDate.addingTimeInterval(100), distanceMeters: 200, heartRate: 180, paceSecondsPerKilometer: 270, elevationMeters: nil, cadence: nil, powerWatts: 260, calories: nil),
                ActivityRecord(elapsedTime: 130, timestamp: startDate.addingTimeInterval(130), distanceMeters: 230, heartRate: 150, paceSecondsPerKilometer: 420, elevationMeters: nil, cadence: nil, powerWatts: 120, calories: nil),
                ActivityRecord(elapsedTime: 260, timestamp: startDate.addingTimeInterval(260), distanceMeters: 520, heartRate: 182, paceSecondsPerKilometer: 255, elevationMeters: nil, cadence: nil, powerWatts: 285, calories: nil)
            ],
            laps: [
                LapRecord(lapIndex: 0, startElapsedTime: 0, endElapsedTime: 100, startDistanceMeters: 0, totalDistanceMeters: 200, totalElapsedTime: 100, avgPaceSecondsPerKm: 260, avgHeartRate: 165, maxHeartRate: 180, avgCadenceSPM: nil, avgPowerWatts: 270, totalAscent: nil, kind: .active),
                LapRecord(lapIndex: 1, startElapsedTime: 100, endElapsedTime: 160, startDistanceMeters: 200, totalDistanceMeters: 60, totalElapsedTime: 60, avgPaceSecondsPerKm: 420, avgHeartRate: 150, maxHeartRate: 180, avgCadenceSPM: nil, avgPowerWatts: 120, totalAscent: nil, kind: .rest),
                LapRecord(lapIndex: 2, startElapsedTime: 160, endElapsedTime: 260, startDistanceMeters: 260, totalDistanceMeters: 260, totalElapsedTime: 100, avgPaceSecondsPerKm: 255, avgHeartRate: 176, maxHeartRate: 182, avgCadenceSPM: nil, avgPowerWatts: 285, totalAscent: nil, kind: .active)
            ]
        )
    }

    private func zeroPaceIntervalActivity() -> ActivityTimeline {
        let startDate = Date(timeIntervalSince1970: 3_100)
        return ActivityTimeline(
            startDate: startDate,
            duration: 100,
            distanceMeters: 0,
            records: [
                ActivityRecord(elapsedTime: 0, timestamp: startDate, distanceMeters: 0, heartRate: 100, paceSecondsPerKilometer: 0, elevationMeters: nil, cadence: nil, powerWatts: nil, calories: nil),
                ActivityRecord(elapsedTime: 100, timestamp: startDate.addingTimeInterval(100), distanceMeters: 0, heartRate: 105, paceSecondsPerKilometer: 0, elevationMeters: nil, cadence: nil, powerWatts: nil, calories: nil)
            ],
            laps: [
                LapRecord(lapIndex: 0, startElapsedTime: 0, endElapsedTime: 100, startDistanceMeters: 0, totalDistanceMeters: 0, totalElapsedTime: 100, avgPaceSecondsPerKm: nil, avgHeartRate: 102, maxHeartRate: 105, avgCadenceSPM: nil, avgPowerWatts: nil, totalAscent: nil, kind: .rest)
            ]
        )
    }

    private func repeatedIntervalActivity(repCount: Int) -> ActivityTimeline {
        let startDate = Date(timeIntervalSince1970: 4_000)
        var laps: [LapRecord] = [
            LapRecord(lapIndex: 0, startElapsedTime: 0, endElapsedTime: 30, startDistanceMeters: 0, totalDistanceMeters: 80, totalElapsedTime: 30, avgPaceSecondsPerKm: 360, avgHeartRate: nil, maxHeartRate: nil, avgCadenceSPM: nil, avgPowerWatts: nil, totalAscent: nil, kind: .warmup)
        ]
        var records: [ActivityRecord] = [
            ActivityRecord(elapsedTime: 0, timestamp: startDate, distanceMeters: 0, heartRate: 120, paceSecondsPerKilometer: 360, elevationMeters: nil, cadence: nil, powerWatts: nil, calories: nil)
        ]
        var elapsed: TimeInterval = 30
        var distance = 80.0
        for rep in 0..<repCount {
            laps.append(LapRecord(lapIndex: laps.count, startElapsedTime: elapsed, endElapsedTime: elapsed + 60, startDistanceMeters: distance, totalDistanceMeters: 250, totalElapsedTime: 60, avgPaceSecondsPerKm: 240, avgHeartRate: nil, maxHeartRate: nil, avgCadenceSPM: nil, avgPowerWatts: nil, totalAscent: nil, kind: .active))
            elapsed += 60
            distance += 250
            records.append(ActivityRecord(elapsedTime: elapsed, timestamp: startDate.addingTimeInterval(elapsed), distanceMeters: distance, heartRate: 170, paceSecondsPerKilometer: 240, elevationMeters: nil, cadence: nil, powerWatts: nil, calories: nil))
            if rep < repCount - 1 {
                laps.append(LapRecord(lapIndex: laps.count, startElapsedTime: elapsed, endElapsedTime: elapsed + 60, startDistanceMeters: distance, totalDistanceMeters: 120, totalElapsedTime: 60, avgPaceSecondsPerKm: 420, avgHeartRate: nil, maxHeartRate: nil, avgCadenceSPM: nil, avgPowerWatts: nil, totalAscent: nil, kind: .rest))
                elapsed += 60
                distance += 120
                records.append(ActivityRecord(elapsedTime: elapsed, timestamp: startDate.addingTimeInterval(elapsed), distanceMeters: distance, heartRate: 140, paceSecondsPerKilometer: 420, elevationMeters: nil, cadence: nil, powerWatts: nil, calories: nil))
            }
        }
        laps.append(LapRecord(lapIndex: laps.count, startElapsedTime: elapsed, endElapsedTime: elapsed + 60, startDistanceMeters: distance, totalDistanceMeters: 120, totalElapsedTime: 60, avgPaceSecondsPerKm: 360, avgHeartRate: nil, maxHeartRate: nil, avgCadenceSPM: nil, avgPowerWatts: nil, totalAscent: nil, kind: .cooldown))
        elapsed += 60
        distance += 120
        records.append(ActivityRecord(elapsedTime: elapsed, timestamp: startDate.addingTimeInterval(elapsed), distanceMeters: distance, heartRate: 125, paceSecondsPerKilometer: 360, elevationMeters: nil, cadence: nil, powerWatts: nil, calories: nil))
        return ActivityTimeline(startDate: startDate, duration: elapsed, distanceMeters: distance, records: records, laps: laps)
    }

    private func sampleWeatherActivity() -> ActivityTimeline {
        let startDate = Date(timeIntervalSince1970: 1_000)
        return ActivityTimeline(
            startDate: startDate,
            duration: 10,
            distanceMeters: 100,
            records: [
                ActivityRecord(
                    elapsedTime: 0,
                    timestamp: startDate,
                    distanceMeters: 0,
                    heartRate: nil,
                    paceSecondsPerKilometer: nil,
                    elevationMeters: nil,
                    cadence: nil,
                    powerWatts: nil,
                    calories: nil,
                    temperatureCelsius: 14
                ),
                ActivityRecord(
                    elapsedTime: 10,
                    timestamp: startDate.addingTimeInterval(10),
                    distanceMeters: 100,
                    heartRate: nil,
                    paceSecondsPerKilometer: nil,
                    elevationMeters: nil,
                    cadence: nil,
                    powerWatts: nil,
                    calories: nil,
                    temperatureCelsius: 16
                )
            ],
            laps: []
        )
    }
}
