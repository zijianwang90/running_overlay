import AVFoundation
import Foundation

enum MediaMetadataReader {
    static func read(url: URL, activity: ActivityTimeline) async -> MediaItem {
        let asset = AVURLAsset(url: url)
        let duration = await loadDuration(asset)
        let metadataDate = await loadCreationDate(asset)
        let filenameDate = FilenameDateParser.date(from: url.deletingPathExtension().lastPathComponent)
        let inferredDate = metadataDate ?? filenameDate
        let cameraGroup = cameraGroupName(for: url)
        let alignmentStatus = alignmentStatus(for: inferredDate, activity: activity)

        return MediaItem(
            displayName: url.lastPathComponent,
            fileURL: url,
            duration: duration,
            inferredStartDate: inferredDate,
            cameraGroupID: cameraGroup,
            alignmentStatus: alignmentStatus
        )
    }

    private static func loadDuration(_ asset: AVURLAsset) async -> TimeInterval {
        do {
            let duration = try await asset.load(.duration)
            guard duration.isNumeric else {
                return 0
            }
            return duration.seconds
        } catch {
            return 0
        }
    }

    private static func loadCreationDate(_ asset: AVURLAsset) async -> Date? {
        do {
            let metadata = try await asset.load(.metadata)
            for item in metadata {
                if let commonKey = item.commonKey, commonKey == .commonKeyCreationDate {
                    if let date = try? await item.load(.dateValue) {
                        return date
                    }
                    if let string = try? await item.load(.stringValue), let date = MetadataDateParser.date(from: string) {
                        return date
                    }
                }

                let identifier = item.identifier?.rawValue.lowercased() ?? ""
                if identifier.contains("creationdate") || identifier.contains("creation_date") {
                    if let date = try? await item.load(.dateValue) {
                        return date
                    }
                    if let string = try? await item.load(.stringValue), let date = MetadataDateParser.date(from: string) {
                        return date
                    }
                }
            }
        } catch {
            return nil
        }

        return nil
    }

    private static func alignmentStatus(for date: Date?, activity: ActivityTimeline) -> AlignmentStatus {
        guard let date else {
            return .needsManualPlacement
        }

        let tolerance: TimeInterval = 12 * 60 * 60
        let earliest = activity.startDate.addingTimeInterval(-tolerance)
        let latest = activity.endDate.addingTimeInterval(tolerance)
        if date >= earliest && date <= latest {
            return .readyToMatch(source: "timestamp")
        }
        return .needsManualPlacement
    }

    private static func cameraGroupName(for url: URL) -> String {
        let name = url.deletingPathExtension().lastPathComponent
        let separators = CharacterSet(charactersIn: "_- .")
        let firstToken = name.components(separatedBy: separators).first?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstToken, !firstToken.isEmpty else {
            return "Camera"
        }
        return firstToken
    }
}

enum FilenameDateParser {
    static func date(from filename: String) -> Date? {
        let candidates = [
            #"(\d{4})(\d{2})(\d{2})[_-]?(\d{2})(\d{2})(\d{2})"#,
            #"(\d{4})-(\d{2})-(\d{2})[_ T-](\d{2})[.-]?(\d{2})[.-]?(\d{2})"#,
            #"(\d{4})_(\d{2})_(\d{2})[_-](\d{2})_(\d{2})_(\d{2})"#
        ]

        for pattern in candidates {
            guard let match = firstMatch(pattern: pattern, in: filename) else {
                continue
            }
            var components = DateComponents()
            components.calendar = Calendar(identifier: .gregorian)
            components.timeZone = .current
            components.year = Int(match[0])
            components.month = Int(match[1])
            components.day = Int(match[2])
            components.hour = Int(match[3])
            components.minute = Int(match[4])
            components.second = Int(match[5])
            if let date = components.date {
                return date
            }
        }

        return nil
    }

    private static func firstMatch(pattern: String, in string: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        guard let match = regex.firstMatch(in: string, range: range), match.numberOfRanges == 7 else {
            return nil
        }

        return (1..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: string) else {
                return nil
            }
            return String(string[range])
        }
    }
}

enum MetadataDateParser {
    static func date(from string: String) -> Date? {
        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    private static let formatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd HH:mm:ss Z",
            "yyyy:MM:dd HH:mm:ss"
        ]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            return formatter
        }
    }()
}
