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
        // Default element shadow stays on: the host applies it around the
        // whole element on both paths.
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
            style: style,
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

    // MARK: - Numeric text

    /// Builds a heart-rate element and a declarative equivalent that uses a
    /// horizontal stack with auto-sized text. Layout runs at pixel size in
    /// both paths, so the unit lands after the measured value width even when
    /// the element is scaled.
    private func makeHeartRatePair(elementScale: Double = 1) throws -> Pair {
        var style = OverlayStyle.default
        style.fontName = "Helvetica Neue"
        style.fontSize = 28
        style.showLabel = false
        style.showUnit = true
        style.unitPosition = .trailing
        style.unitTextAlignment = .leading
        style.unitFontName = "Helvetica Neue"
        style.unitFontSize = 20
        style.unitFontWeight = .medium
        style.iconEnabled = false
        style.backgroundEnabled = false
        // Default element shadow stays on: the host applies it around the
        // whole element on both paths.
        let nativeElement = OverlayElement(
            type: .heartRate,
            position: CGPoint(x: 0.25, y: 0.25),
            scale: elementScale,
            opacity: 1,
            style: style
        )
        let context = OverlayRenderContext(
            canvasSize: Self.canvas,
            activity: Self.activity,
            elapsedTime: 0
        )
        let layout = OverlayRenderModel.textLayout(for: nativeElement, in: context)
        let composition = SkiaTextPresetDrawing.compose(
            element: nativeElement,
            layout: layout,
            renderContext: context
        )
        let valueTracking = -style.fontSize * 0.012

        let definition = """
        {
          "spec": "ros.component/0.1",
          "id": "community.parity.heart-rate",
          "version": "1.0.0",
          "name": "Parity Heart Rate",
          "license": "MIT",
          "size": [\(composition.size.width / elementScale + 8), \(composition.size.height / elementScale + 8)],
          "nodes": [
            {
              "type": "stack",
              "direction": "horizontal",
              "spacing": 8,
              "crossAlign": "start",
              "children": [
                {
                  "type": "text",
                  "text": "=format(signal(\\"activity.heartRate\\"), \\"integer\\")",
                  "font": { "family": "Helvetica Neue", "size": 28, "weight": "semibold" },
                  "color": "#FFFFFF",
                  "align": "left",
                  "verticalAlign": "top",
                  "tracking": \(valueTracking)
                },
                {
                  "type": "text",
                  "text": "bpm",
                  "font": { "family": "Helvetica Neue", "size": 20, "weight": "medium" },
                  "color": "#FFFFFF",
                  "align": "left",
                  "verticalAlign": "top"
                }
              ]
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
            position: nativeElement.position,
            scale: elementScale,
            opacity: 1,
            style: style,
            component: OverlayComponentInstance(reference: reference)
        )

        return Pair(
            native: OverlayLayout(elements: [nativeElement]),
            component: OverlayLayout(elements: [componentElement])
        )
    }

    @Test func heartRateTrailingUnitMatchesEquivalentComponent() throws {
        let pair = try makeHeartRatePair()

        try NativeComponentParityHarness.assertParity(
            label: "heart-rate-trailing-unit",
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

    /// CoreText advances are not linear in point size, so this pins the
    /// decision to lay stacks out at pixel size rather than scaling design-unit
    /// measurements.
    @Test func heartRateTrailingUnitMatchesAtScaledElement() throws {
        let pair = try makeHeartRatePair(elementScale: 1.5)

        try NativeComponentParityHarness.assertParity(
            label: "heart-rate-trailing-unit-scale-1.5",
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

    // MARK: - Numeric chrome

    private enum ChromeLayout {
        /// Icon leading and vertically centered, unit trailing.
        case iconLeadingUnitTrailing
        /// Icon top-centered, unit below the value and centered, minimum width.
        case iconTopUnitBottomCentered
    }

    /// Heart rate with the native icon and background chrome. The component
    /// expresses it with a content-sized definition, a `symbol` node and
    /// stacks. Native background padding and radius are canvas-scaled but not
    /// element-scaled, while component units scale with the element, so the
    /// definition divides them by the element scale; legacy mapping will bake
    /// the same conversion.
    private func makeHeartRateChromePair(
        elementScale: Double,
        layout chrome: ChromeLayout
    ) throws -> Pair {
        var style = OverlayStyle.default
        style.fontName = "Helvetica Neue"
        style.fontSize = 28
        style.showLabel = false
        style.showUnit = true
        style.unitFontName = "Helvetica Neue"
        style.unitFontSize = 20
        style.unitFontWeight = .medium
        style.iconEnabled = true
        style.iconSystemName = "heart.fill"
        style.iconSize = 22
        style.iconSpacing = 8
        style.iconTextAlignment = .center
        style.backgroundEnabled = true
        style.backgroundColor = .black
        style.backgroundOpacity = 51.0 / 255
        style.backgroundPaddingX = 10
        style.backgroundPaddingY = 6
        style.backgroundRadius = 6
        switch chrome {
        case .iconLeadingUnitTrailing:
            style.iconPosition = .leading
            style.unitPosition = .trailing
            style.unitTextAlignment = .leading
            style.numericMinWidth = 0
        case .iconTopUnitBottomCentered:
            style.iconPosition = .top
            style.unitPosition = .bottom
            style.unitTextAlignment = .center
            style.numericMinWidth = 120
        }
        let nativeElement = OverlayElement(
            type: .heartRate,
            position: CGPoint(x: 0.25, y: 0.25),
            scale: elementScale,
            opacity: 1,
            style: style
        )
        let valueTracking = -style.fontSize * 0.012
        let value = """
        {
          "type": "text",
          "text": "=format(signal(\\"activity.heartRate\\"), \\"integer\\")",
          "font": { "family": "Helvetica Neue", "size": 28, "weight": "semibold" },
          "color": "#FFFFFF",
          "tracking": \(valueTracking)
        }
        """
        let icon = """
        { "type": "symbol", "name": "heart.fill", "frame": [0, 0, 22, 22], "color": "#FFFFFF"%@ }
        """
        let content: String
        let minWidth: Double
        switch chrome {
        case .iconLeadingUnitTrailing:
            minWidth = 0
            content = """
            {
              "type": "stack", "direction": "horizontal", "spacing": 8, "crossAlign": "center",
              "children": [
                \(icon.replacingOccurrences(of: "%@", with: "")),
                {
                  "type": "stack", "direction": "horizontal", "spacing": 8, "crossAlign": "start",
                  "children": [
                    \(value),
                    {
                      "type": "text", "text": "bpm",
                      "font": { "family": "Helvetica Neue", "size": 20, "weight": "medium" },
                      "color": "#FFFFFF"
                    }
                  ]
                }
              ]
            }
            """
        case .iconTopUnitBottomCentered:
            minWidth = 120
            content = """
            {
              "type": "stack", "direction": "vertical", "spacing": 8, "crossAlign": "start",
              "children": [
                \(icon.replacingOccurrences(of: "%@", with: ", \"alignSelf\": \"center\"")),
                {
                  "type": "stack", "direction": "vertical", "spacing": 8, "crossAlign": "start",
                  "children": [
                    \(value),
                    {
                      "type": "text", "text": "bpm", "alignSelf": "center",
                      "font": { "family": "Helvetica Neue", "size": 20, "weight": "medium" },
                      "color": "#FFFFFF"
                    }
                  ]
                }
              ]
            }
            """
        }
        let definition = """
        {
          "spec": "ros.component/0.1",
          "id": "community.parity.heart-rate-chrome",
          "version": "1.0.0",
          "name": "Parity Heart Rate Chrome",
          "license": "MIT",
          "size": "content",
          "padding": [\(10 / elementScale), \(6 / elementScale)],
          "minSize": [\(minWidth), 0],
          "background": { "color": "#00000033", "radius": \(6 / elementScale) },
          "nodes": [\(content)]
        }
        """
        let reference = try OverlayComponentReference(
            definitionData: Data(definition.utf8),
            source: .imported
        )
        let componentElement = OverlayElement(
            type: .component,
            position: nativeElement.position,
            scale: elementScale,
            opacity: 1,
            style: style,
            component: OverlayComponentInstance(reference: reference)
        )
        return Pair(
            native: OverlayLayout(elements: [nativeElement]),
            component: OverlayLayout(elements: [componentElement])
        )
    }

    @Test(arguments: [1.0, 1.5, 2.0])
    func heartRateIconAndBackgroundMatchContentSizedComponent(elementScale: Double) throws {
        let pair = try makeHeartRateChromePair(
            elementScale: elementScale,
            layout: .iconLeadingUnitTrailing
        )
        try NativeComponentParityHarness.assertParity(
            label: "heart-rate-chrome-leading-scale-\(elementScale)",
            native: pair.native,
            component: pair.component,
            activity: Self.activity,
            elapsedTime: 0,
            size: Self.canvas,
            thresholds: .exact
        )
    }

    @Test(arguments: [1.0, 2.0])
    func heartRateIconTopUnitBottomMatchesAlignSelfComponent(elementScale: Double) throws {
        let pair = try makeHeartRateChromePair(
            elementScale: elementScale,
            layout: .iconTopUnitBottomCentered
        )
        try NativeComponentParityHarness.assertParity(
            label: "heart-rate-chrome-top-scale-\(elementScale)",
            native: pair.native,
            component: pair.component,
            activity: Self.activity,
            elapsedTime: 0,
            size: Self.canvas,
            thresholds: .exact
        )
    }

    /// The host frame used for hit testing and selection is the measured
    /// content-sized bounds, which equal the native composition size.
    @Test func contentSizedFrameMatchesNativeCompositionSize() throws {
        for chrome in [ChromeLayout.iconLeadingUnitTrailing, .iconTopUnitBottomCentered] {
            let pair = try makeHeartRateChromePair(elementScale: 1.5, layout: chrome)
            let context = OverlayRenderContext(
                canvasSize: Self.canvas,
                activity: Self.activity,
                elapsedTime: 0
            )
            let native = try #require(pair.native.elements.first)
            let composition = SkiaTextPresetDrawing.compose(
                element: native,
                layout: OverlayRenderModel.textLayout(for: native, in: context),
                renderContext: context
            )
            let component = try #require(pair.component.elements.first)
            let frame = try #require(OverlayComponentSkiaRenderer.frame(
                for: component,
                renderContext: context
            ))
            #expect(abs(frame.width - composition.size.width) < 0.001)
            #expect(abs(frame.height - composition.size.height) < 0.001)
        }
    }
}
#endif
