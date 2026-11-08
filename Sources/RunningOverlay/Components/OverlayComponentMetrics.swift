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

    /// Display-unit identifiers accepted for a metric, default first.
    static func units(for id: String) -> [String] {
        guard let metric = metrics[id] else { return [] }
        return OverlayUnitOption.options(for: metric.type).map(\.rawValue)
    }

    /// The display unit to format with: the requested one when the metric
    /// accepts it, otherwise the metric's default.
    static func unitOption(for metric: Metric, requested: String?) -> OverlayUnitOption {
        let options = OverlayUnitOption.options(for: metric.type)
        if let requested,
           let option = OverlayUnitOption(rawValue: requested),
           options.contains(option) {
            return option
        }
        return OverlayUnitOption.defaultOption(for: metric.type)
    }

    static func record(
        id: String,
        unit: String?,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval
    ) -> OverlayComponentValue {
        guard let metric = metrics[id] else { return .null }
        let components = OverlayValueFormatter.components(
            for: metric.type,
            unit: unitOption(for: metric, requested: unit),
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
