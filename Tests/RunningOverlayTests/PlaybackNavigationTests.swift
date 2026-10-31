import Foundation
import Testing
@testable import RunningOverlay

@MainActor
struct PlaybackNavigationTests {
    private func makeProject() -> ProjectDocument {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 100,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        project.timeline.tracks = [
            TimelineTrack(name: "Camera A", clips: [
                TimelineClip(title: "a1", startTime: 10, duration: 20, alignmentOffset: 0, cameraGroupID: "A"),
                TimelineClip(title: "a2", startTime: 40, duration: 10, alignmentOffset: 2, cameraGroupID: "A")
            ]),
            TimelineTrack(name: "Camera B", clips: [
                TimelineClip(title: "b1", startTime: 25, duration: 10, alignmentOffset: 0, cameraGroupID: "B")
            ])
        ]
        return project
    }

    @Test func editPointsAreClipBoundariesAcrossCamerasAndTimelineBounds() {
        let project = makeProject()

        #expect(project.timelineEditPoints == [0, 10, 25, 30, 35, 42, 52, 100])
    }

    @Test func upAndDownJumpBetweenEditPointsAndStopAtTheEnds() {
        let project = makeProject()
        project.setPlayhead(26)

        #expect(project.handleArrowKey(.down, largeStep: false))
        #expect(project.timeline.playhead == 30)
        #expect(project.handleArrowKey(.up, largeStep: false))
        #expect(project.timeline.playhead == 25)

        project.setPlayhead(100)
        #expect(!project.jumpToEditPoint(forward: true))
        project.setPlayhead(0)
        #expect(!project.jumpToEditPoint(forward: false))
    }

    @Test func editPointJumpsKeepPlaying() {
        let project = makeProject()
        project.setPlayhead(11)
        project.togglePlayback()
        #expect(project.isPlaying)

        project.jumpToEditPoint(forward: true)

        #expect(project.timeline.playhead == 25)
        #expect(project.isPlaying)
    }

    @Test func homeAndEndGoToTheTimelineBounds() {
        let project = makeProject()
        project.setPlayhead(40)

        project.movePlayheadToEnd()
        #expect(project.timeline.playhead == 100)
        project.movePlayheadToStart()
        #expect(project.timeline.playhead == 0)
    }

    @Test func jSlowsFastPlaybackThenPauses() {
        let project = makeProject()
        project.decreaseForwardPlaybackRate()
        #expect(!project.isPlaying)

        project.increaseForwardPlaybackRate()
        project.increaseForwardPlaybackRate()
        project.increaseForwardPlaybackRate()
        #expect(project.playbackRate == 4)

        project.decreaseForwardPlaybackRate()
        #expect(project.playbackRate == 2)
        project.decreaseForwardPlaybackRate()
        #expect(project.playbackRate == 1)
        #expect(project.isPlaying)
        project.decreaseForwardPlaybackRate()
        #expect(!project.isPlaying)
    }
}
