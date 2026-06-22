import Foundation

struct ProjectSettings: Equatable, Codable {
    var resolution: ProjectResolution = .hd1080
    var frameRate: ProjectFrameRate = .fps30
    var layerDataFrameRate: ProjectLayerDataFrameRate = .fps5
    var previewTrackName: String?
    var disabledPreviewTrackNames: Set<String> = []
    var bitrateMbps: Double = 30
    var exportCodec: ProjectExportCodec = .hevcWithAlpha
    var openWeatherAPIKey: String = ""

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        resolution = try c.decodeIfPresent(ProjectResolution.self, forKey: .resolution) ?? .hd1080
        frameRate = try c.decodeIfPresent(ProjectFrameRate.self, forKey: .frameRate) ?? .fps30
        layerDataFrameRate = try c.decodeIfPresent(ProjectLayerDataFrameRate.self, forKey: .layerDataFrameRate) ?? .fps5
        previewTrackName = try c.decodeIfPresent(String.self, forKey: .previewTrackName)
        disabledPreviewTrackNames = try c.decodeIfPresent(Set<String>.self, forKey: .disabledPreviewTrackNames) ?? []
        bitrateMbps = try c.decodeIfPresent(Double.self, forKey: .bitrateMbps) ?? 30
        exportCodec = try c.decodeIfPresent(ProjectExportCodec.self, forKey: .exportCodec) ?? .hevcWithAlpha
        openWeatherAPIKey = try c.decodeIfPresent(String.self, forKey: .openWeatherAPIKey) ?? ""
    }
}

struct ProjectResolution: Identifiable, Hashable, Codable {
    let id: String
    let label: String
    let width: Int
    let height: Int

    init(id: String, label: String, width: Int, height: Int) {
        self.id = id
        self.label = label
        self.width = width
        self.height = height
    }

    static let hd720 = ProjectResolution(id: "1280x720", label: "720p 16:9", width: 1280, height: 720)
    static let hd1080 = ProjectResolution(id: "1920x1080", label: "1080p 16:9", width: 1920, height: 1080)
    static let qhd1440 = ProjectResolution(id: "2560x1440", label: "2K 16:9", width: 2560, height: 1440)
    static let uhd4k = ProjectResolution(id: "3840x2160", label: "4K 16:9", width: 3840, height: 2160)
    static let vertical720 = ProjectResolution(id: "720x1280", label: "720p 9:16", width: 720, height: 1280)
    static let vertical1080 = ProjectResolution(id: "1080x1920", label: "1080p 9:16", width: 1080, height: 1920)
    static let vertical1440 = ProjectResolution(id: "1440x2560", label: "2K 9:16", width: 1440, height: 2560)
    static let vertical4k = ProjectResolution(id: "2160x3840", label: "4K 9:16", width: 2160, height: 3840)

    static let presets: [ProjectResolution] = [
        .hd720, .hd1080, .qhd1440, .uhd4k,
        .vertical720, .vertical1080, .vertical1440, .vertical4k
    ]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let id = try container.decode(String.self)
        self = Self.presets.first(where: { $0.id == id }) ?? .hd1080
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }
}

struct ProjectFrameRate: Identifiable, Hashable, Codable {
    let id: String
    let label: String
    let value: Double

    init(id: String, label: String, value: Double) {
        self.id = id
        self.label = label
        self.value = value
    }

    static let fps23976 = ProjectFrameRate(id: "23.976", label: "23.976 fps", value: 23.976)
    static let fps24 = ProjectFrameRate(id: "24", label: "24 fps", value: 24)
    static let fps25 = ProjectFrameRate(id: "25", label: "25 fps", value: 25)
    static let fps2997 = ProjectFrameRate(id: "29.97", label: "29.97 fps", value: 29.97)
    static let fps30 = ProjectFrameRate(id: "30", label: "30 fps", value: 30)
    static let fps50 = ProjectFrameRate(id: "50", label: "50 fps", value: 50)
    static let fps5994 = ProjectFrameRate(id: "59.94", label: "59.94 fps", value: 59.94)
    static let fps60 = ProjectFrameRate(id: "60", label: "60 fps", value: 60)

    static let presets: [ProjectFrameRate] = [
        .fps23976, .fps24, .fps25, .fps2997, .fps30, .fps50, .fps5994, .fps60
    ]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let id = try container.decode(String.self)
        self = Self.presets.first(where: { $0.id == id }) ?? .fps30
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }
}

struct ProjectLayerDataFrameRate: Identifiable, Hashable, Codable {
    let id: String
    let label: String
    let value: Double

    init(id: String, label: String, value: Double) {
        self.id = id
        self.label = label
        self.value = value
    }

    static let fps1 = ProjectLayerDataFrameRate(id: "1", label: "1 fps", value: 1)
    static let fps2 = ProjectLayerDataFrameRate(id: "2", label: "2 fps", value: 2)
    static let fps5 = ProjectLayerDataFrameRate(id: "5", label: "5 fps", value: 5)
    static let fps10 = ProjectLayerDataFrameRate(id: "10", label: "10 fps", value: 10)
    static let fps15 = ProjectLayerDataFrameRate(id: "15", label: "15 fps", value: 15)
    static let fps30 = ProjectLayerDataFrameRate(id: "30", label: "30 fps", value: 30)

    static let presets: [ProjectLayerDataFrameRate] = [
        .fps1, .fps2, .fps5, .fps10, .fps15, .fps30
    ]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let id = try container.decode(String.self)
        self = Self.presets.first(where: { $0.id == id }) ?? .fps5
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }
}

enum ProjectExportCodec: String, CaseIterable, Identifiable, Codable {
    case hevcWithAlpha
    case proRes4444

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hevcWithAlpha:
            "H.265 with Alpha"
        case .proRes4444:
            "ProRes 4444"
        }
    }
}
