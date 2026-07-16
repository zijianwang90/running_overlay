import Foundation
import Testing
@testable import RunningOverlay

@MainActor
struct ProjectDocumentUndoTests {
    @Test func projectAspectRatioAndResolutionChangesAreUndoable() {
        let project = ProjectDocument()

        project.setProjectAspectRatio(.portrait3x4)
        project.setProjectResolution(.portrait3x4_1440)

        #expect(project.settings.aspectRatio == .portrait3x4)
        #expect(project.settings.resolution == .portrait3x4_1440)

        project.undo()
        #expect(project.settings.aspectRatio == .portrait3x4)
        #expect(project.settings.resolution == .portrait3x4_1080)

        project.undo()
        #expect(project.settings.aspectRatio == .landscape16x9)
        #expect(project.settings.resolution == .hd1080)

        project.redo()
        #expect(project.settings.aspectRatio == .portrait3x4)
        #expect(project.settings.resolution == .portrait3x4_1080)
    }

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

    @Test func addedNumericOverlayUsesMetricDefaultIcon() {
        let project = ProjectDocument()

        project.addOverlayElement(.elevation)

        let element = project.overlayLayout.elements[0]
        #expect(element.style.iconEnabled)
        #expect(element.style.iconSystemName == "mountain.2")
    }

    @Test func addedCustomNumericOverlayUsesFieldDefaults() {
        let project = ProjectDocument()

        project.addOverlayElement(.customNumeric)

        let element = project.overlayLayout.elements[0]
        #expect(element.type == .customNumeric)
        #expect(element.type.isNumericOverlay)
        #expect(element.style.iconSystemName == "number")
        #expect(element.style.customNumericField == .latitude)
        #expect(element.style.customNumericFormat == .coordinate)
        #expect(element.style.customNumericPrecision == 5)
        #expect(element.style.customUnit == "")
        #expect(element.style.customLabel == "Latitude")
    }

    @Test func changingCustomNumericFieldAndFormatIsUndoable() {
        let project = ProjectDocument()
        project.addOverlayElement(.customNumeric)
        let elementID = project.overlayLayout.elements[0].id

        project.setOverlayCustomNumericField(elementID, field: .longitude)
        project.setOverlayCustomNumericFormat(elementID, format: .number)
        project.setOverlayCustomNumericPrecision(elementID, precision: 4)
        project.finishContinuousEdit()
        project.setOverlayCustomUnit(elementID, unit: "deg")
        project.finishContinuousEdit()

        #expect(project.overlayLayout.elements[0].style.customNumericField == .longitude)
        #expect(project.overlayLayout.elements[0].style.customNumericPrecision == 4)
        #expect(project.overlayLayout.elements[0].style.customUnit == "deg")

        project.undo()
        #expect(project.overlayLayout.elements[0].style.customUnit == "")
        project.undo()
        #expect(project.overlayLayout.elements[0].style.customNumericPrecision == 5)
        project.undo()
        #expect(project.overlayLayout.elements[0].style.customNumericFormat == .coordinate)
        project.undo()
        #expect(project.overlayLayout.elements[0].style.customNumericField == .latitude)
        #expect(project.overlayLayout.elements[0].style.customUnit == "")
    }

    @Test func customNumericBuiltInMenuExcludesFixedNumericOverlayFields() {
        #expect(CustomNumericField.builtInCases == [.latitude, .longitude])
        #expect(CustomNumericField.recordFieldIDsCoveredByFixedNumericOverlays.contains("record.field_3"))
        #expect(CustomNumericField.recordFieldIDsCoveredByFixedNumericOverlays.contains("record.field_5"))
        #expect(!CustomNumericField.recordFieldIDsCoveredByFixedNumericOverlays.contains("record.field_0"))
        #expect(!CustomNumericField.recordFieldIDsCoveredByFixedNumericOverlays.contains("record.field_1"))
    }

    @Test func customNumericDynamicFieldUsesFallbackDefaults() {
        let project = ProjectDocument()
        project.addOverlayElement(.customNumeric)
        let elementID = project.overlayLayout.elements[0].id

        project.setOverlayCustomNumericField(elementID, field: .record("record.field_87"))

        let style = project.overlayLayout.elements[0].style
        #expect(style.customNumericField == .record("record.field_87"))
        #expect(style.customNumericFormat == .number)
        #expect(style.customNumericPrecision == 2)
        #expect(style.customUnit == "")
        #expect(style.customLabel == "record.field_87")
    }

