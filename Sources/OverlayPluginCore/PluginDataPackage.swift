import CryptoKit
import Foundation

/// An embedded JSON document. Its schema belongs to the shared domain model,
/// not the host adapter. No file URLs, bookmarks, or executable code are needed.
public struct PluginPackageResource: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let sha256: String
    public let data: Data

    public init(schemaVersion: Int, data: Data) {
        self.schemaVersion = schemaVersion
        self.sha256 = PluginDataPackageCodec.digest(data)
        self.data = data
    }
}

public struct PluginPackageTemplate: Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let resource: PluginPackageResource

    public init(id: UUID, name: String, resource: PluginPackageResource) {
        self.id = id
        self.name = name
        self.resource = resource
    }
}

/// Self-contained transport for activity/template JSON, separate from a
/// rendered editor package. Payload Data is base64 in the JSON wire format.
/// Map/weather/user-resource preparation is not included in version 1.
public struct PluginDataPackage: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let fileExtension = "roplugin"

    public let schemaVersion: Int
    public let rendererVersion: String
    public let canvasWidth: Int
    public let canvasHeight: Int
    public let activity: PluginPackageResource
    public let templates: [PluginPackageTemplate]

    public init(
        rendererVersion: String,
        canvasWidth: Int,
        canvasHeight: Int,
        activity: PluginPackageResource,
        templates: [PluginPackageTemplate]
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.rendererVersion = rendererVersion
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.activity = activity
        self.templates = templates
    }
}

public enum PluginDataPackageCodec {
    public static let maximumFileSize = 64 * 1024 * 1024

    public static func encode(_ package: PluginDataPackage) throws -> Data {
        try validate(package)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(package)
        guard data.count <= maximumFileSize else { throw PluginCoreError.packageTooLarge }
        return data
    }

    public static func decode(_ data: Data) throws -> PluginDataPackage {
        guard data.count <= maximumFileSize else { throw PluginCoreError.packageTooLarge }
        let decoder = JSONDecoder()
        // Read the version first so a future schema fails with a useful error.
        struct Header: Decodable { let schemaVersion: Int }
        let header = try decoder.decode(Header.self, from: data)
        guard header.schemaVersion == PluginDataPackage.currentSchemaVersion else {
            throw PluginCoreError.unsupportedPackageVersion(header.schemaVersion)
        }
        let package = try decoder.decode(PluginDataPackage.self, from: data)
        try validate(package)
        return package
    }

    public static func validate(_ package: PluginDataPackage) throws {
        guard package.schemaVersion == PluginDataPackage.currentSchemaVersion else {
            throw PluginCoreError.unsupportedPackageVersion(package.schemaVersion)
        }
        guard !package.rendererVersion.isEmpty,
              (1...8192).contains(package.canvasWidth), (1...8192).contains(package.canvasHeight),
              !package.templates.isEmpty, package.templates.count <= 128,
              Set(package.templates.map(\.id)).count == package.templates.count else {
            throw PluginCoreError.invalidPackage("invalid renderer, canvas, or template selection")
        }
        for template in package.templates where template.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw PluginCoreError.invalidPackage("empty template name")
        }
        for resource in [package.activity] + package.templates.map(\.resource) {
            guard resource.schemaVersion > 0, !resource.data.isEmpty else {
                throw PluginCoreError.invalidPackage("invalid embedded resource")
            }
            guard resource.data.count <= maximumFileSize else { throw PluginCoreError.packageTooLarge }
            guard resource.sha256 == digest(resource.data) else { throw PluginCoreError.contentMismatch }
        }
    }

    public static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
