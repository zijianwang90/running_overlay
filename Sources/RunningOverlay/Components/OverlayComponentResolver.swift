import CoreGraphics
import Foundation

struct OverlayComponentResolved: Equatable {
    var size: OverlayComponentSize
    var contentLayout: OverlayComponentResolvedContentLayout?
    var background: OverlayComponentResolvedBackground?
    var nodes: [OverlayComponentResolvedNode]
    var diagnostics: [String]
}

/// Design-unit padding and minimum inner size of a content-sized component.
struct OverlayComponentResolvedContentLayout: Equatable {
    var paddingX: Double
    var paddingY: Double
    var minWidth: Double
    var minHeight: Double
}

struct OverlayComponentResolvedStackChild: Equatable {
    var node: OverlayComponentResolvedNode
    var alignSelf: OverlayComponentCrossAlignment?
}

struct OverlayComponentResolvedBackground: Equatable {
    var color: OverlayColor
    var radius: Double
}

struct OverlayComponentResolvedFont: Equatable {
    var family: String
    var size: Double
    var weight: OverlayComponentFontWeight
}

struct OverlayComponentResolvedDivider: Equatable {
    var width: Double
    var color: OverlayColor
    var opacity: Double
    var height: Double
}

struct OverlayComponentResolvedSegment: Equatable {
    var index: Int
    var color: OverlayColor
}

struct OverlayComponentResolvedSegmentedBarGlow: Equatable {
    var opacity: Double
    var sigma: Double
}

struct OverlayComponentResolvedSegmentedBarBorder: Equatable {
    var color: OverlayColor
    var opacity: Double
    var width: Double
}

struct OverlayComponentResolvedSegmentedBarMarker: Equatable {
    var role: OverlayComponentSegmentedBarMarkerRole
    var layout: OverlayComponentSegmentedBarMarkerLayout
    var index: Int
    var fraction: Double
    var text: String
    var color: OverlayColor
    var side: OverlayComponentSegmentedBarMarkerSide
    var showsValue: Bool
    var scale: Double
    var font: OverlayComponentResolvedFont
}

struct OverlayComponentResolvedTimelineLap: Equatable {
    var index: Int
    var kind: String
    var startElapsed: Double
    var endElapsed: Double
    var elapsed: Double
    var distance: Double
}

struct OverlayComponentResolvedTimelineColors: Equatable {
    var warmup: OverlayColor
    var active: OverlayColor
    var rest: OverlayColor
    var cooldown: OverlayColor
    var unknown: OverlayColor

    func color(for kind: String) -> OverlayColor {
        switch kind {
        case "warmup": warmup
        case "active": active
        case "rest": rest
        case "cooldown": cooldown
        default: unknown
        }
    }
}

struct OverlayComponentResolvedTimelineLabels: Equatable {
    var font: OverlayComponentResolvedFont
    var currentWorkDistance: String
    var currentWorkTime: String
    var currentRestKind: Bool
    var currentRestDistance: String
    var currentRestTime: String
    var neighbor: String
}

struct OverlayComponentResolvedTimelineMarker: Equatable {
    var enabled: Bool
    /// `progress` or `center`.
    var position: String
    var color: OverlayColor
    var label: String
    var showsLabel: Bool
    var font: OverlayComponentResolvedFont
}

struct OverlayComponentResolvedTimelineProgress: Equatable {
    var value: Double
    var color: OverlayColor
    var opacity: Double
}

struct OverlayComponentResolvedTimelineOverflow: Equatable {
    var enabled: Bool
    var text: String
    var color: OverlayColor
    var inset: Double
}

struct OverlayComponentResolvedTimelineStrip: Equatable {
    var laps: [OverlayComponentResolvedTimelineLap]
    var currentIndex: Int?
    var elapsed: Double
    var mode: String
    var emphasisFraction: Double
    /// Neighbor count for `emphasized`; nil shows every lap.
    var window: Int?
    var showsWarmup: Bool
    var showsRest: Bool
    var showsCooldown: Bool
    var segmentAreaHeight: Double
    var segmentHeight: Double
    var currentHeightScale: Double
    var minSegmentWidth: Double
    var gap: Double
    var radius: Double
    var currentBorderWidth: Double
    var completedOpacity: Double
    var futureOpacity: Double
    var colors: OverlayComponentResolvedTimelineColors
    var labels: OverlayComponentResolvedTimelineLabels?
    var progress: OverlayComponentResolvedTimelineProgress?
    var marker: OverlayComponentResolvedTimelineMarker?
    var overflow: OverlayComponentResolvedTimelineOverflow?
    var repText: String
    var distanceProgress: Double
}


struct OverlayComponentResolvedGaugeRegion: Equatable {
    var config: RunningGaugeRegionConfig
    var components: OverlayValueComponents
}

struct OverlayComponentResolvedGauge: Equatable {
    var style: RunningGaugeStyle
    var progress: Double
    var regions: [OverlayComponentResolvedGaugeRegion]
}

struct OverlayComponentResolvedShadow: Equatable {
    var sigma: Double
    var dx: Double
    var dy: Double
    var color: OverlayColor
    var opacity: Double
}

enum OverlayComponentResolvedPathCommand: Equatable {
    case move(Double, Double)
    case line(Double, Double)
    case quad(Double, Double, Double, Double)
    case cubic(Double, Double, Double, Double, Double, Double)
    case arc(Double, Double, Double, Double, Double)
    case close
}

struct OverlayComponentResolvedRichText: Equatable {
    var text: String
    var font: OverlayComponentResolvedFont
    var color: OverlayColor
    var align: OverlayComponentTextAlignment
    var lineHeight: Double
    var tracking: Double
    var stroke: OverlayColor
    var strokeWidth: Double
    var autoFit: Bool
    var gradient: OverlayComponentResolvedTextGradient?
}

struct OverlayComponentResolvedTextRows: Equatable {
    struct Run: Equatable {
        var text: String
        var font: OverlayComponentResolvedFont
        var color: OverlayColor
        var minimumScaleFactor: Double
        var verticalPadding: Double
        var opacity: Double
        var monospacedDigits: Bool
    }

    struct Row: Equatable {
        var runs: [Run]
        var spacing: Double
        var alignment: OverlayComponentTextRowAlignment
    }

    var rows: [Row]
    var spacing: Double
    var maxWidth: Double?
}

struct OverlayComponentResolvedTextGradient: Equatable {
    var stops: [OverlayComponentGradientStop]
    var from: CGPoint
    var to: CGPoint
}

indirect enum OverlayComponentResolvedNode: Equatable {
    case richText(frame: CGRect, text: OverlayComponentResolvedRichText)
    case textRows(frame: CGRect, text: OverlayComponentResolvedTextRows, autoSize: Bool)
    case group(
        frame: CGRect,
        opacity: Double,
        clip: Bool,
        shadows: [OverlayComponentResolvedShadow],
        shadowBounds: CGRect?,
        children: [OverlayComponentResolvedNode]
    )
    case stack(
        frame: CGRect?,
        direction: OverlayComponentStackDirection,
        spacing: Double,
        crossAlign: OverlayComponentCrossAlignment,
        children: [OverlayComponentResolvedStackChild]
    )
    case opacity(Double, OverlayComponentResolvedNode)
    case rect(
        frame: CGRect,
        fill: OverlayColor,
        radius: Double,
        stroke: OverlayColor?,
        strokeWidth: Double
    )
    case circle(
        center: CGPoint,
        radius: Double,
        fill: OverlayColor?,
        stroke: OverlayColor?,
        strokeWidth: Double
    )
    case line(
        from: CGPoint,
        to: CGPoint,
        width: Double,
        color: OverlayColor,
        cap: OverlayComponentLineCap
    )
    case polyline(
        points: [CGPoint],
        width: Double,
        color: OverlayColor,
        cap: OverlayComponentLineCap,
        join: OverlayComponentLineJoin,
        dash: [Double]?
    )
    case path(
        commands: [OverlayComponentResolvedPathCommand],
        fill: OverlayColor?,
        stroke: OverlayColor?,
        strokeWidth: Double,
        cap: OverlayComponentLineCap,
        join: OverlayComponentLineJoin,
        dash: [Double]?
    )
    case text(
        frame: CGRect,
        text: String,
        font: OverlayComponentResolvedFont,
        color: OverlayColor,
        align: OverlayComponentTextAlignment,
        verticalAlign: OverlayComponentVerticalAlignment,
        maxWidth: Double?,
        lineHeight: Double,
        tracking: Double,
        autoSize: Bool
    )
    case image(
        frame: CGRect,
        asset: String,
        fit: OverlayComponentImageFit
    )
    case spacer(length: Double?, minimum: Double)
    case columns(
        width: Double,
        divider: OverlayComponentResolvedDivider?,
        children: [OverlayComponentResolvedNode]
    )
    case symbol(
        frame: CGRect,
        name: String,
        color: OverlayColor,
        weight: OverlayComponentFontWeight,
        scale: OverlayComponentSymbolScale,
        rendering: OverlayComponentSymbolRendering
    )
    case gradientRect(
        frame: CGRect,
        stops: [OverlayComponentGradientStop],
        from: CGPoint,
        to: CGPoint,
        radius: Double
    )
    case sparkline(
        frame: CGRect,
        values: [Double?],
        stroke: OverlayColor,
        lineWidth: Double,
        fill: OverlayColor?,
        smoothing: OverlayComponentSmoothing
    )
    case progressBar(
        frame: CGRect,
        value: Double,
        trackColor: OverlayColor,
        fillColor: OverlayColor,
        radius: Double
    )
    case arc(
        frame: CGRect,
        value: Double,
        startDegrees: Double,
        sweepDegrees: Double,
        radius: Double,
        width: Double,
        trackColor: OverlayColor?,
        fillColor: OverlayColor,
        cap: OverlayComponentLineCap
    )
    case segmentedBar(
        frame: CGRect,
        vertical: Bool,
        segments: [OverlayComponentResolvedSegment],
        activeIndex: Int?,
        activeWidthShare: Double,
        activeThicknessScale: Double,
        gap: Double,
        radius: Double,
        inactiveOpacity: Double,
        glow: OverlayComponentResolvedSegmentedBarGlow?,
        border: OverlayComponentResolvedSegmentedBarBorder?,
        markers: [OverlayComponentResolvedSegmentedBarMarker]
    )
    case timelineStrip(frame: CGRect, strip: OverlayComponentResolvedTimelineStrip)
    case runningGauge(frame: CGRect, gauge: OverlayComponentResolvedGauge)
    case distanceTimeline(frame: CGRect, style: DistanceTimelineStyle, valueFontSize: Double)
    case elevationChart(
        frame: CGRect,
        style: ElevationChartStyle,
        valueFontSize: Double,
        fontName: String,
        foregroundColor: OverlayColor
    )
    case routeMap(frame: CGRect, style: OverlayStyle)
    case weatherWidget(frame: CGRect, style: WeatherWidgetStyle)
}

struct OverlayComponentResolver {
    let definition: OverlayComponentDefinition

