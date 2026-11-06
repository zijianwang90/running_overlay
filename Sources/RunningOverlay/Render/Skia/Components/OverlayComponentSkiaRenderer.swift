#if canImport(CSkiaBridge)
import AppKit
import CoreText
import CSkiaBridge
import Foundation

/// Draws a resolved declarative component through the shared Skia bridge.
///
/// The component tree is resolved once per frame against the same activity
/// data the native modules consume. All coordinates are design units; the
/// renderer maps them into canvas pixels, clips to the component rectangle and
/// never lets a node paint outside it.
enum OverlayComponentSkiaRenderer {
    static func draw(
        _ element: OverlayElement,
        renderContext: OverlayRenderContext,
        context: OpaquePointer
    ) {
        guard let instance = element.component else { return }
        let scale = element.scale * renderContext.canvasScale
        let data = OverlayComponentActivityData(
            activity: renderContext.activity,
            elapsedTime: renderContext.elapsedTime,
            zoneSnapshot: HeartRateZonePreferences.currentSnapshot(),
            canvasSize: renderContext.canvasSize,
            elementScale: scale
        )
        guard let resolved = OverlayComponentRegistry.resolve(instance: instance, data: data) else {
            return
        }

        let space = DrawSpace(
            origin: CGPoint(
                x: renderContext.canvasSize.width * element.position.x,
                y: renderContext.canvasSize.height * element.position.y
            ),
            scale: scale
        )
        let bounds = CGRect(
            origin: space.origin,
            size: CGSize(
                width: resolved.size.width * scale,
                height: resolved.size.height * scale
            )
        )

        skb_save(context)
        skb_clip_rect(context, Float(bounds.minX), Float(bounds.minY), Float(bounds.width), Float(bounds.height))
        if element.opacity < 0.999 {
            skb_begin_opacity_layer(
                context,
                Float(element.opacity),
                Float(bounds.minX),
                Float(bounds.minY),
                Float(bounds.width),
                Float(bounds.height)
            )
        }
        if let background = resolved.background {
            let radius = background.radius * scale
            skb_fill_round_rect(
                context,
                Float(bounds.minX),
                Float(bounds.minY),
                Float(bounds.width),
                Float(bounds.height),
                Float(radius),
                Float(background.color.red),
                Float(background.color.green),
                Float(background.color.blue),
                Float(background.color.alpha)
            )
        }
        let assets = OverlayComponentRegistry.assets(for: instance.reference)
        for node in resolved.nodes {
            draw(
                node,
                context: context,
                space: space,
                opacity: element.opacity,
                assets: assets
            )
        }
        if element.opacity < 0.999 {
            skb_restore(context)
        }
        skb_restore(context)
    }

    // MARK: - Draw space

    private struct DrawSpace {
        var origin: CGPoint
        var scale: Double

        func point(_ point: CGPoint) -> CGPoint {
            CGPoint(x: origin.x + point.x * scale, y: origin.y + point.y * scale)
        }

        func rect(_ rect: CGRect) -> CGRect {
            CGRect(
                x: origin.x + rect.minX * scale,
                y: origin.y + rect.minY * scale,
                width: rect.width * scale,
                height: rect.height * scale
            )
        }

        func length(_ value: Double) -> Double {
            value * scale
        }
    }

    // MARK: - Node dispatch

