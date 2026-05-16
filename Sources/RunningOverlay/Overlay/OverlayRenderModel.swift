import Foundation

struct OverlayRenderContext {
    var canvasSize: CGSize
    var activity: ActivityTimeline
    var elapsedTime: TimeInterval

    var canvasScale: Double {
        min(canvasSize.width / Self.referenceCanvasSize.width, canvasSize.height / Self.referenceCanvasSize.height)
    }

    func scaled(_ value: Double) -> Double {
        value * canvasScale
    }

    static let referenceCanvasSize = CGSize(width: 1280, height: 720)
}

enum OverlayRenderModel {
    static func textLayout(for element: OverlayElement, in context: OverlayRenderContext) -> OverlayTextRenderLayout {
        let fontSize = context.scaled(element.style.fontSize * element.scale)
        let metrics = textMetrics(for: element.style.textPreset, fontSize: fontSize, scale: element.scale, context: context, element: element)
        let components = OverlayValueFormatter.components(for: element, activity: context.activity, elapsedTime: context.elapsedTime)
        let unifiedTextBaseColor: OverlayColor? = {
            guard element.type == .heartRateZone,
                  element.style.textColorsFollowHeartRateZones else { return nil }
            let snapshot = HeartRateZonePreferences.currentSnapshot()
            let visibleZones = Array(snapshot.zones.prefix(snapshot.zoneCount))
            guard let hr = context.activity.heartRate(at: context.elapsedTime),
                  let zoneIndex = resolvedHeartRateZoneIndex(heartRate: hr, zones: visibleZones)
            else { return nil }
            return HRZonePalette.overlayColor(forIndex: zoneIndex)
        }()
        return OverlayTextRenderLayout(
            value: OverlayValueFormatter.value(for: element, activity: context.activity, elapsedTime: context.elapsedTime),
            components: components,
            preset: element.style.textPreset,
            fontSize: fontSize,
            labelFontSize: context.scaled(element.style.labelFontSize * element.scale),
            unitFontSize: context.scaled(element.style.unitFontSize * element.scale),
            labelFontName: element.style.labelFontName,
            unitFontName: element.style.unitFontName,
            labelFontWeight: element.style.labelFontWeight,
            unitFontWeight: element.style.unitFontWeight,
            labelPosition: element.style.labelPosition,
            unitPosition: element.style.unitPosition,
            labelSpacing: context.scaled(element.style.labelSpacing * element.scale),
            unitSpacing: context.scaled(element.style.unitSpacing * element.scale),
            horizontalPadding: metrics.horizontalPadding,
            verticalPadding: metrics.verticalPadding,
            cornerRadius: metrics.cornerRadius,
            backgroundFadeOutEnabled: element.style.backgroundFadeOutEnabled,
            backgroundFadeOutAmount: element.style.backgroundFadeOutAmount,
            backgroundBlurRadius: context.scaled(element.style.backgroundBlurRadius),
            shadowRadius: context.scaled(element.style.shadowRadius),
            shadowOffsetY: context.scaled(element.style.shadowOffsetY),
            labelTextAlignment: element.style.labelTextAlignment,
            valueTextAlignment: element.style.textAlignment,
            unitTextAlignment: element.style.unitTextAlignment,
            dividerEnabled: element.style.dividerEnabled,
            dividerColor: element.style.dividerColor,
            dividerThickness: context.scaled(element.style.dividerThickness * element.scale),
            dividerOpacity: element.style.dividerOpacity,
            unifiedTextBaseColor: unifiedTextBaseColor
        )
    }

    static func distanceTimelineLayout(for element: OverlayElement, in context: OverlayRenderContext) -> OverlayDistanceTimelineRenderLayout {
        let style = element.style.distanceTimeline
        let width = context.scaled(style.width * element.scale)
        let height = context.scaled(style.height * element.scale)
        let rect = centeredRect(for: element, size: CGSize(width: width, height: height), canvasSize: context.canvasSize)
        let progress = context.activity.distanceMeters > 0
            ? context.activity.distance(at: context.elapsedTime) / context.activity.distanceMeters
            : context.elapsedTime / max(context.activity.duration, 1)
        let clamped = clampedProgress(progress)
        let paddingX = context.scaled(style.paddingX * element.scale)
        let paddingY = context.scaled(style.paddingY * element.scale)
        let mediaSize = style.mediaSlotEnabled && style.preset.supportsMediaSlot
            ? context.scaled(style.mediaSlotSize * element.scale)
            : 0
        let mediaGap = mediaSize > 0 ? context.scaled(10 * element.scale) : 0
        let contentRect = CGRect(
            x: rect.minX + paddingX + mediaSize + mediaGap,
            y: rect.minY + paddingY,
            width: max(rect.width - paddingX * 2 - mediaSize - mediaGap, 1),
            height: max(rect.height - paddingY * 2, 1)
        )
        let trackHeight = max(context.scaled(style.trackHeight * element.scale), 2)
        let valueFontSize = context.scaled(max(12, element.style.fontSize * element.scale))
        let labelFontSize = context.scaled(max(8, style.labelFontSize * element.scale))
        let axisLabelFontSize = context.scaled(max(8, style.axisLabelFontSize * element.scale))
        let valueBlockHeight = (style.showLabel ? labelFontSize + context.scaled(style.labelValueSpacing * element.scale) : 0)
            + (style.showValue || style.customValuesEnabled ? valueFontSize * 1.35 : 0)
        let trackY: Double
        switch style.preset {
        case .lowerThird:
            trackY = min(contentRect.maxY - trackHeight, contentRect.minY + valueBlockHeight + context.scaled(style.valueProgressSpacing * element.scale))
        case .route:
            trackY = contentRect.minY + contentRect.height * 0.58
        default:
            trackY = min(contentRect.maxY - trackHeight, contentRect.minY + valueBlockHeight + context.scaled(style.valueProgressSpacing * element.scale))
        }
        let trackRect = CGRect(
            x: contentRect.minX,
            y: trackY,
            width: contentRect.width,
            height: trackHeight
        )
        let mediaSlotRect: CGRect? = mediaSize > 0
            ? CGRect(x: rect.minX + paddingX, y: rect.midY - mediaSize / 2, width: mediaSize, height: mediaSize)
            : nil
        let routeGeometry = style.preset == .route ? RouteGeometryBuilder.geometry(from: context.activity) : nil
        let routePoints = routeGeometry.map { geometry in
            geometry.points.map { projectRoutePoint($0, bounds: geometry.bounds, rect: contentRect) }
        } ?? []
        let routeCurrentPoint = routeGeometry.flatMap { geometry in
            context.activity.routePoint(at: context.elapsedTime).map {
                projectRoutePoint($0, bounds: geometry.bounds, rect: contentRect)
            }
        }
        let distanceMeters = context.activity.distance(at: context.elapsedTime)
        let totalDistanceMeters = context.activity.distanceMeters
        let currentDistance: Double
        let totalDistance: Double
        let unit: String
        switch style.valueUnitSystem {
        case .metric:
            currentDistance = distanceMeters / 1000
            totalDistance = totalDistanceMeters / 1000
            unit = "km"
        case .imperial:
            currentDistance = distanceMeters / 1609.344
            totalDistance = totalDistanceMeters / 1609.344
            unit = "mi"
        }
        let distanceComponents = OverlayValueComponents(
            label: "Distance",
            shortLabel: "DIST",
            value: String(format: "%.2f", currentDistance),
            unit: unit
        )
        let totalComponents = OverlayValueComponents(
            label: "Distance",
            shortLabel: "DIST",
            value: String(format: "%.2f", totalDistance),
            unit: unit
        )
        let valueText = "\(distanceComponents.value) / \(totalComponents.value) \(totalComponents.unit)"
        let markerDistanceText = "\(distanceComponents.value) \(unit)"
        let distancePointLabels = style.showDistancePoints && style.distancePointCount > 0
            ? Self.distancePointLabels(totalDistance: totalDistance, unit: unit, count: style.distancePointCount)
            : []
        let statsBarItems = distanceStatsBarItems(
            style: style,
            activity: context.activity,
            elapsedTime: context.elapsedTime,
            progress: clamped
        )

        return OverlayDistanceTimelineRenderLayout(
            style: style,
            valueText: valueText,
            label: style.label.isEmpty ? "Distance" : style.label,
            percentText: "\(Int((clamped * 100).rounded()))%",
            customValues: distanceCustomValues(
                style: style,
                activity: context.activity,
                elapsedTime: context.elapsedTime,
                progress: clamped
            ),
            startText: style.axisLabelMode == .startFinish ? "START" : "0 \(unit)",
            finishText: style.axisLabelMode == .startFinish ? "FINISH" : "\(totalComponents.value) \(unit)",
            distancePointLabels: distancePointLabels,
            markerDistanceText: markerDistanceText,
            statsBarItems: statsBarItems,
            rect: rect,
            contentRect: contentRect,
            trackRect: trackRect,
            mediaSlotRect: mediaSlotRect,
            elapsedTime: context.elapsedTime,
            valueFontSize: valueFontSize,
            labelFontSize: labelFontSize,
            percentFontSize: context.scaled(max(9, element.style.fontSize * 0.44 * element.scale)),
            unitFontSize: axisLabelFontSize,
            cornerRadius: context.scaled(style.cornerRadius * element.scale),
            borderWidth: max(context.scaled(style.borderWidth * element.scale), 0.5),
            progress: clamped,
            elevationSamples: elevationSamples(from: context.activity),
            routePoints: routePoints,
            routeCurrentPoint: routeCurrentPoint
        )
    }

    private static func distancePointLabels(totalDistance: Double, unit: String, count: Int) -> [String] {
        guard count > 0 else { return [] }
        return (1...count).map { index in
            let value = totalDistance * Double(index) / Double(count + 1)
            return String(format: value >= 10 ? "%.1f %@" : "%.2f %@", value, unit)
        }
    }

