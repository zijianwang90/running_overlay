import Foundation
import Testing
@testable import RunningOverlay

@MainActor
struct ProjectWeatherCacheTests {
    private static func activity() -> ActivityTimeline {
        let start = Date(timeIntervalSince1970: 1_735_689_600)
        return ActivityTimeline(
            startDate: start, duration: 600, distanceMeters: 1920,
            records: [
                ActivityRecord(
                    elapsedTime: 0, timestamp: start, distanceMeters: 0,
                    heartRate: 140, paceSecondsPerKilometer: 320,
                    elevationMeters: 20, cadence: 170, powerWatts: 240,
                    calories: 0, temperatureCelsius: 17
                )
            ],
            laps: []
        )
    }

    private static func payload(for activity: ActivityTimeline, location: String = "Osaka, Japan") -> WeatherPayload {
        WeatherPayload(
            condition: .partlyCloudy,
            temperatureCelsius: 18,
            humidity: 52,
            highTemperatureCelsius: 21,
            lowTemperatureCelsius: 12,
            windKph: 14,
            feelsLikeCelsius: 17,
            resolvedLocation: location,
            sourceDate: activity.startDate,
            fetchLocationMode: .activityLocation
        )
    }

    private static func weatherReference() throws -> OverlayComponentReference {
        let item = try #require(OverlayComponentLibraryItem.chartComponents.first {
            $0.resourceName == "weather-widget"
        })
        let data = try #require(OverlayComponentLibrary.data(for: item))
        return try OverlayComponentReference(definitionData: data, source: .bundled)
    }

    @Test func snapshotRoundTripsWeatherCache() throws {
        let activity = Self.activity()
        let cache = ProjectWeatherCache(
            payload: Self.payload(for: activity),
            dataSource: .openMeteo,
            fetchedAt: Date(timeIntervalSince1970: 1_735_700_000)
        )
        let snapshot = ProjectPerformanceSnapshot(
            settings: ProjectSettings(),
            activity: activity,
            mediaItems: [],
            mediaFolders: [],
            timeline: .empty,
            overlayElements: OverlayTemplateElementList([]),
            userAssets: [],
            fitSourceName: "",
            workoutStructureSelection: nil,
            weatherCache: cache
        )
        let decoded = try ProjectFileFormat.decode(ProjectFileFormat.encode(snapshot))
        #expect(decoded.weatherCache == cache)

        var legacy = try JSONSerialization.jsonObject(
            with: ProjectFileFormat.encode(snapshot)
        ) as? [String: Any]
        legacy?.removeValue(forKey: "weatherCache")
        let legacyData = try JSONSerialization.data(withJSONObject: try #require(legacy))
        let legacyDecoded = try ProjectFileFormat.decode(legacyData)
        #expect(legacyDecoded.weatherCache == nil)
    }

    @Test func projectCacheFeedsHostWeatherAndUndoes() throws {
        let project = ProjectDocument()
        let activity = Self.activity()
        project.activity = activity
        let reference = try Self.weatherReference()
        project.addComponentElement(reference: reference)
        #expect(project.weatherPayloadForComponents == nil)

        let payload = Self.payload(for: activity)
        project.applyFetchedProjectWeather(payload, dataSource: .openMeteo)
        #expect(project.weatherPayloadForComponents == payload)
        #expect(project.weatherCache?.dataSource == .openMeteo)

        project.undo()
        #expect(project.weatherPayloadForComponents == nil)
    }

    @Test func cacheFromAnotherActivityIsIgnored() throws {
        let project = ProjectDocument()
        let activity = Self.activity()
        project.activity = activity
        var stale = Self.payload(for: activity)
        stale.sourceDate = activity.startDate.addingTimeInterval(86_400)
        project.weatherCache = ProjectWeatherCache(
            payload: stale, dataSource: .openWeather, fetchedAt: Date()
        )
        #expect(project.weatherPayloadForComponents == nil)
    }

    @Test func componentWeatherSourceReadsParameter() throws {
        let reference = try Self.weatherReference()
        let instance = OverlayComponentInstance(
            reference: reference, parameters: ["dataSource": .string("openWeather")]
        )
        #expect(ProjectDocument.componentWeatherSource(instance) == .openWeather)

        let manual = OverlayComponentInstance(
            reference: reference, parameters: ["dataSource": .string("manual")]
        )
        #expect(ProjectDocument.componentWeatherSource(manual) == .manual)

        let missing = OverlayComponentInstance(reference: reference)
        #expect(ProjectDocument.componentWeatherSource(missing) == .openMeteo)
    }

    @Test func weatherDefinitionDeclaresCapability() throws {
        let reference = try Self.weatherReference()
        let definition = try #require(OverlayComponentRegistry.definition(for: reference))
        #expect(definition.usesHostWeather)
        #expect(definition.parameter(named: "dataSource") != nil)

        let element = OverlayElement(
            type: .component,
            position: .zero,
            scale: 1,
            style: .default,
            component: OverlayComponentInstance(reference: reference)
        )
        #expect(element.componentUsesHostWeather)
    }
}
