import Foundation
import Testing
@testable import RunningOverlay

struct WeatherFetcherTests {
    @Test func archiveURLUsesOpenMeteoHistoricalHourlyFields() throws {
        let date = Date(timeIntervalSince1970: 1_776_000_000)
        let url = try WeatherFetcher.archiveURL(latitude: 34.6937, longitude: 135.5023, date: date)
        let text = url.absoluteString

        #expect(text.contains("archive-api.open-meteo.com/v1/archive"))
        #expect(text.contains("latitude=34.69370"))
        #expect(text.contains("longitude=135.50230"))
        #expect(text.contains("hourly=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m"))
        #expect(text.contains("timezone=auto"))
    }

    @Test func openWeatherTimelineURLUsesTimestampMetricUnitsAndAPIKey() throws {
        let date = Date(timeIntervalSince1970: 1_776_000_000)
        let url = try WeatherFetcher.openWeatherTimelineURL(
            latitude: 34.6937,
            longitude: 135.5023,
            date: date,
            apiKey: "abc123"
        )
        let text = url.absoluteString

        #expect(text.contains("api.openweathermap.org/data/4.0/onecall/timeline/1h"))
        #expect(text.contains("lat=34.69370"))
        #expect(text.contains("lon=135.50230"))
        #expect(text.contains("start=1776000000"))
        #expect(text.contains("cnt=1"))
        #expect(text.contains("appid=abc123"))
        #expect(text.contains("units=metric"))
    }

    @Test func openWeatherURLRequiresAPIKey() throws {
        #expect(throws: WeatherFetchError.missingOpenWeatherAPIKey) {
            _ = try WeatherFetcher.openWeatherTimelineURL(
                latitude: 34.6937,
                longitude: 135.5023,
                date: Date(timeIntervalSince1970: 1_776_000_000),
                apiKey: " "
            )
        }
    }

    @Test func openWeather401ExplainsSubscriptionAndFallback() {
        let error = WeatherFetcher.openWeatherHTTPError(statusCode: 401)
        let message = error.errorDescription ?? ""

        #expect(error == .openWeatherUnauthorized)
        #expect(message.contains("may still be activating"))
        #expect(message.contains("One Call 4.0"))
        #expect(message.contains("1,000 calls per day are free"))
        #expect(message.contains("Open-Meteo API"))
        #expect(WeatherFetcher.openWeatherHTTPError(statusCode: 429) == .invalidHTTPStatus(429))
    }

    @Test func payloadParsesClosestHourAndDailyTemperatureRange() throws {
        let response = OpenMeteoArchiveResponse(
            hourly: .init(
                time: ["2026-04-10T07:00", "2026-04-10T08:00", "2026-04-10T09:00"],
                temperature2m: [11, 13, 16],
                relativeHumidity2m: [91, 87, 80],
                apparentTemperature: [10, 12, 15],
                weatherCode: [3, 61, 1],
                windSpeed10m: [8, 12, 10]
            )
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let targetDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 8)))

        let payload = try WeatherFetcher.payload(from: response, targetDate: targetDate, resolvedLocation: "Osaka, Japan")

        #expect(payload.condition == .rain)
        #expect(payload.temperatureCelsius == 13)
        #expect(payload.humidity == 87)
        #expect(payload.highTemperatureCelsius == 16)
        #expect(payload.lowTemperatureCelsius == 11)
        #expect(payload.windKph == 12)
        #expect(payload.feelsLikeCelsius == 12)
        #expect(payload.resolvedLocation == "Osaka, Japan")
    }

    @Test func openWeatherPayloadParsesMetricWeatherData() throws {
        let response = OpenWeatherTimelineResponse(data: [
            .init(
                temp: 14.4,
                feelsLike: 13.1,
                humidity: 82,
                windSpeed: 3.5,
                weather: [.init(id: 500, icon: "10d")]
            )
        ])
        let targetDate = Date(timeIntervalSince1970: 1_776_000_000)

        let payload = try WeatherFetcher.payload(from: response, targetDate: targetDate, resolvedLocation: "Osaka, Japan")

        #expect(payload.condition == .rain)
        #expect(payload.temperatureCelsius == 14.4)
        #expect(payload.feelsLikeCelsius == 13.1)
        #expect(payload.humidity == 82)
        #expect(abs((payload.windKph ?? 0) - 12.6) < 0.0001)
        #expect(payload.highTemperatureCelsius == nil)
        #expect(payload.lowTemperatureCelsius == nil)
        #expect(payload.resolvedLocation == "Osaka, Japan")
    }

    @Test func openWeatherConditionMapsClearNightIcon() {
        #expect(WeatherCondition.fromOpenWeather(id: 800, icon: "01n") == .clearNight)
        #expect(WeatherCondition.fromOpenWeather(id: 800, icon: "01d") == .sunny)
        #expect(WeatherCondition.fromOpenWeather(id: 804, icon: "04d") == .cloudy)
        #expect(WeatherCondition.fromOpenWeather(id: 771, icon: nil) == .wind)
    }

    @Test func activityLocationResolverUsesFirstRoutePoint() throws {
        let startDate = Date(timeIntervalSince1970: 1_000)
        let activity = ActivityTimeline(
            startDate: startDate,
            duration: 10,
            distanceMeters: 100,
            records: [
                ActivityRecord(
                    elapsedTime: 0,
                    timestamp: startDate,
                    distanceMeters: 0,
                    heartRate: nil,
                    paceSecondsPerKilometer: nil,
                    elevationMeters: nil,
                    cadence: nil,
                    powerWatts: nil,
                    calories: nil,
                    latitude: 34.6937,
                    longitude: 135.5023,
                    temperatureCelsius: nil
                )
            ],
            laps: []
        )

        let coordinate = try WeatherLocationResolver.activityStartCoordinate(from: activity)

        #expect(coordinate.latitude == 34.6937)
        #expect(coordinate.longitude == 135.5023)
    }
}