    private static func distanceStatsBarItems(
        style: DistanceTimelineStyle,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        progress: Double
    ) -> [OverlayDistanceTimelineStatsBarItemLayout] {
        style.statsBar.slots.prefix(4).compactMap { slot in
            guard slot.visible else { return nil }
            if slot.metric == .progress {
                return OverlayDistanceTimelineStatsBarItemLayout(
                    label: slot.customLabel.isEmpty ? "PROGRESS" : slot.customLabel,
                    value: "\(Int((progress * 100).rounded()))%",
                    unit: ""
                )
            }
            let components = OverlayValueFormatter.components(for: slot.metric.elementType, activity: activity, elapsedTime: elapsedTime)
            return OverlayDistanceTimelineStatsBarItemLayout(
                label: slot.customLabel.isEmpty ? components.shortLabel : slot.customLabel,
                value: components.value,
                unit: components.unit
            )
        }
    }

    private static func distanceCustomValues(
        style: DistanceTimelineStyle,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        progress: Double
    ) -> [DistanceTimelineCustomValue] {
        guard style.customValuesEnabled else { return [] }
        return style.customValues.prefix(4).compactMap { slot in
            guard slot.visible else { return nil }
            if slot.metric == .progress {
                return DistanceTimelineCustomValue(visible: true, metric: slot.metric, value: "\(Int((progress * 100).rounded()))%")
            }
            let components = OverlayValueFormatter.components(for: slot.metric.elementType, activity: activity, elapsedTime: elapsedTime)
            let text = components.unit.isEmpty ? components.value : "\(components.value) \(components.unit)"
            return DistanceTimelineCustomValue(visible: true, metric: slot.metric, value: text)
        }
    }

    static func elevationChartLayout(for element: OverlayElement, in context: OverlayRenderContext) -> OverlayElevationChartRenderLayout {
        let style = element.style.elevationChart
        let width = context.scaled(style.width * element.scale)
        let height = context.scaled(style.height * element.scale)
        let rect = centeredRect(for: element, size: CGSize(width: width, height: height), canvasSize: context.canvasSize)
        let progress = clampedProgress(context.elapsedTime / max(context.activity.duration, 1))
        let samples = elevationSamples(from: context.activity)
        let visibleSamples: [Double]
        if style.progressMode == .progressToCurrent, samples.count > 1 {
            let count = max(2, min(samples.count, Int((Double(samples.count - 1) * progress).rounded()) + 1))
            visibleSamples = Array(samples.prefix(count))
        } else {
            visibleSamples = samples
        }
        let statsBarItems = elevationChartStatsBarItems(
            style: style,
            activity: context.activity,
            elapsedTime: context.elapsedTime,
            progress: progress
        )
        return OverlayElevationChartRenderLayout(
            style: style,
            bigNumberText: elevationBigNumber(style: style, activity: context.activity, elapsedTime: context.elapsedTime),
            label: OverlayValueFormatter.value(for: element.type, activity: context.activity, elapsedTime: context.elapsedTime),
            statsBarItems: statsBarItems,
            rect: rect,
            labelFontSize: context.scaled(max(10, element.style.fontSize * 0.38 * element.scale)),
            valueFontSize: context.scaled(max(18, style.bigNumberFontSize * element.scale)),
            unitFontSize: context.scaled(max(10, style.bigNumberFontSize * 0.38 * element.scale)),
            horizontalPadding: context.scaled(style.chartPaddingX * element.scale),
            verticalPadding: context.scaled(style.chartPaddingY * element.scale),
            cornerRadius: context.scaled(style.cornerRadius * element.scale),
            chartHeight: context.scaled(max(52, (style.bigNumbersEnabled ? style.height * 0.40 : style.height - (style.statsBar.visible ? style.statsBar.height + 34 : 34)) * element.scale)),
            lineWidth: max(context.scaled(1), context.scaled(style.lineWidth * element.scale)),
            progress: progress,
            samples: visibleSamples
        )
    }

    private static func elevationChartStatsBarItems(
        style: ElevationChartStyle,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        progress: Double
    ) -> [OverlayDistanceTimelineStatsBarItemLayout] {
        guard style.statsBar.visible else { return [] }
        return style.statsBar.slots.prefix(4).compactMap { slot in
            guard slot.visible else { return nil }
            if slot.metric == .progress {
                return OverlayDistanceTimelineStatsBarItemLayout(
                    label: slot.customLabel.isEmpty ? "PROGRESS" : slot.customLabel,
                    value: "\(Int((progress * 100).rounded()))%",
                    unit: ""
                )
            }
            let components = OverlayValueFormatter.components(for: slot.metric.elementType, activity: activity, elapsedTime: elapsedTime)
            return OverlayDistanceTimelineStatsBarItemLayout(
                label: slot.customLabel.isEmpty ? components.shortLabel : slot.customLabel,
                value: components.value,
                unit: components.unit
            )
        }
    }

    private static func elevationBigNumber(
        style: ElevationChartStyle,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval
    ) -> OverlayValueComponents {
        let elevations = activity.records.compactMap(\.elevationMeters)
        switch style.bigNumberMetric {
        case .currentElevation:
            return OverlayValueFormatter.components(for: .elevation, activity: activity, elapsedTime: elapsedTime)
        case .elevationGain:
            let gain = zip(elevations, elevations.dropFirst()).reduce(0) { total, pair in
                total + max(pair.1 - pair.0, 0)
            }
            return OverlayValueComponents(label: "Elevation Gain", shortLabel: "GAIN", value: "+\(Int(gain.rounded()))", unit: "m")
        case .maxElevation:
            return OverlayValueComponents(label: "Max Elevation", shortLabel: "MAX", value: "\(Int((elevations.max() ?? 0).rounded()))", unit: "m")
        case .minElevation:
            return OverlayValueComponents(label: "Min Elevation", shortLabel: "MIN", value: "\(Int((elevations.min() ?? 0).rounded()))", unit: "m")
        }
    }

    static func runningGaugeLayout(for element: OverlayElement, in context: OverlayRenderContext) -> OverlayRunningGaugeRenderLayout {
        let style = element.style.gauge
        let diameter = context.scaled(300 * element.scale)
        let rect = centeredRect(for: element, size: CGSize(width: diameter, height: diameter), canvasSize: context.canvasSize)
        let progress = computeGaugeProgress(style: style, context: context)

        let regionFrames = RunningGaugeLayoutEngine.regionFrames(
            for: style.layoutPreset,
            in: CGSize(width: diameter, height: diameter)
        )
        let baseValueSize = diameter * 0.145
        let baseLabelSize = diameter * 0.038
        let baseUnitSize = diameter * 0.045
        let regions: [OverlayRunningGaugeRegionLayout] = regionFrames.compactMap { frame in
            guard let config = style.regions.first(where: { $0.region == frame.region }) else {
                return nil
            }
            let canvasRect = CGRect(
                x: rect.minX + frame.rect.minX,
                y: rect.minY + frame.rect.minY,
                width: frame.rect.width,
                height: frame.rect.height
            )
            let valueSize = max(baseValueSize * config.valueFontScale, 8)
            let labelSize = max(baseLabelSize * (config.labelFontScale / 0.32), 7)
            let unitSize = max(baseUnitSize * (config.unitFontScale / 0.42), 7)
            let components = OverlayValueFormatter.components(
                for: config.metric.elementType,
                activity: context.activity,
                elapsedTime: context.elapsedTime
            )
            return OverlayRunningGaugeRegionLayout(
                config: config,
                rect: canvasRect,
                components: components,
                valueFontSize: valueSize,
                labelFontSize: labelSize,
                unitFontSize: unitSize
            )
        }

        return OverlayRunningGaugeRenderLayout(
            style: style,
            rect: rect,
            diameter: diameter,
            progress: clampedProgress(progress),
            regions: regions,
            outerRingWidth: max(diameter * style.outerRingWidthScale, 1.5),
            progressRingWidth: max(diameter * style.progressRingWidthScale, 1.5),
            tickLength: diameter * 0.025,
            majorTickLength: diameter * 0.040,
            safeRadius: diameter * 0.40
        )
    }

