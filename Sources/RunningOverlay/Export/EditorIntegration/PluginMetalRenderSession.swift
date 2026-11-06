#if canImport(CSkiaBridge)
import Foundation
import Metal
#if SWIFT_PACKAGE
import OverlayPluginCore
#endif

/// Resolved immutable package/template selection plus one persistent Metal
/// renderer. The host owns package access and converts input time to source
/// time; this adapter owns only explicit source-to-activity sampling.
final class PluginMetalRenderSession: @unchecked Sendable {
    private let session: SkiaMetalRenderSession
    private let activityDuration: TimeInterval
    let templateID: UUID
    var size: CGSize { session.size }

    @MainActor
    init(
        package: PluginDataPackage,
        templateID: UUID? = nil,
        device: any MTLDevice,
        commandQueue: any MTLCommandQueue,
        gpuBackend: SkiaGPUBackendKind = .selected
    ) throws {
        let input = try PluginDataPackageService.resolve(package, templateID: templateID)
        try PluginDataPackageService.validateFrameCapabilities(input.template)
        self.templateID = input.template.id
        activityDuration = input.activity.duration
        session = try SkiaMetalRenderSession(
            size: CGSize(width: package.canvasWidth, height: package.canvasHeight),
            layout: input.template.layout, activity: input.activity,
            device: device, commandQueue: commandQueue, gpuBackend: gpuBackend
        )
    }

    /// Rendering and GPU completion are serialized by the shared session.
    /// No package IO, decode, activity parse, PNG encoding, or actor hop occurs
    /// here. Nil sampling actively clears the target to transparent.
    @discardableResult
    func render(
        into texture: any MTLTexture,
        mediaSourceTime: PluginMediaTime,
        mapping: PluginTimeMapping
    ) throws -> TimeInterval? {
        let elapsed = try mapping.activityElapsedTime(
            forMediaSourceTime: mediaSourceTime, activityDuration: activityDuration
        )
        try session.render(into: texture, activityElapsedTime: elapsed)
        return elapsed
    }
}

#endif
