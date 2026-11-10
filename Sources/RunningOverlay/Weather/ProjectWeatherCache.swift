import Foundation

/// Weather the host fetched for the project's activity location.
///
/// Native weather widgets keep their own copy on the element style. Declarative
/// weather components read this project-level cache instead, so one fetch
/// serves every host-drawn weather component and the snapshot survives a
/// save/reopen. Components never fetch weather themselves.
struct ProjectWeatherCache: Codable, Equatable {
    var payload: WeatherPayload
    /// Source the host used. Open-Meteo and OpenWeather both produce a payload;
    /// the recorded source keeps the Inspector honest after reopening.
    var dataSource: WeatherDataSource
    /// When the host resolved `payload`. Not used for rendering.
    var fetchedAt: Date
}
