import AppKit
import Foundation
import Metal

if CommandLine.arguments.contains("--self-test") {
    do {
        _ = NSApplication.shared
        try MainActor.assumeIsolated {
            let package = try FxPlugRuntime.shared.package()
            guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { throw PluginCoreError.invalidPackage("Metal is unavailable") }
            let session = try PluginMetalRenderSession(package: package, device: device, commandQueue: queue)
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(session.size.width), height: Int(session.size.height), mipmapped: false)
            descriptor.storageMode = .shared
            descriptor.usage = [.renderTarget, .shaderRead]
            guard let target = device.makeTexture(descriptor: descriptor) else { throw PluginCoreError.invalidPackage("Metal target is unavailable") }
            let mapping = try PluginTimeMapping(mediaSourceAnchor: PluginMediaTime(value: 0, timescale: 1), activityElapsedAnchor: 0)
            try session.render(into: target, mediaSourceTime: PluginMediaTime(value: 1, timescale: 1), mapping: mapping)
            var pixels = [UInt8](repeating: 0, count: target.width * target.height * 4)
            target.getBytes(&pixels, bytesPerRow: target.width * 4, from: MTLRegionMake2D(0, 0, target.width, target.height), mipmapLevel: 0)
            guard pixels.contains(where: { $0 != 0 }) else { throw PluginCoreError.invalidPackage("native shared renderer produced no pixels") }
            // Exercise the actual host compositor and all accepted output
            // formats without fabricating FxImageTile instances. The input is
            // transparent, so an outside-activity render must remain zero.
            var clear = [UInt8](repeating: 0, count: target.width * target.height * 4)
            target.replace(region: MTLRegionMake2D(0, 0, target.width, target.height), mipmapLevel: 0, withBytes: &clear, bytesPerRow: target.width * 4)
            for (format, bytesPerPixel) in [(MTLPixelFormat.bgra8Unorm, 4), (.rgba16Float, 8), (.rgba32Float, 16)] {
                descriptor.pixelFormat = format
                guard let output = device.makeTexture(descriptor: descriptor) else { throw PluginCoreError.invalidPackage("native composite target is unavailable") }
                let kernel = try FxPlugRuntime.shared.kernel(device: device, width: target.width, height: target.height, format: format, templateIndex: 0)
                try kernel.render(input: target, output: output, sourceTime: PluginMediaTime(value: 1, timescale: 1), mapping: mapping, flipOverlay: false)
                var image = [UInt8](repeating: 0, count: output.width * output.height * bytesPerPixel)
                output.getBytes(&image, bytesPerRow: output.width * bytesPerPixel, from: MTLRegionMake2D(0, 0, output.width, output.height), mipmapLevel: 0)
                guard image.contains(where: { $0 != 0 }) else { throw PluginCoreError.invalidPackage("native compositor produced no pixels") }
                try kernel.render(input: target, output: output, sourceTime: PluginMediaTime(value: -1, timescale: 1), mapping: mapping, flipOverlay: false)
                output.getBytes(&image, bytesPerRow: output.width * bytesPerPixel, from: MTLRegionMake2D(0, 0, output.width, output.height), mipmapLevel: 0)
                guard image.allSatisfy({ $0 == 0 }) else { throw PluginCoreError.invalidPackage("native compositor retained pixels outside the activity") }
            }
            print("FxPlug native self-test passed: shared Skia, bundled package, \(target.width)x\(target.height)")
        }
        exit(0)
    } catch {
        fputs("FxPlug self-test failed: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}
FxPrincipal.startServicePrincipal()
