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

    @Test func mediaTagsAndDeletionAreUndoable() throws {
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

        project.setMediaTag(.red, for: [media.id])
        #expect(project.mediaItems[0].tag == .red)

        project.deleteMediaItems([media.id])
        #expect(project.mediaItems.isEmpty)
        #expect(project.timeline.tracks.isEmpty)

        project.undo()
        #expect(project.mediaItems[0].tag == .red)
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