    func resolve(
        parameters rawParameters: [String: OverlayComponentValue],
        data: any OverlayComponentDataProviding
    ) -> OverlayComponentResolved {
        var diagnostics: [String] = []
        let parameters = normalizedParameters(rawParameters, diagnostics: &diagnostics)
        var bindings: [String: OverlayComponentValue] = [:]
        var computedBindings: [String: OverlayComponentExpression] = [:]
        for (name, binding) in definition.bindings {
            switch binding {
            case .signal(let path):
                bindings[name] = data.signal(path: path)
            case .series(let path, let window, let samples):
                bindings[name] = data.series(path: path, window: window, samples: samples)
            case .list(let path):
                bindings[name] = data.list(path: path)
            case .value(let expression):
                computedBindings[name] = expression
            }
        }
        var evaluatingBindings: Set<String> = []
        func evaluateComputedBinding(_ name: String) -> OverlayComponentValue {
            if let value = bindings[name] { return value }
            guard let expression = computedBindings[name],
                  evaluatingBindings.insert(name).inserted else {
                return .null
            }
            defer { evaluatingBindings.remove(name) }
            for dependency in expression.referencedIdentifiers
            where computedBindings[dependency] != nil && bindings[dependency] == nil {
                _ = evaluateComputedBinding(dependency)
            }
            let bindingContext = OverlayComponentEvaluationContext(
                parameters: parameters,
                bindings: bindings,
                data: data,
                componentSize: definition.size
            )
            let value = expression.evaluate(in: bindingContext)
            bindings[name] = value
            return value
        }
        for name in computedBindings.keys {
            _ = evaluateComputedBinding(name)
        }

        var context = OverlayComponentEvaluationContext(
            parameters: parameters,
            bindings: bindings,
            data: data,
            componentSize: definition.size
        )

        let contentLayout = definition.contentLayout.map { layout in
            OverlayComponentResolvedContentLayout(
                paddingX: max(layout.paddingX.evaluate(in: context) ?? 0, 0),
                paddingY: max(layout.paddingY.evaluate(in: context) ?? 0, 0),
                minWidth: max(layout.minWidth.evaluate(in: context) ?? 0, 0),
                minHeight: max(layout.minHeight.evaluate(in: context) ?? 0, 0)
            )
        }
        let background = resolveBackground(in: &context, diagnostics: &diagnostics)
        let nodes = resolveNodes(
            definition.nodes,
            path: "$.nodes",
            context: &context,
            diagnostics: &diagnostics
        )
        return OverlayComponentResolved(
            size: definition.size,
            contentLayout: contentLayout,
            background: background,
            nodes: nodes,
            diagnostics: diagnostics
        )
    }

    private func normalizedParameters(
        _ raw: [String: OverlayComponentValue],
        diagnostics: inout [String]
    ) -> [String: OverlayComponentValue] {
        var result = definition.defaultParameters()
        for (id, value) in raw {
            guard let parameter = definition.parameter(named: id) else {
                diagnostics.append("$.params.\(id): unknown parameter ignored")
                continue
            }
            switch parameter.kind {
            case .number(let minimum, let maximum, _, _, _):
                guard let number = value.number else {
                    diagnostics.append("$.params.\(id): expected a number")
                    continue
                }
                result[id] = .number(min(max(number, minimum), maximum))
            case .boolean:
                guard case .boolean = value else {
                    diagnostics.append("$.params.\(id): expected a boolean")
                    continue
                }
                result[id] = value
            case .color:
                guard value.color != nil else {
                    diagnostics.append("$.params.\(id): expected a color")
                    continue
                }
                result[id] = value
            case .enumeration(let options):
                guard let string = value.string,
                      options.contains(where: { $0.value == string }) else {
                    diagnostics.append("$.params.\(id): expected a declared option")
                    continue
                }
                result[id] = value
            case .string(let maxLength):
                guard let string = value.string else {
                    diagnostics.append("$.params.\(id): expected a string")
                    continue
                }
                result[id] = .string(String(string.prefix(maxLength)))
            case .font:
                guard value.string != nil else {
                    diagnostics.append("$.params.\(id): expected a font family")
                    continue
                }
                result[id] = value
            case .metric(let signals, _):
                guard let string = value.string, signals.contains(string) else {
                    diagnostics.append("$.params.\(id): expected a declared metric")
                    continue
                }
                result[id] = value
            }
        }
        return result
    }

    private func resolveBackground(
        in context: inout OverlayComponentEvaluationContext,
        diagnostics: inout [String]
    ) -> OverlayComponentResolvedBackground? {
        guard let background = definition.background,
              let color = background.color.evaluate(in: context) else {
            return nil
        }
        let radius = background.radius?.evaluate(in: context) ?? 0
        return OverlayComponentResolvedBackground(color: color, radius: max(radius, 0))
    }

    private func resolveFont(
        _ font: OverlayComponentFont,
        path: String,
        context: OverlayComponentEvaluationContext,
        diagnostics: inout [String]
    ) -> OverlayComponentResolvedFont? {
        guard let size = font.size.evaluate(in: context), size > 0 else {
            diagnostics.append("\(path): font size did not resolve")
            return nil
        }
        let family = font.family.evaluate(in: context)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let weight = resolveEnum(
            font.weight,
            default: OverlayComponentFontWeight.regular,
            path: "\(path).weight",
            context: context,
            diagnostics: &diagnostics
        )
        return OverlayComponentResolvedFont(
            family: family.isEmpty ? "system" : family,
            size: size,
            weight: weight
        )
    }

    private func resolveNodes(
        _ nodes: [OverlayComponentNode],
        path: String,
        context: inout OverlayComponentEvaluationContext,
        diagnostics: inout [String]
    ) -> [OverlayComponentResolvedNode] {
        var result: [OverlayComponentResolvedNode] = []
        for (index, node) in nodes.enumerated() {
            if let condition = node.condition, !condition.evaluate(in: context).isTruthy {
                continue
            }
            if let resolved = resolveNode(
                node,
                path: "\(path)[\(index)]",
                context: &context,
                diagnostics: &diagnostics
            ) {
                result.append(resolved)
            }
        }
        return result
    }

    /// Like `resolveNodes`, keeping each surviving child's `alignSelf`.
    private func resolveStackChildren(
        _ nodes: [OverlayComponentNode],
        path: String,
        context: inout OverlayComponentEvaluationContext,
        diagnostics: inout [String]
    ) -> [OverlayComponentResolvedStackChild] {
        var result: [OverlayComponentResolvedStackChild] = []
        for (index, node) in nodes.enumerated() {
            if let condition = node.condition, !condition.evaluate(in: context).isTruthy {
                continue
            }
            if let resolved = resolveNode(
                node,
                path: "\(path)[\(index)]",
                context: &context,
                diagnostics: &diagnostics
            ) {
                let alignSelf = node.alignSelf.map {
                    resolveEnum(
                        $0,
                        default: OverlayComponentCrossAlignment.start,
                        path: "\(path)[\(index)].alignSelf",
                        context: context,
                        diagnostics: &diagnostics
                    )
                }
                result.append(OverlayComponentResolvedStackChild(node: resolved, alignSelf: alignSelf))
            }
        }
        return result
    }

    private func resolveEnum<T: RawRepresentable>(
        _ source: OverlayComponentStringSource,
        default fallback: T,
        path: String,
        context: OverlayComponentEvaluationContext,
        diagnostics: inout [String]
    ) -> T where T.RawValue == String {
        let raw = source.evaluate(in: context)
        guard let value = T(rawValue: raw) else {
            diagnostics.append("\(path): '\(raw)' is not a valid value; using '\(fallback.rawValue)'")
            return fallback
        }
        return value
    }

