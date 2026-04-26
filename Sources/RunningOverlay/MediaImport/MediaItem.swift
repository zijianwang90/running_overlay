import Foundation

struct MediaItem: Identifiable, Equatable {
    var id = UUID()
    var displayName: String
    var fileURL: URL?
    var duration: TimeInterval
    var inferredStartDate: Date?
    var cameraGroupID: String
    var alignmentStatus: AlignmentStatus
    var tag: MediaTag? = nil
}

enum MediaTag: String, CaseIterable, Identifiable, Equatable {
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    case gray

    var id: String { rawValue }

    var label: String {
        switch self {
        case .red:
            "Red"
        case .orange:
            "Orange"
        case .yellow:
            "Yellow"
        case .green:
            "Green"
        case .blue:
            "Blue"
        case .purple:
            "Purple"
        case .gray:
            "Gray"
        }
    }
}

enum AlignmentStatus: Equatable {
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
