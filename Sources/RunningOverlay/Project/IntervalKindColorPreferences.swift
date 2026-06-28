import Foundation
import SwiftUI

/// Snapshot of the four user-tunable interval kind colors. Safe to read from
/// non-main contexts during export.
struct IntervalKindColorPalette: Equatable {
    var warmup: OverlayColor
    var active: OverlayColor
    var rest: OverlayColor
    var cooldown: OverlayColor

    /// Defaults mirror the FIT track colors used on the project timeline so
    /// that the overlay color scheme matches the canvas out of the box.
    static let `default` = IntervalKindColorPalette(
        warmup: OverlayColor(red: 58.0 / 255, green: 166.0 / 255, blue: 163.0 / 255, alpha: 1),
        active: OverlayColor(red: 231.0 / 255, green: 122.0 / 255, blue: 60.0 / 255, alpha: 1),
        rest: OverlayColor(red: 79.0 / 255, green: 130.0 / 255, blue: 199.0 / 255, alpha: 1),
        cooldown: OverlayColor(red: 122.0 / 255, green: 106.0 / 255, blue: 216.0 / 255, alpha: 1)
    )

    func color(for kind: LapKind) -> OverlayColor? {
        switch kind {
        case .warmup: warmup
        case .active: active
        case .rest: rest
        case .cooldown: cooldown
        case .unknown: nil
        }
    }
}

@MainActor
@Observable
final class IntervalKindColorPreferences {
    static let shared = IntervalKindColorPreferences()

    nonisolated private static let storageKey = "intervalKindColors.palette.v1"

    var warmupColor: OverlayColor { didSet { persist() } }
    var activeColor: OverlayColor { didSet { persist() } }
    var restColor: OverlayColor { didSet { persist() } }
    var cooldownColor: OverlayColor { didSet { persist() } }

    private init() {
        let stored = Self.loadPersistedPalette() ?? .default
        warmupColor = stored.warmup
        activeColor = stored.active
        restColor = stored.rest
        cooldownColor = stored.cooldown
    }

    var palette: IntervalKindColorPalette {
        IntervalKindColorPalette(
            warmup: warmupColor,
            active: activeColor,
            rest: restColor,
            cooldown: cooldownColor
        )
    }

    func resetToDefaults() {
        let d = IntervalKindColorPalette.default
        warmupColor = d.warmup
        activeColor = d.active
        restColor = d.rest
        cooldownColor = d.cooldown
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(palette) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    nonisolated static func currentSnapshot() -> IntervalKindColorPalette {
        loadPersistedPalette() ?? .default
    }

    nonisolated private static func loadPersistedPalette() -> IntervalKindColorPalette? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let palette = try? JSONDecoder().decode(IntervalKindColorPalette.self, from: data) else {
            return nil
        }
        return palette
    }
}

extension IntervalKindColorPalette: Codable {}
