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
        mapSnapshots: [MapSnapshotRequest: NSImage]
    ) throws -> (any OverlayExportPixelBufferRenderer)? {
        guard backend == .skia else { return nil }
        #if canImport(CSkiaBridge)
        return try SkiaExportFrameRenderer(
            size: size, layout: layout, activity: activity, mapSnapshots: mapSnapshots
        )
        #else
        throw OverlayRendererBackendError.unavailable(.skia)
        #endif
    }
}

#if canImport(CSkiaBridge)
// Adapts the shared Metal session to the export writer's IOSurface buffers.
private final class SkiaExportFrameRenderer: OverlayExportPixelBufferRenderer, @unchecked Sendable {
    private let session: SkiaMetalRenderSession
    private let size: CGSize

    @MainActor
    init(
        size: CGSize,
        layout: OverlayLayout,
        activity: ActivityTimeline,
        mapSnapshots: [MapSnapshotRequest: NSImage]
    ) throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            throw OverlayRendererBackendError.unavailable(.skia)
        }
        self.size = size
        session = try SkiaMetalRenderSession(
            size: size, layout: layout, activity: activity,
            device: device, commandQueue: queue, mapSnapshots: mapSnapshots
        )
    }

    func render(into pixelBuffer: CVPixelBuffer, elapsedTime: TimeInterval) throws {
        try autoreleasepool {
            guard CVPixelBufferGetWidth(pixelBuffer) == Int(size.width),
                  CVPixelBufferGetHeight(pixelBuffer) == Int(size.height),
                  CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA,
                  let surface = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() else {
                throw SwiftUIOverlayExportError.cannotCreatePixelBuffer
            }
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm,
                width: Int(size.width), height: Int(size.height), mipmapped: false
            )
            descriptor.usage = [.renderTarget, .shaderRead]
            descriptor.storageMode = .shared
            guard let texture = session.device.makeTexture(descriptor: descriptor, iosurface: surface, plane: 0) else {
                throw SwiftUIOverlayExportError.cannotCreatePixelBuffer
            }
            try session.render(into: texture, activityElapsedTime: elapsedTime)
        }
    }
}
#endif