    private static func draw(
        _ node: OverlayComponentResolvedNode,
        context: OpaquePointer,
        space: DrawSpace,
        opacity: Double,
        assets: [String: Data]
    ) {
        guard opacity > 0.001 else { return }
        switch node {
        case let .group(frame, groupOpacity, clip, shadow, children):
            let rect = space.rect(frame)
            var restoreCount = 0
            if clip {
                skb_save(context)
                skb_clip_rect(
                    context,
                    Float(rect.minX),
                    Float(rect.minY),
                    Float(rect.width),
                    Float(rect.height)
                )
                restoreCount += 1
            }
            if let shadow {
                skb_begin_shadow_layer(
                    context,
                    Float(space.length(shadow.sigma)),
                    Float(space.length(shadow.dx)),
                    Float(space.length(shadow.dy)),
                    Float(rect.minX),
                    Float(rect.minY),
                    Float(rect.width),
                    Float(rect.height),
                    Float(shadow.color.red),
                    Float(shadow.color.green),
                    Float(shadow.color.blue),
                    Float(shadow.color.alpha * opacity)
                )
                restoreCount += 1
            }
            if groupOpacity < 0.999 {
                skb_begin_opacity_layer(
                    context,
                    Float(groupOpacity),
                    Float(rect.minX),
                    Float(rect.minY),
                    Float(rect.width),
                    Float(rect.height)
                )
                restoreCount += 1
            }
            for child in children {
                draw(child, context: context, space: space, opacity: opacity, assets: assets)
            }
            for _ in 0..<restoreCount {
                skb_restore(context)
            }

        case let .opacity(nodeOpacity, content):
            let rect = space.rect(nodeBounds(content))
            skb_begin_opacity_layer(
                context,
                Float(nodeOpacity),
                Float(rect.minX),
                Float(rect.minY),
                Float(rect.width),
                Float(rect.height)
            )
            draw(content, context: context, space: space, opacity: opacity, assets: assets)
            skb_restore(context)

        case let .rect(frame, fill, radius, stroke, strokeWidth):
            let rect = space.rect(frame)
            let scaledRadius = space.length(radius)
            skb_fill_round_rect(
                context,
                Float(rect.minX),
                Float(rect.minY),
                Float(rect.width),
                Float(rect.height),
                Float(scaledRadius),
                Float(fill.red), Float(fill.green), Float(fill.blue), Float(fill.alpha * opacity)
            )
            if let stroke, strokeWidth > 0 {
                skb_stroke_round_rect(
                    context,
                    Float(rect.minX),
                    Float(rect.minY),
                    Float(rect.width),
                    Float(rect.height),
                    Float(scaledRadius),
                    Float(space.length(strokeWidth)),
                    Float(stroke.red), Float(stroke.green), Float(stroke.blue), Float(stroke.alpha * opacity)
                )
            }

        case let .circle(center, radius, fill, stroke, strokeWidth):
            let point = space.point(center)
            let scaledRadius = space.length(radius)
            if let fill {
                skb_fill_circle(
                    context,
                    Float(point.x), Float(point.y), Float(scaledRadius),
                    Float(fill.red), Float(fill.green), Float(fill.blue), Float(fill.alpha * opacity)
                )
            }
            if let stroke, strokeWidth > 0 {
                withPath(context: context) { path in
                    skb_path_add_arc(
                        path,
                        Float(point.x), Float(point.y), Float(scaledRadius),
                        0, 360, 1
                    )
                    drawStroke(
                        path,
                        context: context,
                        color: stroke,
                        width: space.length(strokeWidth),
                        cap: .round,
                        join: .round,
                        dash: nil,
                        opacity: opacity
                    )
                }
            }

        case let .line(from, to, width, color, cap):
            withPath(context: context) { path in
                let start = space.point(from)
                let end = space.point(to)
                skb_path_move_to(path, Float(start.x), Float(start.y))
                skb_path_line_to(path, Float(end.x), Float(end.y))
                drawStroke(
                    path,
                    context: context,
                    color: color,
                    width: space.length(width),
                    cap: cap,
                    join: .miter,
                    dash: nil,
                    opacity: opacity
                )
            }

        case let .polyline(points, width, color, cap, join, dash):
            guard points.count >= 2 else { return }
            withPath(context: context) { path in
                let mapped = points.map(space.point)
                skb_path_move_to(path, Float(mapped[0].x), Float(mapped[0].y))
                for point in mapped.dropFirst() {
                    skb_path_line_to(path, Float(point.x), Float(point.y))
                }
                drawStroke(
                    path,
                    context: context,
                    color: color,
                    width: space.length(width),
                    cap: cap,
                    join: join,
                    dash: dash.map { $0.map(space.length) },
                    opacity: opacity
                )
            }

        case let .path(commands, fill, stroke, strokeWidth, cap, join, dash):
            withPath(context: context) { path in
                build(path, commands: commands, space: space)
                if let fill {
                    drawFill(path, context: context, color: fill, opacity: opacity)
                }
                if let stroke, strokeWidth > 0 {
                    drawStroke(
                        path,
                        context: context,
                        color: stroke,
                        width: space.length(strokeWidth),
                        cap: cap,
                        join: join,
                        dash: dash.map { $0.map(space.length) },
                        opacity: opacity
                    )
                }
            }

        case let .text(frame, text, font, color, align, verticalAlign, maxWidth, lineHeight):
            drawText(
                text,
                frame: frame,
                font: font,
                color: color,
                align: align,
                verticalAlign: verticalAlign,
                maxWidth: maxWidth,
                lineHeight: lineHeight,
                context: context,
                space: space,
                opacity: opacity
            )

        case let .image(frame, asset, fit):
            OverlayComponentImageCache.draw(
                assetPath: asset,
                assets: assets,
                rect: space.rect(frame),
                fit: fit,
                opacity: opacity,
                context: context
            )

        case let .gradientRect(frame, stops, from, to, radius):
            guard let first = stops.first?.color, let last = stops.last?.color else { return }
            let rect = space.rect(frame)
            let start = space.point(from)
            let end = space.point(to)
            if stops.count > 2 || radius > 0 {
                withPath(context: context) { path in
                    addRoundedRect(path, rect: rect, radius: space.length(radius))
                    var interleaved: [Float] = []
                    interleaved.reserveCapacity(stops.count * 5)
                    for stop in stops {
                        interleaved.append(Float(stop.offset))
                        interleaved.append(Float(stop.color.red))
                        interleaved.append(Float(stop.color.green))
                        interleaved.append(Float(stop.color.blue))
                        interleaved.append(Float(stop.color.alpha * opacity))
                    }
                    interleaved.withUnsafeBufferPointer { values in
                        skb_draw_path_gradient(
                            context,
                            path,
                            1, 0, 0, 0,
                            values.baseAddress,
                            Int32(stops.count),
                            Float(start.x), Float(start.y),
                            Float(end.x), Float(end.y)
                        )
                    }
                }
            } else {
                skb_fill_linear_gradient_rect(
                    context,
                    Float(rect.minX), Float(rect.minY), Float(rect.width), Float(rect.height),
                    Float(start.x), Float(start.y), Float(end.x), Float(end.y),
                    Float(first.red), Float(first.green), Float(first.blue), Float(first.alpha * opacity),
                    Float(last.red), Float(last.green), Float(last.blue), Float(last.alpha * opacity)
                )
            }

        case let .sparkline(frame, values, stroke, lineWidth, fill, smoothing):
            drawSparkline(
                frame: frame,
                values: values,
                stroke: stroke,
                lineWidth: lineWidth,
                fill: fill,
                smoothing: smoothing,
                context: context,
                space: space,
                opacity: opacity
            )

        case let .progressBar(frame, value, trackColor, fillColor, radius):
            let rect = space.rect(frame)
            let scaledRadius = space.length(radius)
            skb_fill_round_rect(
                context,
                Float(rect.minX), Float(rect.minY), Float(rect.width), Float(rect.height),
                Float(scaledRadius),
                Float(trackColor.red), Float(trackColor.green), Float(trackColor.blue), Float(trackColor.alpha * opacity)
            )
            let fillWidth = rect.width * value
            if fillWidth > 0 {
                skb_fill_round_rect(
                    context,
                    Float(rect.minX), Float(rect.minY), Float(fillWidth), Float(rect.height),
                    Float(min(scaledRadius, fillWidth / 2)),
                    Float(fillColor.red), Float(fillColor.green), Float(fillColor.blue), Float(fillColor.alpha * opacity)
                )
            }

        case let .arc(frame, value, startDegrees, sweepDegrees, radius, width, trackColor, fillColor, cap):
            let center = space.point(CGPoint(x: frame.midX, y: frame.midY))
            let scaledRadius = space.length(radius)
            let scaledWidth = space.length(width)
            if let trackColor {
                withPath(context: context) { path in
                    skb_path_add_arc(
                        path,
                        Float(center.x), Float(center.y), Float(scaledRadius),
                        Float(startDegrees), Float(sweepDegrees), 1
                    )
                    drawStroke(
                        path,
                        context: context,
                        color: trackColor,
                        width: scaledWidth,
                        cap: cap,
                        join: .round,
                        dash: nil,
                        opacity: opacity
                    )
                }
            }
            if value > 0 {
                withPath(context: context) { path in
                    skb_path_add_arc(
                        path,
                        Float(center.x), Float(center.y), Float(scaledRadius),
                        Float(startDegrees), Float(sweepDegrees * value), 1
                    )
                    drawStroke(
                        path,
                        context: context,
                        color: fillColor,
                        width: scaledWidth,
                        cap: cap,
                        join: .round,
                        dash: nil,
                        opacity: opacity
                    )
                }
            }
        }
    }

