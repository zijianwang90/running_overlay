import Foundation

/// Adapts `ActivityTimeline` to the read-only component data contract.
///
/// This type deliberately exposes activity elapsed time only. Media, project
/// timeline and render-frame time are never visible to a component.
struct OverlayComponentActivityData: OverlayComponentDataProviding {
    var activity: ActivityTimeline
    var elapsedTime: TimeInterval
    var zoneSnapshot: HeartRateZoneSnapshot?
    var canvasSize: CGSize
    var elementScale: Double
    var intervalColors: IntervalKindColorPalette = IntervalKindColorPreferences.currentSnapshot()
    /// Weather already resolved by the host for the playhead. Components never
    /// fetch weather themselves.
    var weatherPayload: WeatherPayload?

    func signal(path: String) -> OverlayComponentValue {
        let time = activity.componentElapsedTime(elapsedTime)
        switch path {
        case "activity.duration":
            return .number(activity.duration)
        case "activity.totalDistance":
            return .number(activity.distanceMeters)
        case "structure.segment":
            return segment(at: time)
        case "structure.lastWork":
            return lastWork(at: time)
        case "structure.recovery":
            return recovery(at: time)
        case "zone.heartRateThreshold":
            return zoneThreshold(isPace: false)
        case "zone.paceThreshold":
            return zoneThreshold(isPace: true)
        case "activity.elapsed":
            return .number(time)
        case "activity.remaining":
            return .number(max(activity.duration - time, 0))
        case "activity.distance":
            return .number(activity.distance(at: time))
        case "activity.heartRate":
            return activity.heartRate(at: time).map { .number(Double($0)) } ?? .null
        case "activity.pace":
            return activity.pace(at: time).map(OverlayComponentValue.number) ?? .null
        case "activity.avgPace":
            return activity.avgPace(at: time).map(OverlayComponentValue.number) ?? .null
        case "activity.elevation":
            return activity.elevation(at: time).map(OverlayComponentValue.number) ?? .null
        case "activity.elevationGain":
            return activity.elevationGain(at: time).map(OverlayComponentValue.number) ?? .null
        case "activity.cadence":
            return activity.cadence(at: time).map { .number(Double($0)) } ?? .null
        case "activity.power":
            return activity.power(at: time).map { .number(Double($0)) } ?? .null
        case "activity.grade":
            return activity.grade(at: time).map(OverlayComponentValue.number) ?? .null
        case "activity.temperature":
            return activity.temperature(at: time).map(OverlayComponentValue.number) ?? .null
        case "activity.calories":
            return activity.calories(at: time).map(OverlayComponentValue.number) ?? .null
        case "activity.lapPace", "activity.verticalOscillation", "activity.groundContactTime",
             "activity.strideLength", "activity.verticalRatio", "activity.groundContactBalance":
            return runningSignal(path: path, at: time)
        case "clock.realTime":
            return .number(Self.secondsSinceMidnight(activity.startDate.addingTimeInterval(time)))
        case "clock.date":
            return .string(Self.dateString(activity.startDate.addingTimeInterval(time)))
        case "host.canvasWidth", "host":
            return path == "host.canvasWidth"
                ? .number(Double(canvasSize.width))
                : hostRecord
        case "host.canvasHeight":
            return .number(Double(canvasSize.height))
        case "host.scale":
            return .number(elementScale)
        case "zone.current":
            return heartRateOrPaceZone(at: time)
        case "zone.heartRate":
            return heartRateZone(at: time)
        case "zone.pace":
            return paceZone(at: time)
        case "structure.currentLap":
            return activity.currentLap(at: time).map(Self.lapRecord) ?? .null
        case "structure.current":
            return currentStructure(at: time)
        case "route.current":
            return routePosition(at: time)
        case "weather.current":
            guard let weather = weatherPayload else { return .null }
            return .record([
                "temperatureC": .number(weather.temperatureCelsius),
                "condition": .string(weather.condition.rawValue),
                "icon": .string(weather.condition.sfSymbolName),
                "windSpeedMPS": weather.windKph.map { .number($0 / 3.6) } ?? .null,
                "humidity": weather.humidity.map { .number($0) } ?? .null
            ])
        default:
            return .null
        }
    }

    func weatherSnapshot() -> WeatherPayload? { weatherPayload }

    func metric(id: String, units: [String]) -> OverlayComponentValue {
        OverlayComponentMetricCatalog.record(
            id: id,
            units: units,
            activity: activity,
            elapsedTime: activity.componentElapsedTime(elapsedTime)
        )
    }

