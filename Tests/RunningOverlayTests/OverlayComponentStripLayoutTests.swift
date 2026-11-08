import Testing
@testable import RunningOverlay

struct OverlayComponentStripLayoutTests {
    @Test func emptyAndSingleItem() {
        #expect(widths([], .equal).isEmpty)
        #expect(widths([30], .equal) == [100])
        #expect(widths([0], .weighted) == [10])
    }

    @Test func weightedMinimumsNormalizeOnlyWhenTheyOverflow() {
        let result = widths([1, 99], .weighted, minimum: 20)
        #expect(abs(result.reduce(0, +) - 100) < 0.000001)
        #expect(result[0] > 0)
        #expect(result[1] > result[0])
        #expect(widths([0, 0], .weighted) == [10, 10])
    }

    @Test func emphasizedCurrentCanBeNarrowerThanEqualShare() {
        #expect(widths([1, 1], .emphasized, current: 0, fraction: 0.1) == [10, 90])
        #expect(widths([1, 1], .equal, current: 0, fraction: 0.1) == [50, 50])
        #expect(widths([1, 1], .equal, current: 4, fraction: 0.6) == [50, 50])
    }

    @Test func gapsAndMinimumsRespectConstrainedAvailableSpace() {
        let result = OverlayComponentStripLayout.widths(
            weights: [1, 1, 1], mode: .emphasized, currentIndex: 1,
            emphasisFraction: 0.6, availableWidth: 100, gap: 5, minimumWidth: 40
        )
        #expect(abs(result.reduce(0, +) - 90) < 0.000001)
        #expect(result.allSatisfy { $0 > 0 })
    }

    private func widths(
        _ weights: [Double], _ mode: OverlayComponentStripLayout.Mode,
        current: Int? = nil, fraction: Double = 0, minimum: Double = 10
    ) -> [Double] {
        OverlayComponentStripLayout.widths(
            weights: weights, mode: mode, currentIndex: current,
            emphasisFraction: fraction, availableWidth: 100, gap: 0,
            minimumWidth: minimum
        )
    }
}
