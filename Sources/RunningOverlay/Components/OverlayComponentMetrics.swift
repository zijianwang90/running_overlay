import Foundation

/// Host-formatted numeric metrics exposed to components through the
/// `metric(id, unit)` builtin. Formatting stays in `OverlayValueFormatter`, so a
/// component shows exactly the value, unit and label a native numeric overlay
/// would.
enum OverlayComponentMetricCatalog {
    struct Metric {
        var type: OverlayElementType
        var elevationDisplayMode: OverlayElevationDisplayMode = .current
    }

    static let metrics: [String: Metric] = [
        "heartRate": Metric(type: .heartRate),
        "heartRateZone": Metric(type: .heartRateZone),
        "pace": Metric(type: .pace),
        "avgPace": Metric(type: .avgPace),
        "lapPace": Metric(type: .lapPace),
        "calories": Metric(type: .calories),
        "elapsedTime": Metric(type: .elapsedTime),
        "realTime": Metric(type: .realTime),
        "date": Metric(type: .date),
        "distance": Metric(type: .distance),
        "elevation": Metric(type: .elevation),
        "elevationGain": Metric(type: .elevation, elevationDisplayMode: .gain),
        "cadence": Metric(type: .cadence),
        "power": Metric(type: .power),
        "verticalOscillation": Metric(type: .verticalOscillation),
        "groundContactTime": Metric(type: .groundContactTime),
        "strideLength": Metric(type: .strideLength),
        "verticalRatio": Metric(type: .verticalRatio),
        "groundContactBalance": Metric(type: .groundContactBalance),
        "temperature": Metric(type: .temperature),
        "grade": Metric(type: .grade)
    ]

    /// Overlay Pool order, matching the native numeric tiles.
    static let presetOrder = [
        "heartRate", "heartRateZone", "pace", "avgPace", "lapPace", "distance",
        "elapsedTime", "realTime", "date", "calories", "elevation", "elevationGain",
        "cadence", "power", "temperature", "grade", "verticalOscillation",
        "groundContactTime", "strideLength", "verticalRatio", "groundContactBalance"
    ]

    static func displayName(for id: String) -> String {
        guard let metric = metrics[id] else { return id }
        return metric.elevationDisplayMode == .gain ? "Elevation Gain" : metric.type.label
    }

    /// Display-unit identifiers accepted for a metric, default first.
    static func units(for id: String) -> [String] {
        guard let metric = metrics[id] else { return [] }
        return OverlayUnitOption.options(for: metric.type).map(\.rawValue)
    }

    /// Every display-unit identifier any metric accepts.
    static let allUnits: Set<String> = Set(metrics.keys.flatMap(units(for:)))

    /// The display unit to format with: the first requested unit the metric
    /// accepts, otherwise the metric's default. Unit names are disjoint across
    /// metric families, so one call can list a unit per family.
    static func unitOption(for metric: Metric, requested: [String]) -> OverlayUnitOption {
        let options = OverlayUnitOption.options(for: metric.type)
        for candidate in requested {
            if let option = OverlayUnitOption(rawValue: candidate), options.contains(option) {
                return option
            }
        }
        return OverlayUnitOption.defaultOption(for: metric.type)
    }

    static func record(
        id: String,
        units: [String],
        activity: ActivityTimeline,
        elapsedTime: TimeInterval
    ) -> OverlayComponentValue {
        guard let metric = metrics[id] else { return .null }
        let components = OverlayValueFormatter.components(
            for: metric.type,
            unit: unitOption(for: metric, requested: units),
            elevationDisplayMode: metric.elevationDisplayMode,
            customLabel: "",
            activity: activity,
            elapsedTime: elapsedTime
        )
        return .record([
            "value": .string(components.value),
            "unit": .string(components.unit),
            "label": .string(components.label),
            "shortLabel": .string(components.shortLabel),
            "icon": .string(metric.type.defaultNumericIconSystemName)
        ])
    }
}
