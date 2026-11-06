#if canImport(CSkiaBridge)
import AppKit
import Foundation
import Metal

enum SkiaMetalSessionError: LocalizedError, Equatable {
    case invalidConfiguration
    case incompatibleTexture
    case invalidSampleTime
    case cannotWrapTexture
    case submissionFailed

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration: "Cannot create a Skia Metal session for this canvas, layout, or command queue."
        case .incompatibleTexture: "The render target must be a full-canvas BGRA8 2D texture on the session's Metal device, with render-target usage."
        case .invalidSampleTime: "The activity sample time must be finite."
        case .cannotWrapTexture: "Skia could not wrap the external render target."
        case .submissionFailed: "Skia GPU submission failed."
        }
    }
}

/// A persistent serial renderer shared by MOV export and the plugin frame
/// adapter. Setup/preloading occurs on MainActor; frame calls need no actor
/// hop. Each instance owns its context/queue/assets and protects them with one
/// lock. The input texture is borrowed through GPU completion, then detached.
///
/// This renders an overlay plane. Host input compositing, tile coordinates,
/// HDR/color conversion, and FxPlug timing conversion belong to host adapters.
final class SkiaMetalRenderSession: @unchecked Sendable {
    private let lock = NSLock()
    private let renderer: SkiaEasyRunRenderer
    private let layout: OverlayLayout
    private let activity: ActivityTimeline
    let device: any MTLDevice
    let size: CGSize

    @MainActor
    init(
        size: CGSize,
        layout: OverlayLayout,
        activity: ActivityTimeline,
        device: any MTLDevice,
        commandQueue: any MTLCommandQueue,
        mapSnapshots: [MapSnapshotRequest: NSImage] = [:],
        gpuBackend: SkiaGPUBackendKind = .selected
    ) throws {
        guard size.width.isFinite, size.height.isFinite,
              size.width.rounded() == size.width, size.height.rounded() == size.height,
              size.width > 0, size.height > 0,
              size.width <= CGFloat(Int32.max), size.height <= CGFloat(Int32.max),
              commandQueue.device.registryID == device.registryID,
              layout.elements.filter(\.isVisible).allSatisfy(SkiaEasyRunRenderer.supports),
              let renderer = SkiaEasyRunRenderer(
                size: size, device: device, commandQueue: commandQueue,
                offscreen: false, gpuBackend: gpuBackend
              ) else { throw SkiaMetalSessionError.invalidConfiguration }
        self.size = size
        self.device = device
        self.renderer = renderer
        self.layout = layout
        self.activity = activity
        renderer.preloadAssets(layout: layout, activity: activity, mapSnapshots: mapSnapshots)
    }

    /// `nil` clears the entire target to transparent (outside activity).
    /// Callers provide explicit activity elapsed seconds, never host time.
    func render(into texture: any MTLTexture, activityElapsedTime: TimeInterval?) throws {
        guard texture.device.registryID == device.registryID,
              texture.textureType == .type2D, texture.sampleCount == 1,
              texture.width == Int(size.width), texture.height == Int(size.height),
              texture.pixelFormat == .bgra8Unorm,
              texture.usage.contains(.renderTarget) else {
            throw SkiaMetalSessionError.incompatibleTexture
        }
        if let time = activityElapsedTime, !time.isFinite { throw SkiaMetalSessionError.invalidSampleTime }
        try lock.withLock {
            try autoreleasepool {
                guard renderer.wrap(texture: texture) else { throw SkiaMetalSessionError.cannotWrapTexture }
                defer { renderer.releaseExternalSurface() }
                renderer.draw(
                    layout: activityElapsedTime == nil ? .empty : layout,
                    activity: activity, elapsedTime: activityElapsedTime ?? 0
                )
                guard renderer.flush(sync: true) else { throw SkiaMetalSessionError.submissionFailed }
                withExtendedLifetime(texture) {}
            }
        }
    }
}
#endif
