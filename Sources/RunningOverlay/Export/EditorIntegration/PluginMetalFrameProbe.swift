#if canImport(CSkiaBridge)
import CoreVideo
import Foundation
import Metal
import VideoToolbox
#if SWIFT_PACKAGE
import OverlayPluginCore
#endif

/// Developer PNG adapter, outside the host callback boundary. A sequence
/// reuses its session and IOSurface target; PNG conversion happens only after
/// synchronous GPU completion. A real host supplies its own texture instead.
@MainActor
final class PluginMetalFrameProbe {
    private let session: PluginMetalRenderSession
    private let pixelBuffer: CVPixelBuffer
    private let texture: any MTLTexture

    init(package: PluginDataPackage, templateID: UUID? = nil) throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            throw OverlayRendererBackendError.unavailable(.skia)
        }
        session = try PluginMetalRenderSession(
            package: package, templateID: templateID, device: device, commandQueue: queue
        )
        var buffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        guard CVPixelBufferCreate(
            nil, package.canvasWidth, package.canvasHeight, kCVPixelFormatType_32BGRA,
            attributes as CFDictionary, &buffer
        ) == kCVReturnSuccess, let buffer,
              let surface = CVPixelBufferGetIOSurface(buffer)?.takeUnretainedValue() else {
            throw SwiftUIOverlayExportError.cannotCreatePixelBuffer
        }
        pixelBuffer = buffer
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: package.canvasWidth, height: package.canvasHeight, mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor, iosurface: surface, plane: 0) else {
            throw SwiftUIOverlayExportError.cannotCreatePixelBuffer
        }
        self.texture = texture
    }

    @discardableResult
    func exportFramePNG(sourceTime: PluginMediaTime, mapping: PluginTimeMapping, to url: URL) throws -> TimeInterval? {
        let elapsed = try session.render(into: texture, mediaSourceTime: sourceTime, mapping: mapping)
        var image: CGImage?
        guard VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &image) == noErr,
              let image else { throw OverlayRendererBackendError.cannotCreateImage }
        try SwiftUIOverlayVideoExporter.writeFramePNG(image, to: url)
        return elapsed
    }
}
#endif
