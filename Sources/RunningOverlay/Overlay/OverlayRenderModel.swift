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
        let diameter = context.scaled(300 * element.scale)
        let rect = centeredRect(for: element, size: CGSize(width: diameter, height: diameter), canvasSize: context.canvasSize)
        let progress = context.activity.distanceMeters > 0
            ? context.activity.distance(at: context.elapsedTime) / context.activity.distanceMeters
            : context.elapsedTime / max(context.activity.duration, 1)

        return OverlayRunningGaugeRenderLayout(
            preset: element.style.gaugePreset,
            rect: rect,
            progress: clampedProgress(progress),
            distance: OverlayValueFormatter.components(for: .distance, activity: context.activity, elapsedTime: context.elapsedTime),
            elapsedTime: OverlayValueFormatter.components(for: .elapsedTime, activity: context.activity, elapsedTime: context.elapsedTime),
            pace: OverlayValueFormatter.components(for: .pace, activity: context.activity, elapsedTime: context.elapsedTime),
            heartRate: OverlayValueFormatter.components(for: .heartRate, activity: context.activity, elapsedTime: context.elapsedTime),
            primaryFontSize: context.scaled(element.style.fontSize * 1.38 * element.scale),
            secondaryFontSize: context.scaled(element.style.fontSize * 0.88 * element.scale),
            labelFontSize: context.scaled(max(9, element.style.fontSize * 0.36 * element.scale)),
            unitFontSize: context.scaled(max(9, element.style.fontSize * 0.34 * element.scale)),
            ringWidth: max(context.scaled(8 * element.scale), context.scaled(3)),
            tickLength: context.scaled(8 * element.scale),
            dividerWidth: max(context.scaled(1), context.scaled(1.2 * element.scale))
        )
    }

    static func routeMapLayout(for element: OverlayElement, in context: OverlayRenderContext) -> OverlayRouteMapRenderLayout {
        let width = context.scaled(280 * element.scale)
        let height = context.scaled(210 * element.scale)
        let mapShape = element.style.routeMapShape
        let side = min(width, height)
        let mapSize = mapShape == .circle ? CGSize(width: side, height: side) : CGSize(width: width, height: height)
        let rect = centeredRect(for: element, size: mapSize, canvasSize: context.canvasSize)
        let padding = context.scaled(18 * element.scale)
        let progress = context.activity.duration > 0 ? context.elapsedTime / context.activity.duration : 0

        return OverlayRouteMapRenderLayout(
            preset: element.style.routeMapPreset,
            provider: element.style.routeMapProvider,
            rect: rect,
            contentRect: rect.insetBy(dx: padding, dy: padding),
            cornerRadius: mapShape == .circle ? 0 : context.scaled(8 * element.scale),
            shape: mapShape,
            edgeFade: element.style.routeMapEdgeFade,
            fadeAmount: element.style.routeMapFadeAmount,
            lineWidth: max(context.scaled(4 * element.scale), 1.5),
            glowRadius: context.scaled(11 * element.scale),
            progress: clampedProgress(progress),
            geometry: RouteGeometryBuilder.geometry(from: context.activity),
            currentPoint: context.activity.routePoint(at: context.elapsedTime)
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
            return (fontSize * 0.46, fontSize * 0.58, context.scaled(6), context.scaled(4), context.scaled(0))
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

struct OverlayRunningGaugeRenderLayout {
    var preset: OverlayGaugePreset
    var rect: CGRect
    var progress: Double
    var distance: OverlayValueComponents
    var elapsedTime: OverlayValueComponents
    var pace: OverlayValueComponents
    var heartRate: OverlayValueComponents
    var primaryFontSize: Double
    var secondaryFontSize: Double
    var labelFontSize: Double
    var unitFontSize: Double
    var ringWidth: Double
    var tickLength: Double
    var dividerWidth: Double
}
