import AppKit
import Foundation
import MapKit

protocol MapSnapshotProvider {
    func snapshot(for request: MapSnapshotRequest, completion: @escaping @Sendable (Result<NSImage, Error>) -> Void)
}

struct MapSnapshotRequest: Hashable {
    var bounds: RouteBounds
    var size: CGSize
    var backgroundStyle: OverlayRouteMapBackgroundStyle
}

enum RouteMapSnapshotRequestBuilder {
    static func request(
        for element: OverlayElement,
        layout: OverlayRouteMapRenderLayout
    ) -> MapSnapshotRequest? {
        guard layout.provider == .mapKit,
              element.style.routeMapBackgroundStyle != .none,
              let geometry = layout.geometry,
              layout.rect.width > 1,
              layout.rect.height > 1 else {
            return nil
        }
        return MapSnapshotRequest(
            bounds: geometry.bounds,
            size: layout.rect.size,
            backgroundStyle: element.style.routeMapBackgroundStyle
        )
    }
}

final class MapKitMapSnapshotProvider: MapSnapshotProvider {
    func snapshot(for request: MapSnapshotRequest, completion: @escaping @Sendable (Result<NSImage, Error>) -> Void) {
        let options = MKMapSnapshotter.Options()
        options.size = request.size
        options.mapType = mapType(for: request.backgroundStyle)
        options.appearance = appearance(for: request.backgroundStyle)
        options.region = request.bounds.coordinateRegion(padding: 0.18)

        MKMapSnapshotter(options: options).start(with: DispatchQueue.global(qos: .userInitiated)) { snapshot, error in
            if let snapshot {
                completion(.success(snapshot.image))
            } else {
                completion(.failure(error ?? MapSnapshotError.emptySnapshot))
            }
        }
    }

    private func mapType(for style: OverlayRouteMapBackgroundStyle) -> MKMapType {
        switch style {
        case .none:
            .mutedStandard
        case .dark:
            .mutedStandard
        case .light:
            .standard
        case .terrain:
            .hybrid
        case .satellite:
            .satellite
        }
    }

    private func appearance(for style: OverlayRouteMapBackgroundStyle) -> NSAppearance? {
        let appearanceName: NSAppearance.Name
        switch style {
        case .dark:
            appearanceName = .darkAqua
        case .none, .light, .terrain, .satellite:
            appearanceName = .aqua
        }
        return NSAppearance(named: appearanceName)
    }
}

enum MapSnapshotError: LocalizedError {
    case emptySnapshot

    var errorDescription: String? {
        "MapKit did not return a map snapshot."
    }
}

enum RouteGeometryBuilder {
    static func geometry(from activity: ActivityTimeline) -> RouteGeometry? {
        let points = cleaned(points: activity.routePoints)
        guard points.count > 1 else {
            return nil
        }

        let latitudes = points.map(\.latitude)
        let longitudes = points.map(\.longitude)
        let bounds = RouteBounds(
            minLatitude: latitudes.min() ?? 0,
            maxLatitude: latitudes.max() ?? 0,
            minLongitude: longitudes.min() ?? 0,
            maxLongitude: longitudes.max() ?? 0
        )
        return RouteGeometry(points: points, bounds: bounds, distanceMeters: activity.distanceMeters)
    }

    private static func cleaned(points: [RoutePoint]) -> [RoutePoint] {
        points.reduce(into: []) { result, point in
            guard point.latitude.isFinite,
                  point.longitude.isFinite,
                  (-90...90).contains(point.latitude),
                  (-180...180).contains(point.longitude) else {
                return
            }
            if let previous = result.last,
               abs(previous.latitude - point.latitude) < 0.000001,
               abs(previous.longitude - point.longitude) < 0.000001 {
                return
            }
            result.append(point)
        }
    }
}

struct OverlayRouteMapStatsBarItemLayout {
    var value: String
    var unit: String
    var label: String
}

struct OverlayRouteMapStatsBarLayout {
    var rect: CGRect
    var isInside: Bool
    var containerRect: CGRect
    var containerShape: OverlayRouteMapShape
    var containerCornerRadius: Double
    var backgroundOpacity: Double
    var blurRadius: Double
    var dividerOpacity: Double
    var cornerRadius: Double
    var itemSpacing: Double
    var layoutMode: RouteMapStatsBarLayoutMode
    var placement: RouteMapStatsBarPlacement
    var items: [OverlayRouteMapStatsBarItemLayout]
    var fontName: String
    var valueFontName: String
    var valueFontSize: Double
    var valueFontWeight: OverlayFontWeight
    var valueColor: OverlayColor
    var labelFontName: String
    var labelFontSize: Double
    var labelFontWeight: OverlayFontWeight
    var labelColor: OverlayColor
}

