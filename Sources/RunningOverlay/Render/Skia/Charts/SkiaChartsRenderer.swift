#if canImport(CSkiaBridge)
import CSkiaBridge
import CoreGraphics
import Foundation

/// Caller-owned-context entry point for preview and export hosts. The host
/// keeps a persistent (raster or GPU) context; this module draws one chart
/// element into it without creating a context or reading pixels back.
enum SkiaChartsModule {
    static func supports(_ element: OverlayElement) -> Bool {
        switch element.type {
        case .distanceTimeline, .elevationChart:
            true
        default:
            false
        }
    }

    /// Draws one element into `context`. This creates a short-lived canvas
    /// wrapper so text and image caches are not shared across calls; hosts that
    /// want caches should retain a `SkiaChartsCanvas(context:size:)` and use the
    /// overload below.
    static func draw(
        _ element: OverlayElement,
        renderContext: OverlayRenderContext,
        context: OpaquePointer
    ) {
        let canvas = SkiaChartsCanvas(
            context: context,
            size: renderContext.canvasSize
        )
        draw(element, renderContext: renderContext, canvas: canvas)
    }

    /// Draws one element using a caller-held canvas and its caches.
    static func draw(
        _ element: OverlayElement,
        renderContext: OverlayRenderContext,
        canvas: SkiaChartsCanvas
    ) {
        guard element.isVisible, supports(element) else { return }
        switch element.type {
        case .distanceTimeline:
            let elementLayout = OverlayRenderModel.distanceTimelineLayout(
                for: element,
                in: renderContext
            )
            SkiaDistanceTimelineRenderer.draw(
                canvas: canvas,
                element: element,
                layout: elementLayout
            )
        case .elevationChart:
            let elementLayout = OverlayRenderModel.elevationChartLayout(
                for: element,
                in: renderContext
            )
            SkiaElevationChartRenderer.draw(
                canvas: canvas,
                element: element,
                layout: elementLayout
            )
        default:
            break
        }
    }
}

/// CPU Skia renderer for the first chart modules: distance timeline and
/// elevation chart. This type is the golden-frame candidate
/// renderer; preview/export hosts draw through `SkiaChartsModule`.
final class SkiaChartsRenderer {
    let size: CGSize
    private let canvas: SkiaChartsCanvas

    init?(size: CGSize) {
        guard let canvas = SkiaChartsCanvas(size: size) else { return nil }
        self.size = size
        self.canvas = canvas
    }

    static func supports(_ element: OverlayElement) -> Bool {
        SkiaChartsModule.supports(element)
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
        where element.isVisible && SkiaChartsModule.supports(element) {
            SkiaChartsModule.draw(
                element,
                renderContext: context,
                canvas: canvas
            )
        }
        var rowBytes = 0
        guard let base = skb_pixels(canvas.context, &rowBytes) else {
            return nil
        }
        return (base, rowBytes)
    }
}
#endif
