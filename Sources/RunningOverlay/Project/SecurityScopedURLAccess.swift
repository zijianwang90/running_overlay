import Foundation

enum SecurityScopedURLAccess {
    @MainActor
    static func withAccess<T>(to url: URL, _ operation: () throws -> T) rethrows -> T {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try operation()
    }

    @MainActor
    static func withAccess<T>(
        to url: URL,
        _ operation: () async throws -> T
    ) async rethrows -> T {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try await operation()
    }
}
