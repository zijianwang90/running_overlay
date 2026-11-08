import Foundation

/// Host-formatted numeric metrics exposed to components through the
/// `metric(id, unit...)` builtin. Ids are `OverlayMetric` raw values and
/// formatting stays in `OverlayValueFormatter`, so components share the text
/// every other overlay shows for a metric.
enum OverlayComponentMetricCatalog {
    /// Overlay Pool order for the `studio.numeric` presets, matching the
    /// former native Metrics tiles.
    static let presetOrder: [OverlayMetric] = [
        .heartRate, .heartRateZone, .pace, .avgPace, .lapPace, .calories,
        .elapsedTime, .realTime, .date, .distance, .elevation, .elevationGain,
        .cadence, .power, .verticalOscillation, .groundContactTime,
        .strideLength, .verticalRatio, .groundContactBalance, .temperature, .grade
    ]

    /// Display-unit identifiers accepted for a metric id, default first.
    static func units(for id: String) -> [String] {
        OverlayMetric(rawValue: id)?.unitOptions.map(\.rawValue) ?? []
    }

    /// Every display-unit identifier any metric accepts.
    static let allUnits: Set<String> = Set(OverlayMetric.allCases.flatMap { $0.unitOptions.map(\.rawValue) })

    /// The display unit to format with: the first requested unit the metric
    /// accepts, otherwise the metric's default. Unit names are disjoint across
    /// metric families, so one call can list a unit per family.
    static func unitOption(for metric: OverlayMetric, requested: [String]) -> OverlayUnitOption {
        for candidate in requested {
            if let option = OverlayUnitOption(rawValue: candidate), metric.unitOptions.contains(option) {
                return option
            }
        }
        return metric.defaultUnitOption
    }

    static func record(
        id: String,
        units: [String],
        activity: ActivityTimeline,
        elapsedTime: TimeInterval
    ) -> OverlayComponentValue {
        guard let metric = OverlayMetric(rawValue: id) else { return .null }
        let components = OverlayValueFormatter.components(
            for: metric,
            unit: unitOption(for: metric, requested: units),
            activity: activity,
            elapsedTime: elapsedTime
        )
        return .record([
            "value": .string(components.value),
            "unit": .string(components.unit),
            "label": .string(components.label),
            "shortLabel": .string(components.shortLabel),
            "icon": .string(metric.defaultIconSystemName)
        ])
    }
}