    private func resolveNode(
        _ node: OverlayComponentNode,
        path: String,
        context: inout OverlayComponentEvaluationContext,
        diagnostics: inout [String]
    ) -> OverlayComponentResolvedNode? {
        let opacity = min(max(node.opacity?.evaluate(in: context) ?? 1, 0), 1)

        func frame(required: Bool = true) -> CGRect? {
            guard let frame = node.frame else {
                if required { diagnostics.append("\(path): frame did not resolve") }
                return nil
            }
            guard let rect = frame.evaluate(in: context) else {
                if required { diagnostics.append("\(path): frame did not resolve") }
                return nil
            }
            return rect
        }

        func color(_ source: OverlayComponentColorSource?, default fallback: OverlayColor? = nil) -> OverlayColor? {
            guard let source else { return fallback }
            return source.evaluate(in: context)
        }

        func number(_ source: OverlayComponentNumberSource?, default fallback: Double) -> Double {
            source?.evaluate(in: context) ?? fallback
        }

        func flag(_ source: OverlayComponentNumberSource?, default fallback: Bool) -> Bool {
            guard let source else { return fallback }
            return (source.evaluate(in: context) ?? (fallback ? 1 : 0)) != 0
        }

        func weight(
            _ source: OverlayComponentStringSource?,
            default fallback: OverlayFontWeight
        ) -> OverlayFontWeight {
            guard let source else { return fallback }
            return OverlayFontWeight(rawValue: source.evaluate(in: context)) ?? fallback
        }

        func stringEnum<Enum: RawRepresentable>(
            _ source: OverlayComponentStringSource?,
            default fallback: Enum
        ) -> Enum where Enum.RawValue == String {
            guard let source else { return fallback }
            return Enum(rawValue: source.evaluate(in: context)) ?? fallback
        }

        let resolved: OverlayComponentResolvedNode
        switch node.kind {
        case .group(let children, let clip, let shadows, let shadowBounds):
            let groupFrame = frame(required: false)
                ?? CGRect(origin: .zero, size: CGSize(width: CGFloat(definition.size.width), height: CGFloat(definition.size.height)))
            let resolvedShadows = shadows.compactMap { shadow -> OverlayComponentResolvedShadow? in
                guard let color = shadow.color.evaluate(in: context) else { return nil }
                return OverlayComponentResolvedShadow(
                    sigma: number(shadow.sigma, default: 0),
                    dx: number(shadow.dx, default: 0),
                    dy: number(shadow.dy, default: 0),
                    color: color,
                    opacity: min(max(number(shadow.opacity, default: 1), 0), 1)
                )
            }
            let resolvedShadowBounds = shadowBounds?.evaluate(in: context)
            resolved = .group(
                frame: groupFrame,
                opacity: opacity,
                clip: clip,
                shadows: resolvedShadows,
                shadowBounds: resolvedShadowBounds,
                children: resolveNodes(children, path: "\(path).children", context: &context, diagnostics: &diagnostics)
            )
            return resolved

        case .stack(let direction, let spacing, let crossAlign, let children):
            let stackFrame: CGRect?
            if node.frame == nil {
                stackFrame = nil
            } else {
                guard let rect = frame() else { return nil }
                stackFrame = rect
            }
            resolved = .stack(
                frame: stackFrame,
                direction: resolveEnum(
                    direction,
                    default: OverlayComponentStackDirection.horizontal,
                    path: "\(path).direction",
                    context: context,
                    diagnostics: &diagnostics
                ),
                spacing: max(number(spacing, default: 0), 0),
                crossAlign: resolveEnum(
                    crossAlign,
                    default: OverlayComponentCrossAlignment.start,
                    path: "\(path).crossAlign",
                    context: context,
                    diagnostics: &diagnostics
                ),
                children: resolveStackChildren(
                    children,
                    path: "\(path).children",
                    context: &context,
                    diagnostics: &diagnostics
                )
            )

        case .rect(let fill, let radius, let stroke, let strokeWidth):
            guard let rect = frame(), let fillColor = color(fill) else {
                diagnostics.append("\(path): rect did not resolve")
                return nil
            }
            resolved = .rect(
                frame: rect,
                fill: fillColor,
                radius: max(number(radius, default: 0), 0),
                stroke: color(stroke),
                strokeWidth: max(number(strokeWidth, default: 1), 0)
            )

        case .circle(let center, let radius, let fill, let stroke, let strokeWidth):
            guard let resolvedCenter = center.evaluate(in: context) else {
                diagnostics.append("\(path): circle center did not resolve")
                return nil
            }
            let fillColor = color(fill)
            let strokeColor = color(stroke)
            if fillColor == nil && strokeColor == nil {
                diagnostics.append("\(path): circle has no fill or stroke")
                return nil
            }
            resolved = .circle(
                center: resolvedCenter,
                radius: max(number(radius, default: 0), 0),
                fill: fillColor,
                stroke: strokeColor,
                strokeWidth: max(number(strokeWidth, default: 1), 0)
            )

        case .line(let from, let to, let width, let lineColor, let cap):
            guard let start = from.evaluate(in: context),
                  let end = to.evaluate(in: context),
                  let color = lineColor.evaluate(in: context) else {
                diagnostics.append("\(path): line did not resolve")
                return nil
            }
            resolved = .line(
                from: start,
                to: end,
                width: max(number(width, default: 1), 0),
                color: color,
                cap: cap
            )

        case .polyline(let points, let width, let lineColor, let cap, let join, let dash):
            guard let resolvedPoints = points.evaluate(in: context),
                  resolvedPoints.count >= 2,
                  let color = lineColor.evaluate(in: context) else {
                diagnostics.append("\(path): polyline did not resolve")
                return nil
            }
            resolved = .polyline(
                points: resolvedPoints,
                width: max(number(width, default: 1), 0),
                color: color,
                cap: cap,
                join: join,
                dash: dash?.compactMap { $0.evaluate(in: context) }
            )

        case .path(let commands, let fill, let stroke, let strokeWidth, let cap, let join, let dash):
            let resolvedCommands = commands.compactMap { command -> OverlayComponentResolvedPathCommand? in
                resolvePathCommand(command, context: context)
            }
            guard resolvedCommands.count == commands.count else {
                diagnostics.append("\(path): path commands did not resolve")
                return nil
            }
            let fillColor = color(fill)
            let strokeColor = color(stroke)
            if fillColor == nil && strokeColor == nil {
                diagnostics.append("\(path): path has no fill or stroke")
                return nil
            }
            resolved = .path(
                commands: resolvedCommands,
                fill: fillColor,
                stroke: strokeColor,
                strokeWidth: max(number(strokeWidth, default: 1), 0),
                cap: cap,
                join: join,
                dash: dash?.compactMap { $0.evaluate(in: context) }
            )

        case .text(let text, let font, let textColor, let align, let verticalAlign, let maxWidth, let lineHeight, let tracking):
            let resolvedFrame: CGRect?
            if node.frame == nil {
                resolvedFrame = nil
            } else {
                guard let rect = frame() else { return nil }
                resolvedFrame = rect
            }
            guard let resolvedColor = textColor.evaluate(in: context) else {
                diagnostics.append("\(path): text color did not resolve")
                return nil
            }
            let size = font.size.evaluate(in: context) ?? 0
            guard size > 0 else {
                diagnostics.append("\(path): text font size did not resolve")
                return nil
            }
            let family = font.family.evaluate(in: context)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let weightName = font.weight.evaluate(in: context)
            let weight = OverlayComponentFontWeight(rawValue: weightName) ?? {
                diagnostics.append("\(path): font weight '\(weightName)' is invalid; using regular")
                return .regular
            }()
            resolved = .text(
                frame: resolvedFrame ?? .zero,
                text: text.evaluate(in: context),
                font: OverlayComponentResolvedFont(
                    family: family.isEmpty ? "system" : family,
                    size: size,
                    weight: weight
                ),
                color: resolvedColor,
                align: align,
                verticalAlign: verticalAlign,
                maxWidth: maxWidth?.evaluate(in: context),
                lineHeight: max(lineHeight?.evaluate(in: context) ?? 1.2, 0.5),
                tracking: tracking?.evaluate(in: context) ?? 0,
                autoSize: resolvedFrame == nil
            )

        case .textRows(let rows, let spacing, let maxWidth):
            let resolvedFrame: CGRect?
            if node.frame == nil {
                resolvedFrame = nil
            } else {
                guard let rect = frame() else { return nil }
                resolvedFrame = rect
            }
            var resolvedRows: [OverlayComponentResolvedTextRows.Row] = []
            for row in rows {
                if let condition = row.condition, !condition.evaluate(in: context).isTruthy {
                    continue
                }
                var runs: [OverlayComponentResolvedTextRows.Run] = []
                for run in row.runs {
                    if let condition = run.condition, !condition.evaluate(in: context).isTruthy {
                        continue
                    }
                    guard let size = run.font.size.evaluate(in: context), size > 0,
                          let runColor = run.color.evaluate(in: context) else {
                        diagnostics.append("\(path): textRows font or color did not resolve")
                        return nil
                    }
                    let family = run.font.family.evaluate(in: context)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let weight = resolveEnum(run.font.weight, default: OverlayComponentFontWeight.regular,
                                             path: "\(path).rows.font.weight", context: context, diagnostics: &diagnostics)
                    let resolvedText = run.text.evaluate(in: context)
                    guard !resolvedText.isEmpty else { continue }
                    runs.append(.init(
                        text: resolvedText,
                        font: .init(family: family.isEmpty ? "system" : family, size: size, weight: weight),
                        color: runColor,
                        minimumScaleFactor: min(max(number(run.minimumScaleFactor, default: 1), 0.1), 1),
                        verticalPadding: max(number(run.verticalPadding, default: 0), 0),
                        opacity: min(max(number(run.opacity, default: 1), 0), 1),
                        monospacedDigits: run.monospacedDigits
                    ))
                }
                resolvedRows.append(.init(
                    runs: runs,
                    spacing: max(number(row.spacing, default: 0), 0),
                    alignment: row.alignment
                ))
            }
            resolved = .textRows(
                frame: resolvedFrame ?? .zero,
                text: .init(
                    rows: resolvedRows,
                    spacing: max(number(spacing, default: 0), 0),
                    maxWidth: maxWidth.map { max(number($0, default: 0), 1) }
                ),
                autoSize: resolvedFrame == nil
            )

        case .richText(let text):
            guard let rect = frame(), let fill = color(text.color),
                  let size = text.font.size.evaluate(in: context), size > 0 else {
                diagnostics.append("\(path): richText frame, font or color did not resolve")
                return nil
            }
            let family = text.font.family.evaluate(in: context).trimmingCharacters(in: .whitespacesAndNewlines)
            let weight = resolveEnum(text.font.weight, default: OverlayComponentFontWeight.regular,
                                     path: "\(path).font.weight", context: context, diagnostics: &diagnostics)
            var gradient: OverlayComponentResolvedTextGradient?
            if let source = text.gradient {
                let stops = source.stops.compactMap { stop -> OverlayComponentGradientStop? in
                    guard let color = stop.color.evaluate(in: context) else { return nil }
                    return .init(offset: stop.offset, color: color)
                }
                guard stops.count == source.stops.count,
                      let from = source.from.evaluate(in: context),
                      let to = source.to.evaluate(in: context) else {
                    diagnostics.append("\(path).gradient: gradient did not resolve")
                    return nil
                }
                gradient = .init(stops: stops, from: from, to: to)
            }
            resolved = .richText(frame: rect, text: .init(
                text: text.text.evaluate(in: context),
                font: .init(family: family.isEmpty ? "system" : family, size: size, weight: weight),
                color: fill,
                align: resolveEnum(text.align, default: OverlayComponentTextAlignment.center,
                                   path: "\(path).align", context: context, diagnostics: &diagnostics),
                lineHeight: max(number(text.lineHeight, default: 1.2), 0.5),
                tracking: number(text.tracking, default: 0),
                stroke: color(text.stroke, default: .white) ?? .white,
                strokeWidth: max(number(text.strokeWidth, default: 0), 0),
                autoFit: text.autoFit?.evaluate(in: context).isTruthy ?? false,
                gradient: gradient
            ))

        case .image(let asset, let fit):
            guard let rect = frame() else { return nil }
            resolved = .image(frame: rect, asset: asset, fit: fit)

        case .spacer(let length, let minimum):
            resolved = .spacer(
                length: length.map { max(number($0, default: 0), 0) },
                minimum: max(number(minimum, default: 0), 0)
            )

        case .columns(let width, let divider, let children):
            guard let resolvedWidth = width.evaluate(in: context), resolvedWidth > 0 else {
                diagnostics.append("\(path): columns width did not resolve")
                return nil
            }
            let resolvedChildren = resolveNodes(
                children,
                path: "\(path).children",
                context: &context,
                diagnostics: &diagnostics
            )
            var resolvedDivider: OverlayComponentResolvedDivider?
            if let divider {
                guard let color = divider.color.evaluate(in: context) else {
                    diagnostics.append("\(path).divider: color did not resolve")
                    return nil
                }
                resolvedDivider = .init(
                    width: max(number(divider.width, default: 1), 0),
                    color: color,
                    opacity: min(max(number(divider.opacity, default: 1), 0), 1),
                    height: max(number(divider.height, default: 0), 0)
                )
            }
            resolved = .columns(
                width: resolvedWidth,
                divider: resolvedDivider,
                children: resolvedChildren
            )

        case .symbol(let name, let symbolColor, let weight, let scale, let rendering):
            guard let rect = frame() else { return nil }
            let resolvedName = name.evaluate(in: context)
            guard OverlayComponentSymbolName.isValid(resolvedName) else {
                diagnostics.append("\(path): symbol name '\(resolvedName)' is invalid")
                return nil
            }
            guard let resolvedColor = symbolColor.evaluate(in: context) else {
                diagnostics.append("\(path): symbol color did not resolve")
                return nil
            }
            resolved = .symbol(
                frame: rect, name: resolvedName, color: resolvedColor,
                weight: resolveEnum(weight, default: OverlayComponentFontWeight.medium,
                                    path: "\(path).weight", context: context, diagnostics: &diagnostics),
                scale: resolveEnum(scale, default: OverlayComponentSymbolScale.medium,
                                   path: "\(path).scale", context: context, diagnostics: &diagnostics),
                rendering: rendering
            )

        case .gradientRect(let stops, let from, let to, let radius):
            guard let rect = frame(),
                  let start = from.evaluate(in: context),
                  let end = to.evaluate(in: context) else {
                diagnostics.append("\(path): gradientRect did not resolve")
                return nil
            }
            resolved = .gradientRect(
                frame: rect,
                stops: stops,
                from: start,
                to: end,
                radius: max(number(radius, default: 0), 0)
            )

        case .sparkline(let series, let stroke, let lineWidth, let fill, let smoothing):
            guard let rect = frame(),
                  case .list(let rawValues) = series.evaluate(in: context),
                  let strokeColor = stroke.evaluate(in: context) else {
                diagnostics.append("\(path): sparkline series did not resolve")
                return nil
            }
            resolved = .sparkline(
                frame: rect,
                values: rawValues.map(\.number),
                stroke: strokeColor,
                lineWidth: max(number(lineWidth, default: 1), 0),
                fill: color(fill),
                smoothing: smoothing
            )

        case .progressBar(let value, let trackColor, let fillColor, let radius):
            guard let rect = frame(),
                  let progress = value.evaluate(in: context).number,
                  let track = trackColor.evaluate(in: context),
                  let fill = fillColor.evaluate(in: context) else {
                diagnostics.append("\(path): progressBar did not resolve")
                return nil
            }
            resolved = .progressBar(
                frame: rect,
                value: min(max(progress, 0), 1),
                trackColor: track,
                fillColor: fill,
                radius: max(number(radius, default: 0), 0)
            )

        case .arc(let value, let startDegrees, let sweepDegrees, let radius, let width, let trackColor, let fillColor, let cap):
            guard let rect = frame(),
                  let progress = value.evaluate(in: context).number,
                  let fill = fillColor.evaluate(in: context) else {
                diagnostics.append("\(path): arc did not resolve")
                return nil
            }
            resolved = .arc(
                frame: rect,
                value: min(max(progress, 0), 1),
                startDegrees: number(startDegrees, default: 0),
                sweepDegrees: number(sweepDegrees, default: 360),
                radius: max(number(radius, default: 0), 0),
                width: max(number(width, default: 1), 0),
                trackColor: color(trackColor),
                fillColor: fill,
                cap: cap
            )

        case .segmentedBar(let bar):
            guard let rect = frame() else { return nil }
            let segments: [OverlayComponentResolvedSegment]
            switch bar.segments.evaluate(in: context) {
            case .list(let items):
                segments = items.compactMap { item in
                    guard let record = item.record,
                          let index = record["index"]?.number.map({ Int($0.rounded()) }),
                          let segmentColor = record["color"]?.color else {
                        return nil
                    }
                    return OverlayComponentResolvedSegment(index: index, color: segmentColor)
                }
            case .null:
                segments = []
            default:
                diagnostics.append("\(path): segmentedBar segments did not resolve to a list")
                return nil
            }
            let isVertical = bar.orientation?.evaluate(in: context) == "vertical"
            var markers: [OverlayComponentResolvedSegmentedBarMarker] = []
            for marker in bar.markers {
                if let condition = marker.condition, !condition.evaluate(in: context).isTruthy {
                    continue
                }
                guard let markerIndex = marker.index?.evaluate(in: context).map({ Int($0.rounded()) }),
                      let fraction = marker.fraction?.evaluate(in: context),
                      let markerColor = marker.color.evaluate(in: context),
                      let font = resolveFont(marker.font, path: "\(path).markers", context: context, diagnostics: &diagnostics) else {
                    diagnostics.append("\(path): segmentedBar marker did not resolve")
                    continue
                }
                let position = marker.position?.evaluate(in: context)
                let side = OverlayComponentSegmentedBarMarkerSide(rawValue: position ?? "")
                    ?? (isVertical ? .trailing : .above)
                markers.append(OverlayComponentResolvedSegmentedBarMarker(
                    role: marker.role,
                    layout: marker.layout,
                    index: markerIndex,
                    fraction: min(max(fraction, 0), 1),
                    text: marker.text.evaluate(in: context),
                    color: markerColor,
                    side: side,
                    showsValue: marker.showsValue.map { ($0.evaluate(in: context) ?? 0) != 0 } ?? true,
                    scale: marker.scale.flatMap { $0.evaluate(in: context) }.map { max($0, 0) } ?? 1,
                    font: font
                ))
            }
            var glow: OverlayComponentResolvedSegmentedBarGlow?
            if let resolvedGlow = bar.glow {
                glow = OverlayComponentResolvedSegmentedBarGlow(
                    opacity: min(max(number(resolvedGlow.opacity, default: 0), 0), 1),
                    sigma: max(number(resolvedGlow.sigma, default: 0), 0)
                )
            }
            resolved = .segmentedBar(
                frame: rect,
                vertical: isVertical,
                segments: segments,
                activeIndex: bar.activeIndex.flatMap { source in
                    source.evaluate(in: context).map { Int($0.rounded()) }
                },
                activeWidthShare: min(max(number(bar.activeWidthShare, default: 0), 0), 0.5),
                activeThicknessScale: max(number(bar.activeThicknessScale, default: 1), 1),
                gap: max(number(bar.gap, default: 0), 0),
                radius: max(number(bar.radius, default: 0), 0),
                inactiveOpacity: min(max(number(bar.inactiveOpacity, default: 1), 0), 1),
                glow: glow,
                border: bar.border.flatMap { resolvedBorder in
                    guard let borderColor = resolvedBorder.color.evaluate(in: context) else {
                        diagnostics.append("\(path).border: color did not resolve")
                        return nil
                    }
                    return OverlayComponentResolvedSegmentedBarBorder(
                        color: borderColor,
                        opacity: min(max(number(resolvedBorder.opacity, default: 1), 0), 1),
                        width: max(number(resolvedBorder.width, default: 1), 0)
                    )
                },
                markers: markers
            )


        case .timelineStrip(let strip):
            guard let rect = frame() else { return nil }
            let laps: [OverlayComponentResolvedTimelineLap]
            switch strip.segments.evaluate(in: context) {
            case .list(let items):
                laps = items.compactMap { item in
                    guard let record = item.record else { return nil }
                    return OverlayComponentResolvedTimelineLap(
                        index: record["index"]?.number.map { Int($0.rounded()) } ?? 0,
                        kind: record["kind"]?.string ?? "unknown",
                        startElapsed: record["startElapsed"]?.number ?? 0,
                        endElapsed: record["endElapsed"]?.number ?? 0,
                        elapsed: record["elapsed"]?.number ?? 0,
                        distance: record["distance"]?.number ?? 0
                    )
                }
            case .null:
                laps = []
            default:
                diagnostics.append("\(path): timelineStrip segments did not resolve to a list")
                return nil
            }
            let resolvedColors = OverlayComponentResolvedTimelineColors(
                warmup: strip.colors?.warmup.evaluate(in: context) ?? .white,
                active: strip.colors?.active.evaluate(in: context) ?? .white,
                rest: strip.colors?.rest.evaluate(in: context) ?? .white,
                cooldown: strip.colors?.cooldown.evaluate(in: context) ?? .white,
                unknown: strip.colors?.unknown.evaluate(in: context) ?? .white
            )
            var resolvedLabels: OverlayComponentResolvedTimelineLabels?
            if let labels = strip.labels,
               let font = resolveFont(labels.font, path: "\(path).labels", context: context, diagnostics: &diagnostics) {
                resolvedLabels = OverlayComponentResolvedTimelineLabels(
                    font: font,
                    currentWorkDistance: labels.currentWorkDistance?.evaluate(in: context) ?? "elapsed",
                    currentWorkTime: labels.currentWorkTime?.evaluate(in: context) ?? "remaining",
                    currentRestKind: labels.currentRestKind.map { ($0.evaluate(in: context) ?? 0) != 0 } ?? true,
                    currentRestDistance: labels.currentRestDistance?.evaluate(in: context) ?? "hidden",
                    currentRestTime: labels.currentRestTime?.evaluate(in: context) ?? "remaining",
                    neighbor: labels.neighbor?.evaluate(in: context) ?? "distance"
                )
            }
            var resolvedProgress: OverlayComponentResolvedTimelineProgress?
            if let progress = strip.progress,
               let value = progress.value.evaluate(in: context),
               let progressColor = progress.color.evaluate(in: context) {
                resolvedProgress = OverlayComponentResolvedTimelineProgress(
                    value: min(max(value, 0), 1),
                    color: progressColor,
                    opacity: min(max(progress.opacity.flatMap { $0.evaluate(in: context) } ?? 0.3, 0), 1)
                )
            }
            var resolvedMarker: OverlayComponentResolvedTimelineMarker?
            if let marker = strip.marker,
               let markerColor = marker.color.evaluate(in: context),
               let markerFont = resolveFont(marker.font, path: "\(path).marker", context: context, diagnostics: &diagnostics) {
                resolvedMarker = OverlayComponentResolvedTimelineMarker(
                    enabled: marker.enabled.map { ($0.evaluate(in: context) ?? 0) != 0 } ?? true,
                    position: marker.position?.evaluate(in: context) ?? "progress",
                    color: markerColor,
                    label: marker.label?.evaluate(in: context) ?? "NOW",
                    showsLabel: marker.showsLabel.map { ($0.evaluate(in: context) ?? 0) != 0 } ?? true,
                    font: markerFont
                )
            }
            var resolvedOverflow: OverlayComponentResolvedTimelineOverflow?
            if let overflow = strip.overflow,
               let overflowColor = overflow.color.evaluate(in: context) {
                resolvedOverflow = OverlayComponentResolvedTimelineOverflow(
                    enabled: overflow.enabled.map { ($0.evaluate(in: context) ?? 0) != 0 } ?? true,
                    text: overflow.text?.evaluate(in: context) ?? "···",
                    color: overflowColor,
                    inset: max(overflow.inset.flatMap { $0.evaluate(in: context) } ?? 36, 0)
                )
            }
            resolved = .timelineStrip(
                frame: rect,
                strip: OverlayComponentResolvedTimelineStrip(
                    laps: laps,
                    currentIndex: strip.currentIndex.flatMap { source in
                        source.evaluate(in: context).map { Int($0.rounded()) }
                    },
                    elapsed: strip.elapsed.flatMap { $0.evaluate(in: context) } ?? 0,
                    mode: strip.mode?.evaluate(in: context) ?? "emphasized",
                    emphasisFraction: min(max(strip.emphasisFraction.flatMap { $0.evaluate(in: context) } ?? 0.28, 0), 0.65),
                    window: strip.window.flatMap { source in
                        source.evaluate(in: context).map { max(Int($0.rounded()), 0) }
                    },
                    showsWarmup: strip.showsWarmup.map { ($0.evaluate(in: context) ?? 0) != 0 } ?? true,
                    showsRest: strip.showsRest.map { ($0.evaluate(in: context) ?? 0) != 0 } ?? true,
                    showsCooldown: strip.showsCooldown.map { ($0.evaluate(in: context) ?? 0) != 0 } ?? true,
                    segmentAreaHeight: max(strip.segmentAreaHeight.flatMap { $0.evaluate(in: context) } ?? 64, 1),
                    segmentHeight: max(strip.segmentHeight.flatMap { $0.evaluate(in: context) } ?? 30, 1),
                    currentHeightScale: max(strip.currentHeightScale.flatMap { $0.evaluate(in: context) } ?? 1.35, 1),
                    minSegmentWidth: max(strip.minSegmentWidth.flatMap { $0.evaluate(in: context) } ?? 54, 0),
                    gap: max(strip.gap.flatMap { $0.evaluate(in: context) } ?? 4, 0),
                    radius: max(strip.radius.flatMap { $0.evaluate(in: context) } ?? 6, 0),
                    currentBorderWidth: max(strip.currentBorderWidth.flatMap { $0.evaluate(in: context) } ?? 1.4, 0),
                    completedOpacity: min(max(strip.completedOpacity.flatMap { $0.evaluate(in: context) } ?? 0.45, 0), 1),
                    futureOpacity: min(max(strip.futureOpacity.flatMap { $0.evaluate(in: context) } ?? 0.32, 0), 1),
                    colors: resolvedColors,
                    labels: resolvedLabels,
                    progress: resolvedProgress,
                    marker: resolvedMarker,
                    overflow: resolvedOverflow,
                    repText: strip.repText?.evaluate(in: context) ?? "",
                    distanceProgress: min(max(strip.distanceProgress.flatMap { $0.evaluate(in: context) } ?? 0, 0), 1)
                )
            )


        case .runningGauge(let gauge):
            guard let rect = frame() else { return nil }
            return resolveRunningGaugeNode(gauge, rect: rect, path: path,
                                           context: context, diagnostics: &diagnostics)

        case .distanceTimeline(let timeline):
            guard let rect = frame() else { return nil }
            return resolveDistanceTimelineNode(timeline, rect: rect, path: path,
                                               context: context, diagnostics: &diagnostics)

        case .elevationChart(let chart):
            guard let rect = frame() else { return nil }
            return resolveElevationChartNode(chart, rect: rect, path: path,
                                             context: context, diagnostics: &diagnostics)

        case .routeMap(let map):
            guard let rect = frame() else { return nil }
            return resolveRouteMapNode(map, rect: rect, path: path,
                                       context: context, diagnostics: &diagnostics)

        case .weatherWidget(let widget):
            guard let rect = frame() else { return nil }
            return resolveWeatherWidgetNode(widget, rect: rect, path: path,
                                            context: context, diagnostics: &diagnostics)


        case .repeatNode(let over, let itemName, let indexName, let maximum, let children):
            guard let rect = frame() else { return nil }
            guard case .list(let items) = over.evaluate(in: context) else {
                diagnostics.append("\(path): repeat source did not resolve to a list")
                return nil
            }
            let limit = min(max(Int(number(maximum, default: 64)), 0), 512)
            var resolvedChildren: [OverlayComponentResolvedNode] = []
            for (index, item) in items.prefix(limit).enumerated() {
                var childContext = context
                childContext.locals[itemName] = item
                childContext.locals[indexName] = .number(Double(index))
                resolvedChildren.append(contentsOf: resolveNodes(
                    children,
                    path: "\(path).children",
                    context: &childContext,
                    diagnostics: &diagnostics
                ))
            }
            resolved = .group(
                frame: rect,
                opacity: opacity,
                clip: false,
                shadows: [],
                shadowBounds: nil,
                children: resolvedChildren
            )
            return resolved
        }

        if opacity < 1, case .group = node.kind {
            return resolved
        }
        if opacity < 1 {
            return .opacity(opacity, resolved)
        }
        return resolved
    }

