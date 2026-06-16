import Foundation
import Testing
@testable import RunningOverlay

@MainActor
struct ProjectSettingsTests {
    @Test func layerDataSampleTimeUsesConfiguredFrameRate() {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 10,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        project.settings.layerDataFrameRate = .fps5
        project.setPlayhead(1.29)

        #expect(project.layerDataSampleTime == 1.2)
    }

    @Test func layerDataSampleTimeUsesFitAxisOffset() {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 10,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        project.settings.layerDataFrameRate = .fps5
        project.moveFitStart(to: 5)
        project.setPlayhead(6.29)

        #expect(project.layerDataSampleTime == 1.2)
    }

    @Test func layerDataSampleTimeClampsToActivityDuration() {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 2,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        project.settings.layerDataFrameRate = .fps30

        #expect(project.quantizedLayerDataTime(for: 3) == 2)
    }

    @Test func playbackTimeUpdatesPlayheadOnlyWhilePlaying() {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 5,
            distanceMeters: 0,
            records: [],
            laps: []
        )

        project.setPlayheadFromPlayback(2)
        #expect(project.timeline.playhead == 0)

        project.togglePlayback()
        project.setPlayheadFromPlayback(2)
        #expect(project.timeline.playhead == 2)
    }

    @Test func playbackTimeClampsAndStopsAtActivityEnd() {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 5,
            distanceMeters: 0,
            records: [],
            laps: []
        )

        project.togglePlayback()
        project.setPlayheadFromPlayback(8)

        #expect(project.timeline.playhead == 5)
        #expect(!project.isPlaying)
    }

    @Test func arrowFrameSteppingUsesProjectFrameRate() {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 10,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        project.settings.frameRate = .fps25
        project.setPlayhead(2)

        project.stepPlayheadByFrames(1)
        #expect(abs(project.timeline.playhead - 2.04) < 0.0001)

        project.stepPlayheadByFrames(-2)
        #expect(abs(project.timeline.playhead - 1.96) < 0.0001)
    }

    @Test func collapsedPlaybackSkipsTimelineGaps() {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 100,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        project.timeline = TimelineModel(tracks: [
            TimelineTrack(name: "Camera A", clips: [
                TimelineClip(mediaItemID: nil, title: "a.mov", startTime: 10, duration: 5, alignmentOffset: 0, cameraGroupID: "Camera A"),
                TimelineClip(mediaItemID: nil, title: "b.mov", startTime: 40, duration: 5, alignmentOffset: 0, cameraGroupID: "Camera A")
            ])
        ])
        project.toggleTimelineCollapse()
        project.setPlayhead(14.99)

        project.togglePlayback()
        project.advancePlayback(by: 1.0 / 30.0)

        #expect(project.timeline.playhead == 40)
        #expect(project.isPlaying)
    }

    @Test func defaultExportDestinationUsesFirstVideoFolder() {
        let project = ProjectDocument()
        project.mediaItems = [
            MediaItem(
                displayName: "clip-b.mov",
                fileURL: URL(fileURLWithPath: "/tmp/running-overlay/source-a/clip-b.mov"),
                duration: 10,
                inferredStartDate: nil,
                cameraGroupID: "Camera A",
                alignmentStatus: .needsManualPlacement
            ),
            MediaItem(
                displayName: "clip-a.mov",
                fileURL: URL(fileURLWithPath: "/tmp/running-overlay/source-b/clip-a.mov"),
                duration: 10,
                inferredStartDate: nil,
                cameraGroupID: "Camera B",
                alignmentStatus: .needsManualPlacement
            )
        ]

        #expect(project.defaultExportDestinationURL.path == "/tmp/running-overlay/source-a")
    }

    @Test func defaultExportDestinationFallsBackToMoviesWithoutVideoFiles() {
        let project = ProjectDocument()

        #expect(project.defaultExportDestinationURL.path.hasSuffix("/Movies"))
    }

    @Test func timelineZoomSliderUsesFineLowEndMapping() {
        let project = ProjectDocument()
        project.fitPixelsPerSecond = ProjectDocument.minimumTimelinePixelsPerSecond

        #expect(project.timelineZoomSliderValue == 0)

        project.setTimelineZoomSliderValue(3)
        if case .pixelsPerSecond(let value) = project.timeline.zoom {
            #expect(value < 0.5)
        } else {
            Issue.record("Expected pixels-per-second zoom")
        }
    }

    @Test func fontLibraryRestoreDefaultsRestoresMonospacedFavoritesAndDefault() {
        let manager = FontLibraryManager.shared
        let originalFavorites = manager.favoriteFamilies
        let originalDefault = manager.defaultFamily
        defer {
            manager.favoriteFamilies = originalFavorites
            manager.defaultFamily = originalDefault
        }

        manager.favoriteFamilies = ["Avenir Next", "Helvetica Neue"]
        manager.defaultFamily = "Helvetica Neue"

        manager.restoreDefaults()

        #expect(manager.favoriteFamilies == ["PT Mono", "Monaco", "Menlo", "Andale Mono"])
        #expect(manager.defaultFamily == "PT Mono")
    }
}
