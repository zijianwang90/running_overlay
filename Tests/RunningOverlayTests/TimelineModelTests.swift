import Foundation
import Testing
@testable import RunningOverlay

struct TimelineModelTests {
    @Test func addOrMoveClipPlacesMediaOnTrack() {
        let activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 120,
            distanceMeters: 0,
            records: []
        )
        let media = MediaItem(
            displayName: "clip.mov",
            fileURL: nil,
            duration: 20,
            inferredStartDate: nil,
            cameraGroupID: "Camera A",
            alignmentStatus: .needsManualPlacement
        )
        var timeline = TimelineModel(tracks: [])

        let clipID = timeline.addOrMoveClip(
            mediaItem: media,
            trackName: "Camera A",
            startTime: 30,
            activity: activity
        )

        #expect(clipID != nil)
        #expect(timeline.tracks.count == 1)
        #expect(timeline.tracks[0].clips.count == 1)
        #expect(timeline.tracks[0].clips[0].startTime == 30)
    }

    @Test func applyOffsetUpdatesMatchingCameraGroup() {
        var timeline = TimelineModel(tracks: [
            TimelineTrack(name: "Camera A", clips: [
                TimelineClip(mediaItemID: nil, title: "a.mov", startTime: 10, duration: 5, alignmentOffset: 0, cameraGroupID: "Camera A"),
                TimelineClip(mediaItemID: nil, title: "b.mov", startTime: 30, duration: 5, alignmentOffset: 0, cameraGroupID: "Camera A")
            ]),
            TimelineTrack(name: "Camera B", clips: [
                TimelineClip(mediaItemID: nil, title: "c.mov", startTime: 40, duration: 5, alignmentOffset: 0, cameraGroupID: "Camera B")
            ])
        ])

        timeline.applyOffset(2.5, toCameraGroup: "Camera A", activityDuration: 100)

        #expect(timeline.tracks[0].clips.allSatisfy { $0.alignmentOffset == 2.5 })
        #expect(timeline.tracks[1].clips[0].alignmentOffset == 0)
    }

    @Test func moveClipUpdatesEffectiveStartTime() {
        let clip = TimelineClip(
            mediaItemID: nil,
            title: "a.mov",
            startTime: 10,
            duration: 5,
            alignmentOffset: 2,
            cameraGroupID: "Camera A"
        )
        let clipID = clip.id
        var timeline = TimelineModel(tracks: [
            TimelineTrack(name: "Camera A", clips: [clip])
        ])

        timeline.moveClip(clipID, toEffectiveStartTime: 40, activityDuration: 100)

        let moved = timeline.clip(with: clipID)
        #expect(moved?.effectiveStartTime == 40)
        #expect(moved?.alignmentOffset == 2)
    }

    @Test func visibleClipReturnsClipAtPlayhead() {
        let earlyClip = TimelineClip(
            mediaItemID: nil,
            title: "early.mov",
            startTime: 10,
            duration: 10,
            alignmentOffset: 0,
            cameraGroupID: "Camera A"
        )
        let lateClip = TimelineClip(
            mediaItemID: nil,
            title: "late.mov",
            startTime: 40,
            duration: 10,
            alignmentOffset: 0,
            cameraGroupID: "Camera A"
        )
        let timeline = TimelineModel(tracks: [
            TimelineTrack(name: "Camera A", clips: [earlyClip, lateClip])
        ])

        #expect(timeline.visibleClip(at: 15)?.id == earlyClip.id)
        #expect(timeline.visibleClip(at: 45)?.id == lateClip.id)
        #expect(timeline.visibleClip(at: 30) == nil)
    }

    @Test func visibleClipUsesPreferredTrackAndRightOpenEnd() {
        let cameraA = TimelineClip(mediaItemID: nil, title: "a.mov", startTime: 0, duration: 10, alignmentOffset: 0, cameraGroupID: "Camera A")
        let cameraB = TimelineClip(mediaItemID: nil, title: "b.mov", startTime: 0, duration: 10, alignmentOffset: 0, cameraGroupID: "Camera B")
        let timeline = TimelineModel(tracks: [
            TimelineTrack(name: "Camera A", clips: [cameraA]),
            TimelineTrack(name: "Camera B", clips: [cameraB])
        ])

        #expect(timeline.visibleClip(at: 5, preferredTrackName: "Camera B")?.id == cameraB.id)
        #expect(timeline.visibleClip(at: 5, disabledTrackNames: ["Camera A"])?.id == cameraB.id)
        #expect(timeline.visibleClip(at: 10) == nil)
    }

    @Test func collapsedSingleLayerPlacesClipsBackToBack() {
        let firstClip = TimelineClip(mediaItemID: nil, title: "a.mov", startTime: 10, duration: 5, alignmentOffset: 0, cameraGroupID: "Camera A")
        let secondClip = TimelineClip(mediaItemID: nil, title: "b.mov", startTime: 40, duration: 8, alignmentOffset: 0, cameraGroupID: "Camera A")
        let timeline = TimelineModel(tracks: [
            TimelineTrack(name: "Camera A", clips: [firstClip, secondClip])
        ])

        let segments = timeline.collapsedDisplaySegments()

        #expect(segments == [
            TimelineDisplaySegment(projectStartTime: 10, projectEndTime: 15, displayStartTime: 0),
            TimelineDisplaySegment(projectStartTime: 40, projectEndTime: 48, displayStartTime: 5)
        ])
        #expect(timeline.displayTime(forProjectTime: 40, activityDuration: 100, collapsed: true) == 5)
        #expect(timeline.projectTime(forDisplayTime: 7, activityDuration: 100, collapsed: true) == 42)
    }

    @Test func collapsedMultipleLayersUsesUnionOfVideoSpans() {
        let cameraA = TimelineClip(mediaItemID: nil, title: "a.mov", startTime: 10, duration: 10, alignmentOffset: 0, cameraGroupID: "Camera A")
        let cameraB = TimelineClip(mediaItemID: nil, title: "b.mov", startTime: 15, duration: 10, alignmentOffset: 0, cameraGroupID: "Camera B")
        let cameraC = TimelineClip(mediaItemID: nil, title: "c.mov", startTime: 50, duration: 5, alignmentOffset: 0, cameraGroupID: "Camera C")
        let timeline = TimelineModel(tracks: [
            TimelineTrack(name: "Camera A", clips: [cameraA]),
            TimelineTrack(name: "Camera B", clips: [cameraB]),
            TimelineTrack(name: "Camera C", clips: [cameraC])
        ])

        let segments = timeline.collapsedDisplaySegments()

        #expect(segments == [
            TimelineDisplaySegment(projectStartTime: 10, projectEndTime: 25, displayStartTime: 0),
            TimelineDisplaySegment(projectStartTime: 50, projectEndTime: 55, displayStartTime: 15)
        ])
        #expect(timeline.displayTime(forProjectTime: 50, activityDuration: 100, collapsed: true) == 15)
        #expect(timeline.visiblePlaybackTime(atOrAfter: 26) == 50)
    }

    @Test func renameTrackMovesClipAndSetDurationAllowsPostFinishMedia() {
        let clip = TimelineClip(mediaItemID: nil, title: "a.mov", startTime: 80, duration: 5, alignmentOffset: 0, cameraGroupID: "Camera A")
        var timeline = TimelineModel(tracks: [TimelineTrack(name: "Camera A", clips: [clip])])

        timeline.renameTrack(containing: clip.id, to: "Camera B")
        timeline.setClipDuration(clip.id, duration: 50, activityDuration: 100)

        #expect(timeline.tracks.count == 1)
        #expect(timeline.tracks[0].name == "Camera B")
        #expect(timeline.clip(with: clip.id)?.cameraGroupID == "Camera B")
        #expect(timeline.clip(with: clip.id)?.duration == 50)
    }

    @Test func clipsCanStartBeforeFitAndExtendProjectBounds() {
        let activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 100),
            duration: 60,
            distanceMeters: 0,
            records: []
        )
        let media = MediaItem(
            displayName: "prestart.mov",
            fileURL: nil,
            duration: 20,
            inferredStartDate: Date(timeIntervalSince1970: 90),
            cameraGroupID: "Camera A",
            alignmentStatus: .aligned(source: "timestamp")
        )
        var timeline = TimelineModel(tracks: [])

        timeline.replaceClips(with: [media], activity: activity)

        let clip = timeline.tracks[0].clips[0]
        #expect(clip.startTime == -10)
        #expect(clip.duration == 20)
        #expect(timeline.projectBounds(activityDuration: activity.duration).lowerBound == -10)
        #expect(timeline.projectBounds(activityDuration: activity.duration).upperBound == 60)
    }

    @Test func fitAxisCanMoveIndependentlyOfClipProjectTime() {
        let clip = TimelineClip(mediaItemID: nil, title: "a.mov", startTime: -5, duration: 12, alignmentOffset: 0, cameraGroupID: "Camera A")
        var timeline = TimelineModel(tracks: [TimelineTrack(name: "Camera A", clips: [clip])])

        timeline.moveFitStart(to: 3)

        #expect(timeline.fitStartTime == 3)
        #expect(timeline.clip(with: clip.id)?.effectiveStartTime == -5)
        #expect(timeline.activityElapsed(atProjectTime: -5) == -8)
    }

    @Test func deleteClipRemovesEmptyTrack() {
        let clip = TimelineClip(mediaItemID: nil, title: "a.mov", startTime: 0, duration: 5, alignmentOffset: 0, cameraGroupID: "Camera A")
        var timeline = TimelineModel(tracks: [TimelineTrack(name: "Camera A", clips: [clip])])

        timeline.deleteClip(clip.id)

        #expect(timeline.tracks.isEmpty)
        #expect(timeline.clip(with: clip.id) == nil)
    }
}
