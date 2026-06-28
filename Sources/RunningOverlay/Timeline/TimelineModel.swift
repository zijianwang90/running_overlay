import Foundation

struct TimelineModel: Equatable, Codable {
    var tracks: [TimelineTrack]
    var zoom: TimelineZoom = .fit
    var playhead: TimeInterval = 0
    var fitStartTime: TimeInterval = 0

    static let empty = TimelineModel(tracks: [])

    mutating func zoomIn() {
        zoom = zoom.zoomedIn()
    }

    mutating func zoomOut() {
        zoom = zoom.zoomedOut()
    }

    mutating func replaceClips(with mediaItems: [MediaItem], activity: ActivityTimeline) {
        let clipsByCamera = Dictionary(grouping: mediaItems.compactMap { item -> TimelineClip? in
            let canUseTimestamp: Bool
            switch item.alignmentStatus {
            case .aligned, .readyToMatch:
                canUseTimestamp = true
            case .needsManualPlacement:
                canUseTimestamp = false
            }
            guard canUseTimestamp, let inferredStartDate = item.inferredStartDate else {
                return nil
            }

            let startTime = inferredStartDate.timeIntervalSince(activity.startDate)
            let duration = max(item.duration, 0.1)
            guard duration > 0 else {
                return nil
            }

            return TimelineClip(
                mediaItemID: item.id,
                title: item.displayName,
                startTime: fitStartTime + startTime,
                duration: duration,
                alignmentOffset: 0,
                cameraGroupID: item.cameraGroupID
            )
        }, by: \.cameraGroupID)

        tracks = clipsByCamera
            .keys
            .sorted()
            .map { camera in
                TimelineTrack(
                    name: camera,
                    clips: clipsByCamera[camera, default: []].sorted { $0.startTime < $1.startTime }
                )
            }
    }

    func wouldClipOverlap(
        mediaItemID: MediaItem.ID,
        trackName: String,
        startTime: TimeInterval,
        duration: TimeInterval
    ) -> Bool {
        guard let track = tracks.first(where: { $0.name == trackName }) else { return false }
        let newStart = startTime
        let newEnd = startTime + max(duration, 0.1)
        for clip in track.clips where clip.mediaItemID != mediaItemID {
            let existingStart = clip.effectiveStartTime
            let existingEnd = existingStart + clip.duration
            if newStart < existingEnd && existingStart < newEnd {
                return true
            }
        }
        return false
    }

    mutating func addOrMoveClip(
        mediaItem: MediaItem,
        trackName: String,
        startTime: TimeInterval,
        activity: ActivityTimeline
    ) -> TimelineClip.ID? {
        removeClip(for: mediaItem.id)

        let duration = max(mediaItem.duration, 0.1)
        let clip = TimelineClip(
            mediaItemID: mediaItem.id,
            title: mediaItem.displayName,
            startTime: startTime,
            duration: duration,
            alignmentOffset: 0,
            cameraGroupID: trackName
        )

        if let trackIndex = tracks.firstIndex(where: { $0.name == trackName }) {
            tracks[trackIndex].clips.append(clip)
            tracks[trackIndex].clips.sort { $0.effectiveStartTime < $1.effectiveStartTime }
        } else {
            tracks.append(TimelineTrack(name: trackName, clips: [clip]))
            tracks.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }

        return clip.id
    }

    mutating func setClipOffset(_ clipID: TimelineClip.ID, offset: TimeInterval, activityDuration: TimeInterval) {
        guard let indexPath = clipIndexPath(clipID) else {
            return
        }
        tracks[indexPath.track].clips[indexPath.clip].alignmentOffset = offset
        tracks[indexPath.track].clips.sort { $0.effectiveStartTime < $1.effectiveStartTime }
    }

