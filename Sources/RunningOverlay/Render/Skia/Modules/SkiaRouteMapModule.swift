#if canImport(CSkiaBridge)
import AppKit
import CSkiaBridge
import CoreGraphics
import Foundation

/// Skia drawing for the Route Map overlay.
///
/// Layout, projection, and style resolution stay in `OverlayRenderModel` and
/// `OverlayRouteMapRenderLayout`; this module only reproduces the SwiftUI
/// oracle's draw order. All images come from `SkiaRenderAssets` so a frame
/// performs no rasterization or network work.
enum SkiaRouteMapModule {
    static func preloadAssets(
        elements: [OverlayElement],
        activity: ActivityTimeline,
        canvasSize: CGSize,
        mapSnapshots: [MapSnapshotRequest: NSImage],
        into assets: SkiaRenderAssets
    ) {
        SkiaRenderAssets.preloadRouteMaps(
            elements: elements,
            activity: activity,
            canvasSize: canvasSize,
            mapSnapshots: mapSnapshots,
            into: assets
        )
    }

    static func draw(
        _ element: OverlayElement,
        renderContext: OverlayRenderContext,
        context: OpaquePointer,
        assets: SkiaRenderAssets
    ) {
        let layout = OverlayRenderModel.routeMapLayout(
            for: element,
            in: renderContext
        )
        let rect = layout.rect
        guard rect.width > 0, rect.height > 0 else { return }

        let usesOpacityLayer = element.opacity < 0.999
        if usesOpacityLayer {
            skb_begin_opacity_layer(
                context,
                Float(element.opacity),
                0, 0,
                Float(renderContext.canvasSize.width),
                Float(renderContext.canvasSize.height)
            )
        }
        defer {
            if usesOpacityLayer {
                skb_restore(context)
            }
        }

        beginContainerShadow(
            element: element,
            layout: layout,
            context: context
        )

        // Masked map content: container fill, map background, route, markers.
        skb_save(context)
        applyMask(
            element: element,
            layout: layout,
            context: context,
            assets: assets
        )
        drawContainerFill(
            element: element,
            layout: layout,
            context: context
        )
        drawMapBackground(
            element: element,
            layout: layout,
            context: context,
            assets: assets
        )
        drawRoute(
            element: element,
            layout: layout,
            context: context,
            assets: assets
        )
        skb_restore(context)

        drawBorder(
            element: element,
            layout: layout,
            context: context
        )

        skb_restore(context) // container shadow layer (or plain save)

        drawStatsBar(
            element: element,
            layout: layout,
            context: context,
            assets: assets
        )
    }

    // MARK: - Mask and container

    private static func applyMask(
        element: OverlayElement,
        layout: OverlayRouteMapRenderLayout,
        context: OpaquePointer,
        assets: SkiaRenderAssets
    ) {
        let rect = layout.rect
        if layout.edgeFade == .fadeOut, layout.fadeAmount > 0.001 {
            let key = SkiaRenderAssets.ImageSource.routeMask(
                shape: layout.shape,
                cornerRadius: Int(layout.cornerRadius.rounded()),
                edgeFade: layout.edgeFade,
                fadeAmountMilli: Int((layout.fadeAmount * 1000).rounded()),
                pixelWidth: max(Int(rect.width.rounded(.up)), 1),
                pixelHeight: max(Int(rect.height.rounded(.up)), 1)
            )
            if let mask = assets.image(for: key) {
                skb_clip_image_mask(
                    context,
                    mask,
                    Float(rect.minX),
                    Float(rect.minY),
                    Float(rect.width),
                    Float(rect.height)
                )
                return
            }
            // Missing preloaded mask: fall back to the hard shape rather than
            // rasterizing during a frame.
        }
        clipShape(
            layout.shape,
            rect: rect,
            cornerRadius: layout.cornerRadius,
            context: context
        )
    }

    private static func clipShape(
        _ shape: OverlayRouteMapShape,
        rect: CGRect,
        cornerRadius: Double,
        context: OpaquePointer
    ) {
        switch shape {
        case .circle:
            skb_clip_circle(
                context,
                Float(rect.midX),
                Float(rect.midY),
                Float(rect.width / 2)
            )
        case .square:
            skb_clip_round_rect(
                context,
                Float(rect.minX),
                Float(rect.minY),
                Float(rect.width),
                Float(rect.height),
                Float(cornerRadius)
            )
        }
    }