    func series(
        path: String,
        window: OverlayComponentSeriesWindow,
        samples: Int
    ) -> OverlayComponentValue {
        let bounds: (start: Double, end: Double)
        switch window {
        case .full:
            bounds = (0, max(activity.duration, 0))
        case .relative(let start, let end):
            bounds = (
                activity.componentElapsedTime(elapsedTime + start),
                activity.componentElapsedTime(elapsedTime + end)
            )
        }
        let count = max(2, min(samples, 1024))
        let lower = min(bounds.start, bounds.end)
        let upper = max(bounds.start, bounds.end)
        let values: [OverlayComponentValue] = (0..<count).map { index in
            let fraction = count > 1 ? Double(index) / Double(count - 1) : 0
            let time = lower + (upper - lower) * fraction
            return seriesValue(path: path, at: time)
        }
        return .list(values)
    }

    func list(path: String) -> OverlayComponentValue {
        switch path {
        case "zone.heartRateZones":
            return zoneList(isPace: false)
        case "zone.paceZones":
            return zoneList(isPace: true)
        case "structure.laps":
            return .list(activity.laps.map(Self.lapRecord))
        case "structure.intervals":
            return .list(
                activity.laps
                    .filter { $0.kind == .active || $0.kind == .rest }
                    .map(Self.lapRecord)
            )
        default:
            return .null
        }
    }

    private var hostRecord: OverlayComponentValue {
        .record([
            "canvasWidth": .number(Double(canvasSize.width)),
            "canvasHeight": .number(Double(canvasSize.height)),
            "scale": .number(elementScale)
        ])
    }

    private func seriesValue(path: String, at time: TimeInterval) -> OverlayComponentValue {
        let clamped = activity.componentElapsedTime(time)
        switch path {
        case "activity.elapsed": return .number(clamped)
        case "activity.remaining": return .number(max(activity.duration - clamped, 0))
        case "activity.distance": return .number(activity.distance(at: clamped))
        case "activity.heartRate":
            return activity.heartRate(at: clamped).map { .number(Double($0)) } ?? .null
        case "activity.pace":
            return activity.pace(at: clamped).map(OverlayComponentValue.number) ?? .null
        case "activity.avgPace":
            return activity.avgPace(at: clamped).map(OverlayComponentValue.number) ?? .null
        case "activity.elevation":
            return activity.elevation(at: clamped).map(OverlayComponentValue.number) ?? .null
        case "activity.elevationGain":
            return activity.elevationGain(at: clamped).map(OverlayComponentValue.number) ?? .null
        case "activity.cadence":
            return activity.cadence(at: clamped).map { .number(Double($0)) } ?? .null
        case "activity.power":
            return activity.power(at: clamped).map { .number(Double($0)) } ?? .null
        case "activity.grade":
            return activity.grade(at: clamped).map(OverlayComponentValue.number) ?? .null
        case "activity.temperature":
            return activity.temperature(at: clamped).map(OverlayComponentValue.number) ?? .null
        case "activity.calories":
            return activity.calories(at: clamped).map(OverlayComponentValue.number) ?? .null
        default:
            return runningSignal(path: path, at: clamped)
        }
    }

    /// Lap pace and running dynamics in their FIT units: seconds per
    /// kilometer, millimeters, milliseconds, meters, percent, and percent left.
    private func runningSignal(path: String, at time: TimeInterval) -> OverlayComponentValue {
        let value: Double?
        switch path {
        case "activity.lapPace": value = activity.lapPace(at: time)
        case "activity.verticalOscillation": value = activity.verticalOscillation(at: time)
        case "activity.groundContactTime": value = activity.groundContactTime(at: time)
        case "activity.strideLength": value = activity.strideLength(at: time)
        case "activity.verticalRatio": value = activity.verticalRatio(at: time)
        case "activity.groundContactBalance": value = activity.groundContactBalance(at: time)
        default: value = nil
        }
        return value.map(OverlayComponentValue.number) ?? .null
    }

    private func heartRateZone(at time: TimeInterval) -> OverlayComponentValue {
        guard let snapshot = zoneSnapshot,
              let heartRate = activity.heartRate(at: time),
              let zoneIndex = Self.heartRateZoneIndex(heartRate: heartRate, snapshot: snapshot) else {
            return .null
        }
        return zoneValue(index: zoneIndex, snapshot: snapshot, isPace: false, value: Double(heartRate))
    }

    private func paceZone(at time: TimeInterval) -> OverlayComponentValue {
        guard let snapshot = zoneSnapshot,
              let pace = activity.pace(at: time), pace > 0,
              let zoneIndex = Self.paceZoneIndex(pace: pace, snapshot: snapshot) else {
            return .null
        }
        return zoneValue(index: zoneIndex, snapshot: snapshot, isPace: true, value: pace)
    }

