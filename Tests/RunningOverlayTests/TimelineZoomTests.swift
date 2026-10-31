import Foundation
import Testing
@testable import RunningOverlay

@MainActor
struct TimelineZoomTests {
    @Test func continuousZoomScalesFromFitAndSnapsBackToFit() {
        let project = ProjectDocument()
        project.fitPixelsPerSecond = 2

        project.zoomTimeline(by: 0.9)
        #expect(project.timeline.zoom == .fit)

        project.zoomTimeline(by: 1.1)
        #expect(project.timeline.zoom == .pixelsPerSecond(2.2))

        project.zoomTimeline(by: 1.5)
        guard case .pixelsPerSecond(let zoomed) = project.timeline.zoom else {
            Issue.record("Expected pixels-per-second zoom")
            return
        }
        #expect(abs(zoomed - 3.3) < 1e-9)

        project.zoomTimeline(by: 0.5)
        #expect(project.timeline.zoom == .fit)
    }

    @Test func continuousZoomIsClampedAndIgnoresInvalidFactors() {
        let project = ProjectDocument()
        project.fitPixelsPerSecond = 2

        project.zoomTimeline(by: 1_000)
        #expect(project.timeline.zoom == .pixelsPerSecond(ProjectDocument.maximumTimelinePixelsPerSecond))

        project.zoomTimeline(by: .nan)
        project.zoomTimeline(by: 0)
        project.zoomTimeline(by: -2)
        #expect(project.timeline.zoom == .pixelsPerSecond(ProjectDocument.maximumTimelinePixelsPerSecond))
    }

    @Test func zoomButtonsStepByTheSharedFactor() {
        let project = ProjectDocument()
        project.fitPixelsPerSecond = 2

        project.zoomTimelineIn()
        #expect(project.timeline.zoom == .pixelsPerSecond(2 * ProjectDocument.timelineZoomStep))

        project.zoomTimelineOut()
        #expect(project.timeline.zoom == .fit)
    }
}