    private static func drawContainerFill(
        element: OverlayElement,
        layout: OverlayRouteMapRenderLayout,
        context: OpaquePointer
    ) {
        guard element.style.backgroundEnabled else { return }
        let rect = layout.rect
        // SwiftUI fills a RoundedRectangle at layout.cornerRadius and relies on
        // the outer shape mask; circles have cornerRadius 0.
        skb_fill_round_rect(
            context,
            Float(rect.minX),
            Float(rect.minY),
            Float(rect.width),
            Float(rect.height),
            Float(layout.cornerRadius),
            Float(element.style.backgroundColor.red),
            Float(element.style.backgroundColor.green),
            Float(element.style.backgroundColor.blue),
            Float(element.style.backgroundOpacity)
        )
    }

    private static func beginContainerShadow(
        element: OverlayElement,
        layout: OverlayRouteMapRenderLayout,
        context: OpaquePointer
    ) {
        let style = element.style
        var sigmas: [Float] = []
        var dxs: [Float] = []
        var dys: [Float] = []
        var rgba: [Float] = []

        func add(_ sigma: Double, _ dx: Double, _ dy: Double, _ alpha: Double) {
            guard alpha > 0, sigma >= 0 else { return }
            sigmas.append(Float(sigma))
            dxs.append(Float(dx))
            dys.append(Float(dy))
            rgba.append(contentsOf: [
                Float(style.shadowColor.red),
                Float(style.shadowColor.green),
                Float(style.shadowColor.blue),
                Float(alpha),
            ])
        }

        if style.shadowEnabled, style.shadowOpacity > 0 {
            let radius = style.shadowRadius
            let opacity = style.shadowOpacity
            let thickness = style.shadowThickness
            add(radius, style.shadowOffsetX, style.shadowOffsetY, opacity)
            if thickness > 1 {
                add(
                    radius * 0.72,
                    style.shadowOffsetX,
                    style.shadowOffsetY,
                    opacity * max(thickness - 1, 0) * 0.32
                )
            }
            if thickness > 2 {
                add(
                    radius * 0.48,
                    style.shadowOffsetX,
                    style.shadowOffsetY,
                    opacity * max(thickness - 2, 0) * 0.22
                )
            }
        }

        guard !sigmas.isEmpty else {
            skb_save(context)
            return
        }

        let rect = layout.rect
        var pad = 0.0
        for index in sigmas.indices {
            pad = max(
                pad,
                Double(sigmas[index]) * 3
                    + max(abs(Double(dxs[index])), abs(Double(dys[index])))
            )
        }
        sigmas.withUnsafeBufferPointer { sigmas in
            dxs.withUnsafeBufferPointer { dxs in
                dys.withUnsafeBufferPointer { dys in
                    rgba.withUnsafeBufferPointer { rgba in
                        skb_begin_shadow_chain(
                            context,
                            Int32(sigmas.count),
                            sigmas.baseAddress,
                            dxs.baseAddress,
                            dys.baseAddress,
                            rgba.baseAddress,
                            Float(rect.minX - pad),
                            Float(rect.minY - pad),
                            Float(rect.width + pad * 2),
                            Float(rect.height + pad * 2)
                        )
                    }
                }
            }
        }
    }

    private static func drawBorder(
        element: OverlayElement,
        layout: OverlayRouteMapRenderLayout,
        context: OpaquePointer
    ) {
        guard element.style.borderEnabled else { return }
        let rect = layout.rect
        let radius = layout.shape == .circle
            ? rect.width / 2
            : layout.cornerRadius
        skb_stroke_round_rect(
            context,
            Float(rect.minX),
            Float(rect.minY),
            Float(rect.width),
            Float(rect.height),
            Float(radius),
            Float(element.style.borderWidth * element.scale),
            Float(element.style.borderColor.red),
            Float(element.style.borderColor.green),
            Float(element.style.borderColor.blue),
            Float(element.style.borderOpacity)
        )
    }

    // MARK: - Map background