    // MARK: - Text

    private static func drawText(
        _ text: String,
        frame: CGRect,
        font: OverlayComponentResolvedFont,
        color: OverlayColor,
        align: OverlayComponentTextAlignment,
        verticalAlign: OverlayComponentVerticalAlignment,
        maxWidth: Double?,
        lineHeight: Double,
        context: OpaquePointer,
        space: DrawSpace,
        opacity: Double
    ) {
        guard !text.isEmpty else { return }
        let rect = space.rect(frame)
        let nsFont = SkiaTextComposer.font(
            family: resolvedFamily(font.family),
            size: font.size * space.scale,
            weight: font.weight.appKitWeight
        )
        let limit = maxWidth.map(space.length)
        let lines = makeLines(text, font: nsFont, maxWidth: limit)
        guard !lines.isEmpty else { return }

        let lineHeightPixels = max(font.size * space.scale * lineHeight, lines[0].height)
        let totalHeight = lineHeightPixels * Double(lines.count - 1) + lines[0].height
        let top: Double
        switch verticalAlign {
        case .top: top = rect.minY
        case .center: top = rect.minY + (rect.height - totalHeight) / 2
        case .bottom: top = rect.maxY - totalHeight
        }

        for (index, line) in lines.enumerated() {
            let x: Double
            switch align {
            case .left: x = rect.minX
            case .center: x = rect.minX + (rect.width - line.width) / 2
            case .right: x = rect.maxX - line.width
            }
            let y = top + lineHeightPixels * Double(index)
            SkiaTextComposer.draw(
                line,
                context: context,
                x: x,
                baselineY: y + line.ascent,
                color: color,
                opacity: opacity
            )
        }
    }