    static func intervalHUDBarLayout(for element: OverlayElement, in context: OverlayRenderContext) -> IntervalHUDBarRenderLayout {
        let style = element.style.intervalHUDBar
        let width = context.scaled(style.width * element.scale)
        let height = context.scaled(style.height * element.scale)
        let rect = centeredRect(for: element, size: CGSize(width: width, height: height), canvasSize: context.canvasSize)
        let lap = context.activity.currentLap(at: context.elapsedTime)
        let t = min(max(context.elapsedTime, 0), context.activity.duration)
        let lapEnd = lap?.endElapsedTime ?? max(context.activity.duration, 1)
        let remainingTime = max(lapEnd - t, 0)
        let remainingDistance = max((lap?.startDistanceMeters ?? 0) + (lap?.totalDistanceMeters ?? context.activity.distanceMeters) - context.activity.distance(at: t), 0)
        let progress = context.activity.lapProgress(at: t, byDistance: style.progressMode == .distance)
        let zoneSnapshot = HeartRateZonePreferences.currentSnapshot()
        let currentHR = context.activity.heartRate(at: t)
        let currentPace = context.activity.pace(at: t)
        let activeZoneIndex = resolvedZoneIndex(heartRate: currentHR, paceSecondsPerKm: currentPace, snapshot: zoneSnapshot)
        let bottomBarActiveZoneIndex = resolvedBottomBarZoneIndex(
            mode: style.bottomBarMode,
            heartRate: currentHR,
            paceSecondsPerKm: currentPace,
            snapshot: zoneSnapshot
        )
        let phaseColor = lapKindColor(lap?.kind ?? .unknown, activeZoneIndex: activeZoneIndex)
        let remainingTimeText = formatDuration(remainingTime)
        let remainingDistanceText = formatDistanceMeters(remainingDistance)

        return IntervalHUDBarRenderLayout(
            style: style,
            rect: rect,
            phaseLabel: phaseLabel(lap?.kind ?? .unknown),
            phaseDetail: phaseDetail(
                style: style,
                lap: lap,
                remainingTimeText: remainingTimeText,
                remainingDistanceText: remainingDistanceText
            ),
            phaseColor: phaseColor,
            repText: repText(activity: context.activity, lap: lap),
            remainingTimeText: remainingTimeText,
            remainingDistanceText: remainingDistanceText,
            remainingPrimaryLabel: "LEFT",
            remainingPrimaryText: style.remainingPrimary == .time ? remainingTimeText : remainingDistanceText,
            remainingSecondaryText: style.remainingPrimary == .time ? remainingDistanceText : remainingTimeText,
            progress: clampedProgress(progress),
            zoneItem: intervalZoneItem(
                style: style,
                activity: context.activity,
                elapsedTime: t,
                zoneIndex: activeZoneIndex
            ),
            metricItems: intervalMetricItems(
                style: style,
                activity: context.activity,
                elapsedTime: t,
                zoneIndex: activeZoneIndex,
                zoneSnapshot: zoneSnapshot
            ),
            zoneSegments: intervalZoneSegments(snapshot: zoneSnapshot),
            activeZoneIndex: activeZoneIndex,
            bottomBarActiveZoneIndex: bottomBarActiveZoneIndex,
            zoneMarker: intervalZoneMarker(
                style: style,
                heartRate: currentHR,
                paceSecondsPerKm: currentPace,
                snapshot: zoneSnapshot,
                zoneIndex: bottomBarActiveZoneIndex
            ),
            thresholdZoneMarker: intervalThresholdZoneMarker(style: style, snapshot: zoneSnapshot),
            labelText: scaled(style.labelText, scale: element.scale, context: context),
            primaryValueText: scaled(style.primaryValueText, scale: element.scale, context: context),
            phaseText: scaled(style.phaseText, scale: element.scale, context: context),
            phaseDetailText: scaled(style.phaseDetailText, scale: element.scale, context: context),
            metricValueText: scaled(style.metricValueText, scale: element.scale, context: context),
            metricUnitText: scaled(style.metricUnitText, scale: element.scale, context: context),
            barHeight: context.scaled(10 * element.scale)
        )
    }

    static func intervalTimelineLayout(for element: OverlayElement, in context: OverlayRenderContext) -> IntervalTimelineRenderLayout {
        var style = element.style.intervalTimeline
        let kindPalette = IntervalKindColorPreferences.currentSnapshot()
        style.warmupColor = kindPalette.warmup
        style.activeColor = kindPalette.active
        style.restColor = kindPalette.rest
        style.cooldownColor = kindPalette.cooldown
        let width = context.scaled(style.width * element.scale)
        let markerTriangleHeight = context.scaled(6 * element.scale)
        let markerStackSpacing = context.scaled(2 * element.scale)
        let markerLabelHeight = context.scaled(max(style.markerFontSize * 1.4, 14) * element.scale)
        let markerGap = context.scaled(4 * element.scale)
        let markerBottomPadding = context.scaled(4 * element.scale)
        let markerStackHeight = markerTriangleHeight + markerStackSpacing + markerLabelHeight
        let horizontalPadding = context.scaled(16 * element.scale)
        let verticalPadding = context.scaled(6 * element.scale)
        let segmentAreaHeight = context.scaled(style.height * element.scale)
        let innerSegmentHeight = max(segmentAreaHeight - verticalPadding * 2, 1)
        let normalHeightCap = min(context.scaled(style.segmentHeight * element.scale), innerSegmentHeight)
        let currentHeightCap = min(normalHeightCap * style.currentSegmentHeightScale, innerSegmentHeight)
        let segmentMidYRel = verticalPadding + innerSegmentHeight / 2
        let currentBottomRel = segmentMidYRel + currentHeightCap / 2
        let markerTopYRel = currentBottomRel + markerGap
        let markerBottomRel = markerTopYRel + markerStackHeight
        let height = markerBottomRel + markerBottomPadding
        let rect = centeredRect(for: element, size: CGSize(width: width, height: height), canvasSize: context.canvasSize)
        let contentRect = CGRect(
            x: rect.minX + horizontalPadding,
            y: rect.minY + verticalPadding,
            width: max(rect.width - horizontalPadding * 2, 1),
            height: innerSegmentHeight
        )
        let laps = context.activity.laps
        let t = min(max(context.elapsedTime, 0), context.activity.duration)
        let currentIndex = laps.indices.last { laps[$0].startElapsedTime <= t } ?? laps.indices.first
        let shouldCenter = style.mode == .centeredWindow || laps.count > style.maxFullSegments
        let visibleRange: Range<Int>
        if laps.isEmpty {
            visibleRange = 0..<0
        } else if shouldCenter, let currentIndex {
            let neighbors = max(style.visibleNeighbors, 0)
            let start = max(currentIndex - neighbors, 0)
            let end = min(currentIndex + neighbors + 1, laps.count)
            visibleRange = start..<end
        } else {
            visibleRange = 0..<laps.count
        }

        let visibleLaps = visibleRange.map { laps[$0] }
        let leftOverflow = max(visibleRange.lowerBound, 0)
        let rightOverflow = max(laps.count - visibleRange.upperBound, 0)
        let ghostEdgeInsetUnscaled = 14.0
        let ellipsisInsetUnscaled = 38.0
        let pillCenterInsetUnscaled = 64.0
        let pillWidthUnscaled = 36.0
        let pillHeightUnscaled = 26.0
        let pillToSegmentGapUnscaled = 12.0
        let ghostInset = context.scaled(ghostEdgeInsetUnscaled * element.scale)
        let ellipsisInset = context.scaled(ellipsisInsetUnscaled * element.scale)
        let pillInset = context.scaled(pillCenterInsetUnscaled * element.scale)
        let pillSize = CGSize(
            width: context.scaled(pillWidthUnscaled * element.scale),
            height: context.scaled(pillHeightUnscaled * element.scale)
        )
        let pillRightEdgeFromRectEdge = pillInset + pillSize.width / 2
        let pillToSegmentGap = context.scaled(pillToSegmentGapUnscaled * element.scale)
        let edgeOnlyWidth = context.scaled(46 * element.scale)
        let overflowClusterWidth = max(pillRightEdgeFromRectEdge + pillToSegmentGap - horizontalPadding, 0)
        let leadingOverflowWidth = leftOverflow > 0 ? (style.overflowPillsEnabled ? overflowClusterWidth : edgeOnlyWidth) : 0
        let trailingOverflowWidth = rightOverflow > 0 ? (style.overflowPillsEnabled ? overflowClusterWidth : edgeOnlyWidth) : 0
        let segmentArea = CGRect(
            x: contentRect.minX + leadingOverflowWidth,
            y: contentRect.minY,
            width: max(contentRect.width - leadingOverflowWidth - trailingOverflowWidth, 1),
            height: contentRect.height
        )
        let gap = context.scaled(style.segmentGap * element.scale)
        let normalHeight = normalHeightCap
        let currentHeight = currentHeightCap
        let minWidth = context.scaled(style.minSegmentWidth * element.scale)
        let currentProgress = clampedProgress(context.activity.lapProgress(at: t, byDistance: false))
        let currentVisibleOffset = currentIndex.flatMap { visibleRange.contains($0) ? $0 - visibleRange.lowerBound : nil }

        let segmentWidths = intervalTimelineSegmentWidths(
            laps: visibleLaps,
            currentOffset: currentVisibleOffset,
            style: style,
            availableWidth: segmentArea.width,
            gap: gap,
            minWidth: minWidth,
            centered: shouldCenter
        )
        var cursorX = segmentArea.minX
        var segments: [IntervalTimelineSegmentLayout] = []
        for (offset, lap) in visibleLaps.enumerated() {
            let width = segmentWidths.indices.contains(offset) ? segmentWidths[offset] : minWidth
            let isCurrent = currentVisibleOffset == offset
            let h = isCurrent ? currentHeight : normalHeight
            let y = segmentArea.midY - h / 2
            let rect = CGRect(x: cursorX, y: y, width: width, height: h)
            let completed = lap.endElapsedTime <= t
            segments.append(IntervalTimelineSegmentLayout(
                id: lap.id,
                lapIndex: lap.lapIndex,
                rect: rect,
                label: intervalTimelineLabel(for: lap, mode: style.primaryLabelMode),
                durationText: intervalTimelineDuration(lap.totalElapsedTime),
                kind: lap.kind,
                color: intervalTimelineColor(for: lap.kind, style: style),
                opacity: isCurrent ? 1 : (completed ? style.completedOpacity : style.futureOpacity),
                isCurrent: isCurrent,
                isCompleted: completed
            ))
            cursorX += width + gap
        }

        let currentSegment = segments.first(where: \.isCurrent)
        let markerX: Double
        if let currentSegment {
            switch style.markerPosition {
            case .liveProgress:
                markerX = currentSegment.rect.minX + currentSegment.rect.width * clampedProgress(currentProgress)
            case .segmentCenter:
                markerX = currentSegment.rect.midX
            }
        } else {
            markerX = segmentArea.midX
        }
        let markerTopY = rect.minY + markerTopYRel

        return IntervalTimelineRenderLayout(
            style: style,
            rect: rect,
            contentRect: contentRect,
            segments: segments,
            leftOverflowCount: leftOverflow,
            rightOverflowCount: rightOverflow,
            currentProgress: currentProgress,
            markerX: markerX,
            markerTopY: markerTopY,
            markerTriangleHeight: markerTriangleHeight,
            markerLabelHeight: markerLabelHeight,
            markerLabel: style.markerLabel.isEmpty ? "NOW" : style.markerLabel,
            repText: style.repCounterEnabled ? intervalTimelineRepText(activity: context.activity, currentIndex: currentIndex) : nil,
            labelFontSize: context.scaled(16 * element.scale),
            durationFontSize: context.scaled(12 * element.scale),
            pillFontSize: context.scaled(11 * element.scale),
            ghostFontSize: context.scaled(12 * element.scale),
            cornerRadius: context.scaled(element.style.backgroundRadius * element.scale),
            overflowGhostInset: ghostInset,
            overflowEllipsisInset: ellipsisInset,
            overflowPillInset: pillInset,
            overflowPillSize: pillSize
        )
    }

