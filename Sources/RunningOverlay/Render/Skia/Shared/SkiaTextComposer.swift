#if canImport(CSkiaBridge)
import AppKit
import CoreText
import CSkiaBridge
import Foundation

/// One shaped CoreText run. `xPositions` are line-relative, matching
/// `CTRunGetPositions` on macOS. Runs keep their own font so fallback glyphs
/// (symbols, CJK, emoji) are drawn with the typeface CoreText chose.
struct SkiaTextRun {
    var font: NSFont
    var glyphs: [CGGlyph]
    var xPositions: [Float]
}

/// A shaped single line of text with CoreText typographic metrics.
struct SkiaTextLine {
    var text: String
    var runs: [SkiaTextRun]
    var width: Double
    var ascent: Double
    var descent: Double
    var leading: Double

    var height: Double { ascent + descent + leading }
    var isEmpty: Bool { runs.allSatisfy(\.glyphs.isEmpty) }
}

enum SkiaTextHorizontalAlignment {
    case leading
    case center
    case trailing

    init(_ alignment: OverlayTextAlignment) {
        switch alignment {
        case .leading: self = .leading
        case .center: self = .center
        case .trailing: self = .trailing
        }
    }
}

enum SkiaTextVerticalAlignment {
    case top
    case middle
    case bottom

    init(_ alignment: OverlayTextAlignment) {
        switch alignment {
        case .leading: self = .top
        case .center: self = .middle
        case .trailing: self = .bottom
        }
    }
}

/// Shared text shaping and drawing for every Skia module.
///
/// The composer owns CoreText shaping only: it measures and draws text. It
/// does not read `ActivityTimeline` or derive style values; callers pass the
/// resolved font, size, tracking, color, and opacity from their module layout.
enum SkiaTextComposer {
    /// `NSCache` is thread-safe internally; export and preview can resolve
    /// fonts from different threads.
    nonisolated(unsafe) private static let fontCache = NSCache<NSString, NSFont>()

    /// Resolves a family/weight to an AppKit font using the same resolver as
    /// the SwiftUI preview and export paths.
    static func font(family: String, size: Double, weight: NSFont.Weight) -> NSFont {
        let key = "\(family)|\(size)|\(weight.rawValue)" as NSString
        if let cached = fontCache.object(forKey: key) {
            return cached
        }
        let font = OverlayFontResolver.appKitFont(family: family, size: size, weight: weight)
        fontCache.setObject(font, forKey: key)
        return font
    }

    /// Convenience for callers that hold an `OverlayFontWeight` from a render
    /// layout. Named `overlayWeight` so weight literals stay unambiguous.
    static func font(
        family: String,
        size: Double,
        overlayWeight weight: OverlayFontWeight
    ) -> NSFont {
        font(family: family, size: size, weight: weight.skiaFontWeight)
    }

