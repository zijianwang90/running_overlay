import Foundation

struct ProjectSettings: Equatable, Codable {
    private enum CodingKeys: String, CodingKey {
        case aspectRatio
        case resolution
        case frameRate
        case layerDataFrameRate
        case previewTrackName
        case disabledPreviewTrackNames
        case bitrateMbps
        case exportCodec
        case openWeatherAPIKey
    }

    private(set) var aspectRatio: ProjectAspectRatio = .landscape16x9
    var resolution: ProjectResolution = .hd1080 {
        didSet {
            guard !aspectRatio.matches(resolution) else { return }
            aspectRatio = ProjectAspectRatio.inferred(from: resolution)
        }
    }
    var frameRate: ProjectFrameRate = .fps30
    var layerDataFrameRate: ProjectLayerDataFrameRate = .fps5
    var previewTrackName: String?
    var disabledPreviewTrackNames: Set<String> = []
    var bitrateMbps: Double = 30
    var exportCodec: ProjectExportCodec = .hevcWithAlpha
    private(set) var legacyOpenWeatherAPIKey: String?

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let decodedResolution = try c.decodeIfPresent(ProjectResolution.self, forKey: .resolution) ?? .hd1080
        let decodedAspectRatio = try c.decodeIfPresent(ProjectAspectRatio.self, forKey: .aspectRatio)
            ?? ProjectAspectRatio.inferred(from: decodedResolution)
        aspectRatio = decodedAspectRatio
        resolution = decodedAspectRatio.matches(decodedResolution)
            ? decodedResolution
            : ProjectResolution.preferredPreset(
                for: decodedAspectRatio,
                matchingShortEdge: decodedResolution.shortEdge
            )
        frameRate = try c.decodeIfPresent(ProjectFrameRate.self, forKey: .frameRate) ?? .fps30
        layerDataFrameRate = try c.decodeIfPresent(ProjectLayerDataFrameRate.self, forKey: .layerDataFrameRate) ?? .fps5
        previewTrackName = try c.decodeIfPresent(String.self, forKey: .previewTrackName)
        disabledPreviewTrackNames = try c.decodeIfPresent(Set<String>.self, forKey: .disabledPreviewTrackNames) ?? []
        bitrateMbps = try c.decodeIfPresent(Double.self, forKey: .bitrateMbps) ?? 30
        exportCodec = try c.decodeIfPresent(ProjectExportCodec.self, forKey: .exportCodec) ?? .hevcWithAlpha
        legacyOpenWeatherAPIKey = try c.decodeIfPresent(String.self, forKey: .openWeatherAPIKey)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(aspectRatio, forKey: .aspectRatio)
        try c.encode(resolution, forKey: .resolution)
        try c.encode(frameRate, forKey: .frameRate)
        try c.encode(layerDataFrameRate, forKey: .layerDataFrameRate)
        try c.encodeIfPresent(previewTrackName, forKey: .previewTrackName)
        try c.encode(disabledPreviewTrackNames, forKey: .disabledPreviewTrackNames)
        try c.encode(bitrateMbps, forKey: .bitrateMbps)
        try c.encode(exportCodec, forKey: .exportCodec)
        // Credentials are stored in the macOS Keychain. Keep the legacy coding
        // key decodable for migration, but never write it into project data.
    }

    mutating func removeLegacyCredentials() {
        legacyOpenWeatherAPIKey = nil
    }

    mutating func setAspectRatio(_ newAspectRatio: ProjectAspectRatio) {
        guard newAspectRatio != aspectRatio else { return }
        let shortEdge = resolution.shortEdge
        aspectRatio = newAspectRatio
        resolution = ProjectResolution.preferredPreset(
            for: newAspectRatio,
            matchingShortEdge: shortEdge
        )
    }
}

enum ProjectAspectRatio: String, CaseIterable, Identifiable, Codable {
    case landscape16x9
    case landscape4x3
    case landscape1x1
    case portrait9x16
    case portrait3x4
    case portrait1x1

    var id: String { rawValue }

    static let landscapePresets: [ProjectAspectRatio] = [
        .landscape16x9, .landscape4x3, .landscape1x1
    ]

    static let portraitPresets: [ProjectAspectRatio] = [
        .portrait9x16, .portrait3x4, .portrait1x1
    ]

    var label: String {
        "\(ratioLabel) \(orientationLabel)"
    }

    var ratioLabel: String {
        switch self {
        case .landscape16x9: "16:9"
        case .landscape4x3: "4:3"
        case .landscape1x1, .portrait1x1: "1:1"
        case .portrait9x16: "9:16"
        case .portrait3x4: "3:4"
        }
    }

    var orientationLabel: String {
        switch self {
        case .landscape16x9, .landscape4x3, .landscape1x1:
            "Landscape"
        case .portrait9x16, .portrait3x4, .portrait1x1:
            "Portrait"
        }
    }

    func matches(_ resolution: ProjectResolution) -> Bool {
        resolution.width * heightUnits == resolution.height * widthUnits
    }

