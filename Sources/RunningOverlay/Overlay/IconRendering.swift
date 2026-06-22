import AppKit
import CoreGraphics
import Lottie
import SwiftUI

// MARK: - IconRendering
//
// Single rendering contract for icons across overlay components. The Phase
// C1 smoke-test gate (`IconRenderingSmokeTests`) confirmed that macOS-native
// `NSImage(contentsOf:)` correctly rasterizes SVG fixtures via both the
// SwiftUI preview path and the offscreen `CGContext` export path on macOS
// 15+, so this module stays dependency-free for SVG.
//
// Lottie support is deliberately stubbed in `IconRenderer.draw` and
// `IconView`; adding the `lottie-spm` dependency happens in Phase C6 once
// we have a parallel smoke test that confirms Lottie's CALayer renderer
// plays inside a non-window-backed offscreen `CGContext` during export.
//
// Two parallel render paths share one request struct:
//   • `IconView`        — SwiftUI view, used by live preview & ImageRenderer
//                         export
//   • `IconRenderer.draw` — Core Graphics path, used by any future direct
//                         CGContext renderer (kept for future flexibility,
//                         e.g., custom video composition without SwiftUI)
//
// The contract is component-agnostic: rect + asset + tint + animationTime
// → pixels. Decor Icon (Phase D) is the first consumer; DistanceTimeline
// lower-third / RunningGauge / numeric overlay leading icons can plug in
// later without per-component duplication.

/// Inputs to a single icon render. `tint == nil` means "preserve original
/// colors" — applies only to multicolor SVGs; SF Symbols always tint.
struct IconRenderRequest {
    var asset: IconAsset
    var rect: CGRect
    /// Tint color. SF Symbols always honor this. SVGs honor it when
    /// `preserveSVGColors` is false. Lottie is unaffected.
    var tint: NSColor?
    /// When true, multicolor SVG fills are preserved instead of being
    /// flattened to the tint. SF Symbols ignore this flag.
    var preserveSVGColors: Bool = false
    /// Lottie playback time (seconds). Ignored by all other asset kinds.
    /// Driven by the host element's elapsed activity time so animation
    /// progress is deterministic across export and preview.
    var animationTime: TimeInterval = 0
    /// Aspect-fit policy applied when the asset's intrinsic aspect doesn't
    /// match `rect`. SF Symbols are configured for `.fit`-like behavior
    /// natively, so this primarily affects raster/SVG paths.
    var contentMode: IconContentMode = .fit
}

// MARK: - SwiftUI path

/// SwiftUI view that resolves an `IconAsset` and draws it inside the host
/// frame. Use this from any overlay component's body — same call site shape
/// regardless of asset kind.
struct IconView: View {
    let request: IconRenderRequest

    init(request: IconRenderRequest) {
        self.request = request
    }

    /// Convenience initializer for the common case: build from an asset and
    /// an explicit pixel rect, with optional tint.
    init(
        asset: IconAsset,
        rect: CGRect,
        tint: NSColor? = nil,
        preserveSVGColors: Bool = false,
        contentMode: IconContentMode = .fit,
        animationTime: TimeInterval = 0
    ) {
        self.request = IconRenderRequest(
            asset: asset,
            rect: rect,
            tint: tint,
            preserveSVGColors: preserveSVGColors,
            animationTime: animationTime,
            contentMode: contentMode
        )
    }

    var body: some View {
        Group {
            switch request.asset {
            case .none:
                Color.clear
            case .sfSymbol(let name, let weight, let scale):
                sfSymbolView(name: name, weight: weight, scale: scale)
            case .bundledSVG(let name):
                if let image = IconAssetResolver.bundledSVGImage(name: name) {
                    rasterImageView(image)
                } else {
                    Color.clear
                }
            case .bundledImage(let name, let fileExtension):
                if let image = IconAssetResolver.bundledImage(name: name, fileExtension: fileExtension) {
                    rasterImageView(image)
                } else {
                    Color.clear
                }
            case .userStaticSVG(let id):
                if let url = IconAssetResolver.userAssetURL(id: id),
                   let image = NSImage(contentsOf: url) {
                    rasterImageView(image)
                } else {
                    Color.clear
                }
            case .userLottie(let id):
                if let url = IconAssetResolver.userAssetURL(id: id),
                   let anim = LottieAnimation.filepath(url.path) {
                    lottieView(animation: anim)
                } else {
                    Color.clear
                }
            }
        }
        .frame(width: request.rect.width, height: request.rect.height)
    }

