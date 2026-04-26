import AppKit
import CoreText
import Foundation

/// Names of bundled fonts that should be available throughout the app once
/// `BundledFonts.registerAll()` has run during app launch.
enum BundledFontName {
    /// PostScript name for the BankGothic Medium TTF used by the Digital
    /// Watch overlay preset. Mirrors the font Brian Cavalier ships with the
    /// open-source HTML5 digital-clock demo (briancavalier/digital-clock).
    static let digitalWatch = "BankGothicBT-Medium"
}

enum BundledFonts {
    /// Registers every bundled font so they can be referenced by PostScript
    /// name (e.g. `Font.custom("BankGothicBT-Medium", size: ...)` in SwiftUI
    /// or `NSFont(name:size:)` for Core Graphics export rendering).
    ///
    /// Safe to call multiple times — Core Text's font manager treats
    /// re-registration of an already-registered URL as a no-op error.
    static func registerAll() {
        let fontURLs = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in fontURLs {
            register(url)
        }
        let otfURLs = Bundle.module.urls(forResourcesWithExtension: "otf", subdirectory: nil) ?? []
        for url in otfURLs {
            register(url)
        }
    }

    private static func register(_ url: URL) {
        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if !success {
            // Surface registration failures during development but don't
            // crash production: the app falls back to the platform default
            // font when a custom face is missing.
            #if DEBUG
            if let cfError = error?.takeRetainedValue() {
                NSLog("BundledFonts: failed to register \(url.lastPathComponent): \(cfError)")
            }
            #else
            error?.release()
            #endif
        }
    }
}