    private static func makeLines(_ text: String, font: NSFont, maxWidth: Double?) -> [SkiaTextLine] {
        let paragraphs = text.components(separatedBy: "\n").prefix(8)
        var lines: [SkiaTextLine] = []
        for paragraph in paragraphs {
            guard let maxWidth, maxWidth > 0 else {
                lines.append(SkiaTextComposer.makeLine(paragraph, font: font))
                continue
            }
            var current = ""
            for word in paragraph.split(separator: " ", omittingEmptySubsequences: false) {
                let candidate = current.isEmpty ? String(word) : current + " " + word
                let line = SkiaTextComposer.makeLine(candidate, font: font)
                if line.width > maxWidth, !current.isEmpty {
                    lines.append(SkiaTextComposer.makeLine(current, font: font))
                    current = String(word)
                } else {
                    current = candidate
                }
            }
            lines.append(SkiaTextComposer.makeLine(current, font: font))
        }
        return lines
    }

    private static func resolvedFamily(_ family: String) -> String {
        switch family {
        case "system-rounded": "SF Pro Rounded"
        case "system-monospaced": "SF Mono"
        default: family
        }
    }

    // MARK: - Sparkline

    private static func drawSparkline(
        frame: CGRect,
        values: [Double?],
        stroke: OverlayColor,
        lineWidth: Double,
        fill: OverlayColor?,
        smoothing: OverlayComponentSmoothing,
        context: OpaquePointer,
        space: DrawSpace,
        opacity: Double
    ) {
        let numbers = values.compactMap { $0 }.filter(\.isFinite)
        guard numbers.count >= 2 else { return }
        let rect = space.rect(frame)
        let minimum = numbers.min() ?? 0
        let maximum = numbers.max() ?? 0
        let span = maximum - minimum
        let points: [CGPoint] = values.enumerated().compactMap { index, value in
            guard let value, value.isFinite else { return nil }
            let x = rect.minX + rect.width * Double(index) / Double(max(values.count - 1, 1))
            let normalized = span > 0.000_001 ? (value - minimum) / span : 0.5
            let y = rect.maxY - rect.height * normalized
            return CGPoint(x: x, y: y)
        }
        guard points.count >= 2 else { return }

        withPath(context: context) { path in
            if let fill {
                skb_path_move_to(path, Float(points[0].x), Float(rect.maxY))
                skb_path_line_to(path, Float(points[0].x), Float(points[0].y))
                addPolyline(path, points: points, smoothing: smoothing, startsAtOrigin: true)
                skb_path_line_to(path, Float(points[points.count - 1].x), Float(rect.maxY))
                skb_path_close(path)
                drawFill(path, context: context, color: fill, opacity: opacity)
            }
        }
        withPath(context: context) { path in
            addPolyline(path, points: points, smoothing: smoothing, startsAtOrigin: false)
            drawStroke(
                path,
                context: context,
                color: stroke,
                width: space.length(lineWidth),
                cap: .round,
                join: .round,
                dash: nil,
                opacity: opacity
            )
        }
    }

