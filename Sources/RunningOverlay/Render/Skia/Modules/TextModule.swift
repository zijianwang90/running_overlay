#if canImport(CSkiaBridge)
import AppKit
import CSkiaBridge
import Foundation

/// Group T entry point for decor elements. Numeric readings are the bundled
/// `studio.numeric` component (ADR 0014) and draw through the component
/// renderer.
enum SkiaTextModule {
    static func supports(_ element: OverlayElement) -> Bool {
        element.type.isDecorOverlay
    }

    @discardableResult
    static func draw(
        element: OverlayElement,
        context: OpaquePointer,
        canvasSize: CGSize,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval
    ) -> Bool {
        guard element.isVisible, element.type.isDecorOverlay else { return false }
        SkiaDecorDrawing.draw(
            element: element,
            context: context,
            renderContext: OverlayRenderContext(
                canvasSize: canvasSize,
                activity: activity,
                elapsedTime: elapsedTime
            )
        )
        return true
    }
}
#endif
