import Foundation
import Testing
@testable import RunningOverlay

struct OverlayComponentRichTextTests {
    static func definitionData() throws -> Data {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try Data(contentsOf: root.appendingPathComponent("Sources/RunningOverlay/Resources/Components/decor-text.json"))
    }

    @Test func resolvesBundledDefaultAndStyledParagraphs() throws {
        let package = try OverlayComponentLoader.load(data: Self.definitionData())
        let resolver = OverlayComponentResolver(definition: package.definition)
        let defaults = resolver.resolve(parameters: [:], data: OverlayComponentStubData())
        #expect(defaults.diagnostics.isEmpty)
        #expect(defaults.nodes.count == 1)
        guard case .richText(let frame, let text) = defaults.nodes.first else {
            Issue.record("Expected the solid richText node")
            return
        }
        #expect(frame == CGRect(x: 0, y: 0, width: 240, height: 80))
        #expect(text.text == "Hello")
        #expect(text.font.family == "Menlo")
        #expect(text.font.size == 36)
        #expect(text.align == .center)
        #expect(text.gradient == nil)
        #expect(!text.autoFit)

        let styled = resolver.resolve(parameters: [
            "text": .string("FIRST\nSECOND"), "alignment": .string("right"),
            "fontWeight": .string("bold"), "tracking": .number(-1.5),
            "lineHeight": .number(1.8), "autoFit": .boolean(true),
            "fillMode": .string("gradient"), "gradientDirection": .string("bottomLeftToTopRight"),
            "gradientStart": .string("#FF0000"), "gradientEnd": .string("#0000FF"),
            "strokeWidth": .number(3), "strokeColor": .string("#00FF00")
        ], data: OverlayComponentStubData())
        #expect(styled.diagnostics.isEmpty)
        #expect(styled.nodes.count == 1)
        guard case .richText(_, let paragraph) = styled.nodes.first else {
            Issue.record("Expected the gradient richText node")
            return
        }
        #expect(paragraph.text == "FIRST\nSECOND")
        #expect(paragraph.align == .right)
        #expect(paragraph.font.weight == .bold)
        #expect(paragraph.tracking == -1.5)
        #expect(paragraph.lineHeight == 1.8)
        #expect(paragraph.autoFit)
        #expect(paragraph.strokeWidth == 3)
        #expect(paragraph.gradient?.stops.count == 2)
        #expect(paragraph.gradient?.from == CGPoint(x: 0, y: 80))
        #expect(paragraph.gradient?.to == CGPoint(x: 240, y: 0))
    }

    @Test func rejectsMalformedRichTextFields() throws {
        let base: [String: Any] = [
            "type": "richText", "frame": [0, 0, 240, 80], "text": "Hello",
            "font": ["family": "Menlo", "size": 36], "color": "#FFFFFF"
        ]
        var missingFrame = base
        missingFrame.removeValue(forKey: "frame")
        var badAlignment = base
        badAlignment["align"] = "leading"
        var badFit = base
        badFit["autoFit"] = 1
        var badGradient = base
        badGradient["gradient"] = [
            "from": [0, 0], "to": [0, 80],
            "stops": [["offset": 1, "color": "#FFFFFF"], ["offset": 0, "color": "#000000"]]
        ]
        for node in [missingFrame, badAlignment, badFit, badGradient] {
            var document = try #require(JSONSerialization.jsonObject(with: Self.definitionData()) as? [String: Any])
            document["nodes"] = [node]
            let data = try JSONSerialization.data(withJSONObject: document)
            #expect(throws: OverlayComponentValidationError.self) {
                try OverlayComponentLoader.load(data: data)
            }
        }
    }
}

#if canImport(CSkiaBridge)
import AppKit
import CSkiaBridge

