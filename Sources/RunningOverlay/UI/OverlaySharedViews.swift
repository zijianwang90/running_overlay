import AppKit
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
    var staticMapSnapshot: NSImage? = nil
    var showsBaseContent = true
    var showsCurrentMarker = true
    var showsContainerEffects = true

    var body: some View {
        RouteMapOverlayView(
            element: element,
            layout: layout,
            isSelected: isInteractive,
            staticMapSnapshot: staticMapSnapshot,
            showsBaseContent: showsBaseContent,
            showsCurrentMarker: showsCurrentMarker,
            showsContainerEffects: showsContainerEffects
        )
    }
}

struct OverlaySharedElevationChartView: View {
    let element: OverlayElement
    let layout: OverlayElevationChartRenderLayout

    var body: some View {
        ElevationChartOverlayView(
            element: element,
            layout: layout
        )
    }
}

struct OverlaySharedRunningGaugeView: View {
    let element: OverlayElement
    let layout: OverlayRunningGaugeRenderLayout
    let isInteractive: Bool

    var body: some View {
        RunningGaugeOverlayView(
            element: element,
            layout: layout,
            isSelected: isInteractive
        )
    }
}

struct OverlaySharedIntervalHUDBarView: View {
    let element: OverlayElement
    let layout: IntervalHUDBarRenderLayout

    var body: some View {
        IntervalHUDBarOverlayView(
            element: element,
            layout: layout
        )
    }
}

struct OverlaySharedIntervalTimelineView: View {
    let element: OverlayElement
    let layout: IntervalTimelineRenderLayout

    var body: some View {
        IntervalTimelineOverlayView(
            element: element,
            layout: layout
        )
    }
}

struct OverlaySharedZoneEdgeBarView: View {
    let element: OverlayElement
    let layout: ZoneEdgeBarRenderLayout

    var body: some View {
        ZoneEdgeBarOverlayView(
            element: element,
            layout: layout
        )
    }
}
