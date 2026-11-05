import Foundation
import Testing
@testable import RunningOverlay

@MainActor
struct PreviewControlsTests {
    @Test func playbackRateAcceptsHalfSpeedAndClampsToTheMenuRange() {
        let project = ProjectDocument()

        project.setPlaybackRate(0.5)
        #expect(project.playbackRate == 0.5)
        #expect(project.statusMessage == "Playback speed 0.5x.")

        project.setPlaybackRate(0.1)
        #expect(project.playbackRate == 0.5)
        project.setPlaybackRate(16)
        #expect(project.playbackRate == 8)
        #expect(ProjectDocument.playbackRateOptions == [0.5, 1, 2, 4, 8])
    }

    @Test func halfSpeedChosenWhilePausedIsKeptWhenPlaybackStarts() {
        let project = ProjectDocument()
        project.setPlaybackRate(0.5)

        project.togglePlayback()
        #expect(project.isPlaying)
        #expect(project.playbackRate == 0.5)

        // L returns to normal speed; J at normal speed pauses as before.
        project.increaseForwardPlaybackRate()
        #expect(project.playbackRate == 1)
        project.setPlaybackRate(0.5)
        project.decreaseForwardPlaybackRate()
        #expect(!project.isPlaying)
    }

    @Test func playbackRateLabelsDropTrailingZeros() {
        #expect(ProjectDocument.playbackRateLabel(0.5) == "0.5x")
        #expect(ProjectDocument.playbackRateLabel(1) == "1x")
        #expect(ProjectDocument.playbackRateLabel(8) == "8x")
    }

    @Test func playbackBarHasPreviousPlayNextWithoutStop() {
        #expect(PreviewPlaybackButton.allCases == [.previousClip, .playPause, .nextClip])
        let labels = PreviewPlaybackButton.allCases.map { $0.label(isPlaying: false) }
        #expect(labels == ["Previous Clip", "Play", "Next Clip"])
        #expect(PreviewPlaybackButton.playPause.label(isPlaying: true) == "Pause")
        #expect(!labels.contains("Stop"))
    }

    @Test func playbackMenuHasOnePlayItemAndNoKeysInTitles() {
        for isPlaying in [false, true] {
            let titles = PlaybackMenuItem.allCases.map { $0.title(isPlaying: isPlaying) }
            #expect(Set(titles).count == titles.count)
            #expect(titles.filter { $0 == "Play" || $0 == "Pause" }.count == 1)
            for title in titles {
                #expect(!title.contains("("), "\(title) names a key")
            }
        }
        #expect(PlaybackMenuItem.goToStart.editorKeysHelp == "Home")
        #expect(PlaybackMenuItem.previousEditPoint.editorKeysHelp == "Up Arrow")
    }

    @Test func overlayPointerShowsHandsForMovableAndArrowForLocked() {
        #expect(PreviewOverlayPointer.resolve(isLocked: false, isDragging: false) == .openHand)
        #expect(PreviewOverlayPointer.resolve(isLocked: false, isDragging: true) == .closedHand)
        #expect(PreviewOverlayPointer.resolve(isLocked: true, isDragging: false) == .arrow)
        #expect(PreviewOverlayPointer.resolve(isLocked: true, isDragging: false).helpText == "Locked")
        #expect(PreviewOverlayPointer.openHand.helpText.isEmpty)
    }
}