    private static func intervalTimelineSegmentWidths(
        laps: [LapRecord],
        currentOffset: Int?,
        style: IntervalTimelineStyle,
        availableWidth: Double,
        gap: Double,
        minWidth: Double,
        centered: Bool
    ) -> [Double] {
        guard !laps.isEmpty else { return [] }
        let totalGap = gap * Double(max(laps.count - 1, 0))
        let usableWidth = max(availableWidth - totalGap, 1)
        if centered {
            let fraction = min(max(style.currentSegmentWidthFraction, 0.1), 0.6)
            if let currentOffset, laps.indices.contains(currentOffset), laps.count > 1 {
                var currentWidth = max(minWidth, usableWidth * fraction)
                var othersWidth = max(minWidth, (usableWidth - currentWidth) / Double(laps.count - 1))
                let total = currentWidth + othersWidth * Double(laps.count - 1)
                if total > usableWidth {
                    let scale = usableWidth / total
                    currentWidth *= scale
                    othersWidth *= scale
                }
                return laps.indices.map { $0 == currentOffset ? currentWidth : othersWidth }
            }
            var base = max(minWidth, usableWidth / Double(laps.count))
            let total = base * Double(laps.count)
            if total > usableWidth {
                base = usableWidth / Double(laps.count)
            }
            return Array(repeating: base, count: laps.count)
        }

        let totalDuration = max(laps.map(\.totalElapsedTime).reduce(0, +), 1)
        var widths = laps.map { max(minWidth, usableWidth * ($0.totalElapsedTime / totalDuration)) }
        let sum = widths.reduce(0, +)
        if sum > usableWidth {
            let factor = usableWidth / sum
            widths = widths.map { $0 * factor }
        }
        return widths
    }

    private static func intervalTimelineLabel(for lap: LapRecord, mode: IntervalTimelineLabelMode) -> String {
        if mode == .distance, lap.kind == .active, lap.totalDistanceMeters > 0 {
            return formatDistanceMeters(lap.totalDistanceMeters).replacingOccurrences(of: " ", with: "")
        }
        switch lap.kind {
        case .warmup: return "WU"
        case .active: return "1min"
        case .rest: return "R"
        case .cooldown: return "CD"
        case .unknown: return "LAP"
        }
    }

    private static func intervalTimelineDuration(_ duration: TimeInterval) -> String {
        formatDuration(duration)
    }

    private static func intervalTimelineColor(for kind: LapKind, style: IntervalTimelineStyle) -> OverlayColor {
        switch kind {
        case .warmup: style.warmupColor
        case .active: style.activeColor
        case .rest: style.restColor
        case .cooldown: style.cooldownColor
        case .unknown: style.unknownColor
        }
    }

    private static func intervalTimelineRepText(activity: ActivityTimeline, currentIndex: Int?) -> String? {
        let activeLaps = activity.laps.filter { $0.kind == .active }
        guard !activeLaps.isEmpty else { return nil }
        guard let currentIndex, activity.laps.indices.contains(currentIndex) else {
            return "Rep 1 / \(activeLaps.count)"
        }
        let lap = activity.laps[currentIndex]
        if lap.kind == .active,
           let activeIndex = activeLaps.firstIndex(where: { $0.id == lap.id }) {
            return "Rep \(activeIndex + 1) / \(activeLaps.count)"
        }
        let completed = activeLaps.filter { $0.endElapsedTime <= lap.startElapsedTime }.count
        return "Rep \(min(completed + 1, activeLaps.count)) / \(activeLaps.count)"
    }

    private static func scaled(_ text: IntervalHUDBarTextStyle, scale: Double, context: OverlayRenderContext) -> IntervalHUDBarTextStyle {
        IntervalHUDBarTextStyle(
            fontName: text.fontName,
            fontSize: context.scaled(text.fontSize * scale),
            fontWeight: text.fontWeight
        )
    }

    private static func intervalMetricItems(
        style: IntervalHUDBarStyle,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        zoneIndex: Int?,
        zoneSnapshot: HeartRateZoneSnapshot
    ) -> [IntervalHUDBarMetricItem] {
        style.metricSlots.compactMap { slot in
            switch slot.metric {
            case .heartRateZone, .hrDrop:
                return nil
            case .heartRate, .pace, .avgPace, .lapPace, .calories, .elapsedTime, .realTime, .distance, .elevation, .cadence, .power, .verticalOscillation, .groundContactTime, .strideLength, .verticalRatio, .groundContactBalance, .temperature, .grade:
                guard let elementType = slot.metric.elementType else { return nil }
                let components = OverlayValueFormatter.components(
                    for: elementType,
                    unit: slot.unitOption,
                    activity: activity,
                    elapsedTime: elapsedTime
                )
                return IntervalHUDBarMetricItem(
                    metric: slot.metric,
                    label: components.shortLabel.uppercased(),
                    value: components.value,
                    unit: components.unit,
                    accentColor: nil
                )
            }
        }
    }

    private static func intervalZoneItem(
        style: IntervalHUDBarStyle,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        zoneIndex: Int?
    ) -> IntervalHUDBarMetricItem? {
        guard style.showsZone else { return nil }
        if style.zoneDisplayMode == .hrDropAtRest,
           activity.currentLap(at: elapsedTime)?.kind == .rest {
            switch style.hrDropMode {
            case .bpm:
                let drop = activity.recoveryDrop(at: elapsedTime).map(String.init) ?? "--"
                return IntervalHUDBarMetricItem(metric: .hrDrop, label: "HR DROP", value: drop, unit: "bpm", accentColor: nil)
            case .percent:
                let drop = activity.recoveryDropPercent(at: elapsedTime).map { "\(Int($0.rounded()))" } ?? "--"
                return IntervalHUDBarMetricItem(metric: .hrDrop, label: "HR DROP", value: drop, unit: "%", accentColor: nil)
            }
        }
        return IntervalHUDBarMetricItem(
            metric: .heartRateZone,
            label: "ZONE",
            value: zoneIndex.map { "Z\($0 + 1)" } ?? "--",
            unit: "",
            accentColor: zoneIndex.map(HRZonePalette.overlayColor(forIndex:))
        )
    }

    private static func intervalZoneSegments(snapshot: HeartRateZoneSnapshot) -> [IntervalHUDBarZoneSegment] {
        (0..<snapshot.zoneCount).map { index in
            IntervalHUDBarZoneSegment(
                index: index,
                label: "Z\(index + 1)",
                color: HRZonePalette.overlayColor(forIndex: index)
            )
        }
    }

    private static func resolvedZoneIndex(heartRate: Int?, paceSecondsPerKm: Double?, snapshot: HeartRateZoneSnapshot) -> Int? {
        let visibleZones = Array(snapshot.zones.prefix(snapshot.zoneCount))
        if let heartRate,
           let hrIndex = resolvedHeartRateZoneIndex(heartRate: heartRate, zones: visibleZones) {
            return hrIndex
        }
        guard let pace = paceSecondsPerKm, pace > 0 else { return nil }
        return resolvedPaceZoneIndex(paceSecondsPerKm: pace, zones: visibleZones)
    }

    private static func resolvedBottomBarZoneIndex(
        mode: IntervalHUDBarBottomBarMode,
        heartRate: Int?,
        paceSecondsPerKm: Double?,
        snapshot: HeartRateZoneSnapshot
    ) -> Int? {
        let visibleZones = Array(snapshot.zones.prefix(snapshot.zoneCount))
        switch mode {
        case .heartRateZones:
            guard let heartRate else { return nil }
            return resolvedHeartRateZoneIndex(heartRate: heartRate, zones: visibleZones)
        case .paceZones:
            guard let paceSecondsPerKm, paceSecondsPerKm > 0 else { return nil }
            return resolvedPaceZoneIndex(paceSecondsPerKm: paceSecondsPerKm, zones: visibleZones)
        case .none, .lapProgress:
            return nil
        }
    }

    private static func resolvedHeartRateZoneIndex(heartRate: Int, zones: [HeartRateZone]) -> Int? {
        zones.firstIndex { zone in
            let minHR = zone.minHR ?? Int.min
            let maxHR = zone.maxHR ?? Int.max
            return heartRate >= minHR && heartRate <= maxHR && (zone.minHR != nil || zone.maxHR != nil)
        }
    }

    private static func resolvedPaceZoneIndex(paceSecondsPerKm: Double, zones: [HeartRateZone]) -> Int? {
        zones.firstIndex { zone in
            guard zone.minPaceSecPerKm != nil || zone.maxPaceSecPerKm != nil else { return false }
            let a = Double(zone.minPaceSecPerKm ?? Int.min)
            let b = Double(zone.maxPaceSecPerKm ?? Int.max)
            return paceSecondsPerKm >= min(a, b) && paceSecondsPerKm <= max(a, b)
        }
    }

