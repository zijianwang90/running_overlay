#if canImport(CSkiaBridge)
import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import RunningOverlay

/// Guards the animated media-slot path used by the preview display link and
/// the export loop: frames are sampled on a fixed grid and rasterized once, so
/// per-frame drawing only reads the bounded canvas image cache.
@Suite struct SkiaChartsMediaSlotCacheTests {
    private static let animatedSVG = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
          <circle cx="12" cy="12" r="8" fill="#ff5533">
            <animate attributeName="opacity" values="0.2;1;0.2"
                     dur="1.2s" repeatCount="indefinite"/>
          </circle>
        </svg>
        """

    @Test func animatedMediaSlotCachesBoundedFrames() throws {
        let size = CGSize(width: 640, height: 360)
        let canvas = try #require(SkiaChartsCanvas(size: size))
        let element = Self.distanceTimelineElement()
        let activity = SkiaChartsGoldenTests.activity(duration: 600)

        func draw(at elapsedTime: TimeInterval) {
            let context = OverlayRenderContext(
                canvasSize: size,
                activity: activity,
                elapsedTime: elapsedTime
            )
            let layout = OverlayRenderModel.distanceTimelineLayout(
                for: element,
                in: context
            )
            SkiaDistanceTimelineRenderer.draw(
                canvas: canvas,
                element: element,
                layout: layout
            )
        }

        draw(at: 0)
        let populated = canvas.cachedImageCount
        #expect(populated > 1, "animated slot should pre-rasterize frames")

        // A full export-length sweep must not add entries: the sampled frame
        // grid is finite and every later frame is a cache hit.
        var time: TimeInterval = 0
        while time < 12 {
            draw(at: time)
            time += 1.0 / 30.0
        }
        #expect(canvas.cachedImageCount == populated)
        #expect(canvas.cachedImageCount <= 24)
    }

    // MARK: - Fixture

    private static func distanceTimelineElement() -> OverlayElement {
        var style = OverlayStyle.default
        var timeline = DistanceTimelineStyle.preset(.sport)
        timeline.width = 420
        timeline.height = 96
        timeline.statsBar.visible = false
        timeline.mediaSlotEnabled = true
        timeline.mediaSlotMode = .animatedSVG
        timeline.mediaSlotSize = 44
        timeline.mediaSlot.mode = .animatedSVG
        timeline.mediaSlot.svgSource = animatedSVG
        timeline.mediaSlot.animationDuration = 1.2
        timeline.mediaSlot.animationSpeed = 1
        timeline.mediaSlot.loop = true
        style.distanceTimeline = timeline
        style.fontName = "Helvetica Neue"
        return OverlayElement(
            type: .distanceTimeline,
            position: CGPoint(x: 0.5, y: 0.5),
            scale: 1,
            style: style
        )
    }
}
#endif
