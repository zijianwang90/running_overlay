import Foundation

enum OverlayValueFormatter {
    /// Renders the formatted value string for an overlay using only its `type`.
    /// This preserves backward compatibility for callers that do not have an
    /// `OverlayElement` (e.g. inspector previews of bare types).
    static func value(for type: OverlayElementType, activity: ActivityTimeline, elapsedTime: TimeInterval) -> String {
        let components = components(for: type, activity: activity, elapsedTime: elapsedTime)
        return assemble(components, includeLabel: false, includeUnit: true, isChart: type == .elevationChart)
    }

    /// Renders the formatted value string for an overlay element. Honors
    /// per-overlay unit selection, show-label, show-unit and custom label.
    static func value(for element: OverlayElement, activity: ActivityTimeline, elapsedTime: TimeInterval) -> String {
        let components = components(for: element, activity: activity, elapsedTime: elapsedTime)
        return assemble(
            components,
            includeLabel: element.style.showLabel,
            includeUnit: element.style.showUnit,
            isChart: element.type == .elevationChart
        )
    }

    static func components(for type: OverlayElementType, activity: ActivityTimeline, elapsedTime: TimeInterval) -> OverlayValueComponents {
        components(for: type, unit: type.defaultUnitOption, customLabel: "", activity: activity, elapsedTime: elapsedTime)
    }

    static func components(for element: OverlayElement, activity: ActivityTimeline, elapsedTime: TimeInterval) -> OverlayValueComponents {
        let type = element.type
        let unit = type.isNumericOverlay ? element.style.unitOption : type.defaultUnitOption
        return components(for: type, unit: unit, customLabel: element.style.customLabel, activity: activity, elapsedTime: elapsedTime)
    }

    static func formatDuration(_ elapsedTime: TimeInterval) -> String {
        formatDuration(elapsedTime, option: .durationHMS)
    }

    private static func assemble(_ components: OverlayValueComponents, includeLabel: Bool, includeUnit: Bool, isChart: Bool) -> String {
        if isChart {
            return components.value == "--" ? components.label : "\(components.label) \(components.value) \(components.unit)"
        }
        var output = ""
        if includeLabel, !components.label.isEmpty {
            output += components.label + " "
        }
        output += components.value
        if includeUnit, !components.unit.isEmpty {
            if components.unit.hasPrefix("/") {
                output += components.unit
            } else {
                output += " " + components.unit
            }
        }
        return output
    }

    private static func components(
        for type: OverlayElementType,
        unit unitOption: OverlayUnitOption,
        customLabel: String,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval
    ) -> OverlayValueComponents {
        let resolvedLabel: (String) -> String = { defaultLabel in
            let trimmed = customLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? defaultLabel : trimmed
        }

        switch type {
        case .heartRate:
            return OverlayValueComponents(
                label: resolvedLabel("Heart Rate"),
                shortLabel: "HR",
                value: activity.heartRate(at: elapsedTime).map(String.init) ?? "--",
                unit: "bpm"
            )
        case .pace:
            let pace = activity.pace(at: elapsedTime).map { formatPaceComponents($0, option: unitOption) }
            return OverlayValueComponents(
                label: resolvedLabel("Pace"),
                shortLabel: "PACE",
                value: pace?.value ?? "--'--\"",
                unit: pace?.unit ?? defaultPaceUnit(for: unitOption)
            )
        case .calories:
            return OverlayValueComponents(
                label: resolvedLabel("Calories"),
                shortLabel: "CAL",
                value: activity.calories(at: elapsedTime).map { "\(Int($0.rounded()))" } ?? "--",
                unit: "kcal"
            )
        case .elapsedTime:
            return OverlayValueComponents(
                label: resolvedLabel("Elapsed Time"),
                shortLabel: "TIME",
                value: formatDuration(elapsedTime, option: unitOption),
                unit: ""
            )
        case .realTime:
            return OverlayValueComponents(
                label: resolvedLabel("Real Time"),
                shortLabel: "TIME",
                value: formatRealTime(activity.timestamp(at: elapsedTime), option: unitOption),
                unit: ""
            )
        case .distance:
            let formatted = formatDistanceComponents(meters: activity.distance(at: elapsedTime), option: unitOption)
            return OverlayValueComponents(
                label: resolvedLabel("Distance"),
                shortLabel: "DIST",
                value: formatted.value,
                unit: formatted.unit
            )
        case .distanceTimeline:
            return OverlayValueComponents(label: "Distance", shortLabel: "DIST", value: String(format: "%.2f / %.2f", activity.distance(at: elapsedTime) / 1000, activity.distanceMeters / 1000), unit: "km")
        case .elevation:
            let formatted = formatElevationComponents(meters: activity.elevation(at: elapsedTime), option: unitOption)
            return OverlayValueComponents(
                label: resolvedLabel("Elevation"),
                shortLabel: "ELEV",
                value: formatted.value,
                unit: formatted.unit
            )
        case .elevationChart:
            return OverlayValueComponents(label: "Elevation", shortLabel: "ELEV", value: activity.elevation(at: elapsedTime).map { "\(Int($0.rounded()))" } ?? "--", unit: "m")
        case .cadence:
            return OverlayValueComponents(
                label: resolvedLabel("Cadence"),
                shortLabel: "CAD",
                value: activity.cadence(at: elapsedTime).map(String.init) ?? "--",
                unit: "spm"
            )
        case .power:
            return OverlayValueComponents(
                label: resolvedLabel("Power"),
                shortLabel: "PWR",
                value: activity.power(at: elapsedTime).map(String.init) ?? "--",
                unit: "W"
            )
        case .runningGauge:
            return OverlayValueComponents(label: "Running Gauge", shortLabel: "GAUGE", value: String(format: "%.2f", activity.distance(at: elapsedTime) / 1000), unit: "km")
        case .routeMap:
            return OverlayValueComponents(label: "Route Map", shortLabel: "ROUTE", value: "\(activity.routePoints.count)", unit: "pts")
        }
    }

