import AppKit
import Foundation

/// Process-wide cache for MapKit snapshots shared by the SwiftUI and Skia
/// preview paths.
///
/// MapKit can produce slightly different tiles, label placement, and
/// anti-aliasing for two identical requests. Letting each renderer fetch its
/// own snapshot made the same project look different depending on which
/// renderer drew it. Both previews now read through this cache so a given
/// `MapSnapshotRequest` resolves to exactly the same `NSImage`.
///
/// The cache is main-actor isolated because `NSImage` is not `Sendable` and
/// both preview hosts already request snapshots from the main actor.
@MainActor
final class MapSnapshotCache {
    static let shared = MapSnapshotCache()

    private var images: [MapSnapshotRequest: NSImage] = [:]
    private var insertionOrder: [MapSnapshotRequest] = []
    private var inFlight: [MapSnapshotRequest: Task<NSImage?, Never>] = [:]
    private let imageLimit = 12

    private init() {}

    func image(
        for request: MapSnapshotRequest,
        provider: any MapSnapshotProvider & Sendable = MapKitMapSnapshotProvider()
    ) async -> NSImage? {
        if let image = images[request] {
            touch(request)
            return image
        }
        if let task = inFlight[request] {
            return await task.value
        }

        let task = Task<NSImage?, Never> {
            await provider.snapshotImage(for: request).image
        }
        inFlight[request] = task
        let image = await task.value
        inFlight[request] = nil

        if let image {
            images[request] = image
            touch(request)
            while insertionOrder.count > imageLimit {
                let evicted = insertionOrder.removeFirst()
                images[evicted] = nil
            }
        }
        return image
    }

    private func touch(_ request: MapSnapshotRequest) {
        insertionOrder.removeAll { $0 == request }
        insertionOrder.append(request)
    }

    /// Test hook: drops cached images so an injected provider cannot be
    /// shadowed by a snapshot cached earlier in the process.
    func removeAll() {
        images.removeAll()
        insertionOrder.removeAll()
    }
}