struct OverlayRouteMapRenderLayout {
    var provider: OverlayRouteMapProvider
    var rect: CGRect
    var contentRect: CGRect
    var cornerRadius: Double
    var shape: OverlayRouteMapShape
    var edgeFade: OverlayRouteMapEdgeFade
    var fadeAmount: Double
    var borderVisible: Bool
    var lineWidth: Double
    var glowEnabled: Bool
    var glowRadius: Double
    var mapOpacity: Double
    var progress: Double
    var geometry: RouteGeometry?
    var currentPoint: RoutePoint?
    var statsBarLayout: OverlayRouteMapStatsBarLayout?

    var projectedPoints: [CGPoint] {
        guard let geometry else {
            return []
        }
        return geometry.points.map { project($0, bounds: geometry.bounds, rect: contentRect) }
    }

    var projectedCurrentPoint: CGPoint? {
        guard let geometry, let currentPoint else {
            return nil
        }
        return project(currentPoint, bounds: geometry.bounds, rect: contentRect)
    }

    private func project(_ point: RoutePoint, bounds: RouteBounds, rect: CGRect) -> CGPoint {
        // Web Mercator y is monotonically *decreasing* as latitude grows
        // (north → small mercator y, south → large mercator y). Both the
        // SwiftUI preview canvas and the export renderer (set up with
        // `NSGraphicsContext(cgContext:flipped:true)`) use a y-down
        // coordinate system, so mercator y maps directly to render y once
        // we recompute min/max from the actual projected corners (they
        // were inverted in the original code, which produced a near-zero
        // y-range and threw points outside `rect`).
        let projectedMinX = mercatorX(bounds.minLongitude)
        let projectedMaxX = mercatorX(bounds.maxLongitude)
        let projectedSouth = mercatorY(bounds.minLatitude)
        let projectedNorth = mercatorY(bounds.maxLatitude)
        let minX = min(projectedMinX, projectedMaxX)
        let maxX = max(projectedMinX, projectedMaxX)
        let minY = min(projectedSouth, projectedNorth)
        let maxY = max(projectedSouth, projectedNorth)
        let xRange = max(maxX - minX, 0.000001)
        let yRange = max(maxY - minY, 0.000001)
        let scale = min(rect.width / xRange, rect.height / yRange)
        let contentWidth = xRange * scale
        let contentHeight = yRange * scale
        let xOffset = (rect.width - contentWidth) * 0.5
        let yOffset = (rect.height - contentHeight) * 0.5
        let localX = (mercatorX(point.longitude) - minX) * scale
        // North (small mercator y) lands at the top of rect, south at the
        // bottom — this matches the y-down render coordinate system.
        let localY = (mercatorY(point.latitude) - minY) * scale
        return CGPoint(
            x: rect.minX + xOffset + localX,
            y: rect.minY + yOffset + localY
        )
    }

    private func mercatorX(_ longitude: Double) -> Double {
        (longitude + 180) / 360
    }

    private func mercatorY(_ latitude: Double) -> Double {
        let clampedLatitude = min(max(latitude, -85.05112878), 85.05112878)
        let radians = clampedLatitude * .pi / 180
        return (1 - log(tan(radians) + 1 / cos(radians)) / .pi) / 2
    }
}

enum RouteMapMaskRenderer {
    static func makeCGMask(
        size: CGSize,
        shape: OverlayRouteMapShape,
        cornerRadius: Double,
        edgeFade: OverlayRouteMapEdgeFade,
        fadeAmount: Double
    ) -> CGImage? {
        let width = max(Int(size.width.rounded(.up)), 1)
        let height = max(Int(size.height.rounded(.up)), 1)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let rect = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        switch edgeFade {
        case .solid:
            context.setFillColor(gray: 1, alpha: 1)
            shapePath(shape: shape, rect: rect, cornerRadius: cornerRadius).fill()
        case .fadeOut:
            if shape == .square,
               let mask = OverlayFeatherMaskRenderer.makeCGMask(
                   size: CGSize(width: width, height: height),
                   cornerRadius: cornerRadius,
                   fadeAmount: min(max(fadeAmount, 0), Self.maxFadeAmount)
               ) {
                return mask
            }
            drawFadeMask(
                in: context,
                shape: shape,
                rect: rect,
                cornerRadius: cornerRadius,
                fadeAmount: min(max(fadeAmount, 0), Self.maxFadeAmount)
            )
        }
        return context.makeImage()
    }

