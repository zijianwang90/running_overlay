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
