import AppKit
import SwiftUI

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
