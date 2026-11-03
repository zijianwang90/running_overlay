#if canImport(CSkiaBridge)
import CSkiaBridge
import AppKit
import CoreGraphics
import CoreText
import Foundation

/// Shared canvas, text, effect, and image helpers for the Skia chart module
/// ports. Layout stays in `OverlayRenderModel`; this type only draws.
final class SkiaChartsCanvas {
    let context: OpaquePointer
    let size: CGSize
    private let ownsContext: Bool

    private var fontCache: [String: NSFont] = [:]
    private var imageCache: [String: OpaquePointer] = [:]

    init?(size: CGSize) {
        guard size.width > 0,
              size.height > 0,
              let context = skb_create(Int32(size.width), Int32(size.height))
        else {
            return nil
        }
        self.context = context
        self.size = size
        self.ownsContext = true
    }

    /// Wraps a caller-owned context. The canvas never destroys this context,
    /// which lets preview/export reuse a persistent GPU context.
    init(context: OpaquePointer, size: CGSize) {
        self.context = context
        self.size = size
        self.ownsContext = false
    }

    deinit {
        for image in imageCache.values {
            skb_image_destroy(image)
        }
        if ownsContext {
            skb_destroy(context)
        }
    }

    // MARK: - Fonts and text

    func font(family: String, size: Double, weight: NSFont.Weight) -> NSFont {
        let key = "\(family)|\(size)|\(weight.rawValue)"
        if let cached = fontCache[key] {
            return cached
        }
        let font = OverlayFontResolver.appKitFont(
            family: family,
            size: max(size, 1),
            weight: weight
        )
        fontCache[key] = font
        return font
    }

    func font(family: String, size: Double, weight: OverlayFontWeight) -> NSFont {
        font(family: family, size: size, weight: Self.nsWeight(weight))
    }

    /// Shapes a single line with CoreText and per-glyph advances. Positions are
    /// relative to the line origin, matching `skb_draw_glyphs`.
    func line(
        _ text: String,
        font: NSFont,
        monospacedDigits: Bool = false
    ) -> TextLine {
        guard !text.isEmpty else {
            return TextLine(
                font: font,
                glyphs: [],
                xPositions: [],
                width: 0,
                ascent: font.ascender,
                descent: -font.descender,
                leading: font.leading
            )
        }

        let attributed = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: attributed.length)
        attributed.addAttribute(.font, value: font, range: range)
        if monospacedDigits {
            let settings: [[CFString: Any]] = [[
                kCTFontFeatureTypeIdentifierKey: kNumberSpacingType,
                kCTFontFeatureSelectorIdentifierKey: kMonospacedNumbersSelector
            ]]
            attributed.addAttribute(
                NSAttributedString.Key(kCTFontFeatureSettingsAttribute as String),
                value: settings,
                range: range
            )
        }

        let line = CTLineCreateWithAttributedString(attributed)
        let runs = CTLineGetGlyphRuns(line) as NSArray
        var glyphs: [CGGlyph] = []
        var positions: [Float] = []
        var x: CGFloat = 0

