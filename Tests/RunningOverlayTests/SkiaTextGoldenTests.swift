#if canImport(CSkiaBridge)
import AppKit
import CoreGraphics
import CSkiaBridge
import Foundation
import SwiftUI
import Testing
@testable import RunningOverlay

struct SkiaTextGoldenMetrics: CustomStringConvertible {
    var label: String
    var changedPixels: Int
    var totalPixels: Int
    var meanDelta: Double
    var maxDelta: Int
    var diffBox: CGRect
    var referenceURL: URL
    var candidateURL: URL

    var changedRatio: Double {
        totalPixels > 0 ? Double(changedPixels) / Double(totalPixels) : 0
    }

    var description: String {
        "SKIA-TEXT-GOLDEN \(label) changed=\(changedPixels)/\(totalPixels) "
            + "(\(String(format: "%.3f", changedRatio * 100))%) "
            + "meanDelta=\(String(format: "%.4f", meanDelta)) "
            + "maxDelta=\(maxDelta) diffBox=\(diffBox) "
            + "reference=\(referenceURL.path) candidate=\(candidateURL.path)"
    }
}

enum SkiaTextGoldenError: LocalizedError {
    case cannotCreateContext
    case cannotRenderCandidate
    case cannotRenderOracle
    case cannotRasterize
    case cannotEncodePNG

    var errorDescription: String? {
        switch self {
        case .cannotCreateContext: "Could not create a Skia comparison context."
        case .cannotRenderCandidate: "SkiaTextModule declined the element."
        case .cannotRenderOracle: "ImageRenderer did not produce a text oracle image."
        case .cannotRasterize: "Could not rasterize the oracle image."
        case .cannotEncodePNG: "Could not encode a golden PNG."
        }
    }
}

/// Render and comparison seams for text goldens. Production code calls
/// `SkiaTextModule.draw`; tests use the same entry points with deterministic
/// fixtures.
enum SkiaTextRenderSupport {
    static func candidatePixels(
        element: OverlayElement,
        size: CGSize,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        layout: OverlayTextRenderLayout? = nil
    ) throws -> (pixels: [UInt8], rowBytes: Int) {
        guard let context = skb_create(Int32(size.width), Int32(size.height)) else {
            throw SkiaTextGoldenError.cannotCreateContext
        }
        defer { skb_destroy(context) }
        skb_clear(context)
        let renderContext = OverlayRenderContext(
            canvasSize: size,
            activity: activity,
            elapsedTime: elapsedTime
        )
        if let layout {
            SkiaTextModule.draw(
                element: element,
                layout: layout,
                context: context,
                renderContext: renderContext
            )
        } else {
            let handled = SkiaTextModule.draw(
                element: element,
                context: context,
                canvasSize: size,
                activity: activity,
                elapsedTime: elapsedTime
            )
            guard handled else { throw SkiaTextGoldenError.cannotRenderCandidate }
        }
        var rowBytes = 0
        guard let base = skb_pixels(context, &rowBytes) else {
            throw SkiaTextGoldenError.cannotRenderCandidate
        }
        let count = rowBytes * Int(size.height)
        return (Array(UnsafeBufferPointer(start: base, count: count)), rowBytes)
    }

    static func candidateImage(
        element: OverlayElement,
        size: CGSize,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        layout: OverlayTextRenderLayout? = nil
    ) throws -> CGImage {
        let result = try candidatePixels(
            element: element,
            size: size,
            activity: activity,
            elapsedTime: elapsedTime,
            layout: layout
        )
        let data = Data(result.pixels)
        guard let provider = CGDataProvider(data: data as CFData),
              let image = CGImage(
                  width: Int(size.width),
                  height: Int(size.height),
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: result.rowBytes,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(
                      rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue
                          | CGBitmapInfo.byteOrder32Little.rawValue
                  ),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent
              )
        else {
            throw SkiaTextGoldenError.cannotRenderCandidate
        }
        return image
    }

