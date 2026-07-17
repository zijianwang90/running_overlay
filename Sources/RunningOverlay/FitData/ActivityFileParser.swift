import Foundation

enum ActivityFileFormat: String, Equatable {
    case fit
    case gpx

    var displayName: String {
        rawValue.uppercased()
    }
}

enum ActivityFileParserError: LocalizedError, Equatable {
    case unsupportedExtension(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedExtension(let fileExtension):
            let detail = fileExtension.isEmpty ? "without a filename extension" : "with .\(fileExtension) extension"
            return "Activity files \(detail) are not supported. Choose a FIT or GPX file."
        }
    }
}

struct ActivityFileParser {
    static let supportedFilenameExtensions = ["fit", "gpx"]

    static func format(for url: URL) -> ActivityFileFormat? {
        ActivityFileFormat(rawValue: url.pathExtension.lowercased())
    }

    static func parse(url: URL) throws -> ActivityTimeline {
        guard let format = format(for: url) else {
            throw ActivityFileParserError.unsupportedExtension(url.pathExtension.lowercased())
        }

        switch format {
        case .fit:
            return try FitFileParser.parse(url: url)
        case .gpx:
            return try GpxFileParser.parse(url: url)
        }
    }
}