    private func nodeNumber(_ source: OverlayComponentNumberSource?, default fallback: Double,
                           context: OverlayComponentEvaluationContext) -> Double {
        source?.evaluate(in: context) ?? fallback
    }

    private func nodeFlag(_ source: OverlayComponentNumberSource?, default fallback: Bool,
                          context: OverlayComponentEvaluationContext) -> Bool {
        guard let source else { return fallback }
        return (source.evaluate(in: context) ?? (fallback ? 1 : 0)) != 0
    }

    private func nodeColor(_ source: OverlayComponentColorSource?, default fallback: OverlayColor?,
                           context: OverlayComponentEvaluationContext) -> OverlayColor? {
        guard let source else { return fallback }
        return source.evaluate(in: context)
    }

    private func nodeWeight(_ source: OverlayComponentStringSource?, default fallback: OverlayFontWeight,
                            context: OverlayComponentEvaluationContext) -> OverlayFontWeight {
        guard let source else { return fallback }
        return OverlayFontWeight(rawValue: source.evaluate(in: context)) ?? fallback
    }

    private func nodeStringEnum<Enum: RawRepresentable>(
        _ source: OverlayComponentStringSource?, default fallback: Enum,
        context: OverlayComponentEvaluationContext
    ) -> Enum where Enum.RawValue == String {
        guard let source else { return fallback }
        return Enum(rawValue: source.evaluate(in: context)) ?? fallback
    }

