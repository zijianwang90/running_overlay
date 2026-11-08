import AppKit
import CoreVideo
import Foundation
import Metal

/// One serial export owns this renderer. Buffers remain owned by the writer;
/// each unique sample gets a fresh buffer, and repeated samples only read it.
protocol OverlayExportPixelBufferRenderer: AnyObject, Sendable {
    func render(into pixelBuffer: CVPixelBuffer, elapsedTime: TimeInterval) throws
}

enum OverlayExportRendererFactory {
    @MainActor
    static func make(
        backend: OverlayRendererBackendKind,
        size: CGSize,
        layout: OverlayLayout,
        activity: ActivityTimeline,
        mapSnapshots: [MapSnapshotRequest: NSImage],
        weatherPayload: WeatherPayload? = nil
    ) throws -> (any OverlayExportPixelBufferRenderer)? {
        guard backend == .skia else { return nil }
        #if canImport(CSkiaBridge)
        return try SkiaExportFrameRenderer(
            size: size, layout: layout, activity: activity, mapSnapshots: mapSnapshots,
            weatherPayload: weatherPayload
        )
        #else
        throw OverlayRendererBackendError.unavailable(.skia)
        #endif
    }
}

#if canImport(CSkiaBridge)
// Asset creation runs on MainActor. After initialization, the renderer and
// its mutable caches are accessed only under this lock, never by preview.
private final class SkiaExportFrameRenderer: OverlayExportPixelBufferRenderer, @unchecked Sendable {
    private let lock = NSLock()
    private let device: MTLDevice
    private let renderer: SkiaEasyRunRenderer
    private let layout: OverlayLayout
    private let activity: ActivityTimeline
    private let size: CGSize

    @MainActor
    init(
        size: CGSize,
        layout: OverlayLayout,
        activity: ActivityTimeline,
        mapSnapshots: [MapSnapshotRequest: NSImage],
        weatherPayload: WeatherPayload? = nil
    ) throws {
        guard layout.elements.filter(\.isVisible).allSatisfy(SkiaEasyRunRenderer.supports),
              let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue(),
              let renderer = SkiaEasyRunRenderer(
                size: size, device: device, commandQueue: queue, offscreen: false
              ) else {
            throw OverlayRendererBackendError.unavailable(.skia)
        }
        self.device = device
        self.renderer = renderer
        self.layout = layout
        self.activity = activity
        self.size = size
        renderer.weatherPayload = weatherPayload
        renderer.preloadAssets(layout: layout, activity: activity, mapSnapshots: mapSnapshots)
    }

    func render(into pixelBuffer: CVPixelBuffer, elapsedTime: TimeInterval) throws {
        try lock.withLock {
            try autoreleasepool {
                guard let surface = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() else {
                    throw SwiftUIOverlayExportError.cannotCreatePixelBuffer
                }
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: .bgra8Unorm,
                    width: Int(size.width), height: Int(size.height), mipmapped: false
                )
                descriptor.usage = [.renderTarget, .shaderRead]
                descriptor.storageMode = .shared
                guard let texture = device.makeTexture(descriptor: descriptor, iosurface: surface, plane: 0),
                      renderer.wrap(texture: texture) else {
                    throw SwiftUIOverlayExportError.cannotCreatePixelBuffer
                }
                renderer.draw(layout: layout, activity: activity, elapsedTime: elapsedTime)
                // The encoder can read immediately after append. Complete GPU writes
                // before handing the buffer over, while retaining the wrapped texture.
                guard renderer.flush(sync: true) else {
                    throw SwiftUIOverlayExportError.appendFailed("Skia GPU submission failed.")
                }
                withExtendedLifetime(texture) {}
            }
        }
    }
}
#endif
