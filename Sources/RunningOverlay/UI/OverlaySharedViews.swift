import SwiftUI

struct OverlaySharedTextPresetView: View {
    let element: OverlayElement
    let layout: OverlayTextRenderLayout
    let isInteractive: Bool

    var body: some View {
        TextPresetOverlayView(
            element: element,
            layout: layout,
            isSelected: isInteractive
        )
    }
}

struct OverlaySharedDistanceTimelineView: View {
    let element: OverlayElement
    let layout: OverlayDistanceTimelineRenderLayout
    let isInteractive: Bool

    var body: some View {
        DistanceTimelineOverlayView(
            element: element,
            layout: layout,
            isSelected: isInteractive
        )
    }
}

struct OverlaySharedRouteMapView: View {
    let element: OverlayElement
    let layout: OverlayRouteMapRenderLayout
    let isInteractive: Bool

    var body: some View {
        RouteMapOverlayView(
            element: element,
            layout: layout,
            isSelected: isInteractive
        )
    }
}
