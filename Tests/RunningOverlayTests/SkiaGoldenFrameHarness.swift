#if canImport(CSkiaBridge)
import AppKit
import CoreGraphics
import Foundation
@testable import RunningOverlay

struct GoldenFrameMetrics: CustomStringConvertible {
    var label: String
    var changedPixels: Int
    var totalPixels: Int
    var meanDelta: Double
    var maxDelta: Int
    var diffBox: CGRect
    var referenceURL: URL
    var candidateURL: URL

    var changedRatio: Double {
        totalPixels > 0 ? Double(changedPixels) / Double(totalPixels) : 0
    }

    var description: String {
        "GOLDEN \(label) changed=\(changedPixels)/\(totalPixels) "
            + "(\(String(format: "%.3f", changedRatio * 100))%) "
            + "meanDelta=\(String(format: "%.4f", meanDelta)) "
            + "maxDelta=\(maxDelta) diffBox=\(diffBox) "
            + "reference=\(referenceURL.path) candidate=\(candidateURL.path)"
    }
}

enum GoldenFrameError: LocalizedError {
    case cannotCreateContext
    case cannotCreatePNG

    var errorDescription: String? {
        switch self {
        case .cannotCreateContext:
            "Could not create a comparison bitmap context."
        case .cannotCreatePNG:
            "Could not encode a golden-frame PNG."
        }
    }
}

/// Renders one layout through the SwiftUI oracle and the Skia backend, writes
/// both PNGs, and reports pixel deviation. Tests should assert on
/// `changedRatio` and `meanDelta` after human review of the images.
enum SkiaGoldenFrameHarness {
    static func compare(
        layout: OverlayLayout,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        size: CGSize,
        label: String,
        threshold: Int = 8,
        outputDirectory: URL? = nil
    ) async throws -> GoldenFrameMetrics {
        let reference = try await SwiftUIOverlayVideoExporter.renderFrameCGImage(
            overlayLayout: layout,
            activity: activity,
            elapsedTime: elapsedTime,
            size: size
        )
        guard let backend = SkiaFrameRendererBackend(size: size) else {
            throw OverlayRendererBackendError.unavailable(.skia)
        }
        let candidate = try await backend.renderFrame(
            layout: layout,
            activity: activity,
            elapsedTime: elapsedTime
        )

        let width = Int(size.width)
        let height = Int(size.height)
        let referencePixels = try rgbaPixels(reference, width: width, height: height)
        let candidatePixels = try rgbaPixels(candidate, width: width, height: height)

        var changed = 0
        var maxDelta = 0
        var totalDelta = 0
        var diffBox = CGRect.null
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                var pixelDelta = 0
                for channel in 0..<4 {
                    pixelDelta += abs(
                        Int(referencePixels[index + channel])
                            - Int(candidatePixels[index + channel])
                    )
                }
                if pixelDelta > threshold {
                    changed += 1
                    diffBox = diffBox.union(
                        CGRect(x: x, y: y, width: 1, height: 1)
                    )
                }
                maxDelta = max(maxDelta, pixelDelta)
                totalDelta += pixelDelta
            }
        }

        let directory = try resolvedOutputDirectory(outputDirectory, label: label)
        let referenceURL = directory.appendingPathComponent("\(label)-swiftui.png")
        let candidateURL = directory.appendingPathComponent("\(label)-skia.png")
        try writePNG(reference, to: referenceURL)
        try writePNG(candidate, to: candidateURL)

        let totalPixels = width * height
        return GoldenFrameMetrics(
            label: label,
            changedPixels: changed,
            totalPixels: totalPixels,
            meanDelta: totalPixels > 0
                ? Double(totalDelta) / Double(totalPixels * 4)
                : 0,
            maxDelta: maxDelta,
            diffBox: diffBox,
            referenceURL: referenceURL,
            candidateURL: candidateURL
        )
    }

    static func compare(
        element: OverlayElement,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        size: CGSize,
        label: String? = nil,
        threshold: Int = 8,
        outputDirectory: URL? = nil
    ) async throws -> GoldenFrameMetrics {
        try await compare(
            layout: OverlayLayout(elements: [element]),
            activity: activity,
            elapsedTime: elapsedTime,
            size: size,
            label: label ?? element.type.rawValue,
            threshold: threshold,
            outputDirectory: outputDirectory
        )
    }

    private static func rgbaPixels(
        _ image: CGImage,
        width: Int,
        height: Int
    ) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let bitmapInfo = CGBitmapInfo(
            rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        )
        try bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo.rawValue
            ) else {
                throw GoldenFrameError.cannotCreateContext
            }
            context.draw(
                image,
                in: CGRect(x: 0, y: 0, width: width, height: height)
            )
        }
        return bytes
    }

    private static func resolvedOutputDirectory(
        _ directory: URL?,
        label: String
    ) throws -> URL {
        let base = directory ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("skia-golden", isDirectory: true)
        let resolved = base.appendingPathComponent(
            "\(label)-\(UUID().uuidString.prefix(8))",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: resolved,
            withIntermediateDirectories: true
        )
        return resolved
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw GoldenFrameError.cannotCreatePNG
        }
        try data.write(to: url)
    }
}
#endif
