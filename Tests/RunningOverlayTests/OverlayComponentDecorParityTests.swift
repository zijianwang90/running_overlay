#if canImport(CSkiaBridge)
import Foundation
import Testing
@testable import RunningOverlay

@Suite(.serialized, .skiaSerialized)
struct OverlayComponentDecorParityTests {
    @Test func bundledShapeMatchesNative() throws {
        let item = try #require(OverlayComponentLibraryItem.decor.first)
        let reference = try OverlayComponentLibrary.reference(for: item)
        let activity = SkiaChartsGoldenTests.activity(duration: 60)
        for shape in DecorShape.allCases {
            for scale in [1.0, 1.5, 2.0] {
                for border in [false, true] {
                    var style = OverlayStyle.default
                    style.decor.shape = shape
                    style.decor.width = 240
                    style.decor.height = 80
                    style.decor.cornerRadius = 18
                    style.decor.fillColor = OverlayColor(red: 51.0 / 255, green: 153.0 / 255, blue: 229.0 / 255, alpha: 217.0 / 255)
                    style.borderEnabled = border
                    style.borderWidth = 3
                    style.borderColor = .white
                    style.borderOpacity = 1
                    style.glowEnabled = border
                    style.glowIntensity = 0.4
                    let native = OverlayElement(
                        type: .decorSolidColor, position: CGPoint(x: 0.5, y: 0.5),
                        scale: scale, opacity: 0.65, style: style
                    )
                    let canvas = CGSize(width: 1280, height: 720)
                    let context = OverlayRenderContext(canvasSize: canvas, activity: activity, elapsedTime: 30)
                    let size = OverlayRenderModel.decorSolidColorLayout(for: native, in: context).size
                    let component = OverlayElement(
                        type: .component,
                        position: CGPoint(x: 0.5 - size.width / canvas.width / 2, y: 0.5 - size.height / canvas.height / 2),
                        scale: scale, opacity: native.opacity, style: style,
                        component: OverlayComponentInstance(reference: reference, parameters: [
                            "shape": .string(shape.rawValue),
                            "shapeWidth": .number(240), "shapeHeight": .number(80),
                            "cornerRadius": .number(18), "fill": .string("#3399E5D9"),
                            "borderEnabled": .boolean(border), "borderColor": .string("#FFFFFFFF"),
                            // Native border width is in canvas pixels; convert
                            // that legacy quirk to component design units here.
                            "borderWidth": .number(3 / scale)
                        ])
                    )
                    let frame = try #require(OverlayComponentSkiaRenderer.frame(for: component, renderContext: context))
                    #expect(frame.size == size)
                    #expect(abs(frame.midX - canvas.width / 2) < 0.000001)
                    #expect(abs(frame.midY - canvas.height / 2) < 0.000001)
                    try NativeComponentParityHarness.assertParity(
                        label: "shape-\(shape.rawValue)-\(scale)-border-\(border)",
                        native: OverlayLayout(elements: [native]),
                        component: OverlayLayout(elements: [component]), activity: activity,
                        elapsedTime: 30, size: canvas, thresholds: .exact
                    )
                }
            }
        }
    }
}
#endif