    /// Direct-layout oracle: the SwiftUI preset view at the element's
    /// top-leading anchor, matching `SkiaTextModule`'s origin.
    @MainActor
    static func oracleImage(
        element: OverlayElement,
        layout: OverlayTextRenderLayout,
        size: CGSize
    ) -> CGImage? {
        let content = ZStack(alignment: .topLeading) {
            Color.clear
            TextPresetOverlayView(element: element, layout: layout, isSelected: false)
                .opacity(element.opacity)
                .offset(
                    x: size.width * element.position.x,
                    y: size.height * element.position.y
                )
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        let renderer = ImageRenderer(content: content)
        renderer.isOpaque = false
        renderer.proposedSize = ProposedViewSize(
            width: size.width,
            height: size.height
        )
        renderer.scale = 1
        return renderer.cgImage
    }

    static func compare(
        reference: CGImage,
        candidate: CGImage,
        size: CGSize,
        label: String,
        threshold: Int = 8
    ) throws -> SkiaTextGoldenMetrics {
        guard let referencePixels = SwiftUIOverlayVideoExporter.rasterizeCanvas(
            draws: [(reference, CGRect(origin: .zero, size: size))],
            canvasSize: size
        ) else {
            throw SkiaTextGoldenError.cannotRasterize
        }
        guard let candidatePixels = SwiftUIOverlayVideoExporter.rasterizeCanvas(
            draws: [(candidate, CGRect(origin: .zero, size: size))],
            canvasSize: size
        ) else {
            throw SkiaTextGoldenError.cannotRasterize
        }

        let width = Int(size.width)
        let height = Int(size.height)
        let rowBytes = width * 4
        var changed = 0
        var maxDelta = 0
        var totalDelta = 0
        var diffBox = CGRect.null
        for y in 0..<height {
            for x in 0..<width {
                let index = y * rowBytes + x * 4
                var pixelDelta = 0
                for channel in 0..<4 {
                    pixelDelta += abs(
                        Int(referencePixels[index + channel])
                            - Int(candidatePixels[index + channel])
                    )
                }
                if pixelDelta > threshold {
                    changed += 1
                    diffBox = diffBox.union(
                        CGRect(x: x, y: y, width: 1, height: 1)
                    )
                }
                maxDelta = max(maxDelta, pixelDelta)
                totalDelta += pixelDelta
            }
        }

        let directory = try outputDirectory(label: label)
        let referenceURL = directory.appendingPathComponent("\(label)-swiftui.png")
        let candidateURL = directory.appendingPathComponent("\(label)-skia.png")
        try writePNG(reference, to: referenceURL)
        try writePNG(candidate, to: candidateURL)

        let totalPixels = width * height
        return SkiaTextGoldenMetrics(
            label: label,
            changedPixels: changed,
            totalPixels: totalPixels,
            meanDelta: totalPixels > 0
                ? Double(totalDelta) / Double(totalPixels * 4)
                : 0,
            maxDelta: maxDelta,
            diffBox: diffBox,
            referenceURL: referenceURL,
            candidateURL: candidateURL
        )
    }

    private static func outputDirectory(label: String) throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("skia-text-golden", isDirectory: true)
            .appendingPathComponent(label, isDirectory: true)
        try FileManager.default.createDirectory(
            at: base,
            withIntermediateDirectories: true
        )
        return base
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw SkiaTextGoldenError.cannotEncodePNG
        }
        try data.write(to: url)
    }
}

