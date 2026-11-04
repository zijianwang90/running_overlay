import CoreLocation
import Foundation

enum WeatherFetchLocationMode: String, CaseIterable, Identifiable, Equatable, Codable {
    case activityLocation
    // Retained only so projects created before current-location weather was
    // removed can still decode their cached payload provenance.
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

/// Reverse-geocodes the first FIT route point into a readable place name.
///
/// Apple's geocoder is preferred because it needs no key and no attribution.
/// When it returns no placemark (for example in a sandbox where Core Location
/// geocoding is unavailable) a keyless OpenStreetMap Nominatim lookup resolves
/// the same coordinates so the widget can show `Peterborough, ON` instead of
/// raw numbers.
enum WeatherLocationResolver {
    static func activityStartCoordinate(from activity: ActivityTimeline) throws -> WeatherCoordinate {
        guard let point = activity.routePoints.first else {
            throw WeatherFetchError.missingActivityLocation
        }
        return WeatherCoordinate(latitude: point.latitude, longitude: point.longitude)
    }

    static func displayName(latitude: Double, longitude: Double) async -> String? {
        let cacheKey = placeNameCacheKey(latitude: latitude, longitude: longitude)
        if let cached = placeNameCache.value(for: cacheKey) {
            return cached
        }

        var resolved = await applePlaceName(latitude: latitude, longitude: longitude)
        if resolved == nil {
            resolved = await openStreetMapPlaceName(latitude: latitude, longitude: longitude)
        }

        if let resolved {
            placeNameCache.set(resolved, for: cacheKey)
            return resolved
        }
        return coordinateFallback(latitude: latitude, longitude: longitude)
    }

    /// Formats `locality, administrativeArea` (for example `Peterborough, ON`)
    /// and falls back to country or coordinates when parts are missing.
    static func formatPlaceName(
        locality: String?,
        administrativeArea: String?,
        country: String?,
        isoCountryCode: String? = nil
    ) -> String? {
        let locality = trimmed(locality)
        let region = trimmed(administrativeArea).map {
            subdivisionAbbreviation($0, isoCountryCode: isoCountryCode)
        }
        let country = trimmed(country)

        if let locality {
            if let region, locality.caseInsensitiveCompare(region) != .orderedSame {
                return "\(locality), \(region)"
            }
            if let country {
                return "\(locality), \(country)"
            }
            return locality
        }
        if let region {
            return region
        }
        return country
    }

    /// Normalises full province/state names to their short form so Canadian
    /// and US locations read like a weather app (`Ontario` -> `ON`).
    static func subdivisionAbbreviation(_ value: String, isoCountryCode: String? = nil) -> String {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return value }

        // `CLPlacemark.administrativeArea` already uses short codes for many
        // regions, and Nominatim's ISO3166-2 value is passed in as `CA-ON`.
        if let iso = value.split(separator: "-").last,
           iso.count == 2,
           iso.allSatisfy({ $0.isLetter }) {
            return iso.uppercased()
        }
        if value.count <= 3, value.uppercased() == value {
            return value
        }
        if let abbreviation = subdivisionAbbreviations[value.lowercased()] {
            return abbreviation
        }
        return value
    }

    // MARK: Apple geocoder

