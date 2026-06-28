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

/// How the elevation chart area fill is drawn for a given render pass. Used by
/// the SwiftUI export static-fill cache to bake reusable layers. `.standard`
/// reproduces the normal preview/export appearance and is the default.
enum ElevationChartFillRenderMode {
    /// Normal appearance: single fill, or dual-area upper plus progress-masked
    /// lower fill.
    case standard
    /// Base fill drawn full width with no progress mask: dual-area draws the
    /// upper fill only; single-area draws its single fill.
    case baseFill
    /// Dual-area lower fill only, full width, no mask, nothing else. Composited
    /// (cropped to the right of progress) on top of the base fill so the line
    /// layer can still sit above it.
    case lowerOnly
    /// No area fill at all (used by the dynamic marker layer).
    case none
}

/// Per-layer visibility used to bake static export layers and render the cheap
/// dynamic marker layer. Defaults reproduce the full preview appearance so the
/// live preview and normal export paths are unaffected.
struct ElevationChartLayerVisibility: Equatable {
    var showsContainerChrome = true
    var showsGrid = true
    var showsAxisLine = true
    var showsAxisLabels = true
    var fillMode: ElevationChartFillRenderMode = .standard
    var showsLine = true
    var showsMarker = true
    var showsStatsBar = true
    var showsBigNumbers = true
    var appliesOuterEffects = true
}

struct OverlaySharedElevationChartView: View {
    let element: OverlayElement
    let layout: OverlayElevationChartRenderLayout
    var visibility = ElevationChartLayerVisibility()

    var body: some View {
        ElevationChartOverlayView(
            element: element,
            layout: layout,
            visibility: visibility
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
