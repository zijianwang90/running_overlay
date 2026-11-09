import Foundation
import Testing
@testable import RunningOverlay

struct OverlayComponentStatsBarTests {
    static func data() throws -> Data {
        let item = try #require(OverlayComponentLibraryItem.chartComponents.first {
            $0.resourceName == "stats-bar"
        })
        return try #require(OverlayComponentLibrary.data(for: item))
    }

    static func activity() -> ActivityTimeline {
        let start = Date(timeIntervalSince1970: 1_735_689_600)
        var records: [ActivityRecord] = []
        var t: TimeInterval = 0
        while t <= 600 {
            records.append(ActivityRecord(
                elapsedTime: t, timestamp: start.addingTimeInterval(t),
                distanceMeters: t * 3.2, heartRate: 148 + Int(t / 120),
                paceSecondsPerKilometer: 312, elevationMeters: 20 + sin(t / 90) * 6,
                cadence: 176, powerWatts: 245, calories: t / 4
            ))
            t += 1
        }
        return ActivityTimeline(
            startDate: start, duration: 600, distanceMeters: 1920,
            records: records, laps: []
        )
    }

    static func resolve(
        parameters: [String: OverlayComponentValue] = [:]
    ) throws -> [OverlayComponentResolvedNode] {
        let package = try OverlayComponentLoader.load(data: data())
        let data = OverlayComponentActivityData(
            activity: activity(), elapsedTime: 300, zoneSnapshot: nil,
            canvasSize: CGSize(width: 1280, height: 720), elementScale: 1
        )
        let result = OverlayComponentResolver(definition: package.definition)
            .resolve(parameters: parameters, data: data)
        #expect(result.diagnostics.isEmpty, "\(result.diagnostics)")
        return result.nodes
    }

    static func columns(in nodes: [OverlayComponentResolvedNode]) -> [OverlayComponentResolvedNode]? {
        for node in nodes {
            switch node {
            case let .columns(_, _, children):
                return children
            case let .group(_, _, _, _, _, children):
                if let found = columns(in: children) { return found }
            case let .opacity(_, content):
                if let found = columns(in: [content]) { return found }
            case let .stack(_, _, _, _, children):
                if let found = columns(in: children.map(\.node)) { return found }
            default:
                continue
            }
        }
        return nil
    }

    static func textRows(in nodes: [OverlayComponentResolvedNode]) -> [OverlayComponentResolvedTextRows] {
        var result: [OverlayComponentResolvedTextRows] = []
        for node in nodes {
            switch node {
            case let .textRows(_, text, _):
                result.append(text)
            case let .group(_, _, _, _, _, children):
                result.append(contentsOf: textRows(in: children))
            case let .opacity(_, content):
                result.append(contentsOf: textRows(in: [content]))
            case let .stack(_, _, _, _, children):
                result.append(contentsOf: textRows(in: children.map(\.node)))
            case let .columns(_, _, children):
                result.append(contentsOf: textRows(in: children))
            default:
                continue
            }
        }
        return result
    }

    @Test func bundledDefinitionResolves() throws {
        let package = try OverlayComponentLoader.load(data: Self.data())
        #expect(package.definition.id == "studio.stats-bar")
        let ids = Set(package.definition.params.map(\.id))
        #expect(ids.contains("slot1Metric"))
        #expect(ids.contains("slot4Metric"))
        #expect(!ids.contains("statsBar"))
        let nodes = try Self.resolve()
        #expect(!nodes.isEmpty)
    }

    @Test func defaultSlotsRenderThreeCells() throws {
        let cells = try #require(Self.columns(in: try Self.resolve()))
        #expect(cells.count == 3)
    }

    @Test func noneMetricHidesItsCell() throws {
        let cells = try #require(Self.columns(in: try Self.resolve(parameters: [
            "slot2Metric": .string("none")
        ])))
        #expect(cells.count == 2)
    }

    @Test func allEmptySlotsRenderNoCells() throws {
        let cells = Self.columns(in: try Self.resolve(parameters: [
            "slot1Metric": .string("none"),
            "slot2Metric": .string("none"),
            "slot3Metric": .string("none"),
            "slot4Metric": .string("none")
        ]))
        #expect(cells?.isEmpty ?? false)
    }

    @Test func customLabelOverridesShortLabel() throws {
        let cells = try #require(Self.columns(in: try Self.resolve(parameters: [
            "slot1Label": .string("KM DONE")
        ])))
        let labels = Self.textRows(in: cells)
            .compactMap { $0.rows.last?.runs.first?.text }
        #expect(labels.first == "KM DONE")
    }

    @Test func imperialUnitsFormatDistanceInMiles() throws {
        let cells = try #require(Self.columns(in: try Self.resolve(parameters: [
            "unitSystem": .string("imperial")
        ])))
        let runs = Self.textRows(in: cells).flatMap { $0.rows[0].runs }
        #expect(runs.contains { $0.text == "mi" })
    }

    @Test func chartComponentsNoLongerDeclareAttachedStatsBars() throws {
        for resource in ["distance-timeline", "elevation-chart", "route-map"] {
            let item = try #require(OverlayComponentLibraryItem.chartComponents.first {
                $0.resourceName == resource
            })
            let data = try #require(OverlayComponentLibrary.data(for: item))
            let package = try OverlayComponentLoader.load(data: data)
            #expect(!package.definition.params.contains { $0.id == "statsBar" })
        }
    }

    @Test func resolverKeepsPresetStatsBarsHidden() throws {
        func styleNodes(_ resource: String) throws -> [OverlayComponentResolvedNode] {
            let item = try #require(OverlayComponentLibraryItem.chartComponents.first {
                $0.resourceName == resource
            })
            let data = try #require(OverlayComponentLibrary.data(for: item))
            let package = try OverlayComponentLoader.load(data: data)
            let dataContext = OverlayComponentActivityData(
                activity: Self.activity(), elapsedTime: 300, zoneSnapshot: nil,
                canvasSize: CGSize(width: 1280, height: 720), elementScale: 1
            )
            let result = OverlayComponentResolver(definition: package.definition)
                .resolve(parameters: [:], data: dataContext)
            #expect(result.diagnostics.isEmpty, "\(result.diagnostics)")
            return result.nodes
        }

        let elevation = try styleNodes("elevation-chart")
        let elevationStyle = try #require(elevation.compactMap { node -> ElevationChartStyle? in
            guard case let .elevationChart(_, style, _, _, _) = node else { return nil }
            return style
        }.first)
        #expect(!elevationStyle.statsBar.visible)

        let timeline = try styleNodes("distance-timeline")
        let timelineStyle = try #require(timeline.compactMap { node -> DistanceTimelineStyle? in
            guard case let .distanceTimeline(_, style, _) = node else { return nil }
            return style
        }.first)
        #expect(!timelineStyle.statsBar.visible)

        let route = try styleNodes("route-map")
        let routeStyle = try #require(route.compactMap { node -> OverlayStyle? in
            guard case let .routeMap(_, style) = node else { return nil }
            return style
        }.first)
        #expect(!routeStyle.routeMapStatsBar.visible)
    }
}
