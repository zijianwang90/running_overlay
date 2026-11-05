import CoreGraphics
import Foundation
import Testing
@testable import RunningOverlay

struct OverlayComponentResolverTests {
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

    private func flatten(_ nodes: [OverlayComponentResolvedNode]) -> [OverlayComponentResolvedNode] {
        nodes.flatMap { node -> [OverlayComponentResolvedNode] in
            switch node {
            case .group(_, _, _, _, let children):
                return [node] + flatten(children)
            case .opacity(_, let content):
                return [node] + flatten([content])
            default:
                return [node]
            }
        }
    }

    private func textNodes(
        _ resolved: OverlayComponentResolved
    ) -> [(text: String, color: OverlayColor, frame: CGRect)] {
        flatten(resolved.nodes).compactMap { node in
            guard case .text(let frame, let text, _, let color, _, _, _, _) = node else {
                return nil
            }
            return (text, color, frame)
        }
    }

    @Test func resolvesHeartRatePillAgainstStubData() throws {
        let package = try OverlayComponentLoader.load(data: try fixtureData("hr-pill"))
        let zoneColor = OverlayColor(red: 1, green: 0.56, blue: 0.2, alpha: 1)
        let data = OverlayComponentStubData(
            signals: [
                "activity.heartRate": .number(152),
                "zone.heartRate": .record([
                    "index": .number(4),
                    "label": .string("Z4"),
                    "color": .color(zoneColor)
                ])
            ],
            seriesValues: [
                "activity.heartRate": [.number(120), .number(140), .number(152)]
            ]
        )

        let resolved = OverlayComponentResolver(definition: package.definition)
            .resolve(parameters: [:], data: data)

        #expect(resolved.diagnostics.isEmpty)
        #expect(resolved.size == OverlayComponentSize(width: 240, height: 72))
        #expect(resolved.nodes.count == 4)

        let texts = textNodes(resolved)
        #expect(texts.map(\.text).contains("152"))
        #expect(texts.map(\.text).contains("BPM"))
        let valueText = try #require(texts.first { $0.text == "152" })
        #expect(valueText.color == zoneColor)

        let sparkline = try #require(flatten(resolved.nodes).first { node in
            if case .sparkline = node { return true }
            return false
        })
        guard case .sparkline(_, let values, let stroke, _, _, _) = sparkline else {
            Issue.record("expected sparkline")
            return
        }
        #expect(values.count == 60)
        #expect(values[0] == 120)
        #expect(values[2] == 152)
        #expect(stroke == OverlayColor(red: 1, green: 77.0 / 255, blue: 79.0 / 255, alpha: 1))
    }

    @Test func conditionAndParameterOverridesChangeOutput() throws {
        let package = try OverlayComponentLoader.load(data: try fixtureData("hr-pill"))
        let data = OverlayComponentStubData(
            signals: ["activity.heartRate": .number(120)],
            seriesValues: ["activity.heartRate": [.number(120)]]
        )

        let hidden = OverlayComponentResolver(definition: package.definition)
            .resolve(parameters: ["showTrend": .boolean(false)], data: data)
        #expect(!flatten(hidden.nodes).contains { node in
            if case .sparkline = node { return true }
            return false
        })

        let accent = OverlayColor(red: 0.2, green: 1, blue: 0.4, alpha: 1)
        let recolored = OverlayComponentResolver(definition: package.definition)
            .resolve(parameters: ["accent": .string("#33FF66")], data: data)
        let sparkline = try #require(flatten(recolored.nodes).first { node in
            if case .sparkline = node { return true }
            return false
        })
        guard case .sparkline(_, _, let stroke, _, _, _) = sparkline else {
            Issue.record("expected sparkline")
            return
        }
        #expect(stroke == accent)
    }

    @Test func repeatExpandsLapRowsAndResolvesRelativeFrames() throws {
        let package = try OverlayComponentLoader.load(data: try fixtureData("lap-splits"))
        let laps: [OverlayComponentValue] = (1...3).map { index in
            .record([
                "index": .number(Double(index)),
                "avgPace": .number(300),
                "avgHeartRate": .number(150)
            ])
        }
        let data = OverlayComponentStubData(lists: ["structure.laps": laps])

        let resolved = OverlayComponentResolver(definition: package.definition)
            .resolve(parameters: ["maxRows": .number(2)], data: data)

        #expect(resolved.diagnostics.isEmpty)
        let group = try #require(resolved.nodes.last)
        guard case .group(let frame, _, _, _, let children) = group else {
            Issue.record("expected repeat group")
            return
        }
        #expect(frame == CGRect(x: 16, y: 44, width: 288, height: 168))
        #expect(children.count == 9)
        #expect(textNodes(resolved).filter { $0.text == "1" }.count == 1)
        #expect(textNodes(resolved).filter { $0.text == "2" }.count == 1)
        #expect(textNodes(resolved).filter { $0.text == "150" }.count == 2)
    }

    @Test func unknownParametersProduceDiagnosticsButStillResolve() throws {
        let package = try OverlayComponentLoader.load(data: try fixtureData("hr-pill"))
        let resolved = OverlayComponentResolver(definition: package.definition)
            .resolve(
                parameters: ["legacyParam": .number(1)],
                data: OverlayComponentStubData(signals: ["activity.heartRate": .number(90)])
            )

        #expect(resolved.diagnostics.contains { $0.contains("unknown parameter") })
        #expect(!resolved.nodes.isEmpty)
    }

    @Test func opacityAndFrameExpressionsResolve() throws {
        let json = """
        {
          "spec": "ros.component/0.1",
          "id": "community.test.opacity",
          "version": "1.0.0",
          "name": "Opacity",
          "license": "MIT",
          "size": [100, 100],
          "params": [
            { "id": "level", "type": "number", "label": "Level", "min": 0, "max": 1, "default": 0.5 }
          ],
          "nodes": [
            { "type": "rect", "frame": [0, 0, "=width", "=height"], "fill": "#112233FF", "opacity": "=level" }
          ]
        }
        """
        let package = try OverlayComponentLoader.load(data: try #require(json.data(using: .utf8)))
        let resolved = OverlayComponentResolver(definition: package.definition)
            .resolve(parameters: ["level": .number(0.25)], data: OverlayComponentStubData())

        guard case .opacity(let opacity, let content)? = resolved.nodes.first,
              case .rect(let frame, _, _, _, _) = content else {
            Issue.record("expected opacity-wrapped rect")
            return
        }
        #expect(abs(opacity - 0.25) < 0.001)
        #expect(frame == CGRect(x: 0, y: 0, width: 100, height: 100))
    }
}
