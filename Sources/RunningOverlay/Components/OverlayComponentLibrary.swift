import Foundation

/// Read-only components bundled with the app.
///
/// Bundled definitions ship as resources and are referenced by id, version and
/// digest; the project does not embed them. Users can inspect them and
/// duplicate one into an editable project component, but cannot edit the
/// bundled document in place.
struct OverlayComponentLibraryItem: Identifiable, Equatable {
    var id: String
    var displayName: String
    var hint: String
    var systemImage: String
    var resourceName: String

    static let all: [OverlayComponentLibraryItem] = [
        OverlayComponentLibraryItem(
            id: "studio.builtin.heart-rate-pill",
            displayName: "Heart Rate Pill",
            hint: "HR + trend",
            systemImage: "heart.text.square.fill",
            resourceName: "hr-pill"
        ),
        OverlayComponentLibraryItem(
            id: "studio.examples.lap-splits",
            displayName: "Lap Splits",
            hint: "repeat rows",
            systemImage: "list.number",
            resourceName: "lap-splits"
        )
    ]
}

enum OverlayComponentLibrary {
    /// Loads the bundled `component.json` bytes for an item.
    static func data(for item: OverlayComponentLibraryItem) -> Data? {
        let url = Bundle.runningOverlayResources.url(
            forResource: item.resourceName,
            withExtension: "json",
            subdirectory: "Components"
        ) ?? Bundle.runningOverlayResources.url(
            forResource: item.resourceName,
            withExtension: "json"
        )
        return url.flatMap { try? Data(contentsOf: $0) }
    }

    /// Builds a bundled reference (id, version, digest, no embedded bytes).
    static func reference(for item: OverlayComponentLibraryItem) throws -> OverlayComponentReference {
        guard let data = data(for: item) else {
            throw OverlayComponentLibraryError.missingResource(item.resourceName)
        }
        return try OverlayComponentReference(definitionData: data, source: .bundled)
    }

    /// Resolves a bundled reference to a validated definition, matching the
    /// digest recorded in the reference so updated bundled components do not
    /// silently change an existing project.
    static func definition(for reference: OverlayComponentReference) -> OverlayComponentDefinition? {
        guard reference.source == .bundled else { return nil }
        for item in OverlayComponentLibraryItem.all {
            guard let data = data(for: item),
                  let package = try? OverlayComponentLoader.load(data: data),
                  package.definition.id == reference.id,
                  package.digest == reference.digest else {
                continue
            }
            return package.definition
        }
        return nil
    }

    /// Rebuilds a reference with the definition embedded and source
    /// `.project`, used by "Duplicate to My Components".
    static func editableReference(for reference: OverlayComponentReference) -> OverlayComponentReference? {
        guard reference.source == .bundled else { return nil }
        for item in OverlayComponentLibraryItem.all {
            guard let data = data(for: item),
                  let bundled = try? OverlayComponentReference(definitionData: data, source: .project),
                  bundled.id == reference.id,
                  bundled.digest == reference.digest else {
                continue
            }
            return bundled
        }
        return nil
    }
}

enum OverlayComponentLibraryError: LocalizedError, Equatable {
    case missingResource(String)
    case missingDefinition
    case invalidAssetPath(String)

    var errorDescription: String? {
        switch self {
        case .missingResource(let name):
            "Bundled component resource '\(name)' is missing."
        case .missingDefinition:
            "Only imported or project components can be exported."
        case .invalidAssetPath(let path):
            "Component asset path '\(path)' is invalid."
        }
    }
}

/// A component definition carried by the open project, deduplicated by digest.
struct OverlayComponentProjectEntry: Identifiable, Equatable {
    var reference: OverlayComponentReference
    var displayName: String
    var instanceCount: Int

    var id: String { reference.digest }
}

/// Writes a project component back out as a `.rocomponent` directory package.
enum OverlayComponentPackageWriter {
    static func write(_ reference: OverlayComponentReference, to directory: URL) throws {
        guard let definition = reference.definition else {
            throw OverlayComponentLibraryError.missingDefinition
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(definition)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try data.write(
            to: directory.appendingPathComponent("component.json"),
            options: .atomic
        )
        guard let assets = reference.assets, !assets.isEmpty else { return }
        let assetsDirectory = directory.appendingPathComponent("assets", isDirectory: true)
        try FileManager.default.createDirectory(
            at: assetsDirectory,
            withIntermediateDirectories: true
        )
        for (path, bytes) in assets {
            let name = (path as NSString).lastPathComponent
            guard path == "assets/\(name)", !name.isEmpty, name != ".", name != ".." else {
                throw OverlayComponentLibraryError.invalidAssetPath(path)
            }
            try bytes.write(
                to: assetsDirectory.appendingPathComponent(name),
                options: .atomic
            )
        }
    }
}
