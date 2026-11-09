#if canImport(CSkiaBridge)
import CSkiaBridge
import CoreGraphics
import Foundation
import Metal
import Testing
@testable import RunningOverlay

@Suite(.serialized, .skiaSerialized)
struct SkiaBackendSelectionTests {
    @Test func productDefaultsUseSkiaAndPreferGraphiteWhenCompiled() {
        #expect(OverlayRendererBackendKind.defaultBackend == .skia)
        #expect(SkiaGPUBackendKind.defaultBackend == (skb_graphite_available() != 0 ? .graphite : .ganesh))
    }

    @Test func graphiteIsExplicitlyUnavailableInGaneshOnlyBuilds() throws {
        guard skb_graphite_available() == 0 else { return }
        let device = try #require(MTLCreateSystemDefaultDevice())
        let queue = try #require(device.makeCommandQueue())
        #expect(SkiaEasyRunRenderer(
            size: CGSize(width: 1280, height: 720), device: device,
            commandQueue: queue, gpuBackend: .graphite
        ) == nil)
        #expect(SkiaEasyRunRenderer(
            size: CGSize(width: 1280, height: 720), device: device,
            commandQueue: queue, gpuBackend: .ganesh
        ) != nil)
    }

    @Test(.enabled(if: skb_graphite_available() != 0))
    func graphiteAndGaneshRenderSuccessiveFramesWithMatchingAlpha() throws {
        let size = CGSize(width: 1280, height: 720)
        let device = try #require(MTLCreateSystemDefaultDevice())
        let ganeshQueue = try #require(device.makeCommandQueue())
        let graphiteQueue = try #require(device.makeCommandQueue())
        let ganesh = try #require(SkiaEasyRunRenderer(
            size: size, device: device, commandQueue: ganeshQueue,
            gpuBackend: .ganesh
        ))
        let graphite = try #require(SkiaEasyRunRenderer(
            size: size, device: device, commandQueue: graphiteQueue,
            gpuBackend: .graphite
        ))
        let activityURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Activities/synthetic-run.fit")
        let activity = try FitFileParser.parse(url: activityURL)
        var layout = try SkiaGPUSpikeTests.easyRunLayout()
        let shape = try #require(OverlayComponentLibraryItem.decor.first)
        let icon = try #require(
            OverlayComponentLibraryItem.decor.first { $0.id == "studio.decor-icon" }
        )
        layout.elements += [
            OverlayElement(
                type: .component,
                position: CGPoint(x: 0.2, y: 0.2),
                scale: 1,
                style: .default,
                component: OverlayComponentInstance(
                    reference: try OverlayComponentLibrary.reference(for: shape)
                )
            ),
            OverlayElement(
                type: .component,
                position: CGPoint(x: 0.5, y: 0.2),
                scale: 1,
                style: .default,
                component: OverlayComponentInstance(
                    reference: try OverlayComponentLibrary.reference(for: icon)
                )
            )
        ]
        ganesh.preloadAssets(layout: layout, activity: activity)
        graphite.preloadAssets(layout: layout, activity: activity)
        for time: TimeInterval in [0, 3, 7] {
            let (reference, rowBytes) = try #require(ganesh.render(layout: layout, activity: activity, elapsedTime: time))
            let bytes = Array(UnsafeBufferPointer(start: reference, count: rowBytes * Int(size.height)))
            let (candidate, candidateStride) = try #require(graphite.render(layout: layout, activity: activity, elapsedTime: time))
            #expect(candidateStride == rowBytes)
            var alphaDelta = 0.0
            var visiblePixels = 0
            for index in stride(from: 3, to: bytes.count, by: 4) {
                if bytes[index] != 0 || candidate[index] != 0 {
                    visiblePixels += 1
                    alphaDelta += Double(abs(Int(bytes[index]) - Int(candidate[index])))
                }
            }
            #expect(visiblePixels > 1_000)
            #expect(alphaDelta / Double(max(visiblePixels, 1)) < 4)
            #expect(graphite.flush(sync: true))
            #expect(ganesh.flush(sync: true))
        }
    }
}
#endif
