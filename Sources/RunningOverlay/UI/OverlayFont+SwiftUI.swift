import AppKit
import SwiftUI

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

extension Font {
    static func overlayFont(family: String, size: Double, overlayWeight: OverlayFontWeight) -> Font {
        overlayFont(family: family, size: size, weight: overlayWeight.overlaySwiftUIFontWeight)
    }

    static func overlayFont(family: String, size: Double, weight: Font.Weight) -> Font {
        if family.isSystemUIFontFamily {
            return .system(size: size, weight: weight)
        }
        let font = OverlayFontResolver.appKitFont(family: family, size: size, weight: weight.overlayAppKitWeight)
        return .custom(font.fontName, size: size)
    }
}

extension OverlayFontWeight {
    var overlaySwiftUIFontWeight: Font.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }
}

private extension String {
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

private extension Font.Weight {
    var overlayAppKitWeight: NSFont.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
    }
}