    private static func drawMapBackground(
        element: OverlayElement,
        layout: OverlayRouteMapRenderLayout,
        context: OpaquePointer,
        assets: SkiaRenderAssets
    ) {
        let rect = layout.rect
        if layout.provider == .mapKit,
           let request = RouteMapSnapshotRequestBuilder.request(
               for: element,
               layout: layout
           ) {
            let key = SkiaRenderAssets.ImageSource.mapSnapshot(
                request,
                pixelWidth: max(Int(rect.width.rounded()), 1),
                pixelHeight: max(Int(rect.height.rounded()), 1)
            )
            if let image = assets.image(for: key) {
                skb_draw_image_handle(
                    context,
                    image,
                    Float(rect.minX),
                    Float(rect.minY),
                    Float(rect.width),
                    Float(rect.height),
                    Float(layout.mapOpacity),
                    0, 0, 0, 0
                )
                return
            }
        }

        guard element.style.routeMapBackgroundStyle != .none else { return }
        let color = gridColor(element.style.routeMapBackgroundStyle)
        let step = max(rect.width / 6, 18)
        var x = rect.minX + step
        while x < rect.maxX {
            skb_stroke_line(
                context,
                Float(x), Float(rect.minY),
                Float(x), Float(rect.maxY),
                1,
                Float(color.red), Float(color.green), Float(color.blue), Float(color.alpha)
            )
            x += step
        }
        var y = rect.minY + step
        while y < rect.maxY {
            skb_stroke_line(
                context,
                Float(rect.minX), Float(y),
                Float(rect.maxX), Float(y),
                1,
                Float(color.red), Float(color.green), Float(color.blue), Float(color.alpha)
            )
            y += step
        }
    }

    private static func gridColor(
        _ style: OverlayRouteMapBackgroundStyle
    ) -> OverlayColor {
        switch style {
        case .light:
            return OverlayColor(red: 0, green: 0, blue: 0, alpha: 0.10)
        case .terrain:
            return OverlayColor(red: 0, green: 1, blue: 0, alpha: 0.18)
        case .satellite:
            return OverlayColor(red: 1, green: 1, blue: 1, alpha: 0.06)
        case .none, .dark:
            return OverlayColor(red: 1, green: 1, blue: 1, alpha: 0.08)
        }
    }

    // MARK: - Route and markers

    private static func drawRoute(
        element: OverlayElement,
        layout: OverlayRouteMapRenderLayout,
        context: OpaquePointer,
        assets: SkiaRenderAssets
    ) {
        let points = layout.projectedPoints
        guard points.count > 1 else {
            drawNoGPS(
                element: element,
                layout: layout,
                context: context,
                assets: assets
            )
            return
        }

        guard let path = makePath(points) else { return }
        defer { skb_path_destroy(path) }

        let lineWidth = layout.lineWidth
        let foreground = element.style.foregroundColor

        // Underlay.
        skb_draw_path(
            context,
            path,
            0,
            0, 0, 0, 0.55,
            Float(lineWidth + 3),
            1, 1, 0, 0
        )

        // Glow.
        if layout.glowEnabled {
            skb_begin_blur_layer(
                context,
                Float(layout.glowRadius),
                Float(layout.rect.minX),
                Float(layout.rect.minY),
                Float(layout.rect.width),
                Float(layout.rect.height)
            )
            skb_draw_path(
                context,
                path,
                0,
                Float(foreground.red),
                Float(foreground.green),
                Float(foreground.blue),
                0.55,
                Float(lineWidth * 2.3),
                1, 1, 0, 0
            )
            skb_restore(context)
        }

        // Main stroke.
        if element.style.routeMapColorMode == .gradient {
            drawGradientStroke(
                element: element,
                layout: layout,
                points: points,
                path: path,
                context: context
            )
        } else {
            skb_draw_path(
                context,
                path,
                0,
                Float(foreground.red),
                Float(foreground.green),
                Float(foreground.blue),
                Float(foreground.alpha),
                Float(lineWidth),
                1, 1, 0, 0
            )
        }

        if element.style.routeMapStartMarkerStyle != .hidden,
           let start = points.first {
            drawMarker(
                start,
                color: element.style.routeMapStartMarkerColor,
                lineWidth: lineWidth,
                sizeMultiplier: 1,
                context: context
            )
        }
        if element.style.routeMapEndMarkerStyle != .hidden,
           let end = points.last {
            drawMarker(
                end,
                color: element.style.routeMapEndMarkerColor,
                lineWidth: lineWidth,
                sizeMultiplier: 1,
                context: context
            )
        }
        if element.style.routeMapRunnerMarkerStyle != .hidden,
           let current = layout.projectedCurrentPoint {
            drawMarker(
                current,
                color: element.style.routeMapRunnerDotColor,
                lineWidth: lineWidth,
                sizeMultiplier: 1.18,
                context: context
            )
        }
    }

