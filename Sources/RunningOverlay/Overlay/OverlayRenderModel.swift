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
            shadowOffsetY: context.scaled(element.style.shadowOffsetY)
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
        let distancePointLabels = distancePointLabels(
            totalDistance: totalDistance,
            unit: unit,
            count: style.distancePointCount
        )
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
            startText: style.axisLabelMode == .startFinish ? "START" : "0",
            finishText: style.axisLabelMode == .startFinish ? "FINISH" : "\(totalComponents.value) \(unit)",
            distancePointLabels: distancePointLabels,
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

    static func lapListLayout(for element: OverlayElement, in context: OverlayRenderContext) -> LapListRenderLayout {
        let s = element.style.lapList
        let laps = context.activity.laps
        let currentLap = context.activity.currentLap(at: context.elapsedTime)
        let currentIndex = currentLap.flatMap { lap in laps.firstIndex(where: { $0.id == lap.id }) } ?? 0

        let rowH = context.scaled(s.rowHeight * element.scale)
        let spacing = context.scaled(s.rowSpacing * element.scale)
        let visibleCount = s.visibleRowCount
        let totalH = rowH * Double(visibleCount) + spacing * Double(max(visibleCount - 1, 0))
        let width = context.scaled(280 * element.scale)
        let rect = centeredRect(for: element, size: CGSize(width: width, height: totalH), canvasSize: context.canvasSize)

        // Determine which lap indices are visible.
        // The current lap sits at the anchor row (top=0, center=mid, bottom=last).
        let anchorRow: Int
        switch s.currentRowAnchor {
        case .top: anchorRow = 0
        case .center: anchorRow = visibleCount / 2
        case .bottom: anchorRow = visibleCount - 1
        }
        let firstVisibleIndex = currentIndex - anchorRow

        var rows: [LapListRowRenderLayout] = []
        for slot in 0..<visibleCount {
            let lapIndex = firstVisibleIndex + slot
            guard lapIndex >= 0, lapIndex < laps.count else { continue }
            let lap = laps[lapIndex]
            let isCurrent = lapIndex == currentIndex
            let rowY = rect.minY + Double(slot) * (rowH + spacing)
            let rowRect = CGRect(x: rect.minX, y: rowY, width: width, height: rowH)

            let distanceFromCurrent = abs(slot - anchorRow)
            let opacity: Double
            if s.fadeEnabled && distanceFromCurrent > 0 {
                let fraction = Double(distanceFromCurrent) / Double(max(anchorRow, visibleCount - 1 - anchorRow, 1))
                opacity = max(1.0 - (1.0 - s.fadeMinOpacity) * fraction, s.fadeMinOpacity)
            } else {
                opacity = 1.0
            }

            let progress: Double
            if isCurrent {
                progress = context.activity.lapProgress(at: context.elapsedTime, byDistance: s.progressMode == .distance)
            } else if lapIndex < currentIndex {
                progress = 1.0
            } else {
                progress = 0.0
            }

            let texts = s.columns.filter(\.visible).map { col -> String in
                lapColumnText(col.metric, lap: lap, activity: context.activity,
                              elapsedTime: context.elapsedTime, isCurrent: isCurrent)
            }

            rows.append(LapListRowRenderLayout(
                lapRecord: lap,
                rowRect: rowRect,
                progressFraction: progress,
                isCurrent: isCurrent,
                rowOpacity: opacity,
                columnTexts: texts
            ))
        }

        let fontSize = context.scaled(max(10, (s.rowHeight * 0.38) * element.scale))
        return LapListRenderLayout(
            rect: rect,
            rows: rows,
            rowHeight: rowH,
            rowCornerRadius: context.scaled(s.rowCornerRadius * element.scale),
            rowSpacing: spacing,
            backgroundOpacity: s.backgroundOpacity,
            progressColor: s.progressColor,
            progressOpacity: s.progressOpacity,
            progressBarEnabled: s.progressBarEnabled,
            fontSize: fontSize,
            columns: s.columns.filter(\.visible)
        )
    }

    private static func lapColumnText(
        _ metric: LapColumnMetric,
        lap: LapRecord,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        isCurrent: Bool
    ) -> String {
        switch metric {
        case .lapNumber:
            return "#\(lap.lapIndex + 1)"
        case .lapKind:
            switch lap.kind {
            case .warmup: return "WU"
            case .active: return "RUN"
            case .rest: return "REST"
            case .cooldown: return "CD"
            case .unknown: return "LAP"
            }
        case .distance:
            let meters = lap.totalDistanceMeters
            return meters >= 1000
                ? String(format: "%.2f km", meters / 1000)
                : String(format: "%.0f m", meters)
        case .elapsedTime:
            let t = isCurrent ? activity.lapElapsedTime(at: elapsedTime) : lap.totalElapsedTime
            let secs = Int(t.rounded())
            return String(format: "%d:%02d", secs / 60, secs % 60)
        case .pace:
            guard let p = lap.avgPaceSecondsPerKm else { return "--" }
            let secs = Int(p.rounded())
            return String(format: "%d'%02d\"", secs / 60, secs % 60)
        case .heartRate:
            return lap.avgHeartRate.map { "\($0) bpm" } ?? "--"
        case .cadence:
            return lap.avgCadenceSPM.map { "\($0) spm" } ?? "--"
        case .power:
            return lap.avgPowerWatts.map { "\($0) W" } ?? "--"
        case .ascent:
            return lap.totalAscent.map { "\($0) m" } ?? "--"
        }
    }

    static func lapCardLayout(for element: OverlayElement, in context: OverlayRenderContext) -> LapCardRenderLayout {
        let s = element.style.lapCard
        let lastActive = context.activity.lastActiveLap(at: context.elapsedTime)
        let currentLap = context.activity.currentLap(at: context.elapsedTime)
        let isRestLap = currentLap?.kind == .rest

        let rowH = context.scaled(26 * element.scale)
        let hPad = context.scaled(12 * element.scale)
        let vPad = context.scaled(10 * element.scale)
        let fontSize = context.scaled(13 * element.scale)
        let width = context.scaled(s.cardWidth * element.scale)

        var columnRows: [(label: String, value: String)] = []
        if let lap = lastActive {
            columnRows = s.columns.filter(\.visible).map { cfg in
                (cfg.column.label, lapCardColumnText(cfg.column, lap: lap))
            }
        }

        var recoveryRows: [(label: String, value: String)] = []
        var recoveryProgress: Double? = nil
        if isRestLap && s.showRecoverySection {
            recoveryRows = s.recoveryMetrics.map { metric in
                recoveryMetricRow(metric, activity: context.activity,
                                  elapsedTime: context.elapsedTime, targetHR: s.recoveryTargetHR)
            }
            if s.recoveryProgressEnabled && s.recoveryTargetHR > 0 {
                if let peak = context.activity.recoveryPeakHR(at: context.elapsedTime),
                   let current = context.activity.heartRate(at: context.elapsedTime),
                   peak > s.recoveryTargetHR {
                    let drop = Double(peak - current)
                    let needed = Double(peak - s.recoveryTargetHR)
                    recoveryProgress = min(max(drop / needed, 0), 1)
                }
            }
        }

        let headerH = context.scaled(22 * element.scale)
        let statRows = columnRows.count
        let recRows = recoveryRows.count
        let dividerH = (recRows > 0) ? context.scaled(6 * element.scale) : 0
        let recHeaderH = (recRows > 0) ? context.scaled(16 * element.scale) : 0
        let totalH = vPad + headerH + Double(statRows) * rowH + dividerH + recHeaderH + Double(recRows) * rowH + vPad

        let rect = centeredRect(for: element, size: CGSize(width: width, height: totalH), canvasSize: context.canvasSize)
        return LapCardRenderLayout(
            rect: rect,
            headerText: lastActive.map { "#\($0.lapIndex + 1) \(lapKindShort($0.kind))" } ?? "No Lap",
            columnRows: columnRows,
            showRecoverySection: isRestLap && s.showRecoverySection && !recoveryRows.isEmpty,
            recoveryRows: recoveryRows,
            recoveryProgress: recoveryProgress,
            backgroundOpacity: s.backgroundOpacity,
            cornerRadius: context.scaled(s.cornerRadius * element.scale),
            fontSize: fontSize,
            rowHeight: rowH,
            horizontalPadding: hPad,
            verticalPadding: vPad,
            progressColor: s.progressColor,
            headerHeight: headerH,
            dividerHeight: dividerH,
            recoveryHeaderHeight: recHeaderH
        )
    }

    static func lapLiveLayout(for element: OverlayElement, in context: OverlayRenderContext) -> LapLiveRenderLayout {
        let s = element.style.lapLive
        let currentLap = context.activity.currentLap(at: context.elapsedTime)
        let lapKind = currentLap?.kind ?? .unknown
        let isRest = lapKind == .rest

        let hPad = context.scaled(12 * element.scale)
        let vPad = context.scaled(10 * element.scale)
        let rowH = context.scaled(28 * element.scale)
        let headerH = context.scaled(20 * element.scale)
        let progressH = (s.showProgressBar && !isRest) ? context.scaled(6 * element.scale) : 0
        let fontSize = context.scaled(13 * element.scale)
        let width = context.scaled(s.cardWidth * element.scale)

        var metricRows: [(label: String, value: String)] = []
        var recoveryRows: [(label: String, value: String)] = []
        var recoveryProgress: Double? = nil
        let isHidden = isRest && s.restMode == .hidden

        if !isRest {
            metricRows = s.activeMetrics.filter(\.visible).map { cfg in
                lapLiveMetricRow(cfg.metric, activity: context.activity, elapsedTime: context.elapsedTime)
            }
        } else if s.restMode == .recovery {
            recoveryRows = s.recoveryMetrics.map { metric in
                recoveryMetricRow(metric, activity: context.activity,
                                  elapsedTime: context.elapsedTime, targetHR: s.recoveryTargetHR)
            }
            if s.recoveryProgressEnabled && s.recoveryTargetHR > 0 {
                if let peak = context.activity.recoveryPeakHR(at: context.elapsedTime),
                   let current = context.activity.heartRate(at: context.elapsedTime),
                   peak > s.recoveryTargetHR {
                    let drop = Double(peak - current)
                    let needed = Double(peak - s.recoveryTargetHR)
                    recoveryProgress = min(max(drop / needed, 0), 1)
                }
            }
        }

        let activeCount = isRest ? 0 : metricRows.count
        let recCount = isRest ? recoveryRows.count : 0
        let recHeaderH = recCount > 0 ? context.scaled(14 * element.scale) : 0
        let totalH = isHidden ? 0
            : vPad + headerH + progressH + Double(activeCount) * rowH + recHeaderH + Double(recCount) * rowH + vPad

        let lapProgress = context.activity.lapProgress(at: context.elapsedTime,
                                                       byDistance: s.progressMode == .distance)
        let lapHeader: String
        if let lap = currentLap {
            lapHeader = "#\(lap.lapIndex + 1) \(lapKindShort(lap.kind))"
        } else {
            lapHeader = "--"
        }

        let rect = centeredRect(for: element, size: CGSize(width: width, height: totalH), canvasSize: context.canvasSize)
        return LapLiveRenderLayout(
            rect: rect,
            headerText: lapHeader,
            lapKind: lapKind,
            isHidden: isHidden,
            isRestMode: isRest,
            metricRows: metricRows,
            progressFraction: lapProgress,
            showProgressBar: s.showProgressBar && !isRest,
            progressBarHeight: progressH,
            recoveryRows: recoveryRows,
            recoveryHeaderHeight: recHeaderH,
            recoveryProgress: recoveryProgress,
            backgroundOpacity: s.backgroundOpacity,
            cornerRadius: context.scaled(s.cornerRadius * element.scale),
            fontSize: fontSize,
            rowHeight: rowH,
            horizontalPadding: hPad,
            verticalPadding: vPad,
            headerHeight: headerH,
            progressColor: s.progressColor,
            progressOpacity: s.progressOpacity
        )
    }

    private static func lapCardColumnText(_ column: LapCardColumn, lap: LapRecord) -> String {
        switch column {
        case .lapNumber: return "#\(lap.lapIndex + 1)"
        case .lapKind: return lapKindShort(lap.kind)
        case .distance:
            let m = lap.totalDistanceMeters
            return m >= 1000 ? String(format: "%.2f km", m / 1000) : String(format: "%.0f m", m)
        case .elapsedTime:
            let secs = Int(lap.totalElapsedTime.rounded())
            return String(format: "%d:%02d", secs / 60, secs % 60)
        case .pace:
            guard let p = lap.avgPaceSecondsPerKm else { return "--" }
            let secs = Int(p.rounded())
            return String(format: "%d'%02d\"", secs / 60, secs % 60)
        case .avgHR: return lap.avgHeartRate.map { "\($0) bpm" } ?? "--"
        case .maxHR: return lap.maxHeartRate.map { "\($0) bpm" } ?? "--"
        case .cadence: return lap.avgCadenceSPM.map { "\($0) spm" } ?? "--"
        case .power: return lap.avgPowerWatts.map { "\($0) W" } ?? "--"
        case .ascent: return lap.totalAscent.map { "\($0) m" } ?? "--"
        }
    }

    private static func lapKindShort(_ kind: LapKind) -> String {
        switch kind {
        case .warmup: return "WU"
        case .active: return "RUN"
        case .rest: return "REST"
        case .cooldown: return "CD"
        case .unknown: return "LAP"
        }
    }

    private static func recoveryMetricRow(
        _ metric: RecoveryMetric,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        targetHR: Int
    ) -> (label: String, value: String) {
        switch metric {
        case .peakHR:
            return (metric.label, activity.recoveryPeakHR(at: elapsedTime).map { "\($0) bpm" } ?? "--")
        case .currentHR:
            return (metric.label, activity.heartRate(at: elapsedTime).map { "\($0) bpm" } ?? "--")
        case .hrDrop:
            return (metric.label, activity.recoveryDrop(at: elapsedTime).map { "\($0) bpm↓" } ?? "--")
        case .hrDropPercent:
            return (metric.label, activity.recoveryDropPercent(at: elapsedTime).map { String(format: "%.0f%%", $0) } ?? "--")
        case .restElapsedTime:
            let t = activity.lapElapsedTime(at: elapsedTime)
            let secs = Int(t.rounded())
            return (metric.label, String(format: "%d:%02d", secs / 60, secs % 60))
        case .targetHRGap:
            guard targetHR > 0 else { return (metric.label, "--") }
            return (metric.label, activity.recoveryGapToTarget(at: elapsedTime, targetHR: targetHR).map { "\($0) bpm" } ?? "--")
        }
    }

    private static func lapLiveMetricRow(
        _ metric: LapLiveMetric,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval
    ) -> (label: String, value: String) {
        switch metric {
        case .lapElapsedTime:
            let t = activity.lapElapsedTime(at: elapsedTime)
            let secs = Int(t.rounded())
            return (metric.label, String(format: "%d:%02d", secs / 60, secs % 60))
        case .lapDistance:
            guard let cur = activity.currentLap(at: elapsedTime) else { return (metric.label, "--") }
            let d = activity.distance(at: elapsedTime) - cur.startDistanceMeters
            return (metric.label, d >= 1000 ? String(format: "%.2f km", d / 1000) : String(format: "%.0f m", d))
        case .pace:
            let v = activity.pace(at: elapsedTime).map { p -> String in
                let secs = Int(p.rounded()); return String(format: "%d'%02d\"", secs / 60, secs % 60)
            } ?? "--"
            return (metric.label, v)
        case .heartRate:
            return (metric.label, activity.heartRate(at: elapsedTime).map { "\($0) bpm" } ?? "--")
        case .power:
            return (metric.label, activity.power(at: elapsedTime).map { "\($0) W" } ?? "--")
        case .cadence:
            return (metric.label, activity.cadence(at: elapsedTime).map { "\($0) spm" } ?? "--")
        }
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

// MARK: - Lap List

struct LapListRowRenderLayout {
    var lapRecord: LapRecord
    var rowRect: CGRect
    var progressFraction: Double
    var isCurrent: Bool
    var rowOpacity: Double
    var columnTexts: [String]
}

struct LapListRenderLayout {
    var rect: CGRect
    var rows: [LapListRowRenderLayout]
    var rowHeight: Double
    var rowCornerRadius: Double
    var rowSpacing: Double
    var backgroundOpacity: Double
    var progressColor: OverlayColor
    var progressOpacity: Double
    var progressBarEnabled: Bool
    var fontSize: Double
    var columns: [LapListColumn]
}

// MARK: - Lap Card

struct LapCardRenderLayout {
    var rect: CGRect
    var headerText: String
    var columnRows: [(label: String, value: String)]
    var showRecoverySection: Bool
    var recoveryRows: [(label: String, value: String)]
    var recoveryProgress: Double?
    var backgroundOpacity: Double
    var cornerRadius: Double
    var fontSize: Double
    var rowHeight: Double
    var horizontalPadding: Double
    var verticalPadding: Double
    var progressColor: OverlayColor
    var headerHeight: Double
    var dividerHeight: Double
    var recoveryHeaderHeight: Double
}

// MARK: - Lap Live

struct LapLiveRenderLayout {
    var rect: CGRect
    var headerText: String
    var lapKind: LapKind
    var isHidden: Bool
    var isRestMode: Bool
    var metricRows: [(label: String, value: String)]
    var progressFraction: Double
    var showProgressBar: Bool
    var progressBarHeight: Double
    var recoveryRows: [(label: String, value: String)]
    var recoveryHeaderHeight: Double
    var recoveryProgress: Double?
    var backgroundOpacity: Double
    var cornerRadius: Double
    var fontSize: Double
    var rowHeight: Double
    var horizontalPadding: Double
    var verticalPadding: Double
    var headerHeight: Double
    var progressColor: OverlayColor
    var progressOpacity: Double
}
