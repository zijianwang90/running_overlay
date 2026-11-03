import CoreGraphics
import Foundation

/// Selects which overlay frame renderer backs preview, export, and parity
/// tests. SwiftUI stays the default until a module passes its golden-frame
/// review; `RUNNING_OVERLAY_RENDERER=skia` opts into the Skia backend.
enum OverlayRendererBackendKind: String, CaseIterable, Sendable {
    case swiftUI
    case skia

    static var selected: Self {
        guard let raw = ProcessInfo.processInfo.environment["RUNNING_OVERLAY_RENDERER"],
              let backend = Self(rawValue: raw) else {
            return .swiftUI
        }
        return backend
    }
}

enum OverlayRendererBackendError: LocalizedError {
    case unavailable(OverlayRendererBackendKind)
    case cannotCreateImage

    var errorDescription: String? {
        switch self {
        case .unavailable(let backend):
            "The \(backend.rawValue) overlay renderer is unavailable."
        case .cannotCreateImage:
            "Could not create an image from the rendered overlay frame."
        }
    }
}

/// Rasterizes one overlay frame for CPU fallbacks and parity tests.
///
/// Preview and export hosts use the concrete Skia renderer for their target
/// surface (Metal drawable or `CVPixelBuffer`); this protocol keeps the
/// SwiftUI oracle and the Skia renderer interchangeable where a `CGImage` is
/// enough.
protocol OverlayFrameRendererBackend: AnyObject {
    var size: CGSize { get }
    func renderFrame(
        layout: OverlayLayout,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval
    ) async throws -> CGImage
}

final class SwiftUIFrameRendererBackend: OverlayFrameRendererBackend {
    let size: CGSize

    init(size: CGSize) {
        self.size = size
    }

    func renderFrame(
        layout: OverlayLayout,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval
    ) async throws -> CGImage {
        try await SwiftUIOverlayVideoExporter.renderFrameCGImage(
            overlayLayout: layout,
            activity: activity,
            elapsedTime: elapsedTime,
            size: size
        )
    }
}

#if canImport(CSkiaBridge)
final class SkiaFrameRendererBackend: OverlayFrameRendererBackend {
    let size: CGSize
    private let renderer: SkiaEasyRunRenderer

    /// CPU raster backend. Used by tests and by machines without a Metal device.
    init?(size: CGSize) {
        guard let renderer = SkiaEasyRunRenderer(size: size) else { return nil }
        self.renderer = renderer
        self.size = size
    }

    func renderFrame(
        layout: OverlayLayout,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval
    ) async throws -> CGImage {
        let (base, rowBytes) = renderer.render(
            layout: layout,
            activity: activity,
            elapsedTime: elapsedTime
        )
        return try Self.makeImage(
            base,
            rowBytes: rowBytes,
            size: size
        )
    }

    static func makeImage(
        _ base: UnsafePointer<UInt8>,
        rowBytes: Int,
        size: CGSize
    ) throws -> CGImage {
        let data = Data(
            bytes: base,
            count: rowBytes * Int(size.height)
        )
        guard let provider = CGDataProvider(data: data as CFData),
              let image = CGImage(
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: rowBytes,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(
                    rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue
                        | CGBitmapInfo.byteOrder32Little.rawValue
                ),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            throw OverlayRendererBackendError.cannotCreateImage
        }
        return image
    }
}
#endif

enum OverlayFrameRendererFactory {
    static func make(
        size: CGSize,
        backend: OverlayRendererBackendKind = .selected
    ) -> (any OverlayFrameRendererBackend)? {
        switch backend {
        case .swiftUI:
            return SwiftUIFrameRendererBackend(size: size)
        case .skia:
            #if canImport(CSkiaBridge)
            return SkiaFrameRendererBackend(size: size)
            #else
            return nil
            #endif
        }
    }
}
