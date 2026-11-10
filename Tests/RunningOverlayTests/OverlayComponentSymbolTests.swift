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