@Suite(.serialized, .skiaSerialized)
struct OverlayComponentRichTextParityTests {
    @Test func defaultAndStyledTextMatchNative() throws {
        let reference = try OverlayComponentReference(
            definitionData: OverlayComponentRichTextTests.definitionData(), source: .project
        )
        let activity = SkiaChartsGoldenTests.activity(duration: 60)
        for styled in [false, true] {
            for alignment in [DecorTextAlignment.leading, .center, .trailing] {
                for scale in [1.0, 1.5, 2.0] {
                    var style = OverlayStyle.default
                    style.glowEnabled = false
                    style.shadowEnabled = false
                    style.borderEnabled = false
                    style.decor.width = styled ? 360 : 240
                    style.decor.height = styled ? 180 : 80
                    style.decor.textContent = styled ? "FIRST LINE WITH WRAPPING\nSecond line" : "Hello"
                    style.decor.textFont = .system(family: "Menlo")
                    style.decor.textSize = 36
                    style.decor.textAlignment = alignment
                    style.decor.textLineHeight = styled ? 1.7 : 1.2
                    style.decor.textLetterSpacing = styled ? -4 : 0
                    style.decor.textFillMode = .solid(color: styled
                        ? OverlayColor(red: 51.0 / 255, green: 204.0 / 255, blue: 1, alpha: 1) : .white)
                    style.decor.textStrokeWidth = styled ? 3 : 0
                    style.decor.textStrokeColor = OverlayColor(red: 1, green: 0, blue: 0, alpha: 1)
                    let native = OverlayElement(type: .decorText, position: CGPoint(x: 0.5, y: 0.5),
                                                scale: scale, opacity: styled ? 0.65 : 1, style: style)
                    let canvas = CGSize(width: 1280, height: 720)
                    let context = OverlayRenderContext(canvasSize: canvas, activity: activity, elapsedTime: 30)
                    let layout = OverlayRenderModel.decorTextLayout(for: native, in: context)
                    let align: String = switch alignment {
                    case .leading: "left"
                    case .center: "center"
                    case .trailing: "right"
                    }
                    let component = OverlayElement(
                        type: .component,
                        position: CGPoint(x: 0.5 - layout.size.width / canvas.width / 2,
                                          y: 0.5 - layout.size.height / canvas.height / 2),
                        scale: scale, opacity: native.opacity, style: style,
                        component: OverlayComponentInstance(reference: reference, parameters: [
                            "text": .string(layout.content), "fontFamily": .string("Menlo"),
                            "textWidth": .number(style.decor.width), "textHeight": .number(style.decor.height),
                            "fontSize": .number(36), "alignment": .string(align),
                            "lineHeight": .number(layout.lineHeight),
                            "fillColor": .string(styled ? "#33CCFF" : "#FFFFFF"),
                            // Native converts its scaled letterSpacing to a
                            // dimensionless AppKit kern. richText uses points.
                            "tracking": .number(layout.letterSpacing / max(layout.fontSize, 1) / scale),
                            "strokeWidth": .number(styled ? 3 : 0), "strokeColor": .string("#FF0000")
                        ])
                    )
                    try NativeComponentParityHarness.assertParity(
                        label: "text-\(styled)-\(alignment)-\(scale)",
                        native: OverlayLayout(elements: [native]), component: OverlayLayout(elements: [component]),
                        activity: activity, elapsedTime: 30, size: canvas, thresholds: .exact
                    )
                }
            }
        }
    }

    @Test func gradientPaintsGlyphsAndPreservesStroke() throws {
        let request = SkiaParagraphTextLayout(
            size: CGSize(width: 240, height: 100), content: "MMMM",
            font: OverlayFontResolver.appKitFont(family: "Menlo", size: 54, weight: .regular),
            alignment: .center, lineHeight: 1.2, tracking: 0, color: .white,
            gradient: .init(stops: [
                .init(offset: 0, color: OverlayColor(red: 1, green: 0, blue: 0, alpha: 1)),
                .init(offset: 1, color: OverlayColor(red: 0, green: 0, blue: 1, alpha: 1))
            ], from: CGPoint(x: 0, y: 0), to: CGPoint(x: 240, y: 0)),
            strokeWidth: 5, strokeColor: OverlayColor(red: 0, green: 1, blue: 0, alpha: 1), autoFit: false
        )
        let bitmap = try #require(SkiaParagraphTextRasterCache.bitmap(for: request))
        let image = try #require(bitmap.pointer)
        let context = try #require(skb_create(240, 100))
        defer { skb_destroy(context) }
        skb_clear(context)
        skb_draw_image_handle(context, image, 0, 0, 240, 100, 1, 0, 0, 0, 0)
        var rowBytes = 0
        let pixels = try #require(skb_pixels(context, &rowBytes))
        var redFill = 0
        var blueFill = 0
        var greenStroke = 0
        var transparent = 0
        for y in 0..<100 {
            for x in 0..<240 {
                let offset = y * rowBytes + x * 4
                let b = Int(pixels[offset]), g = Int(pixels[offset + 1]), r = Int(pixels[offset + 2])
                if pixels[offset + 3] == 0 { transparent += 1 }
                if r > b + 20 && r > g + 20 { redFill += 1 }
                if b > r + 20 && b > g + 20 { blueFill += 1 }
                if g > r + 20 && g > b + 20 { greenStroke += 1 }
            }
        }
        #expect(redFill > 100)
        #expect(blueFill > 100)
        #expect(greenStroke > 20)
        #expect(transparent > 12000)
    }

    @Test func autoFitShrinksOnlyWhenNeededAndEmptyTextIsSafe() throws {
        var request = SkiaParagraphTextLayout(
            size: CGSize(width: 120, height: 40), content: "First line\nSecond line",
            font: OverlayFontResolver.appKitFont(family: "Menlo", size: 60, weight: .regular),
            alignment: .center, lineHeight: 1.2, tracking: 1, color: .white,
            gradient: nil, strokeWidth: 0, strokeColor: .white, autoFit: true
        )
        let fitted = SkiaParagraphTextRasterCache.fittedFontSize(for: request, width: 120, height: 40)
        #expect(fitted >= 1)
        #expect(fitted < 30)
        request.size = CGSize(width: 1200, height: 400)
        #expect(SkiaParagraphTextRasterCache.fittedFontSize(for: request, width: 1200, height: 400) == 60)
        request.autoFit = false
        #expect(SkiaParagraphTextRasterCache.fittedFontSize(for: request, width: 120, height: 40) == 60)
        request.content = ""
        #expect(SkiaParagraphTextRasterCache.bitmap(for: request) == nil)
    }
}
#endif