    mutating func moveClip(_ clipID: TimelineClip.ID, toEffectiveStartTime effectiveStartTime: TimeInterval, activityDuration: TimeInterval) {
        guard let indexPath = clipIndexPath(clipID) else {
            return
        }
        let clip = tracks[indexPath.track].clips[indexPath.clip]
        tracks[indexPath.track].clips[indexPath.clip].startTime = effectiveStartTime - clip.alignmentOffset
        tracks[indexPath.track].clips.sort { $0.effectiveStartTime < $1.effectiveStartTime }
    }

    mutating func setClipDuration(_ clipID: TimelineClip.ID, duration: TimeInterval, activityDuration: TimeInterval) {
        guard let indexPath = clipIndexPath(clipID) else {
            return
        }
        tracks[indexPath.track].clips[indexPath.clip].duration = max(duration, 0.1)
    }

    mutating func renameTrack(containing clipID: TimelineClip.ID, to name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, let indexPath = clipIndexPath(clipID) else {
            return
        }

        let clip = tracks[indexPath.track].clips.remove(at: indexPath.clip)
        let updatedClip = TimelineClip(
            id: clip.id,
            mediaItemID: clip.mediaItemID,
            title: clip.title,
            startTime: clip.startTime,
            duration: clip.duration,
            alignmentOffset: clip.alignmentOffset,
            cameraGroupID: trimmedName
        )
        if tracks[indexPath.track].clips.isEmpty {
            tracks.remove(at: indexPath.track)
        }

        if let destinationIndex = tracks.firstIndex(where: { $0.name == trimmedName }) {
            tracks[destinationIndex].clips.append(updatedClip)
            tracks[destinationIndex].clips.sort { $0.effectiveStartTime < $1.effectiveStartTime }
        } else {
            tracks.append(TimelineTrack(name: trimmedName, clips: [updatedClip]))
            tracks.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    mutating func applyOffset(_ offset: TimeInterval, toTrackContaining clipID: TimelineClip.ID, activityDuration: TimeInterval) {
        guard let indexPath = clipIndexPath(clipID) else {
            return
        }
        let trackIndex = indexPath.track
        for clipIndex in tracks[trackIndex].clips.indices {
            tracks[trackIndex].clips[clipIndex].alignmentOffset = offset
        }
        tracks[trackIndex].clips.sort { $0.effectiveStartTime < $1.effectiveStartTime }
    }

    func clip(with id: TimelineClip.ID) -> TimelineClip? {
        for track in tracks {
            if let clip = track.clips.first(where: { $0.id == id }) {
                return clip
            }
        }
        return nil
    }

    mutating func removeTrack(named name: String) {
        tracks.removeAll { $0.name == name }
    }

    mutating func deleteClip(_ clipID: TimelineClip.ID) {
        for trackIndex in tracks.indices {
            tracks[trackIndex].clips.removeAll { $0.id == clipID }
        }
        tracks.removeAll { $0.clips.isEmpty }
    }

    mutating func deleteClips(forMediaItemIDs mediaItemIDs: Set<MediaItem.ID>) {
        guard !mediaItemIDs.isEmpty else {
            return
        }
        for trackIndex in tracks.indices {
            tracks[trackIndex].clips.removeAll { clip in
                guard let mediaItemID = clip.mediaItemID else {
                    return false
                }
                return mediaItemIDs.contains(mediaItemID)
            }
        }
        tracks.removeAll { $0.clips.isEmpty }
    }

    func visibleClip(
        at playhead: TimeInterval,
        preferredTrackName: String? = nil,
        disabledTrackNames: Set<String> = []
    ) -> TimelineClip? {
        let orderedTracks: [TimelineTrack]
        let enabledTracks = tracks.filter { !disabledTrackNames.contains($0.name) }
        if let preferredTrackName, let preferredTrack = enabledTracks.first(where: { $0.name == preferredTrackName }) {
            orderedTracks = [preferredTrack] + enabledTracks.filter { $0.id != preferredTrack.id }
        } else {
            orderedTracks = enabledTracks
        }

        for track in orderedTracks {
            if let clip = track.clips.first(where: {
                playhead >= $0.effectiveStartTime && playhead < $0.effectiveStartTime + $0.duration
            }) {
                return clip
            }
        }
        return nil
    }

    func displayBounds(activityDuration: TimeInterval, collapsed: Bool) -> ClosedRange<TimeInterval> {
        guard collapsed else {
            return projectBounds(activityDuration: activityDuration)
        }
        let duration = collapsedDisplaySegments().last?.displayEndTime ?? 0
        return 0...max(duration, 1)
    }

    func displayTime(forProjectTime projectTime: TimeInterval, activityDuration: TimeInterval, collapsed: Bool) -> TimeInterval {
        guard collapsed else {
            return projectTime
        }
        let segments = collapsedDisplaySegments()
        guard let firstSegment = segments.first else {
            return projectTime - projectBounds(activityDuration: activityDuration).lowerBound
        }

        if projectTime <= firstSegment.projectStartTime {
            return 0
        }

        for segment in segments {
            if projectTime < segment.projectStartTime {
                return segment.displayStartTime
            }
            if projectTime <= segment.projectEndTime {
                return segment.displayStartTime + projectTime - segment.projectStartTime
            }
        }

        return segments.last?.displayEndTime ?? 0
    }

    func projectTime(forDisplayTime displayTime: TimeInterval, activityDuration: TimeInterval, collapsed: Bool) -> TimeInterval {
        guard collapsed else {
            return displayTime
        }
        let segments = collapsedDisplaySegments()
        guard let firstSegment = segments.first else {
            return projectBounds(activityDuration: activityDuration).lowerBound + displayTime
        }

        let clampedDisplayTime = min(max(displayTime, 0), segments.last?.displayEndTime ?? 0)
        for segment in segments {
            if clampedDisplayTime <= segment.displayEndTime {
                return segment.projectStartTime + max(clampedDisplayTime - segment.displayStartTime, 0)
            }
        }

        return firstSegment.projectStartTime
    }

    func visiblePlaybackTime(atOrAfter projectTime: TimeInterval) -> TimeInterval? {
        let segments = collapsedDisplaySegments()
        guard !segments.isEmpty else {
            return nil
        }

        for segment in segments {
            if projectTime < segment.projectStartTime {
                return segment.projectStartTime
            }
            if projectTime < segment.projectEndTime {
                return projectTime
            }
        }
        return nil
    }

    func collapsedDisplaySegments() -> [TimelineDisplaySegment] {
        let clips = tracks
            .flatMap(\.clips)
            .sorted {
                if $0.effectiveStartTime == $1.effectiveStartTime {
                    return $0.duration < $1.duration
                }
                return $0.effectiveStartTime < $1.effectiveStartTime
            }
        guard !clips.isEmpty else {
            return []
        }

        let intervals: [(start: TimeInterval, end: TimeInterval)]
        if tracks.count <= 1 {
            intervals = clips.map { clip in
                (clip.effectiveStartTime, clip.effectiveStartTime + clip.duration)
            }
        } else {
            intervals = Self.mergedIntervals(from: clips.map { clip in
                (clip.effectiveStartTime, clip.effectiveStartTime + clip.duration)
            })
        }

        var displayStart: TimeInterval = 0
        return intervals.compactMap { interval in
            let duration = max(interval.end - interval.start, 0)
            guard duration > 0 else {
                return nil
            }
            defer {
                displayStart += duration
            }
            return TimelineDisplaySegment(
                projectStartTime: interval.start,
                projectEndTime: interval.end,
                displayStartTime: displayStart
            )
        }
    }

    private mutating func removeClip(for mediaItemID: MediaItem.ID) {
        for trackIndex in tracks.indices {
            tracks[trackIndex].clips.removeAll { $0.mediaItemID == mediaItemID }
        }
        tracks.removeAll { $0.clips.isEmpty }
    }

    private static func mergedIntervals(from intervals: [(start: TimeInterval, end: TimeInterval)]) -> [(start: TimeInterval, end: TimeInterval)] {
        let sortedIntervals = intervals
            .filter { $0.end > $0.start }
            .sorted { $0.start < $1.start }
        guard var current = sortedIntervals.first else {
            return []
        }

        var merged: [(start: TimeInterval, end: TimeInterval)] = []
        for interval in sortedIntervals.dropFirst() {
            if interval.start <= current.end {
                current.end = max(current.end, interval.end)
            } else {
                merged.append(current)
                current = interval
            }
        }
        merged.append(current)
        return merged
    }

    mutating func moveFitStart(to startTime: TimeInterval) {
        fitStartTime = startTime
    }

    func activityElapsed(atProjectTime projectTime: TimeInterval) -> TimeInterval {
        projectTime - fitStartTime
    }

    func projectBounds(activityDuration: TimeInterval) -> ClosedRange<TimeInterval> {
        var lowerBound = fitStartTime
        var upperBound = fitStartTime + max(activityDuration, 0)
        for track in tracks {
            for clip in track.clips {
                lowerBound = min(lowerBound, clip.effectiveStartTime)
                upperBound = max(upperBound, clip.effectiveStartTime + clip.duration)
            }
        }
        if upperBound <= lowerBound {
            upperBound = lowerBound + max(activityDuration, 1)
        }
        return lowerBound...upperBound
    }

    func nextLayerName() -> String {
        let existingNames = Set(tracks.map(\.name))
        var index = max(tracks.count + 1, 1)
        while existingNames.contains("Layer \(index)") {
            index += 1
        }
        return "Layer \(index)"
    }

    private func clipIndexPath(_ clipID: TimelineClip.ID) -> (track: Int, clip: Int)? {
        for trackIndex in tracks.indices {
            if let clipIndex = tracks[trackIndex].clips.firstIndex(where: { $0.id == clipID }) {
                return (trackIndex, clipIndex)
            }
        }
        return nil
    }

}

struct TimelineDisplaySegment: Equatable {
    var projectStartTime: TimeInterval
    var projectEndTime: TimeInterval
    var displayStartTime: TimeInterval

    var displayEndTime: TimeInterval {
        displayStartTime + projectEndTime - projectStartTime
    }
}

struct TimelineTrack: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
    var clips: [TimelineClip]
}

struct TimelineClip: Identifiable, Equatable, Codable {
    var id = UUID()
    var mediaItemID: MediaItem.ID?
    var title: String
    var startTime: TimeInterval
    var duration: TimeInterval
    var alignmentOffset: TimeInterval
    var cameraGroupID: String

