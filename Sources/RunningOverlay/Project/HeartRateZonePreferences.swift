import Foundation
import SwiftUI

enum HRZoneCount: Int, Codable, CaseIterable, Identifiable {
    case five = 5
    case six = 6

    var id: Int { rawValue }
    var label: String { "\(rawValue)" }
}

enum PaceUnit: String, Codable, CaseIterable, Identifiable {
    case minPerKm
    case minPerMile

    var id: String { rawValue }

    var label: String {
        switch self {
        case .minPerKm: "min/km"
        case .minPerMile: "min/mile"
        }
    }

    static let metersPerMile: Double = 1609.344
}

struct HeartRateZone: Codable, Identifiable, Equatable {
    let id: UUID
    var minHR: Int?
    var maxHR: Int?
    /// Always stored as seconds per kilometer; UI converts to the active `PaceUnit` for display.
    var minPaceSecPerKm: Int?
    var maxPaceSecPerKm: Int?

    init(
        id: UUID = UUID(),
        minHR: Int? = nil,
        maxHR: Int? = nil,
        minPaceSecPerKm: Int? = nil,
        maxPaceSecPerKm: Int? = nil
    ) {
        self.id = id
        self.minHR = minHR
        self.maxHR = maxHR
        self.minPaceSecPerKm = minPaceSecPerKm
        self.maxPaceSecPerKm = maxPaceSecPerKm
    }

    static func emptySlots(count: Int = 6) -> [HeartRateZone] {
        (0..<count).map { _ in HeartRateZone() }
    }
}

enum HRZonePalette {
    static let colors: [Color] = [.blue, .cyan, .green, .yellow, .orange, .red]
    static let overlayColors: [OverlayColor] = [
        OverlayColor(red: 0.12, green: 0.56, blue: 1.00, alpha: 1),
        OverlayColor(red: 0.28, green: 0.82, blue: 0.96, alpha: 1),
        OverlayColor(red: 0.18, green: 0.86, blue: 0.42, alpha: 1),
        OverlayColor(red: 1.00, green: 0.84, blue: 0.12, alpha: 1),
        OverlayColor(red: 1.00, green: 0.56, blue: 0.20, alpha: 1),
        OverlayColor(red: 1.00, green: 0.22, blue: 0.18, alpha: 1)
    ]

    static func color(forIndex index: Int) -> Color {
        colors[max(0, min(index, colors.count - 1))]
    }

    static func overlayColor(forIndex index: Int) -> OverlayColor {
        overlayColors[max(0, min(index, overlayColors.count - 1))]
    }
}

@MainActor
@Observable
final class HeartRateZonePreferences {
    static let shared = HeartRateZonePreferences()

    nonisolated private static let zoneCountKey = "heartRateZones.zoneCount"
    nonisolated private static let paceUnitKey = "heartRateZones.paceUnit"
    nonisolated private static let zonesKey = "heartRateZones.zones"
    nonisolated private static let thresholdHRKey = "heartRateZones.thresholdHR"
    nonisolated private static let thresholdPaceKey = "heartRateZones.thresholdPaceSecPerKm"

    var zoneCount: HRZoneCount {
        didSet { UserDefaults.standard.set(zoneCount.rawValue, forKey: Self.zoneCountKey) }
    }

    var paceUnit: PaceUnit {
        didSet { UserDefaults.standard.set(paceUnit.rawValue, forKey: Self.paceUnitKey) }
    }

    /// Persistent layer always holds 6 slots so switching 5 ↔ 6 preserves the 6th zone's filled data.
    var zones: [HeartRateZone] {
        didSet {
            if let data = try? JSONEncoder().encode(zones) {
                UserDefaults.standard.set(data, forKey: Self.zonesKey)
            }
        }
    }

    var thresholdHR: Int? {
        didSet {
            if let v = thresholdHR {
                UserDefaults.standard.set(v, forKey: Self.thresholdHRKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.thresholdHRKey)
            }
        }
    }

    /// Stored as seconds-per-km regardless of the active `PaceUnit`.
    var thresholdPaceSecPerKm: Int? {
        didSet {
            if let v = thresholdPaceSecPerKm {
                UserDefaults.standard.set(v, forKey: Self.thresholdPaceKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.thresholdPaceKey)
            }
        }
    }

