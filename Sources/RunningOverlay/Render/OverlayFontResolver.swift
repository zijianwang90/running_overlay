import AppKit

enum OverlayFontResolver {
    static func appKitFont(family: String, size: Double, weight: NSFont.Weight) -> NSFont {
        let normalized = family.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isSystemUIFontFamily {
            return .systemFont(ofSize: size, weight: weight)
        }

        if let font = fontMatchingFamily(normalized, size: size, weight: weight) {
            return font
        }

        return NSFont(name: normalized, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }

    private static func fontMatchingFamily(_ family: String, size: Double, weight: NSFont.Weight) -> NSFont? {
        let descriptor = NSFontDescriptor(fontAttributes: [
            .family: family,
            .traits: [NSFontDescriptor.TraitKey.weight: weight.rawValue]
        ])
        if let font = NSFont(descriptor: descriptor, size: size), font.familyName == family {
            return font
        }

        guard let exactFont = NSFont(name: family, size: size),
              let exactFamily = exactFont.familyName
        else {
            return nil
        }
        let exactDescriptor = NSFontDescriptor(fontAttributes: [
            .family: exactFamily,
            .traits: [NSFontDescriptor.TraitKey.weight: weight.rawValue]
        ])
        return NSFont(descriptor: exactDescriptor, size: size) ?? exactFont
    }
}
extension String {
    var isSystemUIFontFamily: Bool {
        let normalized = trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == ".apple-system"
            || normalized == "system"
            || normalized == "system font"
            || normalized == "sf pro"
            || normalized == "sf pro display"
            || normalized == "sf pro text"
            || normalized == "sf pro rounded"
    }
}
