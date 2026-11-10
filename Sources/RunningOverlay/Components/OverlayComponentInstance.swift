import CryptoKit
import Foundation

// MARK: - Raw JSON persistence

/// Arbitrary JSON kept with a project element. Component definitions are
/// embedded as data so a project renders from its own bytes instead of an
/// external package that may have moved on.
extension OverlayJSONValue: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([OverlayJSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: OverlayJSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .boolean(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }

    /// Deterministic bytes used for digests and cache keys. Keys are sorted so
    /// formatting differences in the source package do not change identity.
    func canonicalData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}

enum OverlayComponentDigest {
    static func sha256(of data: Data) -> String {
        "sha256:" + SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - Persisted instance

/// Where an instance's definition came from. Bundled definitions are resolved
/// by the host; imported and project definitions embed their bytes.
enum OverlayComponentSource: String, Codable, Equatable {
    case bundled
    case imported
    case project
}

/// The persisted reference to a component definition.
///
/// The spec models this as the `component` object of an element, with parameter
/// values stored beside it as `params`.
struct OverlayComponentReference: Codable, Equatable {
    var id: String
    var version: String
    var digest: String
    var source: OverlayComponentSource
    /// Nil for bundled components, which ship with the host.
    var definition: OverlayJSONValue?
    /// Package-relative asset bytes (`assets/name.png`), embedded for imported
    /// and project components. Nil when the component has no assets.
    var assets: [String: Data]?

    init(
        id: String,
        version: String,
        digest: String,
        source: OverlayComponentSource,
        definition: OverlayJSONValue? = nil,
        assets: [String: Data]? = nil
    ) {
        self.id = id
        self.version = version
        self.digest = digest
        self.source = source
        self.definition = definition
        self.assets = assets
    }

    /// Validates `component.json` bytes and builds a reference. Imported and
    /// project definitions embed the canonical document and their asset bytes;
    /// bundled ones omit both.
    init(
        definitionData: Data,
        source: OverlayComponentSource,
        assets: [String: Data] = [:]
    ) throws {
        let root = try OverlayJSONValue.decode(definitionData)
        let canonical = try root.canonicalData()
        let package = try OverlayComponentLoader.load(
            data: canonical,
            assets: Set(assets.keys),
            assetData: assets
        )
        self.init(
            id: package.definition.id,
            version: package.definition.version,
            digest: package.digest,
            source: source,
            definition: source == .bundled ? nil : root,
            assets: source == .bundled || assets.isEmpty ? nil : assets
        )
    }
}

/// An `OverlayElement`'s component payload: the persisted reference plus the
/// element's parameter values, stored as authored JSON (`#RRGGBB`, numbers,
/// booleans) and typed against the definition when resolved.
struct OverlayComponentInstance: Equatable {
    var reference: OverlayComponentReference
    var parameters: [String: OverlayJSONValue]

    init(reference: OverlayComponentReference, parameters: [String: OverlayJSONValue] = [:]) {
        self.reference = reference
        self.parameters = parameters
    }
}

// MARK: - Display

extension OverlayComponentInstance {
    /// Localized display name from the resolved definition, falling back to the
    /// component id so a missing definition still identifies the element.
    var displayName: String {
        guard let definition = OverlayComponentRegistry.definition(for: reference) else {
            return reference.id
        }
        return definition.name.resolve(language: Self.hostLanguage)
    }

    static var hostLanguage: String {
        Locale.preferredLanguages.first ?? "en"
    }
}

extension OverlayElement {
    /// User-facing element name. Components use their definition name instead
    /// of the generic "Component" type label.
    var displayLabel: String {
        component?.displayName ?? type.label
    }
}

// MARK: - Parameter typing

extension OverlayComponentDefinition {
    /// Converts persisted JSON parameter values to typed evaluation values.
    /// Unknown parameters and values of the wrong JSON type are ignored; the
    /// resolver then keeps the declared default for that parameter.
    func parameterValues(from raw: [String: OverlayJSONValue]) -> [String: OverlayComponentValue] {
        var result: [String: OverlayComponentValue] = [:]
        for (id, json) in raw {
            guard let parameter = parameter(named: id) else { continue }
            switch parameter.kind {
            case .number:
                if case .number(let value) = json, value.isFinite {
                    result[id] = .number(value)
                }
            case .boolean:
                if case .boolean(let value) = json {
                    result[id] = .boolean(value)
                }
            case .color:
                if case .string(let value) = json,
                   let color = OverlayComponentColorParser.parse(value) {
                    result[id] = .color(color)
                }
            case .enumeration, .string, .font, .metric:
                if case .string(let value) = json {
                    result[id] = .string(value)
                }
            }
        }
        return result
    }
}

// MARK: - Definition registry

/// Resolves and caches component definitions for rendering.
///
/// Validation runs once per digest. References without embedded bytes resolve
/// through `OverlayComponentLibrary` when they name a bundled definition with
/// the recorded digest.
enum OverlayComponentRegistry {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var definitionsByDigest: [String: OverlayComponentDefinition] = [:]
    /// Bundled definitions resolve by reading and parsing a resource. Rendering
    /// asks for them every frame, so a miss here costs the whole preview.
    nonisolated(unsafe) private static var bundledDefinitions: [String: OverlayComponentDefinition] = [:]
    #if DEBUG
    /// Test hook: proves repeated lookups reuse the cached definition without
    /// being disturbed by other bundled definitions loading in parallel tests.
    nonisolated(unsafe) private static var bundledDefinitionLoads: [String: Int] = [:]

    static func bundledLoadCount(for reference: OverlayComponentReference) -> Int {
        let key = "\(reference.id)|\(reference.version)|\(reference.digest)"
        lock.lock()
        defer { lock.unlock() }
        return bundledDefinitionLoads[key, default: 0]
    }
    #endif

    /// Returns the parsed definition for an instance, or nil when the
    /// reference cannot be resolved.
    static func definition(for reference: OverlayComponentReference) -> OverlayComponentDefinition? {
        guard let embedded = reference.definition,
              let data = try? embedded.canonicalData() else {
            return bundledDefinition(for: reference)
        }
        let assetData = reference.assets ?? [:]
        let assetPaths = assetData.keys.sorted().joined(separator: "|")
        let key = OverlayComponentDigest.sha256(of: data) + "|" + assetPaths

        lock.lock()
        if let cached = definitionsByDigest[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let package = try? OverlayComponentLoader.load(
            data: data,
            assets: Set(assetData.keys),
            assetData: assetData
        ) else {
            return nil
        }

        lock.lock()
        definitionsByDigest[key] = package.definition
        lock.unlock()
        return package.definition
    }

    /// Bundled references carry no bytes, so their only identity is the id,
    /// version and digest the project recorded. Cache the parsed definition:
    /// the preview resolves every component each frame.
    private static func bundledDefinition(
        for reference: OverlayComponentReference
    ) -> OverlayComponentDefinition? {
        guard reference.source == .bundled else {
            return OverlayComponentLibrary.definition(for: reference)
        }
        let key = "\(reference.id)|\(reference.version)|\(reference.digest)"
        lock.lock()
        if let cached = bundledDefinitions[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        // Parse outside the lock; a duplicate load during a race is harmless.
        #if DEBUG
        lock.lock()
        bundledDefinitionLoads[key, default: 0] += 1
        lock.unlock()
        #endif
        guard let definition = OverlayComponentLibrary.definition(for: reference) else {
            return nil
        }
        lock.lock()
        bundledDefinitions[key] = definition
        lock.unlock()
        return definition
    }

    /// Asset bytes available to a component, keyed by package-relative path.
    static func assets(for reference: OverlayComponentReference) -> [String: Data] {
        reference.assets ?? [:]
    }

    /// Resolves an instance against host data. Returns nil when the definition
    /// cannot be resolved; resolver-level diagnostics remain available on the
    /// resolved value for callers that need them.
    static func resolve(
        instance: OverlayComponentInstance,
        data: any OverlayComponentDataProviding
    ) -> OverlayComponentResolved? {
        guard let definition = definition(for: instance.reference) else { return nil }
        var resolved = OverlayComponentResolver(definition: definition).resolve(
            parameters: definition.parameterValues(from: instance.parameters),
            data: data
        )
        if let embedded = instance.reference.definition,
           let data = try? embedded.canonicalData(),
           OverlayComponentDigest.sha256(of: data) != instance.reference.digest {
            // The embedded bytes are authoritative; the stored digest only
            // records what the instance was imported from.
            resolved.diagnostics.insert(
                "component \(instance.reference.id): stored digest does not match the embedded definition",
                at: 0
            )
        }
        return resolved
    }

    /// Test and import hook: drops cached definitions.
    static func clearCache() {
        lock.lock()
        definitionsByDigest.removeAll()
        bundledDefinitions.removeAll()
        lock.unlock()
    }
}

// MARK: - Host capabilities

extension OverlayComponentDefinition {
    /// Whether the definition reads host weather, through the `weatherWidget`
    /// capability node or a `weather.*` signal binding. The host uses this to
    /// show a fetch control and to decide when a project weather cache is
    /// relevant; components themselves never fetch weather.
    var usesHostWeather: Bool {
        if bindings.values.contains(where: { binding in
            guard case .signal(let path) = binding else { return false }
            return path == "weather.current" || path.hasPrefix("weather.")
        }) {
            return true
        }
        return nodes.contains { $0.kind.usesHostWeather }
    }
}

extension OverlayComponentNodeKind {
    /// Recursively reports whether this node or any descendant uses weather.
    var usesHostWeather: Bool {
        switch self {
        case .weatherWidget:
            return true
        case .group(_, _, _, _), .stack(_, _, _, _), .columns(_, _, _), .repeatNode(_, _, _, _, _):
            return self.children.contains { $0.kind.usesHostWeather }
        default:
            return false
        }
    }

    /// Direct child nodes, for recursive capability checks.
    private var children: [OverlayComponentNode] {
        switch self {
        case .group(let children, _, _, _): children
        case .stack(_, _, _, let children): children
        case .columns(_, _, let children): children
        case .repeatNode(_, _, _, _, let children): children
        default: []
        }
    }
}

extension OverlayElement {
    /// Host-drawn component that consumes the project weather snapshot.
    var componentUsesHostWeather: Bool {
        guard let definition = component.flatMap({
            OverlayComponentRegistry.definition(for: $0.reference)
        }) else { return false }
        return definition.usesHostWeather
    }
}
