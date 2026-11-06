import Foundation

/// Version of the overlay pixel output. Bump it whenever a renderer change
/// alters exported pixels, so cached editor renders are invalidated (ADR 0013).
enum OverlayRendererVersion {
    static let current = "skia-1"
}
