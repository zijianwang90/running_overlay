import CoreGraphics
import Foundation
import Testing
@testable import RunningOverlay

struct PreviewSnapTests {
    private let canvas = CGSize(width: 1000, height: 500)
    private let movingID = UUID()
    private let frame = CGRect(x: 0, y: 0, width: 100, height: 50)

    @Test func nearCenterSnapsToCanvasCenterByDefault() {
        // Proposed center is 3 pt right of the canvas center line, inside the 6 pt threshold.
        let result = PreviewSnapResolver().snap(
            movingElementID: movingID,
            proposedPosition: CGPoint(x: 0.503, y: 0.3),
            currentFrame: frame,
            overlayFrames: [:],
            canvasSize: canvas,
            guidesEnabled: true
        )

        #expect(abs(result.position.x - 0.5) < 1e-9)
        #expect(result.lines.contains { $0.axis == .vertical })
    }

    @Test func disablingSnappingKeepsTheProposedPositionAndShowsNoLines() {
        let resolver = PreviewSnapResolver()
        let free = resolver.snap(
            movingElementID: movingID,
            proposedPosition: CGPoint(x: 0.503, y: 0.3),
            currentFrame: frame,
            overlayFrames: [:],
            canvasSize: canvas,
            guidesEnabled: true,
            isSnappingEnabled: false
        )
        #expect(abs(free.position.x - 0.503) < 1e-9)
        #expect(abs(free.position.y - 0.3) < 1e-9)
        #expect(free.lines.isEmpty)

        let freeTopLeading = resolver.snapTopLeading(
            movingElementID: movingID,
            proposedPosition: CGPoint(x: 0.003, y: 0.004),
            currentFrame: frame,
            overlayFrames: [:],
            canvasSize: canvas,
            guidesEnabled: true,
            isSnappingEnabled: false
        )
        #expect(abs(freeTopLeading.position.x - 0.003) < 1e-9)
        #expect(freeTopLeading.lines.isEmpty)
    }

    @Test func disabledSnappingStillKeepsTheOverlayOnTheCanvas() {
        let result = PreviewSnapResolver().snap(
            movingElementID: movingID,
            proposedPosition: CGPoint(x: 1.2, y: -0.4),
            currentFrame: frame,
            overlayFrames: [:],
            canvasSize: canvas,
            guidesEnabled: false,
            isSnappingEnabled: false
        )

        #expect(result.position.x <= 1)
        #expect(result.position.y >= 0)
    }
}
