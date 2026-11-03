#if canImport(CSkiaBridge)
import CSkiaBridge
import CoreGraphics
import Foundation

/// CPU Skia renderer for the first chart modules: distance timeline, running
/// gauge, and elevation chart. Preview/export hosts keep using their own
/// persistent contexts; this type is the golden-frame candidate renderer.
final class SkiaChartsRenderer {
    let size: CGSize
    private let canvas: SkiaChartsCanvas

    init?(size: CGSize) {
        guard let canvas = SkiaChartsCanvas(size: size) else { return nil }
        self.size = size
        self.canvas = canvas
    }

    static func supports(_ element: OverlayElement) -> Bool {
        switch element.type {
        case .distanceTimeline, .runningGauge, .elevationChart:
            true
        default:
            false
        }
    }

    /// Renders the supported elements and returns premultiplied BGRA pixels.
    /// The pointer is owned by the canvas and stays valid until the next render.
    func render(
        layout: OverlayLayout,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval
    ) -> (UnsafePointer<UInt8>, Int)? {
        skb_clear(canvas.context)
        let context = OverlayRenderContext(
            canvasSize: size,
            activity: activity,
            elapsedTime: elapsedTime
        )
        for element in layout.elements
        where element.isVisible && Self.supports(element) {
            switch element.type {
            case .distanceTimeline:
                let elementLayout = OverlayRenderModel.distanceTimelineLayout(
                    for: element,
                    in: context
                )
                SkiaDistanceTimelineRenderer.draw(
                    canvas: canvas,
                    element: element,
                    layout: elementLayout
                )
            case .runningGauge:
                let elementLayout = OverlayRenderModel.runningGaugeLayout(
                    for: element,
                    in: context
                )
                SkiaRunningGaugeRenderer.draw(
                    canvas: canvas,
                    element: element,
                    layout: elementLayout
                )
            default:
                break
            }
        }
        var rowBytes = 0
        guard let base = skb_pixels(canvas.context, &rowBytes) else {
            return nil
        }
        return (base, rowBytes)
    }
}
#endif
