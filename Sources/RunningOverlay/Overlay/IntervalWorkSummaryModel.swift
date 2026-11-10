import Foundation

enum IntervalWorkSummaryMetric: String, CaseIterable, Identifiable, Codable {
    case lapTime
    case lapPace
    case lapDistance
    case avgHeartRate
    case maxHeartRate
    case avgPower
    case avgCadence

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lapTime: "Lap Time"
        case .lapPace: "Lap Pace"
        case .lapDistance: "Lap Distance"
        case .avgHeartRate: "Avg Heart Rate"
        case .maxHeartRate: "Max Heart Rate"
        case .avgPower: "Avg Power"
        case .avgCadence: "Avg Cadence"
        }
    }

    var shortLabel: String {
        switch self {
        case .lapTime: "LAP TIME"
        case .lapPace: "PACE"
        case .lapDistance: "DIST"
        case .avgHeartRate: "HR"
        case .maxHeartRate: "MAX HR"
        case .avgPower: "POWER"
        case .avgCadence: "CAD"
        }
    }
}

enum IntervalWorkSummaryUnitSystem: String, CaseIterable, Identifiable, Codable {
    case metric
    case imperial

    var id: String { rawValue }

    var label: String {
        switch self {
        case .metric: "Metric"
        case .imperial: "Imperial"
        }
    }
}
