import AppKit
import CoreMedia
import Foundation
import Metal

private func failure(_ reason: String) -> NSError {
    NSError(domain: FxPlugErrorDomain, code: 1, userInfo: [NSLocalizedDescriptionKey: reason])
}

private struct FrameState: Codable {
    let schemaVersion: Int
    let templateIndex: Int
    let correction: Double
}

/// Authored diagnostic carrier, using the SDK's FxTileableEffect protocol.
/// The demo package is bundled by the local build command, never fetched.
@objc(RunningOverlayFxPlug)
final class RunningOverlayFxPlug: NSObject, FxTileableEffect {
    private let apiManager: any PROAPIAccessing

    required init?(apiManager: any PROAPIAccessing) {
        self.apiManager = apiManager
        super.init()
    }

    func addParameters() throws {
        guard let api = apiManager.api(for: FxParameterCreationAPI_v5.self) as? any FxParameterCreationAPI_v5 else {
            throw failure("FxPlug parameter creation API is unavailable.")
        }
        let package = try FxPlugRuntime.shared.package()
        let fixed = FxParameterFlags(kFxParameterFlag_NOT_ANIMATABLE)
        guard api.addStringParameter(withName: "Activity (diagnostic)", parameterID: 1,
                                    defaultValue: "Bundled synthetic activity", parameterFlags: FxParameterFlags(kFxParameterFlag_DISABLED)),
              api.addPopupMenu(withName: "Template", parameterID: 2, defaultValue: 0,
                               menuEntries: package.templates.map(\.name), parameterFlags: fixed),
              api.addFloatSlider(withName: "Activity Offset (seconds)", parameterID: 3,
                                 defaultValue: 0, parameterMin: -86400, parameterMax: 86400,
                                 sliderMin: -60, sliderMax: 60, delta: 0.01, parameterFlags: fixed) else {
            throw failure("FxPlug could not create the diagnostic parameters.")
        }
    }

    func properties(_ properties: AutoreleasingUnsafeMutablePointer<NSDictionary>?) throws {
        properties?.pointee = [
            kFxPropertyKey_MayRemapTime: false,
            kFxPropertyKey_NeedsFullBuffer: true,
            kFxPropertyKey_PixelTransformSupport: kFxPixelTransform_ScaleTranslate,
            kFxPropertyKey_VariesWhenParamsAreStatic: true
        ] as NSDictionary
    }

    func pluginState(_ pluginState: AutoreleasingUnsafeMutablePointer<NSData>?, at renderTime: CMTime, quality qualityLevel: UInt) throws {
        guard let api = apiManager.api(for: FxParameterRetrievalAPI_v6.self) as? any FxParameterRetrievalAPI_v6 else {
            throw failure("FxPlug parameter retrieval API is unavailable.")
        }
        var template: Int32 = 0
        var offset = 0.0
        guard api.getIntValue(&template, fromParameter: 2, at: renderTime),
              api.getFloatValue(&offset, fromParameter: 3, at: renderTime), offset.isFinite else {
            throw failure("FxPlug could not retrieve the frame parameters.")
        }
        pluginState?.pointee = try JSONEncoder().encode(FrameState(schemaVersion: 1, templateIndex: Int(template), correction: offset)) as NSData
    }

    func destinationImageRect(_ destinationImageRect: UnsafeMutablePointer<FxRect>, sourceImages: [FxImageTile], destinationImage: FxImageTile, pluginState: Data?, at renderTime: CMTime) throws {
        guard let source = sourceImages.first else { throw failure("The diagnostic effect requires an input image.") }
        destinationImageRect.pointee = source.imagePixelBounds
    }

    func sourceTileRect(_ sourceTileRect: UnsafeMutablePointer<FxRect>, sourceImageIndex: UInt, sourceImages: [FxImageTile], destinationTileRect: FxRect, destinationImage: FxImageTile, pluginState: Data?, at renderTime: CMTime) throws {
        guard sourceImageIndex < sourceImages.count else { throw failure("Missing input image.") }
        sourceTileRect.pointee = sourceImages[Int(sourceImageIndex)].imagePixelBounds
    }

    func renderDestinationImage(_ destinationImage: FxImageTile, sourceImages: [FxImageTile], pluginState: Data?, at renderTime: CMTime) throws {
        guard let source = sourceImages.first, let pluginState else { throw failure("Missing input or frame state.") }
        let state = try JSONDecoder().decode(FrameState.self, from: pluginState)
        guard state.schemaVersion == 1, state.correction.isFinite else { throw failure("Unsupported frame state.") }
        guard source.mediaTime.isNumeric, source.mediaTime.epoch == 0 else { throw failure("The input media time is not a finite source timestamp.") }
        let runtime = FxPlugRuntime.shared
        let device = try runtime.device(registryID: destinationImage.deviceRegistryID)
        guard source.deviceRegistryID == destinationImage.deviceRegistryID,
              let input = source.metalTexture(for: device),
              let output = destinationImage.metalTexture(for: device),
              input.width == output.width, input.height == output.height,
              output.width == Int(destinationImage.imagePixelBounds.right - destinationImage.imagePixelBounds.left),
              output.height == Int(destinationImage.imagePixelBounds.top - destinationImage.imagePixelBounds.bottom) else {
            throw failure("The diagnostic requires matching full-frame input and output textures.")
        }
        let kernel = try runtime.kernel(device: device, width: output.width, height: output.height, format: output.pixelFormat, templateIndex: state.templateIndex)
        let sourceTime = try PluginMediaTime(value: source.mediaTime.value, timescale: source.mediaTime.timescale)
        // Local normal-speed checks followed original media after a split and
        // timeline gap. Retiming/reverse/freeze and mixed-rate cases remain
        // unverified and must not assume this diagnostic conversion.
        let mapping = try PluginTimeMapping(mediaSourceAnchor: PluginMediaTime(value: 0, timescale: 1), activityElapsedAnchor: 0, correctionSeconds: state.correction)
        try kernel.render(input: input, output: output, sourceTime: sourceTime, mapping: mapping, flipOverlay: destinationImage.imageOrigin == kFxImageOrigin_BOTTOM_LEFT)
    }
}