    @inline(never)
    private func resolveRunningGaugeNode(_ gauge: OverlayComponentRunningGauge, rect: CGRect, path: String,
        context: OverlayComponentEvaluationContext, diagnostics: inout [String]
    ) -> OverlayComponentResolvedNode? {
        let resolved: OverlayComponentResolvedNode
        
        let presetName = gauge.layoutPreset?.evaluate(in: context) ?? "topTwoMiddleBottom"
        let layoutPreset = RunningGaugeLayoutPreset(rawValue: presetName) ?? .topTwoMiddleBottom
        var style = RunningGaugeStyle.default
        style.layoutPreset = layoutPreset
        style.fontName = gauge.font.family.evaluate(in: context)
        style.dialBackgroundColor = gauge.dialBackgroundColor?.evaluate(in: context) ?? style.dialBackgroundColor
        style.dialBackgroundOpacity = nodeNumber(gauge.dialBackgroundOpacity, default: style.dialBackgroundOpacity, context: context)
        style.glassEffectEnabled = nodeFlag(gauge.glassEffectEnabled, default: style.glassEffectEnabled, context: context)
        style.outerRingEnabled = nodeFlag(gauge.outerRingEnabled, default: style.outerRingEnabled, context: context)
        style.outerRingColor = gauge.outerRingColor?.evaluate(in: context) ?? style.outerRingColor
        style.outerRingOpacity = nodeNumber(gauge.outerRingOpacity, default: style.outerRingOpacity, context: context)
        style.outerRingWidthScale = nodeNumber(gauge.outerRingWidthScale, default: style.outerRingWidthScale, context: context)
        style.tickMarksEnabled = nodeFlag(gauge.tickMarksEnabled, default: style.tickMarksEnabled, context: context)
        style.tickColor = gauge.tickColor?.evaluate(in: context) ?? style.tickColor
        style.tickOpacity = nodeNumber(gauge.tickOpacity, default: style.tickOpacity, context: context)
        style.majorTickOpacity = nodeNumber(gauge.majorTickOpacity, default: style.majorTickOpacity, context: context)
        style.tickCount = Int(nodeNumber(gauge.tickCount, default: Double(style.tickCount), context: context).rounded())
        style.majorTickEvery = Int(nodeNumber(gauge.majorTickEvery, default: Double(style.majorTickEvery), context: context).rounded())
        style.progressRingEnabled = nodeFlag(gauge.progressRingEnabled, default: style.progressRingEnabled, context: context)
        style.progressColor = gauge.progressColor?.evaluate(in: context) ?? style.progressColor
        style.progressTrackColor = gauge.progressTrackColor?.evaluate(in: context) ?? style.progressTrackColor
        style.progressTrackOpacity = nodeNumber(gauge.progressTrackOpacity, default: style.progressTrackOpacity, context: context)
        style.progressRingWidthScale = nodeNumber(gauge.progressRingWidthScale, default: style.progressRingWidthScale, context: context)
        style.progressRoundedCaps = nodeFlag(gauge.progressRoundedCaps, default: style.progressRoundedCaps, context: context)
        style.dividerEnabled = nodeFlag(gauge.dividerEnabled, default: style.dividerEnabled, context: context)
        style.dividerColor = gauge.dividerColor?.evaluate(in: context) ?? style.dividerColor
        style.dividerOpacity = nodeNumber(gauge.dividerOpacity, default: style.dividerOpacity, context: context)
        style.dividerWidth = nodeNumber(gauge.dividerWidth, default: style.dividerWidth, context: context)
        style.monospacedDigits = nodeFlag(gauge.monospacedDigits, default: style.monospacedDigits, context: context)
        style.primaryFontWeight = nodeWeight(gauge.primaryFontWeight, default: style.primaryFontWeight, context: context)
        style.secondaryFontWeight = nodeWeight(gauge.secondaryFontWeight, default: style.secondaryFontWeight, context: context)
        style.primaryTextColor = gauge.primaryTextColor?.evaluate(in: context) ?? style.primaryTextColor
        style.secondaryTextColor = gauge.secondaryTextColor?.evaluate(in: context) ?? style.secondaryTextColor
        style.accentColor = gauge.accentColor?.evaluate(in: context) ?? style.accentColor

        var configs: [RunningGaugeRegionConfig] = []
        for (index, region) in (gauge.regions ?? []).enumerated() {
            let metricId = region.metric.evaluate(in: context)
            guard let overlayMetric = OverlayMetric(rawValue: metricId),
                  let gaugeMetric = OverlayGaugeMetric(metric: overlayMetric) else {
                diagnostics.append("\(path).regions[\(index)]: unknown metric")
                continue
            }
            let regionName = region.region?.evaluate(in: context)
                ?? layoutPreset.regions[min(index, max(layoutPreset.regions.count - 1, 0))].rawValue
            guard let gaugeRegion = RunningGaugeRegion(rawValue: regionName) else {
                diagnostics.append("\(path).regions[\(index)]: unknown region '\(regionName)'")
                continue
            }
            configs.append(RunningGaugeRegionConfig(
                region: gaugeRegion,
                metric: gaugeMetric,
                customLabel: region.customLabel?.evaluate(in: context) ?? "",
                showLabel: nodeFlag(region.showLabel, default: true, context: context),
                showUnit: nodeFlag(region.showUnit, default: true, context: context),
                showIcon: false,
                valueFontScale: nodeNumber(region.valueFontScale, default: 1, context: context),
                labelFontScale: nodeNumber(region.labelFontScale, default: 0.32, context: context),
                unitFontScale: nodeNumber(region.unitFontScale, default: 0.42, context: context),
                valueWeight: nodeWeight(region.valueWeight, default: .bold, context: context),
                labelWeight: nodeWeight(region.labelWeight, default: .medium, context: context),
                valueColor: region.valueColor?.evaluate(in: context),
                labelColor: region.labelColor?.evaluate(in: context)
            ))
        }
        style.regions = configs
        let regions = configs.enumerated().map { index, config in
            let value = context.data?.metric(
                id: (gauge.regions ?? [])[index].metric.evaluate(in: context),
                units: []
            ) ?? .null
            let record = value.record
            return OverlayComponentResolvedGaugeRegion(
                config: config,
                components: OverlayValueComponents(
                    label: record?["label"]?.string ?? "",
                    shortLabel: record?["shortLabel"]?.string ?? "",
                    value: record?["value"]?.string ?? "",
                    unit: record?["unit"]?.string ?? ""
                )
            )
        }
        resolved = .runningGauge(
            frame: rect,
            gauge: OverlayComponentResolvedGauge(
                style: style,
                progress: min(max(nodeNumber(gauge.progress, default: 0, context: context), 0), 1),
                regions: regions
            )
        )
        return resolved
    }