    @ViewBuilder
    private func sfSymbolView(name: String, weight: SymbolWeight, scale: SymbolScale) -> some View {
        // Size the symbol to the larger of the rect dimensions; SwiftUI's
        // `.font(.system(size:weight:))` controls glyph point size.
        let pointSize = min(request.rect.width, request.rect.height) * 0.92
        let img = Image(systemName: name)
            .font(.system(size: pointSize, weight: weight.swiftUIWeight))
            .imageScale(scale.swiftUIScale)
        if let tint = request.tint {
            img.foregroundStyle(Color(nsColor: tint))
        } else {
            img
        }
    }

    @ViewBuilder
    private func lottieView(animation: LottieAnimation) -> some View {
        LottieView(animation: animation)
    }

    @ViewBuilder
    private func rasterImageView(_ image: NSImage) -> some View {
        let view = Image(nsImage: image)
            .resizable()
            .interpolation(.high)
        switch request.contentMode {
        case .fit:
            view.scaledToFit()
        case .fill:
            view.scaledToFill()
        case .stretch:
            view
        }
    }
}

// MARK: - Core Graphics path

/// Direct `CGContext` renderer. Kept alongside `IconView` so non-SwiftUI
/// consumers (e.g. future custom video compositors) have a single contract
/// to call. Today the export pipeline is SwiftUI-based, so most callers
/// will use `IconView` instead.
enum IconRenderer {
    static func draw(_ request: IconRenderRequest, in ctx: CGContext) {
        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsCtx
        defer { NSGraphicsContext.restoreGraphicsState() }

        switch request.asset {
        case .none:
            return
        case .sfSymbol(let name, let weight, let scale):
            drawSFSymbol(name: name, weight: weight, scale: scale, request: request)
        case .bundledSVG(let name):
            if let image = IconAssetResolver.bundledSVGImage(name: name) {
                drawNSImage(image, request: request)
            }
        case .bundledImage(let name, let fileExtension):
            if let image = IconAssetResolver.bundledImage(name: name, fileExtension: fileExtension) {
                drawNSImage(image, request: request)
            }
        case .userStaticSVG(let id):
            if let url = IconAssetResolver.userAssetURL(id: id),
               let image = NSImage(contentsOf: url) {
                drawNSImage(image, request: request)
            }
        case .userLottie(let id):
            if let url = IconAssetResolver.userAssetURL(id: id),
               let animation = LottieAnimation.filepath(url.path) {
                drawLottie(animation: animation, request: request)
            }
        }
    }

    private static func drawLottie(
        animation: LottieAnimation,
        request: IconRenderRequest
    ) {
        let config = LottieConfiguration(renderingEngine: .mainThread)
        let view = LottieAnimationView(animation: animation, configuration: config)
        view.frame = CGRect(origin: .zero, size: request.rect.size)
        let fraction = animation.duration > 0
            ? min(max(request.animationTime / animation.duration, 0), 1)
            : 0
        view.currentProgress = fraction
        view.layoutSubtreeIfNeeded()
        // Best-effort: the mainThread engine renders via CoreGraphics
        // only when the view has a window. The export pipeline uses the
        // SwiftUI IconView path (LottieView) which works correctly.
        view.display()
        view.layer?.render(in: NSGraphicsContext.current!.cgContext)
    }

    private static func drawSFSymbol(
        name: String,
        weight: SymbolWeight,
        scale: SymbolScale,
        request: IconRenderRequest
    ) {
        let pointSize = min(request.rect.width, request.rect.height) * 0.92
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight.nsFontWeight)
            .applying(.init(scale: scale.nsSymbolScale))
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        else { return }