    private init() {
        let storedCount = UserDefaults.standard.object(forKey: Self.zoneCountKey) as? Int
        zoneCount = storedCount.flatMap(HRZoneCount.init(rawValue:)) ?? .five

        let storedUnit = UserDefaults.standard.string(forKey: Self.paceUnitKey)
        paceUnit = storedUnit.flatMap(PaceUnit.init(rawValue:)) ?? .minPerKm

        if let data = UserDefaults.standard.data(forKey: Self.zonesKey),
           let decoded = try? JSONDecoder().decode([HeartRateZone].self, from: data) {
            var padded = decoded
            while padded.count < 6 { padded.append(HeartRateZone()) }
            zones = Array(padded.prefix(6))
        } else {
            zones = HeartRateZone.emptySlots()
        }

        thresholdHR = UserDefaults.standard.object(forKey: Self.thresholdHRKey) as? Int
        thresholdPaceSecPerKm = UserDefaults.standard.object(forKey: Self.thresholdPaceKey) as? Int
    }

    /// Clears HR + pace values within the currently-visible zone range, leaving the rest untouched.
    func resetVisibleZones() {
        for i in 0..<zoneCount.rawValue where i < zones.count {
            zones[i] = HeartRateZone(id: zones[i].id)
        }
    }

    nonisolated static func currentSnapshot() -> HeartRateZoneSnapshot {
        let defaults = UserDefaults.standard
        let storedCount = defaults.object(forKey: zoneCountKey) as? Int
        let zoneCount = storedCount.flatMap(HRZoneCount.init(rawValue:))?.rawValue ?? HRZoneCount.five.rawValue
        let storedUnit = defaults.string(forKey: paceUnitKey)
        let paceUnit = storedUnit.flatMap(PaceUnit.init(rawValue:)) ?? .minPerKm
        let zones: [HeartRateZone]
        if let data = defaults.data(forKey: zonesKey),
           let decoded = try? JSONDecoder().decode([HeartRateZone].self, from: data) {
            var padded = decoded
            while padded.count < 6 { padded.append(HeartRateZone()) }
            zones = Array(padded.prefix(6))
        } else {
            zones = HeartRateZone.emptySlots()
        }
        return HeartRateZoneSnapshot(zoneCount: zoneCount, paceUnit: paceUnit, zones: zones)
    }
}

// MARK: - Pace conversion helpers

enum PaceConversion {
    static func secondsPerKm(from secondsPerUnit: Int, unit: PaceUnit) -> Int {
        switch unit {
        case .minPerKm: return secondsPerUnit
        case .minPerMile:
            // sec/mile → sec/km: divide by miles-per-km (i.e. multiply by km/mile = 1/1.609344)
            return Int((Double(secondsPerUnit) / (PaceUnit.metersPerMile / 1000.0)).rounded())
        }
    }

    static func secondsPerUnit(fromSecondsPerKm secondsPerKm: Int, unit: PaceUnit) -> Int {
        switch unit {
        case .minPerKm: return secondsPerKm
        case .minPerMile:
            return Int((Double(secondsPerKm) * (PaceUnit.metersPerMile / 1000.0)).rounded())
        }
    }

    static func format(secondsPerKm: Int?, unit: PaceUnit) -> String {
        guard let s = secondsPerKm else { return "" }
        let total = secondsPerUnit(fromSecondsPerKm: s, unit: unit)
        let m = total / 60
        let sec = total % 60
        return String(format: "%d:%02d", m, sec)
    }

    /// Parses "m:ss" or "mm:ss" (also accepts a bare integer treated as minutes). Returns nil if invalid/empty.
    static func parse(_ text: String, unit: PaceUnit) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        let parts = trimmed.split(separator: ":")
        let totalPerUnit: Int
        if parts.count == 1, let m = Int(parts[0]) {
            totalPerUnit = m * 60
        } else if parts.count == 2,
                  let m = Int(parts[0]),
                  let s = Int(parts[1]),
                  s >= 0, s < 60 {
            totalPerUnit = m * 60 + s
        } else {
            return nil
        }
        return secondsPerKm(from: totalPerUnit, unit: unit)
    }
}
