#if canImport(CSkiaBridge)
import AppKit
import Foundation
import Testing
@testable import RunningOverlay

@Suite struct SkiaTextComposerTests {
    private let font = SkiaTextComposer.font(
        family: "Menlo",
        size: 42,
        weight: .regular
    )

    @Test func shapesTextAndReportsTypographicMetrics() {
        let line = SkiaTextComposer.makeLine("140", font: font)
        #expect(line.width > 0)
        #expect(line.ascent > 0)
        #expect(line.descent >= 0)
        #expect(line.height > 0)
        #expect(!line.isEmpty)
        #expect(!line.runs.isEmpty)
        #expect(line.runs.allSatisfy { $0.glyphs.count == $0.xPositions.count })
    }

    @Test func emptyTextHasNoGlyphsAndZeroWidth() {
        let line = SkiaTextComposer.makeLine("", font: font)
        #expect(line.width == 0)
        #expect(line.isEmpty)
    }

    /// `.monospacedDigit()` is applied to every preset; the `tnum` feature
    /// makes all digits equally wide.
    @Test func monospacedDigitsEqualizeDigitWidths() {
        let ones = SkiaTextComposer.makeLine("1111", font: font)
        let eights = SkiaTextComposer.makeLine("8888", font: font)
        #expect(abs(ones.width - eights.width) < 0.01)
    }

    @Test func trackingIncreasesWidth() {
        let plain = SkiaTextComposer.makeLine("HEART", font: font, tracking: 0)
        let tracked = SkiaTextComposer.makeLine(
            "HEART",
            font: font,
            tracking: 2
        )
        #expect(tracked.width > plain.width)
        #expect(tracked.width - plain.width >= 4 * 2)
    }

    @Test func preservesRunPositionsForMultiGlyphText() {
        let line = SkiaTextComposer.makeLine("140", font: font)
        let positions = line.runs.flatMap(\.xPositions)
        #expect(positions.count == 3)
        #expect(positions[0] < positions[1])
        #expect(positions[1] < positions[2])
    }

    @Test func resolvesOverlayWeightThroughSharedResolver() {
        let overlay = SkiaTextComposer.font(
            family: "Menlo",
            size: 20,
            overlayWeight: .bold
        )
        let direct = SkiaTextComposer.font(
            family: "Menlo",
            size: 20,
            weight: .bold
        )
        #expect(overlay.fontName == direct.fontName)
    }

    @Test func alignmentOffsetsDistributeRemainingSpace() {
        #expect(
            SkiaTextComposer.horizontalOffset(
                child: 4,
                parent: 10,
                alignment: .leading
            ) == 0
        )
        #expect(
            SkiaTextComposer.horizontalOffset(
                child: 4,
                parent: 10,
                alignment: .center
            ) == 3
        )
        #expect(
            SkiaTextComposer.horizontalOffset(
                child: 4,
                parent: 10,
                alignment: .trailing
            ) == 6
        )
        #expect(
            SkiaTextComposer.verticalOffset(
                child: 4,
                parent: 10,
                alignment: .top
            ) == 0
        )
        #expect(
            SkiaTextComposer.verticalOffset(
                child: 4,
                parent: 10,
                alignment: .middle
            ) == 3
        )
        #expect(
            SkiaTextComposer.verticalOffset(
                child: 4,
                parent: 10,
                alignment: .bottom
            ) == 6
        )
    }
}

#endif
