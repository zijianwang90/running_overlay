import Foundation
import Testing
@testable import RunningOverlay

@MainActor
struct SecurityScopedURLAccessTests {
    @Test func synchronousAccessRunsOperation() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("running-overlay-security-scope-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        try SecurityScopedURLAccess.withAccess(to: directory) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data("ok".utf8).write(to: directory.appendingPathComponent("sync.txt"))
        }

        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("sync.txt").path))
    }

    @Test func asynchronousAccessRunsOperation() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("running-overlay-security-scope-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        try await SecurityScopedURLAccess.withAccess(to: directory) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try await Task.sleep(for: .milliseconds(1))
            try Data("ok".utf8).write(to: directory.appendingPathComponent("async.txt"))
        }

        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("async.txt").path))
    }
}
