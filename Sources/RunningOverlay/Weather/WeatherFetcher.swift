import CoreLocation
import Foundation

enum WeatherFetchLocationMode: String, CaseIterable, Identifiable, Equatable, Codable {
    case activityLocation
    case currentLocation

    var id: String { rawValue }

    var label: String {
        switch self {
        case .activityLocation: "Activity Location"
        case .currentLocation: "Current Location"
        }
    }
}

enum WeatherFetchError: LocalizedError, Equatable {
    case missingActivityLocation
    case missingOpenWeatherAPIKey
    case openWeatherUnauthorized
    case invalidURL
    case invalidHTTPStatus(Int)
    case missingHourlyData
    case missingOpenWeatherData
    case currentLocationUnavailable
    case currentLocationDenied

    var errorDescription: String? {
        switch self {
        case .missingActivityLocation:
            "Activity route has no GPS position."
        case .missingOpenWeatherAPIKey:
            "OpenWeather API key is missing. Add it in Project Settings."
        case .openWeatherUnauthorized:
            "OpenWeather access was denied. A new API key or One Call subscription may still be activating. Otherwise, subscribe to One Call 4.0 (the first 1,000 calls per day are free), verify the key, or switch this widget to Open-Meteo API."
        case .invalidURL:
            "Could not build the weather API URL."
        case .invalidHTTPStatus(let status):
            "Weather API returned HTTP \(status)."
        case .missingHourlyData:
            "Weather API response did not include usable hourly data."
        case .missingOpenWeatherData:
            "OpenWeather response did not include usable weather data."
        case .currentLocationUnavailable:
            "Current location is unavailable."
        case .currentLocationDenied:
            "Location permission is denied."
        }
    }
}

struct WeatherCoordinate: Equatable {
    var latitude: Double
    var longitude: Double
}

struct OpenMeteoArchiveResponse: Decodable, Equatable {
    var hourly: Hourly

    struct Hourly: Decodable, Equatable {
        var time: [String]
        var temperature2m: [Double?]
        var relativeHumidity2m: [Double?]?
        var apparentTemperature: [Double?]?
        var weatherCode: [Int?]?
        var windSpeed10m: [Double?]?

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2m = "temperature_2m"
            case relativeHumidity2m = "relative_humidity_2m"
            case apparentTemperature = "apparent_temperature"
            case weatherCode = "weather_code"
            case windSpeed10m = "wind_speed_10m"
        }
    }
}

struct OpenWeatherTimelineResponse: Decodable, Equatable {
    var data: [WeatherData]

    struct WeatherData: Decodable, Equatable {
        var temp: Double?
        var feelsLike: Double?
        var humidity: Double?
        var windSpeed: Double?
        var weather: [WeatherConditionData]?

        enum CodingKeys: String, CodingKey {
            case temp
            case feelsLike = "feels_like"
            case humidity
            case windSpeed = "wind_speed"
            case weather
        }
    }

    struct WeatherConditionData: Decodable, Equatable {
        var id: Int
        var icon: String?
    }
}

enum WeatherFetcher {
    static func fetch(latitude: Double, longitude: Double, date: Date, resolvedLocation: String?) async throws -> WeatherPayload {
        let url = try archiveURL(latitude: latitude, longitude: longitude, date: date)
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw WeatherFetchError.invalidHTTPStatus(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(OpenMeteoArchiveResponse.self, from: data)
        return try payload(from: decoded, targetDate: date, resolvedLocation: resolvedLocation)
    }

    static func archiveURL(latitude: Double, longitude: Double, date: Date) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "archive-api.open-meteo.com"
        components.path = "/v1/archive"
        let day = weatherAPIDateFormatter.string(from: date)
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.5f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.5f", longitude)),
            URLQueryItem(name: "start_date", value: day),
            URLQueryItem(name: "end_date", value: day),
            URLQueryItem(name: "hourly", value: "temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        guard let url = components.url else {
            throw WeatherFetchError.invalidURL
        }
        return url
    }

    static func fetchOpenWeather(
        latitude: Double,
        longitude: Double,
        date: Date,
        apiKey: String,
        resolvedLocation: String?
    ) async throws -> WeatherPayload {
        let url = try openWeatherTimelineURL(latitude: latitude, longitude: longitude, date: date, apiKey: apiKey)
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw openWeatherHTTPError(statusCode: http.statusCode)
        }