    @Test func customNumericStyleCodableRoundTripsAndDefaults() throws {
        var style = OverlayStyle.default
        style.customNumericField = .record("record.field_87")
        style.customNumericFormat = .coordinate
        style.customNumericPrecision = 6
        style.customUnit = "deg"

        let encoded = try JSONEncoder().encode(style)
        let decoded = try JSONDecoder().decode(OverlayStyle.self, from: encoded)

        #expect(decoded.customNumericField == .record("record.field_87"))
        #expect(decoded.customNumericFormat == .coordinate)
        #expect(decoded.customNumericPrecision == 6)
        #expect(decoded.customUnit == "deg")

        let oldStyle = try JSONDecoder().decode(OverlayStyle.self, from: Data("{}".utf8))
        #expect(oldStyle.customNumericField == .latitude)
        #expect(oldStyle.customNumericFormat == .coordinate)
        #expect(oldStyle.customNumericPrecision == 5)
        #expect(oldStyle.customUnit == "")
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

    @Test func deletingMarqueeSelectedClipsIsOneUndoableEdit() {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 100),
            duration: 100,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        let timestampMedia = MediaItem(
            displayName: "timestamp.mov",
            fileURL: nil,
            duration: 10,
            inferredStartDate: Date(timeIntervalSince1970: 120),
            cameraGroupID: "Layer 1",
            alignmentStatus: .aligned(source: "timestamp")
        )
        let manualMedia = MediaItem(
            displayName: "manual.mov",
            fileURL: nil,
            duration: 10,
            inferredStartDate: nil,
            cameraGroupID: "Layer 2",
            alignmentStatus: .aligned(source: "manual")
        )
        let retainedMedia = MediaItem(
            displayName: "retained.mov",
            fileURL: nil,
            duration: 10,
            inferredStartDate: Date(timeIntervalSince1970: 140),
            cameraGroupID: "Layer 1",
            alignmentStatus: .aligned(source: "timestamp")
        )
        let timestampClip = TimelineClip(
            mediaItemID: timestampMedia.id,
            title: timestampMedia.displayName,
            startTime: 20,
            duration: 10,
            alignmentOffset: 0,
            cameraGroupID: "Layer 1"
        )
        let manualClip = TimelineClip(
            mediaItemID: manualMedia.id,
            title: manualMedia.displayName,
            startTime: 20,
            duration: 10,
            alignmentOffset: 0,
            cameraGroupID: "Layer 2"
        )
        let retainedClip = TimelineClip(
            mediaItemID: retainedMedia.id,
            title: retainedMedia.displayName,
            startTime: 40,
            duration: 10,
            alignmentOffset: 0,
            cameraGroupID: "Layer 1"
        )
        let selectedClipIDs: Set<TimelineClip.ID> = [timestampClip.id, manualClip.id]
        project.mediaItems = [timestampMedia, manualMedia, retainedMedia]
        project.timeline = TimelineModel(tracks: [
            TimelineTrack(name: "Layer 1", clips: [timestampClip, retainedClip]),
            TimelineTrack(name: "Layer 2", clips: [manualClip])
        ])
        project.selectClips(selectedClipIDs)

        project.deleteSelectedItem()

        #expect(project.timeline.clip(with: timestampClip.id) == nil)
        #expect(project.timeline.clip(with: manualClip.id) == nil)
        #expect(project.timeline.clip(with: retainedClip.id) != nil)
        #expect(project.mediaItems[0].alignmentStatus == .readyToMatch(source: "timestamp"))
        #expect(project.mediaItems[1].alignmentStatus == .needsManualPlacement)
        #expect(project.mediaItems[2].alignmentStatus == .aligned(source: "timestamp"))
        #expect(project.selection == .none)

        project.undo()

        #expect(project.timeline.clip(with: timestampClip.id) != nil)
        #expect(project.timeline.clip(with: manualClip.id) != nil)
        #expect(project.timeline.clip(with: retainedClip.id) != nil)
        #expect(project.mediaItems[0].alignmentStatus == .aligned(source: "timestamp"))
        #expect(project.mediaItems[1].alignmentStatus == .aligned(source: "manual"))
        #expect(project.selection == .timelineClips(selectedClipIDs))
    }

    @Test func deletingTimestampMatchedClipReturnsMediaStatusToReadyToMatch() throws {
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
            inferredStartDate: Date(timeIntervalSince1970: 120),
            cameraGroupID: "Layer 1",
            alignmentStatus: .aligned(source: "timestamp")
        )
        let clip = TimelineClip(
            mediaItemID: media.id,
            title: media.displayName,
            startTime: 20,
            duration: media.duration,
            alignmentOffset: 0,
            cameraGroupID: "Layer 1"
        )
        project.mediaItems = [media]
        project.timeline = TimelineModel(tracks: [TimelineTrack(name: "Layer 1", clips: [clip])])
        project.selection = .timelineClip(clip.id)

        project.deleteSelectedItem()