    /// Shapes one line. `monospacedDigits` enables the OpenType `tnum` feature,
    /// matching SwiftUI's `.monospacedDigit()` on every preset.
    static func makeLine(
        _ text: String,
        font: NSFont,
        tracking: Double = 0,
        monospacedDigits: Bool = true
    ) -> SkiaTextLine {
        let shapedFont = monospacedDigits ? monospacedDigitFont(font) : font
        var attributes: [NSAttributedString.Key: Any] = [.font: shapedFont]
        if tracking != 0 {
            attributes[.kern] = tracking
        }
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: attributes)
        )

        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)

        var runs: [SkiaTextRun] = []
        if let ctRuns = CTLineGetGlyphRuns(line) as? [CTRun] {
            for run in ctRuns {
                let count = CTRunGetGlyphCount(run)
                guard count > 0 else { continue }
                let range = CFRange(location: 0, length: count)
                var glyphs = [CGGlyph](repeating: 0, count: count)
                var positions = [CGPoint](repeating: .zero, count: count)
                CTRunGetGlyphs(run, range, &glyphs)
                CTRunGetPositions(run, range, &positions)
                let attributes = CTRunGetAttributes(run) as NSDictionary
                let runFont = attributes[kCTFontAttributeName] as? NSFont ?? shapedFont
                runs.append(
                    SkiaTextRun(
                        font: runFont,
                        glyphs: glyphs,
                        xPositions: positions.map { Float($0.x) }
                    )
                )
            }
        }

        return SkiaTextLine(
            text: text,
            runs: runs,
            width: Double(width),
            ascent: Double(ascent),
            descent: Double(descent),
            leading: Double(leading)
        )
    }

    static func measure(
        _ text: String,
        font: NSFont,
        tracking: Double = 0,
        monospacedDigits: Bool = true
    ) -> CGSize {
        let line = makeLine(
            text,
            font: font,
            tracking: tracking,
            monospacedDigits: monospacedDigits
        )
        return CGSize(width: line.width, height: line.height)
    }

    /// Draws a line with its left edge at `x` and its baseline at `baselineY`.
    static func draw(
        _ line: SkiaTextLine,
        context: OpaquePointer,
        x: Double,
        baselineY: Double,
        color: OverlayColor,
        opacity: Double
    ) {
        guard opacity > 0.001 else { return }
        let alpha = Float(color.alpha * opacity)
        for run in line.runs where !run.glyphs.isEmpty {
            run.glyphs.withUnsafeBufferPointer { glyphs in
                run.xPositions.withUnsafeBufferPointer { positions in
                    skb_draw_glyphs(
                        context,
                        Unmanaged.passUnretained(run.font).toOpaque(),
                        glyphs.baseAddress,
                        positions.baseAddress,
                        Int32(run.glyphs.count),
                        Float(x),
                        Float(baselineY),
                        Float(color.red),
                        Float(color.green),
                        Float(color.blue),
                        alpha,
                        0, 0, 0, 0
                    )
                }
            }
        }
    }

    /// Draws a line top-left anchored at `origin`.
    static func draw(
        _ line: SkiaTextLine,
        context: OpaquePointer,
        origin: CGPoint,
        color: OverlayColor,
        opacity: Double
    ) {
        draw(
            line,
            context: context,
            x: origin.x,
            baselineY: origin.y + line.ascent,
            color: color,
            opacity: opacity
        )
    }

    /// Draws a line inside a rect with horizontal and vertical alignment.
    static func draw(
        _ line: SkiaTextLine,
        context: OpaquePointer,
        in rect: CGRect,
        horizontal: SkiaTextHorizontalAlignment,
        vertical: SkiaTextVerticalAlignment,
        color: OverlayColor,
        opacity: Double
    ) {
        let x = rect.minX + horizontalOffset(
            child: line.width,
            parent: rect.width,
            alignment: horizontal
        )
        let y = rect.minY + verticalOffset(
            child: line.height,
            parent: rect.height,
            alignment: vertical
        )
        draw(
            line,
            context: context,
            x: x,
            baselineY: y + line.ascent,
            color: color,
            opacity: opacity
        )
    }

    /// Convenience for modules that only need one line in a rect.
    static func draw(
        _ text: String,
        context: OpaquePointer,
        in rect: CGRect,
        font: NSFont,
        tracking: Double = 0,
        monospacedDigits: Bool = true,
        horizontal: SkiaTextHorizontalAlignment = .leading,
        vertical: SkiaTextVerticalAlignment = .middle,
        color: OverlayColor,
        opacity: Double
    ) {
        let line = makeLine(
            text,
            font: font,
            tracking: tracking,
            monospacedDigits: monospacedDigits
        )
        draw(
            line,
            context: context,
            in: rect,
            horizontal: horizontal,
            vertical: vertical,
            color: color,
            opacity: opacity
        )
    }

    static func horizontalOffset(
        child: Double,
        parent: Double,
        alignment: SkiaTextHorizontalAlignment
    ) -> Double {
        switch alignment {
        case .leading: 0
        case .center: (parent - child) / 2
        case .trailing: parent - child
        }
    }

    static func verticalOffset(
        child: Double,
        parent: Double,
        alignment: SkiaTextVerticalAlignment
    ) -> Double {
        switch alignment {
        case .top: 0
        case .middle: (parent - child) / 2
        case .bottom: parent - child
        }
    }

    private static func monospacedDigitFont(_ font: NSFont) -> NSFont {
        let key = "tnum|\(font.fontName)|\(font.pointSize)" as NSString
        if let cached = fontCache.object(forKey: key) {
            return cached
        }
        let features: [[NSFontDescriptor.FeatureKey: Int]] = [[
            .typeIdentifier: kNumberSpacingType,
            .selectorIdentifier: kMonospacedNumbersSelector
        ]]
        let descriptor = font.fontDescriptor.addingAttributes([
            .featureSettings: features
        ])
        let resolved = NSFont(descriptor: descriptor, size: font.pointSize) ?? font
        fontCache.setObject(resolved, forKey: key)
        return resolved
    }
}

extension OverlayFontWeight {
    /// AppKit weight used by Skia text drawing. Kept separate from the
    /// SwiftUI-only extension so modules do not depend on view code.
    var skiaFontWeight: NSFont.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }
}
#endif
