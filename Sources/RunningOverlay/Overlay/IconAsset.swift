import Foundation

// MARK: - IconAsset
//
// Component-agnostic icon descriptor. Any overlay component that wants to
// embed an icon (Decor Icon today; future DistanceTimeline lower-third,
// RunningGauge center glyph, numeric overlay leading icon) holds a single
// `IconAsset` value on its style sub-struct and lets the shared
// `IconRendering` API turn it into pixels.
//
// Design intent: a value-type, equatable, fully Codable enum so that an
// `IconAsset` round-trips cleanly through `OverlayTemplate` JSON, can be
// embedded inside any `OverlayStyle` field without polluting the namespace,
// and can be diffed by SwiftUI's `@Equatable` view tracking.
//
// **Phase C scope**: SF Symbols, bundled SVG, and bundled raster image paths
// are wired end-to-end.
// User-uploaded SVG resolution waits on the Phase E `UserAssetStore`. Lottie
// (`userLottie`) is reserved in the data model so existing projects stay
// forward-compatible, but its renderer is a stub — adding `lottie-spm` and
// the animation path is gated on a Phase C6 smoke test.
//
// See `~/.claude/plans/overlay-pool-solid-color-layout-bg-effe-shiny-pudding.md`.

/// Symbol weight options for SF Symbols. Subset of `NSFont.Weight` chosen
/// to mirror what the SwiftUI inspector exposes.
enum SymbolWeight: String, CaseIterable, Identifiable, Codable {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ultraLight: "Ultra Light"
        case .thin: "Thin"
        case .light: "Light"
        case .regular: "Regular"
        case .medium: "Medium"
        case .semibold: "Semibold"
        case .bold: "Bold"
        case .heavy: "Heavy"
        case .black: "Black"
        }
    }
}

/// Symbol scale variants offered by SF Symbols. Maps directly to
/// `NSImage.SymbolScale`.
enum SymbolScale: String, CaseIterable, Identifiable, Codable {
    case small, medium, large

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }
}

/// Aspect-fit policy for icons whose intrinsic aspect ratio doesn't match
/// the host rect. `.fit` preserves aspect inside the rect, `.fill` covers
/// the rect (may crop), `.stretch` distorts.
enum IconContentMode: String, CaseIterable, Identifiable, Codable {
    case fit, fill, stretch

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fit: "Fit"
        case .fill: "Fill"
        case .stretch: "Stretch"
        }
    }
}

/// The single Codable union describing what icon to draw. Any overlay
/// component that wants an icon slot embeds one of these on its style
/// sub-struct.
///
/// Cases:
/// - `none` — no icon (default).
/// - `sfSymbol` — SF Symbols glyph; rendered via
///   `NSImage(systemSymbolName:accessibilityDescription:)` configured with a
///   `SymbolConfiguration`.
/// - `userStaticSVG` — points at a `.svg` file owned by `UserAssetStore`
///   (Phase E). Resolves to a file URL via the project's asset index.
/// - `userLottie` — points at a `.json` Lottie asset; rendered through
///   `lottie-spm` once the dependency lands (Phase C6).
/// - `bundledSVG` — looks up a `.svg` file shipped under
///   `Resources/Icons/<name>.svg`.
/// - `bundledImage` — looks up a raster image file shipped under
///   `Resources/Icons/<name>.<fileExtension>`.
enum IconAsset: Equatable, Codable {
    case none
    case sfSymbol(name: String, weight: SymbolWeight = .regular, scale: SymbolScale = .medium)
    case userStaticSVG(assetID: UUID)
    case userLottie(assetID: UUID)
    case bundledSVG(name: String)
    case bundledImage(name: String, fileExtension: String = "png")

    // MARK: Codable
    //
    // We hand-roll Codable so the on-disk shape is a discriminated union
    // (`{ "kind": "sfSymbol", "name": "star", … }`) instead of Swift's
    // default keyed-by-case-name layout. That gives us a stable JSON schema
    // older builds can still parse via `decodeIfPresent` defaults.

    private enum Kind: String, Codable {
        case none
        case sfSymbol
        case userStaticSVG
        case userLottie
        case bundledSVG
        case bundledImage
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case name
        case fileExtension
        case weight
        case scale
        case assetID
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try c.encode(Kind.none, forKey: .kind)
        case .sfSymbol(let name, let weight, let scale):
            try c.encode(Kind.sfSymbol, forKey: .kind)
            try c.encode(name, forKey: .name)
            try c.encode(weight, forKey: .weight)
            try c.encode(scale, forKey: .scale)
        case .userStaticSVG(let id):
            try c.encode(Kind.userStaticSVG, forKey: .kind)
            try c.encode(id, forKey: .assetID)
        case .userLottie(let id):
            try c.encode(Kind.userLottie, forKey: .kind)
            try c.encode(id, forKey: .assetID)
        case .bundledSVG(let name):
            try c.encode(Kind.bundledSVG, forKey: .kind)
            try c.encode(name, forKey: .name)
        case .bundledImage(let name, let fileExtension):
            try c.encode(Kind.bundledImage, forKey: .kind)
            try c.encode(name, forKey: .name)
            try c.encode(fileExtension, forKey: .fileExtension)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .none:
            self = .none
        case .sfSymbol:
            let name = try c.decode(String.self, forKey: .name)
            let weight = try c.decodeIfPresent(SymbolWeight.self, forKey: .weight) ?? .regular
            let scale = try c.decodeIfPresent(SymbolScale.self, forKey: .scale) ?? .medium
            self = .sfSymbol(name: name, weight: weight, scale: scale)
        case .userStaticSVG:
            let id = try c.decode(UUID.self, forKey: .assetID)
            self = .userStaticSVG(assetID: id)
        case .userLottie:
            let id = try c.decode(UUID.self, forKey: .assetID)
            self = .userLottie(assetID: id)
        case .bundledSVG:
            let name = try c.decode(String.self, forKey: .name)
            self = .bundledSVG(name: name)
        case .bundledImage:
            let name = try c.decode(String.self, forKey: .name)
            let fileExtension = try c.decodeIfPresent(String.self, forKey: .fileExtension) ?? "png"
            self = .bundledImage(name: name, fileExtension: fileExtension)
        }
    }
}