    static func formatDuration(_ elapsedTime: TimeInterval, option: OverlayUnitOption) -> String {
        let totalSeconds = max(elapsedTime, 0)
        switch option {
        case .durationSeconds:
            return "\(Int(totalSeconds.rounded()))"
        case .durationMS:
            let minutes = Int(totalSeconds) / 60
            let seconds = Int(totalSeconds.rounded()) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        default:
            let total = Int(totalSeconds.rounded())
            let hours = total / 3600
            let minutes = (total % 3600) / 60
            let seconds = total % 60
            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            }
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private static func formatRealTime(_ date: Date, option: OverlayUnitOption) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = option == .clock12Hour ? "h:mm:ss a" : "HH:mm:ss"
        return formatter.string(from: date)
    }

    private static func formatDistanceComponents(meters: Double, option: OverlayUnitOption) -> (value: String, unit: String) {
        switch option {
        case .distanceMiles:
            return (String(format: "%.2f", meters / 1609.344), "mi")
        case .distanceMeters:
            return (String(format: "%.0f", meters.rounded()), "m")
        default:
            return (String(format: "%.2f", meters / 1000), "km")
        }
    }

    private static func formatElevationComponents(meters: Double?, option: OverlayUnitOption) -> (value: String, unit: String) {
        guard let meters else {
            return ("--", option == .elevationFeet ? "ft" : "m")
        }
        switch option {
        case .elevationFeet:
            return ("\(Int((meters * 3.28084).rounded()))", "ft")
        default:
            return ("\(Int(meters.rounded()))", "m")
        }
    }

    private static func defaultPaceUnit(for option: OverlayUnitOption) -> String {
        switch option {
        case .paceImperial: "/mi"
        case .paceRowing: "/500m"
        default: "/km"
        }
    }

    private static func formatPaceComponents(_ secondsPerKilometer: Double, option: OverlayUnitOption) -> (value: String, unit: String) {
        guard secondsPerKilometer.isFinite, secondsPerKilometer > 0 else {
            return ("--'--\"", defaultPaceUnit(for: option))
        }
        let secondsPerUnit: Double
        let unit: String
        switch option {
        case .paceImperial:
            secondsPerUnit = secondsPerKilometer * 1.609344
            unit = "/mi"
        case .paceRowing:
            secondsPerUnit = secondsPerKilometer * 0.5
            unit = "/500m"
        default:
            secondsPerUnit = secondsPerKilometer
            unit = "/km"
        }
        let minutes = Int(secondsPerUnit) / 60
        let seconds = Int(secondsPerUnit.rounded()) % 60
        return (String(format: "%d'%02d\"", minutes, seconds), unit)
    }
}

struct OverlayValueComponents: Equatable {
    var label: String
    var shortLabel: String
    var value: String
    var unit: String
}
