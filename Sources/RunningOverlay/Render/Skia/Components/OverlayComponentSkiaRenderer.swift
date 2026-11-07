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
        guard let instance = element.component,
              let placement = placement(for: element, renderContext: renderContext) else {
            return
        }
        let resolved = placement.resolved
        let space = placement.space
        let bounds = placement.bounds
        let clip = placement.clip

        // Element-level styling (opacity, glow, drop shadow) is host state, not
        // part of a component definition. Apply it once around the whole
        // component so a ported built-in keeps the same Inspector effects as
        // the native module it replaces.
        SkiaTextEffects.withElementLayers(element: element, bounds: bounds, context: context) {
            skb_save(context)
            skb_clip_rect(context, Float(clip.minX), Float(clip.minY), Float(clip.width), Float(clip.height))
            if let background = resolved.background {
                let radius = background.radius * space.scale
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
            // Element opacity is handled by the host layer above; passing it
            // into individual nodes would apply it twice and double-blend
            // overlapping shapes.
            for node in resolved.nodes {
                draw(
                    node,
                    context: context,
                    space: space,
                    opacity: 1,
                    assets: assets
                )
            }
            skb_restore(context)
        }
    }

    /// Canvas-pixel frame of a component instance at the render context's
    /// playhead. Content-sized components measure their content, so the frame
    /// follows the current values; hit testing and selection use this.
    static func frame(
        for element: OverlayElement,
        renderContext: OverlayRenderContext
    ) -> CGRect? {
        placement(for: element, renderContext: renderContext)?.bounds
    }

    // MARK: - Placement

    /// Glyph ink can overhang the typographic box (negative tracking, italic
    /// shapes). A content-sized component has no author-chosen slack around
    /// its measured bounds, so its clip grows by this many design units.
    static let contentInkMargin = 16.0

    private struct Placement {
        var resolved: OverlayComponentResolved
        /// Space whose origin is the content origin (inside any padding).
        var space: DrawSpace
        /// Element frame: background rect and host layer bounds.
        var bounds: CGRect
        var clip: CGRect
    }

    private static func placement(
        for element: OverlayElement,
        renderContext: OverlayRenderContext
    ) -> Placement? {
        guard let instance = element.component else { return nil }
        let scale = element.scale * renderContext.canvasScale
        let data = OverlayComponentActivityData(
            activity: renderContext.activity,
            elapsedTime: renderContext.elapsedTime,
            zoneSnapshot: HeartRateZonePreferences.currentSnapshot(),
            canvasSize: renderContext.canvasSize,
            elementScale: scale
        )
        guard let resolved = OverlayComponentRegistry.resolve(instance: instance, data: data) else {
            return nil
        }
        let origin = CGPoint(
            x: renderContext.canvasSize.width * element.position.x,
            y: renderContext.canvasSize.height * element.position.y
        )

        guard let layout = resolved.contentLayout else {
            let bounds = CGRect(
                origin: origin,
                size: CGSize(
                    width: resolved.size.width * scale,
                    height: resolved.size.height * scale
                )
            )
            return Placement(
                resolved: resolved,
                space: DrawSpace(origin: origin, scale: scale),
                bounds: bounds,
                clip: bounds
            )
        }

        // Content size is measured in pixel space, like stacks, then padded.
        // Content keeps its top-leading origin when a minimum size is larger.
        let padX = layout.paddingX * scale
        let padY = layout.paddingY * scale
        let space = DrawSpace(
            origin: CGPoint(x: origin.x + padX, y: origin.y + padY),
            scale: scale
        )
        var extent = CGSize.zero
        for node in resolved.nodes {
            let rect = pixelBounds(node, space: space)
            extent.width = max(extent.width, rect.maxX - space.origin.x)
            extent.height = max(extent.height, rect.maxY - space.origin.y)
        }
        let innerWidth = max(extent.width, layout.minWidth * scale)
        let innerHeight = max(extent.height, layout.minHeight * scale)
        let bounds = CGRect(
            x: origin.x,
            y: origin.y,
            width: innerWidth + padX * 2,
            height: innerHeight + padY * 2
        )
        let margin = contentInkMargin * scale
        return Placement(
            resolved: resolved,
            space: space,
            bounds: bounds,
            clip: bounds.insetBy(dx: -margin, dy: -margin)
        )
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

        case let .stack(frame, direction, spacing, crossAlign, children):
            drawStack(
                frame: frame,
                direction: direction,
                spacing: spacing,
                crossAlign: crossAlign,
                children: children,
                context: context,
                space: space,
                opacity: opacity,
                assets: assets
            )

        case let .opacity(nodeOpacity, content):
            let rect = pixelBounds(content, space: space)
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

        case let .text(frame, text, font, color, align, verticalAlign, maxWidth, lineHeight, tracking, autoSize):
            let drawFrame: CGRect
            if autoSize {
                let size = intrinsicTextSize(
                    text: text,
                    font: font,
                    maxWidth: maxWidth,
                    lineHeight: lineHeight,
                    tracking: tracking,
                    space: space
                )
                drawFrame = CGRect(
                    origin: frame.origin,
                    size: CGSize(
                        width: size.width / space.scale,
                        height: size.height / space.scale
                    )
                )
            } else {
                drawFrame = frame
            }
            drawText(
                text,
                frame: drawFrame,
                font: font,
                color: color,
                align: align,
                verticalAlign: verticalAlign,
                maxWidth: maxWidth,
                lineHeight: lineHeight,
                tracking: tracking,
                context: context,
                space: space,
                opacity: opacity
            )

        case let .symbol(frame, name, color, weight):
            // Square glyph box centered in the frame; the point size follows
            // the box edge, matching native numeric overlay icons.
            let rect = space.rect(frame)
            let side = min(rect.width, rect.height)
            SkiaIconRasterCache.draw(
                systemName: name,
                rect: CGRect(
                    x: rect.midX - side / 2,
                    y: rect.midY - side / 2,
                    width: side,
                    height: side
                ),
                color: color,
                opacity: opacity,
                weight: weight.appKitWeight,
                context: context
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

    // MARK: - Stack layout

    /// Stack layout runs at draw time in pixel space because CoreText advances
    /// are not linear in font size: measuring at design size and scaling the
    /// result drifts from measuring at the final pixel size.
    private struct StackLayout {
        var bounds: CGRect
        var placements: [(node: OverlayComponentResolvedNode, origin: CGPoint)]
    }

    private static func drawStack(
        frame: CGRect?,
        direction: OverlayComponentStackDirection,
        spacing: Double,
        crossAlign: OverlayComponentCrossAlignment,
        children: [OverlayComponentResolvedStackChild],
        context: OpaquePointer,
        space: DrawSpace,
        opacity: Double,
        assets: [String: Data]
    ) {
        let layout = layoutStack(
            frame: frame,
            direction: direction,
            spacing: spacing,
            crossAlign: crossAlign,
            children: children,
            space: space
        )
        for placement in layout.placements {
            let origin = nodeOrigin(placement.node)
            var childSpace = space
            childSpace.origin = CGPoint(
                x: layout.bounds.minX + placement.origin.x - origin.x * space.scale,
                y: layout.bounds.minY + placement.origin.y - origin.y * space.scale
            )
            draw(
                placement.node,
                context: context,
                space: childSpace,
                opacity: opacity,
                assets: assets
            )
        }
    }

    private static func layoutStack(
        frame: CGRect?,
        direction: OverlayComponentStackDirection,
        spacing: Double,
        crossAlign: OverlayComponentCrossAlignment,
        children: [OverlayComponentResolvedStackChild],
        space: DrawSpace
    ) -> StackLayout {
        let spacingPixels = spacing * space.scale
        let sizes = children.map { intrinsicSize(of: $0.node, space: space) }
        let mainSizes = sizes.map { direction == .horizontal ? $0.width : $0.height }
        let crossSizes = sizes.map { direction == .horizontal ? $0.height : $0.width }
        let contentMain = mainSizes.reduce(0, +)
            + spacingPixels * Double(max(children.count - 1, 0))
        let contentCross = crossSizes.max() ?? 0
        let contentOrigin = space.point(frame?.origin ?? .zero)
        let containerSize: CGSize
        if let frame {
            containerSize = CGSize(
                width: frame.width * space.scale,
                height: frame.height * space.scale
            )
        } else {
            containerSize = direction == .horizontal
                ? CGSize(width: contentMain, height: contentCross)
                : CGSize(width: contentCross, height: contentMain)
        }
        let availableCross = direction == .horizontal
            ? containerSize.height
            : containerSize.width
        var placements: [(OverlayComponentResolvedNode, CGPoint)] = []
        var cursor = 0.0
        for (index, child) in children.enumerated() {
            let childMain = mainSizes[index]
            let childCross = crossSizes[index]
            let crossOffset: Double
            switch child.alignSelf ?? crossAlign {
            case .start:
                crossOffset = 0
            case .center:
                crossOffset = (availableCross - childCross) / 2
            case .end:
                crossOffset = availableCross - childCross
            }
            let origin = direction == .horizontal
                ? CGPoint(x: cursor, y: crossOffset)
                : CGPoint(x: crossOffset, y: cursor)
            placements.append((child.node, origin))
            cursor += childMain + spacingPixels
        }
        return StackLayout(
            bounds: CGRect(origin: contentOrigin, size: containerSize),
            placements: placements
        )
    }

    private static func intrinsicSize(
        of node: OverlayComponentResolvedNode,
        space: DrawSpace
    ) -> CGSize {
        switch node {
        case let .text(frame, text, font, _, _, _, maxWidth, lineHeight, tracking, autoSize):
            if autoSize {
                return intrinsicTextSize(
                    text: text,
                    font: font,
                    maxWidth: maxWidth,
                    lineHeight: lineHeight,
                    tracking: tracking,
                    space: space
                )
            }
            return CGSize(
                width: frame.width * space.scale,
                height: frame.height * space.scale
            )

        case let .stack(stackFrame, direction, spacing, crossAlign, children):
            if let stackFrame {
                return CGSize(
                    width: stackFrame.width * space.scale,
                    height: stackFrame.height * space.scale
                )
            }
            return layoutStack(
                frame: nil,
                direction: direction,
                spacing: spacing,
                crossAlign: crossAlign,
                children: children,
                space: space
            ).bounds.size

        case .opacity(_, let content):
            return intrinsicSize(of: content, space: space)

        default:
            let rect = nodeBounds(node)
            return CGSize(
                width: rect.width * space.scale,
                height: rect.height * space.scale
            )
        }
    }

    private static func nodeOrigin(_ node: OverlayComponentResolvedNode) -> CGPoint {
        switch node {
        case let .group(frame, _, _, _, _): frame.origin
        case let .stack(frame, _, _, _, _): frame?.origin ?? .zero
        case .opacity(_, let content): nodeOrigin(content)
        case let .rect(frame, _, _, _, _): frame.origin
        case .circle: .zero
        case .line: .zero
        case .polyline: .zero
        case .path: .zero
        case let .text(frame, _, _, _, _, _, _, _, _, _): frame.origin
        case let .image(frame, _, _): frame.origin
        case let .symbol(frame, _, _, _): frame.origin
        case let .gradientRect(frame, _, _, _, _): frame.origin
        case let .sparkline(frame, _, _, _, _, _): frame.origin
        case let .progressBar(frame, _, _, _, _): frame.origin
        case let .arc(frame, _, _, _, _, _, _, _, _): frame.origin
        }
    }

    private static func pixelBounds(
        _ node: OverlayComponentResolvedNode,
        space: DrawSpace
    ) -> CGRect {
        switch node {
        case let .stack(frame, direction, spacing, crossAlign, children):
            return layoutStack(
                frame: frame,
                direction: direction,
                spacing: spacing,
                crossAlign: crossAlign,
                children: children,
                space: space
            ).bounds
        case .opacity(_, let content):
            return pixelBounds(content, space: space)
        case let .text(frame, text, font, _, _, _, maxWidth, lineHeight, tracking, autoSize):
            guard autoSize else { return space.rect(frame) }
            let size = intrinsicTextSize(
                text: text,
                font: font,
                maxWidth: maxWidth,
                lineHeight: lineHeight,
                tracking: tracking,
                space: space
            )
            return CGRect(origin: space.point(frame.origin), size: size)
        default:
            return space.rect(nodeBounds(node))
        }
    }

    // MARK: - Text

    private struct TextMeasurement {
        var lines: [SkiaTextLine]
        var lineHeightPixels: Double
        var totalHeight: Double
        var width: Double
    }

    private static func measureText(
        _ text: String,
        font: OverlayComponentResolvedFont,
        maxWidth: Double?,
        lineHeight: Double,
        tracking: Double,
        space: DrawSpace
    ) -> TextMeasurement? {
        let nsFont = SkiaTextComposer.font(
            family: resolvedFamily(font.family),
            size: font.size * space.scale,
            weight: font.weight.appKitWeight
        )
        let lines = makeLines(
            text,
            font: nsFont,
            maxWidth: maxWidth.map(space.length),
            tracking: space.length(tracking)
        )
        guard let first = lines.first else { return nil }
        let lineHeightPixels = max(font.size * space.scale * lineHeight, first.height)
        let totalHeight = lineHeightPixels * Double(lines.count - 1) + first.height
        return TextMeasurement(
            lines: lines,
            lineHeightPixels: lineHeightPixels,
            totalHeight: totalHeight,
            width: lines.map(\.width).max() ?? 0
        )
    }

    private static func intrinsicTextSize(
        text: String,
        font: OverlayComponentResolvedFont,
        maxWidth: Double?,
        lineHeight: Double,
        tracking: Double,
        space: DrawSpace
    ) -> CGSize {
        guard !text.isEmpty,
              let measurement = measureText(
                  text,
                  font: font,
                  maxWidth: maxWidth,
                  lineHeight: lineHeight,
                  tracking: tracking,
                  space: space
              ) else {
            return .zero
        }
        return CGSize(width: measurement.width, height: measurement.totalHeight)
    }

    private static func drawText(
        _ text: String,
        frame: CGRect,
        font: OverlayComponentResolvedFont,
        color: OverlayColor,
        align: OverlayComponentTextAlignment,
        verticalAlign: OverlayComponentVerticalAlignment,
        maxWidth: Double?,
        lineHeight: Double,
        tracking: Double,
        context: OpaquePointer,
        space: DrawSpace,
        opacity: Double
    ) {
        guard !text.isEmpty,
              let measurement = measureText(
                  text,
                  font: font,
                  maxWidth: maxWidth,
                  lineHeight: lineHeight,
                  tracking: tracking,
                  space: space
              ) else {
            return
        }
        let rect = space.rect(frame)
        let lines = measurement.lines
        let totalHeight = measurement.totalHeight
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
            let y = top + measurement.lineHeightPixels * Double(index)
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

    private static func makeLines(
        _ text: String,
        font: NSFont,
        maxWidth: Double?,
        tracking: Double
    ) -> [SkiaTextLine] {
        let paragraphs = text.components(separatedBy: "\n").prefix(8)
        var lines: [SkiaTextLine] = []
        for paragraph in paragraphs {
            guard let maxWidth, maxWidth > 0 else {
                lines.append(SkiaTextComposer.makeLine(paragraph, font: font, tracking: tracking))
                continue
            }
            var current = ""
            for word in paragraph.split(separator: " ", omittingEmptySubsequences: false) {
                let candidate = current.isEmpty ? String(word) : current + " " + word
                let line = SkiaTextComposer.makeLine(candidate, font: font, tracking: tracking)
                if line.width > maxWidth, !current.isEmpty {
                    lines.append(SkiaTextComposer.makeLine(current, font: font, tracking: tracking))
                    current = String(word)
                } else {
                    current = candidate
                }
            }
            lines.append(SkiaTextComposer.makeLine(current, font: font, tracking: tracking))
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
        case .stack: .zero
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
        case let .text(frame, _, _, _, _, _, _, _, _, _): frame
        case let .image(frame, _, _): frame
        case let .symbol(frame, _, _, _): frame
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