    private func currentStructure(at time: TimeInterval) -> OverlayComponentValue {
        guard activity.workoutStructure.kind == .structured,
              let lap = activity.currentLap(at: time),
              lap.kind != .unknown else {
            return .null
        }
        let elapsed = max(activity.componentElapsedTime(time) - lap.startElapsedTime, 0)
        let duration = max(lap.totalElapsedTime, 0)
        let remaining = max(duration - elapsed, 0)
        let progress = duration > 0 ? min(max(elapsed / duration, 0), 1) : 0
        return .record([
            "index": .number(Double(lap.lapIndex)),
            "phase": .string(lap.kind.rawValue),
            "elapsed": .number(elapsed),
            "duration": .number(duration),
            "remaining": .number(remaining),
            "progress": .number(progress)
        ])
    }

    private func routePosition(at time: TimeInterval) -> OverlayComponentValue {
        let clamped = activity.componentElapsedTime(time)
        guard let record = activity.records.last(where: {
            $0.elapsedTime <= clamped && $0.latitude != nil && $0.longitude != nil
        }),
              let latitude = record.latitude,
              let longitude = record.longitude else {
            return .null
        }
        let fraction = activity.distanceMeters > 0
            ? min(max(activity.distance(at: clamped) / activity.distanceMeters, 0), 1)
            : 0
        return .record([
            "lat": .number(latitude),
            "lon": .number(longitude),
            "distanceFraction": .number(fraction),
            "elevation": record.elevationMeters.map(OverlayComponentValue.number) ?? .null
        ])
    }

    static func heartRateZoneIndex(
        heartRate: Int,
        snapshot: HeartRateZoneSnapshot
    ) -> Int? {
        snapshot.zones.prefix(snapshot.zoneCount).firstIndex { zone in
            guard zone.minHR != nil || zone.maxHR != nil else { return false }
            let lower = zone.minHR ?? Int.min
            let upper = zone.maxHR ?? Int.max
            return heartRate >= lower && heartRate <= upper
        }
    }

    static func paceZoneIndex(
        pace: Double,
        snapshot: HeartRateZoneSnapshot
    ) -> Int? {
        snapshot.zones.prefix(snapshot.zoneCount).firstIndex { zone in
            guard zone.minPaceSecPerKm != nil || zone.maxPaceSecPerKm != nil else {
                return false
            }
            let lower = Double(zone.minPaceSecPerKm ?? Int.min)
            let upper = Double(zone.maxPaceSecPerKm ?? Int.max)
            return pace >= min(lower, upper) && pace <= max(lower, upper)
        }
    }

    static func zoneRecord(
        index: Int,
        snapshot: HeartRateZoneSnapshot,
        isPace: Bool
    ) -> OverlayComponentValue {
        let zone = snapshot.zones[index]
        let lower: OverlayComponentValue
        let upper: OverlayComponentValue
        if isPace {
            lower = zone.minPaceSecPerKm.map { .number(Double($0)) } ?? .null
            upper = zone.maxPaceSecPerKm.map { .number(Double($0)) } ?? .null
        } else {
            lower = zone.minHR.map { .number(Double($0)) } ?? .null
            upper = zone.maxHR.map { .number(Double($0)) } ?? .null
        }
        return .record([
            "index": .number(Double(index + 1)),
            "count": .number(Double(snapshot.zoneCount)),
            "label": .string("Z\(index + 1)"),
            "color": .color(HRZonePalette.overlayColor(forIndex: index)),
            "lower": lower,
            "upper": upper
        ])
    }

    static func lapRecord(_ lap: LapRecord) -> OverlayComponentValue {
        .record([
            "index": .number(Double(lap.lapIndex)),
            "startElapsed": .number(lap.startElapsedTime),
            "endElapsed": .number(lap.endElapsedTime),
            "startDistance": .number(lap.startDistanceMeters),
            "elapsed": .number(lap.totalElapsedTime),
            "distance": .number(lap.totalDistanceMeters),
            "avgPace": lap.avgPaceSecondsPerKm.map(OverlayComponentValue.number) ?? .null,
            "avgHeartRate": lap.avgHeartRate.map { .number(Double($0)) } ?? .null,
            "maxHeartRate": lap.maxHeartRate.map { .number(Double($0)) } ?? .null,
            "avgCadence": lap.avgCadenceSPM.map { .number(Double($0)) } ?? .null,
            "avgPower": lap.avgPowerWatts.map { .number(Double($0)) } ?? .null,
            "totalAscent": lap.totalAscent.map { .number(Double($0)) } ?? .null,
            "kind": .string(lap.kind.rawValue)
        ])
    }

    private static func secondsSinceMidnight(_ date: Date) -> Double {
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        return Double((components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60 + (components.second ?? 0))
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

extension ActivityTimeline {
    func componentElapsedTime(_ time: TimeInterval) -> TimeInterval {
        min(max(time, 0), max(duration, 0))
    }
}
