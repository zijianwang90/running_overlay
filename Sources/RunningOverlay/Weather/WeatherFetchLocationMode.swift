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