        #expect(project.timeline.tracks.isEmpty)
        #expect(project.mediaItems[0].alignmentStatus == .readyToMatch(source: "timestamp"))

        project.undo()
        #expect(project.timeline.tracks.first?.clips.first?.id == clip.id)
        #expect(project.mediaItems[0].alignmentStatus == .aligned(source: "timestamp"))
    }

    @Test func deletingManuallyPlacedClipReturnsMediaStatusToNeedsManualPlacement() throws {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 100),
            duration: 100,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        let media = MediaItem(
            displayName: "manual.mov",
            fileURL: nil,
            duration: 10,
            inferredStartDate: nil,
            cameraGroupID: "Layer 1",
            alignmentStatus: .aligned(source: "manual")
        )
        let clip = TimelineClip(
            mediaItemID: media.id,
            title: media.displayName,
            startTime: 20,
            duration: media.duration,
            alignmentOffset: 0,
            cameraGroupID: "Layer 1"
        )
        project.mediaItems = [media]
        project.timeline = TimelineModel(tracks: [TimelineTrack(name: "Layer 1", clips: [clip])])
        project.selection = .timelineClip(clip.id)

        project.deleteSelectedItem()

        #expect(project.timeline.tracks.isEmpty)
        #expect(project.mediaItems[0].alignmentStatus == .needsManualPlacement)
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

    @Test func mediaAlignmentStatusHelpTextExplainsStatusDots() {
        #expect(AlignmentStatus.readyToMatch(source: "timestamp").helpText == "Ready to match activity timestamps")
        #expect(AlignmentStatus.aligned(source: "timestamp").helpText == "Already on the timeline")
        #expect(AlignmentStatus.needsManualPlacement.helpText == "Needs manual placement")
    }

    @Test func matchingMediaToExistingLayerUsesSelectedLayerAndIsUndoable() throws {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 100),
            duration: 100,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        let existingMedia = MediaItem(
            displayName: "existing.mov",
            fileURL: nil,
            duration: 5,
            cameraGroupID: "Layer 2",
            alignmentStatus: .aligned(source: "manual")
        )
        let media = MediaItem(
            displayName: "clip.mov",
            fileURL: nil,
            duration: 10,
            inferredStartDate: Date(timeIntervalSince1970: 120),
            cameraGroupID: "Camera A",
            alignmentStatus: .readyToMatch(source: "timestamp")
        )
        let existingClip = TimelineClip(
            mediaItemID: existingMedia.id,
            title: existingMedia.displayName,
            startTime: 60,
            duration: existingMedia.duration,
            alignmentOffset: 0,
            cameraGroupID: "Layer 2"
        )
        project.mediaItems = [existingMedia, media]
        project.timeline = TimelineModel(tracks: [
            TimelineTrack(name: "Layer 1", clips: []),
            TimelineTrack(name: "Layer 2", clips: [existingClip])
        ])

        project.matchMediaItems([media.id], toLayer: "Layer 2")

        let targetTrack = try #require(project.timeline.tracks.first { $0.name == "Layer 2" })
        let matchedClip = try #require(targetTrack.clips.first { $0.mediaItemID == media.id })
        #expect(matchedClip.startTime == 20)
        #expect(project.mediaItems[1].cameraGroupID == "Layer 2")
        #expect(project.statusMessage.contains("Matched 1 media item(s) to Layer 2"))

        project.undo()
        let restoredTrack = try #require(project.timeline.tracks.first { $0.name == "Layer 2" })
        #expect(!restoredTrack.clips.contains { $0.mediaItemID == media.id })
        #expect(project.mediaItems[1].cameraGroupID == "Camera A")
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

    @Test func replacingFitAutoMatchesExistingTimestampedVideos() {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 10_000),
            duration: 100,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        let correctStart = Date(timeIntervalSince1970: 1_000)
        let media = MediaItem(
            displayName: "clip.mov",
            fileURL: nil,
            duration: 12,
            inferredStartDate: correctStart.addingTimeInterval(30),
            cameraGroupID: "Camera A",
            alignmentStatus: .needsManualPlacement
        )
        project.mediaItems = [media]

        project.finishFitImport(
            activity: ActivityTimeline(
                startDate: correctStart,
                duration: 120,
                distanceMeters: 0,
                records: [],
                laps: []
            ),
            sourceName: "correct.fit"
        )

        #expect(project.mediaItems.first?.alignmentStatus == .aligned(source: "timestamp"))
        #expect(project.timeline.tracks.first?.name == "Camera A")
        #expect(project.timeline.tracks.first?.clips.first?.effectiveStartTime == 30)
        #expect(project.statusMessage.contains("Auto-matched 1 existing video"))
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
