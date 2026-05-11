import Foundation
import Testing
@testable import RunningOverlay

@MainActor
struct ProjectDocumentUndoTests {
    @Test func undoRedoRestoresAddedOverlay() {
        let project = ProjectDocument()

        project.addOverlayElement(.heartRate)
        #expect(project.overlayLayout.elements.count == 1)
        #expect(project.canUndo)

        project.undo()
        #expect(project.overlayLayout.elements.isEmpty)
        #expect(project.canRedo)

        project.redo()
        #expect(project.overlayLayout.elements.count == 1)
    }

    @Test func undoRestoresDeletedOverlay() {
        let project = ProjectDocument()

        project.addOverlayElement(.pace)
        let elementID = project.overlayLayout.elements[0].id
        project.deleteOverlay(elementID)
        #expect(project.overlayLayout.elements.isEmpty)

        project.undo()
        #expect(project.overlayLayout.elements.count == 1)
        #expect(project.overlayLayout.elements[0].id == elementID)
    }

    @Test func deleteSelectedClipIsUndoable() throws {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 100,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        var timeline = TimelineModel(tracks: [])
        let media = MediaItem(
            displayName: "clip.mov",
            fileURL: nil,
            duration: 10,
            inferredStartDate: nil,
            cameraGroupID: "Camera A",
            alignmentStatus: .needsManualPlacement
        )
        let clipID = timeline.addOrMoveClip(mediaItem: media, trackName: "Camera A", startTime: 5, activity: project.activity)
        project.timeline = timeline
        project.selection = .timelineClip(try #require(clipID))

        project.deleteSelectedItem()
        #expect(project.timeline.tracks.isEmpty)
        #expect(project.selection == .none)

        project.undo()
        #expect(project.timeline.tracks[0].clips.count == 1)
    }

    @Test func changingPausedVisibleClipOffsetKeepsSourceFrameStill() {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 100,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        let clip = TimelineClip(
            mediaItemID: nil,
            title: "clip.mov",
            startTime: 10,
            duration: 20,
            alignmentOffset: 0,
            cameraGroupID: "Camera A"
        )
        project.timeline = TimelineModel(tracks: [
            TimelineTrack(name: "Camera A", clips: [clip])
        ])
        project.setPlayhead(15)

        project.setSelectedClipOffset(clip.id, offset: 3)

        #expect(project.timeline.clip(with: clip.id)?.effectiveStartTime == 13)
        #expect(project.timeline.playhead == 18)
    }

    @Test func changingPlayingClipOffsetDoesNotMovePlayhead() {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 100,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        let clip = TimelineClip(
            mediaItemID: nil,
            title: "clip.mov",
            startTime: 10,
            duration: 20,
            alignmentOffset: 0,
            cameraGroupID: "Camera A"
        )
        project.timeline = TimelineModel(tracks: [
            TimelineTrack(name: "Camera A", clips: [clip])
        ])
        project.setPlayhead(15)
        project.isPlaying = true

        project.setSelectedClipOffset(clip.id, offset: 3)

        #expect(project.timeline.clip(with: clip.id)?.effectiveStartTime == 13)
        #expect(project.timeline.playhead == 15)
    }

    @Test func draggingAutoMatchedClipUpdatesOffsetOnly() throws {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 100,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        let media = MediaItem(
            displayName: "auto.mov",
            fileURL: nil,
            duration: 20,
            inferredStartDate: Date(timeIntervalSince1970: 10),
            cameraGroupID: "Camera A",
            alignmentStatus: .aligned(source: "timestamp")
        )
        let clip = TimelineClip(
            mediaItemID: media.id,
            title: media.displayName,
            startTime: 10,
            duration: 20,
            alignmentOffset: 0,
            cameraGroupID: "Camera A"
        )
        project.mediaItems = [media]
        project.timeline = TimelineModel(tracks: [
            TimelineTrack(name: "Camera A", clips: [clip])
        ])

        project.moveTimelineClipFromDrag(clip.id, toEffectiveStartTime: 13)

        let moved = try #require(project.timeline.clip(with: clip.id))
        #expect(moved.startTime == 10)
        #expect(moved.alignmentOffset == 3)
        #expect(moved.effectiveStartTime == 13)
    }

    @Test func draggingManuallyPlacedClipUpdatesAlignedTimeOnly() throws {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 100,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        let media = MediaItem(
            displayName: "manual.mov",
            fileURL: nil,
            duration: 20,
            inferredStartDate: nil,
            cameraGroupID: "Camera A",
            alignmentStatus: .aligned(source: "manual")
        )
        let clip = TimelineClip(
            mediaItemID: media.id,
            title: media.displayName,
            startTime: 10,
            duration: 20,
            alignmentOffset: 2,
            cameraGroupID: "Camera A"
        )
        project.mediaItems = [media]
        project.timeline = TimelineModel(tracks: [
            TimelineTrack(name: "Camera A", clips: [clip])
        ])

        project.moveTimelineClipFromDrag(clip.id, toEffectiveStartTime: 15)

        let moved = try #require(project.timeline.clip(with: clip.id))
        #expect(moved.startTime == 13)
        #expect(moved.alignmentOffset == 2)
        #expect(moved.effectiveStartTime == 15)
    }

    @Test func matchingMediaToNewLayerUsesTimestampAndIsUndoable() throws {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 100),
            duration: 100,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        let media = MediaItem(
            displayName: "clip.mov",
            fileURL: nil,
            duration: 10,
            inferredStartDate: Date(timeIntervalSince1970: 90),
            cameraGroupID: "Camera A",
            alignmentStatus: .aligned(source: "timestamp")
        )
        project.mediaItems = [media]

        project.matchMediaItemsToNewLayer([media.id])

        let track = try #require(project.timeline.tracks.first)
        let clip = try #require(track.clips.first)
        #expect(track.name == "Layer 1")
        #expect(clip.startTime == -10)
        #expect(project.mediaItems[0].cameraGroupID == "Layer 1")

        project.undo()
        #expect(project.timeline.tracks.isEmpty)
        #expect(project.mediaItems[0].cameraGroupID == "Camera A")
    }

