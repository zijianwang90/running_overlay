import Foundation

enum OverlayValueFormatter {
    static func value(for type: OverlayElementType, activity: ActivityTimeline, elapsedTime: TimeInterval) -> String {
        let components = components(for: type, activity: activity, elapsedTime: elapsedTime)
        if type == .elevationChart {
            return components.value == "--" ? components.label : "\(components.label) \(components.value) \(components.unit)"
        }
        if components.unit.isEmpty {
            return components.value
        }
        if components.unit.hasPrefix("/") {
            return "\(components.value)\(components.unit)"
        }
        return "\(components.value) \(components.unit)"
    }

    static func components(for type: OverlayElementType, activity: ActivityTimeline, elapsedTime: TimeInterval) -> OverlayValueComponents {
        switch type {
        case .heartRate:
            return OverlayValueComponents(label: "Heart Rate", shortLabel: "HR", value: activity.heartRate(at: elapsedTime).map(String.init) ?? "--", unit: "bpm")
        case .pace:
            let pace = activity.pace(at: elapsedTime).map(formatPaceComponents)
            return OverlayValueComponents(label: "Pace", shortLabel: "PACE", value: pace?.value ?? "--'--\"", unit: pace?.unit ?? "/km")
        case .calories:
            return OverlayValueComponents(label: "Calories", shortLabel: "CAL", value: activity.calories(at: elapsedTime).map { "\(Int($0.rounded()))" } ?? "--", unit: "kcal")
        case .elapsedTime:
            return OverlayValueComponents(label: "Elapsed Time", shortLabel: "TIME", value: formatDuration(elapsedTime), unit: "")
        case .realTime:
            return OverlayValueComponents(label: "Real Time", shortLabel: "TIME", value: activity.timestamp(at: elapsedTime).formatted(date: .omitted, time: .standard), unit: "")
        case .distance:
            return OverlayValueComponents(label: "Distance", shortLabel: "DIST", value: String(format: "%.2f", activity.distance(at: elapsedTime) / 1000), unit: "km")
        case .distanceTimeline:
            return OverlayValueComponents(label: "Distance", shortLabel: "DIST", value: String(format: "%.2f / %.2f", activity.distance(at: elapsedTime) / 1000, activity.distanceMeters / 1000), unit: "km")
        case .elevation:
            return OverlayValueComponents(label: "Elevation", shortLabel: "ELEV", value: activity.elevation(at: elapsedTime).map { "\(Int($0.rounded()))" } ?? "--", unit: "m")
        case .elevationChart:
            return OverlayValueComponents(label: "Elevation", shortLabel: "ELEV", value: activity.elevation(at: elapsedTime).map { "\(Int($0.rounded()))" } ?? "--", unit: "m")
        case .cadence:
            return OverlayValueComponents(label: "Cadence", shortLabel: "CAD", value: activity.cadence(at: elapsedTime).map(String.init) ?? "--", unit: "spm")
        case .power:
            return OverlayValueComponents(label: "Power", shortLabel: "PWR", value: activity.power(at: elapsedTime).map(String.init) ?? "--", unit: "W")
        case .runningGauge:
            return OverlayValueComponents(label: "Running Gauge", shortLabel: "GAUGE", value: String(format: "%.2f", activity.distance(at: elapsedTime) / 1000), unit: "km")
        case .routeMap:
            return OverlayValueComponents(label: "Route Map", shortLabel: "ROUTE", value: "\(activity.routePoints.count)", unit: "pts")
        }
    }

    static func formatDuration(_ elapsedTime: TimeInterval) -> String {
        let totalSeconds = Int(max(elapsedTime, 0).rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private static func formatPace(_ secondsPerKilometer: Double) -> String {
        let components = formatPaceComponents(secondsPerKilometer)
        return "\(components.value)\(components.unit)"
    }

    private static func formatPaceComponents(_ secondsPerKilometer: Double) -> (value: String, unit: String) {
        guard secondsPerKilometer.isFinite, secondsPerKilometer > 0 else {
            return ("--'--\"", "/km")
        }
        let minutes = Int(secondsPerKilometer) / 60
        let seconds = Int(secondsPerKilometer.rounded()) % 60
        return (String(format: "%d'%02d\"", minutes, seconds), "/km")
    }
}

struct OverlayValueComponents: Equatable {
    var label: String
    var shortLabel: String
    var value: String
    var unit: String
}
