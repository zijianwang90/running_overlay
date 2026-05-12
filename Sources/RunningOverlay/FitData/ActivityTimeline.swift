import Foundation

enum LapKind: String, Equatable, Codable {
    case warmup
    case active    // fast running / interval
    case rest      // recovery jog
    case cooldown
    case unknown
}

struct LapRecord: Identifiable, Equatable, Codable {
    var id = UUID()
    var lapIndex: Int
    var startElapsedTime: TimeInterval
    var endElapsedTime: TimeInterval
    var startDistanceMeters: Double
    var totalDistanceMeters: Double
    var totalElapsedTime: TimeInterval
    var avgPaceSecondsPerKm: Double?
    var avgHeartRate: Int?
    var maxHeartRate: Int?
    var avgCadenceSPM: Int?
    var avgPowerWatts: Int?
    var totalAscent: Int?
    var kind: LapKind
}

struct ActivityTimeline: Equatable, Codable {
    var startDate: Date
    var duration: TimeInterval
    var distanceMeters: Double
    var records: [ActivityRecord]
    var laps: [LapRecord]
    var annotatedSegments: [ActivityAnnotatedSegment] = []

    var endDate: Date {
        startDate.addingTimeInterval(duration)
    }

    func timestamp(at elapsedTime: TimeInterval) -> Date {
        startDate.addingTimeInterval(clampedElapsedTime(elapsedTime))
    }

