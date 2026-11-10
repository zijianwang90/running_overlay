import Foundation
import Testing
@testable import RunningOverlay

struct ComponentAuthoringTests {
    private func definition() throws -> OverlayComponentDefinition {
        let item = try #require(OverlayComponentLibraryItem.examples.first)
        let reference = try OverlayComponentLibrary.reference(for: item)
        return try #require(OverlayComponentRegistry.definition(for: reference))
    }

    private func command() -> ComponentRenderCommand {
        ComponentRenderCommand(
            packageURL: URL(fileURLWithPath: "/unused/component.json"),
            outputURL: URL(fileURLWithPath: "/unused/frame.png")
        )
    }

    @Test func parsesActivityTimeAndParameterInputs() throws {
        let parsed = try ComponentCLICommand.parse(arguments: [
            "RunningOverlay", "--component-render", "card.json",
            "--component-output", "card.png", "--component-activity", "run.fit",
            "--component-at", "30.5", "--component-params", "params.json"
        ])
        guard case .render(let command) = parsed else {
            Issue.record("Expected render command")
            return
        }
        #expect(command.elapsedTime == 30.5)
        #expect(command.activityURL?.lastPathComponent == "run.fit")
        #expect(command.parametersURL?.lastPathComponent == "params.json")
        for invalid in ["-1", "nan", "inf", "nope"] {
            #expect(throws: ComponentCLIError.self) {
                _ = try ComponentCLICommand.parse(arguments: [
                    "RunningOverlay", "--component-render", "card.json",
                    "--component-output", "out.png", "--component-at", invalid
                ])
            }
        }
    }

    @Test func parsesWeatherInputForHostDrawnWeather() throws {
        let parsed = try ComponentCLICommand.parse(arguments: [
            "RunningOverlay", "--component-render", "weather.json",
            "--component-output", "weather.png", "--component-weather", "weather-input.json"
        ])
        guard case .render(let renderCommand) = parsed else {
            Issue.record("Expected render command")
            return
        }
        #expect(renderCommand.weatherURL?.lastPathComponent == "weather-input.json")

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("weather.json")
        var withWeather = command()
        withWeather.weatherURL = url
        let definition = try definition()

        try Data(#"""
        {"condition":"rain","temperatureC":8.5,"humidity":94,"highC":11,"lowC":5,
         "windKph":18,"feelsLikeC":4,"location":"Shanghai"}
        """#.utf8).write(to: url)
        let inputs = try ComponentCommandRunner.inputs(for: withWeather, definition: definition)
        #expect(inputs.weather?.condition == .rain)
        #expect(inputs.weather?.temperatureCelsius == 8.5)
        #expect(inputs.weather?.resolvedLocation == "Shanghai")
        #expect(inputs.weather?.sourceDate == nil)

        for invalid in [
            #"{"condition":"hail","temperatureC":8}"#,
            #"{"compiles":true}"#,
            "[]"
        ] {
            try Data(invalid.utf8).write(to: url)
            #expect(throws: ComponentCLIError.self) {
                _ = try ComponentCommandRunner.inputs(for: withWeather, definition: definition)
            }
        }
    }

    @Test func syntheticFixtureSuppliesMetricsSeriesAndLaps() throws {
        var command = command()
        let fixtureURL = try #require(Bundle.module.url(
            forResource: "synthetic-component-run", withExtension: "fit",
            subdirectory: "Fixtures/Activities"
        ))
        command.activityURL = fixtureURL
        let inputs = try ComponentCommandRunner.inputs(for: command, definition: definition())
        #expect(inputs.activity.duration == 60)
        #expect(inputs.activity.records.count == 3)
        #expect(inputs.activity.laps.count == 3)
        let data = OverlayComponentActivityData(
            activity: inputs.activity, elapsedTime: 30,
            canvasSize: CGSize(width: 1280, height: 720), elementScale: 1
        )
        #expect(data.signal(path: "activity.heartRate") == .number(145))
        #expect(data.list(path: "structure.laps").list?.count == 3)
        #expect(data.series(path: "activity.heartRate", window: .full, samples: 3).list?.count == 3)
    }

    @Test func authorParametersRejectTyposAndInvalidValues() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("params.json")
        var command = command()
        command.parametersURL = url
        let definition = try definition()
        for json in [
            #"{"unknown": 1}"#, #"{"showTrend": "true"}"#,
            #"{"radius": -1}"#, #"{"radius": 37}"#, #"{"accent": "broken"}"#,
            #"{"radius": null}"#, "[]"
        ] {
            try Data(json.utf8).write(to: url)
            #expect(throws: ComponentCLIError.self) {
                _ = try ComponentCommandRunner.inputs(for: command, definition: definition)
            }
        }
        try Data(##"{"accent":"#22CCFF", "radius":12, "showTrend":false}"##.utf8).write(to: url)
        let inputs = try ComponentCommandRunner.inputs(for: command, definition: definition)
        #expect(inputs.parameters["radius"] == .number(12))
        #expect(inputs.parameters["showTrend"] == .boolean(false))
        #expect(inputs.activity.records.isEmpty)
    }
}

#if canImport(CSkiaBridge)
@Suite(.serialized, .skiaSerialized)
struct ComponentAuthoringRenderTests {
    @MainActor
    @Test func CLIUsesActivityTimeAndParametersInPixels() throws {
        let package = try #require(Bundle.module.url(
            forResource: "hr-pill", withExtension: "json", subdirectory: "Fixtures/Components"
        ))
        let fixture = try #require(Bundle.module.url(
            forResource: "synthetic-component-run", withExtension: "fit", subdirectory: "Fixtures/Activities"
        ))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appendingPathComponent("frame.png")
        let parameters = directory.appendingPathComponent("params.json")
        var command = ComponentRenderCommand(packageURL: package, outputURL: output)
        _ = try ComponentCommandRunner.renderComponent(command)
        let empty = try Data(contentsOf: output)
        command.activityURL = fixture
        command.elapsedTime = 30
        _ = try ComponentCommandRunner.renderComponent(command)
        let middle = try Data(contentsOf: output)
        #expect(middle != empty)
        command.elapsedTime = 60
        _ = try ComponentCommandRunner.renderComponent(command)
        let end = try Data(contentsOf: output)
        #expect(end != middle)
        command.elapsedTime = 600
        _ = try ComponentCommandRunner.renderComponent(command)
        #expect(try Data(contentsOf: output) == end)
        try Data(##"{"showTrend":false,"accent":"#00FF00"}"##.utf8).write(to: parameters)
        command.parametersURL = parameters
        _ = try ComponentCommandRunner.renderComponent(command)
        #expect(try Data(contentsOf: output) != end)
    }

    /// The render context, not the element style, carries authored weather.
    /// This pins the plumbing the app uses for host-drawn weather components.
    @MainActor
    @Test func CLIWeatherInputChangesWeatherNodePixels() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let package = directory.appendingPathComponent("weather.json")
        let weather = directory.appendingPathComponent("weather-input.json")
        let output = directory.appendingPathComponent("weather.png")
        try Data(#"""
        {
          "spec": "ros.component/0.1",
          "id": "tests.weather-node",
          "version": "1.0.0",
          "name": "Weather Node",
          "license": "MIT",
          "size": [300, 110],
          "nodes": [
            { "type": "weatherWidget", "frame": [0, 0, 300, 110], "dataSource": "openMeteo" }
          ]
        }
        """#.utf8).write(to: package)
        try Data(#"""
        {"condition":"rain","temperatureC":7,"humidity":93,"highC":10,"lowC":4,
         "windKph":22,"feelsLikeC":3,"location":"Shanghai"}
        """#.utf8).write(to: weather)

        var command = ComponentRenderCommand(packageURL: package, outputURL: output)
        _ = try ComponentCommandRunner.renderComponent(command)
        let manual = try Data(contentsOf: output)
        command.weatherURL = weather
        _ = try ComponentCommandRunner.renderComponent(command)
        let snapshot = try Data(contentsOf: output)
        #expect(snapshot != manual)
    }
}
#endif
