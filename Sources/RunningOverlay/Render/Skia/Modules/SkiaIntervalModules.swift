#if canImport(CSkiaBridge)
import CoreGraphics
import CSkiaBridge
import Foundation

/// Dispatch seam for the interval-family Skia ports.
///
/// The lead can route `OverlayElementType.intervalHUDBar`, `.intervalTimeline`,
/// `.intervalCountdown`, `.intervalWorkSummary`, and `.zoneEdgeBar` here without
/// editing the shared renderer files owned by other groups.
enum SkiaIntervalModules {
    static let supportedTypes: Set<OverlayElementType> = [
        .intervalHUDBar,
        .intervalTimeline,
        .intervalCountdown,
        .intervalWorkSummary,
        .zoneEdgeBar
    ]

    static func supports(_ element: OverlayElement) -> Bool {
        supportedTypes.contains(element.type)
    }

    /// Draws one interval-family element. `skiaContext` is the bridge context;
    /// `renderContext` supplies canvas size, activity, and elapsed time.
    static func draw(
        _ element: OverlayElement,
        in renderContext: OverlayRenderContext,
        skiaContext: OpaquePointer,
        maskCache: SkiaIntervalDraw.MaskCache
    ) {
        switch element.type {
        case .intervalHUDBar:
            let layout = OverlayRenderModel.intervalHUDBarLayout(
                for: element,
                in: renderContext
            )
            IntervalHUDBarSkiaRenderer.draw(
                element,
                layout: layout,
                context: skiaContext,
                maskCache: maskCache
            )
        case .intervalTimeline:
            let layout = OverlayRenderModel.intervalTimelineLayout(
                for: element,
                in: renderContext
            )
            IntervalTimelineSkiaRenderer.draw(
                element,
                layout: layout,
                context: skiaContext,
                maskCache: maskCache
            )
        case .intervalCountdown:
            let layout = OverlayRenderModel.intervalCountdownLayout(
                for: element,
                in: renderContext
            )
            IntervalCountdownSkiaRenderer.draw(
                element,
                layout: layout,
                context: skiaContext,
                maskCache: maskCache
            )
        case .intervalWorkSummary:
            let layout = OverlayRenderModel.intervalWorkSummaryLayout(
                for: element,
                in: renderContext
            )
            IntervalWorkSummarySkiaRenderer.draw(
                element,
                layout: layout,
                context: skiaContext,
                maskCache: maskCache
            )
        case .zoneEdgeBar:
            let layout = OverlayRenderModel.zoneEdgeBarLayout(
                for: element,
                in: renderContext
            )
            ZoneEdgeBarSkiaRenderer.draw(
                element,
                layout: layout,
                context: skiaContext,
                maskCache: maskCache
            )
        default:
            break
        }
    }
}

/// Small raster host used by parity tests to render interval elements without
/// wiring the full export backend.
final class SkiaIntervalFrameRenderer {
    let size: CGSize
    private let context: OpaquePointer
    private let maskCache = SkiaIntervalDraw.MaskCache()

    init?(size: CGSize) {
        guard let context = skb_create(Int32(size.width), Int32(size.height)) else {
            return nil
        }
        self.context = context
        self.size = size
    }

    deinit {
        skb_destroy(context)
    }

    /// Renders supported elements; returns premultiplied BGRA pixels borrowed
    /// until the next render.
    func render(
        layout: OverlayLayout,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval
    ) -> (UnsafePointer<UInt8>, Int) {
        skb_clear(context)
        let renderContext = OverlayRenderContext(
            canvasSize: size,
            activity: activity,
            elapsedTime: elapsedTime
        )
        for element in layout.elements
        where element.isVisible && SkiaIntervalModules.supports(element) {
            SkiaIntervalModules.draw(
                element,
                in: renderContext,
                skiaContext: context,
                maskCache: maskCache
            )
        }
        var rowBytes = 0
        let base = skb_pixels(context, &rowBytes)!
        return (base, rowBytes)
    }
}
#endif