final class FxPlugRuntime: @unchecked Sendable {
    static let shared = FxPlugRuntime()
    private let lock = NSLock()
    private var loadedPackage: PluginDataPackage?
    private var kernels: [String: FxPlugKernel] = [:]

    func package() throws -> PluginDataPackage {
        if let existing = lock.withLock({ loadedPackage }) { return existing }
        guard let url = Bundle.main.url(forResource: "PluginDemo", withExtension: "roplugin") else {
            throw failure("The local diagnostic bundle has no prepared activity package.")
        }
        let loaded = try PluginDataPackageService.load(from: url)
        return lock.withLock { loadedPackage = loadedPackage ?? loaded; return loadedPackage! }
    }

    func device(registryID: UInt64) throws -> any MTLDevice {
        guard let device = MTLCopyAllDevices().first(where: { $0.registryID == registryID }) else { throw failure("The host Metal device is unavailable.") }
        return device
    }

    func kernel(device: any MTLDevice, width: Int, height: Int, format: MTLPixelFormat, templateIndex: Int) throws -> FxPlugKernel {
        let key = "\(device.registryID):\(width):\(height):\(format.rawValue):\(templateIndex)"
        if let existing = lock.withLock({ kernels[key] }) { return existing }
        let package = try package()
        // Cold asset setup only. Never hold the cache lock while entering
        // MainActor; a concurrent callback may already be on the main thread.
        let make = { @MainActor in try FxPlugKernel(package: package, templateIndex: templateIndex, device: device, width: width, height: height, format: format) }
        let created: FxPlugKernel
        if Thread.isMainThread { created = try MainActor.assumeIsolated { try make() } }
        else { created = try DispatchQueue.main.sync { try MainActor.assumeIsolated { try make() } } }
        return lock.withLock {
            if let existing = kernels[key] { return existing }
            if kernels.count >= 8, let oldest = kernels.keys.sorted().first { kernels.removeValue(forKey: oldest) }
            kernels[key] = created
            return created
        }
    }
}

final class FxPlugKernel: @unchecked Sendable {
    private let lock = NSLock()
    private let queue: any MTLCommandQueue
    private let session: PluginMetalRenderSession
    private let overlay: any MTLTexture
    private let pipeline: any MTLRenderPipelineState

    @MainActor
    init(package: PluginDataPackage, templateIndex: Int, device: any MTLDevice, width: Int, height: Int, format: MTLPixelFormat) throws {
        guard package.templates.indices.contains(templateIndex), [.bgra8Unorm, .rgba16Float, .rgba32Float].contains(format),
              let queue = device.makeCommandQueue() else { throw failure("Unsupported template, output format or command queue.") }
        self.queue = queue
        let resized = PluginDataPackage(rendererVersion: package.rendererVersion, canvasWidth: width, canvasHeight: height, activity: package.activity, templates: package.templates)
        session = try PluginMetalRenderSession(package: resized, templateID: package.templates[templateIndex].id, device: device, commandQueue: queue)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .private
        descriptor.usage = [.renderTarget, .shaderRead]
        guard let overlay = device.makeTexture(descriptor: descriptor) else { throw failure("Cannot allocate the diagnostic overlay target.") }
        self.overlay = overlay
        let library = try device.makeDefaultLibrary(bundle: .main)
        let pipeline = MTLRenderPipelineDescriptor()
        pipeline.vertexFunction = library.makeFunction(name: "overlayVertex")
        pipeline.fragmentFunction = library.makeFunction(name: "overlayComposite")
        pipeline.colorAttachments[0].pixelFormat = format
        self.pipeline = try device.makeRenderPipelineState(descriptor: pipeline)
    }

    func render(input: any MTLTexture, output: any MTLTexture, sourceTime: PluginMediaTime, mapping: PluginTimeMapping, flipOverlay: Bool) throws {
        try lock.withLock {
            try session.render(into: overlay, mediaSourceTime: sourceTime, mapping: mapping)
            guard let command = queue.makeCommandBuffer() else { throw failure("Cannot create the composite command buffer.") }
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = output
            pass.colorAttachments[0].loadAction = .dontCare
            pass.colorAttachments[0].storeAction = .store
            guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { throw failure("Cannot create the composite encoder.") }
            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentTexture(input, index: 0)
            encoder.setFragmentTexture(overlay, index: 1)
            var flip = flipOverlay
            encoder.setFragmentBytes(&flip, length: MemoryLayout<Bool>.size, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
            command.commit()
            command.waitUntilCompleted()
            guard command.status == .completed else { throw failure(command.error?.localizedDescription ?? "Composite GPU submission failed.") }
        }
    }
}