        for case let run as CTRun in runs {
            let count = CTRunGetGlyphCount(run)
            guard count > 0 else { continue }
            var runGlyphs = [CGGlyph](repeating: 0, count: count)
            var runPositions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: count), &runGlyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: count), &runPositions)
            for index in 0..<count {
                glyphs.append(runGlyphs[index])
                positions.append(Float(x + runPositions[index].x))
            }
            x += CTRunGetTypographicBounds(
                run,
                CFRange(location: 0, length: count),
                nil,
                nil,
                nil
            )
        }

        return TextLine(
            font: font,
            glyphs: glyphs,
            xPositions: positions,
            width: Double(x),
            ascent: Double(font.ascender),
            descent: Double(-font.descender),
            leading: Double(font.leading)
        )
    }

    func fittedLine(
        _ text: String,
        family: String,
        size: Double,
        weight: NSFont.Weight,
        maxWidth: Double,
        minScale: Double = 0.7,
        monospacedDigits: Bool = false
    ) -> TextLine {
        let nominal = font(family: family, size: size, weight: weight)
        var result = line(text, font: nominal, monospacedDigits: monospacedDigits)
        guard maxWidth > 0, result.width > maxWidth, result.width > 0 else {
            return result
        }
        let scale = max(minScale, maxWidth / result.width)
        let scaled = font(family: family, size: size * scale, weight: weight)
        result = line(text, font: scaled, monospacedDigits: monospacedDigits)
        return result
    }

    func draw(
        _ textLine: TextLine,
        x: Double,
        baselineY: Double,
        color: OverlayColor,
        opacity: Double = 1
    ) {
        guard !textLine.glyphs.isEmpty else { return }
        textLine.glyphs.withUnsafeBufferPointer { glyphs in
            textLine.xPositions.withUnsafeBufferPointer { positions in
                skb_draw_glyphs(
                    context,
                    Unmanaged.passUnretained(textLine.font).toOpaque(),
                    glyphs.baseAddress,
                    positions.baseAddress,
                    Int32(textLine.glyphs.count),
                    Float(x),
                    Float(baselineY),
                    Float(color.red),
                    Float(color.green),
                    Float(color.blue),
                    Float(color.alpha * opacity),
                    0,
                    0,
                    0,
                    0
                )
            }
        }
    }

    func drawCentered(
        _ textLine: TextLine,
        centerX: Double,
        top: Double,
        color: OverlayColor,
        opacity: Double = 1
    ) {
        draw(
            textLine,
            x: centerX - textLine.width / 2,
            baselineY: top + textLine.ascent,
            color: color,
            opacity: opacity
        )
    }

    /// Draws a line inside a vertical text band whose top is `top` and whose
    /// height is `bandHeight`, matching SwiftUI's `.position(y:)` centering.
    func drawCentered(
        _ textLine: TextLine,
        centerX: Double,
        bandTop: Double,
        bandHeight: Double,
        color: OverlayColor,
        opacity: Double = 1
    ) {
        let baseline = bandTop
            + (bandHeight - textLine.height) / 2
            + textLine.ascent
        draw(
            textLine,
            x: centerX - textLine.width / 2,
            baselineY: baseline,
            color: color,
            opacity: opacity
        )
    }

    func drawRightAligned(
        _ textLine: TextLine,
        rightX: Double,
        bandTop: Double,
        bandHeight: Double,
        color: OverlayColor,
        opacity: Double = 1
    ) {
        let baseline = bandTop
            + (bandHeight - textLine.height) / 2
            + textLine.ascent
        draw(
            textLine,
            x: rightX - textLine.width,
            baselineY: baseline,
            color: color,
            opacity: opacity
        )
    }

    // MARK: - Element effects

    /// Pushes the SwiftUI effect stack for one element: shadow closest to the
    /// content, glow outside it. Returns the number of layers pushed; restore
    /// them in reverse after drawing the element.
    @discardableResult
    func beginElementEffects(
        style: OverlayStyle,
        bounds: CGRect,
        includeGlow: Bool = true
    ) -> Int {
        var count = 0

        if includeGlow, style.glowEnabled, style.glowIntensity > 0 {
            let intensity = style.glowIntensity
            let outer = max(intensity * 34, 0)
            let inner = max(intensity * 18, 0)
            if outer > 0 {
                beginShadow(
                    sigma: outer,
                    dx: 0,
                    dy: 0,
                    bounds: bounds,
                    color: style.glowColor,
                    opacity: intensity * 0.35
                )
                count += 1
            }
            if inner > 0 {
                beginShadow(
                    sigma: inner,
                    dx: 0,
                    dy: 0,
                    bounds: bounds,
                    color: style.glowColor,
                    opacity: intensity * 0.72
                )
                count += 1
            }
        }

        if style.shadowEnabled, style.shadowOpacity > 0 {
            let radius = max(style.shadowRadius, 0)
            let thickness = style.shadowThickness
            if thickness > 2 {
                beginShadow(
                    sigma: radius * 0.48,
                    dx: style.shadowOffsetX,
                    dy: style.shadowOffsetY,
                    bounds: bounds,
                    color: style.shadowColor,
                    opacity: style.shadowOpacity * (thickness - 2) * 0.22
                )
                count += 1
            }
            if thickness > 1 {
                beginShadow(
                    sigma: radius * 0.72,
                    dx: style.shadowOffsetX,
                    dy: style.shadowOffsetY,
                    bounds: bounds,
                    color: style.shadowColor,
                    opacity: style.shadowOpacity * (thickness - 1) * 0.32
                )
                count += 1
            }
            beginShadow(
                sigma: radius,
                dx: style.shadowOffsetX,
                dy: style.shadowOffsetY,
                bounds: bounds,
                color: style.shadowColor,
                opacity: style.shadowOpacity
            )
            count += 1
        }

        return count
    }

    func beginShadow(
        sigma: Double,
        dx: Double,
        dy: Double,
        bounds: CGRect,
        color: OverlayColor,
        opacity: Double
    ) {
        guard opacity > 0 else { return }
        skb_begin_shadow_layer(
            context,
            Float(sigma),
            Float(dx),
            Float(dy),
            Float(bounds.minX),
            Float(bounds.minY),
            Float(bounds.width),
            Float(bounds.height),
            Float(color.red),
            Float(color.green),
            Float(color.blue),
            Float(color.alpha * opacity)
        )
    }

    func beginOpacityLayer(alpha: Double, bounds: CGRect) {
        skb_begin_opacity_layer(
            context,
            Float(alpha),
            Float(bounds.minX),
            Float(bounds.minY),
            Float(bounds.width),
            Float(bounds.height)
        )
    }

    // MARK: - Feathered background

    func drawFeatheredBackground(
        rect: CGRect,
        cornerRadius: Double,
        fadeEnabled: Bool,
        fadeAmount: Double,
        color: OverlayColor,
        opacity: Double
    ) {
        guard fadeEnabled, fadeAmount > 0.001 else {
            fillRoundedRect(rect, radius: cornerRadius, color: color, opacity: opacity)
            return
        }

        guard let mask = featherMask(
            width: rect.width,
            height: rect.height,
            cornerRadius: cornerRadius,
            fadeAmount: fadeAmount
        ) else {
            fillRoundedRect(rect, radius: cornerRadius, color: color, opacity: opacity)
            return
        }

        skb_save(context)
        beginOpacityLayer(alpha: 1, bounds: rect)
        fillRoundedRect(rect, radius: cornerRadius, color: color, opacity: opacity)
        skb_draw_image_dst_in(
            context,
            mask,
            Float(rect.minX),
            Float(rect.minY),
            Float(rect.width),
            Float(rect.height)
        )
        skb_restore(context)
        skb_restore(context)
    }

    private func featherMask(
        width: Double,
        height: Double,
        cornerRadius: Double,
        fadeAmount: Double
    ) -> OpaquePointer? {
        let pixelWidth = max(Int(width.rounded(.up)), 1)
        let pixelHeight = max(Int(height.rounded(.up)), 1)
        let key = "feather|\(pixelWidth)x\(pixelHeight)|\(cornerRadius)|\(fadeAmount)"
        if let cached = imageCache[key] {
            return cached
        }
        guard let cgMask = OverlayFeatherMaskRenderer.makeCGMask(
            size: CGSize(width: pixelWidth, height: pixelHeight),
            cornerRadius: cornerRadius,
            fadeAmount: fadeAmount
        ), let data = cgMask.dataProvider?.data,
              let pointer = CFDataGetBytePtr(data)
        else {
            return nil
        }

        let rowBytes = cgMask.bytesPerRow
        var bgra = [UInt8](repeating: 0, count: pixelWidth * pixelHeight * 4)
        for y in 0..<pixelHeight {
            for x in 0..<pixelWidth {
                let alpha = pointer[y * rowBytes + x]
                let index = (y * pixelWidth + x) * 4
                bgra[index] = alpha
                bgra[index + 1] = alpha
                bgra[index + 2] = alpha
                bgra[index + 3] = alpha
            }
        }
        let handle = bgra.withUnsafeBufferPointer {
            skb_image_create($0.baseAddress, Int32(pixelWidth), Int32(pixelHeight))
        }
        if let handle {
            imageCache[key] = handle
        }
        return handle
    }

    // MARK: - Images

    func image(
        key: String,
        make: () -> NSImage?,
        pixelSize: CGSize,
        tint: NSColor? = nil,
        scaleToFit: Bool = true
    ) -> OpaquePointer? {
        if let cached = imageCache[key] {
            return cached
        }
        guard let image = make() else { return nil }
        guard let bgra = rasterize(
            image,
            pixelWidth: max(Int(pixelSize.width.rounded()), 1),
            pixelHeight: max(Int(pixelSize.height.rounded()), 1),
            tint: tint,
            scaleToFit: scaleToFit
        ) else {
            return nil
        }
        let handle = bgra.withUnsafeBufferPointer {
            skb_image_create(
                $0.baseAddress,
                Int32(pixelSize.width.rounded()),
                Int32(pixelSize.height.rounded())
            )
        }
        if let handle {
            imageCache[key] = handle
        }
        return handle
    }

    func drawImage(_ handle: OpaquePointer, in rect: CGRect, opacity: Double = 1) {
        skb_draw_image_handle(
            context,
            handle,
            Float(rect.minX),
            Float(rect.minY),
            Float(rect.width),
            Float(rect.height),
            Float(opacity),
            0,
            0,
            0,
            0
        )
    }

    private func rasterize(
        _ image: NSImage,
        pixelWidth: Int,
        pixelHeight: Int,
        tint: NSColor?,
        scaleToFit: Bool
    ) -> [UInt8]? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: pixelWidth * 4,
            bitsPerPixel: 32
        ), let graphics = NSGraphicsContext(bitmapImageRep: rep) else {
            return nil
        }

        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }
        let scale = scaleToFit
            ? min(
                CGFloat(pixelWidth) / sourceSize.width,
                CGFloat(pixelHeight) / sourceSize.height
            )
            : 1
        let drawSize = CGSize(
            width: sourceSize.width * scale,
            height: sourceSize.height * scale
        )
        let drawRect = CGRect(
            x: (CGFloat(pixelWidth) - drawSize.width) / 2,
            y: (CGFloat(pixelHeight) - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        graphics.imageInterpolation = .high
        NSColor.clear.setFill()
        CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight).fill()
        image.draw(
            in: drawRect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        if let tint {
            tint.setFill()
            drawRect.fill(using: .sourceAtop)
        }
        graphics.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        guard let source = rep.bitmapData else { return nil }
        var bgra = [UInt8](repeating: 0, count: pixelWidth * pixelHeight * 4)
        for index in stride(from: 0, to: bgra.count, by: 4) {
            bgra[index] = source[index + 2]
            bgra[index + 1] = source[index + 1]
            bgra[index + 2] = source[index]
            bgra[index + 3] = source[index + 3]
        }
        return bgra
    }

    // MARK: - Primitives

    func save() {
        skb_save(context)
    }

    func restore() {
        skb_restore(context)
    }

    func fillRect(_ rect: CGRect, color: OverlayColor, opacity: Double = 1) {
        skb_fill_rect(
            context,
            Float(rect.minX),
            Float(rect.minY),
            Float(rect.width),
            Float(rect.height),
            Float(color.red),
            Float(color.green),
            Float(color.blue),
            Float(color.alpha * opacity)
        )
    }

    func fillRoundedRect(
        _ rect: CGRect,
        radius: Double,
        color: OverlayColor,
        opacity: Double = 1
    ) {
        skb_fill_round_rect(
            context,
            Float(rect.minX),
            Float(rect.minY),
            Float(rect.width),
            Float(rect.height),
            Float(radius),
            Float(color.red),
            Float(color.green),
            Float(color.blue),
            Float(color.alpha * opacity)
        )
    }

    func strokeRoundedRect(
        _ rect: CGRect,
        radius: Double,
        width: Double,
        color: OverlayColor,
        opacity: Double = 1
    ) {
        skb_stroke_round_rect(
            context,
            Float(rect.minX),
            Float(rect.minY),
            Float(rect.width),
            Float(rect.height),
            Float(radius),
            Float(width),
            Float(color.red),
            Float(color.green),
            Float(color.blue),
            Float(color.alpha * opacity)
        )
    }

    func fillCircle(center: CGPoint, radius: Double, color: OverlayColor) {
        skb_fill_circle(
            context,
            Float(center.x),
            Float(center.y),
            Float(radius),
            Float(color.red),
            Float(color.green),
            Float(color.blue),
            Float(color.alpha)
        )
    }

    func strokeLine(
        from start: CGPoint,
        to end: CGPoint,
        width: Double,
        color: OverlayColor,
        opacity: Double = 1
    ) {
        skb_stroke_line(
            context,
            Float(start.x),
            Float(start.y),
            Float(end.x),
            Float(end.y),
            Float(width),
            Float(color.red),
            Float(color.green),
            Float(color.blue),
            Float(color.alpha * opacity)
        )
    }

    func fillPath(
        _ path: OpaquePointer,
        color: OverlayColor,
        opacity: Double = 1
    ) {
        skb_draw_path(
            context,
            path,
            1,
            Float(color.red),
            Float(color.green),
            Float(color.blue),
            Float(color.alpha * opacity),
            0,
            0,
            0,
            0,
            0
        )
    }

    func strokePath(
        _ path: OpaquePointer,
        color: OverlayColor,
        width: Double,
        cap: Int32 = 1,
        join: Int32 = 1,
        opacity: Double = 1
    ) {
        skb_draw_path(
            context,
            path,
            0,
            Float(color.red),
            Float(color.green),
            Float(color.blue),
            Float(color.alpha * opacity),
            Float(width),
            cap,
            join,
            0,
            0
        )
    }

    func clipRect(_ rect: CGRect) {
        skb_clip_rect(
            context,
            Float(rect.minX),
            Float(rect.minY),
            Float(rect.width),
            Float(rect.height)
        )
    }

    func clipRoundedRect(_ rect: CGRect, radius: Double) {
        skb_clip_round_rect(
            context,
            Float(rect.minX),
            Float(rect.minY),
            Float(rect.width),
            Float(rect.height),
            Float(radius)
        )
    }

    static func nsWeight(_ weight: OverlayFontWeight) -> NSFont.Weight {
        switch weight {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }

    static func nsColor(_ color: OverlayColor) -> NSColor {
        NSColor(
            srgbRed: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha
        )
    }
}

struct TextLine {
    var font: NSFont
    var glyphs: [CGGlyph]
    var xPositions: [Float]
    var width: Double
    var ascent: Double
    var descent: Double
    var leading: Double

    var height: Double {
        ascent + descent + leading
    }
}

/// Shared stats-bar drawing used by the distance timeline and elevation chart.
/// Mirrors `SharedStatsBarContentView`: equal flexible slots with fixed-width
/// dividers and `itemSpacing` between every adjacent child.
enum SkiaStatsBar {
    static func draw(
        canvas: SkiaChartsCanvas,
        items: [OverlayDistanceTimelineStatsBarItemLayout],
        rect: CGRect,
        stacked: Bool,
        itemSpacing: Double,
        dividerOpacity: Double,
        cornerRadius: Double,
        backgroundOpacity: Double,
        valueFontName: String,
        valueFontSize: Double,
        valueFontWeight: OverlayFontWeight,
        valueColor: OverlayColor,
        labelFontName: String,
        labelFontSize: Double,
        labelFontWeight: OverlayFontWeight,
        labelColor: OverlayColor
    ) {
        guard !items.isEmpty else { return }
        canvas.fillRoundedRect(
            rect,
            radius: cornerRadius,
            color: .black,
            opacity: backgroundOpacity
        )

        canvas.save()
        canvas.clipRoundedRect(rect, radius: cornerRadius)
        defer { canvas.restore() }

        let count = items.count
        let spacingTotal = Double(max(2 * count - 2, 0)) * itemSpacing

        if stacked {
            let dividerHeight = 1.0
            let fixed = Double(max(count - 1, 0)) * dividerHeight + spacingTotal
            let itemHeight = (rect.height - fixed) / Double(count)
            var cursor = rect.minY
            for (index, item) in items.enumerated() {
                let cell = CGRect(
                    x: rect.minX,
                    y: cursor,
                    width: rect.width,
                    height: itemHeight
                )
                drawItem(
                    canvas: canvas,
                    item: item,
                    cell: cell,
                    valueFontName: valueFontName,
                    valueFontSize: valueFontSize,
                    valueFontWeight: valueFontWeight,
                    valueColor: valueColor,
                    labelFontName: labelFontName,
                    labelFontSize: labelFontSize,
                    labelFontWeight: labelFontWeight,
                    labelColor: labelColor
                )
                cursor += itemHeight
                if index < count - 1 {
                    cursor += itemSpacing
                    if dividerOpacity > 0 {
                        canvas.fillRect(
                            CGRect(
                                x: rect.minX + 6,
                                y: cursor,
                                width: max(rect.width - 12, 0),
                                height: dividerHeight
                            ),
                            color: labelColor,
                            opacity: dividerOpacity
                        )
                    }
                    cursor += dividerHeight + itemSpacing
                }
            }
        } else {
            let dividerWidth = 1.0
            let fixed = Double(max(count - 1, 0)) * dividerWidth + spacingTotal
            let itemWidth = (rect.width - fixed) / Double(count)
            var cursor = rect.minX
            for (index, item) in items.enumerated() {
                let cell = CGRect(
                    x: cursor,
                    y: rect.minY,
                    width: itemWidth,
                    height: rect.height
                )
                drawItem(
                    canvas: canvas,
                    item: item,
                    cell: cell,
                    valueFontName: valueFontName,
                    valueFontSize: valueFontSize,
                    valueFontWeight: valueFontWeight,
                    valueColor: valueColor,
                    labelFontName: labelFontName,
                    labelFontSize: labelFontSize,
                    labelFontWeight: labelFontWeight,
                    labelColor: labelColor
                )
                cursor += itemWidth
                if index < count - 1 {
                    cursor += itemSpacing
                    if dividerOpacity > 0 {
                        canvas.fillRect(
                            CGRect(
                                x: cursor,
                                y: rect.minY + 6,
                                width: 1,
                                height: max(rect.height - 12, 0)
                            ),
                            color: labelColor,
                            opacity: dividerOpacity
                        )
                    }
                    cursor += dividerWidth + itemSpacing
                }
            }
        }
    }

    private static func drawItem(
        canvas: SkiaChartsCanvas,
        item: OverlayDistanceTimelineStatsBarItemLayout,
        cell: CGRect,
        valueFontName: String,
        valueFontSize: Double,
        valueFontWeight: OverlayFontWeight,
        valueColor: OverlayColor,
        labelFontName: String,
        labelFontSize: Double,
        labelFontWeight: OverlayFontWeight,
        labelColor: OverlayColor
    ) {
        let valueText = item.value
            + (item.unit.isEmpty ? "" : " \(item.unit)")
        let valueLine = canvas.fittedLine(
            valueText,
            family: valueFontName,
            size: valueFontSize,
            weight: SkiaChartsCanvas.nsWeight(valueFontWeight),
            maxWidth: cell.width,
            minScale: 0.7,
            monospacedDigits: true
        )
        let labelLine = canvas.fittedLine(
            item.label.uppercased(),
            family: labelFontName,
            size: labelFontSize,
            weight: SkiaChartsCanvas.nsWeight(labelFontWeight),
            maxWidth: cell.width,
            minScale: 0.7
        )
        let totalHeight = valueLine.height + 1 + labelLine.height
        let top = cell.midY - totalHeight / 2
        canvas.drawCentered(
            valueLine,
            centerX: cell.midX,
            top: top,
            color: valueColor
        )
        canvas.drawCentered(
            labelLine,
            centerX: cell.midX,
            top: top + valueLine.height + 1,
            color: labelColor
        )
    }
}
#endif
