import AppKit
import Foundation
import MapKit

protocol MapSnapshotProvider {
    func snapshot(for request: MapSnapshotRequest, completion: @escaping @Sendable (Result<NSImage, Error>) -> Void)
}

struct MapSnapshotRequest: Hashable {
    var bounds: RouteBounds
    var size: CGSize
    var style: OverlayRouteMapPreset
    var backgroundStyle: OverlayRouteMapBackgroundStyle
}

final class MapKitMapSnapshotProvider: MapSnapshotProvider {
    func snapshot(for request: MapSnapshotRequest, completion: @escaping @Sendable (Result<NSImage, Error>) -> Void) {
        let options = MKMapSnapshotter.Options()
        options.size = request.size
        options.mapType = mapType(for: request.backgroundStyle)
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

struct OverlayRouteMapRenderLayout {
    var preset: OverlayRouteMapPreset
    var provider: OverlayRouteMapProvider
    var rect: CGRect
    var contentRect: CGRect
    var cornerRadius: Double
    var shape: OverlayRouteMapShape
    var edgeFade: OverlayRouteMapEdgeFade
    var fadeAmount: Double
    var lineWidth: Double
    var glowRadius: Double
    var progress: Double
    var geometry: RouteGeometry?
    var currentPoint: RoutePoint?

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
        let minX = mercatorX(bounds.minLongitude)
        let maxX = mercatorX(bounds.maxLongitude)
        let minY = mercatorY(bounds.minLatitude)
        let maxY = mercatorY(bounds.maxLatitude)
        let xRange = max(maxX - minX, 0.000001)
        let yRange = max(maxY - minY, 0.000001)
        let x = (mercatorX(point.longitude) - minX) / xRange
        let y = (mercatorY(point.latitude) - minY) / yRange
        return CGPoint(
            x: rect.minX + rect.width * x,
            y: rect.maxY - rect.height * y
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
            drawFadeMask(
                in: context,
                shape: shape,
                rect: rect,
                cornerRadius: cornerRadius,
                fadeAmount: min(max(fadeAmount, 0.05), 0.45)
            )
        }
        return context.makeImage()
    }

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
        context.saveGState()
        shapePath(shape: shape, rect: rect, cornerRadius: cornerRadius).addClip()

        switch shape {
        case .circle:
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let outerRadius = min(rect.width, rect.height) * 0.5
            let innerRadius = outerRadius * (1 - fadeAmount)
            let colors = [CGColor(gray: 1, alpha: 1), CGColor(gray: 0, alpha: 1)] as CFArray
            let locations: [CGFloat] = [0, 1]
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceGray(), colors: colors, locations: locations) else {
                context.restoreGState()
                return
            }
            context.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: innerRadius,
                endCenter: center,
                endRadius: outerRadius,
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        case .square:
            let inset = min(rect.width, rect.height) * fadeAmount
            let innerRect = rect.insetBy(dx: inset, dy: inset)
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(innerRect)

            let colors = [CGColor(gray: 0, alpha: 1), CGColor(gray: 1, alpha: 1)] as CFArray
            let locations: [CGFloat] = [0, 1]
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceGray(), colors: colors, locations: locations) else {
                context.restoreGState()
                return
            }

            context.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.midY), end: CGPoint(x: innerRect.minX, y: rect.midY), options: [.drawsAfterEndLocation])
            context.drawLinearGradient(gradient, start: CGPoint(x: rect.maxX, y: rect.midY), end: CGPoint(x: innerRect.maxX, y: rect.midY), options: [.drawsAfterEndLocation])
            context.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.minY), end: CGPoint(x: rect.midX, y: innerRect.minY), options: [.drawsAfterEndLocation])
            context.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.maxY), end: CGPoint(x: rect.midX, y: innerRect.maxY), options: [.drawsAfterEndLocation])
        }
        context.restoreGState()
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