@Suite(.serialized) struct SkiaTextGoldenTests {
    /// D2: `.minimal` is the only runtime-reachable preset, so this fixture
    /// uses the unmodified production model path (element + `textLayout`) and
    /// the shipping SwiftUI frame renderer as the oracle.
    @Test func minimalProductionPathMatchesSwiftUI() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            let element = SkiaTextFixtureFactory.element()
            let activity = SkiaTextFixtureFactory.activity()
            let size = SkiaTextFixtureFactory.canvasSize
            let reference = try await SwiftUIOverlayVideoExporter.renderFrameCGImage(
                overlayLayout: OverlayLayout(elements: [element]),
                activity: activity,
                elapsedTime: SkiaTextFixtureFactory.elapsedTime,
                size: size
            )
            let candidate = try SkiaTextRenderSupport.candidateImage(
                element: element,
                size: size,
                activity: activity,
                elapsedTime: SkiaTextFixtureFactory.elapsedTime
            )
            let metrics = try SkiaTextRenderSupport.compare(
                reference: reference,
                candidate: candidate,
                size: size,
                label: "minimal-production"
            )
            print(metrics.description)
            #expect(metrics.changedRatio < 0.02)
            #expect(metrics.meanDelta < 4)
        }
    }


    /// D6: element opacity, generic border, glow, and layered shadow all run
    /// through `withElementLayers` on the production minimal layout.
    @Test func minimalEffectsMatchSwiftUI() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            let element = SkiaTextFixtureFactory.effectsElement()
            let activity = SkiaTextFixtureFactory.activity()
            let size = SkiaTextFixtureFactory.canvasSize
            let reference = try await SwiftUIOverlayVideoExporter.renderFrameCGImage(
                overlayLayout: OverlayLayout(elements: [element]),
                activity: activity,
                elapsedTime: SkiaTextFixtureFactory.elapsedTime,
                size: size
            )
            let candidate = try SkiaTextRenderSupport.candidateImage(
                element: element,
                size: size,
                activity: activity,
                elapsedTime: SkiaTextFixtureFactory.elapsedTime
            )
            let metrics = try SkiaTextRenderSupport.compare(
                reference: reference,
                candidate: candidate,
                size: size,
                label: "minimal-effects"
            )
            print(metrics.description)
            // Blur tails over a large glow/shadow region differ subtly even
            // when geometry, color, and opacity match; meanDelta stays low.
            #expect(metrics.changedRatio < 0.05)
            #expect(metrics.meanDelta < 2)
        }
    }

    @Test func decorEffectsMatchSwiftUI() async throws {
        try await decorGolden(
            element: SkiaTextFixtureFactory.effectsSolidColorElement(),
            label: "decor-effects",
            maxChangedRatio: 0.05,
            maxMeanDelta: 2
        )
    }

    /// Decor containers use the production frame renderer as the oracle.
    @Test func decorSolidColorMatchesSwiftUI() async throws {
        try await decorGolden(
            element: SkiaTextFixtureFactory.solidColorElement(),
            label: "decor-solid"
        )
    }

    @Test func decorIconMatchesSwiftUI() async throws {
        try await decorGolden(
            element: SkiaTextFixtureFactory.iconElement(),
            label: "decor-icon"
        )
    }

    /// D5: stroked decor text is rasterized through AppKit into a cached BGRA
    /// image because the bridge has no glyph-stroke primitive.
    @Test func decorStrokedTextMatchesSwiftUI() async throws {
        try await decorGolden(
            element: SkiaTextFixtureFactory.textElement(),
            label: "decor-text-stroke"
        )
    }

    private func decorGolden(
        element: OverlayElement,
        label: String,
        maxChangedRatio: Double = 0.02,
        maxMeanDelta: Double = 4
    ) async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            let activity = SkiaTextFixtureFactory.activity()
            let size = SkiaTextFixtureFactory.canvasSize
            let reference = try await SwiftUIOverlayVideoExporter.renderFrameCGImage(
                overlayLayout: OverlayLayout(elements: [element]),
                activity: activity,
                elapsedTime: SkiaTextFixtureFactory.elapsedTime,
                size: size
            )
            let candidate = try SkiaTextRenderSupport.candidateImage(
                element: element,
                size: size,
                activity: activity,
                elapsedTime: SkiaTextFixtureFactory.elapsedTime
            )
            let metrics = try SkiaTextRenderSupport.compare(
                reference: reference,
                candidate: candidate,
                size: size,
                label: label
            )
            print(metrics.description)
            #expect(metrics.changedRatio < maxChangedRatio)
            #expect(metrics.meanDelta < maxMeanDelta)
        }
    }

    /// D3: export has no backdrop to blur. `ImageRenderer` renders
    /// `.ultraThinMaterial` over a transparent canvas as a near-white
    /// translucent fill; the Skia module reproduces that measured fallback.
    @Test func materialBlurFallbackMatchesSwiftUI() async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            var style = SkiaTextFixtureFactory.style()
            style.backgroundBlurRadius = 12
            style.backgroundOpacity = 0.5
            let element = SkiaTextFixtureFactory.element(style: style)
            let activity = SkiaTextFixtureFactory.activity()
            let size = SkiaTextFixtureFactory.canvasSize
            let reference = try await SwiftUIOverlayVideoExporter.renderFrameCGImage(
                overlayLayout: OverlayLayout(elements: [element]),
                activity: activity,
                elapsedTime: SkiaTextFixtureFactory.elapsedTime,
                size: size
            )
            let candidate = try SkiaTextRenderSupport.candidateImage(
                element: element,
                size: size,
                activity: activity,
                elapsedTime: SkiaTextFixtureFactory.elapsedTime
            )
            let metrics = try SkiaTextRenderSupport.compare(
                reference: reference,
                candidate: candidate,
                size: size,
                label: "material-blur-fallback"
            )
            print(metrics.description)
            #expect(metrics.changedRatio < 0.02)
            #expect(metrics.meanDelta < 4)
        }
    }

    /// Canonical presets 1-9 (`.minimal` covered by the production fixture).
    /// Numeric elements force `.minimal` in the model, so each preset is
    /// compared through the direct-layout oracle.
    @Test(arguments: SkiaTextFixtureFactory.canonicalPresets.filter { $0 != .minimal })
    func canonicalPresetMatchesDirectLayoutOracle(
        _ preset: OverlayTextPreset
    ) async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            var style = SkiaTextFixtureFactory.style()
            style.iconEnabled = false
            let element = SkiaTextFixtureFactory.element(style: style)
            let activity = SkiaTextFixtureFactory.activity()
            let layout = SkiaTextFixtureFactory.directLayout(
                for: element,
                preset: preset,
                activity: activity
            )
            let size = SkiaTextFixtureFactory.canvasSize
            let reference = await MainActor.run {
                SkiaTextRenderSupport.oracleImage(
                    element: element,
                    layout: layout,
                    size: size
                )
            }
            let oracle = try #require(
                reference,
                "ImageRenderer returned no image for \(preset.rawValue)"
            )
            let candidate = try SkiaTextRenderSupport.candidateImage(
                element: element,
                size: size,
                activity: activity,
                elapsedTime: SkiaTextFixtureFactory.elapsedTime,
                layout: layout
            )
            let metrics = try SkiaTextRenderSupport.compare(
                reference: oracle,
                candidate: candidate,
                size: size,
                label: "canonical-\(preset.rawValue)"
            )
            print(metrics.description)
            #expect(metrics.changedRatio < 0.02)
            #expect(metrics.meanDelta < 4)
        }
    }

    /// Deprecated presets are drawn but not re-enabled. Thresholds are the
    /// same; failures here do not block runtime exposure.
    @Test(arguments: SkiaTextFixtureFactory.deprecatedPresets)
    func deprecatedPresetMatchesDirectLayoutOracle(
        _ preset: OverlayTextPreset
    ) async throws {
        try await OverlayPreferenceFixtures.withDefaults {
            var style = SkiaTextFixtureFactory.style()
            style.iconEnabled = false
            let element = SkiaTextFixtureFactory.element(style: style)
            let activity = SkiaTextFixtureFactory.activity()
            let layout = SkiaTextFixtureFactory.directLayout(
                for: element,
                preset: preset,
                activity: activity
            )
            let size = SkiaTextFixtureFactory.canvasSize
            let reference = await MainActor.run {
                SkiaTextRenderSupport.oracleImage(
                    element: element,
                    layout: layout,
                    size: size
                )
            }
            let oracle = try #require(
                reference,
                "ImageRenderer returned no image for \(preset.rawValue)"
            )
            let candidate = try SkiaTextRenderSupport.candidateImage(
                element: element,
                size: size,
                activity: activity,
                elapsedTime: SkiaTextFixtureFactory.elapsedTime,
                layout: layout
            )
            let metrics = try SkiaTextRenderSupport.compare(
                reference: oracle,
                candidate: candidate,
                size: size,
                label: "deprecated-\(preset.rawValue)"
            )
            print(metrics.description)
            #expect(metrics.changedRatio < 0.03)
            #expect(metrics.meanDelta < 6)
        }
    }
}
#endif
