import Foundation

struct OverlayTemplate: Identifiable, Codable, Equatable {
    var schemaVersion: Int
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var referenceResolution: OverlayTemplateResolution?
    var elements: [OverlayTemplateElement]

    init(
        schemaVersion: Int = 1,
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        referenceResolution: OverlayTemplateResolution? = nil,
        elements: [OverlayTemplateElement]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.referenceResolution = referenceResolution
        self.elements = elements
    }

    init(
        name: String,
        layout: OverlayLayout,
        referenceResolution: OverlayTemplateResolution? = nil,
        now: Date = Date()
    ) {
        self.init(
            name: name,
            createdAt: now,
            updatedAt: now,
            referenceResolution: referenceResolution,
            elements: layout.elements.map(OverlayTemplateElement.init(element:))
        )
    }

    var layout: OverlayLayout {
        OverlayLayout(elements: elements.map(\.overlayElement))
    }
}

struct OverlayTemplateResolution: Codable, Equatable {
    var width: Int
    var height: Int
}

struct BuiltInOverlayTemplate: Identifiable, Equatable {
    struct Element: Equatable {
        var type: OverlayElementType
        var positionX: Double
        var positionY: Double
        var scale: Double
    }

    var id: String
    var name: String
    var elements: [Element]

    static let all: [BuiltInOverlayTemplate] = [
        BuiltInOverlayTemplate(
            id: "easyRun",
            name: "Easy Run",
            elements: [
                Element(type: .distance, positionX: 0.22, positionY: 0.82, scale: 1.0),
                Element(type: .pace, positionX: 0.78, positionY: 0.82, scale: 1.0),
                Element(type: .heartRate, positionX: 0.18, positionY: 0.18, scale: 1.0)
            ]
        ),
        BuiltInOverlayTemplate(
            id: "intervalWorkout",
            name: "Interval Workout",
            elements: [
                Element(type: .elapsedTime, positionX: 0.5, positionY: 0.16, scale: 1.0),
                Element(type: .pace, positionX: 0.78, positionY: 0.82, scale: 1.0),
                Element(type: .heartRate, positionX: 0.22, positionY: 0.82, scale: 1.0),
                Element(type: .lapLive, positionX: 0.5, positionY: 0.86, scale: 1.0)
            ]
        ),
        BuiltInOverlayTemplate(
            id: "race",
            name: "Race",
            elements: [
                Element(type: .distanceTimeline, positionX: 0.5, positionY: 0.86, scale: 1.0),
                Element(type: .runningGauge, positionX: 0.18, positionY: 0.25, scale: 1.0),
                Element(type: .routeMap, positionX: 0.82, positionY: 0.26, scale: 0.9),
                Element(type: .pace, positionX: 0.82, positionY: 0.82, scale: 1.0)
            ]
        )
    ]
}

struct OverlayTemplateElement: Codable, Equatable {
    var type: OverlayElementType
    var positionX: Double
    var positionY: Double
    var scale: Double
    var isVisible: Bool
    var isLocked: Bool
    var style: OverlayStyle

    init(
        type: OverlayElementType,
        positionX: Double,
        positionY: Double,
        scale: Double,
        isVisible: Bool = true,
        isLocked: Bool = false,
        style: OverlayStyle
    ) {
        self.type = type
        self.positionX = positionX
        self.positionY = positionY
        self.scale = scale
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.style = style
    }

    init(element: OverlayElement) {
        self.init(
            type: element.type,
            positionX: element.position.x,
            positionY: element.position.y,
            scale: element.scale,
            isVisible: element.isVisible,
            isLocked: element.isLocked,
            style: element.style
        )
    }

    var overlayElement: OverlayElement {
        OverlayElement(
            type: type,
            position: CGPoint(x: positionX, y: positionY),
            scale: scale,
            isVisible: isVisible,
            isLocked: isLocked,
            style: style
        )
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case positionX
        case positionY
        case scale
        case isVisible
        case isLocked
        case style
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(OverlayElementType.self, forKey: .type)
        positionX = try container.decode(Double.self, forKey: .positionX)
        positionY = try container.decode(Double.self, forKey: .positionY)
        scale = try container.decode(Double.self, forKey: .scale)
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        style = try container.decode(OverlayStyle.self, forKey: .style)
    }
}

struct OverlayTemplateStore {
    static let fileExtension = "rotemplate"
    var fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
    }

    func load() throws -> [OverlayTemplate] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([OverlayTemplate].self, from: data)
    }

    func save(_ templates: [OverlayTemplate]) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(templates)
        try data.write(to: fileURL, options: .atomic)
    }

    func loadTemplateFile(from url: URL) throws -> OverlayTemplate {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(OverlayTemplate.self, from: data)
    }

    func exportTemplate(_ template: OverlayTemplate, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(template)
        try data.write(to: url, options: .atomic)
    }

    private static func defaultFileURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return baseURL
            .appendingPathComponent("RunningOverlay", isDirectory: true)
            .appendingPathComponent("OverlayTemplates.json")
    }
}
