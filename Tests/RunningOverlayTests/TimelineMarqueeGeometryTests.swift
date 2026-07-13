import Foundation
import Testing
@testable import RunningOverlay

struct TimelineMarqueeGeometryTests {
    @Test func startRegionIncludesEmptyWorkspaceBelowVideoTracks() {
        let bounds = CGRect(x: 0, y: 0, width: 2_000, height: 600)
        let region = TimelineMarqueeGeometry.startRegion(
            in: bounds,
            timelineStartX: 72,
            trackStartY: 116
        )

        #expect(region.contains(CGPoint(x: 1_000, y: 500)))
        #expect(!region.contains(CGPoint(x: 40, y: 500)))
        #expect(!region.contains(CGPoint(x: 1_000, y: 80)))
    }
}