        // Tint by drawing the symbol mask into a tinted color rect when a
        // tint is supplied; otherwise draw with default rendering.
        let tinted: NSImage
        if let tint = request.tint {
            tinted = NSImage(size: base.size, flipped: false) { rect in
                tint.set()
                rect.fill()
                base.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
                return true
            }
        } else {
            tinted = base
        }
        let target = aspectFitRect(intrinsicSize: base.size, in: request.rect, mode: request.contentMode)
        tinted.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1)
    }

    private static func drawNSImage(_ image: NSImage, request: IconRenderRequest) {
        // SVG-specific tinting: only apply when caller asked for it AND
        // didn't ask to preserve original colors.
        let target = aspectFitRect(intrinsicSize: image.size, in: request.rect, mode: request.contentMode)
        if let tint = request.tint, !request.preserveSVGColors {
            let tinted = NSImage(size: image.size, flipped: false) { rect in
                tint.set()
                rect.fill()
                image.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
                return true
            }
            tinted.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1)
        } else {
            image.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1)
        }
    }

    /// Compute the destination rect that satisfies the requested
    /// `IconContentMode` given the asset's intrinsic size.
    static func aspectFitRect(intrinsicSize: CGSize, in rect: CGRect, mode: IconContentMode) -> CGRect {
        guard intrinsicSize.width > 0, intrinsicSize.height > 0 else { return rect }
        switch mode {
        case .stretch:
            return rect
        case .fit:
            let s = min(rect.width / intrinsicSize.width, rect.height / intrinsicSize.height)
            let w = intrinsicSize.width * s
            let h = intrinsicSize.height * s
            return CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
        case .fill:
            let s = max(rect.width / intrinsicSize.width, rect.height / intrinsicSize.height)
            let w = intrinsicSize.width * s
            let h = intrinsicSize.height * s
            return CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
        }
    }
}

// MARK: - Asset resolution

/// Centralized lookups so both render paths share one resolution policy.
enum IconAssetResolver {
    /// Resolve a bundled SVG by base name (no extension). Looks under
    /// `Resources/Icons/` in the executable's resource bundle.
    static func bundledSVGImage(name: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "svg", subdirectory: "Icons")
            ?? Bundle.module.url(forResource: name, withExtension: "svg")
        else { return nil }
        return NSImage(contentsOf: url)
    }

    /// Resolve a bundled raster image by base name and extension. Looks under
    /// `Resources/Icons/` in the executable's resource bundle.
    static func bundledImage(name: String, fileExtension: String = "png") -> NSImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: fileExtension, subdirectory: "Icons")
            ?? Bundle.module.url(forResource: name, withExtension: fileExtension)
        else { return nil }
        return NSImage(contentsOf: url)
    }

    /// Resolve a user-uploaded asset to a file URL. Set `userAssets` and
    /// `projectURL` via `configure(userAssets:projectURL:)` from the active
    /// `ProjectDocument` when the project loads/changes.
    nonisolated(unsafe) private static var _userAssets: [UserAsset] = []
    nonisolated(unsafe) private static var _projectURL: URL?

    @MainActor
    static func configure(userAssets: [UserAsset], projectURL: URL?) {
        _userAssets = userAssets
        _projectURL = projectURL
    }

    static func userAssetURL(id: UUID) -> URL? {
        guard let asset = _userAssets.first(where: { $0.id == id }) else { return nil }
        return UserAssetStore.url(for: asset, projectURL: _projectURL)
    }
}

// MARK: - SymbolWeight / SymbolScale bridges

extension SymbolWeight {
    var swiftUIWeight: Font.Weight {
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
        }
    }

    var nsFontWeight: NSFont.Weight {
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
        }
    }
}

extension SymbolScale {
    var swiftUIScale: Image.Scale {
        switch self {
        case .small: .small
        case .medium: .medium
        case .large: .large
        }
    }

    var nsSymbolScale: NSImage.SymbolScale {
        switch self {
        case .small: .small
        case .medium: .medium
        case .large: .large
        }
    }
}
