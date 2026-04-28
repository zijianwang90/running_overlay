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
            labelFontSize: metrics.labelFontSize,
            unitFontSize: metrics.unitFontSize,
            horizontalPadding: metrics.horizontalPadding,
            verticalPadding: metrics.verticalPadding,
            cornerRadius: metrics.cornerRadius,
            shadowRadius: context.scaled(element.style.shadowRadius),
            shadowOffsetY: context.scaled(2)
        )
    }

    static func distanceTimelineLayout(for element: OverlayElement, in context: OverlayRenderContext) -> OverlayDistanceTimelineRenderLayout {
        let width = context.scaled(220 * element.scale)
        let height = context.scaled(58 * element.scale)
        let rect = centeredRect(for: element, size: CGSize(width: width, height: height), canvasSize: context.canvasSize)
        let progress = context.activity.distanceMeters > 0
            ? context.activity.distance(at: context.elapsedTime) / context.activity.distanceMeters
            : context.elapsedTime / max(context.activity.duration, 1)

        return OverlayDistanceTimelineRenderLayout(
            label: OverlayValueFormatter.value(for: element.type, activity: context.activity, elapsedTime: context.elapsedTime),
            rect: rect,
            labelFontSize: context.scaled(max(12, element.style.fontSize * 0.58 * element.scale)),
            horizontalPadding: context.scaled(10),
            verticalPadding: context.scaled(8),
            cornerRadius: context.scaled(6),
            trackHeight: max(context.scaled(6), context.scaled(8 * element.scale)),
            progress: clampedProgress(progress)
        )
    }

    static func elevationChartLayout(for element: OverlayElement, in context: OverlayRenderContext) -> OverlayElevationChartRenderLayout {
        let width = context.scaled(220 * element.scale)
        let height = context.scaled(90 * element.scale)
        let rect = centeredRect(for: element, size: CGSize(width: width, height: height), canvasSize: context.canvasSize)
        return OverlayElevationChartRenderLayout(
            label: OverlayValueFormatter.value(for: element.type, activity: context.activity, elapsedTime: context.elapsedTime),
            rect: rect,
            labelFontSize: context.scaled(max(12, element.style.fontSize * 0.52 * element.scale)),
            horizontalPadding: context.scaled(10),
            verticalPadding: context.scaled(8),
            cornerRadius: context.scaled(6),
            chartHeight: context.scaled(60 * element.scale),
            lineWidth: max(context.scaled(1.5), context.scaled(2 * element.scale)),
            progress: clampedProgress(context.elapsedTime / max(context.activity.duration, 1)),
            samples: elevationSamples(from: context.activity)
        )
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

        // Stats bar: attaches below the map container.
        let statsBarConfig = element.style.routeMapStatsBar
        let statsBarVisible = statsBarConfig.visible && statsBarConfig.slots.contains { $0.visible }
        let barDesignHeight: Double = 64
        let barHeight = statsBarVisible ? context.scaled(barDesignHeight * element.scale) : 0

        // Total rect (map + bar) centered at element.position; map stays on top.
        let totalSize = CGSize(width: mapSize.width, height: mapSize.height + barHeight)
        let totalRect = centeredRect(for: element, size: totalSize, canvasSize: context.canvasSize)
        let mapRect = CGRect(origin: totalRect.origin, size: mapSize)

        let statsBarLayout: OverlayRouteMapStatsBarLayout? = statsBarVisible ? {
            let barRect = CGRect(x: totalRect.minX, y: mapRect.maxY, width: totalRect.width, height: barHeight)
            let visibleSlots = statsBarConfig.slots.filter { $0.visible }
            let items = visibleSlots.map { slot -> OverlayRouteMapStatsBarItemLayout in
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
                backgroundOpacity: statsBarConfig.backgroundOpacity,
                items: items,
                fontName: element.style.fontName
            )
        }() : nil

        return OverlayRouteMapRenderLayout(
            preset: element.style.routeMapPreset,
            provider: provider,
            rect: mapRect,
            contentRect: mapRect.insetBy(dx: padding, dy: padding),
            cornerRadius: mapShape == .circle ? 0 : context.scaled(12 * element.scale),
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
    var horizontalPadding: Double
    var verticalPadding: Double
    var cornerRadius: Double
    var shadowRadius: Double
    var shadowOffsetY: Double
}

struct OverlayDistanceTimelineRenderLayout {
    var label: String
    var rect: CGRect
    var labelFontSize: Double
    var horizontalPadding: Double
    var verticalPadding: Double
    var cornerRadius: Double
    var trackHeight: Double
    var progress: Double
}

struct OverlayElevationChartRenderLayout {
    var label: String
    var rect: CGRect
    var labelFontSize: Double
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