    private static func intervalZoneMarker(
        style: IntervalHUDBarStyle,
        heartRate: Int?,
        paceSecondsPerKm: Double?,
        snapshot: HeartRateZoneSnapshot,
        zoneIndex: Int?
    ) -> IntervalHUDBarZoneMarker? {
        guard style.zoneMarkerEnabled,
              style.bottomBarMode == .heartRateZones || style.bottomBarMode == .paceZones,
              let zoneIndex,
              zoneIndex >= 0,
              zoneIndex < snapshot.zoneCount,
              zoneIndex < snapshot.zones.count
        else { return nil }

        let zone = snapshot.zones[zoneIndex]
        switch style.bottomBarMode {
        case .heartRateZones:
            guard let heartRate else { return nil }
            return IntervalHUDBarZoneMarker(
                role: .current,
                zoneIndex: zoneIndex,
                fractionInZone: heartRateFraction(heartRate, zone: zone),
                valueText: "\(heartRate) bpm",
                color: HRZonePalette.overlayColor(forIndex: zoneIndex)
            )
        case .paceZones:
            guard let paceSecondsPerKm, paceSecondsPerKm > 0 else { return nil }
            return IntervalHUDBarZoneMarker(
                role: .current,
                zoneIndex: zoneIndex,
                fractionInZone: paceFraction(paceSecondsPerKm, zone: zone),
                valueText: formatPace(secondsPerKm: paceSecondsPerKm, paceUnit: snapshot.paceUnit),
                color: HRZonePalette.overlayColor(forIndex: zoneIndex)
            )
        case .none, .lapProgress:
            return nil
        }
    }

    private static func intervalThresholdZoneMarker(
        style: IntervalHUDBarStyle,
        snapshot: HeartRateZoneSnapshot
    ) -> IntervalHUDBarZoneMarker? {
        guard style.thresholdZoneMarkerEnabled,
              style.bottomBarMode == .heartRateZones || style.bottomBarMode == .paceZones
        else { return nil }
        let visibleZones = Array(snapshot.zones.prefix(snapshot.zoneCount))
        switch style.bottomBarMode {
        case .heartRateZones:
            guard let thresholdHR = snapshot.thresholdHR,
                  let zoneIndex = resolvedHeartRateZoneIndex(heartRate: thresholdHR, zones: visibleZones),
                  zoneIndex >= 0,
                  zoneIndex < snapshot.zones.count
            else { return nil }
            let zone = snapshot.zones[zoneIndex]
            return IntervalHUDBarZoneMarker(
                role: .threshold,
                zoneIndex: zoneIndex,
                fractionInZone: heartRateFraction(thresholdHR, zone: zone),
                valueText: "T",
                color: HRZonePalette.overlayColor(forIndex: zoneIndex)
            )
        case .paceZones:
            guard let thresholdPace = snapshot.thresholdPaceSecPerKm,
                  thresholdPace > 0,
                  let zoneIndex = resolvedPaceZoneIndex(paceSecondsPerKm: Double(thresholdPace), zones: visibleZones),
                  zoneIndex >= 0,
                  zoneIndex < snapshot.zones.count
            else { return nil }
            let zone = snapshot.zones[zoneIndex]
            return IntervalHUDBarZoneMarker(
                role: .threshold,
                zoneIndex: zoneIndex,
                fractionInZone: paceFraction(Double(thresholdPace), zone: zone),
                valueText: "T",
                color: HRZonePalette.overlayColor(forIndex: zoneIndex)
            )
        case .none, .lapProgress:
            return nil
        }
    }

    private static func formatPace(secondsPerKm: Double, paceUnit: PaceUnit) -> String {
        "\(PaceConversion.format(secondsPerKm: Int(secondsPerKm.rounded()), unit: paceUnit)) \(paceUnit.label)"
    }

    private static func heartRateFraction(_ heartRate: Int, zone: HeartRateZone) -> Double {
        guard let minHR = zone.minHR,
              let maxHR = zone.maxHR,
              maxHR > minHR
        else { return 0.5 }
        return clampedProgress(Double(heartRate - minHR) / Double(maxHR - minHR))
    }

    private static func paceFraction(_ paceSecondsPerKm: Double, zone: HeartRateZone) -> Double {
        guard let minPace = zone.minPaceSecPerKm,
              let maxPace = zone.maxPaceSecPerKm,
              minPace != maxPace
        else { return 0.5 }
        let lower = Double(min(minPace, maxPace))
        let upper = Double(max(minPace, maxPace))
        return clampedProgress((paceSecondsPerKm - lower) / (upper - lower))
    }

    static func intervalZoneSegmentFrames(
        segmentCount: Int,
        activeIndex: Int?,
        activeWidthShare: Double
    ) -> [IntervalHUDBarZoneSegmentFrame] {
        guard segmentCount > 0 else { return [] }
        let equalWidth = 1 / Double(segmentCount)
        let requestedActiveWidth = min(max(activeWidthShare, 0), 0.5)
        guard let activeIndex,
              activeIndex >= 0,
              activeIndex < segmentCount,
              requestedActiveWidth > equalWidth
        else {
            return (0..<segmentCount).map { index in
                IntervalHUDBarZoneSegmentFrame(index: index, start: Double(index) * equalWidth, width: equalWidth)
            }
        }

        let inactiveWidth = (1 - requestedActiveWidth) / Double(max(segmentCount - 1, 1))
        var cursor = 0.0
        return (0..<segmentCount).map { index in
            let width = index == activeIndex ? requestedActiveWidth : inactiveWidth
            defer { cursor += width }
            return IntervalHUDBarZoneSegmentFrame(index: index, start: cursor, width: width)
        }
    }

    private static func repText(activity: ActivityTimeline, lap: LapRecord?) -> String {
        let activeLaps = activity.laps.filter { $0.kind == .active }
        guard !activeLaps.isEmpty else { return "-- / --" }
        guard let lap else { return "1 / \(activeLaps.count)" }
        if lap.kind == .active,
           let index = activeLaps.firstIndex(where: { $0.id == lap.id }) {
            return "\(index + 1) / \(activeLaps.count)"
        }
        let completed = activeLaps.filter { $0.endElapsedTime <= lap.startElapsedTime }.count
        return "\(min(completed + 1, activeLaps.count)) / \(activeLaps.count)"
    }

    private static func phaseLabel(_ kind: LapKind) -> String {
        switch kind {
        case .warmup: "WU"
        case .active: "WORK"
        case .rest: "REST"
        case .cooldown: "CD"
        case .unknown: "LAP"
        }
    }

    private static func phaseDetail(
        style: IntervalHUDBarStyle,
        lap: LapRecord?,
        remainingTimeText: String,
        remainingDistanceText: String
    ) -> String {
        guard lap != nil else { return "" }
        let mode = lap?.kind == .rest ? style.restPhaseDetailMode : style.phaseDetailMode
        switch mode {
        case .time:
            return remainingTimeText
        case .distance:
            return remainingDistanceText
        }
    }

