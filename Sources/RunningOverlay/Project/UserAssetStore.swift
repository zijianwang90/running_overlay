import CryptoKit
import Foundation
import UniformTypeIdentifiers

// MARK: - UserAsset

/// A content-addressed user asset (SVG icon, custom font, etc.) stored
/// alongside the project document and referenced by UUID from overlay styles.
struct UserAsset: Codable, Equatable, Identifiable {
    var id: UUID
    var kind: Kind
    var originalName: String
    var sha256: String
    var fileExtension: String

    enum Kind: String, Codable, Equatable {
        case svg
        case font
        case lottie
    }
}

// MARK: - UserAssetStore

/// Content-addressed file store that copies imported assets next to the
/// project document. Untitled projects fall back to an app-support directory.
enum UserAssetStore {
    /// Import a file from `sourceURL` into the project's asset store,
    /// returning the newly created `UserAsset`. Deduplicates by SHA-256.
    static func `import`(url sourceURL: URL, kind: UserAsset.Kind, projectURL: URL?) throws -> UserAsset {
        let data = try Data(contentsOf: sourceURL)
        let hash = SHA256.hash(data: data)
        let sha256 = hash.compactMap { String(format: "%02x", $0) }.joined()
        let ext = sourceURL.pathExtension.lowercased()
        let originalName = sourceURL.lastPathComponent
        let id = UUID()

        let storeDir = assetStoreDirectory(projectURL: projectURL)
        try FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)

        let destName = "\(sha256).\(ext)"
        let destURL = storeDir.appendingPathComponent(destName)
        if !FileManager.default.fileExists(atPath: destURL.path) {
            try data.write(to: destURL, options: .atomic)
        }

        return UserAsset(id: id, kind: kind, originalName: originalName, sha256: sha256, fileExtension: ext)
    }

    /// Resolve a `UserAsset` to a file URL, or nil if the file is missing.
    static func url(for asset: UserAsset, projectURL: URL?) -> URL? {
        let dir = assetStoreDirectory(projectURL: projectURL)
        let fileURL = dir.appendingPathComponent("\(asset.sha256).\(asset.fileExtension)")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        return nil
    }

    /// Delete the backing file for a single asset.
    static func delete(_ asset: UserAsset, projectURL: URL?) throws {
        if let url = url(for: asset, projectURL: projectURL) {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
    }

    /// Delete the entire asset store directory (for unsaved project cleanup).
    static func deleteStore(projectURL: URL?) throws {
        let dir = assetStoreDirectory(projectURL: projectURL)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }

    // MARK: Internal

    private static func assetStoreDirectory(projectURL: URL?) -> URL {
        if let projectURL {
            // .assets/ directory next to the project document
            return projectURL
                .deletingLastPathComponent()
                .appendingPathComponent(".assets", isDirectory: true)
        }
        // Untitled / unsaved projects fall back to App Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("RunningOverlay", isDirectory: true)
            .appendingPathComponent("UnsavedProjectAssets", isDirectory: true)
    }
}
