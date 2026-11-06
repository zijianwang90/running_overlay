#if canImport(CSkiaBridge)
import CoreGraphics
import Foundation
import Testing
@testable import RunningOverlay

/// Compares the imperative native overlay modules with the declarative
/// component path on the same Skia raster surface.
///
/// Both sides share the bridge and the text composer, so differences are
/// attributable to draw-tree construction: geometry, color resolution, layer
/// ordering and clipping. Text rasterized differently (for example the AppKit
/// decor-text cache versus Skia glyph shaping) needs a looser threshold or a
/// structural comparison instead.
enum NativeComponentParityHarness {
    struct Thresholds {
        /// Maximum per-channel difference allowed before a pixel counts as
        /// changed (0 = exact).
        var channelTolerance = 0
        /// Share of pixels allowed to exceed `channelTolerance`.
        var maximumChangedPixelRatio = 0.0
        /// Maximum difference seen on any channel, changed or not.
        var maximumChannelDelta = 0
        var maximumMeanChannelDelta = 0.0
    }

    struct Result {
        var label: String
        var width: Int
        var height: Int
        var changedPixels: Int
        var maximumChannelDelta: Int
        var meanChannelDelta: Double

        var changedPixelRatio: Double {
            guard width * height > 0 else { return 0 }
            return Double(changedPixels) / Double(width * height)
        }

        var summary: String {
            "\(label): \(changedPixels) changed pixels "
                + "(\(String(format: "%.4f", changedPixelRatio))), "
                + "max channel Δ \(maximumChannelDelta), "
                + "mean Δ \(String(format: "%.3f", meanChannelDelta))"
        }
    }

    enum ParityError: Error, CustomStringConvertible {
        case rendererUnavailable
        case invalidLayout(String)

        var description: String {
            switch self {
            case .rendererUnavailable:
                "Skia raster renderer is unavailable."
            case .invalidLayout(let message):
                "Invalid parity layout: \(message)"
            }
        }
    }

    /// Renders both layouts and compares their BGRA pixels.
    static func compare(
        label: String,
        native: OverlayLayout,
        component: OverlayLayout,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        size: CGSize,
        channelTolerance: Int = 0
    ) throws -> Result {
        guard let renderer = SkiaEasyRunRenderer(size: size) else {
            throw ParityError.rendererUnavailable
        }
        let nativePixels = try render(
            renderer: renderer,
            layout: native,
            activity: activity,
            elapsedTime: elapsedTime,
            size: size
        )
        let componentPixels = try render(
            renderer: renderer,
            layout: component,
            activity: activity,
            elapsedTime: elapsedTime,
            size: size
        )

        let width = Int(size.width)
        let height = Int(size.height)
        guard nativePixels.count == componentPixels.count,
              nativePixels.count >= width * height * 4 else {
            throw ParityError.invalidLayout("rendered buffers differ in size")
        }

        var changedPixels = 0
        var maximumChannelDelta = 0
        var totalChannelDelta = 0
        for pixelOffset in stride(from: 0, to: width * height * 4, by: 4) {
            var pixelChanged = false
            for channel in 0..<4 {
                let delta = abs(
                    Int(nativePixels[pixelOffset + channel])
                        - Int(componentPixels[pixelOffset + channel])
                )
                maximumChannelDelta = max(maximumChannelDelta, delta)
                totalChannelDelta += delta
                if delta > channelTolerance {
                    pixelChanged = true
                }
            }
            if pixelChanged {
                changedPixels += 1
            }
        }

        return Result(
            label: label,
            width: width,
            height: height,
            changedPixels: changedPixels,
            maximumChannelDelta: maximumChannelDelta,
            meanChannelDelta: Double(totalChannelDelta)
                / Double(width * height * 4)
        )
    }

    static func assertParity(
        label: String,
        native: OverlayLayout,
        component: OverlayLayout,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        size: CGSize,
        thresholds: Thresholds,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let result = try compare(
            label: label,
            native: native,
            component: component,
            activity: activity,
            elapsedTime: elapsedTime,
            size: size,
            channelTolerance: thresholds.channelTolerance
        )
        #expect(
            result.maximumChannelDelta <= thresholds.maximumChannelDelta,
            "\(result.summary) exceeds max channel Δ \(thresholds.maximumChannelDelta)",
            sourceLocation: sourceLocation
        )
        #expect(
            result.changedPixelRatio <= thresholds.maximumChangedPixelRatio,
            "\(result.summary) exceeds changed ratio \(thresholds.maximumChangedPixelRatio)",
            sourceLocation: sourceLocation
        )
        #expect(
            result.meanChannelDelta <= thresholds.maximumMeanChannelDelta,
            "\(result.summary) exceeds mean Δ \(thresholds.maximumMeanChannelDelta)",
            sourceLocation: sourceLocation
        )
    }

    private static func render(
        renderer: SkiaEasyRunRenderer,
        layout: OverlayLayout,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        size: CGSize
    ) throws -> [UInt8] {
        guard let (pixels, rowBytes) = renderer.render(
            layout: layout,
            activity: activity,
            elapsedTime: elapsedTime
        ) else {
            throw ParityError.invalidLayout("renderer returned no pixels")
        }
        let count = rowBytes * Int(size.height)
        return Array(UnsafeBufferPointer(start: pixels, count: count))
    }
}
#endif
