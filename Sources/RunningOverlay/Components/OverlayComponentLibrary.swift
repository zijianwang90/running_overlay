import Foundation

/// Read-only components bundled with the app.
///
/// Bundled definitions ship as resources and are referenced by id, version and
/// digest; the project does not embed them. Users can inspect them and
/// duplicate one into an editable project component, but cannot edit the
/// bundled document in place.
struct OverlayComponentLibraryItem: Identifiable, Equatable, Sendable {
    /// Pool entry identity. Presets of one definition share `resourceName`
    /// and differ by `parameters`, so the id is not the component id.
    var id: String
    var displayName: String
    var hint: String
    var systemImage: String
    var resourceName: String
    /// Initial parameter values for a new instance.
    var parameters: [String: OverlayJSONValue] = [:]

    /// Every bundled entry: numeric presets (Overlay Pool → Metrics) and
    /// decor and example components (Overlay Pool → Components → Bundled).
    static let all: [OverlayComponentLibraryItem] = numericPresets + decor + intervalComponents + chartComponents + examples

    static let decor: [OverlayComponentLibraryItem] = [
        OverlayComponentLibraryItem(
            id: "studio.decor-shape",
            displayName: "Shape",
            hint: "fill + border",
            systemImage: "square.fill",
            resourceName: "decor-shape"
        ),
        OverlayComponentLibraryItem(
            id: "studio.decor-text",
            displayName: "Text",
            hint: "paragraph + styles",
            systemImage: "textformat",
            resourceName: "decor-text"
        ),
        OverlayComponentLibraryItem(
            id: "studio.decor-icon",
            displayName: "Symbol",
            hint: "SF Symbol + tint",
            systemImage: "figure.run",
            resourceName: "decor-icon"
        )
    ]

    /// Interval workout modules whose composition is declarative. Data comes
    /// from the host `structure.segment` contract.
    static let intervalComponents: [OverlayComponentLibraryItem] = [
        OverlayComponentLibraryItem(
            id: "studio.interval-countdown",
            displayName: "Interval Countdown",
            hint: "ring + remaining",
            systemImage: "timer",
            resourceName: "interval-countdown"
        ),
        OverlayComponentLibraryItem(
            id: "studio.interval-work-summary",
            displayName: "Interval Work Summary",
            hint: "primary + columns",
            systemImage: "list.bullet.rectangle",
            resourceName: "interval-work-summary"
        ),
        OverlayComponentLibraryItem(
            id: "studio.interval-hud-bar",
            displayName: "Interval HUD Bar",
            hint: "rep + phase + metrics",
            systemImage: "rectangle.split.3x1",
            resourceName: "interval-hud-bar"
        ),
        OverlayComponentLibraryItem(
            id: "studio.interval-timeline",
            displayName: "Interval Timeline",
            hint: "lap schedule + marker",
            systemImage: "rectangle.split.3x1.fill",
            resourceName: "interval-timeline"
        ),
        OverlayComponentLibraryItem(
            id: "studio.zone-edge-bar",
            displayName: "Zone Edge Bar",
            hint: "zones + markers",
            systemImage: "chart.bar.fill",
            resourceName: "zone-edge-bar"
        )
    ]

    /// Chart and dial modules whose data and formatting stay host-owned.
    static let chartComponents: [OverlayComponentLibraryItem] = [
        OverlayComponentLibraryItem(
            id: "studio.running-gauge",
            displayName: "Running Gauge",
            hint: "dial + rings + metrics",
            systemImage: "gauge.with.dots.needle.67percent",
            resourceName: "running-gauge"
        ),
        OverlayComponentLibraryItem(
            id: "studio.distance-timeline",
            displayName: "Distance Timeline",
            hint: "track + axis + marker",
            systemImage: "point.topleft.down.to.point.bottomright.curvepath",
            resourceName: "distance-timeline"
        ),
        OverlayComponentLibraryItem(
            id: "studio.elevation-chart",
            displayName: "Elevation Chart",
            hint: "profile + fill + marker",
            systemImage: "chart.xyaxis.line",
            resourceName: "elevation-chart"
        ),
        OverlayComponentLibraryItem(
            id: "studio.route-map",
            displayName: "Route Map",
            hint: "route + markers",
            systemImage: "map",
            resourceName: "route-map"
        ),
        OverlayComponentLibraryItem(
            id: "studio.stats-bar",
            displayName: "Stats Bar",
            hint: "up to four metrics",
            systemImage: "rectangle.split.3x1",
            resourceName: "stats-bar"
        ),
        OverlayComponentLibraryItem(
            id: "studio.weather-widget",
            displayName: "Weather Widget",
            hint: "weather + metrics",
            systemImage: "cloud.sun.fill",
            resourceName: "weather-widget"
        )
    ]

    static let bundledVisuals: [OverlayComponentLibraryItem] = decor + intervalComponents + chartComponents + examples

    static let examples: [OverlayComponentLibraryItem] = [
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

    /// One Overlay Pool → Metrics entry per metric of the generic
    /// `studio.numeric` definition, which replaced the native numeric
    /// overlays (ADR 0014).
    static let numericPresets: [OverlayComponentLibraryItem] = OverlayComponentMetricCatalog
        .presetOrder
        .map { metric in
            OverlayComponentLibraryItem(
                id: "studio.numeric#\(metric.rawValue)",
                displayName: metric.displayName,
                hint: metric.poolHint,
                systemImage: metric.defaultIconSystemName,
                resourceName: "numeric",
                parameters: ["metricId": .string(metric.rawValue)]
            )
        }
}

enum OverlayComponentLibrary {
    /// One item per bundled resource; presets share a definition.
    private static var uniqueResources: [OverlayComponentLibraryItem] {
        var seen: Set<String> = []
        return OverlayComponentLibraryItem.all.filter { seen.insert($0.resourceName).inserted }
    }

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

    /// A `studio.numeric` instance for one metric, as the Overlay Pool adds it.
    static func numericElement(
        _ metric: OverlayMetric,
        position: CGPoint,
        scale: Double,
        style: OverlayStyle = .default
    ) -> OverlayElement? {
        guard let item = OverlayComponentLibraryItem.numericPresets.first(where: {
            $0.parameters["metricId"] == .string(metric.rawValue)
        }), let reference = try? reference(for: item) else {
            return nil
        }
        return OverlayElement(
            type: .component,
            position: position,
            scale: scale,
            style: style,
            component: OverlayComponentInstance(reference: reference, parameters: item.parameters)
        )
    }

    /// The host's current reference for a bundled id and version, used when a
    /// project or template was authored against an older app build. A version
    /// the host does not ship still fails to resolve.
    static func currentBundledReference(
        matching reference: OverlayComponentReference
    ) -> OverlayComponentReference? {
        guard reference.source == .bundled else { return nil }
        for item in uniqueResources {
            guard let data = data(for: item),
                  let current = try? OverlayComponentReference(
                      definitionData: data,
                      source: .bundled
                  ),
                  current.id == reference.id,
                  current.version == reference.version else {
                continue
            }
            return current
        }
        return nil
    }

    /// Resolves a bundled reference to a validated definition, matching the
    /// digest recorded in the reference so a template or project only resolves
    /// against the exact build it recorded. Callers that need to keep an older
    /// reference rendering refresh it with `currentBundledReference(matching:)`
    /// before resolving.
    static func definition(for reference: OverlayComponentReference) -> OverlayComponentDefinition? {
        guard reference.source == .bundled else { return nil }
        for item in uniqueResources {
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
        for item in uniqueResources {
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
