#if canImport(CSkiaBridge)
import AppKit
import CSkiaBridge
import CoreText
import Foundation

/// CoreText shaping and drawing shared by the route and weather modules.
///
/// This is a module-local helper until Group T publishes `SkiaTextComposer`.
/// It does not derive style values; callers pass the exact font, color, and
/// opacity from the render model.
enum SkiaRouteWeatherText {
    struct Line {
        var glyphs: [CGGlyph]
        var xPositions: [Float]
        var width: Double
        var ascent: Double
        var descent: Double
        var leading: Double

        var height: Double { ascent + descent + leading }
    }

    static func makeLine(
        _ text: String,
        font: NSFont,
        tracking: Double = 0
    ) -> Line {
        var attributes: [NSAttributedString.Key: Any] = [.font: font]
        if tracking != 0 {
            attributes[.kern] = tracking
        }
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: attributes)
        )
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CTLineGetTypographicBounds(
            line,
            &ascent,
            &descent,
            &leading
        )

        var glyphs: [CGGlyph] = []
        var xPositions: [Float] = []
        if let runs = CTLineGetGlyphRuns(line) as? [CTRun] {
            for run in runs {
                let count = CTRunGetGlyphCount(run)
                guard count > 0 else { continue }
                var runGlyphs = [CGGlyph](repeating: 0, count: count)
                var runPositions = [CGPoint](repeating: .zero, count: count)
                let range = CFRange(location: 0, length: count)
                CTRunGetGlyphs(run, range, &runGlyphs)
                CTRunGetPositions(run, range, &runPositions)
                glyphs.append(contentsOf: runGlyphs)
                xPositions.append(contentsOf: runPositions.map { Float($0.x) })
            }
        }
        return Line(
            glyphs: glyphs,
            xPositions: xPositions,
            width: width,
            ascent: ascent,
            descent: descent,
            leading: leading
        )
    }

    /// Shrinks the font until the line fits `maxWidth`, down to `minScale`,
    /// then truncates with an ellipsis. Mirrors SwiftUI's
    /// `lineLimit(1).minimumScaleFactor(_:)`.
    static func fittedLine(
        _ text: String,
        font: NSFont,
        maxWidth: Double,
        minScale: Double,
        tracking: Double = 0
    ) -> (font: NSFont, line: Line) {
        let line = makeLine(text, font: font, tracking: tracking)
        guard maxWidth > 0, line.width > maxWidth, line.width > 0 else {
            return (font, line)
        }
        let ratio = maxWidth / line.width
        let scale = min(1, max(minScale, ratio))
        let scaledFont = scale < 1
            ? NSFont(
                descriptor: font.fontDescriptor,
                size: max(font.pointSize * scale, 1)
            ) ?? font
            : font
        let scaledLine = makeLine(text, font: scaledFont, tracking: tracking)
        // Scaling by `maxWidth / width` lands exactly on the limit; allow a
        // subpixel of rounding error before truncating.
        guard scaledLine.width > maxWidth + 0.5 else {
            return (scaledFont, scaledLine)
        }
        return (
            scaledFont,
            truncatedLine(text, font: scaledFont, maxWidth: maxWidth, tracking: tracking)
        )
    }

    /// Longest prefix that fits `maxWidth` with a trailing ellipsis.
    static func truncatedLine(
        _ text: String,
        font: NSFont,
        maxWidth: Double,
        tracking: Double = 0
    ) -> Line {
        let ellipsis = "…"
        var characters = Array(text)
        while !characters.isEmpty {
            characters.removeLast()
            let candidate = makeLine(
                String(characters) + ellipsis,
                font: font,
                tracking: tracking
            )
            if candidate.width <= maxWidth {
                return candidate
            }
        }
        return makeLine(ellipsis, font: font, tracking: tracking)
    }

    static func monospacedDigitFont(_ font: NSFont) -> NSFont {
        let features: [[NSFontDescriptor.FeatureKey: Int]] = [[
            .typeIdentifier: kNumberSpacingType,
            .selectorIdentifier: kMonospacedNumbersSelector,
        ]]
        let descriptor = font.fontDescriptor.addingAttributes([
            .featureSettings: features,
        ])
        return NSFont(descriptor: descriptor, size: font.pointSize) ?? font
    }

    static func draw(
        _ line: Line,
        font: NSFont,
        x: Double,
        top: Double,
        color: OverlayColor,
        opacity: Double = 1,
        context: OpaquePointer
    ) {
        guard !line.glyphs.isEmpty else { return }
        let alpha = min(max(color.alpha * opacity, 0), 1)
        guard alpha > 0 else { return }
        line.glyphs.withUnsafeBufferPointer { glyphs in
            line.xPositions.withUnsafeBufferPointer { positions in
                skb_draw_glyphs(
                    context,
                    Unmanaged.passUnretained(font).toOpaque(),
                    glyphs.baseAddress,
                    positions.baseAddress,
                    Int32(line.glyphs.count),
                    Float(x),
                    Float(top + line.ascent),
                    Float(color.red),
                    Float(color.green),
                    Float(color.blue),
                    Float(alpha),
                    0, 0, 0, 0
                )
            }
        }
    }

    static func drawCentered(
        _ line: Line,
        font: NSFont,
        centerX: Double,
        top: Double,
        color: OverlayColor,
        opacity: Double = 1,
        context: OpaquePointer
    ) {
        draw(
            line,
            font: font,
            x: centerX - line.width / 2,
            top: top,
            color: color,
            opacity: opacity,
            context: context
        )
    }

    static func drawRightAligned(
        _ line: Line,
        font: NSFont,
        rightX: Double,
        top: Double,
        color: OverlayColor,
        opacity: Double = 1,
        context: OpaquePointer
    ) {
        draw(
            line,
            font: font,
            x: rightX - line.width,
            top: top,
            color: color,
            opacity: opacity,
            context: context
        )
    }
}
#endif
