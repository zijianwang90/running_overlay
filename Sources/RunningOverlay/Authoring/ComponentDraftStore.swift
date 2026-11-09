import Foundation

/// One component draft on disk: a single JSON document or a `.rocomponent`
/// package directory inside the drafts folder.
struct ComponentDraft: Identifiable, Equatable {
    enum Status: Equatable {
        case valid(OverlayComponentReference, displayName: String)
        case invalid([OverlayComponentDiagnostic])
    }

    /// File name without extension; stable across edits of the same draft.
    var id: String
    var url: URL
    var modified: Date
    var status: Status

    var reference: OverlayComponentReference? {
        if case let .valid(reference, _) = status { return reference }
        return nil
    }

    var displayName: String {
        if case let .valid(_, name) = status { return name }
        return id
    }
}

/// The shared folder where AI clients (through `RunningOverlay --mcp`) and
/// people save component drafts for the app to show live.
///
/// The app and the MCP server are the same executable, so in a sandboxed build
/// both resolve Application Support inside the same container and need no
/// file picker, socket or shared group to exchange drafts.
struct ComponentDraftStore {
    static let fileExtension = "json"
    static let packageExtension = "rocomponent"
    static let maximumDocumentBytes = 1024 * 1024

    let directory: URL

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RunningOverlay", isDirectory: true)
            .appendingPathComponent("ComponentDrafts", isDirectory: true)
    }

    init(directory: URL = ComponentDraftStore.defaultDirectory) {
        self.directory = directory
    }

    /// Lowercase letters, digits and single hyphens; empty when nothing
    /// usable remains.
    static func slug(_ name: String) -> String {
        var result = ""
        for scalar in name.lowercased().unicodeScalars {
            if ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) {
                result.unicodeScalars.append(scalar)
            } else if !result.isEmpty, !result.hasSuffix("-") {
                result.append("-")
            }
        }
        while result.hasSuffix("-") { result.removeLast() }
        return String(result.prefix(64))
    }

    func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Draft entries sorted by most recent change first. Unreadable or invalid
    /// drafts are listed with their diagnostics so the app can show why.
    func drafts() -> [ComponentDraft] {
        entries().map { url, modified in
            ComponentDraft(
                id: url.deletingPathExtension().lastPathComponent,
                url: url,
                modified: modified,
                status: Self.status(at: url)
            )
        }
        .sorted { $0.modified == $1.modified ? $0.id < $1.id : $0.modified > $1.modified }
    }

    /// Cheap change signature: name and latest modification date of every
    /// draft, including files inside package directories.
    func fingerprint() -> [String: String] {
        var result: [String: String] = [:]
        for (url, modified) in entries() {
            result[url.lastPathComponent] = "\(modified.timeIntervalSinceReferenceDate)"
        }
        return result
    }

    /// Validates and writes `data` as `<slug>.json`, replacing an earlier
    /// draft of the same name. Invalid documents are rejected with their
    /// diagnostics and nothing is written.
    @discardableResult
    func save(name: String, data: Data) throws -> ComponentDraft {
        let slug = Self.slug(name)
        guard !slug.isEmpty else { throw ComponentDraftError.invalidName(name) }
        guard data.count <= Self.maximumDocumentBytes else { throw ComponentDraftError.tooLarge }
        let reference = try OverlayComponentReference(definitionData: data, source: .imported)
        guard !reference.id.hasPrefix("studio.") else {
            throw ComponentDraftError.reservedID(reference.id)
        }
        try ensureDirectory()
        let url = directory.appendingPathComponent(slug).appendingPathExtension(Self.fileExtension)
        try data.write(to: url, options: .atomic)
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate ?? Date()
        return ComponentDraft(
            id: slug,
            url: url,
            modified: modified,
            status: .valid(reference, displayName: Self.displayName(for: reference))
        )
    }

    /// Saves a component pasted from an AI chat. Accepts bare JSON or a reply
    /// with one fenced code block; the draft is named after the component id.
    @discardableResult
    func saveDraft(fromPastedText text: String) throws -> ComponentDraft {
        guard let data = Self.componentJSON(fromPastedText: text) else {
            throw ComponentDraftError.noComponentJSON
        }
        let reference = try OverlayComponentReference(definitionData: data, source: .imported)
        let name = reference.id.split(separator: ".").last.map(String.init) ?? reference.id
        return try save(name: name, data: data)
    }

    /// The outermost JSON object in pasted text, ignoring surrounding prose
    /// and Markdown code fences.
    static func componentJSON(fromPastedText text: String) -> Data? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end else {
            return nil
        }
        return Data(text[start...end].utf8)
    }

    func draft(named name: String) -> ComponentDraft? {
        let slug = Self.slug(name)
        return drafts().first { $0.id == slug }
    }

    func delete(_ draft: ComponentDraft) throws {
        guard draft.url.deletingLastPathComponent().standardizedFileURL
            == directory.standardizedFileURL else {
            throw ComponentDraftError.outsideDraftsFolder
        }
        try FileManager.default.removeItem(at: draft.url)
    }

    private func entries() -> [(URL, Date)] {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isDirectoryKey]
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return contents.compactMap { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            let isPackage = values?.isDirectory == true && url.pathExtension == Self.packageExtension
            guard isPackage || (values?.isDirectory != true && url.pathExtension == Self.fileExtension) else {
                return nil
            }
            var modified = values?.contentModificationDate ?? .distantPast
            if isPackage {
                modified = max(modified, Self.latestModification(inside: url))
            }
            return (url, modified)
        }
    }

    private static func latestModification(inside directory: URL) -> Date {
        let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        var latest = Date.distantPast
        while let url = enumerator?.nextObject() as? URL {
            if let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                latest = max(latest, date)
            }
        }
        return latest
    }

    private static func status(at url: URL) -> ComponentDraft.Status {
        do {
            let reference = try OverlayComponentLoader.loadReference(at: url)
            return .valid(reference, displayName: displayName(for: reference))
        } catch let error as OverlayComponentValidationError {
            return .invalid(error.diagnostics.filter { $0.severity == .error })
        } catch {
            return .invalid([OverlayComponentDiagnostic(path: "", message: error.localizedDescription)])
        }
    }

    static func displayName(for reference: OverlayComponentReference) -> String {
        OverlayComponentRegistry.definition(for: reference)?.name
            .resolve(language: OverlayComponentInstance.hostLanguage) ?? reference.id
    }
}

enum ComponentDraftError: LocalizedError, Equatable {
    case invalidName(String)
    case tooLarge
    case outsideDraftsFolder
    case reservedID(String)
    case noComponentJSON

    var errorDescription: String? {
        switch self {
        case .invalidName(let name):
            "Draft name '\(name)' has no letters or digits."
        case .tooLarge:
            "Component JSON must not exceed 1 MiB."
        case .outsideDraftsFolder:
            "Only drafts inside the drafts folder can be deleted."
        case .reservedID(let id):
            "Component id '\(id)' uses the reserved 'studio.' namespace; choose your own prefix."
        case .noComponentJSON:
            "The clipboard does not contain a component JSON object."
        }
    }
}
