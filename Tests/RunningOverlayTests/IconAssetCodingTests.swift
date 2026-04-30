import CoreGraphics
import Foundation
import Testing
@testable import RunningOverlay

/// Phase C2 — `IconAsset` round-trips cleanly through `Codable` for every
/// case. The on-disk schema is a `{kind, …}` discriminated union so older
/// builds can decode forward-compat by ignoring unknown keys via
/// `decodeIfPresent`. This test pins that schema.
struct IconAssetCodingTests {
    @Test func noneRoundTrips() throws {
        try roundTrip(.none)
    }

    @Test func sfSymbolRoundTrips() throws {
        try roundTrip(.sfSymbol(name: "heart.fill", weight: .bold, scale: .large))
    }

    @Test func sfSymbolUsesDefaultWeightAndScaleWhenAbsent() throws {
        // Older project JSON may omit weight/scale; decoder should fall
        // back to .regular / .medium without throwing.
        let json = #"{"kind":"sfSymbol","name":"star"}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(IconAsset.self, from: json)
        guard case let .sfSymbol(name, weight, scale) = decoded else {
            Issue.record("Expected .sfSymbol, got \(decoded)")
            return
        }
        #expect(name == "star")
        #expect(weight == .regular)
        #expect(scale == .medium)
    }

    @Test func userStaticSVGRoundTrips() throws {
        try roundTrip(.userStaticSVG(assetID: UUID()))
    }

    @Test func userLottieRoundTrips() throws {
        try roundTrip(.userLottie(assetID: UUID()))
    }

    @Test func bundledSVGRoundTrips() throws {
        try roundTrip(.bundledSVG(name: "running"))
    }

    private func roundTrip(_ asset: IconAsset) throws {
        let data = try JSONEncoder().encode(asset)
        let back = try JSONDecoder().decode(IconAsset.self, from: data)
        #expect(asset == back)
    }
}

/// Phase C3-C5 — exercise the SF Symbols and bundled-SVG render paths
/// through `IconRenderer.draw` and assert the offscreen `CGContext`
/// receives non-trivial pixel coverage. (Bundled SVG is exercised via the
/// existing test fixtures rather than shipping new bundled icons.)
struct IconRenderingTests {
    @Test func sfSymbolDrawsPixels() throws {
        let request = IconRenderRequest(
            asset: .sfSymbol(name: "heart.fill", weight: .bold, scale: .large),
            rect: CGRect(x: 0, y: 0, width: 96, height: 96),
            tint: .systemRed
        )
        let coverage = try drawAndCount(request: request, canvasSide: 96)
        #expect(coverage > 200, "SF Symbol render produced almost no pixels (\(coverage)).")
    }

    @Test func sfSymbolWithoutTintStillDraws() throws {
        let request = IconRenderRequest(
            asset: .sfSymbol(name: "circle.fill"),
            rect: CGRect(x: 0, y: 0, width: 64, height: 64),
            tint: nil
        )
        let coverage = try drawAndCount(request: request, canvasSide: 64)
        #expect(coverage > 200)
    }

    @Test func noneAssetIsNoOp() throws {
        let request = IconRenderRequest(
            asset: .none,
            rect: CGRect(x: 0, y: 0, width: 32, height: 32),
            tint: .white
        )
        let coverage = try drawAndCount(request: request, canvasSide: 32)
        #expect(coverage == 0)
    }

    @Test func aspectFitRectPreservesAspectInsideHostRect() {
        let host = CGRect(x: 0, y: 0, width: 100, height: 50)
        let intrinsic = CGSize(width: 200, height: 200)
        let fit = IconRenderer.aspectFitRect(intrinsicSize: intrinsic, in: host, mode: .fit)
        // 200×200 fit into 100×50 → 50×50 centered horizontally.
        #expect(fit.width == 50)
        #expect(fit.height == 50)
        #expect(fit.midX == host.midX)
        #expect(fit.midY == host.midY)
    }

    @Test func aspectFillRectCoversHostRect() {
        let host = CGRect(x: 0, y: 0, width: 100, height: 50)
        let intrinsic = CGSize(width: 200, height: 200)
        let fill = IconRenderer.aspectFillRect(in: host, with: intrinsic)
        #expect(fill.width >= host.width)
        #expect(fill.height >= host.height)
    }

    private func drawAndCount(request: IconRenderRequest, canvasSide: Int) throws -> Int {
        let bytesPerPixel = 4
        let bytesPerRow = canvasSide * bytesPerPixel
        var raw = [UInt8](repeating: 0, count: canvasSide * canvasSide * bytesPerPixel)
        let cs = CGColorSpaceCreateDeviceRGB()
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue
        guard let ctx = raw.withUnsafeMutableBytes({ ptr in
            CGContext(
                data: ptr.baseAddress,
                width: canvasSide,
                height: canvasSide,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: cs,
                bitmapInfo: info
            )
        }) else {
            Issue.record("Failed to create offscreen CGContext")
            throw CocoaError(.fileWriteUnknown)
        }
        IconRenderer.draw(request, in: ctx)
        var coverage = 0
        for i in stride(from: 3, to: raw.count, by: bytesPerPixel) where raw[i] > 0 {
            coverage += 1
        }
        return coverage
    }
}

private extension IconRenderer {
    /// Test-only wrapper around `aspectFitRect` for the `.fill` mode, kept
    /// out of production code so we don't add an unused convenience.
    static func aspectFillRect(in rect: CGRect, with intrinsic: CGSize) -> CGRect {
        aspectFitRect(intrinsicSize: intrinsic, in: rect, mode: .fill)
    }
}