    @Test func mediaFoldersAndDeletionAreUndoable() throws {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 100,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        let media = MediaItem(
            displayName: "clip.mov",
            fileURL: nil,
            duration: 10,
            inferredStartDate: nil,
            cameraGroupID: "Camera A",
            alignmentStatus: .needsManualPlacement
        )
        project.mediaItems = [media]
        project.placeMediaItem(media.id, onTrack: "Camera A", at: 5)

        let folderID = project.createMediaFolder(name: "B-Roll", containing: [media.id])
        #expect(project.mediaFolders.count == 1)
        #expect(project.mediaItems[0].folderID == folderID)

        project.moveMediaItems([media.id], toFolder: nil)
        #expect(project.mediaItems[0].folderID == nil)

        project.undo()
        #expect(project.mediaItems[0].folderID == folderID)

        project.deleteMediaFolder(folderID)
        #expect(project.mediaFolders.isEmpty)
        #expect(project.mediaItems[0].folderID == nil)

        project.undo()
        #expect(project.mediaFolders.count == 1)
        #expect(project.mediaItems[0].folderID == folderID)

        project.deleteMediaItems([media.id])
        #expect(project.mediaItems.isEmpty)
        #expect(project.timeline.tracks.isEmpty)

        project.undo()
        #expect(project.mediaItems[0].folderID == folderID)
        #expect(project.timeline.tracks[0].clips.count == 1)
    }

    @Test func mediaPoolPreviewUsesSelectedMediaAndClearsOnDelete() throws {
        let project = ProjectDocument()
        let url = URL(fileURLWithPath: "/tmp/clip.mov")
        let media = MediaItem(
            displayName: "clip.mov",
            fileURL: url,
            duration: 10,
            inferredStartDate: nil,
            cameraGroupID: "Camera A",
            alignmentStatus: .needsManualPlacement
        )
        project.mediaItems = [media]

        project.previewMediaPoolItem(media.id)

        let preview = try #require(project.activePreviewMedia())
        #expect(preview.url == url)
        #expect(preview.sourceTime == 0)
        #expect(project.isPreviewingMediaPoolItem)
        #expect(project.isPlaying)

        project.setMediaPoolPreviewSourceTime(3)
        #expect(project.activePreviewMedia()?.sourceTime == 3)

        project.deleteMediaItems([media.id])
        #expect(project.activePreviewMedia() == nil)
        #expect(!project.isPreviewingMediaPoolItem)
        #expect(!project.isPlaying)
    }

    @Test func placeMediaItemRejectsOverlap() throws {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 100,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        let mediaA = MediaItem(
            displayName: "a.mov",
            fileURL: nil,
            duration: 10,
            inferredStartDate: nil,
            cameraGroupID: "Camera A",
            alignmentStatus: .needsManualPlacement
        )
        let mediaB = MediaItem(
            displayName: "b.mov",
            fileURL: nil,
            duration: 10,
            inferredStartDate: nil,
            cameraGroupID: "Camera A",
            alignmentStatus: .needsManualPlacement
        )
        project.mediaItems = [mediaA, mediaB]
        project.placeMediaItem(mediaA.id, onTrack: "Camera A", at: 5)
        #expect(project.timeline.tracks.first?.clips.count == 1)

        project.placeMediaItem(mediaB.id, onTrack: "Camera A", at: 10)
        #expect(project.timeline.tracks.first?.clips.count == 1)
        #expect(project.statusMessage.contains("overlap"))
        #expect(project.statusMessage.contains("Match to New Layer"))

        project.placeMediaItem(mediaB.id, onTrack: "Camera A", at: 20)
        #expect(project.timeline.tracks.first?.clips.count == 2)
    }

    @Test func matchMediaItemsSkipsOverlappingItems() throws {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 100,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        let baseDate = Date(timeIntervalSince1970: 10)
        let mediaA = MediaItem(
            displayName: "a.mov",
            fileURL: nil,
            duration: 10,
            inferredStartDate: baseDate,
            cameraGroupID: "Camera A",
            alignmentStatus: .readyToMatch(source: "timestamp")
        )
        let mediaB = MediaItem(
            displayName: "b.mov",
            fileURL: nil,
            duration: 10,
            inferredStartDate: baseDate.addingTimeInterval(5),
            cameraGroupID: "Camera A",
            alignmentStatus: .readyToMatch(source: "timestamp")
        )
        project.mediaItems = [mediaA, mediaB]

        project.matchMediaItemsToCurrentLayer([mediaA.id, mediaB.id])

        #expect(project.timeline.tracks.first?.clips.count == 1)
        #expect(project.statusMessage.contains("skipped 1"))
        #expect(project.statusMessage.contains("Match to New Layer"))
    }

    @Test func forwardPlaybackRateCyclesUpToEightX() {
        let project = ProjectDocument()

        project.increaseForwardPlaybackRate()
        #expect(project.isPlaying)
        #expect(project.playbackRate == 1)

        project.increaseForwardPlaybackRate()
        #expect(project.playbackRate == 2)

        project.increaseForwardPlaybackRate()
        #expect(project.playbackRate == 4)

        project.increaseForwardPlaybackRate()
        #expect(project.playbackRate == 8)

        project.increaseForwardPlaybackRate()
        #expect(project.playbackRate == 8)

        project.togglePlayback()
        #expect(!project.isPlaying)
        #expect(project.playbackRate == 1)
    }
}
