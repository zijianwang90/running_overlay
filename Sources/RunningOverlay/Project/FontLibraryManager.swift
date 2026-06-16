import AppKit
import Foundation

@MainActor
@Observable
final class FontLibraryManager {
    static let shared = FontLibraryManager()

    nonisolated private static let favoritesKey = "fontLibraryFavorites"
    nonisolated private static let defaultFamilyKey = "fontLibraryDefaultFamily"
    nonisolated private static let fallbackDefaults: [String] = ["PT Mono", "Monaco", "Menlo", "Andale Mono"]

    /// Nonisolated accessor so non-@MainActor types (OverlayStyle, RunningGaugeModel)
    /// can read the current default font name from UserDefaults.
    nonisolated static var currentDefaultFamily: String {
        UserDefaults.standard.string(forKey: defaultFamilyKey) ?? fallbackDefaults[0]
    }

    var favoriteFamilies: [String] {
        didSet {
            UserDefaults.standard.set(favoriteFamilies, forKey: Self.favoritesKey)
        }
    }

    var defaultFamily: String {
        didSet {
            UserDefaults.standard.set(defaultFamily, forKey: Self.defaultFamilyKey)
        }
    }

    var defaults: [String] { Self.fallbackDefaults }

    private init() {
        let stored = UserDefaults.standard.array(forKey: Self.favoritesKey) as? [String]
        favoriteFamilies = stored ?? Self.fallbackDefaults

        let storedDefault = UserDefaults.standard.string(forKey: Self.defaultFamilyKey)
        defaultFamily = storedDefault ?? Self.fallbackDefaults[0]
    }

    var allSystemFamilies: [String] {
        NSFontManager.shared.availableFontFamilies.sorted()
    }

    func isFavorite(_ family: String) -> Bool {
        favoriteFamilies.contains(family)
    }

    func isDefault(_ family: String) -> Bool {
        defaultFamily == family
    }

    func setDefault(_ family: String) {
        defaultFamily = family
        if !isFavorite(family) {
            favoriteFamilies.append(family)
        }
    }

    func toggle(_ family: String) {
        if isFavorite(family) {
            favoriteFamilies.removeAll { $0 == family }
            if defaultFamily == family {
                defaultFamily = favoriteFamilies.first ?? Self.fallbackDefaults[0]
            }
        } else {
            favoriteFamilies.append(family)
        }
    }

    func restoreDefaults() {
        favoriteFamilies = Self.fallbackDefaults
        defaultFamily = Self.fallbackDefaults[0]
    }

    /// Safe fallback: returns defaults if the user clears all favorites.
    /// The default family is placed first in the list.
    var effectiveFavorites: [String] {
        let favs = (favoriteFamilies.isEmpty ? Self.fallbackDefaults : favoriteFamilies.sorted())
        guard let idx = favs.firstIndex(of: defaultFamily), idx > 0 else { return favs }
        var reordered = favs
        reordered.remove(at: idx)
        reordered.insert(defaultFamily, at: 0)
        return reordered
    }
}