    @inline(never)
    private func resolveDistanceTimelineNode(_ timeline: OverlayComponentDistanceTimeline, rect: CGRect, path: String,
        context: OverlayComponentEvaluationContext, diagnostics: inout [String]
    ) -> OverlayComponentResolvedNode? {
        let resolved: OverlayComponentResolvedNode
        
        let presetName = timeline.preset?.evaluate(in: context) ?? "minimal"
        let preset = DistanceTimelinePreset(rawValue: presetName) ?? .minimal
        var style = DistanceTimelineStyle.preset(preset)
        style.width = nodeNumber(timeline.width, default: style.width, context: context)
        style.height = nodeNumber(timeline.height, default: style.height, context: context)
        style.valueUnitSystem = nodeStringEnum(timeline.valueUnitSystem, default: style.valueUnitSystem, context: context)
        style.showValue = nodeFlag(timeline.showValue, default: style.showValue, context: context)
        style.showTotalDistance = nodeFlag(timeline.showTotalDistance, default: style.showTotalDistance, context: context)
        style.showLabel = nodeFlag(timeline.showLabel, default: style.showLabel, context: context)
        style.label = timeline.label?.evaluate(in: context) ?? style.label
        style.labelFontName = timeline.labelFontFamily?.evaluate(in: context) ?? style.labelFontName
        style.labelFontSize = nodeNumber(timeline.labelFontSize, default: style.labelFontSize, context: context)
        style.labelFontWeight = nodeWeight(timeline.labelFontWeight, default: style.labelFontWeight, context: context)
        style.labelColor = nodeColor(timeline.labelColor, default: style.labelColor, context: context) ?? style.labelColor
        style.labelValueSpacing = nodeNumber(timeline.labelValueSpacing, default: style.labelValueSpacing, context: context)
        style.showAxisLabels = nodeFlag(timeline.showAxisLabels, default: style.showAxisLabels, context: context)
        style.axisLabelMode = nodeStringEnum(timeline.axisLabelMode, default: style.axisLabelMode, context: context)
        style.axisLabelOffset = nodeNumber(timeline.axisLabelOffset, default: style.axisLabelOffset, context: context)
        style.axisLabelFontName = timeline.axisLabelFontFamily?.evaluate(in: context) ?? style.axisLabelFontName
        style.axisLabelFontSize = nodeNumber(timeline.axisLabelFontSize, default: style.axisLabelFontSize, context: context)
        style.axisLabelFontWeight = nodeWeight(timeline.axisLabelFontWeight, default: style.axisLabelFontWeight, context: context)
        style.axisLabelColor = nodeColor(timeline.axisLabelColor, default: style.axisLabelColor, context: context) ?? style.axisLabelColor
        style.showDistancePoints = nodeFlag(timeline.showDistancePoints, default: style.showDistancePoints, context: context)
        style.distancePointCount = Int(nodeNumber(timeline.distancePointCount, default: Double(style.distancePointCount), context: context).rounded())
        style.distancePointOffset = nodeNumber(timeline.distancePointOffset, default: style.distancePointOffset, context: context)
        style.midpointAxisLabelOffset = nodeNumber(timeline.midpointAxisLabelOffset, default: style.midpointAxisLabelOffset, context: context)
        style.axisEndpointLabelPlacement = nodeStringEnum(timeline.axisEndpointLabelPlacement, default: style.axisEndpointLabelPlacement, context: context)
        style.axisMidpointLabelPlacement = nodeStringEnum(timeline.axisMidpointLabelPlacement, default: style.axisMidpointLabelPlacement, context: context)
        style.markerDistanceLabelEnabled = nodeFlag(timeline.markerDistanceLabelEnabled, default: style.markerDistanceLabelEnabled, context: context)
        style.markerDistanceLabelPlacement = nodeStringEnum(timeline.markerDistanceLabelPlacement, default: style.markerDistanceLabelPlacement, context: context)
        style.markerDistanceLabelOffset = nodeNumber(timeline.markerDistanceLabelOffset, default: style.markerDistanceLabelOffset, context: context)
        style.currentMarkerSizeMultiplier = nodeNumber(timeline.currentMarkerSizeMultiplier, default: style.currentMarkerSizeMultiplier, context: context)
        style.backgroundEnabled = nodeFlag(timeline.backgroundEnabled, default: style.backgroundEnabled, context: context)
        style.backgroundColor = nodeColor(timeline.backgroundColor, default: style.backgroundColor, context: context) ?? style.backgroundColor
        style.backgroundOpacity = nodeNumber(timeline.backgroundOpacity, default: style.backgroundOpacity, context: context)
        style.borderEnabled = nodeFlag(timeline.borderEnabled, default: style.borderEnabled, context: context)
        style.borderColor = nodeColor(timeline.borderColor, default: style.borderColor, context: context) ?? style.borderColor
        style.borderOpacity = nodeNumber(timeline.borderOpacity, default: style.borderOpacity, context: context)
        style.borderWidth = nodeNumber(timeline.borderWidth, default: style.borderWidth, context: context)
        style.cornerRadius = nodeNumber(timeline.cornerRadius, default: style.cornerRadius, context: context)
        style.paddingX = nodeNumber(timeline.paddingX, default: style.paddingX, context: context)
        style.paddingY = nodeNumber(timeline.paddingY, default: style.paddingY, context: context)
        style.trackHeight = nodeNumber(timeline.trackHeight, default: style.trackHeight, context: context)
        style.trackOpacity = nodeNumber(timeline.trackOpacity, default: style.trackOpacity, context: context)
        style.fillColor = nodeColor(timeline.fillColor, default: style.fillColor, context: context) ?? style.fillColor
        style.tickMarksEnabled = nodeFlag(timeline.tickMarksEnabled, default: style.tickMarksEnabled, context: context)
        style.tickDensity = Int(nodeNumber(timeline.tickDensity, default: Double(style.tickDensity), context: context).rounded())
        style.currentMarkerEnabled = nodeFlag(timeline.currentMarkerEnabled, default: style.currentMarkerEnabled, context: context)
        style.currentMarkerStyle = nodeStringEnum(timeline.currentMarkerStyle, default: style.currentMarkerStyle, context: context)
        style.currentMarkerColor = nodeColor(timeline.currentMarkerColor, default: style.currentMarkerColor, context: context) ?? style.currentMarkerColor
        style.glowEnabled = nodeFlag(timeline.glowEnabled, default: style.glowEnabled, context: context)
        style.fadeEnabled = nodeFlag(timeline.fadeEnabled, default: style.fadeEnabled, context: context)
        style.fadeEdge = nodeStringEnum(timeline.fadeEdge, default: style.fadeEdge, context: context)
        style.fadeAmount = nodeNumber(timeline.fadeAmount, default: style.fadeAmount, context: context)
        style.mediaSlotEnabled = nodeFlag(timeline.mediaSlotEnabled, default: style.mediaSlotEnabled, context: context)
        style.mediaSlotMode = nodeStringEnum(timeline.mediaSlotMode, default: style.mediaSlotMode, context: context)
        style.mediaSystemImage = timeline.mediaSystemImage?.evaluate(in: context) ?? style.mediaSystemImage
        style.mediaSlotSize = nodeNumber(timeline.mediaSlotSize, default: style.mediaSlotSize, context: context)
        style.elevationProfileVisible = nodeFlag(timeline.elevationProfileVisible, default: style.elevationProfileVisible, context: context)
        if let statsBar = timeline.statsBar {
            applyStatsBar(
                statsBar,
                to: &style.statsBar,
                context: context,
                fallbackFontName: style.labelFontName
            )
        }
        resolved = .distanceTimeline(
            frame: rect,
            style: style,
            valueFontSize: max(nodeNumber(timeline.valueFontSize, default: 28, context: context), 1)
        )
        return resolved
    }