    private static func addPolyline(
        _ path: OpaquePointer,
        points: [CGPoint],
        smoothing: OverlayComponentSmoothing,
        startsAtOrigin: Bool
    ) {
        if !startsAtOrigin {
            skb_path_move_to(path, Float(points[0].x), Float(points[0].y))
        }
        switch smoothing {
        case .none:
            for point in points.dropFirst() {
                skb_path_line_to(path, Float(point.x), Float(point.y))
            }
        case .monotone:
            // Catmull-Rom to cubic. Endpoints duplicate so the curve reaches
            // the first and last sample.
            for index in 1..<points.count {
                let p0 = points[max(index - 2, 0)]
                let p1 = points[index - 1]
                let p2 = points[index]
                let p3 = points[min(index + 1, points.count - 1)]
                let c1 = CGPoint(
                    x: p1.x + (p2.x - p0.x) / 6,
                    y: p1.y + (p2.y - p0.y) / 6
                )
                let c2 = CGPoint(
                    x: p2.x - (p3.x - p1.x) / 6,
                    y: p2.y - (p3.y - p1.y) / 6
                )
                skb_path_cubic_to(
                    path,
                    Float(c1.x), Float(c1.y),
                    Float(c2.x), Float(c2.y),
                    Float(p2.x), Float(p2.y)
                )
            }
        }
    }

    // MARK: - Path helpers

    private static func withPath(context: OpaquePointer, _ body: (OpaquePointer) -> Void) {
        guard let path = skb_path_create() else { return }
        body(path)
        skb_path_destroy(path)
    }

    private static func build(
        _ path: OpaquePointer,
        commands: [OverlayComponentResolvedPathCommand],
        space: DrawSpace
    ) {
        for command in commands {
            switch command {
            case let .move(x, y):
                let point = space.point(CGPoint(x: x, y: y))
                skb_path_move_to(path, Float(point.x), Float(point.y))
            case let .line(x, y):
                let point = space.point(CGPoint(x: x, y: y))
                skb_path_line_to(path, Float(point.x), Float(point.y))
            case let .quad(cx, cy, x, y):
                let control = space.point(CGPoint(x: cx, y: cy))
                let point = space.point(CGPoint(x: x, y: y))
                skb_path_quad_to(
                    path,
                    Float(control.x), Float(control.y),
                    Float(point.x), Float(point.y)
                )
            case let .cubic(c1x, c1y, c2x, c2y, x, y):
                let c1 = space.point(CGPoint(x: c1x, y: c1y))
                let c2 = space.point(CGPoint(x: c2x, y: c2y))
                let point = space.point(CGPoint(x: x, y: y))
                skb_path_cubic_to(
                    path,
                    Float(c1.x), Float(c1.y),
                    Float(c2.x), Float(c2.y),
                    Float(point.x), Float(point.y)
                )
            case let .arc(cx, cy, radius, start, sweep):
                let center = space.point(CGPoint(x: cx, y: cy))
                skb_path_add_arc(
                    path,
                    Float(center.x), Float(center.y), Float(space.length(radius)),
                    Float(start), Float(sweep), 0
                )
            case .close:
                skb_path_close(path)
            }
        }
    }

