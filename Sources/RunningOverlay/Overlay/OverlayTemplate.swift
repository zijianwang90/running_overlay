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

struct OverlayTemplateElement: Codable, Equatable {
    var type: OverlayElementType
    var positionX: Double
    var positionY: Double
    var scale: Double
    var style: OverlayStyle

    init(type: OverlayElementType, positionX: Double, positionY: Double, scale: Double, style: OverlayStyle) {
        self.type = type
        self.positionX = positionX
        self.positionY = positionY
        self.scale = scale
        self.style = style
    }

    init(element: OverlayElement) {
        self.init(
            type: element.type,
            positionX: element.position.x,
            positionY: element.position.y,
            scale: element.scale,
            style: element.style
        )
    }

    var overlayElement: OverlayElement {
        OverlayElement(
            type: type,
            position: CGPoint(x: positionX, y: positionY),
            scale: scale,
            style: style
        )
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
