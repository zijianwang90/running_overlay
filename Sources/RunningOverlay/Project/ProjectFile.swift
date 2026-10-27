import Foundation
import UniformTypeIdentifiers

/// On-disk `.roproj` project file: versioned JSON of `ProjectPerformanceSnapshot`.
enum ProjectFileFormat {
    static let fileExtension = "roproj"
    static let typeIdentifier = "io.github.zijianwang90.runningoverlay.project"
    static let currentSchemaVersion = 1
    static let untitledName = "Untitled"

    /// Declared in the app bundle's Info.plist. Unbundled `swift run` builds
    /// fall back to a dynamic type that carries the same filename extension.
    static var contentType: UTType {
        UTType(typeIdentifier)
            ?? UTType(filenameExtension: fileExtension, conformingTo: .json)
            ?? .json
    }

    static func encode(_ snapshot: ProjectPerformanceSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    static func decode(_ data: Data) throws -> ProjectPerformanceSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // Check the version first so a newer file reports a clear error
        // instead of an arbitrary missing-key failure.
        let header = try decoder.decode(Header.self, from: data)
        if let version = header.schemaVersion, version > currentSchemaVersion {
            throw ProjectFileError.newerSchemaVersion(version)
        }
        return try decoder.decode(ProjectPerformanceSnapshot.self, from: data)
    }

    private struct Header: Decodable {
        var schemaVersion: Int?
    }
}

enum ProjectFileError: LocalizedError, Equatable {
    case newerSchemaVersion(Int)

    var errorDescription: String? {
        switch self {
        case .newerSchemaVersion(let version):
            "This project was saved by a newer version of Running Overlay Studio (format \(version)). Update the app to open it."
        }
    }
}

/// Bookmarks that let a reopened project regain access to files outside the
/// App Sandbox and follow files that were moved or renamed.
enum FileBookmark {
    static func make(for url: URL) -> Data? {
        if let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            return data
        }
        return try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    static func resolve(_ data: Data) -> URL? {
        var isStale = false
        if let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) {
            return url
        }
        return try? URL(
            resolvingBookmarkData: data,
            options: [.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }
}

/// Most-recently-used project files, stored as bookmarks so the sandboxed app
/// can reopen them from the Open Recent menu.
struct RecentProjectStore {
    static let storageKey = "projectFile.recentProjects"
    static let limit = 10

    struct Entry: Codable, Equatable {
        var path: String
        var bookmark: Data
    }

    let userDefaults: UserDefaults

    func entries() -> [Entry] {
        guard let data = userDefaults.data(forKey: Self.storageKey),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            return []
        }
        return entries
    }

    func add(_ url: URL) {
        guard let bookmark = FileBookmark.make(for: url) else { return }
        let path = url.standardizedFileURL.path
        var updated = entries().filter { $0.path != path }
        updated.insert(Entry(path: path, bookmark: bookmark), at: 0)
        save(Array(updated.prefix(Self.limit)))
    }

    func remove(path: String) {
        save(entries().filter { $0.path != path })
    }

    func clear() {
        userDefaults.removeObject(forKey: Self.storageKey)
    }

    private func save(_ entries: [Entry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        userDefaults.set(data, forKey: Self.storageKey)
    }
}