    private static func applePlaceName(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let holder = GeocoderHolder()
        return await withCheckedContinuation { continuation in
            holder.geocoder.reverseGeocodeLocation(
                location,
                preferredLocale: Locale(identifier: "en_US")
            ) { placemarks, _ in
                // Keep the geocoder alive until the asynchronous callback fires.
                withExtendedLifetime(holder) {}
                guard let placemark = placemarks?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: formatPlaceName(
                    locality: placemark.locality ?? placemark.subAdministrativeArea ?? placemark.name,
                    administrativeArea: placemark.administrativeArea,
                    country: placemark.country,
                    isoCountryCode: placemark.isoCountryCode
                ))
            }
        }
    }

    private final class GeocoderHolder: @unchecked Sendable {
        let geocoder = CLGeocoder()
    }

    // MARK: OpenStreetMap Nominatim fallback

    static func nominatimReverseURL(latitude: Double, longitude: Double) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "nominatim.openstreetmap.org"
        components.path = "/reverse"
        components.queryItems = [
            URLQueryItem(name: "format", value: "jsonv2"),
            URLQueryItem(name: "lat", value: String(format: "%.5f", latitude)),
            URLQueryItem(name: "lon", value: String(format: "%.5f", longitude)),
            URLQueryItem(name: "zoom", value: "10"),
            URLQueryItem(name: "addressdetails", value: "1"),
            URLQueryItem(name: "accept-language", value: "en")
        ]
        return components.url
    }

    private static func openStreetMapPlaceName(latitude: Double, longitude: Double) async -> String? {
        guard let url = nominatimReverseURL(latitude: latitude, longitude: longitude) else {
            return nil
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        // Nominatim's usage policy requires a descriptive User-Agent.
        request.setValue(
            "RunningOverlayStudio/1.0 (https://github.com/zijianwang90/running_overlay)",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            return try JSONDecoder().decode(NominatimReverseResponse.self, from: data).resolvedPlaceName
        } catch {
            return nil
        }
    }

    // MARK: Helpers

    private final class PlaceNameCache: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [String: String] = [:]

        func value(for key: String) -> String? {
            lock.lock()
            defer { lock.unlock() }
            return storage[key]
        }

        func set(_ value: String, for key: String) {
            lock.lock()
            storage[key] = value
            lock.unlock()
        }
    }

    private static let placeNameCache = PlaceNameCache()

    private static func placeNameCacheKey(latitude: Double, longitude: Double) -> String {
        String(format: "%.4f,%.4f", latitude, longitude)
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func coordinateFallback(latitude: Double, longitude: Double) -> String {
        "\(String(format: "%.4f", latitude)), \(String(format: "%.4f", longitude))"
    }

    private static let subdivisionAbbreviations: [String: String] = [
        // Canadian provinces and territories.
        "ontario": "ON", "quebec": "QC", "québec": "QC", "british columbia": "BC",
        "alberta": "AB", "manitoba": "MB", "saskatchewan": "SK", "nova scotia": "NS",
        "new brunswick": "NB", "newfoundland and labrador": "NL",
        "prince edward island": "PE", "northwest territories": "NT",
        "yukon": "YT", "nunavut": "NU",
        // United States.
        "alabama": "AL", "alaska": "AK", "arizona": "AZ", "arkansas": "AR",
        "california": "CA", "colorado": "CO", "connecticut": "CT", "delaware": "DE",
        "florida": "FL", "georgia": "GA", "hawaii": "HI", "idaho": "ID",
        "illinois": "IL", "indiana": "IN", "iowa": "IA", "kansas": "KS",
        "kentucky": "KY", "louisiana": "LA", "maine": "ME", "maryland": "MD",
        "massachusetts": "MA", "michigan": "MI", "minnesota": "MN",
        "mississippi": "MS", "missouri": "MO", "montana": "MT", "nebraska": "NE",
        "nevada": "NV", "new hampshire": "NH", "new jersey": "NJ",
        "new mexico": "NM", "new york": "NY", "north carolina": "NC",
        "north dakota": "ND", "ohio": "OH", "oklahoma": "OK", "oregon": "OR",
        "pennsylvania": "PA", "rhode island": "RI", "south carolina": "SC",
        "south dakota": "SD", "tennessee": "TN", "texas": "TX", "utah": "UT",
        "vermont": "VT", "virginia": "VA", "washington": "WA",
        "west virginia": "WV", "wisconsin": "WI", "wyoming": "WY",
        "district of columbia": "DC",
        // Australian states.
        "new south wales": "NSW", "queensland": "QLD", "south australia": "SA",
        "tasmania": "TAS", "victoria": "VIC", "western australia": "WA",
        "australian capital territory": "ACT", "northern territory": "NT"
    ]
}

struct NominatimReverseResponse: Decodable, Equatable {
    var address: Address?

    struct Address: Decodable, Equatable {
        var city: String?
        var town: String?
        var village: String?
        var municipality: String?
        var county: String?
        var state: String?
        var country: String?
        var countryCode: String?
        var iso3166Level4: String?

        enum CodingKeys: String, CodingKey {
            case city, town, village, municipality, county, state, country
            case countryCode = "country_code"
            case iso3166Level4 = "ISO3166-2-lvl4"
        }
    }

    var resolvedPlaceName: String? {
        guard let address else { return nil }
        let locality = address.city ?? address.town ?? address.village
            ?? address.municipality ?? address.county
        let region = address.iso3166Level4 ?? address.state
        return WeatherLocationResolver.formatPlaceName(
            locality: locality,
            administrativeArea: region,
            country: address.country,
            isoCountryCode: address.countryCode?.uppercased()
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