    @inline(never)
    private func resolveElevationChartNode(_ chart: OverlayComponentElevationChart, rect: CGRect, path: String,
        context: OverlayComponentEvaluationContext, diagnostics: inout [String]
    ) -> OverlayComponentResolvedNode? {
        let resolved: OverlayComponentResolvedNode
        
        let presetName = chart.preset?.evaluate(in: context) ?? "gradientArea"
        let preset = ElevationChartPreset(rawValue: presetName) ?? .gradientArea
        var style = ElevationChartStyle.preset(preset)
        style.width = nodeNumber(chart.width, default: style.width, context: context)
        style.height = nodeNumber(chart.height, default: style.height, context: context)
        style.chartStyle = nodeStringEnum(chart.chartStyle, default: style.chartStyle, context: context)
        style.smoothingEnabled = nodeFlag(chart.smoothingEnabled, default: style.smoothingEnabled, context: context)
        style.smoothingAmount = nodeNumber(chart.smoothingAmount, default: style.smoothingAmount, context: context)
        style.progressMode = nodeStringEnum(chart.progressMode, default: style.progressMode, context: context)
        style.chartPaddingX = nodeNumber(chart.chartPaddingX, default: style.chartPaddingX, context: context)
        style.chartPaddingY = nodeNumber(chart.chartPaddingY, default: style.chartPaddingY, context: context)
        style.lineColor = nodeColor(chart.lineColor, default: style.lineColor, context: context) ?? style.lineColor
        style.lineWidth = nodeNumber(chart.lineWidth, default: style.lineWidth, context: context)
        style.lineOpacity = nodeNumber(chart.lineOpacity, default: style.lineOpacity, context: context)
        style.fillEnabled = nodeFlag(chart.fillEnabled, default: style.fillEnabled, context: context)
        style.fillStartColor = nodeColor(chart.fillStartColor, default: style.fillStartColor, context: context) ?? style.fillStartColor
        style.fillEndColor = nodeColor(chart.fillEndColor, default: style.fillEndColor, context: context) ?? style.fillEndColor
        style.fillOpacity = nodeNumber(chart.fillOpacity, default: style.fillOpacity, context: context)
        style.dualAreaEnabled = nodeFlag(chart.dualAreaEnabled, default: style.dualAreaEnabled, context: context)
        style.upperFillColor = nodeColor(chart.upperFillColor, default: style.upperFillColor, context: context) ?? style.upperFillColor
        style.lowerFillColor = nodeColor(chart.lowerFillColor, default: style.lowerFillColor, context: context) ?? style.lowerFillColor
        style.currentMarkerEnabled = nodeFlag(chart.currentMarkerEnabled, default: style.currentMarkerEnabled, context: context)
        style.markerColor = nodeColor(chart.markerColor, default: style.markerColor, context: context) ?? style.markerColor
        style.markerSizeMultiplier = nodeNumber(chart.markerSizeMultiplier, default: style.markerSizeMultiplier, context: context)
        style.markerPlayheadLineEnabled = nodeFlag(chart.markerPlayheadLineEnabled, default: style.markerPlayheadLineEnabled, context: context)
        style.markerLabelEnabled = nodeFlag(chart.markerLabelEnabled, default: style.markerLabelEnabled, context: context)
        style.gridEnabled = nodeFlag(chart.gridEnabled, default: style.gridEnabled, context: context)
        style.axisLineEnabled = nodeFlag(chart.axisLineEnabled, default: style.axisLineEnabled, context: context)
        style.axisLabelsEnabled = nodeFlag(chart.axisLabelsEnabled, default: style.axisLabelsEnabled, context: context)
        style.bigNumbersEnabled = nodeFlag(chart.bigNumbersEnabled, default: style.bigNumbersEnabled, context: context)
        style.bigNumberMetric = nodeStringEnum(chart.bigNumberMetric, default: style.bigNumberMetric, context: context)
        style.bigNumberFontSize = nodeNumber(chart.bigNumberFontSize, default: style.bigNumberFontSize, context: context)
        style.bigNumberFontName = chart.bigNumberFontFamily?.evaluate(in: context) ?? style.bigNumberFontName
        style.bigNumberFontWeight = nodeWeight(chart.bigNumberFontWeight, default: style.bigNumberFontWeight, context: context)
        style.backgroundEnabled = nodeFlag(chart.backgroundEnabled, default: style.backgroundEnabled, context: context)
        style.backgroundColor = nodeColor(chart.backgroundColor, default: style.backgroundColor, context: context) ?? style.backgroundColor
        style.backgroundOpacity = nodeNumber(chart.backgroundOpacity, default: style.backgroundOpacity, context: context)
        style.cornerRadius = nodeNumber(chart.cornerRadius, default: style.cornerRadius, context: context)
        style.borderEnabled = nodeFlag(chart.borderEnabled, default: style.borderEnabled, context: context)
        style.borderOpacity = nodeNumber(chart.borderOpacity, default: style.borderOpacity, context: context)
        style.shadowEnabled = nodeFlag(chart.shadowEnabled, default: style.shadowEnabled, context: context)
        style.shadowOpacity = nodeNumber(chart.shadowOpacity, default: style.shadowOpacity, context: context)
        style.shadowRadius = nodeNumber(chart.shadowRadius, default: style.shadowRadius, context: context)
        style.glowEnabled = nodeFlag(chart.glowEnabled, default: style.glowEnabled, context: context)
        style.glowOpacity = nodeNumber(chart.glowOpacity, default: style.glowOpacity, context: context)
        if let statsBar = chart.statsBar {
            applyStatsBar(
                statsBar,
                to: &style.statsBar,
                context: context,
                fallbackFontName: style.statsBar.valueFontName
            )
        }
        let defaultStyle = OverlayStyle.default
        resolved = .elevationChart(
            frame: rect,
            style: style,
            valueFontSize: max(nodeNumber(chart.valueFontSize, default: defaultStyle.fontSize, context: context), 1),
            fontName: chart.fontFamily?.evaluate(in: context) ?? defaultStyle.fontName,
            foregroundColor: nodeColor(chart.foregroundColor, default: defaultStyle.foregroundColor, context: context) ?? defaultStyle.foregroundColor
        )
        return resolved
    }

    @inline(never)
    private func resolveWeatherWidgetNode(
        _ widget: OverlayComponentWeatherWidget, rect: CGRect, path: String,
        context: OverlayComponentEvaluationContext, diagnostics: inout [String]
    ) -> OverlayComponentResolvedNode? {

        let preset = nodeStringEnum(widget.preset, default: WeatherWidgetPreset.simpleCard, context: context)
        var style = WeatherWidgetStyle.preset(preset)
        let dataSource: WeatherDataSource = nodeStringEnum(
        widget.dataSource, default: .openMeteo, context: context
        )
        style.manualCondition = nodeStringEnum(widget.condition, default: style.manualCondition, context: context)
        style.manualTemperatureCelsius = nodeNumber(
        widget.temperatureCelsius, default: style.manualTemperatureCelsius, context: context
        )
        style.manualHumidity = nodeNumber(widget.humidity, default: style.manualHumidity, context: context)
        style.manualHigh = nodeNumber(widget.highCelsius, default: style.manualHigh, context: context)
        style.manualLow = nodeNumber(widget.lowCelsius, default: style.manualLow, context: context)
        style.manualWind = nodeNumber(widget.windKph, default: style.manualWind, context: context)
        style.manualFeelsLike = nodeNumber(
        widget.feelsLikeCelsius, default: style.manualFeelsLike, context: context
        )
        style.temperatureUnit = nodeStringEnum(
        widget.temperatureUnit, default: style.temperatureUnit, context: context
        )
        style.useFITTemperature = nodeFlag(
        widget.useActivityTemperature, default: style.useFITTemperature, context: context
        )
        style.locationText = widget.locationText?.evaluate(in: context) ?? style.locationText
        style.showLocation = nodeFlag(widget.showLocation, default: style.showLocation, context: context)
        style.showWeekday = nodeFlag(widget.showWeekday, default: style.showWeekday, context: context)
        style.showHumidity = nodeFlag(widget.showHumidity, default: style.showHumidity, context: context)
        style.showHighLow = nodeFlag(widget.showHighLow, default: style.showHighLow, context: context)
        style.showWind = nodeFlag(widget.showWind, default: style.showWind, context: context)
        style.showFeelsLike = nodeFlag(widget.showFeelsLike, default: style.showFeelsLike, context: context)
        style.showIcon = nodeFlag(widget.showIcon, default: style.showIcon, context: context)
        style.showConditionLabel = nodeFlag(
        widget.showConditionLabel, default: style.showConditionLabel, context: context
        )
        style.conditionLabelOverride = widget.conditionLabelOverride?.evaluate(in: context)
        ?? style.conditionLabelOverride
        style.humiditySuffix = widget.humiditySuffix?.evaluate(in: context) ?? style.humiditySuffix
        style.humidityMetricLabel = widget.humidityMetricLabel?.evaluate(in: context)
        ?? style.humidityMetricLabel
        style.windMetricLabel = widget.windMetricLabel?.evaluate(in: context) ?? style.windMetricLabel
        style.feelsLikeMetricLabel = widget.feelsLikeMetricLabel?.evaluate(in: context)
        ?? style.feelsLikeMetricLabel
        style.cardBackgroundColor = nodeColor(
        widget.cardBackgroundColor, default: style.cardBackgroundColor, context: context
        ) ?? style.cardBackgroundColor
        style.cardBackgroundOpacity = nodeNumber(
        widget.cardBackgroundOpacity, default: style.cardBackgroundOpacity, context: context
        )
        style.cardCornerRadius = nodeNumber(
        widget.cardCornerRadius, default: style.cardCornerRadius, context: context
        )
        style.dividerEnabled = nodeFlag(widget.dividerEnabled, default: style.dividerEnabled, context: context)
        style.dividerColor = nodeColor(
        widget.dividerColor, default: style.dividerColor, context: context
        ) ?? style.dividerColor
        style.dividerThickness = nodeNumber(
        widget.dividerThickness, default: style.dividerThickness, context: context
        )
        style.dividerOpacity = nodeNumber(
        widget.dividerOpacity, default: style.dividerOpacity, context: context
        )
        style.palette = nodeStringEnum(widget.palette, default: style.palette, context: context)
        style.iconSize = nodeNumber(widget.iconSize, default: style.iconSize, context: context)
        style.slotBackgroundColor = nodeColor(
        widget.slotBackgroundColor, default: style.slotBackgroundColor, context: context
        ) ?? style.slotBackgroundColor
        style.slotBackgroundOpacity = nodeNumber(
        widget.slotBackgroundOpacity, default: style.slotBackgroundOpacity, context: context
        )
        style.slotSpacing = nodeNumber(widget.slotSpacing, default: style.slotSpacing, context: context)

        let family = widget.fontFamily?.evaluate(in: context)
        .trimmingCharacters(in: .whitespacesAndNewlines)
        func textStyle(
        _ base: WeatherTextStyle,
        size: OverlayComponentNumberSource?,
        weight: OverlayComponentStringSource?,
        color: OverlayComponentColorSource?
        ) -> WeatherTextStyle {
        var result = base
        if let family, !family.isEmpty { result.fontName = family }
        result.fontSize = nodeNumber(size, default: result.fontSize, context: context)
        result.fontWeight = nodeWeight(weight, default: result.fontWeight, context: context)
        result.color = nodeColor(color, default: result.color, context: context) ?? result.color
        return result
        }
        style.locationTextStyle = textStyle(
        style.locationTextStyle,
        size: widget.locationFontSize,
        weight: widget.locationFontWeight,
        color: widget.locationColor
        )
        style.conditionTextStyle = textStyle(
        style.conditionTextStyle,
        size: widget.conditionFontSize,
        weight: widget.conditionFontWeight,
        color: widget.conditionColor
        )
        style.temperatureTextStyle = textStyle(
        style.temperatureTextStyle,
        size: widget.temperatureFontSize,
        weight: widget.temperatureFontWeight,
        color: widget.temperatureColor
        )
        style.slotTitleTextStyle = textStyle(
        style.slotTitleTextStyle,
        size: widget.slotTitleFontSize,
        weight: widget.slotTitleFontWeight,
        color: widget.slotTitleColor
        )
        style.slotLabelTextStyle = textStyle(
        style.slotLabelTextStyle,
        size: widget.slotLabelFontSize,
        weight: widget.slotLabelFontWeight,
        color: widget.slotLabelColor
        )

        var slots: [WeatherMetricSlotValue] = []
        if style.showHumidity { slots.append(.humidity) }
        if style.showHighLow { slots.append(.highLow) }
        if style.showWind { slots.append(.wind) }
        if style.showFeelsLike { slots.append(.feelsLike) }
        style.metricSlots = slots.isEmpty ? preset.defaultMetricSlots : slots

        if dataSource.isAPI, let snapshot = context.data?.weatherSnapshot() {
        style.dataSource = dataSource
        style.cachedWeather = snapshot
        } else {
        style.dataSource = .manual
        style.cachedWeather = nil
        }
        return .weatherWidget(frame: rect, style: style)
    }

