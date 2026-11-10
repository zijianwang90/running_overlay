import Foundation
import Testing
@testable import RunningOverlay

struct OverlayComponentPlotDataTests {
    @Test func smoothingRetainsEndpointsAndFlatSeries() {
        #expect(OverlayComponentPlotData.smoothed([]).isEmpty)
        #expect(OverlayComponentPlotData.smoothed([10]) == [10])
        #expect(OverlayComponentPlotData.smoothed([10, 20]) == [10, 20])
        let flat = [Double](repeating: 12, count: 20)
        for value in OverlayComponentPlotData.smoothed(flat) {
            #expect(abs(value - 12) < 0.000001)
        }
        let staircase = [0.0, 0, 0, 10, 10, 10, 20]
        let smoothed = OverlayComponentPlotData.smoothed(staircase, amount: 1)
        #expect(smoothed.first == 0)
        #expect(smoothed.last == 20)
        #expect(smoothed[2] > 0)
        #expect(smoothed[3] < 10)
        #expect(OverlayComponentPlotData.smoothed(staircase, amount: 0) == staircase)
    }
}
