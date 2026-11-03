#if DEBUG && canImport(CSkiaBridge)
import AppKit
import CoreGraphics
import Foundation
import Metal
import Testing
@testable import RunningOverlay

/// Preview asset preload: map snapshots are fetched off the frame path, cached,
/// registered through `preloadAssets`, and cause exactly one redraw.
@MainActor
@Suite(.serialized) struct SkiaPreviewAssetPreloadTests {
    private static let hd1080 = CGSize(width: 1920, height: 1080)

    @Test func routeMapSnapshotIsFetchedOnceAndRedrawsWhenItArrives() async throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            Issue.record("No Metal device available")
            return
        }

        let element = Self.routeMapElement(background: .dark)
        let renderContext = OverlayRenderContext(
            canvasSize: Self.hd1080,
            activity: Self.activity,
            elapsedTime: 0
        )
        let routeLayout = OverlayRenderModel.routeMapLayout(for: element, in: renderContext)
        _ = try #require(
            RouteMapSnapshotRequestBuilder.request(for: element, layout: routeLayout),
            "fixture must produce a MapKit snapshot request"
        )

        let provider = ManualMapSnapshotProvider(
            image: Self.solidImage(size: routeLayout.rect.size, color: .systemPink)
        )
        let view = SkiaPreviewMetalView(
            frame: CGRect(origin: .zero, size: CGSize(width: 480, height: 270))
        )
        view.mapSnapshotProvider = provider
        view.configure(
            layout: OverlayLayout(elements: [element]),
            activity: Self.activity,
            elapsedTime: 12,
            canvasSize: Self.hd1080,
            isPaused: true
        )
        let baseline = view.presentedFrameCount

        try await Self.waitUntil { provider.requestCount == 1 }
        #expect(provider.pendingCount == 1)

        // Render once with the grid fallback, complete the snapshot, then
        // verify the arriving asset changed the map pixels.
        let before = try Self.readPixels(view: view, size: Self.hd1080)
        provider.completeAll()
        try await Self.waitUntil { view.presentedFrameCount == baseline + 1 }
        let after = try Self.readPixels(view: view, size: Self.hd1080)

        let changed = Self.changedPixelCount(
            after: after,
            before: before,
            in: routeLayout.rect,
            canvasWidth: Int(Self.hd1080.width)
        )
        #expect(changed > 1_000)

        // Frame rendering must never issue snapshot requests.
        for _ in 0..<3 {
            _ = view.renderFrame()
        }
        #expect(provider.requestCount == 1)

        // Reconfiguring with the same layout/activity must not refetch.
        view.configure(
            layout: OverlayLayout(elements: [element]),
            activity: Self.activity,
            elapsedTime: 13,
            canvasSize: Self.hd1080,
            isPaused: true
        )
        #expect(provider.requestCount == 1)
    }

    @Test func routeMapWithoutBackgroundDoesNotFetchSnapshots() {
        let provider = ManualMapSnapshotProvider(
            image: NSImage(size: CGSize(width: 320, height: 240))
        )
        let view = SkiaPreviewMetalView(
            frame: CGRect(origin: .zero, size: CGSize(width: 480, height: 270))
        )
        view.mapSnapshotProvider = provider
        view.configure(
            layout: OverlayLayout(elements: [Self.routeMapElement(background: .none)]),
            activity: Self.activity,
            elapsedTime: 12,
            canvasSize: Self.hd1080,
            isPaused: true
        )

        #expect(provider.requestCount == 0)
    }

    /// Decor icon and decor text joined the unified dispatch in this merge;
    /// neither may fall back to SwiftUI.
    @Test func decorIconAndTextRenderThroughSkia() throws {
        var iconStyle = OverlayStyle.default
        iconStyle.decor.iconAsset = .sfSymbol(name: "heart.fill")
        let icon = OverlayElement(
            type: .decorIcon,
            position: CGPoint(x: 0.4, y: 0.5),
            scale: 1,
            style: iconStyle
        )

        var textStyle = OverlayStyle.default
        textStyle.decor.textContent = "SKIA"
        let text = OverlayElement(
            type: .decorText,
            position: CGPoint(x: 0.6, y: 0.5),
            scale: 1,
            style: textStyle
        )

        for element in [icon, text] {
            #expect(SkiaEasyRunRenderer.supports(element), "\(element.type.rawValue)")

            let renderer = try #require(SkiaEasyRunRenderer(size: Self.hd1080))
            let (pixels, rowBytes) = try #require(renderer.render(
                layout: OverlayLayout(elements: [element]),
                activity: Self.activity,
                elapsedTime: 12
            ))

            var drewPixels = false
            for y in stride(from: 0, to: Int(Self.hd1080.height), by: 8) where !drewPixels {
                for x in stride(from: 0, to: Int(Self.hd1080.width), by: 8) {
                    if pixels[y * rowBytes + x * 4 + 3] > 0 {
                        drewPixels = true
                        break
                    }
                }
            }
            #expect(drewPixels, "\(element.type.rawValue) drew nothing")
        }
    }

    // MARK: - Fixtures

    private static func routeMapElement(
        background: OverlayRouteMapBackgroundStyle
    ) -> OverlayElement {
        var style = OverlayStyle.default
        style.routeMapBackgroundStyle = background
        style.routeMapWidth = 320
        style.routeMapHeight = 240
        return OverlayElement(
            type: .routeMap,
            position: CGPoint(x: 0.5, y: 0.5),
            scale: 1,
            style: style
        )
    }

    private static func solidImage(size: CGSize, color: NSColor) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }

    private static func waitUntil(
        _ condition: () -> Bool,
        timeout: TimeInterval = 2
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            await Task.yield()
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(condition())
    }

    private static func readPixels(
        view: SkiaPreviewMetalView,
        size: CGSize
    ) throws -> [UInt8] {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let width = Int(size.width)
        let height = Int(size.height)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        let texture = try #require(device.makeTexture(descriptor: descriptor))

        #expect(view.renderIntoTexture(texture))

        let rowBytes = width * 4
        var pixels = [UInt8](repeating: 0, count: rowBytes * height)
        texture.getBytes(
            &pixels,
            bytesPerRow: rowBytes,
            from: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0
        )
        return pixels
    }

    private static func changedPixelCount(
        after: [UInt8],
        before: [UInt8],
        in rect: CGRect,
        canvasWidth: Int
    ) -> Int {
        let canvasHeight = before.count / (canvasWidth * 4)
        let minX = max(Int(rect.minX), 0)
        let maxX = min(Int(rect.maxX), canvasWidth)
        let minY = max(Int(rect.minY), 0)
        let maxY = min(Int(rect.maxY), canvasHeight)
        guard minX < maxX, minY < maxY else { return 0 }

        var changed = 0
        for y in minY..<maxY {
            for x in minX..<maxX {
                let index = (y * canvasWidth + x) * 4
                for channel in 0..<4 where abs(
                    Int(after[index + channel]) - Int(before[index + channel])
                ) > 8 {
                    changed += 1
                    break
                }
            }
        }
        return changed
    }

    private static let activity: ActivityTimeline = {
        let start = Date(timeIntervalSince1970: 1_735_689_600)
        let records = stride(from: 0.0, through: 60, by: 1).map { t in
            ActivityRecord(
                elapsedTime: t,
                timestamp: start.addingTimeInterval(t),
                distanceMeters: t * 3.3,
                heartRate: 130 + Int(t / 3),
                paceSecondsPerKilometer: 300,
                elevationMeters: 20 + t / 10,
                cadence: 176,
                powerWatts: 250,
                calories: t / 4,
                latitude: 40.75 + 0.0006 * sin(t / 8),
                longitude: -73.99 + 0.0008 * cos(t / 8)
            )
        }
        return ActivityTimeline(
            startDate: start,
            duration: 60,
            distanceMeters: 200,
            records: records,
            laps: []
        )
    }()
}

/// Snapshot provider that records requests and lets a test complete them at a
/// deterministic point instead of hitting MapKit.
private final class ManualMapSnapshotProvider: MapSnapshotProvider, @unchecked Sendable {
    private let image: NSImage
    private let lock = NSLock()
    private var requests: [MapSnapshotRequest] = []
    private var pending: [(MapSnapshotRequest, @Sendable (Result<NSImage, Error>) -> Void)] = []

    init(image: NSImage) {
        self.image = image
    }

    var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return requests.count
    }

    var pendingCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return pending.count
    }

    func snapshot(
        for request: MapSnapshotRequest,
        completion: @escaping @Sendable (Result<NSImage, Error>) -> Void
    ) {
        lock.lock()
        requests.append(request)
        pending.append((request, completion))
        lock.unlock()
    }

    func completeAll() {
        lock.lock()
        let entries = pending
        pending.removeAll()
        lock.unlock()
        for (_, completion) in entries {
            completion(.success(image))
        }
    }
}
#endif
