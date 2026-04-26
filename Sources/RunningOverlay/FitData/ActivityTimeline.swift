import Foundation

struct ActivityTimeline: Equatable {
    var startDate: Date
    var duration: TimeInterval
    var distanceMeters: Double
    var records: [ActivityRecord]

    var endDate: Date {
        startDate.addingTimeInterval(duration)
    }

    func timestamp(at elapsedTime: TimeInterval) -> Date {
        startDate.addingTimeInterval(clampedElapsedTime(elapsedTime))
    }

    func distance(at elapsedTime: TimeInterval) -> Double {
        interpolatedValue(at: elapsedTime, keyPath: \.distanceMeters) ?? (duration > 0 ? distanceMeters * clampedElapsedTime(elapsedTime) / duration : 0)
    }

    func heartRate(at elapsedTime: TimeInterval) -> Int? {
        interpolatedValue(at: elapsedTime, keyPath: \.heartRate).map { Int($0.rounded()) }
    }

    func pace(at elapsedTime: TimeInterval) -> Double? {
        interpolatedValue(at: elapsedTime, keyPath: \.paceSecondsPerKilometer)
    }

    func elevation(at elapsedTime: TimeInterval) -> Double? {
        interpolatedValue(at: elapsedTime, keyPath: \.elevationMeters)
    }

    func cadence(at elapsedTime: TimeInterval) -> Int? {
        interpolatedValue(at: elapsedTime, keyPath: \.cadence).map { Int($0.rounded()) }
    }

    func power(at elapsedTime: TimeInterval) -> Int? {
        interpolatedValue(at: elapsedTime, keyPath: \.powerWatts).map { Int($0.rounded()) }
    }

    func calories(at elapsedTime: TimeInterval) -> Double? {
        interpolatedValue(at: elapsedTime, keyPath: \.calories)
    }

    var routePoints: [RoutePoint] {
        records.compactMap { record in
            guard let latitude = record.latitude, let longitude = record.longitude else {
                return nil
            }
            return RoutePoint(
                elapsedTime: record.elapsedTime,
                latitude: latitude,
                longitude: longitude,
                distanceMeters: record.distanceMeters,
                paceSecondsPerKilometer: record.paceSecondsPerKilometer,
                heartRate: record.heartRate,
                elevationMeters: record.elevationMeters
            )
        }
    }

    func routePoint(at elapsedTime: TimeInterval) -> RoutePoint? {
        let points = routePoints
        guard !points.isEmpty else {
            return nil
        }

        let elapsedTime = clampedElapsedTime(elapsedTime)
        if let exact = points.first(where: { $0.elapsedTime == elapsedTime }) {
            return exact
        }

        guard let before = points.last(where: { $0.elapsedTime <= elapsedTime }) else {
            return points.first
        }
        guard let after = points.first(where: { $0.elapsedTime >= elapsedTime }),
              after.elapsedTime > before.elapsedTime else {
            return before
        }

        let progress = (elapsedTime - before.elapsedTime) / (after.elapsedTime - before.elapsedTime)
        return RoutePoint(
            elapsedTime: elapsedTime,
            latitude: before.latitude + (after.latitude - before.latitude) * progress,
            longitude: before.longitude + (after.longitude - before.longitude) * progress,
            distanceMeters: interpolateOptional(before.distanceMeters, after.distanceMeters, progress: progress),
            paceSecondsPerKilometer: interpolateOptional(before.paceSecondsPerKilometer, after.paceSecondsPerKilometer, progress: progress),
            heartRate: interpolateOptional(before.heartRate.map(Double.init), after.heartRate.map(Double.init), progress: progress).map { Int($0.rounded()) },
            elevationMeters: interpolateOptional(before.elevationMeters, after.elevationMeters, progress: progress)
        )
    }

    private func interpolatedValue(at elapsedTime: TimeInterval, keyPath: KeyPath<ActivityRecord, Double?>) -> Double? {
        interpolate(at: elapsedTime) { $0[keyPath: keyPath] }
    }

    private func interpolatedValue(at elapsedTime: TimeInterval, keyPath: KeyPath<ActivityRecord, Int?>) -> Double? {
        interpolate(at: elapsedTime) { $0[keyPath: keyPath].map(Double.init) }
    }

    private func interpolate(at elapsedTime: TimeInterval, value: (ActivityRecord) -> Double?) -> Double? {
        let elapsedTime = clampedElapsedTime(elapsedTime)
        guard !records.isEmpty else {
            return nil
        }

        if let exact = records.first(where: { $0.elapsedTime == elapsedTime }), let exactValue = value(exact) {
            return exactValue
        }

        let before = records.last { $0.elapsedTime <= elapsedTime && value($0) != nil }
        let after = records.first { $0.elapsedTime >= elapsedTime && value($0) != nil }

        guard let before, let beforeValue = value(before) else {
            return after.flatMap(value)
        }
        guard let after, let afterValue = value(after), after.elapsedTime > before.elapsedTime else {
            return beforeValue
        }

        let progress = (elapsedTime - before.elapsedTime) / (after.elapsedTime - before.elapsedTime)
        return beforeValue + (afterValue - beforeValue) * progress
    }

    private func clampedElapsedTime(_ elapsedTime: TimeInterval) -> TimeInterval {
        min(max(elapsedTime, 0), duration)
    }

    private func interpolateOptional(_ before: Double?, _ after: Double?, progress: Double) -> Double? {
        guard let before else {
            return after
        }
        guard let after else {
            return before
        }
        return before + (after - before) * progress
    }

    static let empty = ActivityTimeline(
        startDate: Date(timeIntervalSince1970: 0),
        duration: 0,
        distanceMeters: 0,
        records: []
    )
}

struct ActivityRecord: Identifiable, Equatable {
    let id = UUID()
    var elapsedTime: TimeInterval
    var timestamp: Date
    var distanceMeters: Double?
    var heartRate: Int?
    var paceSecondsPerKilometer: Double?
    var elevationMeters: Double?
    var cadence: Int?
    var powerWatts: Int?
    var calories: Double?
    var latitude: Double?
    var longitude: Double?

    init(
        elapsedTime: TimeInterval,
        timestamp: Date,
        distanceMeters: Double?,
        heartRate: Int?,
        paceSecondsPerKilometer: Double?,
        elevationMeters: Double?,
        cadence: Int?,
        powerWatts: Int?,
        calories: Double?,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.elapsedTime = elapsedTime
        self.timestamp = timestamp
        self.distanceMeters = distanceMeters
        self.heartRate = heartRate
        self.paceSecondsPerKilometer = paceSecondsPerKilometer
        self.elevationMeters = elevationMeters
        self.cadence = cadence
        self.powerWatts = powerWatts
        self.calories = calories
        self.latitude = latitude
        self.longitude = longitude
    }
}

struct RoutePoint: Equatable, Codable {
    var elapsedTime: TimeInterval
    var latitude: Double
    var longitude: Double
    var distanceMeters: Double?
    var paceSecondsPerKilometer: Double?
    var heartRate: Int?
    var elevationMeters: Double?
}

struct RouteBounds: Equatable, Hashable, Codable {
    var minLatitude: Double
    var maxLatitude: Double
    var minLongitude: Double
    var maxLongitude: Double
}

struct RouteGeometry: Equatable {
    var points: [RoutePoint]
    var bounds: RouteBounds
    var distanceMeters: Double
}
