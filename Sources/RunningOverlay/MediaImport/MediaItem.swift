import Foundation

struct MediaItem: Identifiable, Equatable, Codable {
    var id = UUID()
    var displayName: String
    var fileURL: URL?
    var duration: TimeInterval
    var inferredStartDate: Date?
    var cameraGroupID: String
    var alignmentStatus: AlignmentStatus
    var folderID: MediaFolder.ID? = nil
}

struct MediaFolder: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
}

enum AlignmentStatus: Equatable, Codable {
    case readyToMatch(source: String)
    case aligned(source: String)
    case needsManualPlacement

    var label: String {
        switch self {
        case .readyToMatch(let source):
            "Ready to match by \(source)"
        case .aligned(let source):
            "Aligned by \(source)"
        case .needsManualPlacement:
            "Needs placement"
        }
    }
}