    /// SwiftUI's `LinearGradient(.leading -> .trailing)` is applied to a shape
    /// that occupies the whole map content frame, so the endpoints are
    /// `layout.contentRect`, not the tight route bounds. The golden
    /// `route-gradient-space` pins this interpretation.
    private static func drawGradientStroke(
        element: OverlayElement,
        layout: OverlayRouteMapRenderLayout,
        points: [CGPoint],
        path: OpaquePointer,
        context: OpaquePointer
    ) {
        let content = layout.contentRect
        guard content.width > 0 else { return }
        let start = element.style.routeMapGradientStart
        let middle = element.style.routeMapGradientMiddle
        let end = element.style.routeMapGradientEnd
        let stops: [Float] = [
            0,
            Float(start.red), Float(start.green), Float(start.blue), Float(start.alpha),
            0.5,
            Float(middle.red), Float(middle.green), Float(middle.blue), Float(middle.alpha),
            1,
            Float(end.red), Float(end.green), Float(end.blue), Float(end.alpha),
        ]
        let midY = content.midY
        stops.withUnsafeBufferPointer { buffer in
            skb_draw_path_gradient(
                context,
                path,
                0,
                Float(layout.lineWidth),
                1, 1,
                buffer.baseAddress,
                3,
                Float(content.minX),
                Float(midY),
                Float(content.maxX),
                Float(midY)
            )
        }
    }

    private static func makePath(_ points: [CGPoint]) -> OpaquePointer? {
        guard let first = points.first,
              let path = skb_path_create() else {
            return nil
        }
        skb_path_move_to(path, Float(first.x), Float(first.y))
        for point in points.dropFirst() {
            skb_path_line_to(path, Float(point.x), Float(point.y))
        }
        return path
    }

    private static func drawMarker(
        _ point: CGPoint,
        color: OverlayColor,
        lineWidth: Double,
        sizeMultiplier: Double,
        context: OpaquePointer
    ) {
        let diameter = lineWidth * 2.7 * sizeMultiplier
        let radius = diameter / 2
        let rect = CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: diameter,
            height: diameter
        )

        if color.isRouteMapEndCheckerboard {
            skb_save(context)
            skb_clip_circle(context, Float(point.x), Float(point.y), Float(radius))
            skb_fill_rect(
                context,
                Float(rect.minX), Float(rect.minY),
                Float(rect.width), Float(rect.height),
                1, 1, 1, 1
            )
            let cellWidth = rect.width / 3
            let cellHeight = rect.height / 3
            for row in 0..<3 {
                for column in 0..<3 where (row + column).isMultiple(of: 2) {
                    skb_fill_rect(
                        context,
                        Float(rect.minX + cellWidth * Double(column)),
                        Float(rect.minY + cellHeight * Double(row)),
                        Float(cellWidth),
                        Float(cellHeight),
                        0, 0, 0, 1
                    )
                }
            }
            skb_restore(context)
        } else {
            skb_fill_circle(
                context,
                Float(point.x),
                Float(point.y),
                Float(radius),
                Float(color.red),
                Float(color.green),
                Float(color.blue),
                Float(color.alpha)
            )
        }