    private static func addRoundedRect(_ path: OpaquePointer, rect: CGRect, radius: Double) {
        let r = min(max(radius, 0), min(rect.width, rect.height) / 2)
        guard r > 0.01 else {
            skb_path_move_to(path, Float(rect.minX), Float(rect.minY))
            skb_path_line_to(path, Float(rect.maxX), Float(rect.minY))
            skb_path_line_to(path, Float(rect.maxX), Float(rect.maxY))
            skb_path_line_to(path, Float(rect.minX), Float(rect.maxY))
            skb_path_close(path)
            return
        }
        skb_path_move_to(path, Float(rect.minX + r), Float(rect.minY))
        skb_path_line_to(path, Float(rect.maxX - r), Float(rect.minY))
        skb_path_add_arc(path, Float(rect.maxX - r), Float(rect.minY + r), Float(r), -90, 90, 0)
        skb_path_line_to(path, Float(rect.maxX), Float(rect.maxY - r))
        skb_path_add_arc(path, Float(rect.maxX - r), Float(rect.maxY - r), Float(r), 0, 90, 0)
        skb_path_line_to(path, Float(rect.minX + r), Float(rect.maxY))
        skb_path_add_arc(path, Float(rect.minX + r), Float(rect.maxY - r), Float(r), 90, 90, 0)
        skb_path_line_to(path, Float(rect.minX), Float(rect.minY + r))
        skb_path_add_arc(path, Float(rect.minX + r), Float(rect.minY + r), Float(r), 180, 90, 0)
        skb_path_close(path)
    }

    private static func drawFill(
        _ path: OpaquePointer,
        context: OpaquePointer,
        color: OverlayColor,
        opacity: Double
    ) {
        skb_draw_path(
            context,
            path,
            1,
            Float(color.red), Float(color.green), Float(color.blue), Float(color.alpha * opacity),
            0, 0, 0, 0, 0
        )
    }

    private static func drawStroke(
        _ path: OpaquePointer,
        context: OpaquePointer,
        color: OverlayColor,
        width: Double,
        cap: OverlayComponentLineCap,
        join: OverlayComponentLineJoin,
        dash: [Double]?,
        opacity: Double
    ) {
        let dashLength = dash?.first ?? 0
        let dashGap = dash?.dropFirst().first ?? 0
        skb_draw_path(
            context,
            path,
            0,
            Float(color.red), Float(color.green), Float(color.blue), Float(color.alpha * opacity),
            Float(width), cap.skiaValue, join.skiaValue,
            Float(max(dashLength, 0)), Float(max(dashGap, 0))
        )
    }

    // MARK: - Bounds

    private static func nodeBounds(_ node: OverlayComponentResolvedNode) -> CGRect {
        switch node {
        case let .group(frame, _, _, _, _): frame
        case let .opacity(_, node): nodeBounds(node)
        case let .rect(frame, _, _, _, _): frame
        case let .circle(center, radius, _, _, _):
            CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        case let .line(from, to, width, _, _):
            CGRect(
                x: min(from.x, to.x) - width,
                y: min(from.y, to.y) - width,
                width: abs(to.x - from.x) + width * 2,
                height: abs(to.y - from.y) + width * 2
            )
        case let .polyline(points, width, _, _, _, _):
            boundingBox(points: points, padding: width)
        case let .path(_, _, _, _, _, _, _):
            CGRect(x: -32768, y: -32768, width: 65536, height: 65536)
        case let .text(frame, _, _, _, _, _, _, _): frame
        case let .image(frame, _, _): frame
        case let .gradientRect(frame, _, _, _, _): frame
        case let .sparkline(frame, _, _, _, _, _): frame
        case let .progressBar(frame, _, _, _, _): frame
        case let .arc(frame, _, _, _, _, _, _, _, _): frame
        }
    }

    private static func boundingBox(points: [CGPoint], padding: Double) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x
        var minY = first.y
        var maxX = first.x
        var maxY = first.y
        for point in points.dropFirst() {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }
        return CGRect(
            x: minX - padding,
            y: minY - padding,
            width: maxX - minX + padding * 2,
            height: maxY - minY + padding * 2
        )
    }
}

private extension OverlayComponentFontWeight {
    var appKitWeight: NSFont.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }
}

private extension OverlayComponentLineCap {
    var skiaValue: Int32 {
        switch self {
        case .butt: 0
        case .round: 1
        case .square: 2
        }
    }
}

private extension OverlayComponentLineJoin {
    var skiaValue: Int32 {
        switch self {
        case .miter: 0
        case .round: 1
        case .bevel: 2
        }
    }
}
#endif
