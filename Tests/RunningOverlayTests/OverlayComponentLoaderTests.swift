import Foundation
import Testing
@testable import RunningOverlay

struct OverlayComponentLoaderTests {
    private func fixtureData(_ name: String) throws -> Data {
        let url = try #require(
            Bundle.module.url(
                forResource: name,
                withExtension: "json",
                subdirectory: "Fixtures/Components"
            )
        )
        return try Data(contentsOf: url)
    }

    private func errors(from data: Data, assets: Set<String> = []) -> [OverlayComponentDiagnostic] {
        do {
            _ = try OverlayComponentLoader.load(data: data, assets: assets)
            return []
        } catch let error as OverlayComponentValidationError {
            return error.errors
        } catch {
            return [OverlayComponentDiagnostic(path: "$", message: "unexpected error")]
        }
    }

    @Test func loadsHeartRatePillExample() throws {
        let data = try fixtureData("hr-pill")
        let package = try OverlayComponentLoader.load(data: data)

        #expect(package.definition.spec == "ros.component/0.1")
        #expect(package.definition.id == "studio.builtin.heart-rate-pill")
        #expect(package.definition.version == "1.0.0")
        #expect(package.definition.license == "MIT")
        #expect(package.definition.size == OverlayComponentSize(width: 240, height: 72))
        #expect(package.definition.params.count == 3)
        #expect(package.definition.bindings.count == 3)
        #expect(package.definition.nodes.count == 4)
        #expect(package.digest.hasPrefix("sha256:"))
        #expect(package.digest.count == "sha256:".count + 64)
    }

    @Test func loadsLapSplitsExampleWithRepeat() throws {
        let data = try fixtureData("lap-splits")
        let package = try OverlayComponentLoader.load(data: data)

        #expect(package.definition.id == "studio.examples.lap-splits")
        #expect(package.definition.nodes.count == 4)

        guard case .repeatNode(_, let itemName, let indexName, _, let children)? =
            package.definition.nodes.last?.kind else {
            Issue.record("expected trailing repeat node")
            return
        }
        #expect(itemName == "lap")
        #expect(indexName == "index")
        #expect(children.count == 5)
    }

    @Test func rejectsUnknownTopLevelFields() throws {
        let original = try fixtureData("hr-pill")
        var text = try #require(String(data: original, encoding: .utf8))
        text = text.replacingOccurrences(of: "{", with: "{\n  \"unexpected\": true,", options: [], range: text.startIndex..<text.index(after: text.startIndex))
        let diagnostics = errors(from: try #require(text.data(using: .utf8)))

        #expect(diagnostics.contains { $0.path == "$.unexpected" })
    }

    @Test func rejectsMissingNodes() throws {
        let json = """
        {
          "spec": "ros.component/0.1",
          "id": "community.test.empty",
          "version": "1.0.0",
          "name": "Empty",
          "license": "MIT",
          "size": [100, 100]
        }
        """
        let diagnostics = errors(from: try #require(json.data(using: .utf8)))
        #expect(diagnostics.contains { $0.path == "$.nodes" })
    }

    @Test func rejectsInvalidExpressionWithPointer() throws {
        let json = """
        {
          "spec": "ros.component/0.1",
          "id": "community.test.bad-expression",
          "version": "1.0.0",
          "name": "Bad",
          "license": "MIT",
          "size": [100, 100],
          "nodes": [
            { "type": "rect", "frame": ["=1 +", 0, 100, 100], "fill": "#000000" }
          ]
        }
        """
        let diagnostics = errors(from: try #require(json.data(using: .utf8)))
        #expect(diagnostics.contains { $0.path == "$.nodes[0].frame[0]" })
    }

    @Test func rejectsNestedRepeat() throws {
        let json = """
        {
          "spec": "ros.component/0.1",
          "id": "community.test.nested-repeat",
          "version": "1.0.0",
          "name": "Nested",
          "license": "MIT",
          "size": [100, 100],
          "bindings": { "values": { "list": "structure.laps" } },
          "nodes": [
            {
              "type": "repeat", "frame": [0, 0, 100, 100], "over": "=values",
              "children": [
                {
                  "type": "repeat", "frame": [0, 0, 100, 100], "over": "=values",
                  "children": [
                    { "type": "rect", "frame": [0, 0, 10, 10], "fill": "#FFFFFF" }
                  ]
                }
              ]
            }
          ]
        }
        """
        let diagnostics = errors(from: try #require(json.data(using: .utf8)))
        #expect(diagnostics.contains { $0.message.contains("nested repeat") })
    }

    @Test func loadsStackWithAutoSizedText() throws {
        let json = """
        {
          "spec": "ros.component/0.1",
          "id": "community.test.stack",
          "version": "1.0.0",
          "name": "Stack",
          "license": "MIT",
          "size": [200, 100],
          "nodes": [
            {
              "type": "stack",
              "direction": "vertical",
              "spacing": 6,
              "crossAlign": "center",
              "children": [
                {
                  "type": "text", "text": "=format(42, \\"integer\\")",
                  "font": { "family": "Helvetica Neue", "size": 20 },
                  "color": "#FFFFFF"
                },
                { "type": "rect", "frame": [0, 0, 40, 4], "fill": "#FFFFFF" }
              ]
            }
          ]
        }
        """
        let package = try OverlayComponentLoader.load(
            data: try #require(json.data(using: .utf8))
        )
        guard case .stack(let direction, _, let crossAlign, let children)? =
            package.definition.nodes.first?.kind else {
            Issue.record("expected stack node")
            return
        }
        #expect(direction == .vertical)
        #expect(crossAlign == .center)
        #expect(children.count == 2)
        #expect(children.first?.frame == nil)
        #expect(children.last?.frame != nil)
    }

    @Test func rejectsStackChildWithoutFrame() throws {
        let json = """
        {
          "spec": "ros.component/0.1",
          "id": "community.test.stack-child",
          "version": "1.0.0",
          "name": "Stack Child",
          "license": "MIT",
          "size": [100, 100],
          "nodes": [
            {
              "type": "stack",
              "children": [
                {
                  "type": "group",
                  "children": [
                    { "type": "rect", "frame": [0, 0, 10, 10], "fill": "#FFFFFF" }
                  ]
                }
              ]
            }
          ]
        }
        """
        let diagnostics = errors(from: try #require(json.data(using: .utf8)))
        #expect(diagnostics.contains { $0.path == "$.nodes[0].children[0].frame" })
    }

    @Test func rejectsDuplicateParameterIDs() throws {
        let json = """
        {
          "spec": "ros.component/0.1",
          "id": "community.test.duplicate-param",
          "version": "1.0.0",
          "name": "Duplicate",
          "license": "MIT",
          "size": [100, 100],
          "params": [
            { "id": "accent", "type": "color", "label": "Accent", "default": "#FF0000" },
            { "id": "accent", "type": "bool", "label": "Accent", "default": true }
          ],
          "nodes": [
            { "type": "rect", "frame": [0, 0, 100, 100], "fill": "#000000" }
          ]
        }
        """
        let diagnostics = errors(from: try #require(json.data(using: .utf8)))
        #expect(diagnostics.contains { $0.message.contains("duplicate param id") })
    }

    @Test func rejectsImageAssetMissingFromPackage() throws {
        let json = """
        {
          "spec": "ros.component/0.1",
          "id": "community.test.missing-asset",
          "version": "1.0.0",
          "name": "Missing Asset",
          "license": "MIT",
          "size": [100, 100],
          "nodes": [
            { "type": "image", "frame": [0, 0, 100, 100], "asset": "assets/missing.png" }
          ]
        }
        """
        let diagnostics = errors(
            from: try #require(json.data(using: .utf8)),
            assets: ["assets/present.png"]
        )
        #expect(diagnostics.contains { $0.path == "$.nodes[0].asset" })
    }

    @Test func acceptsImageAssetPresentInPackage() throws {
        let json = """
        {
          "spec": "ros.component/0.1",
          "id": "community.test.present-asset",
          "version": "1.0.0",
          "name": "Present Asset",
          "license": "MIT",
          "size": [100, 100],
          "nodes": [
            { "type": "image", "frame": [0, 0, 100, 100], "asset": "assets/present.png" }
          ]
        }
        """
        let package = try OverlayComponentLoader.load(
            data: try #require(json.data(using: .utf8)),
            assets: ["assets/present.png"]
        )
        #expect(package.assets == ["assets/present.png"])
    }

    @Test func rejectsInvalidParameterDefault() throws {
        let json = """
        {
          "spec": "ros.component/0.1",
          "id": "community.test.bad-default",
          "version": "1.0.0",
          "name": "Bad Default",
          "license": "MIT",
          "size": [100, 100],
          "params": [
            { "id": "size", "type": "number", "label": "Size", "min": 0, "max": 10, "default": 20 }
          ],
          "nodes": [
            { "type": "rect", "frame": [0, 0, 100, 100], "fill": "#000000" }
          ]
        }
        """
        let diagnostics = errors(from: try #require(json.data(using: .utf8)))
        #expect(diagnostics.contains { $0.path == "$.params[0].default" })
    }
}