        skb_stroke_round_rect(
            context,
            Float(rect.minX),
            Float(rect.minY),
            Float(rect.width),
            Float(rect.height),
            Float(radius),
            Float(max(lineWidth * 0.45, 1)),
            1, 1, 1, 1
        )
    }

    private static func drawNoGPS(
        element: OverlayElement,
        layout: OverlayRouteMapRenderLayout,
        context: OpaquePointer,
        assets: SkiaRenderAssets
    ) {
        let fontSize = max(layout.rect.width * 0.09, 10)
        let font = assets.font(
            family: element.style.fontName,
            size: fontSize,
            weight: .semibold
        )
        let line = SkiaRouteWeatherText.makeLine("NO GPS", font: font)
        SkiaRouteWeatherText.drawCentered(
            line,
            font: font,
            centerX: layout.rect.midX,
            top: layout.rect.midY - line.height / 2,
            color: element.style.foregroundColor,
            opacity: 0.72,
            context: context
        )
    }

    // MARK: - Stats bar

    private static func drawStatsBar(
        element: OverlayElement,
        layout: OverlayRouteMapRenderLayout,
        context: OpaquePointer,
        assets: SkiaRenderAssets
    ) {
        guard let bar = layout.statsBarLayout, !bar.items.isEmpty else { return }

        if bar.isInside {
            skb_save(context)
            clipShape(
                bar.containerShape,
                rect: bar.containerRect,
                cornerRadius: bar.containerCornerRadius,
                context: context
            )
        }

        let rect = bar.rect
        skb_fill_round_rect(
            context,
            Float(rect.minX),
            Float(rect.minY),
            Float(rect.width),
            Float(rect.height),
            Float(bar.cornerRadius),
            0, 0, 0,
            Float(bar.backgroundOpacity)
        )

        let stacked = bar.placement.isVertical || bar.layoutMode == .stack
        if stacked {
            drawStackedItems(bar: bar, context: context, assets: assets)
        } else {
            drawHorizontalItems(bar: bar, context: context, assets: assets)
        }

        if bar.isInside {
            skb_restore(context)
        }
    }

    private static func drawHorizontalItems(
        bar: OverlayRouteMapStatsBarLayout,
        context: OpaquePointer,
        assets: SkiaRenderAssets
    ) {
        let count = bar.items.count
        let rect = bar.rect
        let dividerWidth = 1.0
        let gaps = Double(2 * count - 2) * bar.itemSpacing
            + Double(max(count - 1, 0)) * dividerWidth
        let cellWidth = max((rect.width - gaps) / Double(count), 1)
        var x = rect.minX

        for (index, item) in bar.items.enumerated() {
            let cell = CGRect(
                x: x,
                y: rect.minY,
                width: cellWidth,
                height: rect.height
            )
            drawStatsItem(
                item,
                in: cell,
                bar: bar,
                context: context,
                assets: assets
            )
            x += cellWidth + bar.itemSpacing

            if index < count - 1 {
                skb_fill_rect(
                    context,
                    Float(x),
                    Float(rect.minY + 6),
                    Float(dividerWidth),
                    Float(max(rect.height - 12, 0)),
                    Float(bar.labelColor.red),
                    Float(bar.labelColor.green),
                    Float(bar.labelColor.blue),
                    Float(bar.dividerOpacity)
                )
                x += dividerWidth + bar.itemSpacing
            }
        }
    }

    private static func drawStackedItems(
        bar: OverlayRouteMapStatsBarLayout,
        context: OpaquePointer,
        assets: SkiaRenderAssets
    ) {
        let count = bar.items.count
        let rect = bar.rect
        let dividerHeight = 1.0
        let gaps = Double(2 * count - 2) * bar.itemSpacing
            + Double(max(count - 1, 0)) * dividerHeight
        let cellHeight = max((rect.height - gaps) / Double(count), 1)
        var y = rect.minY

        for (index, item) in bar.items.enumerated() {
            let cell = CGRect(
                x: rect.minX,
                y: y,
                width: rect.width,
                height: cellHeight
            )
            drawStatsItem(
                item,
                in: cell,
                bar: bar,
                context: context,
                assets: assets
            )
            y += cellHeight + bar.itemSpacing

            if index < count - 1 {
                skb_fill_rect(
                    context,
                    Float(rect.minX + 6),
                    Float(y),
                    Float(max(rect.width - 12, 0)),
                    Float(dividerHeight),
                    Float(bar.labelColor.red),
                    Float(bar.labelColor.green),
                    Float(bar.labelColor.blue),
                    Float(bar.dividerOpacity)
                )
                y += dividerHeight + bar.itemSpacing
            }
        }
    }

    private static func drawStatsItem(
        _ item: OverlayRouteMapStatsBarItemLayout,
        in cell: CGRect,
        bar: OverlayRouteMapStatsBarLayout,
        context: OpaquePointer,
        assets: SkiaRenderAssets
    ) {
        let valueText = item.unit.isEmpty
            ? item.value
            : "\(item.value) \(item.unit)"
        let valueFont = SkiaRouteWeatherText.monospacedDigitFont(
            assets.font(
                family: bar.valueFontName,
                size: bar.valueFontSize,
                weight: weight(bar.valueFontWeight)
            )
        )
        let labelFont = assets.font(
            family: bar.labelFontName,
            size: bar.labelFontSize,
            weight: weight(bar.labelFontWeight)
        )
        let value = SkiaRouteWeatherText.fittedLine(
            valueText,
            font: valueFont,
            maxWidth: cell.width,
            minScale: 0.7
        )
        let label = SkiaRouteWeatherText.fittedLine(
            item.label.uppercased(),
            font: labelFont,
            maxWidth: cell.width,
            minScale: 0.7
        )
        let totalHeight = value.line.height + 1 + label.line.height
        let top = cell.midY - totalHeight / 2

        SkiaRouteWeatherText.drawCentered(
            value.line,
            font: value.font,
            centerX: cell.midX,
            top: top,
            color: bar.valueColor,
            context: context
        )
        SkiaRouteWeatherText.drawCentered(
            label.line,
            font: label.font,
            centerX: cell.midX,
            top: top + value.line.height + 1,
            color: bar.labelColor,
            context: context
        )
    }

    private static func weight(_ weight: OverlayFontWeight) -> NSFont.Weight {
        switch weight {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }
}
#endif