    var effectiveStartTime: TimeInterval {
        startTime + alignmentOffset
    }
}

enum TimelineZoom: Equatable, Codable {
    case fit
    case pixelsPerSecond(Double)

    var label: String {
        switch self {
        case .fit:
            "Fit"
        case .pixelsPerSecond(let value):
            "\(Int(value)) px/s"
        }
    }

    func zoomedIn() -> TimelineZoom {
        switch self {
        case .fit:
            .pixelsPerSecond(0.5)
        case .pixelsPerSecond(let value):
            .pixelsPerSecond(min(value * 1.35, 200))
        }
    }

    func zoomedOut() -> TimelineZoom {
        switch self {
        case .fit:
            .fit
        case .pixelsPerSecond(let value) where value <= 0.5:
            .fit
        case .pixelsPerSecond(let value):
            .pixelsPerSecond(max(value / 1.35, 0.5))
        }
    }

    private enum CodingKeys: String, CodingKey {
        case mode
        case pixelsPerSecond
    }

    private enum Mode: String, Codable {
        case fit
        case pixelsPerSecond
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let mode = try container.decode(Mode.self, forKey: .mode)
        switch mode {
        case .fit:
            self = .fit
        case .pixelsPerSecond:
            self = .pixelsPerSecond(try container.decode(Double.self, forKey: .pixelsPerSecond))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .fit:
            try container.encode(Mode.fit, forKey: .mode)
        case .pixelsPerSecond(let value):
            try container.encode(Mode.pixelsPerSecond, forKey: .mode)
            try container.encode(value, forKey: .pixelsPerSecond)
        }
    }
}
