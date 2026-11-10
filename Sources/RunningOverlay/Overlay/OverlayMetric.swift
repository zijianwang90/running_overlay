import Foundation

/// An activity reading with host formatting (value, unit and label text).
///
/// Components read metrics through the `metric(id, unit...)` builtin, keyed by
/// `rawValue`. Interval HUD, running gauge and route-map stats slots bridge to
/// the same vocabulary so every surface formats a metric identically.
enum OverlayMetric: String, CaseIterable, Identifiable, Codable, Sendable {
    case heartRate
    case heartRateZone
    case pace
    case avgPace
    case lapPace
    case calories
    case elapsedTime
    case realTime
    case date
    case distance
    case elevation
    case elevationGain
    case cadence
    case power
    case verticalOscillation
    case groundContactTime
    case strideLength
    case verticalRatio
    case groundContactBalance
    case temperature
    case grade

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .heartRate: "Heart Rate"
        case .heartRateZone: "HR Zone"
        case .pace: "Pace"
        case .avgPace: "Avg Pace"
        case .lapPace: "Lap Pace"
        case .calories: "Calories"
        case .elapsedTime: "Elapsed Time"
        case .realTime: "Real Time"
        case .date: "Date"
        case .distance: "Distance"
        case .elevation: "Elevation"
        case .elevationGain: "Elevation Gain"
        case .cadence: "Cadence"
        case .power: "Power"
        case .verticalOscillation: "Vertical Oscillation"
        case .groundContactTime: "Ground Contact Time"
        case .strideLength: "Stride Length"
        case .verticalRatio: "Vertical Ratio"
        case .groundContactBalance: "GCT Balance"
        case .temperature: "Temperature"
        case .grade: "Grade"
        }
    }

    var defaultIconSystemName: String {
        switch self {
        case .heartRate: "heart"
        case .heartRateZone: "heart.text.square.fill"
        case .pace, .avgPace: "speedometer"
        case .lapPace: "flag.checkered"
        case .calories: "flame"
        case .elapsedTime: "clock"
        case .realTime: "watch.analog"
        case .date: "calendar"
        case .distance: "ruler"
        case .elevation, .elevationGain: "mountain.2"
        case .cadence: "figure.run"
        case .power: "bolt"
        case .verticalOscillation: "arrow.up.and.down"
        case .groundContactTime: "timer"
        case .strideLength: "arrow.left.and.right"
        case .verticalRatio: "percent"
        case .groundContactBalance: "scale.3d"
        case .temperature: "thermometer"
        case .grade: "arrow.up.right"
        }
    }

    /// Short hint under the Overlay Pool tile.
    var poolHint: String {
        switch self {
        case .heartRate: "bpm"
        case .heartRateZone: "Z1–Z6"
        case .pace: "min/km"
        case .avgPace: "avg"
        case .lapPace: "lap"
        case .calories: "kcal"
        case .elapsedTime: "duration"
        case .realTime: "clock time"
        case .date: "year / month / day"
        case .distance: "km / mi"
        case .elevation: "altitude"
        case .elevationGain: "ascent"
        case .cadence: "spm"
        case .power: "watts"
        case .verticalOscillation: "cm"
        case .groundContactTime: "ms"
        case .strideLength: "m"
        case .verticalRatio: "%"
        case .groundContactBalance: "L/R"
        case .temperature: "°C / °F"
        case .grade: "slope %"
        }
    }

    /// Display units the metric can be formatted with, default first.
    var unitOptions: [OverlayUnitOption] {
        switch self {
        case .heartRate: [.bpm]
        case .heartRateZone: []
        case .pace, .avgPace, .lapPace: [.paceMetric, .paceImperial, .paceRowing]
        case .distance: [.distanceKilometers, .distanceMiles, .distanceMeters]
        case .elevation, .elevationGain: [.elevationMeters, .elevationFeet]
        case .power: [.watts]
        case .cadence: [.spm]
        case .calories: [.kcal]
        case .elapsedTime: [.durationHMS, .durationMS, .durationSeconds]
        case .realTime: [.clock24Hour, .clock12Hour]
        case .date: [.dateYMDHyphen, .dateYMDSlash, .dateMDYSlash, .dateMDHyphen, .dateMDSlash, .dateMonthDay]
        case .verticalOscillation: [.oscillationCentimeters, .oscillationMillimeters]
        case .groundContactTime: [.contactTimeMilliseconds]
        case .strideLength: [.strideLengthMeters]
        case .verticalRatio: [.verticalRatioPercent]
        case .groundContactBalance: [.balancePercent]
        case .temperature: [.temperatureCelsius, .temperatureFahrenheit]
        case .grade: [.gradePercent]
        }
    }

    var defaultUnitOption: OverlayUnitOption {
        unitOptions.first ?? .bpm
    }
}

enum ActivityMetricCatalog {
    /// Metrics offered by slot pickers in multi-metric overlays (interval HUD,
    /// running gauge, route-map stats). Zone, date and elevation gain have no
    /// slot presentation.
    static let selectableMetrics: [OverlayMetric] = OverlayMetric.allCases.filter {
        $0 != .heartRateZone && $0 != .date && $0 != .elevationGain
    }
}