    @inline(never)
    private func resolveRouteMapNode(_ map: OverlayComponentRouteMap, rect: CGRect, path: String,
        context: OverlayComponentEvaluationContext, diagnostics: inout [String]
    ) -> OverlayComponentResolvedNode? {
        let resolved: OverlayComponentResolvedNode
        
        let defaultStyle = OverlayStyle.default
        var style = defaultStyle
        style.shadowEnabled = false
        style.glowEnabled = false
        style.routeMapShape = nodeStringEnum(map.shape, default: style.routeMapShape, context: context)
        style.routeMapBackgroundStyle = nodeStringEnum(map.backgroundStyle, default: style.routeMapBackgroundStyle, context: context)
        style.routeMapCornerRadius = nodeNumber(map.cornerRadius, default: style.routeMapCornerRadius, context: context)
        style.backgroundRadius = style.routeMapCornerRadius
        style.backgroundOpacity = nodeNumber(map.backgroundOpacity, default: style.backgroundOpacity, context: context)
        style.routeMapStartMarkerStyle = nodeStringEnum(map.startMarkerStyle, default: style.routeMapStartMarkerStyle, context: context)
        style.routeMapEndMarkerStyle = nodeStringEnum(map.endMarkerStyle, default: style.routeMapEndMarkerStyle, context: context)
        style.routeMapRunnerMarkerStyle = nodeStringEnum(map.runnerMarkerStyle, default: style.routeMapRunnerMarkerStyle, context: context)
        style.routeMapStartMarkerColor = nodeColor(map.startMarkerColor, default: style.routeMapStartMarkerColor, context: context) ?? style.routeMapStartMarkerColor
        style.routeMapEndMarkerColor = nodeColor(map.endMarkerColor, default: style.routeMapEndMarkerColor, context: context) ?? style.routeMapEndMarkerColor
        style.routeMapRunnerDotColor = nodeColor(map.runnerMarkerColor, default: style.routeMapRunnerDotColor, context: context) ?? style.routeMapRunnerDotColor
        style.glowEnabled = nodeFlag(map.glowEnabled, default: style.glowEnabled, context: context)
        style.routeMapMapOpacity = nodeNumber(map.mapOpacity, default: style.routeMapMapOpacity, context: context)
        style.borderEnabled = nodeFlag(map.borderEnabled, default: style.borderEnabled, context: context)
        style.borderColor = nodeColor(map.borderColor, default: style.borderColor, context: context) ?? style.borderColor
        style.borderOpacity = nodeNumber(map.borderOpacity, default: style.borderOpacity, context: context)
        style.borderWidth = nodeNumber(map.borderWidth, default: style.borderWidth, context: context)
        style.foregroundColor = nodeColor(map.foregroundColor, default: style.foregroundColor, context: context) ?? style.foregroundColor
        style.fontName = map.fontFamily?.evaluate(in: context) ?? style.fontName
        style.fontSize = nodeNumber(map.fontSize, default: style.fontSize, context: context)
        style.fontWeight = nodeWeight(map.fontWeight, default: style.fontWeight, context: context)
        style.routeMapWidth = max(nodeNumber(map.width, default: style.routeMapWidth, context: context), 1)
        style.routeMapHeight = max(nodeNumber(map.height, default: style.routeMapHeight, context: context), 1)
        let edgeFade = nodeStringEnum(map.edgeFade, default: style.routeMapEdgeFade, context: context)
        style.routeMapEdgeFade = edgeFade
        style.backgroundFadeOutEnabled = edgeFade == .fadeOut
        style.routeMapFadeAmount = nodeNumber(map.fadeAmount, default: style.routeMapFadeAmount, context: context)
        style.backgroundFadeOutAmount = style.routeMapFadeAmount
        style.routeMapColorMode = nodeStringEnum(map.colorMode, default: style.routeMapColorMode, context: context)
        style.routeMapGradientStart = nodeColor(map.gradientStart, default: style.routeMapGradientStart, context: context) ?? style.routeMapGradientStart
        style.routeMapGradientMiddle = nodeColor(map.gradientMiddle, default: style.routeMapGradientMiddle, context: context) ?? style.routeMapGradientMiddle
        style.routeMapGradientEnd = nodeColor(map.gradientEnd, default: style.routeMapGradientEnd, context: context) ?? style.routeMapGradientEnd
        style.routeMapZoom = min(max(nodeNumber(map.zoom, default: style.routeMapZoom, context: context), 0.5), 3)
        style.routeMapShowsPointsOfInterest = nodeFlag(map.showsPointsOfInterest, default: style.routeMapShowsPointsOfInterest, context: context)
        if let statsBar = map.statsBar {
            applyStatsBar(
                statsBar,
                to: &style.routeMapStatsBar,
                context: context,
                fallbackFontName: style.fontName
            )
        }
        resolved = .routeMap(frame: rect, style: style)
        return resolved
    }

    private func applyStatsBar(
        _ bar: OverlayComponentStatsBar,
        to config: inout DistanceTimelineStatsBarConfig,
        context: OverlayComponentEvaluationContext,
        fallbackFontName: String
    ) {
        let placement = nodeStringEnum(bar.placement, default: config.placement, context: context)
        config.placement = placement.attachedDistanceTimelinePlacement
        config.inside = placement.isInside
            || nodeFlag(bar.inside, default: config.inside, context: context)
        config.visible = nodeFlag(bar.visible, default: config.visible, context: context)
        config.layoutMode = nodeStringEnum(bar.layoutMode, default: config.layoutMode, context: context)
        config.width = nodeNumber(bar.width, default: config.width, context: context)
        config.height = nodeNumber(bar.height, default: config.height, context: context)
        config.offsetX = nodeNumber(bar.offsetX, default: config.offsetX, context: context)
        config.offsetY = nodeNumber(bar.offsetY, default: config.offsetY, context: context)
        config.itemSpacing = nodeNumber(bar.itemSpacing, default: config.itemSpacing, context: context)
        config.backgroundOpacity = nodeNumber(bar.backgroundOpacity, default: config.backgroundOpacity, context: context)
        config.dividerOpacity = nodeNumber(bar.dividerOpacity, default: config.dividerOpacity, context: context)
        config.cornerRadius = nodeNumber(bar.cornerRadius, default: config.cornerRadius, context: context)
        config.valueFontName = bar.valueFontFamily?.evaluate(in: context) ?? fallbackFontName
        config.valueFontSize = nodeNumber(bar.valueFontSize, default: config.valueFontSize, context: context)
        config.valueFontWeight = nodeWeight(bar.valueFontWeight, default: config.valueFontWeight, context: context)
        config.valueColor = nodeColor(bar.valueColor, default: config.valueColor, context: context) ?? config.valueColor
        config.labelFontName = bar.labelFontFamily?.evaluate(in: context) ?? fallbackFontName
        config.labelFontSize = nodeNumber(bar.labelFontSize, default: config.labelFontSize, context: context)
        config.labelFontWeight = nodeWeight(bar.labelFontWeight, default: config.labelFontWeight, context: context)
        config.labelColor = nodeColor(bar.labelColor, default: config.labelColor, context: context) ?? config.labelColor
        if let slots = bar.slots {
            while config.slots.count < 4 {
                config.slots.append(DistanceTimelineStatsBarSlot(
                    metric: .distance, visible: false, customLabel: ""
                ))
            }
            for (index, slot) in slots.enumerated() where index < config.slots.count {
                config.slots[index].metric = nodeStringEnum(
                    slot.metric, default: config.slots[index].metric, context: context
                )
                config.slots[index].visible = nodeFlag(
                    slot.visible, default: config.slots[index].visible, context: context
                )
                config.slots[index].customLabel = slot.customLabel?.evaluate(in: context)
                    ?? config.slots[index].customLabel
            }
        }
    }

    private func applyStatsBar(
        _ bar: OverlayComponentStatsBar,
        to config: inout OverlayRouteMapStatsBarConfig,
        context: OverlayComponentEvaluationContext,
        fallbackFontName: String
    ) {
        let placement = nodeStringEnum(bar.placement, default: config.placement, context: context)
        config.placement = placement
        config.inside = placement.isInside
            || nodeFlag(bar.inside, default: config.inside, context: context)
        config.visible = nodeFlag(bar.visible, default: config.visible, context: context)
        config.layoutMode = nodeStringEnum(bar.layoutMode, default: config.layoutMode, context: context)
        config.width = nodeNumber(bar.width, default: config.width, context: context)
        config.height = nodeNumber(bar.height, default: config.height, context: context)
        config.offsetX = nodeNumber(bar.offsetX, default: config.offsetX, context: context)
        config.offsetY = nodeNumber(bar.offsetY, default: config.offsetY, context: context)
        config.itemSpacing = nodeNumber(bar.itemSpacing, default: config.itemSpacing, context: context)
        config.backgroundOpacity = nodeNumber(bar.backgroundOpacity, default: config.backgroundOpacity, context: context)
        config.blurRadius = nodeNumber(bar.blurRadius, default: config.blurRadius, context: context)
        config.dividerOpacity = nodeNumber(bar.dividerOpacity, default: config.dividerOpacity, context: context)
        config.cornerRadius = nodeNumber(bar.cornerRadius, default: config.cornerRadius, context: context)
        config.valueFontName = bar.valueFontFamily?.evaluate(in: context) ?? fallbackFontName
        config.valueFontSize = nodeNumber(bar.valueFontSize, default: config.valueFontSize, context: context)
        config.valueFontWeight = nodeWeight(bar.valueFontWeight, default: config.valueFontWeight, context: context)
        config.valueColor = nodeColor(bar.valueColor, default: config.valueColor, context: context) ?? config.valueColor
        config.labelFontName = bar.labelFontFamily?.evaluate(in: context) ?? fallbackFontName
        config.labelFontSize = nodeNumber(bar.labelFontSize, default: config.labelFontSize, context: context)
        config.labelFontWeight = nodeWeight(bar.labelFontWeight, default: config.labelFontWeight, context: context)
        config.labelColor = nodeColor(bar.labelColor, default: config.labelColor, context: context) ?? config.labelColor
        if let slots = bar.slots {
            while config.slots.count < 4 {
                config.slots.append(RouteMapStatsBarSlot(
                    metric: .distance, visible: false, customLabel: ""
                ))
            }
            for (index, slot) in slots.enumerated() where index < config.slots.count {
                config.slots[index].metric = nodeStringEnum(
                    slot.metric, default: config.slots[index].metric, context: context
                )
                config.slots[index].visible = nodeFlag(
                    slot.visible, default: config.slots[index].visible, context: context
                )
                config.slots[index].customLabel = slot.customLabel?.evaluate(in: context)
                    ?? config.slots[index].customLabel
            }
        }
    }

    private func resolvePathCommand(
        _ command: OverlayComponentPathCommand,
        context: OverlayComponentEvaluationContext
    ) -> OverlayComponentResolvedPathCommand? {
        func value(_ source: OverlayComponentNumberSource) -> Double? {
            source.evaluate(in: context)
        }
        switch command {
        case .move(let x, let y):
            guard let x = value(x), let y = value(y) else { return nil }
            return .move(x, y)
        case .line(let x, let y):
            guard let x = value(x), let y = value(y) else { return nil }
            return .line(x, y)
        case .quad(let cx, let cy, let x, let y):
            guard let cx = value(cx), let cy = value(cy),
                  let x = value(x), let y = value(y) else { return nil }
            return .quad(cx, cy, x, y)
        case .cubic(let c1x, let c1y, let c2x, let c2y, let x, let y):
            guard let c1x = value(c1x), let c1y = value(c1y),
                  let c2x = value(c2x), let c2y = value(c2y),
                  let x = value(x), let y = value(y) else { return nil }
            return .cubic(c1x, c1y, c2x, c2y, x, y)
        case .arc(let cx, let cy, let radius, let start, let sweep):
            guard let cx = value(cx), let cy = value(cy), let radius = value(radius),
                  let start = value(start), let sweep = value(sweep) else { return nil }
            return .arc(cx, cy, radius, start, sweep)
        case .close:
            return .close
        }
    }
}
