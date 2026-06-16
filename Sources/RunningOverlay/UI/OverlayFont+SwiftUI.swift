import SwiftUI

extension Font {
    static func overlayFont(family: String, size: Double, overlayWeight: OverlayFontWeight) -> Font {
        overlayFont(family: family, size: size, weight: overlayWeight.overlaySwiftUIFontWeight)
    }

    static func overlayFont(family: String, size: Double, weight: Font.Weight) -> Font {
        if family.isSystemUIFontFamily {
            return .system(size: size, weight: weight)
        }
        return .custom(family, size: size).weight(weight)
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