    private static func lapKindColor(_ kind: LapKind, activeZoneIndex: Int?) -> OverlayColor {
        if kind == .active, let activeZoneIndex {
            return HRZonePalette.overlayColor(forIndex: activeZoneIndex)
        }
        if let color = IntervalKindColorPreferences.currentSnapshot().color(for: kind) {
            return color
        }
        // Only .unknown reaches here — keep the existing green fallback.
        return OverlayColor(red: 0.25, green: 0.82, blue: 0.38, alpha: 1)
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let total = max(Int(duration.rounded()), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private static func formatDistanceMeters(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        }
        return "\(Int(meters.rounded())) m"
    }

    private static func computeGaugeProgress(style: RunningGaugeStyle, context: OverlayRenderContext) -> Double {
        switch style.progressMode {
        case .none:
            return 0
        case .distanceTarget:
            return context.activity.distanceMeters > 0
                ? context.activity.distance(at: context.elapsedTime) / context.activity.distanceMeters
                : 0
        case .elapsedTimeTarget:
            return context.activity.duration > 0
                ? context.elapsedTime / context.activity.duration
                : 0
        case .heartRateZone, .powerZone, .paceIntensity:
            // Zone modes: fall back to elapsed-time progression until the
            // user wires a custom max into the project model.
            return context.activity.duration > 0
                ? context.elapsedTime / context.activity.duration
                : 0
        case .customPercentage:
            return 0.5
        }
    }

    static func routeMapLayout(for element: OverlayElement, in context: OverlayRenderContext) -> OverlayRouteMapRenderLayout {
        let mapShape = element.style.routeMapShape
        let designWidth = element.style.routeMapWidth
        let designHeight = element.style.routeMapHeight
        let width = context.scaled(designWidth * element.scale)
        let height = context.scaled(designHeight * element.scale)
        // Circles ignore aspect: take the shorter edge as the diameter so the
        // user can drag the bounding box wider/taller without distorting the
        // circular window.
        let side = min(width, height)
        let mapSize = mapShape == .circle ? CGSize(width: side, height: side) : CGSize(width: width, height: height)
        // Padding scales with the box size so wider boxes still keep the
        // route well inside the visible map. The minimum keeps tiny boxes
        // (≤120 pt) from squashing the route to the center.
        let paddingDesign = max(min(min(designWidth, designHeight) * 0.12, 32), 12)
        let padding = context.scaled(paddingDesign * element.scale)
        // Map background visibility is purely driven by the background style
        // now that the route style preset no longer encodes "show map".
        let backgroundEnabled = element.style.routeMapBackgroundStyle != .none
        let provider: OverlayRouteMapProvider = backgroundEnabled ? .mapKit : .none
        let progress = context.activity.duration > 0 ? context.elapsedTime / context.activity.duration : 0

        // Stats bar: placement-aware layout relative to the map container.
        let statsBarConfig = element.style.routeMapStatsBar
        let statsBarVisible = statsBarConfig.visible && statsBarConfig.slots.contains { $0.visible }
        let placement = statsBarConfig.placement
        let isInside = statsBarConfig.inside
        let barThickness = statsBarVisible ? context.scaled(statsBarConfig.height * element.scale) : 0

        // Total element size expands for attached placements; inside placements
        // overlay the map so the total size stays at mapSize.
        let totalSize: CGSize
        if isInside || !statsBarVisible {
            totalSize = mapSize
        } else if placement.isVertical {
            totalSize = CGSize(width: mapSize.width + barThickness, height: mapSize.height)
        } else {
            totalSize = CGSize(width: mapSize.width, height: mapSize.height + barThickness)
        }
        let totalRect = centeredRect(for: element, size: totalSize, canvasSize: context.canvasSize)

        let mapRect: CGRect
        let barRect: CGRect
        if statsBarVisible {
            let autoSpan = placement.isVertical ? mapSize.height : mapSize.width
            let span = isInside
                ? autoSpan
                : (statsBarConfig.width > 0
                ? min(context.scaled(statsBarConfig.width * element.scale), autoSpan)
                : autoSpan)
            let xOffset = context.scaled(statsBarConfig.offsetX * element.scale)
            let yOffset = context.scaled(statsBarConfig.offsetY * element.scale)

            switch placement {
            case .bottomAttached:
                mapRect = CGRect(origin: totalRect.origin, size: mapSize)
                if isInside {
                    barRect = CGRect(
                        x: mapRect.midX - span * 0.5 + xOffset,
                        y: mapRect.maxY - barThickness + yOffset,
                        width: span,
                        height: barThickness
                    )
                } else {
                    barRect = CGRect(
                        x: mapRect.midX - span * 0.5 + xOffset,
                        y: mapRect.maxY + yOffset,
                        width: span,
                        height: barThickness
                    )
                }
            case .topAttached:
                if isInside {
                    mapRect = totalRect
                    barRect = CGRect(
                        x: totalRect.midX - span * 0.5 + xOffset,
                        y: totalRect.minY + yOffset,
                        width: span,
                        height: barThickness
                    )
                } else {
                    barRect = CGRect(
                        x: totalRect.midX - span * 0.5 + xOffset,
                        y: totalRect.minY + yOffset,
                        width: span,
                        height: barThickness
                    )
                    mapRect = CGRect(x: totalRect.minX, y: barRect.maxY, width: mapSize.width, height: mapSize.height)
                }
            case .leftAttached:
                if isInside {
                    mapRect = totalRect
                    barRect = CGRect(
                        x: totalRect.minX + xOffset,
                        y: totalRect.midY - span * 0.5 + yOffset,
                        width: barThickness,
                        height: span
                    )
                } else {
                    barRect = CGRect(
                        x: totalRect.minX + xOffset,
                        y: totalRect.midY - span * 0.5 + yOffset,
                        width: barThickness,
                        height: span
                    )
                    mapRect = CGRect(x: barRect.maxX, y: totalRect.minY, width: mapSize.width, height: mapSize.height)
                }
            case .rightAttached:
                mapRect = CGRect(origin: totalRect.origin, size: mapSize)
                if isInside {
                    barRect = CGRect(
                        x: mapRect.maxX - barThickness + xOffset,
                        y: totalRect.midY - span * 0.5 + yOffset,
                        width: barThickness,
                        height: span
                    )
                } else {
                    barRect = CGRect(
                        x: mapRect.maxX + xOffset,
                        y: totalRect.midY - span * 0.5 + yOffset,
                        width: barThickness,
                        height: span
                    )
                }
            case .insideBottom:
                mapRect = totalRect
                barRect = CGRect(
                    x: totalRect.midX - span * 0.5 + xOffset,
                    y: totalRect.maxY - barThickness + yOffset,
                    width: span,
                    height: barThickness
                )
            case .insideTop:
                mapRect = totalRect
                barRect = CGRect(
                    x: totalRect.midX - span * 0.5 + xOffset,
                    y: totalRect.minY + yOffset,
                    width: span,
                    height: barThickness
                )
            }
        } else {
            mapRect = totalRect
            barRect = .zero
        }

        let statsBarLayout: OverlayRouteMapStatsBarLayout? = statsBarVisible ? {
            let visibleSlots = statsBarConfig.slots.filter { $0.visible }
            let items = visibleSlots.map { slot -> OverlayRouteMapStatsBarItemLayout in
                if slot.metric == .progress {
                    let progress = context.activity.distanceMeters > 0
                        ? context.activity.distance(at: context.elapsedTime) / context.activity.distanceMeters
                        : context.elapsedTime / max(context.activity.duration, 1)
                    let label = slot.customLabel.isEmpty ? slot.metric.label : slot.customLabel
                    return OverlayRouteMapStatsBarItemLayout(value: "\(Int((clampedProgress(progress) * 100).rounded()))%", unit: "", label: label)
                }
                let comps = OverlayValueFormatter.components(
                    for: slot.metric.elementType,
                    activity: context.activity,
                    elapsedTime: context.elapsedTime
                )
                let label = slot.customLabel.isEmpty ? slot.metric.label : slot.customLabel
                return OverlayRouteMapStatsBarItemLayout(value: comps.value, unit: comps.unit, label: label)
            }
            return OverlayRouteMapStatsBarLayout(
                rect: barRect,
                isInside: isInside,
                containerRect: mapRect,
                containerShape: mapShape,
                containerCornerRadius: mapShape == .circle ? 0 : context.scaled(element.style.routeMapCornerRadius * element.scale),
                backgroundOpacity: statsBarConfig.backgroundOpacity,
                blurRadius: context.scaled(statsBarConfig.blurRadius * element.scale),
                dividerOpacity: statsBarConfig.dividerOpacity,
                cornerRadius: isInside ? 0 : context.scaled(statsBarConfig.cornerRadius * element.scale),
                itemSpacing: context.scaled(statsBarConfig.itemSpacing * element.scale),
                layoutMode: statsBarConfig.layoutMode,
                placement: placement,
                items: items,
                fontName: element.style.fontName,
                valueFontName: statsBarConfig.valueFontName,
                valueFontSize: context.scaled(statsBarConfig.valueFontSize * element.scale),
                valueFontWeight: statsBarConfig.valueFontWeight,
                valueColor: statsBarConfig.valueColor,
                labelFontName: statsBarConfig.labelFontName,
                labelFontSize: context.scaled(statsBarConfig.labelFontSize * element.scale),
                labelFontWeight: statsBarConfig.labelFontWeight,
                labelColor: statsBarConfig.labelColor
            )
        }() : nil

        var routeContentRect = mapRect.insetBy(dx: padding, dy: padding)
        if let statsBar = statsBarLayout, statsBar.isInside {
            // Reserve chart area so inside Stats Bar never covers route geometry.
            let reserved = statsBar.rect.height + context.scaled(6 * element.scale)
            if placement.isVertical {
                if placement == .leftAttached {
                    routeContentRect.origin.x += reserved
                    routeContentRect.size.width = max(routeContentRect.width - reserved, 1)
                } else {
                    routeContentRect.size.width = max(routeContentRect.width - reserved, 1)
                }
            } else {
                if placement == .topAttached {
                    routeContentRect.origin.y += reserved
                    routeContentRect.size.height = max(routeContentRect.height - reserved, 1)
                } else {
                    routeContentRect.size.height = max(routeContentRect.height - reserved, 1)
                }
            }
        }

        return OverlayRouteMapRenderLayout(
            preset: element.style.routeMapPreset,
            provider: provider,
            rect: mapRect,
            contentRect: routeContentRect,
            cornerRadius: mapShape == .circle ? 0 : context.scaled(element.style.routeMapCornerRadius * element.scale),
            shape: mapShape,
            edgeFade: element.style.routeMapEdgeFade,
            fadeAmount: element.style.routeMapFadeAmount,
            borderVisible: element.style.routeMapBorderVisible,
            lineWidth: max(context.scaled(4 * element.scale), 1.5),
            glowRadius: context.scaled(11 * element.scale),
            mapOpacity: element.style.routeMapMapOpacity,
            progress: clampedProgress(progress),
            geometry: RouteGeometryBuilder.geometry(from: context.activity),
            currentPoint: context.activity.routePoint(at: context.elapsedTime),
            statsBarLayout: statsBarLayout
        )
    }

    static func centeredRect(for element: OverlayElement, contentSize: CGSize, textSize: CGSize, context: OverlayRenderContext) -> CGRect {
        let width = textSize.width + contentSize.width
        let height = textSize.height + contentSize.height
        return centeredRect(for: element, size: CGSize(width: width, height: height), canvasSize: context.canvasSize)
    }

    private static func centeredRect(for element: OverlayElement, size: CGSize, canvasSize: CGSize) -> CGRect {
        CGRect(
            x: canvasSize.width * element.position.x - size.width / 2,
            y: canvasSize.height * element.position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private static func elevationSamples(from activity: ActivityTimeline) -> [Double] {
        let records = activity.records.compactMap(\.elevationMeters)
        if !records.isEmpty {
            return records
        }
        return (0..<40).map { index in
            activity.elevation(at: activity.duration * Double(index) / 39) ?? 0
        }
    }

    private static func clampedProgress(_ progress: Double) -> Double {
        min(max(progress, 0), 1)
    }

    private static func projectRoutePoint(_ point: RoutePoint, bounds: RouteBounds, rect: CGRect) -> CGPoint {
        let projectedMinX = mercatorX(bounds.minLongitude)
        let projectedMaxX = mercatorX(bounds.maxLongitude)
        let projectedSouth = mercatorY(bounds.minLatitude)
        let projectedNorth = mercatorY(bounds.maxLatitude)
        let minX = min(projectedMinX, projectedMaxX)
        let maxX = max(projectedMinX, projectedMaxX)
        let minY = min(projectedSouth, projectedNorth)
        let maxY = max(projectedSouth, projectedNorth)
        let xRange = max(maxX - minX, 0.000001)
        let yRange = max(maxY - minY, 0.000001)
        let scale = min(rect.width / xRange, rect.height / yRange)
        let contentWidth = xRange * scale
        let contentHeight = yRange * scale
        let xOffset = (rect.width - contentWidth) * 0.5
        let yOffset = (rect.height - contentHeight) * 0.5
        return CGPoint(
            x: rect.minX + xOffset + (mercatorX(point.longitude) - minX) * scale,
            y: rect.minY + yOffset + (mercatorY(point.latitude) - minY) * scale
        )
    }

    private static func mercatorX(_ longitude: Double) -> Double {
        (longitude + 180) / 360
    }

    private static func mercatorY(_ latitude: Double) -> Double {
        let clampedLatitude = min(max(latitude, -85.05112878), 85.05112878)
        let radians = clampedLatitude * .pi / 180
        return (1 - log(tan(radians) + 1 / cos(radians)) / .pi) / 2
    }

    private static func textMetrics(
        for preset: OverlayTextPreset,
        fontSize: Double,
        scale: Double,
        context: OverlayRenderContext,
        element: OverlayElement
    ) -> (labelFontSize: Double, unitFontSize: Double, horizontalPadding: Double, verticalPadding: Double, cornerRadius: Double) {
        switch preset {
        case .minimal:
            // Minimal preset adopts model-backed padding/radius from the numeric overlay style.
            return (
                fontSize * 0.72,
                fontSize * 0.58,
                context.scaled(element.style.backgroundPaddingX),
                context.scaled(element.style.backgroundPaddingY),
                context.scaled(element.style.backgroundRadius)
            )
        case .pillBadge:
            return (fontSize * 0.42, fontSize * 0.58, context.scaled(18 * scale), context.scaled(10 * scale), context.scaled(28 * scale))
        case .metricCard:
            return (fontSize * 0.58, fontSize * 0.58, context.scaled(18 * scale), context.scaled(14 * scale), context.scaled(10 * scale))
        case .bigNumber:
            return (fontSize * 0.56, fontSize * 0.42, context.scaled(6), context.scaled(4), context.scaled(0))
        case .sportWatch:
            return (fontSize * 0.46, fontSize * 0.46, context.scaled(18 * scale), context.scaled(14 * scale), context.scaled(18 * scale))
        case .splitLabel:
            return (fontSize * 0.34, fontSize * 0.50, context.scaled(0), context.scaled(0), context.scaled(0))
        case .minimalLabel:
            return (fontSize * 0.34, fontSize * 0.55, context.scaled(0), context.scaled(0), context.scaled(0))
        case .neonGlow:
            return (fontSize * 0.34, fontSize * 0.55, context.scaled(0), context.scaled(0), context.scaled(0))
        case .racingStripe:
            return (
                fontSize * 0.34,
                fontSize * 0.50,
                context.scaled(element.style.backgroundPaddingX > 0 ? element.style.backgroundPaddingX : 18),
                context.scaled(element.style.backgroundPaddingY > 0 ? element.style.backgroundPaddingY : 12),
                context.scaled(element.style.backgroundRadius)
            )
        case .editorial:
            return (fontSize * 0.34, fontSize * 0.42, context.scaled(0), context.scaled(0), context.scaled(0))
        case .digitalWatch:
            return (
                fontSize * 0.32,
                fontSize * 0.48,
                context.scaled(element.style.backgroundPaddingX > 0 ? element.style.backgroundPaddingX : 18),
                context.scaled(element.style.backgroundPaddingY > 0 ? element.style.backgroundPaddingY : 12),
                context.scaled(element.style.backgroundRadius)
            )
        case .inlineGhost:
            return (fontSize * 0.44, fontSize * 0.44, context.scaled(0), context.scaled(0), context.scaled(0))
        case .accentBar:
            return (fontSize * 0.27, fontSize * 0.33, context.scaled(0), context.scaled(0), context.scaled(0))
        case .sportNeon:
            return (fontSize * 0.22, fontSize * 0.25, context.scaled(0), context.scaled(0), context.scaled(0))
        case .serifEditorial:
            return (fontSize * 0.22, fontSize * 0.25, context.scaled(0), context.scaled(0), context.scaled(0))
        }
    }

    /// Resolve final pixel dimensions for a Decor Solid Color element.
    /// Width and height come from `DecorStyle`; `element.scale` plus the
    /// canvas DPR (`context.scaled`) bring design units into pixel space.
    /// Circle collapses both edges to the shorter side so a non-square
    /// bounding box still renders as a circle until the user resizes.
    static func decorSolidColorLayout(
        for element: OverlayElement,
        in context: OverlayRenderContext
    ) -> DecorSolidColorRenderLayout {
        let s = element.style.decor
        let w = context.scaled(s.width * element.scale)
        let h = context.scaled(s.height * element.scale)
        let size: CGSize
        switch s.shape {
        case .circle:
            let side = min(w, h)
            size = CGSize(width: side, height: side)
        default:
            size = CGSize(width: w, height: h)
        }
        return DecorSolidColorRenderLayout(
            shape: s.shape,
            size: size,
            fillColor: s.fillColor,
            cornerRadius: context.scaled(s.cornerRadius * element.scale)
        )
    }

    static func decorIconLayout(
        for element: OverlayElement,
        in context: OverlayRenderContext
    ) -> DecorIconRenderLayout {
        let s = element.style.decor
        let r = DecorIconResolved(from: s)
        let w = context.scaled(s.width * element.scale)
        let h = context.scaled(s.height * element.scale)
        return DecorIconRenderLayout(
            size: CGSize(width: w, height: h),
            iconAsset: r.asset,
            iconTint: r.tint,
            iconPreserveSVGColors: r.preserveSVGColors,
            iconContentMode: r.contentMode
        )
    }

    static func decorTextLayout(
        for element: OverlayElement,
        in context: OverlayRenderContext
    ) -> DecorTextRenderLayout {
        let s = element.style.decor
        let r = DecorTextResolved(from: s)
        let w = context.scaled(s.width * element.scale)
        let h = context.scaled(s.height * element.scale)
        let fs = context.scaled(r.size * element.scale)
        return DecorTextRenderLayout(
            size: CGSize(width: w, height: h),
            content: r.content,
            font: r.font,
            fontSize: fs,
            alignment: r.alignment,
            lineHeight: r.lineHeight,
            letterSpacing: context.scaled(r.letterSpacing * element.scale),
            fillMode: r.fillMode,
            strokeWidth: context.scaled(r.strokeWidth * element.scale),
            strokeColor: r.strokeColor,
            autoFit: r.autoFit
        )
    }
}

/// Pixel-space layout for a Decor Solid Color element. Returned by
/// `OverlayRenderModel.decorSolidColorLayout(for:in:)` and consumed by both
/// the live preview view and the SwiftUI export pipeline.
struct DecorSolidColorRenderLayout {
    var shape: DecorShape
    var size: CGSize
    var fillColor: OverlayColor
    var cornerRadius: Double
}

/// Pixel-space layout for a Decor Icon element.
struct DecorIconRenderLayout {
    var size: CGSize
    var iconAsset: IconAsset
    var iconTint: OverlayColor
    var iconPreserveSVGColors: Bool
    var iconContentMode: IconContentMode
}

/// Pixel-space layout for a Decor Text element.
struct DecorTextRenderLayout {
    var size: CGSize
    var content: String
    var font: DecorFontRef
    var fontSize: Double
    var alignment: DecorTextAlignment
    var lineHeight: Double
    var letterSpacing: Double
    var fillMode: DecorTextFill
    var strokeWidth: Double
    var strokeColor: OverlayColor
    var autoFit: Bool
}

struct OverlayTextRenderLayout {
    var value: String
    var components: OverlayValueComponents
    var preset: OverlayTextPreset
    var fontSize: Double
    var labelFontSize: Double
    var unitFontSize: Double
    var labelFontName: String
    var unitFontName: String
    var labelFontWeight: OverlayFontWeight
    var unitFontWeight: OverlayFontWeight
    var labelPosition: OverlayTextAttachmentPosition
    var unitPosition: OverlayTextAttachmentPosition
    var labelSpacing: Double
    var unitSpacing: Double
    var horizontalPadding: Double
    var verticalPadding: Double
    var cornerRadius: Double
    var backgroundFadeOutEnabled: Bool
    var backgroundFadeOutAmount: Double
    var backgroundBlurRadius: Double
    var shadowRadius: Double
    var shadowOffsetY: Double
    var labelTextAlignment: OverlayTextAlignment
    var valueTextAlignment: OverlayTextAlignment
    var unitTextAlignment: OverlayTextAlignment
    var dividerEnabled: Bool
    var dividerColor: OverlayColor
    var dividerThickness: Double
    var dividerOpacity: Double
    /// When non-nil, numeric preset views and export use this RGB for text
    /// (per-role opacity still applies) instead of `valueColor` / `labelColor` /
    /// `unitColor`. Set for `.heartRateZone` when zone-colored text is enabled
    /// and a zone resolves for the current HR.
    var unifiedTextBaseColor: OverlayColor?
}

struct OverlayDistanceTimelineRenderLayout {
    var style: DistanceTimelineStyle
    var valueText: String
    var label: String
    var percentText: String
    var customValues: [DistanceTimelineCustomValue]
    var startText: String
    var finishText: String
    var distancePointLabels: [String]
    var markerDistanceText: String
    var statsBarItems: [OverlayDistanceTimelineStatsBarItemLayout]
    var rect: CGRect
    var contentRect: CGRect
    var trackRect: CGRect
    var mediaSlotRect: CGRect?
    var elapsedTime: TimeInterval
    var valueFontSize: Double
    var labelFontSize: Double
    var percentFontSize: Double
    var unitFontSize: Double
    var cornerRadius: Double
    var borderWidth: Double
    var progress: Double
    var elevationSamples: [Double]
    var routePoints: [CGPoint]
    var routeCurrentPoint: CGPoint?
}

struct OverlayDistanceTimelineStatsBarItemLayout {
    var label: String
    var value: String
    var unit: String
}

struct OverlayElevationChartRenderLayout {
    var style: ElevationChartStyle
    var bigNumberText: OverlayValueComponents
    var label: String
    var statsBarItems: [OverlayDistanceTimelineStatsBarItemLayout]
    var rect: CGRect
    var labelFontSize: Double
    var valueFontSize: Double
    var unitFontSize: Double
    var horizontalPadding: Double
    var verticalPadding: Double
    var cornerRadius: Double
    var chartHeight: Double
    var lineWidth: Double
    var progress: Double
    var samples: [Double]
}

struct OverlayRunningGaugeRegionLayout {
    var config: RunningGaugeRegionConfig
    /// Region bounding rect in canvas (export) coordinates.
    var rect: CGRect
    var components: OverlayValueComponents
    var valueFontSize: Double
    var labelFontSize: Double
    var unitFontSize: Double
}

struct OverlayRunningGaugeRenderLayout {
    var style: RunningGaugeStyle
    /// Bounding square of the gauge in canvas coordinates.
    var rect: CGRect
    var diameter: Double
    /// Normalised 0...1 progress used by the progress ring (regardless of
    /// whether `style.progressRingEnabled` is true; the renderer guards on
    /// the flag separately).
    var progress: Double
    var regions: [OverlayRunningGaugeRegionLayout]
    var outerRingWidth: Double
    var progressRingWidth: Double
    var tickLength: Double
    var majorTickLength: Double
    var safeRadius: Double

    /// Convenience accessor for the legacy `preset` API still consumed by
    /// some helpers. Resolves to `style.stylePreset`.
    var preset: OverlayGaugePreset { style.stylePreset }
}

// MARK: - Weather Widget

struct WeatherWidgetRenderLayout {
    var style: WeatherWidgetStyle
    var rect: CGRect
    var condition: WeatherCondition
    var temperatureFormatted: String
    var highFormatted: String
    var lowFormatted: String
    var humidityFormatted: String
    var windFormatted: String
    var feelsLikeFormatted: String
    var locationText: String
    var weekdayText: String
    var conditionLabel: String
    var sfSymbolName: String
    var iconTint: OverlayColor
    var iconSize: Double
    var fontSize: Double
    var metricSlots: [WeatherMetricSlotRender]
}

struct WeatherMetricSlotRender: Equatable {
    var kind: WeatherMetricSlotValue
    var label: String
    var value: String
}

extension OverlayRenderModel {
    static func weatherWidgetLayout(for element: OverlayElement, in context: OverlayRenderContext) -> WeatherWidgetRenderLayout {
        let style = element.style.weatherWidget
        let w = context.scaled(style.width * element.scale)
        let h = context.scaled(style.height * element.scale)
        let rect = centeredRect(for: element, size: CGSize(width: w, height: h), canvasSize: context.canvasSize)

        let condition: WeatherCondition
        let temperatureCelsius: Double
        let humidity: Double?
        let highCelsius: Double?
        let lowCelsius: Double?
        let windKph: Double?
        let feelsLikeCelsius: Double?
        let resolvedLocation: String?

        if style.dataSource == .openMeteo, let cached = style.cachedWeather {
            condition = cached.condition
            temperatureCelsius = cached.temperatureCelsius
            humidity = cached.humidity
            highCelsius = cached.highTemperatureCelsius
            lowCelsius = cached.lowTemperatureCelsius
            windKph = cached.windKph
            feelsLikeCelsius = cached.feelsLikeCelsius
            resolvedLocation = cached.resolvedLocation
        } else {
            condition = style.manualCondition
            switch style.dataSource {
            case .fitTemperature:
                temperatureCelsius = context.activity.temperature(at: context.elapsedTime) ?? style.manualTemperatureCelsius
            case .manual, .openMeteo:
                temperatureCelsius = style.manualTemperatureCelsius
            }
            humidity = style.manualHumidity
            highCelsius = style.manualHigh
            lowCelsius = style.manualLow
            windKph = style.manualWind
            feelsLikeCelsius = style.manualFeelsLike
            resolvedLocation = style.showLocation && !style.locationText.isEmpty ? style.locationText : nil
        }

        let unit = style.temperatureUnit
        let tempStr = unit.formatted(temperatureCelsius)
        let highStr = highCelsius.map { unit.formatted($0) } ?? ""
        let lowStr = lowCelsius.map { unit.formatted($0) } ?? ""
        let humidityStr = humidity.map { "\(Int($0.rounded()))%" } ?? ""
        let windStr = windKph.map { "\(String(format: "%.0f", $0)) km/h" } ?? ""
        let feelsLikeStr = feelsLikeCelsius.map { unit.formatted($0) } ?? ""
        let metricSlots = resolvedMetricSlots(
            style: style,
            highFormatted: highStr,
            lowFormatted: lowStr,
            humidityFormatted: humidityStr,
            windFormatted: windStr,
            feelsLikeFormatted: feelsLikeStr
        )

        let location: String
        if !style.locationText.isEmpty {
            location = style.locationText
        } else if let resolved = resolvedLocation {
            location = resolved
        } else {
            location = ""
        }

        var weekday = ""
        if style.showWeekday {
            let df = DateFormatter()
            df.locale = Locale(identifier: localeIdentifier(for: location))
            df.dateFormat = "EEEE"
            weekday = df.string(from: context.activity.startDate)
        }

        let fontSize = context.scaled(max(10, style.width * 0.04 * element.scale))

        return WeatherWidgetRenderLayout(
            style: style,
            rect: rect,
            condition: condition,
            temperatureFormatted: tempStr,
            highFormatted: highStr,
            lowFormatted: lowStr,
            humidityFormatted: humidityStr,
            windFormatted: windStr,
            feelsLikeFormatted: feelsLikeStr,
            locationText: location,
            weekdayText: weekday,
            conditionLabel: resolvedConditionLabel(style: style, condition: condition, location: location),
            sfSymbolName: condition.sfSymbolName,
            iconTint: condition.iconTint,
            iconSize: context.scaled(style.iconSize * element.scale),
            fontSize: fontSize,
            metricSlots: metricSlots
        )
    }

    private static func resolvedMetricSlots(
        style: WeatherWidgetStyle,
        highFormatted: String,
        lowFormatted: String,
        humidityFormatted: String,
        windFormatted: String,
        feelsLikeFormatted: String
    ) -> [WeatherMetricSlotRender] {
        style.normalizedMetricSlots().compactMap { slot in
            let value: String
            switch slot {
            case .none:
                value = ""
            case .humidity:
                value = metricValue(humidityFormatted, suffix: style.humiditySuffix)
            case .highLow:
                value = highFormatted.isEmpty || lowFormatted.isEmpty ? "" : "H \(highFormatted) / L \(lowFormatted)"
            case .wind:
                value = windFormatted
            case .feelsLike:
                value = feelsLikeFormatted
            }
            guard !value.isEmpty else { return nil }
            return WeatherMetricSlotRender(kind: slot, label: metricLabel(for: slot, style: style), value: value)
        }
    }

    private static func metricLabel(for slot: WeatherMetricSlotValue, style: WeatherWidgetStyle) -> String {
        switch slot {
        case .none:
            return slot.compactLabel
        case .humidity:
            return style.humidityMetricLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? slot.compactLabel : style.humidityMetricLabel
        case .wind:
            return style.windMetricLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? slot.compactLabel : style.windMetricLabel
        case .feelsLike:
            return style.feelsLikeMetricLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? slot.compactLabel : style.feelsLikeMetricLabel
        case .highLow:
            return slot.compactLabel
        }
    }

    private static func metricValue(_ value: String, suffix: String) -> String {
        let suffix = suffix.trimmingCharacters(in: .whitespacesAndNewlines)
        return suffix.isEmpty ? value : "\(value) \(suffix)"
    }

    private static func localeIdentifier(for location: String) -> String {
        let lowercased = location.lowercased()
        if location.contains("日本") || lowercased.contains("japan") {
            return "ja_JP"
        }
        if location.contains("中国") || lowercased.contains("china") {
            return "zh_CN"
        }
        if location.contains("台灣") || location.contains("台湾") || lowercased.contains("taiwan") {
            return "zh_Hant_TW"
        }
        return Locale.current.identifier
    }

    private static func localizedConditionLabel(_ condition: WeatherCondition, location: String) -> String {
        let lowercased = location.lowercased()
        if location.contains("日本") || lowercased.contains("japan") {
            switch condition {
            case .sunny: return "晴"
            case .clearNight: return "晴夜"
            case .partlyCloudy: return "晴曇"
            case .cloudy: return "曇"
            case .rain: return "雨"
            case .heavyRain: return "大雨"
            case .thunder: return "雷雨"
            case .snow: return "雪"
            case .fog: return "霧"
            case .wind: return "風"
            }
        }
        return condition.label
    }

    private static func resolvedConditionLabel(style: WeatherWidgetStyle, condition: WeatherCondition, location: String) -> String {
        let override = style.conditionLabelOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        if !override.isEmpty {
            return override
        }
        return localizedConditionLabel(condition, location: location)
    }
}