    func annotatedSegment(at elapsedTime: TimeInterval) -> ActivityAnnotatedSegment? {
        let t = clampedElapsedTime(elapsedTime)
        return annotatedSegments.first { segment in
            t >= segment.startElapsedTime && t < segment.endElapsedTime
        }
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

    func verticalOscillation(at elapsedTime: TimeInterval) -> Double? {
        interpolatedValue(at: elapsedTime, keyPath: \.verticalOscillationMM)
    }

    func groundContactTime(at elapsedTime: TimeInterval) -> Double? {
        interpolatedValue(at: elapsedTime, keyPath: \.groundContactTimeMS)
    }

    func strideLength(at elapsedTime: TimeInterval) -> Double? {
        interpolatedValue(at: elapsedTime, keyPath: \.strideLengthM)
    }

    func verticalRatio(at elapsedTime: TimeInterval) -> Double? {
        guard let osc = verticalOscillation(at: elapsedTime),
              let stride = strideLength(at: elapsedTime),
              stride > 0 else { return nil }
        // osc is in mm, stride is in m → convert stride to mm for ratio
        return osc / (stride * 1000) * 100
    }

    func groundContactBalance(at elapsedTime: TimeInterval) -> Double? {
        interpolatedValue(at: elapsedTime, keyPath: \.groundContactBalance)
    }

    func temperature(at elapsedTime: TimeInterval) -> Double? {
        interpolatedValue(at: elapsedTime, keyPath: \.temperatureCelsius)
    }

    func grade(at elapsedTime: TimeInterval) -> Double? {
        interpolatedValue(at: elapsedTime, keyPath: \.gradePercent)
    }

    // MARK: - Lap queries

    func currentLap(at elapsedTime: TimeInterval) -> LapRecord? {
        let t = clampedElapsedTime(elapsedTime)
        return laps.last { $0.startElapsedTime <= t }
    }

    func previousLap(at elapsedTime: TimeInterval) -> LapRecord? {
        guard let cur = currentLap(at: elapsedTime),
              let idx = laps.firstIndex(where: { $0.id == cur.id }),
              idx > 0 else { return nil }
        return laps[idx - 1]
    }

    /// Most recent lap with kind == .active that has already ended.
    func lastActiveLap(at elapsedTime: TimeInterval) -> LapRecord? {
        let t = clampedElapsedTime(elapsedTime)
        return laps.last { $0.kind == .active && $0.endElapsedTime <= t }
    }

    func lapElapsedTime(at elapsedTime: TimeInterval) -> TimeInterval {
        guard let lap = currentLap(at: elapsedTime) else { return elapsedTime }
        return max(clampedElapsedTime(elapsedTime) - lap.startElapsedTime, 0)
    }

    func lapProgress(at elapsedTime: TimeInterval, byDistance: Bool) -> Double {
        guard let lap = currentLap(at: elapsedTime) else { return 0 }
        if byDistance {
            guard lap.totalDistanceMeters > 0 else { return 0 }
            let traveled = distance(at: elapsedTime) - lap.startDistanceMeters
            return min(max(traveled / lap.totalDistanceMeters, 0), 1)
        } else {
            guard lap.totalElapsedTime > 0 else { return 0 }
            let inLap = clampedElapsedTime(elapsedTime) - lap.startElapsedTime
            return min(max(inLap / lap.totalElapsedTime, 0), 1)
        }
    }

    // MARK: - Recovery HR queries

    /// Max HR recorded from the start of the current lap up to elapsedTime.
    /// Useful for rest laps: captures the HR peak that occurs just after
    /// stopping a hard interval.
    func recoveryPeakHR(at elapsedTime: TimeInterval) -> Int? {
        guard let lap = currentLap(at: elapsedTime) else { return nil }
        let t = clampedElapsedTime(elapsedTime)
        return records
            .filter { $0.elapsedTime >= lap.startElapsedTime && $0.elapsedTime <= t }
            .compactMap(\.heartRate)
            .max()
    }

    /// How many bpm the HR has dropped from the lap peak to now.
    func recoveryDrop(at elapsedTime: TimeInterval) -> Int? {
        guard let peak = recoveryPeakHR(at: elapsedTime),
              let current = heartRate(at: elapsedTime) else { return nil }
        return max(peak - current, 0)
    }

    /// Percentage of peak HR that has been shed (drop / peak × 100).
    func recoveryDropPercent(at elapsedTime: TimeInterval) -> Double? {
        guard let peak = recoveryPeakHR(at: elapsedTime), peak > 0,
              let drop = recoveryDrop(at: elapsedTime) else { return nil }
        return Double(drop) / Double(peak) * 100
    }

    /// How far the current HR is above a target (positive = still above target).
    func recoveryGapToTarget(at elapsedTime: TimeInterval, targetHR: Int) -> Int? {
        guard let current = heartRate(at: elapsedTime) else { return nil }
        return max(current - targetHR, 0)
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
        records: [],
        laps: [],
        annotatedSegments: []
    )
}

enum ActivityAnnotatedSegmentKind: String, Equatable, Codable {
    case timerPaused

    var label: String {
        switch self {
        case .timerPaused:
            "运动暂停"
        }
    }
}

struct ActivityAnnotatedSegment: Identifiable, Equatable, Codable {
    var id = UUID()
    var kind: ActivityAnnotatedSegmentKind
    var startElapsedTime: TimeInterval
    var endElapsedTime: TimeInterval

    var duration: TimeInterval {
        max(endElapsedTime - startElapsedTime, 0)
    }
}

struct ActivityRecord: Identifiable, Equatable, Codable {
    var id = UUID()
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
    var verticalOscillationMM: Double?
    var groundContactTimeMS: Double?
    var strideLengthM: Double?
    var groundContactBalance: Double?
    var temperatureCelsius: Double?
    var gradePercent: Double?

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
        longitude: Double? = nil,
        verticalOscillationMM: Double? = nil,
        groundContactTimeMS: Double? = nil,
        strideLengthM: Double? = nil,
        groundContactBalance: Double? = nil,
        temperatureCelsius: Double? = nil,
        gradePercent: Double? = nil
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
        self.verticalOscillationMM = verticalOscillationMM
        self.groundContactTimeMS = groundContactTimeMS
        self.strideLengthM = strideLengthM
        self.groundContactBalance = groundContactBalance
        self.temperatureCelsius = temperatureCelsius
        self.gradePercent = gradePercent
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
