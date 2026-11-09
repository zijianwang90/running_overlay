import Foundation

/// Synthetic data for AI-assisted authoring previews.
///
/// Previews sent to an AI client never use the open project's activity: heart
/// rate, pace, position and weather here are generated, deterministic and
/// fictional, so no athlete data leaves the machine through a render.
enum ComponentAuthoringFixture {
    /// A 12-minute interval workout: warmup, two work reps with recovery and a
    /// cooldown, with smoothly varying metrics and a fictional loop route.
    static func workout() -> ActivityTimeline {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let specs: [(kind: LapKind, seconds: Double, heartRate: Double, pace: Double)] = [
            (.warmup, 60, 128, 330),
            (.active, 240, 172, 248),
            (.rest, 60, 146, 420),
            (.active, 240, 178, 244),
            (.rest, 60, 148, 430),
            (.cooldown, 60, 124, 360)
        ]
        var laps: [LapRecord] = []
        var records: [ActivityRecord] = []
        var elapsed: TimeInterval = 0
        var distance = 0.0
        var previousHeartRate = specs[0].heartRate
        for (index, spec) in specs.enumerated() {
            let lapDistance = spec.seconds * 1000 / spec.pace
            laps.append(LapRecord(
                lapIndex: index,
                startElapsedTime: elapsed,
                endElapsedTime: elapsed + spec.seconds,
                startDistanceMeters: distance,
                totalDistanceMeters: lapDistance,
                totalElapsedTime: spec.seconds,
                avgPaceSecondsPerKm: spec.pace,
                avgHeartRate: Int(spec.heartRate),
                maxHeartRate: Int(spec.heartRate) + 4,
                avgCadenceSPM: 176,
                avgPowerWatts: 240,
                totalAscent: nil,
                kind: spec.kind
            ))
            for second in stride(from: elapsed, to: elapsed + spec.seconds, by: 1) {
                let fraction = (second - elapsed) / spec.seconds
                // Heart rate eases toward the lap target instead of jumping.
                let ease = min(fraction * 4, 1)
                let heartRate = previousHeartRate + (spec.heartRate - previousHeartRate) * ease
                records.append(record(
                    at: second,
                    start: start,
                    distance: distance + lapDistance * fraction,
                    heartRate: heartRate + 2 * sin(second / 7),
                    pace: spec.pace + 6 * sin(second / 23)
                ))
            }
            previousHeartRate = spec.heartRate
            elapsed += spec.seconds
            distance += lapDistance
        }
        records.append(record(
            at: elapsed,
            start: start,
            distance: distance,
            heartRate: specs[specs.count - 1].heartRate,
            pace: specs[specs.count - 1].pace
        ))
        return ActivityTimeline(
            startDate: start,
            duration: elapsed,
            distanceMeters: distance,
            records: records,
            laps: laps
        )
    }

    /// Fixed weather so weather components preview without any network.
    static let weather = WeatherPayload(
        condition: .partlyCloudy,
        temperatureCelsius: 18,
        humidity: 62,
        highTemperatureCelsius: 21,
        lowTemperatureCelsius: 12,
        windKph: 11,
        feelsLikeCelsius: 17,
        resolvedLocation: "Sample City",
        sourceDate: nil
    )

    private static func record(
        at elapsed: TimeInterval,
        start: Date,
        distance: Double,
        heartRate: Double,
        pace: Double
    ) -> ActivityRecord {
        // A fictional loop over open ocean, away from any real route.
        let angle = elapsed / 720 * 2 * .pi
        return ActivityRecord(
            elapsedTime: elapsed,
            timestamp: start.addingTimeInterval(elapsed),
            distanceMeters: distance,
            heartRate: Int(heartRate.rounded()),
            paceSecondsPerKilometer: pace,
            elevationMeters: 20 + 8 * sin(elapsed / 90),
            cadence: 176,
            powerWatts: 240,
            calories: elapsed / 4,
            latitude: 0.5 + 0.006 * sin(angle) + 0.0015 * sin(angle * 3),
            longitude: -30.5 + 0.008 * cos(angle)
        )
    }
}
