import AppKit
import Foundation
import Testing
@testable import RunningOverlay

@MainActor
struct TimelineInteractionTests {
    // MARK: Fixtures

    private func makeProject(clipStarts: [String: [TimeInterval]] = ["Layer 1": [5, 40]]) -> ProjectDocument {
        let project = ProjectDocument()
        project.activity = ActivityTimeline(
            startDate: Date(timeIntervalSince1970: 0),
            duration: 100,
            distanceMeters: 0,
            records: [],
            laps: []
        )
        var timeline = TimelineModel(tracks: [])
        var mediaItems: [MediaItem] = []
        for trackName in clipStarts.keys.sorted() {
            for start in clipStarts[trackName, default: []] {
                let media = MediaItem(
                    displayName: "\(trackName) \(Int(start)).mov",
                    fileURL: nil,
                    duration: 20,
                    inferredStartDate: nil,
                    cameraGroupID: trackName,
                    alignmentStatus: .needsManualPlacement
                )
                mediaItems.append(media)
                _ = timeline.addOrMoveClip(mediaItem: media, trackName: trackName, startTime: start, activity: project.activity)
            }
        }
        project.mediaItems = mediaItems
        project.timeline = timeline
        return project
    }

    private func makeCanvas(for project: ProjectDocument) -> (NSWindow, TimelineCanvasNSView) {
        // The window is never ordered front, so tests stay off screen.
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 900, height: 300),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )
        let canvas = TimelineCanvasNSView(frame: CGRect(x: 0, y: 0, width: 900, height: 300))
        window.contentView = canvas
        canvas.update(
            project: project,
            activity: project.activity,
            timeline: project.timeline,
            hasMediaItems: !project.mediaItems.isEmpty,
            selection: project.selection,
            isCollapsed: project.isTimelineCollapsed,
            viewportSize: CGSize(width: 900, height: 300)
        )
        return (window, canvas)
    }

    private func clickEvent(on canvas: TimelineCanvasNSView, at point: CGPoint, modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: canvas.convert(point, to: nil),
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: canvas.window?.windowNumber ?? 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )!
    }

    private func deleteKeyEvent(window: NSWindow) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            characters: "\u{7F}",
            charactersIgnoringModifiers: "\u{7F}",
            isARepeat: false,
            keyCode: TimelineDeleteKey.deleteKeyCode
        )!
    }

    /// Middle of a clip in the first layer (ruler 28 pt + Activity 44 pt).
    private func clipCenter(_ clip: TimelineClip, in canvas: TimelineCanvasNSView, trackIndex: Int = 0) -> CGPoint {
        let startX = canvas.x(forProjectTime: clip.effectiveStartTime)
        let endX = canvas.x(forProjectTime: clip.effectiveStartTime + clip.duration)
        return CGPoint(x: (startX + endX) / 2, y: 28 + 44 + CGFloat(trackIndex) * 44 + 22)
    }

    // MARK: C hover scrub

    @Test func hoverScrubLeavesCToFocusedTextInput() {
        #expect(TimelineHoverScrubKey.shouldConsume(keyCode: 8, isMouseOverTimeline: true, isTextInputFocused: false))
        #expect(!TimelineHoverScrubKey.shouldConsume(keyCode: 8, isMouseOverTimeline: true, isTextInputFocused: true))
        #expect(!TimelineHoverScrubKey.shouldConsume(keyCode: 8, isMouseOverTimeline: false, isTextInputFocused: false))
        #expect(!TimelineHoverScrubKey.shouldConsume(keyCode: 9, isMouseOverTimeline: true, isTextInputFocused: false))
    }

    // MARK: Delete

    @Test func deleteKeysMatchWithoutCommandModifiers() {
        #expect(TimelineDeleteKey.matches(keyCode: 51, modifiers: []))
        #expect(TimelineDeleteKey.matches(keyCode: 117, modifiers: .function))
        #expect(!TimelineDeleteKey.matches(keyCode: 51, modifiers: .command))
        #expect(!TimelineDeleteKey.matches(keyCode: 8, modifiers: []))
    }

    /// Regression: selecting an overlay, then clicking a clip and pressing
    /// Delete beeped and deleted nothing. Delete now reaches the canvas
    /// through the key-equivalent pass, before the main menu, and removes the
    /// clip that was selected last as one undo step.
    @Test func deleteAfterSwitchingFromOverlayToClipDeletesTheClip() throws {
        let project = makeProject()
        project.addOverlayElement(.decorSolidColor)
        let overlayID = try #require(project.selectedOverlayID)
        let (window, canvas) = makeCanvas(for: project)
        let clip = project.timeline.tracks[0].clips[0]
        let undoBaseline = project.canUndo

        canvas.mouseDown(with: clickEvent(on: canvas, at: clipCenter(clip, in: canvas)))
        canvas.mouseUp(with: clickEvent(on: canvas, at: clipCenter(clip, in: canvas)))
        #expect(project.selection == .timelineClip(clip.id))
        #expect(window.firstResponder === canvas)

        #expect(window.performKeyEquivalent(with: deleteKeyEvent(window: window)))
        #expect(project.timeline.clip(with: clip.id) == nil)
        #expect(project.timelineClipCount == 1)
        #expect(project.overlayLayout.elements.map(\.id) == [overlayID])

        project.undo()
        #expect(project.timeline.clip(with: clip.id) != nil)
        #expect(project.canUndo == undoBaseline)
    }

    @Test func deleteKeyEquivalentIsIgnoredWhenTheCanvasIsNotFocused() {
        let project = makeProject()
        let (window, canvas) = makeCanvas(for: project)
        project.selectClip(project.timeline.tracks[0].clips[0].id)
        window.makeFirstResponder(nil)
        #expect(!canvas.performKeyEquivalent(with: deleteKeyEvent(window: window)))
        #expect(project.timelineClipCount == 2)
    }

    // MARK: Selection

    @Test func clickSelectionModifiers() {
        let project = makeProject(clipStarts: ["Layer 1": [0, 25, 50, 75], "Layer 2": [10]])
        let layer1 = project.timeline.tracks[0].clips.map(\.id)
        let other = project.timeline.tracks[1].clips[0].id
        let tracks = project.timeline.tracks

        #expect(TimelineClipSelection.mode(for: .command) == .toggle)
        #expect(TimelineClipSelection.mode(for: .shift) == .range)
        #expect(TimelineClipSelection.mode(for: []) == .replace)

        let plain = TimelineClipSelection.click(layer1[1], mode: .replace, current: [layer1[0]], anchor: layer1[0], tracks: tracks)
        #expect(plain == .init(selection: [layer1[1]], anchor: layer1[1]))

        let added = TimelineClipSelection.click(layer1[3], mode: .toggle, current: [layer1[1]], anchor: layer1[1], tracks: tracks)
        #expect(added == .init(selection: [layer1[1], layer1[3]], anchor: layer1[3]))
        let removed = TimelineClipSelection.click(layer1[3], mode: .toggle, current: added.selection, anchor: layer1[3], tracks: tracks)
        #expect(removed.selection == [layer1[1]])

        let range = TimelineClipSelection.click(layer1[3], mode: .range, current: [layer1[1]], anchor: layer1[1], tracks: tracks)
        #expect(range == .init(selection: Set(layer1[1...3]), anchor: layer1[1]))

        // A Shift-click on another layer starts over from that clip.
        let otherLayer = TimelineClipSelection.click(other, mode: .range, current: [layer1[1]], anchor: layer1[1], tracks: tracks)
        #expect(otherLayer == .init(selection: [other], anchor: other))
    }

    @Test func commandClickOnCanvasTogglesThroughProjectSelection() {
        let project = makeProject()
        let (_, canvas) = makeCanvas(for: project)
        let clips = project.timeline.tracks[0].clips

        canvas.mouseDown(with: clickEvent(on: canvas, at: clipCenter(clips[0], in: canvas)))
        canvas.mouseUp(with: clickEvent(on: canvas, at: clipCenter(clips[0], in: canvas)))
        canvas.mouseDown(with: clickEvent(on: canvas, at: clipCenter(clips[1], in: canvas), modifiers: .command))
        #expect(project.selection == .timelineClips([clips[0].id, clips[1].id]))
    }

    @Test func selectAllSelectsEveryClip() {
        let project = makeProject(clipStarts: ["Layer 1": [0, 50], "Layer 2": [10]])
        let (_, canvas) = makeCanvas(for: project)
        canvas.selectAll(nil)
        #expect(project.selection == .timelineClips(Set(project.timeline.tracks.flatMap(\.clips).map(\.id))))
    }

    // MARK: Context menu commands

    @Test func resettingSeveralClipOffsetsIsOneUndoStep() {
        let project = makeProject()
        let clips = project.timeline.tracks[0].clips
        for clip in clips {
            project.setSelectedClipOffset(clip.id, offset: 1.5)
            project.finishContinuousEdit()
        }

        project.resetClipOffsets(Set(clips.map(\.id)))
        #expect(project.timeline.tracks[0].clips.allSatisfy { $0.alignmentOffset == 0 })

        project.undo()
        #expect(project.timeline.tracks[0].clips.allSatisfy { $0.alignmentOffset == 1.5 })
    }

    // MARK: Header

    @Test func collapseButtonAndMenuItemShareOneState() {
        let project = ProjectDocument()
        project.setTimelineCollapsed(true)
        #expect(project.isTimelineCollapsed)
        project.toggleTimelineCollapse()
        #expect(!project.isTimelineCollapsed)
        project.setTimelineCollapsed(false)
        #expect(!project.isTimelineCollapsed)
    }

    @Test func zoomReadoutShowsVisibleDuration() {
        #expect(TimelineHeaderText.zoomReadout(visibleDuration: 0.2) == "1 s")
        #expect(TimelineHeaderText.zoomReadout(visibleDuration: 30) == "30 s")
        #expect(TimelineHeaderText.zoomReadout(visibleDuration: 125) == "2 min")
        #expect(TimelineHeaderText.zoomReadout(visibleDuration: 3600) == "1 h")
        #expect(TimelineHeaderText.zoomReadout(visibleDuration: 5400) == "1.5 h")
    }

    @Test func visibleDurationShrinksAsZoomGrows() {
        let project = makeProject()
        project.fitPixelsPerSecond = 2
        let fitDuration = project.timelineVisibleDuration
        project.zoomTimeline(by: 4)
        #expect(abs(project.timelineVisibleDuration - fitDuration / 4) < 1e-9)

        project.zoomTimelineToFit()
        #expect(project.timeline.zoom == .fit)
        project.toggleTimelineFitZoom()
        #expect(project.timeline.zoom == .pixelsPerSecond(8))
    }

    @Test func previewLayerCountAppearsOnlyWhenLayersAreExcluded() {
        #expect(TimelineHeaderText.previewLayerCount(trackNames: ["Layer 1", "Layer 2"], disabled: []) == nil)
        #expect(TimelineHeaderText.previewLayerCount(trackNames: ["Layer 1", "Layer 2"], disabled: ["Layer 2"]) == "1 of 2")
        #expect(TimelineHeaderText.previewLayerCount(trackNames: [], disabled: ["Gone"]) == nil)
    }

    // MARK: Pointer

    @Test func pointerReflectsWhatTheClickWouldDo() {
        #expect(TimelinePointer.pointer(for: .clip, isCollapsed: false, isDraggingClip: false) == .openHand)
        #expect(TimelinePointer.pointer(for: .clip, isCollapsed: true, isDraggingClip: false) == .notAllowed)
        #expect(TimelinePointer.pointer(for: .clip, isCollapsed: false, isDraggingClip: true) == .closedHand)
        #expect(TimelinePointer.pointer(for: .ruler, isCollapsed: false, isDraggingClip: false) == .positioning)
        #expect(TimelinePointer.pointer(for: .playhead, isCollapsed: true, isDraggingClip: false) == .positioning)
        #expect(TimelinePointer.pointer(for: .none, isCollapsed: false, isDraggingClip: false) == .arrow)
    }

    // MARK: Accessibility

    @Test func accessibilityExposesLayersClipsAndPlayhead() throws {
        let project = makeProject(clipStarts: ["Layer 1": [0, 50], "Layer 2": [10]])
        let (_, canvas) = makeCanvas(for: project)

        #expect(canvas.accessibilityRole() == .group)
        #expect(canvas.accessibilityLabel() == "Timeline")

        let children = try #require(canvas.accessibilityChildren() as? [NSAccessibilityElement])
        let layers = children.filter { $0.accessibilityRole() == .group }
        #expect(layers.map { $0.accessibilityLabel() } == ["Layer 1, 2 clips", "Layer 2, 1 clip"])

        let clipElements = layers.flatMap { ($0.accessibilityChildren() as? [NSAccessibilityElement]) ?? [] }
        #expect(clipElements.count == project.timelineClipCount)
        #expect(clipElements.first?.accessibilityLabel()?.hasPrefix("Layer 1 0.mov, starts at 00:00") == true)

        let playhead = try #require(children.first { $0.accessibilityRole() == .slider })
        let start = project.timeline.playhead
        #expect(playhead.accessibilityPerformIncrement())
        #expect(project.timeline.playhead > start)

        #expect(clipElements[1].accessibilityPerformPress())
        #expect(project.selection == .timelineClip(project.timeline.tracks[0].clips[1].id))
    }
}

private extension ProjectDocument {
    var timelineClipCount: Int {
        timeline.tracks.reduce(0) { $0 + $1.clips.count }
    }
}
