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

struct OverlayComponentResolvedShadow: Equatable {
    var sigma: Double
    var dx: Double
    var dy: Double
    var color: OverlayColor
}

enum OverlayComponentResolvedPathCommand: Equatable {
    case move(Double, Double)
    case line(Double, Double)
    case quad(Double, Double, Double, Double)
    case cubic(Double, Double, Double, Double, Double, Double)
    case arc(Double, Double, Double, Double, Double)
    case close
}

indirect enum OverlayComponentResolvedNode: Equatable {
    case group(
        frame: CGRect,
        opacity: Double,
        clip: Bool,
        shadow: OverlayComponentResolvedShadow?,
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
    case symbol(
        frame: CGRect,
        name: String,
        color: OverlayColor,
        weight: OverlayComponentFontWeight
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
        for (name, binding) in definition.bindings {
            switch binding {
            case .signal(let path):
                bindings[name] = data.signal(path: path)
            case .series(let path, let window, let samples):
                bindings[name] = data.series(path: path, window: window, samples: samples)
            case .list(let path):
                bindings[name] = data.list(path: path)
            }
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
                result.append(OverlayComponentResolvedStackChild(node: resolved, alignSelf: node.alignSelf))
            }
        }
        return result
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

        let resolved: OverlayComponentResolvedNode
        switch node.kind {
        case .group(let children, let clip, let shadow):
            let groupFrame = frame(required: false)
                ?? CGRect(origin: .zero, size: CGSize(width: CGFloat(definition.size.width), height: CGFloat(definition.size.height)))
            let resolvedShadow = shadow.flatMap { shadow -> OverlayComponentResolvedShadow? in
                guard let color = shadow.color.evaluate(in: context) else { return nil }
                return OverlayComponentResolvedShadow(
                    sigma: number(shadow.sigma, default: 0),
                    dx: number(shadow.dx, default: 0),
                    dy: number(shadow.dy, default: 0),
                    color: color
                )
            }
            resolved = .group(
                frame: groupFrame,
                opacity: opacity,
                clip: clip,
                shadow: resolvedShadow,
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
                direction: direction,
                spacing: max(number(spacing, default: 0), 0),
                crossAlign: crossAlign,
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
            resolved = .text(
                frame: resolvedFrame ?? .zero,
                text: text.evaluate(in: context),
                font: OverlayComponentResolvedFont(
                    family: font.family,
                    size: size,
                    weight: font.weight
                ),
                color: resolvedColor,
                align: align,
                verticalAlign: verticalAlign,
                maxWidth: maxWidth?.evaluate(in: context),
                lineHeight: max(lineHeight?.evaluate(in: context) ?? 1.2, 0.5),
                tracking: tracking?.evaluate(in: context) ?? 0,
                autoSize: resolvedFrame == nil
            )

        case .image(let asset, let fit):
            guard let rect = frame() else { return nil }
            resolved = .image(frame: rect, asset: asset, fit: fit)

        case .symbol(let name, let symbolColor, let weight):
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
            resolved = .symbol(frame: rect, name: resolvedName, color: resolvedColor, weight: weight)

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
                shadow: nil,
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
