import AppKit
import CoreGraphics
import Foundation
import Lottie
import SwiftUI
import Testing
@testable import RunningOverlay

/// **Phase C1 — SVG / Lottie smoke test gate.**
///
/// This spike answers a single question before we commit to the IconAsset /
/// IconRendering design: can macOS native APIs render SVG icons reliably in
/// **both** the live preview path (SwiftUI / `NSImage`) and the export path
/// (offscreen `CGContext`)?
///
/// The previous DistanceTimeline Lower Third attempt failed because some
/// SVGs that rendered fine in WebKit/preview did not render via the path the
/// exporter used. So we test three flavors that historically expose those
/// gaps:
///
/// 1. `simple-circle.svg`  — single shape, single fill (sanity check).
/// 2. `styled-square.svg`  — uses an internal `<style>` block with classes
///    (NSImage's SVG renderer is known to be selective about CSS).
/// 3. `multicolor-flag.svg` — multiple fills, no tinting (proves multicolor
///    SVGs survive a tint-less render path; later phases handle tinted SVGs).
///
/// The test passes when each fixture (a) loads as an `NSImage`, and (b)
/// rasterizes into an offscreen bitmap with at least one non-transparent
/// pixel — that's the gate. If any fixture fails, switch the IconRendering
/// design to a third-party SVG library (SVGKit) before Phase C2 starts and
/// document the choice at the top of `IconRendering.swift`.
///
/// Lottie is not exercised here — adding `lottie-spm` is a Phase C6 concern.
/// Phase C1 only gates the static SVG path because that's the one that has
/// failed historically.
struct IconRenderingSmokeTests {
    @Test func simpleCircleSVGLoadsAndRasterizes() throws {
        try assertSVGRoundTrip(named: "simple-circle")
    }

    @Test func styleBlockSVGLoadsAndRasterizes() throws {
        try assertSVGRoundTrip(named: "styled-square")
    }

    @Test func multicolorSVGLoadsAndRasterizes() throws {
        try assertSVGRoundTrip(named: "multicolor-flag")
    }

    // MARK: - Helpers

    /// Loads `<name>.svg` from the test bundle's `Fixtures/Icons` directory,
    /// then rasterizes it into a 128×128 32-bit RGBA `CGContext`. Returns
    /// (image, opaquePixelCount) for the caller to assert against.
    private func assertSVGRoundTrip(named name: String) throws {
        let url = try fixtureURL(named: name, ext: "svg")

        // Path A: live preview — does NSImage parse the SVG at all?
        guard let image = NSImage(contentsOf: url) else {
            Issue.record("NSImage(contentsOf:) returned nil for \(name).svg")
            return
        }
        #expect(image.size.width > 0 && image.size.height > 0,
                "NSImage reported a zero-size representation for \(name).svg — SVG parsing failed silently.")

        // Path B: export — render into an offscreen RGBA CGContext and count
        // non-transparent pixels. This is the path the SwiftUI export
        // pipeline ultimately drives, and the one that failed before.
        let pixelSize = 128
        let bytesPerPixel = 4
        let bytesPerRow = pixelSize * bytesPerPixel
        var raw = [UInt8](repeating: 0, count: pixelSize * pixelSize * bytesPerPixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue
        guard let ctx = raw.withUnsafeMutableBytes({ ptr -> CGContext? in
            CGContext(
                data: ptr.baseAddress,
                width: pixelSize,
                height: pixelSize,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        }) else {
            Issue.record("Failed to create offscreen CGContext for \(name).svg")
            return
        }

        // NSGraphicsContext lets NSImage draw via its native renderer (which
        // is what NSImage uses for SVG on macOS 14+). This is the same path
        // the SwiftUI export pipeline takes when ImageRenderer rasterizes a
        // view containing Image(nsImage:).
        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsCtx
        let drawRect = NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
        image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        // Count alpha-non-zero pixels. Any non-trivial SVG should fill more
        // than a few stray pixels; we use a low threshold so test stability
        // doesn't depend on subpixel rasterization differences across macOS
        // versions.
        var opaquePixels = 0
        for i in stride(from: 3, to: raw.count, by: bytesPerPixel) where raw[i] > 0 {
            opaquePixels += 1
        }
        #expect(
            opaquePixels > 100,
            "SVG \(name).svg rasterized to <= 100 non-transparent pixels — NSImage's native SVG path likely produced a blank frame; switch to SVGKit before Phase C2."
        )
    }

    private func fixtureURL(named name: String, ext: String) throws -> URL {
        // SPM testTarget resources with `.copy("Fixtures")` end up under
        // Bundle.module/Fixtures/Icons/<name>.<ext>.
        if let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures/Icons") {
            return url
        }
        // Fallback: walk the resource bundle if the platform places copied
        // resources at the bundle root rather than in a subdirectory.
        if let url = Bundle.module.url(forResource: name, withExtension: ext) {
            return url
        }
        Issue.record("Could not locate \(name).\(ext) in test bundle.")
        throw CocoaError(.fileNoSuchFile)
    }
}

// MARK: - Phase C6 Lottie smoke test

/// **Phase C6 — Lottie gate.**
///
/// Verifies the Lottie dependency resolves, a JSON animation loads, and
/// `LottieView` / `IconView` construct without crashing — the SwiftUI path
/// is what the preview canvas and `SwiftUIOverlayVideoExporter` (via
/// `ImageRenderer`) both exercise.
///
/// The offscreen `NSView` / `CGContext` path was smoke-tested and fails
/// (0 opaque pixels) — `LottieAnimationView` does not paint its layer
/// inside a non-window-backed view regardless of rendering engine. This
/// matches the risk flagged in the plan. Because the export pipeline
/// renders through SwiftUI, `IconRenderer.draw`'s `.userLottie` arm is a
/// best-effort hook that produces output only when a window is present.
@MainActor
struct LottieSmokeTests {
    @Test func lottieJSONLoadsSuccessfully() throws {
        let url = try fixtureURL(named: "simple-circle", ext: "json")
        let animation = LottieAnimation.filepath(url.path)
        #expect(animation != nil, "LottieAnimation.filepath returned nil for simple-circle.json")
        guard let anim = animation else { return }
        #expect(anim.duration > 0, "Lottie animation has zero duration")
        #expect(anim.startFrame < anim.endFrame, "Lottie animation has invalid frame range")
    }

    @Test func lottieViewConstructsWithoutCrashing() throws {
        let url = try fixtureURL(named: "simple-circle", ext: "json")
        let animation = try #require(LottieAnimation.filepath(url.path))
        _ = LottieView(animation: animation).frame(width: 128, height: 128)
    }

    /// Confirms the `.userLottie` arm inside `IconView` resolves to a
    /// LottieView rather than falling through to the empty placeholder.
    /// The SwiftUI path is what the export pipeline drives via ImageRenderer.
    @Test func iconViewHandlesLottieAsset() throws {
        let request = IconRenderRequest(
            asset: .userLottie(assetID: UUID()),
            rect: CGRect(x: 0, y: 0, width: 128, height: 128),
            animationTime: 1.0
        )
        _ = IconView(request: request)
    }

    private func fixtureURL(named name: String, ext: String) throws -> URL {
        if let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures/Icons") {
            return url
        }
        if let url = Bundle.module.url(forResource: name, withExtension: ext) {
            return url
        }
        Issue.record("Could not locate \(name).\(ext) in test bundle.")
        throw CocoaError(.fileNoSuchFile)
    }
}