        let decoded = try JSONDecoder().decode(OpenWeatherTimelineResponse.self, from: data)
        return try payload(from: decoded, targetDate: date, resolvedLocation: resolvedLocation)
    }

    static func openWeatherHTTPError(statusCode: Int) -> WeatherFetchError {
        statusCode == 401 ? .openWeatherUnauthorized : .invalidHTTPStatus(statusCode)
    }

    static func openWeatherTimelineURL(latitude: Double, longitude: Double, date: Date, apiKey: String) throws -> URL {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw WeatherFetchError.missingOpenWeatherAPIKey
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.openweathermap.org"
        components.path = "/data/4.0/onecall/timeline/1h"
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(format: "%.5f", latitude)),
            URLQueryItem(name: "lon", value: String(format: "%.5f", longitude)),
            URLQueryItem(name: "start", value: String(Int(date.timeIntervalSince1970.rounded()))),
            URLQueryItem(name: "cnt", value: "1"),
            URLQueryItem(name: "appid", value: trimmedKey),
            URLQueryItem(name: "units", value: "metric")
        ]
        guard let url = components.url else {
            throw WeatherFetchError.invalidURL
        }
        return url
    }

    static func payload(from response: OpenMeteoArchiveResponse, targetDate: Date, resolvedLocation: String?) throws -> WeatherPayload {
        let hourly = response.hourly
        guard !hourly.time.isEmpty, !hourly.temperature2m.isEmpty else {
            throw WeatherFetchError.missingHourlyData
        }

        let targetHour = Calendar.current.component(.hour, from: targetDate)
        let bestIndex = bestHourlyIndex(times: hourly.time, targetHour: targetHour)
        guard bestIndex < hourly.temperature2m.count, let temperature = hourly.temperature2m[bestIndex] else {
            throw WeatherFetchError.missingHourlyData
        }

        let temperatures = hourly.temperature2m.compactMap { $0 }
        let weatherCode = hourly.weatherCode?[safe: bestIndex] ?? nil

        return WeatherPayload(
            condition: WeatherCondition.fromWMO(weatherCode ?? 3),
            temperatureCelsius: temperature,
            humidity: hourly.relativeHumidity2m?[safe: bestIndex] ?? nil,
            highTemperatureCelsius: temperatures.max(),
            lowTemperatureCelsius: temperatures.min(),
            windKph: hourly.windSpeed10m?[safe: bestIndex] ?? nil,
            feelsLikeCelsius: hourly.apparentTemperature?[safe: bestIndex] ?? nil,
            resolvedLocation: resolvedLocation,
            sourceDate: targetDate,
            fetchLocationMode: nil
        )
    }

    static func payload(from response: OpenWeatherTimelineResponse, targetDate: Date, resolvedLocation: String?) throws -> WeatherPayload {
        guard let data = response.data.first, let temperature = data.temp else {
            throw WeatherFetchError.missingOpenWeatherData
        }

        let weather = data.weather?.first
        let condition = weather.map { WeatherCondition.fromOpenWeather(id: $0.id, icon: $0.icon) } ?? .cloudy
        let windKph = data.windSpeed.map { $0 * 3.6 }

        return WeatherPayload(
            condition: condition,
            temperatureCelsius: temperature,
            humidity: data.humidity,
            highTemperatureCelsius: nil,
            lowTemperatureCelsius: nil,
            windKph: windKph,
            feelsLikeCelsius: data.feelsLike,
            resolvedLocation: resolvedLocation,
            sourceDate: targetDate,
            fetchLocationMode: nil
        )
    }

    private static var weatherAPIDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static func bestHourlyIndex(times: [String], targetHour: Int) -> Int {
        let parsedHours = times.map { timeString -> Int? in
            guard let hourText = timeString.split(separator: "T").last?.prefix(2),
                  let hour = Int(hourText) else {
                return nil
            }
            return hour
        }

        if let exact = parsedHours.firstIndex(where: { $0 == targetHour }) {
            return exact
        }

        return parsedHours.enumerated()
            .compactMap { index, hour -> (Int, Int)? in
                guard let hour else { return nil }
                return (index, abs(hour - targetHour))
            }
            .min { $0.1 < $1.1 }?
            .0 ?? 0
    }
}

@MainActor
final class CurrentLocationProvider: NSObject, CLLocationManagerDelegate {
    static let shared = CurrentLocationProvider()

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override private init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestCurrentLocation() async throws -> CLLocation {
        guard CLLocationManager.locationServicesEnabled() else {
            throw WeatherFetchError.currentLocationUnavailable
        }

        let status = manager.authorizationStatus
        if status == .denied || status == .restricted {
            throw WeatherFetchError.currentLocationDenied
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            if status == .notDetermined {
                manager.requestWhenInUseAuthorization()
            }
            manager.requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else {
                continuation?.resume(throwing: WeatherFetchError.currentLocationUnavailable)
                continuation = nil
                return
            }
            continuation?.resume(returning: location)
            continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}

enum WeatherLocationResolver {
    static func activityStartCoordinate(from activity: ActivityTimeline) throws -> WeatherCoordinate {
        guard let point = activity.routePoints.first else {
            throw WeatherFetchError.missingActivityLocation
        }
        return WeatherCoordinate(latitude: point.latitude, longitude: point.longitude)
    }

    static func currentCoordinate() async throws -> WeatherCoordinate {
        let location = try await CurrentLocationProvider.shared.requestCurrentLocation()
        return WeatherCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }

    static func displayName(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        return await withCheckedContinuation { continuation in
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
                guard let placemark = placemarks?.first else {
                    continuation.resume(returning: coordinateFallback(latitude: latitude, longitude: longitude))
                    return
                }
                let locality = placemark.locality ?? placemark.administrativeArea ?? placemark.name
                let country = placemark.country
                switch (locality?.isEmpty == false ? locality : nil, country?.isEmpty == false ? country : nil) {
                case let (locality?, country?):
                    continuation.resume(returning: "\(locality), \(country)")
                case let (locality?, nil):
                    continuation.resume(returning: locality)
                case let (nil, country?):
                    continuation.resume(returning: country)
                case (nil, nil):
                    continuation.resume(returning: coordinateFallback(latitude: latitude, longitude: longitude))
                }
            }
        }
    }

    private static func coordinateFallback(latitude: Double, longitude: Double) -> String {
        "\(String(format: "%.4f", latitude)), \(String(format: "%.4f", longitude))"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
