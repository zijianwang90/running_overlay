#if canImport(CSkiaBridge)
import CoreGraphics
import Foundation
import Testing
@testable import RunningOverlay

/// Establishes the native-module ↔ declarative-component parity harness and
/// proves it on the simplest fully expressible overlay: Decor Solid Color.
///
/// The pilot is intentionally small. It validates that both draw-tree builders
/// produce the same pixels on the same Skia surface before the harness is used
/// for larger built-ins, and it gives later ports a threshold precedent.
@Suite(.serialized, .skiaSerialized)
struct OverlayComponentParityTests {
    private static let canvas = CGSize(width: 1280, height: 720)
    private static let activity = SkiaChartsGoldenTests.activity(duration: 600)

    private struct Pair {
        var native: OverlayLayout
        var component: OverlayLayout
    }

    private func makeDecorPair(
        opacity: Double = 1,
        shape: DecorShape = .roundedRectangle,
        cornerRadius: Double = 24,
        componentFill: String = "#3399E5D9"
    ) throws -> Pair {
        var style = OverlayStyle.default
        style.decor.shape = shape
        style.decor.width = 240
        style.decor.height = 120
        style.decor.cornerRadius = cornerRadius
        // Element-level shadows/glows are host styling that the component model
        // does not yet carry; compare the shape itself.
        style.shadowEnabled = false
        style.glowEnabled = false
        style.decor.fillColor = OverlayColor(
            red: 51.0 / 255,
            green: 153.0 / 255,
            blue: 229.0 / 255,
            alpha: 217.0 / 255
        )
        let nativeElement = OverlayElement(
            type: .decorSolidColor,
            position: CGPoint(x: 0.5, y: 0.5),
            scale: 1,
            opacity: opacity,
            style: style
        )

        // Decor elements are center-anchored; components are top-leading
        // anchored. Derive the component position from the native layout so the
        // geometries coincide exactly.
        let renderContext = OverlayRenderContext(
            canvasSize: Self.canvas,
            activity: Self.activity,
            elapsedTime: 0
        )
        let layout = OverlayRenderModel.decorSolidColorLayout(
            for: nativeElement,
            in: renderContext
        )
        let origin = CGPoint(
            x: Self.canvas.width * 0.5 - layout.size.width / 2,
            y: Self.canvas.height * 0.5 - layout.size.height / 2
        )

        let definition = """
        {
          "spec": "ros.component/0.1",
          "id": "community.parity.decor-rect",
          "version": "1.0.0",
          "name": "Parity Rectangle",
          "license": "MIT",
          "size": [\(layout.size.width), \(layout.size.height)],
          "nodes": [
            {
              "type": "rect",
              "frame": [0, 0, \(layout.size.width), \(layout.size.height)],
              "fill": "\(componentFill)",
              "radius": \(layout.cornerRadius)
            }
          ]
        }
        """
        let reference = try OverlayComponentReference(
            definitionData: Data(definition.utf8),
            source: .imported
        )
        let componentElement = OverlayElement(
            type: .component,
            position: CGPoint(
                x: origin.x / Self.canvas.width,
                y: origin.y / Self.canvas.height
            ),
            scale: 1,
            opacity: opacity,
            style: .default,
            component: OverlayComponentInstance(reference: reference)
        )

        return Pair(
            native: OverlayLayout(elements: [nativeElement]),
            component: OverlayLayout(elements: [componentElement])
        )
    }

    @Test func decorRoundedRectangleMatchesEquivalentComponent() throws {
        let pair = try makeDecorPair()

        try NativeComponentParityHarness.assertParity(
            label: "decor-rounded-rectangle",
            native: pair.native,
            component: pair.component,
            activity: Self.activity,
            elapsedTime: 0,
            size: Self.canvas,
            thresholds: NativeComponentParityHarness.Thresholds(
                channelTolerance: 0,
                maximumChangedPixelRatio: 0,
                maximumChannelDelta: 0,
                maximumMeanChannelDelta: 0
            )
        )
    }

    @Test func elementOpacityMatchesBetweenPaths() throws {
        let pair = try makeDecorPair(opacity: 0.6)

        try NativeComponentParityHarness.assertParity(
            label: "decor-rounded-rectangle-opacity",
            native: pair.native,
            component: pair.component,
            activity: Self.activity,
            elapsedTime: 0,
            size: Self.canvas,
            thresholds: NativeComponentParityHarness.Thresholds(
                channelTolerance: 0,
                maximumChangedPixelRatio: 0,
                maximumChannelDelta: 0,
                maximumMeanChannelDelta: 0
            )
        )
    }

    @Test func decorRectangleMatchesComponentWithZeroRadius() throws {
        let pair = try makeDecorPair(shape: .rectangle, cornerRadius: 0)

        try NativeComponentParityHarness.assertParity(
            label: "decor-rectangle",
            native: pair.native,
            component: pair.component,
            activity: Self.activity,
            elapsedTime: 0,
            size: Self.canvas,
            thresholds: NativeComponentParityHarness.Thresholds(
                channelTolerance: 0,
                maximumChangedPixelRatio: 0,
                maximumChannelDelta: 0,
                maximumMeanChannelDelta: 0
            )
        )
    }

    @Test func harnessDetectsARealDifference() throws {
        let pair = try makeDecorPair(componentFill: "#3499E5D9")

        let result = try NativeComponentParityHarness.compare(
            label: "decor-negative-control",
            native: pair.native,
            component: pair.component,
            activity: Self.activity,
            elapsedTime: 0,
            size: Self.canvas
        )
        #expect(result.changedPixels > 0)
        #expect(result.maximumChannelDelta >= 1)
    }
}
#endif
