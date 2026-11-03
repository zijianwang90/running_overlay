#if canImport(CSkiaBridge)
import Foundation
@testable import RunningOverlay

/// Seeds UserDefaults-backed overlay preferences so golden frames are
/// deterministic, then restores the previous values. Production code keeps
/// reading the same keys through `currentSnapshot()`.
enum OverlayPreferenceFixtures {
    private static let keys = [
        "heartRateZones.zoneCount",
        "heartRateZones.paceUnit",
        "heartRateZones.zones",
        "heartRateZones.thresholdHR",
        "heartRateZones.thresholdPaceSecPerKm",
        "intervalKindColors.palette.v1"
    ]

    static func withDefaults<T>(_ body: () throws -> T) rethrows -> T {
        let defaults = UserDefaults.standard
        let previous = save(defaults)
        seed(defaults)
        defer { restore(defaults, previous: previous) }
        return try body()
    }

    static func withDefaults<T>(_ body: () async throws -> T) async rethrows -> T {
        let defaults = UserDefaults.standard
        let previous = save(defaults)
        seed(defaults)
        defer { restore(defaults, previous: previous) }
        return try await body()
    }

    private static func save(_ defaults: UserDefaults) -> [(String, Any?)] {
        keys.map { ($0, defaults.object(forKey: $0)) }
    }

    private static func restore(
        _ defaults: UserDefaults,
        previous: [(String, Any?)]
    ) {
        for (key, value) in previous {
            if let value {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }

    private static func seed(_ defaults: UserDefaults) {
        let snapshot = HeartRateZonePreferences.defaultSnapshot
        defaults.set(snapshot.zoneCount, forKey: keys[0])
        defaults.set(snapshot.paceUnit.rawValue, forKey: keys[1])
        if let data = try? JSONEncoder().encode(snapshot.zones) {
            defaults.set(data, forKey: keys[2])
        }
        if let thresholdHR = snapshot.thresholdHR {
            defaults.set(thresholdHR, forKey: keys[3])
        } else {
            defaults.removeObject(forKey: keys[3])
        }
        if let pace = snapshot.thresholdPaceSecPerKm {
            defaults.set(pace, forKey: keys[4])
        } else {
            defaults.removeObject(forKey: keys[4])
        }
        if let data = try? JSONEncoder().encode(IntervalKindColorPalette.default) {
            defaults.set(data, forKey: keys[5])
        }
    }
}
#endif