    static func inferred(from resolution: ProjectResolution) -> ProjectAspectRatio {
        if resolution.width == resolution.height {
            return .landscape1x1
        }

        let candidates = resolution.width > resolution.height ? landscapePresets : portraitPresets
        return candidates.first(where: { $0.matches(resolution) })
            ?? (resolution.width > resolution.height ? .landscape16x9 : .portrait9x16)
    }

    private var widthUnits: Int {
        switch self {
        case .landscape16x9: 16
        case .landscape4x3: 4
        case .landscape1x1, .portrait1x1: 1
        case .portrait9x16: 9
        case .portrait3x4: 3
        }
    }

    private var heightUnits: Int {
        switch self {
        case .landscape16x9: 9
        case .landscape4x3: 3
        case .landscape1x1, .portrait1x1: 1
        case .portrait9x16: 16
        case .portrait3x4: 4
        }
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

    static let hd720 = ProjectResolution(id: "1280x720", label: "720p - 1280 x 720", width: 1280, height: 720)
    static let hd1080 = ProjectResolution(id: "1920x1080", label: "1080p - 1920 x 1080", width: 1920, height: 1080)
    static let qhd1440 = ProjectResolution(id: "2560x1440", label: "1440p - 2560 x 1440", width: 2560, height: 1440)
    static let uhd4k = ProjectResolution(id: "3840x2160", label: "2160p - 3840 x 2160", width: 3840, height: 2160)
    static let vertical720 = ProjectResolution(id: "720x1280", label: "720p - 720 x 1280", width: 720, height: 1280)
    static let vertical1080 = ProjectResolution(id: "1080x1920", label: "1080p - 1080 x 1920", width: 1080, height: 1920)
    static let vertical1440 = ProjectResolution(id: "1440x2560", label: "1440p - 1440 x 2560", width: 1440, height: 2560)
    static let vertical4k = ProjectResolution(id: "2160x3840", label: "2160p - 2160 x 3840", width: 2160, height: 3840)

    static let landscape4x3_720 = ProjectResolution(id: "960x720", label: "720p - 960 x 720", width: 960, height: 720)
    static let landscape4x3_1080 = ProjectResolution(id: "1440x1080", label: "1080p - 1440 x 1080", width: 1440, height: 1080)
    static let landscape4x3_1440 = ProjectResolution(id: "1920x1440", label: "1440p - 1920 x 1440", width: 1920, height: 1440)
    static let landscape4x3_2160 = ProjectResolution(id: "2880x2160", label: "2160p - 2880 x 2160", width: 2880, height: 2160)
    static let portrait3x4_720 = ProjectResolution(id: "720x960", label: "720p - 720 x 960", width: 720, height: 960)
    static let portrait3x4_1080 = ProjectResolution(id: "1080x1440", label: "1080p - 1080 x 1440", width: 1080, height: 1440)
    static let portrait3x4_1440 = ProjectResolution(id: "1440x1920", label: "1440p - 1440 x 1920", width: 1440, height: 1920)
    static let portrait3x4_2160 = ProjectResolution(id: "2160x2880", label: "2160p - 2160 x 2880", width: 2160, height: 2880)
    static let square720 = ProjectResolution(id: "720x720", label: "720p - 720 x 720", width: 720, height: 720)
    static let square1080 = ProjectResolution(id: "1080x1080", label: "1080p - 1080 x 1080", width: 1080, height: 1080)
    static let square1440 = ProjectResolution(id: "1440x1440", label: "1440p - 1440 x 1440", width: 1440, height: 1440)
    static let square2160 = ProjectResolution(id: "2160x2160", label: "2160p - 2160 x 2160", width: 2160, height: 2160)

    static let presets: [ProjectResolution] = [
        .hd720, .hd1080, .qhd1440, .uhd4k,
        .vertical720, .vertical1080, .vertical1440, .vertical4k,
        .landscape4x3_720, .landscape4x3_1080, .landscape4x3_1440, .landscape4x3_2160,
        .portrait3x4_720, .portrait3x4_1080, .portrait3x4_1440, .portrait3x4_2160,
        .square720, .square1080, .square1440, .square2160
    ]

    static func presets(for aspectRatio: ProjectAspectRatio) -> [ProjectResolution] {
        switch aspectRatio {
        case .landscape16x9:
            [.hd720, .hd1080, .qhd1440, .uhd4k]
        case .portrait9x16:
            [.vertical720, .vertical1080, .vertical1440, .vertical4k]
        case .landscape4x3:
            [.landscape4x3_720, .landscape4x3_1080, .landscape4x3_1440, .landscape4x3_2160]
        case .portrait3x4:
            [.portrait3x4_720, .portrait3x4_1080, .portrait3x4_1440, .portrait3x4_2160]
        case .landscape1x1, .portrait1x1:
            [.square720, .square1080, .square1440, .square2160]
        }
    }

    static func preferredPreset(
        for aspectRatio: ProjectAspectRatio,
        matchingShortEdge shortEdge: Int
    ) -> ProjectResolution {
        presets(for: aspectRatio).min {
            abs($0.shortEdge - shortEdge) < abs($1.shortEdge - shortEdge)
        } ?? .hd1080
    }

    var shortEdge: Int {
        min(width, height)
    }

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
