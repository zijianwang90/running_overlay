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
            case .group(_, _, _, _, _, let children):
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
            guard case .text(let frame, let text, _, let color, _, _, _, _, _, _) = node else {
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
        guard case .group(let frame, _, _, _, _, let children) = group else {
            Issue.record("expected repeat group")
            return
        }
        #expect(frame == CGRect(x: 16, y: 44, width: 288, height: 168))
        #expect(children.count == 9)
        guard case .rect(let firstRow, _, _, _, _) = children.first else {
            Issue.record("Expected a first-row background")
            return
        }
        #expect(firstRow.minX == 16)
        #expect(firstRow.minY == 44)
        #expect(textNodes(resolved).filter { $0.text == "1" }.count == 1)
        #expect(textNodes(resolved).filter { $0.text == "2" }.count == 1)
        #expect(textNodes(resolved).filter { $0.text == "150" }.count == 2)
    }

    @Test func textTrackingResolvesAndDefaultsToZero() throws {
        let json = """
        {
          "spec": "ros.component/0.1",
          "id": "community.test.tracking",
          "version": "1.0.0",
          "name": "Tracking",
          "license": "MIT",
          "size": [200, 80],
          "nodes": [
            {
              "type": "text", "frame": [0, 0, 100, 30], "text": "tight",
              "font": { "family": "Helvetica Neue", "size": 20, "weight": "semibold" },
              "color": "#FFFFFF", "tracking": -2.5
            },
            {
              "type": "text", "frame": [0, 40, 100, 30], "text": "default",
              "font": { "family": "Helvetica Neue", "size": 20 },
              "color": "#FFFFFF"
            }
          ]
        }
        """
        let package = try OverlayComponentLoader.load(data: try #require(json.data(using: .utf8)))
        let resolved = OverlayComponentResolver(definition: package.definition)
            .resolve(parameters: [:], data: OverlayComponentStubData())

        var trackingByText: [String: Double] = [:]
        for node in flatten(resolved.nodes) {
            guard case .text(_, let text, _, _, _, _, _, _, let tracking, _) = node else {
                continue
            }
            trackingByText[text] = tracking
        }
        #expect(trackingByText["tight"] == -2.5)
        #expect(trackingByText["default"] == 0)
    }

    @Test func columnsAutoSizedTextRowsAndPinnedSpacersResolve() throws {
        let json = """
        {
          "spec": "ros.component/0.1",
          "id": "community.test.columns",
          "version": "1.0.0",
          "name": "Columns",
          "license": "MIT",
          "size": [300, 200],
          "bindings": { "hostInfo": { "signal": "host" } },
          "nodes": [
            {
              "type": "stack",
              "children": [
                {
                  "type": "textRows", "maxWidth": 120,
                  "rows": [{ "runs": [{
                    "text": "A", "font": { "family": "Helvetica Neue", "size": 12 },
                    "color": "#FFFFFF", "opacity": 0.6
                  }] }]
                },
                { "type": "spacer", "min": "=10 / hostInfo.scale" },
                {
                  "type": "columns", "width": "=width - 20",
                  "divider": { "width": 2, "color": "#FFFFFF", "height": 30 },
                  "children": [
                    {
                      "type": "textRows", "maxWidth": 80,
                      "rows": [{ "runs": [{
                        "text": "1", "font": { "family": "Helvetica Neue", "size": 12 },
                        "color": "#FFFFFF"
                      }] }]
                    }
                  ]
                }
              ]
            }
          ]
        }
        """
        let package = try OverlayComponentLoader.load(data: try #require(json.data(using: .utf8)))
        let data = OverlayComponentStubData(signals: ["host": .record(["scale": .number(2)])])
        let resolved = OverlayComponentResolver(definition: package.definition)
            .resolve(parameters: [:], data: data)
        #expect(resolved.diagnostics.isEmpty)

        guard case .stack(_, _, _, _, let children) = try #require(resolved.nodes.first) else {
            Issue.record("expected stack")
            return
        }
        #expect(children.count == 3)
        guard case .textRows(let frame, let rows, let autoSize) = children[0].node else {
            Issue.record("expected auto-sized textRows")
            return
        }
        #expect(autoSize)
        #expect(frame.height == 0)
        #expect(rows.maxWidth == 120)
        #expect(rows.rows[0].runs[0].opacity == 0.6)
        guard case .spacer(let length, let minimum) = children[1].node else {
            Issue.record("expected pinned spacer")
            return
        }
        #expect(length == nil)
        #expect(minimum == 5)
        guard case .columns(let width, let divider, let columns) = children[2].node else {
            Issue.record("expected columns")
            return
        }
        #expect(width == 280)
        #expect(divider?.width == 2)
        #expect(divider?.height == 30)
        #expect(columns.count == 1)
        guard case .textRows(_, let columnRows, _) = columns[0] else {
            Issue.record("expected column textRows")
            return
        }
        #expect(columnRows.maxWidth == 80)
    }

    @Test func stackResolvesChildrenAndMarksAutoSizedText() throws {
        let json = """
        {
          "spec": "ros.component/0.1",
          "id": "community.test.stack",
          "version": "1.0.0",
          "name": "Stack",
          "license": "MIT",
          "size": [200, 100],
          "params": [
            { "id": "gap", "type": "number", "label": "Gap", "min": 0, "max": 20, "default": 4 }
          ],
          "nodes": [
            {
              "type": "stack",
              "direction": "horizontal",
              "spacing": "=gap",
              "crossAlign": "center",
              "children": [
                {
                  "type": "text", "text": "130",
                  "font": { "family": "Helvetica Neue", "size": 28, "weight": "semibold" },
                  "color": "#FFFFFF"
                },
                { "type": "rect", "frame": [0, 0, 20, 4], "fill": "#FFFFFF" }
              ]
            }
          ]
        }
        """
        let package = try OverlayComponentLoader.load(data: try #require(json.data(using: .utf8)))
        let resolved = OverlayComponentResolver(definition: package.definition)
            .resolve(parameters: ["gap": .number(6)], data: OverlayComponentStubData())

        #expect(resolved.diagnostics.isEmpty)
        let stack = try #require(resolved.nodes.first)
        guard case .stack(let frame, let direction, let spacing, let crossAlign, let children) = stack else {
            Issue.record("expected stack")
            return
        }
        #expect(frame == nil)
        #expect(direction == .horizontal)
        #expect(spacing == 6)
        #expect(crossAlign == .center)
        #expect(children.count == 2)
        guard case .text(let textFrame, _, _, _, _, _, _, _, _, let autoSize) = children[0].node else {
            Issue.record("expected auto-sized text")
            return
        }
        #expect(autoSize)
        #expect(textFrame == .zero)
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

    @Test func symbolNameResolvesFromExpressionAndInvalidNamesAreDropped() throws {
        let json = """
        {
          "spec": "ros.component/0.1",
          "id": "community.test.symbol",
          "version": "1.0.0",
          "name": "Symbol",
          "license": "MIT",
          "size": [100, 100],
          "params": [
            { "id": "icon", "type": "string", "label": "Icon", "default": "heart.fill" }
          ],
          "nodes": [
            { "type": "symbol", "name": "=icon", "frame": [0, 0, 22, 22], "color": "#FF0000", "weight": "bold" }
          ]
        }
        """
        let package = try OverlayComponentLoader.load(data: try #require(json.data(using: .utf8)))
        let resolver = OverlayComponentResolver(definition: package.definition)

        let resolved = resolver.resolve(parameters: [:], data: OverlayComponentStubData())
        guard case .symbol(let frame, let name, _, let weight, _, _)? = resolved.nodes.first else {
            Issue.record("expected symbol")
            return
        }
        #expect(frame == CGRect(x: 0, y: 0, width: 22, height: 22))
        #expect(name == "heart.fill")
        #expect(weight == .bold)

        let invalid = resolver.resolve(
            parameters: ["icon": .string("../etc/passwd")],
            data: OverlayComponentStubData()
        )
        #expect(invalid.nodes.isEmpty)
        #expect(invalid.diagnostics.contains { $0.contains("symbol name") })
    }

    @Test func stackChildrenKeepAlignSelfAfterConditionalChildIsSkipped() throws {
        let json = """
        {
          "spec": "ros.component/0.1",
          "id": "community.test.align-self",
          "version": "1.0.0",
          "name": "Align Self",
          "license": "MIT",
          "size": [100, 100],
          "params": [
            { "id": "showFirst", "type": "bool", "label": "Show", "default": false }
          ],
          "nodes": [
            {
              "type": "stack", "direction": "vertical",
              "children": [
                { "type": "rect", "frame": [0, 0, 10, 10], "fill": "#FFFFFF", "if": "=showFirst", "alignSelf": "end" },
                { "type": "rect", "frame": [0, 0, 20, 10], "fill": "#FFFFFF", "alignSelf": "center" },
                { "type": "rect", "frame": [0, 0, 30, 10], "fill": "#FFFFFF" }
              ]
            }
          ]
        }
        """
        let package = try OverlayComponentLoader.load(data: try #require(json.data(using: .utf8)))
        let resolved = OverlayComponentResolver(definition: package.definition)
            .resolve(parameters: [:], data: OverlayComponentStubData())
        guard case .stack(_, _, _, _, let children)? = resolved.nodes.first else {
            Issue.record("expected stack")
            return
        }
        #expect(children.map(\.alignSelf) == [.center, nil])
    }

    @Test func contentLayoutResolvesExpressionsAndClampsNegativeValues() throws {
        let json = """
        {
          "spec": "ros.component/0.1",
          "id": "community.test.content",
          "version": "1.0.0",
          "name": "Content",
          "license": "MIT",
          "size": "content",
          "padding": ["=showBackground ? 10 : 0", -4],
          "minSize": ["=minWidth", 0],
          "params": [
            { "id": "showBackground", "type": "bool", "label": "Background", "default": true },
            { "id": "minWidth", "type": "number", "label": "Min", "min": 0, "max": 400, "default": 120 }
          ],
          "nodes": [
            { "type": "text", "text": "A", "font": { "family": "system", "size": 12 }, "color": "#FFFFFF" }
          ]
        }
        """
        let package = try OverlayComponentLoader.load(data: try #require(json.data(using: .utf8)))
        let resolver = OverlayComponentResolver(definition: package.definition)

        let resolved = resolver.resolve(parameters: [:], data: OverlayComponentStubData())
        #expect(resolved.contentLayout == OverlayComponentResolvedContentLayout(
            paddingX: 10,
            paddingY: 0,
            minWidth: 120,
            minHeight: 0
        ))
        let withoutBackground = resolver.resolve(
            parameters: ["showBackground": .boolean(false)],
            data: OverlayComponentStubData()
        )
        #expect(withoutBackground.contentLayout?.paddingX == 0)
    }

    @Test func invalidEnumExpressionsFallBackWithDiagnostics() throws {
        let json = """
        {
          "spec": "ros.component/0.1",
          "id": "community.test.enum-expr",
          "version": "1.0.0",
          "name": "Enum Expressions",
          "license": "MIT",
          "size": [100, 100],
          "params": [
            { "id": "dir", "type": "string", "label": "Direction", "default": "diagonal" },
            { "id": "weight", "type": "string", "label": "Weight", "default": "heavy" }
          ],
          "nodes": [
            {
              "type": "stack", "direction": "=dir", "crossAlign": "=dir",
              "children": [
                { "type": "spacer", "length": -3 },
                {
                  "type": "text", "text": "A", "alignSelf": "=dir",
                  "font": { "family": "=\\"\\"", "size": 12, "weight": "=weight" }, "color": "#FFFFFF"
                }
              ]
            }
          ]
        }
        """
        let package = try OverlayComponentLoader.load(data: try #require(json.data(using: .utf8)))
        let resolver = OverlayComponentResolver(definition: package.definition)
        let resolved = resolver.resolve(parameters: [:], data: OverlayComponentStubData())
        guard case .stack(_, let direction, _, let crossAlign, let children)? = resolved.nodes.first else {
            Issue.record("expected stack")
            return
        }
        #expect(direction == .horizontal)
        #expect(crossAlign == .start)
        #expect(children[0].node == .spacer(length: 0, minimum: 0))
        #expect(children[1].alignSelf == .start)
        guard case .text(_, _, let font, _, _, _, _, _, _, _) = children[1].node else {
            Issue.record("expected text")
            return
        }
        #expect(font.family == "system")
        #expect(font.weight == .heavy)
        #expect(resolved.diagnostics.filter { $0.contains("not a valid value") }.count == 3)

        let invalidWeight = resolver.resolve(parameters: ["weight": .string("wide")], data: OverlayComponentStubData())
        #expect(invalidWeight.diagnostics.contains { $0.contains("font weight 'wide'") })
    }

    @Test func everyNumericPresetResolvesWithoutDiagnostics() throws {
        // No samples: every metric formats its placeholder, which still has to
        // resolve cleanly (the icon comes from the metric, not the data).
        let emptyActivity = OverlayComponentActivityData(
            activity: ActivityTimeline(
                startDate: Date(timeIntervalSince1970: 0),
                duration: 0,
                distanceMeters: 0,
                records: [],
                laps: []
            ),
            elapsedTime: 0,
            zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720),
            elementScale: 1
        )
        for item in OverlayComponentLibraryItem.numericPresets {
            let data = try #require(OverlayComponentLibrary.data(for: item))
            let package = try OverlayComponentLoader.load(data: data)
            let parameters = item.parameters.mapValues { value -> OverlayComponentValue in
                if case .string(let string) = value { return .string(string) }
                return .null
            }
            for extra in [[:], ["showLabel": OverlayComponentValue.boolean(true), "labelPosition": .string("trailing")]] {
                let resolved = OverlayComponentResolver(definition: package.definition)
                    .resolve(parameters: parameters.merging(extra) { $1 }, data: emptyActivity)
                #expect(resolved.diagnostics.isEmpty, "\(item.id): \(resolved.diagnostics)")
                #expect(!resolved.nodes.isEmpty, "\(item.id)")
            }
        }
    }
}

extension OverlayComponentResolverTests {
    @Test func segmentedBarResolvesComputedBindingsSegmentsAndMarkers() throws {
        let json = """
        {
          "spec": "ros.component/0.1",
          "id": "community.test.segmented",
          "version": "1.0.0",
          "name": "Segmented",
          "license": "MIT",
          "size": [200, 40],
          "bindings": {
            "zones": { "list": "zone.heartRateZones" },
            "zoneCount": { "value": "=count(zones)" },
            "active": { "value": "=zoneCount - 1" }
          },
          "params": [
            { "id": "isBelow", "type": "bool", "label": "Below", "default": true }
          ],
          "nodes": [{
            "type": "segmentedBar", "frame": [0, 0, 200, 10],
            "segments": "=zones", "activeIndex": "=active",
            "activeWidthShare": 0.25, "activeThicknessScale": 1.5,
            "gap": 2, "radius": 6, "inactiveOpacity": 0.4,
            "glow": { "opacity": 0.5, "sigma": 8 },
            "border": { "color": "#FFFFFF", "opacity": 0.3, "width": 1 },
            "markers": [
              {
                "role": "current", "index": "=active", "fraction": 0.5,
                "text": "=format(active)", "color": "#FFFFFF",
                "position": "=isBelow ? \\"below\\" : \\"above\\"", "showsValue": 0,
                "font": { "family": "Menlo", "size": 9 }
              },
              {
                "role": "threshold", "index": 2, "fraction": 0.75, "text": "T",
                "color": "#FF0000", "font": { "family": "Menlo", "size": 9 }
              }
            ]
          }]
        }
        """
        let package = try OverlayComponentLoader.load(data: try #require(json.data(using: .utf8)))
        let red = OverlayColor(red: 1, green: 0.2, blue: 0.2, alpha: 1)
        let blue = OverlayColor(red: 0.2, green: 0.4, blue: 1, alpha: 1)
        let yellow = OverlayColor(red: 1, green: 0.8, blue: 0.2, alpha: 1)
        let stub = OverlayComponentStubData(lists: [
            "zone.heartRateZones": [
                .record(["index": .number(1), "color": .color(red)]),
                .record(["index": .number(2), "color": .color(blue)]),
                .record(["index": .number(3), "color": .color(yellow)])
            ]
        ])
        let resolved = OverlayComponentResolver(definition: package.definition)
            .resolve(parameters: [:], data: stub)
        #expect(resolved.diagnostics.isEmpty)
        guard case .segmentedBar(
            let frame, let vertical, let segments, let activeIndex, let activeWidthShare,
            let activeThicknessScale, let gap, let radius, let inactiveOpacity,
            let glow, let border, let markers
        ) = resolved.nodes.first else {
            Issue.record("expected a segmentedBar")
            return
        }
        #expect(frame == CGRect(x: 0, y: 0, width: 200, height: 10))
        #expect(vertical == false)
        #expect(segments.map(\.index) == [1, 2, 3])
        #expect(segments.map(\.color) == [red, blue, yellow])
        // The computed binding chain resolves lazily: `count(zones)` feeds
        // `active`, which the node then reads.
        #expect(activeIndex == 2)
        #expect(activeWidthShare == 0.25)
        #expect(activeThicknessScale == 1.5)
        #expect(gap == 2)
        #expect(radius == 6)
        #expect(inactiveOpacity == 0.4)
        #expect(glow?.opacity == 0.5)
        #expect(glow?.sigma == 8)
        #expect(border?.color == .white)
        #expect(border?.opacity == 0.3)
        #expect(border?.width == 1)
        #expect(markers.count == 2)
        #expect(markers[0].role == .current)
        #expect(markers[0].index == 2)
        #expect(markers[0].fraction == 0.5)
        #expect(markers[0].text == "2")
        #expect(markers[0].layout == .inline)
        #expect(markers[0].side == .below)
        #expect(markers[0].scale == 1)
        #expect(markers[0].showsValue == false)
        #expect(markers[0].font.size == 9)
        #expect(markers[1].role == .threshold)
        #expect(markers[1].side == .above)
        #expect(markers[1].showsValue == true)
        #expect(markers[1].text == "T")
    }
}
