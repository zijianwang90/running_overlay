import Foundation
import Testing
@testable import RunningOverlay

struct OverlayComponentSymbolTests {
    static func data() throws -> Data {
        let item = try #require(OverlayComponentLibraryItem.decor.first { $0.id == "studio.decor-icon" })
        return try #require(OverlayComponentLibrary.data(for: item))
    }

    @Test func fittedSymbolResolvesParametersAndInvalidEnums() throws {
        let package = try OverlayComponentLoader.load(data: Self.data())
        let resolver = OverlayComponentResolver(definition: package.definition)
        let result = resolver.resolve(parameters: [
            "weight": .string("thin"), "symbolScale": .string("large"),
            "iconWidth": .number(120), "iconHeight": .number(80)
        ], data: OverlayComponentStubData())
        #expect(result.diagnostics.isEmpty)
        guard case let .symbol(frame, name, _, weight, scale, rendering) = result.nodes.first else {
            Issue.record("Expected fitted symbol")
            return
        }
        #expect(frame.size == CGSize(width: 120, height: 80))
        #expect(name == "figure.run")
        #expect(weight == .thin)
        #expect(scale == .large)
        #expect(rendering == .fit)

        var document = try #require(JSONSerialization.jsonObject(with: Self.data()) as? [String: Any])
        var nodes = try #require(document["nodes"] as? [[String: Any]])
        nodes[0]["weight"] = "=\"invalid\""
        nodes[0]["scale"] = "=\"invalid\""
        document["nodes"] = nodes
        let invalid = try OverlayComponentLoader.load(data: JSONSerialization.data(withJSONObject: document))
        let fallback = OverlayComponentResolver(definition: invalid.definition)
            .resolve(parameters: [:], data: OverlayComponentStubData())
        #expect(fallback.diagnostics.count == 2)
        guard case let .symbol(_, _, _, fallbackWeight, fallbackScale, _) = fallback.nodes.first else {
            Issue.record("Expected fallback symbol")
            return
        }
        #expect(fallbackWeight == .medium)
        #expect(fallbackScale == .medium)
    }

    @Test func rejectsUnknownLiteralSymbolConfiguration() throws {
        for (key, value) in [("weight", "invalid"), ("scale", "huge"), ("rendering", "stretch")] {
            var document = try #require(JSONSerialization.jsonObject(with: Self.data()) as? [String: Any])
            var nodes = try #require(document["nodes"] as? [[String: Any]])
            nodes[0][key] = value
            document["nodes"] = nodes
            let data = try JSONSerialization.data(withJSONObject: document)
            #expect(throws: OverlayComponentValidationError.self) {
                try OverlayComponentLoader.load(data: data)
            }
        }
    }
}

#if canImport(CSkiaBridge)
@Suite(.serialized, .skiaSerialized)
struct OverlayComponentSymbolParityTests {
    @Test func fittedSymbolsMatchNative() throws {
        let reference = try OverlayComponentReference(definitionData: OverlayComponentSymbolTests.data(), source: .bundled)
        let activity = SkiaChartsGoldenTests.activity(duration: 60)
        let canvas = CGSize(width: 1280, height: 720)
        for (weightIndex, weight) in SymbolWeight.allCases.enumerated() {
            for (scaleIndex, symbolScale) in SymbolScale.allCases.enumerated() {
                let scale = [1.0, 1.5, 2.0][(weightIndex + scaleIndex) % 3]
                let width = weightIndex.isMultiple(of: 2) ? 160.0 : 240.0
                let height = 120.0
                let name = ["figure.run", "heart.fill", "arrow.right"][scaleIndex]
                var style = OverlayStyle.default
                style.decor.width = width
                style.decor.height = height
                style.decor.iconAsset = .sfSymbol(name: name, weight: weight, scale: symbolScale)
                style.decor.iconTint = .white
                style.decor.iconContentMode = .fit
                style.glowEnabled = weightIndex.isMultiple(of: 2)
                style.glowIntensity = 0.4
                let native = OverlayElement(type: .decorIcon, position: CGPoint(x: 0.5, y: 0.5),
                                            scale: scale, opacity: 0.65, style: style)
                let context = OverlayRenderContext(canvasSize: canvas, activity: activity, elapsedTime: 30)
                let size = OverlayRenderModel.decorIconLayout(for: native, in: context).size
                let component = OverlayElement(
                    type: .component,
                    position: CGPoint(x: 0.5 - size.width / canvas.width / 2,
                                      y: 0.5 - size.height / canvas.height / 2),
                    scale: scale, opacity: native.opacity, style: style,
                    component: OverlayComponentInstance(reference: reference, parameters: [
                        "symbolName": .string(name), "weight": .string(weight.rawValue),
                        "symbolScale": .string(symbolScale.rawValue),
                        "iconWidth": .number(width), "iconHeight": .number(height)
                    ])
                )
                let frame = try #require(OverlayComponentSkiaRenderer.frame(for: component, renderContext: context))
                #expect(abs(frame.width - size.width) < 0.000001)
                #expect(abs(frame.height - size.height) < 0.000001)
                try NativeComponentParityHarness.assertParity(
                    label: "symbol-\(weight.rawValue)-\(symbolScale.rawValue)-\(scale)",
                    native: OverlayLayout(elements: [native]), component: OverlayLayout(elements: [component]),
                    activity: activity, elapsedTime: 30, size: canvas, thresholds: .exact
                )
            }
        }
    }
}
#endif
