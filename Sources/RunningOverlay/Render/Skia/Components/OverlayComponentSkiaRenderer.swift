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
        // component, outside the component clip, so a ported built-in keeps the
        // same Inspector effects as the native module it replaces.
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
                    assets: assets,
                    renderContext: renderContext
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
            elementScale: scale,
            weatherPayload: renderContext.weatherPayload ?? element.style.weatherWidget.cachedWeather
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
                space: DrawSpace(origin: origin, scale: scale, elementScale: element.scale),
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
            scale: scale,
            elementScale: element.scale
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
        /// Element scale alone, without the canvas scale. Host modules size a
        /// few marker constants from it before canvas scaling.
        var elementScale: Double = 1

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
        assets: [String: Data],
        renderContext: OverlayRenderContext
    ) {
        guard opacity > 0.001 else { return }
        switch node {
        case let .group(frame, groupOpacity, clip, shadows, shadowBounds, children):
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
            if !shadows.isEmpty {
                let chainBounds = shadowBounds.map(space.rect) ?? rect
                var sigmas: [Float] = []
                var dxs: [Float] = []
                var dys: [Float] = []
                var rgba: [Float] = []
                for shadow in shadows
                where shadow.color.alpha * shadow.opacity * opacity > 0.0001 && shadow.sigma >= 0 {
                    sigmas.append(Float(space.length(shadow.sigma)))
                    dxs.append(Float(space.length(shadow.dx)))
                    dys.append(Float(space.length(shadow.dy)))
                    rgba.append(contentsOf: [
                        Float(shadow.color.red), Float(shadow.color.green),
                        Float(shadow.color.blue),
                        Float(min(max(shadow.color.alpha * shadow.opacity * opacity, 0), 1))
                    ])
                }
                if !sigmas.isEmpty {
                    sigmas.withUnsafeBufferPointer { sigmas in
                    dxs.withUnsafeBufferPointer { dxs in
                        dys.withUnsafeBufferPointer { dys in
                            rgba.withUnsafeBufferPointer { rgba in
                                skb_begin_shadow_chain(
                                    context, Int32(sigmas.count),
                                    sigmas.baseAddress, dxs.baseAddress, dys.baseAddress,
                                    rgba.baseAddress,
                                    Float(chainBounds.minX), Float(chainBounds.minY),
                                    Float(chainBounds.width), Float(chainBounds.height)
                                )
                            }
                        }
                    }
                    }
                    restoreCount += 1
                }
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
                draw(child, context: context, space: space, opacity: opacity, assets: assets, renderContext: renderContext)
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
                assets: assets,
                renderContext: renderContext
            )

        case let .opacity(nodeOpacity, content):
            let rect = paintBounds(content, space: space)
            skb_begin_opacity_layer(
                context,
                Float(nodeOpacity),
                Float(rect.minX),
                Float(rect.minY),
                Float(rect.width),
                Float(rect.height)
            )
            draw(content, context: context, space: space, opacity: opacity, assets: assets, renderContext: renderContext)
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

        case let .textRows(frame, text, autoSize):
            SkiaIntervalText.drawRows(
                intervalRows(text, space: space, opacity: opacity),
                rect: textRowsRect(frame, text: text, autoSize: autoSize, space: space),
                spacing: space.length(text.spacing),
                context: context
            )

        case let .columns(width, divider, children):
            drawColumns(
                width: width,
                divider: divider,
                children: children,
                context: context,
                space: space,
                opacity: opacity,
                assets: assets,
                renderContext: renderContext
            )

        case let .richText(frame, text):
            let rect = space.rect(frame)
            let alignment: NSTextAlignment = switch text.align {
            case .left: .left
            case .center: .center
            case .right: .right
            }
            let gradient = text.gradient.map {
                OverlayComponentResolvedTextGradient(
                    stops: $0.stops,
                    from: CGPoint(x: $0.from.x * space.scale, y: $0.from.y * space.scale),
                    to: CGPoint(x: $0.to.x * space.scale, y: $0.to.y * space.scale)
                )
            }
            let request = SkiaParagraphTextLayout(
                size: rect.size, content: text.text,
                font: SkiaTextComposer.font(family: resolvedFamily(text.font.family),
                                            size: space.length(text.font.size),
                                            weight: text.font.weight.appKitWeight),
                alignment: alignment, lineHeight: text.lineHeight,
                tracking: space.length(text.tracking), color: text.color,
                gradient: gradient, strokeWidth: space.length(text.strokeWidth),
                strokeColor: text.stroke, autoFit: text.autoFit
            )
            if let bitmap = SkiaParagraphTextRasterCache.bitmap(for: request), let pointer = bitmap.pointer {
                skb_draw_image_handle(context, pointer,
                                      Float(rect.minX), Float(rect.minY), Float(rect.width), Float(rect.height),
                                      Float(opacity), 0, 0, 0, 0)
            }

        case .spacer(_, _):
            return

        case let .symbol(frame, name, color, weight, scale, rendering):
            if rendering == .fit {
                SkiaIconRasterCache.draw(
                    asset: .sfSymbol(name: name,
                                     weight: SymbolWeight(rawValue: weight.rawValue) ?? .medium,
                                     scale: SymbolScale(rawValue: scale.rawValue) ?? .medium),
                    rect: space.rect(frame), tint: color, preserveSVGColors: false,
                    contentMode: .fit, opacity: opacity, context: context
                )
                return
            }
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

        case let .segmentedBar(frame, vertical, segments, activeIndex, activeWidthShare,
                               activeThicknessScale, gap, radius, inactiveOpacity, glow,
                               border, markers):
            let barRect = space.rect(frame)
            let geometry = segmentedBarGeometry(
                barRect: barRect,
                vertical: vertical,
                segments: segments,
                activeIndex: activeIndex,
                activeWidthShare: activeWidthShare,
                activeThicknessScale: activeThicknessScale,
                gap: space.length(gap),
                space: space
            )
            let activeRect = geometry.rects.first { $0.index == activeIndex }?.rect
            if let glow, let activeRect, glow.opacity > 0.0001 {
                let color = segments.first { $0.index == activeIndex }?.color ?? .white
                let sigma = space.length(glow.sigma)
                let bounds = activeRect.insetBy(dx: -sigma * 3, dy: -sigma * 3)
                SkiaIntervalDraw.withBlur(context, sigma: sigma, bounds: bounds) {
                    SkiaIntervalDraw.fillRoundRect(
                        context,
                        activeRect,
                        radius: segmentRadius(radius: space.length(radius), rect: activeRect),
                        color: color,
                        opacity: glow.opacity * opacity
                    )
                }
            }
            for entry in geometry.rects {
                let isActive = entry.index == activeIndex
                let segmentColor = segments.first { $0.index == entry.index }?.color ?? .white
                SkiaIntervalDraw.fillRoundRect(
                    context,
                    entry.rect,
                    radius: segmentRadius(radius: space.length(radius), rect: entry.rect),
                    color: segmentColor,
                    opacity: opacity * (isActive ? 1 : inactiveOpacity)
                )
            }
            if let border, border.opacity > 0.0001, border.width > 0 {
                SkiaIntervalDraw.strokeRoundRect(
                    context,
                    barRect,
                    radius: min(space.length(radius), (vertical ? barRect.width : barRect.height) / 2),
                    lineWidth: space.length(border.width),
                    color: border.color,
                    opacity: border.opacity * opacity
                )
            }
            for marker in markers {
                switch marker.layout {
                case .inline:
                    drawSegmentedBarMarker(
                        marker,
                        barRect: barRect,
                        geometry: geometry,
                        vertical: vertical,
                        space: space,
                        opacity: opacity,
                        context: context
                    )
                case .outside:
                    drawOutsideSegmentedBarMarker(
                        marker,
                        barRect: barRect,
                        geometry: geometry,
                        vertical: vertical,
                        space: space,
                        opacity: opacity,
                        context: context
                    )
                }
            }

        case let .timelineStrip(frame, strip):
            drawTimelineStrip(
                frame: space.rect(frame),
                strip: strip,
                space: space,
                context: context
            )

        case let .runningGauge(frame, gauge):
            drawRunningGauge(
                frame: space.rect(frame),
                gauge: gauge,
                space: space,
                context: context
            )

        case let .distanceTimeline(frame, style, valueFontSize):
            drawDistanceTimeline(
                frame: space.rect(frame),
                style: style,
                valueFontSize: valueFontSize,
                space: space,
                renderContext: renderContext,
                context: context
            )

        case let .elevationChart(frame, style, valueFontSize, fontName, foregroundColor):
            drawElevationChart(
                frame: space.rect(frame),
                style: style,
                valueFontSize: valueFontSize,
                fontName: fontName,
                foregroundColor: foregroundColor,
                space: space,
                renderContext: renderContext,
                context: context
            )

        case let .routeMap(frame, style):
            drawRouteMap(
                frame: space.rect(frame),
                style: style,
                space: space,
                renderContext: renderContext,
                context: context
            )

        case let .weatherWidget(frame, style):
            drawWeatherWidget(
                frame: space.rect(frame),
                style: style,
                space: space,
                renderContext: renderContext,
                context: context
            )
        }
    }

    // MARK: - Timeline strip

    private struct TimelineSegment {
        var lap: OverlayComponentResolvedTimelineLap
        var rect: CGRect
        var labelLines: [String]
        var color: OverlayColor
        var opacity: Double
        var isCurrent: Bool
    }

    private static func drawTimelineStrip(
        frame: CGRect,
        strip: OverlayComponentResolvedTimelineStrip,
        space: DrawSpace,
        context: OpaquePointer
    ) {
        guard frame.width > 0, frame.height > 0 else { return }
        let horizontalPadding = space.length(16)
        let verticalPadding = space.length(6)
        let markerGap = space.length(4)
        let markerBottomPadding = space.length(4)
        let triangleWidth = space.length(10)
        let triangleHeight = space.length(6)
        let markerStackSpacing = space.length(2)
        let markerFontSize = space.length(strip.marker?.font.size ?? 11)
        let markerLabelHeight = space.length(max((strip.marker?.font.size ?? 11) * 1.4, 14))
        let markerStackHeight = triangleHeight + markerStackSpacing + markerLabelHeight
        let innerSegmentHeight = max(
            space.length(strip.segmentAreaHeight) - verticalPadding * 2,
            1
        )
        let contentRect = CGRect(
            x: frame.minX + horizontalPadding,
            y: frame.minY + verticalPadding,
            width: max(frame.width - horizontalPadding * 2, 1),
            height: innerSegmentHeight
        )
        let normalHeight = min(space.length(strip.segmentHeight), innerSegmentHeight)
        let currentHeight = min(normalHeight * strip.currentHeightScale, innerSegmentHeight)

        let visible = strip.laps.filter { lap in
            switch lap.kind {
            case "warmup": strip.showsWarmup
            case "rest": strip.showsRest
            case "cooldown": strip.showsCooldown
            default: true
            }
        }
        guard !visible.isEmpty else { return }
        let currentFilteredOffset = strip.currentIndex.flatMap { index in
            visible.firstIndex { $0.index == index }
        }
        let anchorOffset = currentFilteredOffset ?? nearestTimelineOffset(
            to: strip.elapsed,
            in: visible
        )
        let visibleRange: Range<Int>
        if strip.mode == "emphasized", let anchorOffset, let neighbors = strip.window {
            let start = max(anchorOffset - neighbors, 0)
            let end = min(anchorOffset + neighbors + 1, visible.count)
            visibleRange = start..<end
        } else {
            visibleRange = 0..<visible.count
        }
        let visibleLaps = visibleRange.map { visible[$0] }
        let leftOverflow = max(visibleRange.lowerBound, 0)
        let rightOverflow = max(visible.count - visibleRange.upperBound, 0)
        let overflowEnabled = strip.overflow?.enabled ?? false
        let overflowHintWidth = overflowEnabled ? space.length(strip.overflow?.inset ?? 36) : 0
        let leadingOverflowWidth = leftOverflow > 0 ? overflowHintWidth : 0
        let trailingOverflowWidth = rightOverflow > 0 ? overflowHintWidth : 0
        let segmentArea = CGRect(
            x: contentRect.minX + leadingOverflowWidth,
            y: contentRect.minY,
            width: max(contentRect.width - leadingOverflowWidth - trailingOverflowWidth, 1),
            height: contentRect.height
        )
        let gap = space.length(strip.gap)
        let minWidth = space.length(strip.minSegmentWidth)
        let currentVisibleOffset = currentFilteredOffset.flatMap {
            visibleRange.contains($0) ? $0 - visibleRange.lowerBound : nil
        }
        let layoutMode: OverlayComponentStripLayout.Mode = switch strip.mode {
        case "weighted": .weighted
        case "equal": .equal
        default: .emphasized
        }
        let widths = OverlayComponentStripLayout.widths(
            weights: visibleLaps.map(\.elapsed),
            mode: layoutMode,
            currentIndex: currentVisibleOffset,
            emphasisFraction: strip.emphasisFraction,
            availableWidth: segmentArea.width,
            gap: gap,
            minimumWidth: minWidth
        )
        var cursorX = segmentArea.minX
        var segments: [TimelineSegment] = []
        for (offset, lap) in visibleLaps.enumerated() {
            let width = widths.indices.contains(offset) ? widths[offset] : minWidth
            let isCurrent = currentVisibleOffset == offset
            let height = isCurrent ? currentHeight : normalHeight
            let rect = CGRect(
                x: cursorX,
                y: segmentArea.midY - height / 2,
                width: width,
                height: height
            )
            let completed = lap.endElapsed <= strip.elapsed
            segments.append(TimelineSegment(
                lap: lap,
                rect: rect,
                labelLines: timelineLabelLines(
                    lap: lap,
                    isCurrent: isCurrent,
                    strip: strip
                ),
                color: strip.colors.color(for: lap.kind),
                opacity: isCurrent ? 1 : (completed ? strip.completedOpacity : strip.futureOpacity),
                isCurrent: isCurrent
            ))
            cursorX += width + gap
        }

        let segmentCornerRadius = space.length(strip.radius)
        let labelFontSize = space.length(16)
        let durationFontSize = space.length(12)
        let currentBorderWidth = space.length(strip.currentBorderWidth)
        for segment in segments {
            drawTimelineSegment(
                segment,
                strip: strip,
                space: space,
                labelFontSize: labelFontSize,
                durationFontSize: durationFontSize,
                segmentCornerRadius: segmentCornerRadius,
                currentBorderWidth: currentBorderWidth,
                context: context
            )
        }

        if overflowEnabled {
            let font = intervalFont(
                family: strip.labels?.font.family ?? "",
                size: labelFontSize * 0.95,
                weight: .bold,
                monospacedDigits: false
            )
            let line = SkiaIntervalText.makeLine(strip.overflow?.text ?? "···", font: font)
            let baselineY = contentRect.midY - line.height / 2 + line.ascent
            let inset = horizontalPadding + overflowHintWidth / 2
            if leftOverflow > 0 {
                SkiaIntervalText.draw(
                    line, font: font,
                    x: frame.minX + inset - line.width / 2,
                    baselineY: baselineY,
                    color: strip.overflow?.color ?? .white,
                    opacity: 0.5,
                    context: context
                )
            }
            if rightOverflow > 0 {
                SkiaIntervalText.draw(
                    line, font: font,
                    x: frame.maxX - inset - line.width / 2,
                    baselineY: baselineY,
                    color: strip.overflow?.color ?? .white,
                    opacity: 0.5,
                    context: context
                )
            }
        }

        guard let marker = strip.marker, marker.enabled else { return }
        let currentSegment = segments.first { $0.isCurrent }
        let fallbackSegment = anchorOffset.flatMap { anchor -> TimelineSegment? in
            let offset = anchor - visibleRange.lowerBound
            guard visibleRange.contains(anchor), segments.indices.contains(offset) else {
                return nil
            }
            return segments[offset]
        }
        let markerX: Double
        if let currentSegment {
            markerX = marker.position == "center"
                ? currentSegment.rect.midX
                : currentSegment.rect.minX
                    + currentSegment.rect.width * (strip.progress?.value ?? 0)
        } else if let fallbackSegment {
            markerX = fallbackSegment.rect.midX
        } else {
            markerX = segmentArea.midX
        }
        let markerTopY = frame.minY + verticalPadding + innerSegmentHeight / 2
            + currentHeight / 2 + markerGap
        SkiaIntervalDraw.fillTriangle(
            context,
            CGPoint(x: markerX, y: markerTopY),
            CGPoint(x: markerX + triangleWidth / 2, y: markerTopY + triangleHeight),
            CGPoint(x: markerX - triangleWidth / 2, y: markerTopY + triangleHeight),
            color: marker.color,
            opacity: 0.92
        )
        guard marker.showsLabel else { return }
        let family = marker.font.family.isEmpty
            ? (strip.labels?.font.family ?? "")
            : marker.font.family
        let font = intervalFont(
            family: family,
            size: markerFontSize,
            weight: marker.font.weight,
            monospacedDigits: false
        )
        let line = SkiaIntervalText.makeLine(marker.label, font: font)
        let labelTop = markerTopY + triangleHeight + markerStackSpacing
        let baselineY = labelTop + markerLabelHeight / 2 - line.height / 2 + line.ascent
        SkiaIntervalText.draw(
            line, font: font,
            x: markerX - line.width / 2,
            baselineY: baselineY,
            color: marker.color,
            opacity: 0.88,
            context: context
        )
    }

    private static func drawTimelineSegment(
        _ segment: TimelineSegment,
        strip: OverlayComponentResolvedTimelineStrip,
        space: DrawSpace,
        labelFontSize: Double,
        durationFontSize: Double,
        segmentCornerRadius: Double,
        currentBorderWidth: Double,
        context: OpaquePointer
    ) {
        let rect = segment.rect
        guard rect.width > 0, rect.height > 0 else { return }
        let radius = min(segmentCornerRadius, rect.width / 2, rect.height / 2)
        SkiaIntervalDraw.withShadowChain(
            context,
            shadows: segment.isCurrent
                ? [.init(radius: space.length(10), dx: 0, dy: 0,
                         color: segment.color, alpha: 0.45)]
                : [],
            bounds: rect.insetBy(dx: -space.length(12), dy: -space.length(12))
        ) {
            SkiaIntervalDraw.fillRoundRect(
                context, rect,
                radius: radius,
                color: segment.color,
                opacity: segment.opacity
            )
            if segment.isCurrent, let progress = strip.progress {
                let progressWidth = rect.width * progress.value
                if progressWidth > 0 {
                    SkiaIntervalDraw.fillRoundRect(
                        context,
                        CGRect(x: rect.minX, y: rect.minY, width: progressWidth, height: rect.height),
                        radius: min(segmentCornerRadius, progressWidth / 2, rect.height / 2),
                        color: progress.color,
                        opacity: progress.opacity * segment.opacity
                    )
                }
            }
            if segment.isCurrent {
                SkiaIntervalDraw.strokeRoundRect(
                    context, rect,
                    radius: radius,
                    lineWidth: currentBorderWidth,
                    color: .white,
                    opacity: 0.74
                )
            }
        }

        let padding = space.length(4)
        let textRect = rect.insetBy(dx: padding, dy: 0)
        guard textRect.width > 0 else { return }
        let family = strip.labels?.font.family ?? ""
        var lines: [SkiaIntervalText.StackLine] = []
        if segment.isCurrent, !strip.repText.isEmpty {
            lines.append(.init(
                text: strip.repText,
                font: intervalFont(
                    family: family,
                    size: max(durationFontSize * 0.82, 8),
                    weight: .semibold,
                    monospacedDigits: false
                ),
                color: .white,
                opacity: 0.78,
                minimumScaleFactor: 0.7,
                monospacedDigits: false
            ))
        }
        for (offset, text) in segment.labelLines.enumerated() {
            let size = offset == 0
                ? (segment.isCurrent ? labelFontSize * 1.08 : labelFontSize)
                : durationFontSize
            lines.append(.init(
                text: text,
                font: intervalFont(
                    family: family,
                    size: size,
                    weight: offset == 0 ? .bold : .semibold,
                    monospacedDigits: true
                ),
                color: .white,
                opacity: offset == 0 ? 0.96 : 0.86,
                minimumScaleFactor: 0.64,
                monospacedDigits: true
            ))
        }
        SkiaIntervalText.drawStack(
            lines,
            rect: textRect,
            spacing: space.length(1),
            context: context
        )
    }

    private static func nearestTimelineOffset(
        to elapsed: Double,
        in laps: [OverlayComponentResolvedTimelineLap]
    ) -> Int? {
        guard !laps.isEmpty else { return nil }
        return laps.indices.min { lhs, rhs in
            timelineDistance(from: elapsed, to: laps[lhs])
                < timelineDistance(from: elapsed, to: laps[rhs])
        }
    }

    private static func timelineDistance(
        from elapsed: Double,
        to lap: OverlayComponentResolvedTimelineLap
    ) -> Double {
        if lap.startElapsed <= elapsed, elapsed <= lap.endElapsed { return 0 }
        return min(abs(elapsed - lap.startElapsed), abs(elapsed - lap.endElapsed))
    }

    private static func timelineLabelLines(
        lap: OverlayComponentResolvedTimelineLap,
        isCurrent: Bool,
        strip: OverlayComponentResolvedTimelineStrip
    ) -> [String] {
        let labels = strip.labels
        if isCurrent {
            var lines: [String] = []
            let distanceMode: String
            let timeMode: String
            if lap.kind == "active" {
                distanceMode = labels?.currentWorkDistance ?? "elapsed"
                timeMode = labels?.currentWorkTime ?? "remaining"
            } else {
                if labels?.currentRestKind ?? true {
                    lines.append(timelineKindText(lap.kind))
                }
                distanceMode = labels?.currentRestDistance ?? "hidden"
                timeMode = labels?.currentRestTime ?? "remaining"
            }
            switch distanceMode {
            case "elapsed":
                lines.append(timelineDistanceText(lap.distance * strip.distanceProgress))
            case "remaining":
                lines.append(timelineDistanceText(max(lap.distance * (1 - strip.distanceProgress), 0)))
            default:
                break
            }
            let timeProgress = strip.progress?.value ?? 0
            switch timeMode {
            case "elapsed":
                lines.append(timelineDurationText(lap.elapsed * timeProgress))
            case "remaining":
                lines.append(timelineDurationText(max(lap.elapsed * (1 - timeProgress), 0)))
            default:
                break
            }
            return lines
        }
        switch labels?.neighbor ?? "distance" {
        case "hidden": return []
        case "time": return [timelineDurationText(lap.elapsed)]
        default: return [timelineDistanceText(lap.distance)]
        }
    }

    private static func timelineKindText(_ kind: String) -> String {
        switch kind {
        case "warmup": "WU"
        case "active": "Work"
        case "rest": "Rest"
        case "cooldown": "CD"
        default: "Lap"
        }
    }

    private static func timelineDistanceText(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000).replacingOccurrences(of: " ", with: "")
        }
        return "\(Int(meters.rounded())) m".replacingOccurrences(of: " ", with: "")
    }

    private static func timelineDurationText(_ duration: TimeInterval) -> String {
        let total = max(Int(duration.rounded()), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Segmented bar

    private struct SegmentRect {
        var index: Int
        var rect: CGRect
    }

    private struct SegmentedBarGeometry {
        var rects: [SegmentRect]
    }

    private static func segmentRadius(radius: Double, rect: CGRect) -> Double {
        min(radius, rect.height / 2, rect.width / 2)
    }

    private static func segmentedBarGeometry(
        barRect: CGRect,
        vertical: Bool,
        segments: [OverlayComponentResolvedSegment],
        activeIndex: Int?,
        activeWidthShare: Double,
        activeThicknessScale: Double,
        gap: Double,
        space: DrawSpace
    ) -> SegmentedBarGeometry {
        let count = segments.count
        guard count > 0, barRect.width > 0, barRect.height > 0 else {
            return SegmentedBarGeometry(rects: [])
        }
        let equalWidth = 1 / Double(count)
        let requestedWidth = min(max(activeWidthShare, 0), 0.5)
        let activePosition = activeIndex.flatMap { active in
            segments.firstIndex { $0.index == active }
        }
        var frames: [(start: Double, width: Double)] = []
        if let activePosition, requestedWidth > equalWidth, count > 1 {
            let inactiveWidth = (1 - requestedWidth) / Double(count - 1)
            var cursor = 0.0
            for position in 0..<count {
                let width = position == activePosition ? requestedWidth : inactiveWidth
                frames.append((cursor, width))
                cursor += width
            }
        } else {
            frames = (0..<count).map { position in
                (Double(position) * equalWidth, equalWidth)
            }
        }
        let length = vertical ? barRect.height : barRect.width
        let cross = vertical ? barRect.width : barRect.height
        let maxGap = count > 1 ? max(length / Double(count - 1) * 0.18, 0) : 0
        let clampedGap = min(max(gap, 0), maxGap)
        let usable = max(length - clampedGap * Double(count - 1), 1)
        var rects: [SegmentRect] = []
        for position in 0..<count {
            let segment = segments[position]
            let isActive = position == activePosition
            let thickness = isActive
                ? cross * max(activeThicknessScale, 1)
                : cross
            let segmentLength = max(usable * frames[position].width, 0)
            let rect: CGRect
            if vertical {
                // Vertical bars run from the bottom edge upward, so the first
                // segment sits at the bottom, matching the native zone bars.
                let y = barRect.maxY
                    - usable * (frames[position].start + frames[position].width)
                    - Double(position) * clampedGap
                rect = CGRect(
                    x: barRect.midX - thickness / 2,
                    y: y,
                    width: thickness,
                    height: segmentLength
                )
            } else {
                let x = barRect.minX + usable * frames[position].start + Double(position) * clampedGap
                rect = CGRect(
                    x: x,
                    y: barRect.midY - thickness / 2,
                    width: segmentLength,
                    height: thickness
                )
            }
            rects.append(SegmentRect(index: segment.index, rect: rect))
        }
        return SegmentedBarGeometry(rects: rects)
    }

    /// `true` when a marker sits on the start side of the bar: above a
    /// horizontal bar or leading a vertical one.
    private static func isStartSide(
        _ side: OverlayComponentSegmentedBarMarkerSide,
        vertical: Bool
    ) -> Bool {
        vertical ? side != .trailing : side != .below
    }

    /// Inline marker used by the interval HUD: an arrow plus optional value
    /// pill stacked directly against the bar.
    private static func drawSegmentedBarMarker(
        _ marker: OverlayComponentResolvedSegmentedBarMarker,
        barRect: CGRect,
        geometry: SegmentedBarGeometry,
        vertical: Bool,
        space: DrawSpace,
        opacity: Double,
        context: OpaquePointer
    ) {
        guard let zoneRect = geometry.rects.first(where: { $0.index == marker.index })?.rect else {
            return
        }
        let cross = vertical ? barRect.width : barRect.height
        let startSide = isStartSide(marker.side, vertical: vertical)
        switch marker.role {
        case .current:
            let valueFontSize = max(space.length(marker.font.size), 9)
            let valueFont = intervalFont(
                family: resolvedFamily(marker.font.family),
                size: valueFontSize,
                weight: marker.font.weight,
                monospacedDigits: true
            )
            let line = SkiaIntervalText.makeLine(marker.text, font: valueFont)
            let markerScale = max(marker.scale, 0)
            let arrowSize = vertical
                ? CGSize(
                    width: max(cross * 0.9, 8) * markerScale,
                    height: max(cross * 1.35, 12) * markerScale
                )
                : CGSize(
                    width: max(cross * 1.35, 12) * markerScale,
                    height: max(cross * 0.9, 8) * markerScale
                )
            let horizontalPadding = 5.0
            let verticalPadding = 2.0
            let cornerRadius = 4.0
            let stackSpacing = 2.0
            let markerGap = startSide ? max(cross * 0.35, 3) : max(cross * 0.55, 4)
            let pillSize = CGSize(
                width: line.width + horizontalPadding * 2,
                height: line.height + verticalPadding * 2
            )
            let formattedHeight = vertical ? arrowSize.width : arrowSize.height
            let formulaExtent = formattedHeight
                + (marker.showsValue ? valueFontSize + 4 : 0)
                + (marker.showsValue ? stackSpacing : 0)
            let actualExtent = formattedHeight
                + (marker.showsValue ? pillSize.height : 0)
                + (marker.showsValue ? stackSpacing : 0)

            func drawValue(_ rect: CGRect) {
                SkiaIntervalDraw.fillRoundRect(
                    context, rect, radius: cornerRadius, color: .black,
                    opacity: 0.55 * opacity
                )
                SkiaIntervalText.draw(
                    line,
                    font: valueFont,
                    x: rect.midX - line.width / 2,
                    baselineY: rect.midY - line.height / 2 + line.ascent,
                    color: marker.color,
                    opacity: opacity,
                    context: context
                )
            }

            if vertical {
                let anchorY = zoneRect.maxY - zoneRect.height * marker.fraction
                let anchorX = startSide
                    ? barRect.minX - markerGap - formulaExtent / 2
                    : barRect.maxX + markerGap + formulaExtent / 2
                var cursor = anchorX - actualExtent / 2
                if startSide {
                    if marker.showsValue {
                        drawValue(CGRect(
                            x: cursor, y: anchorY - pillSize.height / 2,
                            width: pillSize.width, height: pillSize.height
                        ))
                        cursor += pillSize.width + stackSpacing
                    }
                    let rect = CGRect(
                        x: cursor, y: anchorY - arrowSize.height / 2,
                        width: arrowSize.width, height: arrowSize.height
                    )
                    SkiaIntervalDraw.fillTriangle(
                        context,
                        CGPoint(x: rect.maxX, y: rect.midY),
                        CGPoint(x: rect.minX, y: rect.minY),
                        CGPoint(x: rect.minX, y: rect.maxY),
                        color: marker.color,
                        opacity: opacity
                    )
                } else {
                    let rect = CGRect(
                        x: cursor, y: anchorY - arrowSize.height / 2,
                        width: arrowSize.width, height: arrowSize.height
                    )
                    SkiaIntervalDraw.fillTriangle(
                        context,
                        CGPoint(x: rect.minX, y: rect.midY),
                        CGPoint(x: rect.maxX, y: rect.minY),
                        CGPoint(x: rect.maxX, y: rect.maxY),
                        color: marker.color,
                        opacity: opacity
                    )
                    cursor += arrowSize.width + stackSpacing
                    if marker.showsValue {
                        drawValue(CGRect(
                            x: cursor, y: anchorY - pillSize.height / 2,
                            width: pillSize.width, height: pillSize.height
                        ))
                    }
                }
                return
            }

            let anchorX = zoneRect.minX + zoneRect.width * marker.fraction
            let centerY = startSide
                ? barRect.minY - markerGap - formulaExtent / 2
                : barRect.maxY + markerGap + formulaExtent / 2
            var cursor = centerY - actualExtent / 2

            if startSide {
                if marker.showsValue {
                    drawValue(CGRect(
                        x: anchorX - pillSize.width / 2, y: cursor,
                        width: pillSize.width, height: pillSize.height
                    ))
                    cursor += pillSize.height + stackSpacing
                }
                SkiaIntervalDraw.fillTriangle(
                    context,
                    CGPoint(x: anchorX - arrowSize.width / 2, y: cursor),
                    CGPoint(x: anchorX + arrowSize.width / 2, y: cursor),
                    CGPoint(x: anchorX, y: cursor + arrowSize.height),
                    color: marker.color,
                    opacity: opacity
                )
            } else {
                SkiaIntervalDraw.fillTriangle(
                    context,
                    CGPoint(x: anchorX, y: cursor),
                    CGPoint(x: anchorX + arrowSize.width / 2, y: cursor + arrowSize.height),
                    CGPoint(x: anchorX - arrowSize.width / 2, y: cursor + arrowSize.height),
                    color: marker.color,
                    opacity: opacity
                )
                cursor += arrowSize.height + stackSpacing
                if marker.showsValue {
                    drawValue(CGRect(
                        x: anchorX - pillSize.width / 2, y: cursor,
                        width: pillSize.width, height: pillSize.height
                    ))
                }
            }

        case .threshold:
            let valueFontSize = max(space.length(marker.font.size) * 0.72, 7)
            let valueFont = intervalFont(
                family: resolvedFamily(marker.font.family),
                size: valueFontSize,
                weight: marker.font.weight,
                monospacedDigits: false
            )
            let line = SkiaIntervalText.makeLine(marker.text, font: valueFont)
            let lineWidth = max(1.2 * space.elementScale, 1)
            let stackSpacing = 2.0
            if vertical {
                // A vertical bar's threshold is a horizontal tick centered on
                // the bar with the label stacked on the start side.
                let lineLength = max(cross * 1.35, 10)
                let anchorY = zoneRect.maxY - zoneRect.height * marker.fraction
                let totalHeight = line.height + stackSpacing + lineWidth
                var top = startSide
                    ? anchorY - lineLength / 2 - totalHeight
                    : anchorY + lineLength / 2
                if startSide {
                    SkiaIntervalText.draw(
                        line,
                        font: valueFont,
                        x: barRect.midX - line.width / 2,
                        baselineY: top + line.ascent,
                        color: marker.color,
                        opacity: 0.78 * opacity,
                        context: context
                    )
                    top += line.height + stackSpacing
                }
                SkiaIntervalDraw.fillCapsule(
                    context,
                    CGRect(
                        x: barRect.midX - lineLength / 2,
                        y: anchorY - lineWidth / 2,
                        width: lineLength,
                        height: lineWidth
                    ),
                    color: marker.color,
                    opacity: 0.78 * opacity
                )
                if !startSide {
                    SkiaIntervalText.draw(
                        line,
                        font: valueFont,
                        x: barRect.midX - line.width / 2,
                        baselineY: anchorY + lineLength / 2 + stackSpacing + line.ascent,
                        color: marker.color,
                        opacity: 0.78 * opacity,
                        context: context
                    )
                }
                return
            }
            // The native interval HUD always draws the tick first with its
            // label below it, regardless of the current marker's side.
            let anchorX = zoneRect.minX + zoneRect.width * marker.fraction
            let lineHeight = max(barRect.height * 1.35, 10)
            let formulaLabelHeight = valueFontSize + 4
            let formulaHeight = lineHeight + stackSpacing + formulaLabelHeight
            let centerY = barRect.minY + barRect.height / 2 - lineHeight / 2 + formulaHeight / 2
            let actualHeight = lineHeight + stackSpacing + line.height
            let top = centerY - actualHeight / 2
            SkiaIntervalDraw.fillCapsule(
                context,
                CGRect(x: anchorX - lineWidth / 2, y: top, width: lineWidth, height: lineHeight),
                color: marker.color,
                opacity: 0.78 * opacity
            )
            let textTop = top + lineHeight + stackSpacing
            SkiaIntervalText.draw(
                line,
                font: valueFont,
                x: anchorX - line.width / 2,
                baselineY: textTop + line.ascent,
                color: marker.color,
                opacity: 0.78 * opacity,
                context: context
            )
        }
    }

    /// Outside marker used by the zone edge bar: a callout or tick that sits
    /// wholly on the chosen side and never overlaps the bar.
    private static func drawOutsideSegmentedBarMarker(
        _ marker: OverlayComponentResolvedSegmentedBarMarker,
        barRect: CGRect,
        geometry: SegmentedBarGeometry,
        vertical: Bool,
        space: DrawSpace,
        opacity: Double,
        context: OpaquePointer
    ) {
        guard let zoneRect = geometry.rects.first(where: { $0.index == marker.index })?.rect else {
            return
        }
        let cross = vertical ? barRect.width : barRect.height
        let markerScale = min(max(marker.scale, 0.1), 4)
        let startSide = isStartSide(marker.side, vertical: vertical)
        let gap = max(cross * 0.35, 3)
        let stackSpacing = 2.0
        let pillHorizontalPadding = 5.0
        let pillVerticalPadding = 2.0
        let pillCornerRadius = 4.0
        let showsValue = marker.showsValue

        switch marker.role {
        case .current:
            let textSize = max(space.length(marker.font.size), 7)
            let textFont = intervalFont(
                family: resolvedFamily(marker.font.family),
                size: textSize,
                weight: marker.font.weight,
                monospacedDigits: true
            )
            let line = SkiaIntervalText.makeLine(marker.text, font: textFont)
            let pillSize = CGSize(
                width: line.width + pillHorizontalPadding * 2,
                height: line.height + pillVerticalPadding * 2
            )
            let arrowSize = vertical
                ? CGSize(
                    width: max(cross * 0.9, 8) * markerScale,
                    height: max(cross * 1.35, 12) * markerScale
                )
                : CGSize(
                    width: max(cross * 1.35, 12) * markerScale,
                    height: max(cross * 0.9, 8) * markerScale
                )
            // The native module anchors the horizontal callout by its height
            // and the vertical one by a fixed 84px value-pill allowance.
            let markerExtent = max(cross * 0.9, 8) * markerScale
                + (showsValue
                    ? (vertical ? 84 : max(space.length(marker.font.size), 9) + 8)
                    : 0)

            func drawPill(_ rect: CGRect) {
                SkiaIntervalDraw.fillRoundRect(
                    context, rect, radius: pillCornerRadius, color: .black,
                    opacity: 0.55 * opacity
                )
                let textRect = rect.insetBy(
                    dx: pillHorizontalPadding,
                    dy: pillVerticalPadding
                )
                SkiaIntervalText.draw(
                    line,
                    font: textFont,
                    x: textRect.midX - line.width / 2,
                    baselineY: textRect.midY - line.height / 2 + line.ascent,
                    color: marker.color,
                    opacity: opacity,
                    context: context
                )
            }

            if vertical {
                let anchorY = zoneRect.maxY - zoneRect.height * marker.fraction
                let anchorX = startSide
                    ? barRect.minX - markerExtent / 2 - gap
                    : barRect.maxX + markerExtent / 2 + gap
                var totalWidth = arrowSize.width
                if showsValue { totalWidth += pillSize.width + stackSpacing }
                var left = anchorX - totalWidth / 2
                if showsValue && startSide {
                    drawPill(CGRect(
                        x: left, y: anchorY - pillSize.height / 2,
                        width: pillSize.width, height: pillSize.height
                    ))
                    left += pillSize.width + stackSpacing
                }
                let triangle = CGRect(
                    x: left, y: anchorY - arrowSize.height / 2,
                    width: arrowSize.width, height: arrowSize.height
                )
                if startSide {
                    SkiaIntervalDraw.fillTriangle(
                        context,
                        CGPoint(x: triangle.maxX, y: triangle.midY),
                        CGPoint(x: triangle.minX, y: triangle.minY),
                        CGPoint(x: triangle.minX, y: triangle.maxY),
                        color: marker.color,
                        opacity: opacity
                    )
                } else {
                    SkiaIntervalDraw.fillTriangle(
                        context,
                        CGPoint(x: triangle.minX, y: triangle.midY),
                        CGPoint(x: triangle.maxX, y: triangle.minY),
                        CGPoint(x: triangle.maxX, y: triangle.maxY),
                        color: marker.color,
                        opacity: opacity
                    )
                }
                left += arrowSize.width + stackSpacing
                if showsValue && !startSide {
                    drawPill(CGRect(
                        x: left, y: anchorY - pillSize.height / 2,
                        width: pillSize.width, height: pillSize.height
                    ))
                }
                return
            }

            let anchorX = zoneRect.minX + zoneRect.width * marker.fraction
            let anchorY = startSide
                ? barRect.minY - markerExtent / 2 - gap
                : barRect.maxY + markerExtent / 2 + gap
            var totalHeight = arrowSize.height
            if showsValue { totalHeight += pillSize.height + stackSpacing }
            var top = anchorY - totalHeight / 2
            if showsValue && startSide {
                drawPill(CGRect(
                    x: anchorX - pillSize.width / 2, y: top,
                    width: pillSize.width, height: pillSize.height
                ))
                top += pillSize.height + stackSpacing
            }
            let triangle = CGRect(
                x: anchorX - arrowSize.width / 2, y: top,
                width: arrowSize.width, height: arrowSize.height
            )
            if startSide {
                SkiaIntervalDraw.fillTriangle(
                    context,
                    CGPoint(x: triangle.minX, y: triangle.minY),
                    CGPoint(x: triangle.maxX, y: triangle.minY),
                    CGPoint(x: triangle.midX, y: triangle.maxY),
                    color: marker.color,
                    opacity: opacity
                )
            } else {
                SkiaIntervalDraw.fillTriangle(
                    context,
                    CGPoint(x: triangle.midX, y: triangle.minY),
                    CGPoint(x: triangle.maxX, y: triangle.maxY),
                    CGPoint(x: triangle.minX, y: triangle.maxY),
                    color: marker.color,
                    opacity: opacity
                )
            }
            top += arrowSize.height + stackSpacing
            if showsValue && !startSide {
                drawPill(CGRect(
                    x: anchorX - pillSize.width / 2, y: top,
                    width: pillSize.width, height: pillSize.height
                ))
            }

        case .threshold:
            let textSize = max(space.length(marker.font.size) * 0.72, 7) * markerScale
            let textFont = intervalFont(
                family: resolvedFamily(marker.font.family),
                size: textSize,
                weight: marker.font.weight,
                monospacedDigits: true
            )
            let line = SkiaIntervalText.makeLine(marker.text, font: textFont)
            let lineLength = max(cross * 1.35, 10) * markerScale
            let lineThickness = max(1.2 * space.elementScale, 1)
            let labelAndSpacing = textSize + 6

            if vertical {
                let anchorY = zoneRect.maxY - zoneRect.height * marker.fraction
                let offset = startSide ? -labelAndSpacing / 2 : labelAndSpacing / 2
                let totalWidth = line.width + stackSpacing + lineLength
                var left = barRect.midX + offset - totalWidth / 2
                if startSide {
                    SkiaIntervalText.draw(
                        line,
                        font: textFont,
                        x: left,
                        baselineY: anchorY - line.height / 2 + line.ascent,
                        color: marker.color,
                        opacity: 0.78 * opacity,
                        context: context
                    )
                    left += line.width + stackSpacing
                }
                SkiaIntervalDraw.fillCapsule(
                    context,
                    CGRect(
                        x: left,
                        y: anchorY - lineThickness / 2,
                        width: lineLength,
                        height: lineThickness
                    ),
                    color: marker.color,
                    opacity: 0.78 * opacity
                )
                left += lineLength + stackSpacing
                if !startSide {
                    SkiaIntervalText.draw(
                        line,
                        font: textFont,
                        x: left,
                        baselineY: anchorY - line.height / 2 + line.ascent,
                        color: marker.color,
                        opacity: 0.78 * opacity,
                        context: context
                    )
                }
                return
            }

            let anchorX = zoneRect.minX + zoneRect.width * marker.fraction
            let offset = startSide ? -labelAndSpacing / 2 : labelAndSpacing / 2
            let totalHeight = line.height + stackSpacing + lineLength
            var top = barRect.midY + offset - totalHeight / 2
            if startSide {
                SkiaIntervalText.draw(
                    line,
                    font: textFont,
                    x: anchorX - line.width / 2,
                    baselineY: top + line.ascent,
                    color: marker.color,
                    opacity: 0.78 * opacity,
                    context: context
                )
                top += line.height + stackSpacing
            }
            SkiaIntervalDraw.fillCapsule(
                context,
                CGRect(
                    x: anchorX - lineThickness / 2,
                    y: top,
                    width: lineThickness,
                    height: lineLength
                ),
                color: marker.color,
                opacity: 0.78 * opacity
            )
            top += lineLength + stackSpacing
            if !startSide {
                SkiaIntervalText.draw(
                    line,
                    font: textFont,
                    x: anchorX - line.width / 2,
                    baselineY: top + line.ascent,
                    color: marker.color,
                    opacity: 0.78 * opacity,
                    context: context
                )
            }
        }
    }

    // MARK: - Stack layout

    /// Stack layout runs at draw time in pixel space because CoreText advances
    /// are not linear in font size: measuring at design size and scaling the
    /// result drifts from measuring at the final pixel size.
    private struct StackLayout {
        var bounds: CGRect
        var placements: [StackPlacement]
    }

    private struct StackPlacement {
        var node: OverlayComponentResolvedNode
        var origin: CGPoint
        /// Cross-axis extent imposed on a stretched child stack, in pixels.
        var proposal: StackProposal?
    }

    /// Pixel extents a parent imposes on a stretched stack. A `nil` axis keeps
    /// the stack's natural size; a proposal never shrinks a stack.
    private struct StackProposal {
        var width: Double?
        var height: Double?
    }

    private static func drawStack(
        frame: CGRect?,
        direction: OverlayComponentStackDirection,
        spacing: Double,
        crossAlign: OverlayComponentCrossAlignment,
        children: [OverlayComponentResolvedStackChild],
        proposal: StackProposal? = nil,
        context: OpaquePointer,
        space: DrawSpace,
        opacity: Double,
        assets: [String: Data],
        renderContext: OverlayRenderContext
    ) {
        let layout = layoutStack(
            frame: frame,
            direction: direction,
            spacing: spacing,
            crossAlign: crossAlign,
            children: children,
            proposal: proposal,
            space: space
        )
        for placement in layout.placements {
            let origin = nodeOrigin(placement.node)
            var childSpace = space
            childSpace.origin = CGPoint(
                x: layout.bounds.minX + placement.origin.x - origin.x * space.scale,
                y: layout.bounds.minY + placement.origin.y - origin.y * space.scale
            )
            drawStackChild(
                placement.node,
                proposal: placement.proposal,
                context: context,
                space: childSpace,
                opacity: opacity,
                assets: assets,
                renderContext: renderContext
            )
        }
    }

    /// Draws a stack child, forwarding a stretch proposal to child stacks
    /// (including ones wrapped in a node opacity layer).
    private static func drawStackChild(
        _ node: OverlayComponentResolvedNode,
        proposal: StackProposal?,
        context: OpaquePointer,
        space: DrawSpace,
        opacity: Double,
        assets: [String: Data],
        renderContext: OverlayRenderContext
    ) {
        guard let proposal else {
            draw(node, context: context, space: space, opacity: opacity, assets: assets, renderContext: renderContext)
            return
        }
        switch node {
        case let .stack(frame, direction, spacing, crossAlign, children):
            drawStack(
                frame: frame,
                direction: direction,
                spacing: spacing,
                crossAlign: crossAlign,
                children: children,
                proposal: proposal,
                context: context,
                space: space,
                opacity: opacity,
                assets: assets,
                renderContext: renderContext
            )
        case let .opacity(nodeOpacity, content):
            let rect = pixelBounds(content, proposal: proposal, space: space)
            skb_begin_opacity_layer(
                context,
                Float(nodeOpacity),
                Float(rect.minX),
                Float(rect.minY),
                Float(rect.width),
                Float(rect.height)
            )
            drawStackChild(
                content,
                proposal: proposal,
                context: context,
                space: space,
                opacity: opacity,
                assets: assets,
                renderContext: renderContext
            )
            skb_restore(context)
        default:
            draw(node, context: context, space: space, opacity: opacity, assets: assets, renderContext: renderContext)
        }
    }

    private static func flexibleSpacerAllocations(
        children: [OverlayComponentResolvedStackChild],
        available: Double,
        space: DrawSpace
    ) -> [Double] {
        var allocations = [Double](repeating: 0, count: children.count)
        var pending: [Int] = []
        for (index, child) in children.enumerated() {
            if case .spacer(nil, _) = child.node { pending.append(index) }
        }
        var remaining = max(available, 0)
        while !pending.isEmpty {
            let share = remaining / Double(pending.count)
            let pinned = pending.filter { index in
                guard case .spacer(_, let minimum) = children[index].node else { return false }
                return minimum * space.scale > share + 0.0001
            }
            if pinned.isEmpty {
                for index in pending { allocations[index] = max(share, 0) }
                break
            }
            for index in pinned {
                guard case .spacer(_, let minimum) = children[index].node else { continue }
                let value = max(minimum * space.scale, 0)
                allocations[index] = value
                remaining -= value
            }
            pending.removeAll { pinned.contains($0) }
            remaining = max(remaining, 0)
        }
        return allocations
    }

    private static func intervalRows(
        _ text: OverlayComponentResolvedTextRows,
        space: DrawSpace,
        opacity: Double
    ) -> [SkiaIntervalText.Row] {
        text.rows.map { row in
            SkiaIntervalText.Row(
                items: row.runs.map { run in
                    SkiaIntervalText.RowItem(
                        text: run.text,
                        font: intervalFont(
                            family: resolvedFamily(run.font.family),
                            size: space.length(run.font.size),
                            weight: run.font.weight,
                            monospacedDigits: run.monospacedDigits
                        ),
                        color: run.color,
                        opacity: opacity * run.opacity,
                        minimumScaleFactor: run.minimumScaleFactor,
                        verticalPadding: space.length(run.verticalPadding)
                    )
                },
                spacing: space.length(row.spacing),
                alignment: row.alignment == .center ? .center : .firstTextBaseline
            )
        }
    }

    private static func textRowsSize(
        _ text: OverlayComponentResolvedTextRows,
        space: DrawSpace
    ) -> CGSize {
        guard let maxWidth = text.maxWidth else { return .zero }
        let width = space.length(maxWidth)
        let measured = SkiaIntervalText.rowsSize(
            intervalRows(text, space: space, opacity: 1),
            maxWidth: width,
            spacing: space.length(text.spacing)
        )
        return CGSize(width: width, height: measured.height)
    }

    private static func textRowsRect(
        _ frame: CGRect,
        text: OverlayComponentResolvedTextRows,
        autoSize: Bool,
        space: DrawSpace
    ) -> CGRect {
        guard autoSize else { return space.rect(frame) }
        return CGRect(
            origin: space.point(frame.origin),
            size: textRowsSize(text, space: space)
        )
    }

    private struct ColumnsMetrics {
        var itemWidth: Double
        var dividerWidth: Double
        var dividerHeight: Double
        var height: Double
        var childHeights: [Double]
        var childWidths: [Double]
    }

    private static func columnsMetrics(
        width: Double,
        divider: OverlayComponentResolvedDivider?,
        children: [OverlayComponentResolvedNode],
        space: DrawSpace
    ) -> ColumnsMetrics {
        let count = children.count
        guard count > 0 else {
            return ColumnsMetrics(
                itemWidth: 0, dividerWidth: 0, dividerHeight: 0,
                height: 0, childHeights: [], childWidths: []
            )
        }
        let dividerHeight = count > 1
            ? max(divider?.height ?? 0, 0) * space.scale
            : 0
        let dividerWidth = dividerHeight > 0
            ? max(max(divider?.width ?? 1, 0.5) * space.scale, 0)
            : 0
        let itemWidth = max(
            (width * space.scale - dividerWidth * Double(max(count - 1, 0))) / Double(count),
            1
        )
        let proposal = StackProposal(width: itemWidth)
        let childSizes = children.map {
            intrinsicSize(of: $0, proposal: proposal, space: space)
        }
        let childHeights = childSizes.map { Double($0.height) }
        let childWidths = childSizes.map { Double($0.width) }
        return ColumnsMetrics(
            itemWidth: itemWidth,
            dividerWidth: dividerWidth,
            dividerHeight: dividerHeight,
            height: max(childHeights.max() ?? 0, dividerHeight),
            childHeights: childHeights,
            childWidths: childWidths
        )
    }

    private static func columnsHeight(
        width: Double,
        divider: OverlayComponentResolvedDivider?,
        children: [OverlayComponentResolvedNode],
        space: DrawSpace
    ) -> Double {
        columnsMetrics(width: width, divider: divider, children: children, space: space).height
    }

    private static func drawColumns(
        width: Double,
        divider: OverlayComponentResolvedDivider?,
        children: [OverlayComponentResolvedNode],
        context: OpaquePointer,
        space: DrawSpace,
        opacity: Double,
        assets: [String: Data],
        renderContext: OverlayRenderContext
    ) {
        let metrics = columnsMetrics(
            width: width,
            divider: divider,
            children: children,
            space: space
        )
        guard metrics.itemWidth > 0 else { return }
        let origin = space.point(.zero)
        var x = 0.0
        for (index, child) in children.enumerated() {
            if index > 0 {
                if metrics.dividerWidth > 0, let divider {
                    let rect = CGRect(
                        x: origin.x + x,
                        y: origin.y + (metrics.height - metrics.dividerHeight) / 2,
                        width: metrics.dividerWidth,
                        height: metrics.dividerHeight
                    )
                    skb_fill_round_rect(
                        context,
                        Float(rect.minX), Float(rect.minY),
                        Float(rect.width), Float(rect.height),
                        0,
                        Float(divider.color.red), Float(divider.color.green),
                        Float(divider.color.blue),
                        Float(min(max(divider.color.alpha * divider.opacity * opacity, 0), 1))
                    )
                }
                x += metrics.dividerWidth
            }
            let childHeight = metrics.childHeights[index]
            let childWidth = min(metrics.childWidths[index], metrics.itemWidth)
            let y = (metrics.height - childHeight) / 2
            let childX = x + (metrics.itemWidth - childWidth) / 2
            let childOrigin = nodeOrigin(child)
            var childSpace = space
            childSpace.origin = CGPoint(
                x: origin.x + childX - childOrigin.x * space.scale,
                y: origin.y + y - childOrigin.y * space.scale
            )
            drawStackChild(
                child,
                proposal: StackProposal(width: metrics.itemWidth),
                context: context,
                space: childSpace,
                opacity: opacity,
                assets: assets,
                renderContext: renderContext
            )
            x += metrics.itemWidth
        }
    }

    private static func layoutStack(
        frame: CGRect?,
        direction: OverlayComponentStackDirection,
        spacing: Double,
        crossAlign: OverlayComponentCrossAlignment,
        children: [OverlayComponentResolvedStackChild],
        proposal: StackProposal? = nil,
        space: DrawSpace
    ) -> StackLayout {
        let horizontal = direction == .horizontal
        let spacingPixels = spacing * space.scale
        var flexibleCount = 0
        let sizes: [CGSize] = children.map { child in
            if case .spacer(let length, _) = child.node {
                if length == nil { flexibleCount += 1 }
                let main = (length ?? 0) * space.scale
                return horizontal ? CGSize(width: main, height: 0) : CGSize(width: 0, height: main)
            }
            return intrinsicSize(of: child.node, space: space)
        }
        let mainSizes = sizes.map { horizontal ? $0.width : $0.height }
        let crossSizes = sizes.map { horizontal ? $0.height : $0.width }
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
            let natural = horizontal
                ? CGSize(width: contentMain, height: contentCross)
                : CGSize(width: contentCross, height: contentMain)
            containerSize = CGSize(
                width: max(proposal?.width ?? natural.width, natural.width),
                height: max(proposal?.height ?? natural.height, natural.height)
            )
        }
        let availableMain = horizontal ? containerSize.width : containerSize.height
        let availableCross = horizontal ? containerSize.height : containerSize.width
        let flexAllocations = flexibleSpacerAllocations(
            children: children,
            available: max(availableMain - contentMain, 0),
            space: space
        )
        var placements: [StackPlacement] = []
        var cursor = 0.0
        for (index, child) in children.enumerated() {
            var childMain = mainSizes[index]
            childMain += flexAllocations[index]

            let childCross = crossSizes[index]
            let alignment = child.alignSelf ?? crossAlign
            let crossOffset: Double
            switch alignment {
            case .start, .stretch:
                crossOffset = 0
            case .center:
                crossOffset = (availableCross - childCross) / 2
            case .end:
                crossOffset = availableCross - childCross
            }
            let childProposal: StackProposal? = alignment == .stretch
                ? (horizontal
                    ? StackProposal(width: nil, height: availableCross)
                    : StackProposal(width: availableCross, height: nil))
                : nil
            let origin = horizontal
                ? CGPoint(x: cursor, y: crossOffset)
                : CGPoint(x: crossOffset, y: cursor)
            placements.append(StackPlacement(node: child.node, origin: origin, proposal: childProposal))
            cursor += childMain + spacingPixels
        }
        return StackLayout(
            bounds: CGRect(origin: contentOrigin, size: containerSize),
            placements: placements
        )
    }

    private static func intrinsicSize(
        of node: OverlayComponentResolvedNode,
        proposal: StackProposal? = nil,
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
                proposal: proposal,
                space: space
            ).bounds.size

        case let .textRows(frame, text, autoSize):
            guard autoSize else {
                return CGSize(
                    width: frame.width * space.scale,
                    height: frame.height * space.scale
                )
            }
            return textRowsSize(text, space: space)

        case let .columns(width, divider, children):
            return CGSize(
                width: width * space.scale,
                height: columnsHeight(
                    width: width,
                    divider: divider,
                    children: children,
                    space: space
                )
            )

        case .opacity(_, let content):
            return intrinsicSize(of: content, proposal: proposal, space: space)

        default:
            let rect = nodeBounds(node)
            return CGSize(
                width: rect.width * space.scale,
                height: rect.height * space.scale
            )
        }
    }

    private static func intervalFont(
        family: String,
        size: Double,
        weight: OverlayComponentFontWeight,
        monospacedDigits: Bool
    ) -> NSFont {
        let font = SkiaTextComposer.font(family: family, size: size, weight: weight.appKitWeight)
        guard monospacedDigits else { return font }
        let descriptor = font.fontDescriptor.addingAttributes([
            .featureSettings: [[
                NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
                NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector
            ]]
        ])
        return NSFont(descriptor: descriptor, size: size) ?? font
    }

    private static func nodeOrigin(_ node: OverlayComponentResolvedNode) -> CGPoint {
        switch node {
        case let .group(frame, _, _, _, _, _): frame.origin
        case let .stack(frame, _, _, _, _): frame?.origin ?? .zero
        case .opacity(_, let content): nodeOrigin(content)
        case let .rect(frame, _, _, _, _): frame.origin
        case .circle: .zero
        case .line: .zero
        case .polyline: .zero
        case .path: .zero
        case let .text(frame, _, _, _, _, _, _, _, _, _): frame.origin
        case let .richText(frame, _): frame.origin
        case let .textRows(frame, _, _): frame.origin
        case .columns: .zero
        case let .image(frame, _, _): frame.origin
        case let .symbol(frame, _, _, _, _, _): frame.origin
        case .spacer(_, _): .zero
        case let .gradientRect(frame, _, _, _, _): frame.origin
        case let .sparkline(frame, _, _, _, _, _): frame.origin
        case let .progressBar(frame, _, _, _, _): frame.origin
        case let .arc(frame, _, _, _, _, _, _, _, _): frame.origin
        case let .segmentedBar(frame, _, _, _, _, _, _, _, _, _, _, _): frame.origin
        case let .timelineStrip(frame, _): frame.origin
        case let .runningGauge(frame, _): frame.origin
        case let .distanceTimeline(frame, _, _): frame.origin
        case let .elevationChart(frame, _, _, _, _): frame.origin
        case let .routeMap(frame, _): frame.origin
        case let .weatherWidget(frame, _): frame.origin
        }
    }

    /// Bounds of everything a node paints, including a stroke's outer half.
    /// An opacity layer must cover the paint, not just the geometric frame, or
    /// a centered stroke is clipped along the frame edge.
    private static func paintBounds(
        _ node: OverlayComponentResolvedNode,
        space: DrawSpace
    ) -> CGRect {
        switch node {
        case let .rect(_, _, _, stroke, strokeWidth) where stroke != nil:
            let outset = space.length(strokeWidth) / 2
            return pixelBounds(node, space: space).insetBy(dx: -outset, dy: -outset)
        case let .circle(center, radius, _, stroke, strokeWidth) where stroke != nil:
            let extent = space.length(radius + strokeWidth / 2)
            let point = space.point(center)
            return CGRect(x: point.x - extent, y: point.y - extent,
                          width: extent * 2, height: extent * 2)
        default:
            return pixelBounds(node, space: space)
        }
    }

    private static func pixelBounds(
        _ node: OverlayComponentResolvedNode,
        proposal: StackProposal? = nil,
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
                proposal: proposal,
                space: space
            ).bounds
        case .opacity(_, let content):
            return pixelBounds(content, proposal: proposal, space: space)
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
        case let .textRows(frame, text, autoSize):
            let rect = textRowsRect(frame, text: text, autoSize: autoSize, space: space)
            return CGRect(origin: space.point(frame.origin), size: rect.size)
        case let .columns(width, divider, children):
            return CGRect(
                origin: space.point(.zero),
                size: CGSize(
                    width: width * space.scale,
                    height: columnsHeight(
                        width: width,
                        divider: divider,
                        children: children,
                        space: space
                    )
                )
            )
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
        case let .group(frame, _, _, _, _, _): frame
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
        case let .richText(frame, _): frame
        case let .textRows(frame, _, _): frame
        case .columns: .zero
        case let .image(frame, _, _): frame
        case let .symbol(frame, _, _, _, _, _): frame
        case .spacer(_, _): .zero
        case let .gradientRect(frame, _, _, _, _): frame
        case let .sparkline(frame, _, _, _, _, _): frame
        case let .progressBar(frame, _, _, _, _): frame
        case let .arc(frame, _, _, _, _, _, _, _, _): frame
        case let .segmentedBar(frame, _, _, _, _, _, _, _, _, _, _, _): frame
        case let .timelineStrip(frame, _): frame
        case let .runningGauge(frame, _): frame
        case let .distanceTimeline(frame, _, _): frame
        case let .elevationChart(frame, _, _, _, _): frame
        case let .routeMap(frame, _): frame
        case let .weatherWidget(frame, _): frame
        }
    }

    // MARK: - Running gauge

    private static func drawRunningGauge(
        frame: CGRect,
        gauge: OverlayComponentResolvedGauge,
        space: DrawSpace,
        context: OpaquePointer
    ) {
        let diameter = frame.width
        guard diameter > 0, frame.height > 0 else { return }
        let style = gauge.style
        let regionFrames = RunningGaugeLayoutEngine.regionFrames(
            for: style.layoutPreset,
            in: CGSize(width: diameter, height: diameter)
        )
        let baseValueSize = diameter * 0.145
        let baseLabelSize = diameter * 0.038
        let baseUnitSize = diameter * 0.045
        let regions: [OverlayRunningGaugeRegionLayout] = regionFrames.compactMap { regionFrame in
            guard let region = gauge.regions.first(where: { $0.config.region == regionFrame.region }) else {
                return nil
            }
            return OverlayRunningGaugeRegionLayout(
                config: region.config,
                rect: CGRect(
                    x: frame.minX + regionFrame.rect.minX,
                    y: frame.minY + regionFrame.rect.minY,
                    width: regionFrame.rect.width,
                    height: regionFrame.rect.height
                ),
                components: region.components,
                valueFontSize: max(baseValueSize * region.config.valueFontScale, 8),
                labelFontSize: max(baseLabelSize * (region.config.labelFontScale / 0.32), 7),
                unitFontSize: max(baseUnitSize * (region.config.unitFontScale / 0.42), 7)
            )
        }
        let layout = OverlayRunningGaugeRenderLayout(
            style: style,
            rect: frame,
            diameter: diameter,
            progress: min(max(gauge.progress, 0), 1),
            regions: regions,
            outerRingWidth: max(diameter * style.outerRingWidthScale, 1.5),
            progressRingWidth: max(diameter * style.progressRingWidthScale, 1.5),
            tickLength: diameter * 0.025,
            majorTickLength: diameter * 0.040,
            safeRadius: diameter * 0.40
        )
        let canvas = SkiaChartsCanvas(context: context, size: frame.size)
        // The host applies the element's opacity, glow and shadow once around
        // the whole component. The chart renderer applies element effects
        // itself, so hand it an effect-free element to avoid a second blend.
        var hostStyle = OverlayStyle.default
        hostStyle.shadowEnabled = false
        hostStyle.glowEnabled = false
        let element = OverlayElement(
            type: .runningGauge,
            position: .zero,
            scale: space.elementScale,
            style: hostStyle
        )
        SkiaRunningGaugeRenderer.draw(canvas: canvas, element: element, layout: layout)
    }

    // MARK: - Distance timeline

    private static func drawDistanceTimeline(
        frame: CGRect,
        style: DistanceTimelineStyle,
        valueFontSize: Double,
        space: DrawSpace,
        renderContext: OverlayRenderContext,
        context: OpaquePointer
    ) {
        guard frame.width > 0, frame.height > 0 else { return }
        // The native layout sizes the element from its style. Feed it the
        // node's frame so preview and export reuse the same track, labels,
        // marker and stats-bar layout.
        var resolvedStyle = style
        let scale = max(renderContext.canvasScale * space.elementScale, 0.0001)
        resolvedStyle.width = frame.width / scale
        resolvedStyle.height = frame.height / scale
        var hostStyle = OverlayStyle.default
        hostStyle.shadowEnabled = false
        hostStyle.glowEnabled = false
        hostStyle.fontSize = valueFontSize
        // The native module paints its background and border from the shared
        // element style. Map the node's declarative fields onto it and drop
        // the host background padding so the frame is the painted bounds.
        hostStyle.backgroundEnabled = resolvedStyle.backgroundEnabled
        hostStyle.backgroundColor = resolvedStyle.backgroundColor
        hostStyle.backgroundOpacity = resolvedStyle.backgroundOpacity
        hostStyle.backgroundPaddingX = 0
        hostStyle.backgroundPaddingY = 0
        hostStyle.borderEnabled = resolvedStyle.borderEnabled
        hostStyle.borderColor = resolvedStyle.borderColor
        hostStyle.borderOpacity = resolvedStyle.borderOpacity
        hostStyle.borderWidth = resolvedStyle.borderWidth
        hostStyle.distanceTimeline = resolvedStyle
        let element = OverlayElement(
            type: .distanceTimeline,
            position: CGPoint(
                x: frame.midX / max(renderContext.canvasSize.width, 1),
                y: frame.midY / max(renderContext.canvasSize.height, 1)
            ),
            scale: space.elementScale,
            style: hostStyle
        )
        let layout = OverlayRenderModel.distanceTimelineLayout(for: element, in: renderContext)
        let canvas = SkiaChartsCanvas(context: context, size: frame.size)
        SkiaDistanceTimelineRenderer.draw(canvas: canvas, element: element, layout: layout)
    }

    // MARK: - Elevation chart

    private static func drawElevationChart(
        frame: CGRect,
        style: ElevationChartStyle,
        valueFontSize: Double,
        fontName: String,
        foregroundColor: OverlayColor,
        space: DrawSpace,
        renderContext: OverlayRenderContext,
        context: OpaquePointer
    ) {
        guard frame.width > 0, frame.height > 0 else { return }
        var resolvedStyle = style
        let scale = max(renderContext.canvasScale * space.elementScale, 0.0001)
        resolvedStyle.width = frame.width / scale
        resolvedStyle.height = frame.height / scale
        var hostStyle = OverlayStyle.default
        hostStyle.shadowEnabled = false
        hostStyle.glowEnabled = false
        hostStyle.fontName = fontName
        hostStyle.fontSize = valueFontSize
        hostStyle.foregroundColor = foregroundColor
        hostStyle.backgroundEnabled = resolvedStyle.backgroundEnabled
        hostStyle.backgroundColor = resolvedStyle.backgroundColor
        hostStyle.backgroundOpacity = resolvedStyle.backgroundOpacity
        hostStyle.backgroundRadius = resolvedStyle.cornerRadius
        hostStyle.backgroundPaddingX = 0
        hostStyle.backgroundPaddingY = 0
        hostStyle.borderEnabled = resolvedStyle.borderEnabled
        hostStyle.borderOpacity = resolvedStyle.borderOpacity
        hostStyle.elevationChart = resolvedStyle
        let element = OverlayElement(
            type: .elevationChart,
            position: CGPoint(
                x: frame.midX / max(renderContext.canvasSize.width, 1),
                y: frame.midY / max(renderContext.canvasSize.height, 1)
            ),
            scale: space.elementScale,
            style: hostStyle
        )
        let layout = OverlayRenderModel.elevationChartLayout(for: element, in: renderContext)
        let canvas = SkiaChartsCanvas(context: context, size: frame.size)
        SkiaElevationChartRenderer.draw(canvas: canvas, element: element, layout: layout)
    }

    // MARK: - Route map

    private static func drawRouteMap(
        frame: CGRect,
        style: OverlayStyle,
        space: DrawSpace,
        renderContext: OverlayRenderContext,
        context: OpaquePointer
    ) {
        guard frame.width > 0, frame.height > 0 else { return }
        var hostStyle = style
        let scale = max(renderContext.canvasScale * space.elementScale, 0.0001)
        hostStyle.routeMapWidth = frame.width / scale
        hostStyle.routeMapHeight = frame.height / scale
        hostStyle.backgroundEnabled = hostStyle.routeMapBackgroundStyle != .none
        hostStyle.backgroundPaddingX = 0
        hostStyle.backgroundPaddingY = 0
        let element = OverlayElement(
            type: .routeMap,
            position: CGPoint(
                x: frame.midX / max(renderContext.canvasSize.width, 1),
                y: frame.midY / max(renderContext.canvasSize.height, 1)
            ),
            scale: space.elementScale,
            style: hostStyle
        )
        let layout = OverlayRenderModel.routeMapLayout(for: element, in: renderContext)
        // The host module owns the map snapshot, mask and stats-bar drawing.
        // Components carry no render assets of their own, so an empty store
        // falls back to the module's generated background.
        SkiaRouteMapModule.draw(
            element,
            renderContext: renderContext,
            context: context,
            assets: renderContext.renderAssets ?? SkiaRenderAssets()
        )
    }

    // MARK: - Weather widget

    private static func drawWeatherWidget(
        frame: CGRect,
        style: WeatherWidgetStyle,
        space: DrawSpace,
        renderContext: OverlayRenderContext,
        context: OpaquePointer
    ) {
        guard frame.width > 0, frame.height > 0 else { return }
        var hostStyle = OverlayStyle.default
        // The host applies the element's opacity, glow and shadow once around
        // the whole component; the weather module must not blend them again.
        hostStyle.shadowEnabled = false
        hostStyle.glowEnabled = false
        let scale = max(renderContext.canvasScale * space.elementScale, 0.0001)
        var widget = style
        widget.width = frame.width / scale
        widget.height = frame.height / scale
        hostStyle.weatherWidget = widget
        let element = OverlayElement(
            type: .weatherWidget,
            position: CGPoint(
                x: frame.midX / max(renderContext.canvasSize.width, 1),
                y: frame.midY / max(renderContext.canvasSize.height, 1)
            ),
            scale: space.elementScale,
            style: hostStyle
        )
        let assets = renderContext.renderAssets ?? SkiaRenderAssets()
        // Components do not run the host's preload pass over weather elements,
        // so register the bundled condition icon for this frame's pixel size
        // without evicting icons the host preloaded for native cards.
        SkiaRenderAssets.registerWeatherIcons(
            for: [element],
            activity: renderContext.activity,
            canvasSize: renderContext.canvasSize,
            into: assets
        )
        SkiaWeatherWidgetModule.draw(
            element,
            renderContext: renderContext,
            context: context,
            assets: assets
        )
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
        case .thin: .thin
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