    /// Maximum allowed Edge Softness. Above this the inner solid region
    /// disappears entirely and the box becomes invisible, so we cap the
    /// slider here. The value matches the docs spec.
    static let maxFadeAmount: Double = 0.85

    static func makeNSImage(
        size: CGSize,
        shape: OverlayRouteMapShape,
        cornerRadius: Double,
        edgeFade: OverlayRouteMapEdgeFade,
        fadeAmount: Double
    ) -> NSImage? {
        guard let cgMask = makeCGMask(
            size: size,
            shape: shape,
            cornerRadius: cornerRadius,
            edgeFade: edgeFade,
            fadeAmount: fadeAmount
        ) else {
            return nil
        }
        return NSImage(cgImage: cgMask, size: size)
    }

    private static func drawFadeMask(
        in context: CGContext,
        shape: OverlayRouteMapShape,
        rect: CGRect,
        cornerRadius: Double,
        fadeAmount: Double
    ) {
        if fadeAmount <= 0.001 {
            context.setFillColor(gray: 1, alpha: 1)
            shapePath(shape: shape, rect: rect, cornerRadius: cornerRadius).fill()
            return
        }

        switch shape {
        case .circle:
            // Radial gradient: works perfectly for circular containers.
            context.saveGState()
            context.addPath(shapePath(shape: shape, rect: rect, cornerRadius: cornerRadius).cgPath)
            context.clip()
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceGray(),
                colors: [CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 1), CGColor(gray: 0, alpha: 1)] as CFArray,
                locations: [0, 0.45, 1] as [CGFloat]
            ) else {
                context.restoreGState()
                return
            }
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let outerRadius = min(rect.width, rect.height) * 0.5
            let innerRadius = outerRadius * max(0, 1 - fadeAmount)
            context.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: innerRadius,
                endCenter: center,
                endRadius: outerRadius,
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
            context.restoreGState()

        case .square:
            // Step 1: fill the shape interior white, clipped to the rounded rect.
            context.saveGState()
            context.addPath(shapePath(shape: shape, rect: rect, cornerRadius: cornerRadius).cgPath)
            context.clip()
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(rect)
            context.restoreGState()

            // Step 2: apply fade per-pixel using a rounded-rect SDF so the
            // softness follows the corner curve instead of producing pointy
            // bright corners. The SDF gives the signed distance to the shape
            // boundary (negative inside), so distToBoundary = -sdf.
            let fadeWidth = min(rect.width, rect.height) * 0.5 * fadeAmount
            guard fadeWidth > 0.5, let data = context.data else { return }
            let ctxW = context.width
            let ctxH = context.height
            let bpr = context.bytesPerRow
            let buf = data.assumingMemoryBound(to: UInt8.self)
            let cx = Double(ctxW) * 0.5
            let cy = Double(ctxH) * 0.5
            let hw = Double(ctxW) * 0.5   // half-width
            let hh = Double(ctxH) * 0.5   // half-height
            // Clamp radius so it never exceeds the shorter half-dimension.
            let r = min(cornerRadius, min(hw, hh))
            for row in 0..<ctxH {
                let base = row * bpr
                let py = Double(row) - cy + 0.5
                for col in 0..<ctxW {
                    let v = buf[base + col]
                    guard v > 0 else { continue }
                    let px = Double(col) - cx + 0.5
                    // Rounded-rect SDF (standard formulation).
                    let qx = abs(px) - (hw - r)
                    let qy = abs(py) - (hh - r)
                    let sdf = sqrt(max(qx, 0) * max(qx, 0) + max(qy, 0) * max(qy, 0))
                              + min(max(qx, qy), 0) - r
                    // Inside the shape sdf < 0; distance from boundary = -sdf.
                    let alpha = min(max(-sdf / fadeWidth, 0), 1)
                    buf[base + col] = UInt8(alpha * 255)
                }
            }
        }
    }

    static func shapePath(shape: OverlayRouteMapShape, rect: CGRect, cornerRadius: Double) -> NSBezierPath {
        switch shape {
        case .square:
            return NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        case .circle:
            return NSBezierPath(ovalIn: rect)
        }
    }
}

extension RouteBounds {
    func coordinateRegion(padding: Double) -> MKCoordinateRegion {
        let latitudeDelta = max(maxLatitude - minLatitude, 0.002)
        let longitudeDelta = max(maxLongitude - minLongitude, 0.002)
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLatitude + maxLatitude) / 2,
                longitude: (minLongitude + maxLongitude) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: latitudeDelta * (1 + padding * 2),
                longitudeDelta: longitudeDelta * (1 + padding * 2)
            )
        )
    }
}
