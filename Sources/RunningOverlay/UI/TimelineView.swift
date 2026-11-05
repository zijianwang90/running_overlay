import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct TimelineView: View {
    @EnvironmentObject private var project: ProjectDocument
    @State private var hoverInfo: TimelineHoverInfo?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(project.timeline.tracks) { track in
                        Toggle(track.name, isOn: Binding(
                            get: { !project.settings.disabledPreviewTrackNames.contains(track.name) },
                            set: { project.setPreviewTrackDisabled(track.name, disabled: !$0) }
                        ))
                    }
                } label: {
                    Label {
                        Text(previewLayersTitle)
                    } icon: {
                        Image(systemName: previewLayerCount == nil ? "eye" : "eye.slash")
                    }
                    .labelStyle(.titleAndIcon)
                }
                .menuStyle(.button)
                .buttonStyle(.borderless)
                .menuIndicator(.visible)
                .fixedSize()
                .font(EditorTheme.captionFont)
                .foregroundStyle(EditorTheme.textSecondary)
                .disabled(project.timeline.tracks.isEmpty)
                .help("Choose which layers the preview shows")

                Spacer()
                Toggle(isOn: Binding(
                    get: { project.isTimelineCollapsed },
                    set: { project.setTimelineCollapsed($0) }
                )) {
                    Label("Hide Gaps Without Video", systemImage: "arrow.left.and.right.square")
                        .labelStyle(.iconOnly)
                }
                .toggleStyle(.button)
                .controlSize(.regular)
                .help(project.isTimelineCollapsed ? "Show timeline gaps" : "Hide gaps without video")

                Button {
                    project.zoomTimelineOut()
                } label: {
                    Label("Zoom Out", systemImage: "minus.magnifyingglass")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(InspectorIconButtonStyle())
                .disabled(project.timeline.zoom == .fit)
                .help("Zoom Out (Command-Minus)")
                Slider(
                    value: Binding(
                        get: { project.timelineZoomSliderValue },
                        set: { project.setTimelineZoomSliderValue($0) }
                    ),
                    in: 0...100
                )
                .frame(width: 160)
                .accessibilityLabel("Zoom")
                .accessibilityValue(zoomReadout)
                Button {
                    project.zoomTimelineIn()
                } label: {
                    Label("Zoom In", systemImage: "plus.magnifyingglass")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(InspectorIconButtonStyle())
                .help("Zoom In (Command-Plus)")
                Text(zoomReadout)
                    .font(EditorTheme.numericFont)
                    .foregroundStyle(EditorTheme.textSecondary)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: 58, alignment: .trailing)
                    .help("Time visible in the timeline")
                    .accessibilityHidden(true)
                Button("Fit") {
                    project.zoomTimelineToFit()
                }
                .controlSize(.regular)
                .font(EditorTheme.captionFont)
                .disabled(project.timeline.zoom == .fit)
                .help("Zoom to Fit (Shift-Z)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .frame(height: EditorTheme.panelHeaderHeight)
            .background(EditorTheme.panelHeader)
            .overlay(alignment: .bottom) {
                Divider()
                    .overlay(EditorTheme.borderSubtle)
            }

            TimelineCanvasRepresentable(
                project: project,
                activity: project.activity,
                timeline: project.timeline,
                hasMediaItems: !project.mediaItems.isEmpty,
                selection: project.selection,
                isPlaying: project.isPlaying,
                isCollapsed: project.isTimelineCollapsed,
                hoverInfo: $hoverInfo
            )
            .overlay(alignment: .topLeading) {
                if let hoverInfo {
                    RulerHoverTooltip(info: hoverInfo)
                        .offset(y: -(4 + 22 + 5))
                }
            }
        }
        .background(EditorTheme.panelBackground)
    }

    private var zoomReadout: String {
        TimelineHeaderText.zoomReadout(visibleDuration: project.timelineVisibleDuration)
    }

    private var previewLayerCount: String? {
        TimelineHeaderText.previewLayerCount(
            trackNames: project.timeline.tracks.map(\.name),
            disabled: project.settings.disabledPreviewTrackNames
        )
    }

    private var previewLayersTitle: String {
        previewLayerCount.map { "Preview Layers  \($0)" } ?? "Preview Layers"
    }
}

private struct TimelineCanvasRepresentable: NSViewRepresentable {
    let project: ProjectDocument
    let activity: ActivityTimeline
    let timeline: TimelineModel
    let hasMediaItems: Bool
    let selection: EditorSelection
    let isPlaying: Bool
    let isCollapsed: Bool
    @Binding var hoverInfo: TimelineHoverInfo?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .editorPanelBackground

        let canvas = TimelineCanvasNSView()
        canvas.hostScrollView = scrollView
        let coordinator = context.coordinator
        canvas.onHoverChange = { info in coordinator.onHoverChange?(info) }
        scrollView.documentView = canvas
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let canvas = scrollView.documentView as? TimelineCanvasNSView else {
            return
        }
        let zoomChanged = context.coordinator.lastZoom != nil && context.coordinator.lastZoom != timeline.zoom
        let zoomAnchor = canvas.takeZoomAnchor()
        canvas.update(
            project: project,
            activity: activity,
            timeline: timeline,
            hasMediaItems: hasMediaItems,
            selection: selection,
            isCollapsed: isCollapsed,
            viewportSize: scrollView.contentView.bounds.size
        )
        if zoomChanged, let zoomAnchor {
            keepTime(zoomAnchor.time, atViewportX: zoomAnchor.viewportX, in: scrollView, canvas: canvas)
        } else if zoomChanged {
            centerPlayhead(in: scrollView, canvas: canvas)
        } else if isPlaying {
            keepPlayheadVisible(in: scrollView, canvas: canvas)
        }
        context.coordinator.lastZoom = timeline.zoom
        context.coordinator.onHoverChange = { [binding = _hoverInfo] info in binding.wrappedValue = info }
    }

    final class Coordinator {
        var lastZoom: TimelineZoom?
        var onHoverChange: ((TimelineHoverInfo?) -> Void)?
    }

    private func centerPlayhead(in scrollView: NSScrollView, canvas: TimelineCanvasNSView) {
        let visibleRect = scrollView.contentView.bounds
        let maxX = max(canvas.bounds.width - visibleRect.width, 0)
        let targetX = min(max(canvas.playheadX - visibleRect.width / 2, 0), maxX)
        scrollView.contentView.scroll(to: CGPoint(x: targetX, y: visibleRect.origin.y))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    /// Scrolls so `time` stays under the pointer after a pinch or Command-scroll zoom.
    private func keepTime(_ time: TimeInterval, atViewportX viewportX: CGFloat, in scrollView: NSScrollView, canvas: TimelineCanvasNSView) {
        let visibleRect = scrollView.contentView.bounds
        let maxX = max(canvas.bounds.width - visibleRect.width, 0)
        let targetX = min(max(canvas.x(forProjectTime: time) - viewportX, 0), maxX)
        scrollView.contentView.scroll(to: CGPoint(x: targetX, y: visibleRect.origin.y))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func keepPlayheadVisible(in scrollView: NSScrollView, canvas: TimelineCanvasNSView) {
        let visibleRect = scrollView.contentView.bounds
        let playheadX = canvas.playheadX
        let margin: CGFloat = 80
        var targetOrigin = visibleRect.origin

        if playheadX > visibleRect.maxX - margin {
            targetOrigin.x = min(playheadX - visibleRect.width * 0.35, max(canvas.bounds.width - visibleRect.width, 0))
        } else if playheadX < visibleRect.minX + margin {
            targetOrigin.x = max(playheadX - visibleRect.width * 0.35, 0)
        } else {
            return
        }

        scrollView.contentView.scroll(to: targetOrigin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }
}

private struct RectCorners: OptionSet {
    let rawValue: Int

    static let topLeft = RectCorners(rawValue: 1 << 0)
    static let topRight = RectCorners(rawValue: 1 << 1)
    static let bottomRight = RectCorners(rawValue: 1 << 2)
    static let bottomLeft = RectCorners(rawValue: 1 << 3)
    static let all: RectCorners = [.topLeft, .topRight, .bottomRight, .bottomLeft]
}

struct TimelineHoverInfo {
    let visibleX: CGFloat
    let text: String
}

enum TimelineMarqueeGeometry {
    static func startRegion(in bounds: CGRect, timelineStartX: CGFloat, trackStartY: CGFloat) -> CGRect {
        CGRect(
            x: timelineStartX,
            y: trackStartY,
            width: max(bounds.maxX - timelineStartX, 0),
            height: max(bounds.maxY - trackStartY, 0)
        )
    }
}

private struct RulerHoverTooltip: View {
    let info: TimelineHoverInfo

    private static let font = NSFont.systemFont(ofSize: 11, weight: .medium)
    private let horizontalPadding: CGFloat = 8
    private let tooltipHeight: CGFloat = 22
    private let arrowSize: CGFloat = 5
    private let topPad: CGFloat = 4

    /// The pill grows with its text, up to the canvas width.
    private var textWidth: CGFloat {
        ceil((info.text as NSString).size(withAttributes: [.font: Self.font]).width)
    }

    var body: some View {
        GeometryReader { geo in
            let tooltipWidth = min(textWidth + horizontalPadding * 2, max(geo.size.width - 8, 0))
            let x = info.visibleX
            let pillX = min(max(x - tooltipWidth / 2, 4), geo.size.width - tooltipWidth - 4)
            let arrowAnchorX = min(max(x, pillX + 12), pillX + tooltipWidth - 12)

            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    let rect = CGRect(x: pillX, y: topPad, width: tooltipWidth, height: tooltipHeight)
                    let pillPath = Path(roundedRect: rect, cornerRadius: 10)
                    ctx.fill(pillPath, with: .color(Color(nsColor: .editorPanelHeader).opacity(0.96)))
                    ctx.stroke(pillPath, with: .color(Color(nsColor: .editorBorderSubtle).opacity(0.9)), lineWidth: 1)

                    var arrow = Path()
                    arrow.move(to: CGPoint(x: arrowAnchorX - arrowSize, y: topPad + tooltipHeight))
                    arrow.addLine(to: CGPoint(x: arrowAnchorX + arrowSize, y: topPad + tooltipHeight))
                    arrow.addLine(to: CGPoint(x: arrowAnchorX, y: topPad + tooltipHeight + arrowSize))
                    arrow.closeSubpath()
                    ctx.fill(arrow, with: .color(Color(nsColor: .editorPanelHeader).opacity(0.96)))

                    var arrowStroke = Path()
                    arrowStroke.move(to: CGPoint(x: arrowAnchorX - arrowSize, y: topPad + tooltipHeight))
                    arrowStroke.addLine(to: CGPoint(x: arrowAnchorX, y: topPad + tooltipHeight + arrowSize))
                    arrowStroke.addLine(to: CGPoint(x: arrowAnchorX + arrowSize, y: topPad + tooltipHeight))
                    ctx.stroke(arrowStroke, with: .color(Color(nsColor: .editorBorderSubtle).opacity(0.9)), lineWidth: 1)
                }

                Text(info.text)
                    .font(Font(Self.font))
                    .foregroundStyle(Color(nsColor: .editorTextPrimary))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: max(tooltipWidth - horizontalPadding * 2, 0), alignment: .leading)
                    .offset(x: pillX + horizontalPadding, y: topPad + (tooltipHeight - 14) / 2)
            }
        }
        .frame(height: topPad + tooltipHeight + arrowSize)
        .allowsHitTesting(false)
    }
}

final class TimelineCanvasNSView: NSView {
    private weak var project: ProjectDocument?
    private var tracks: [TimelineTrack] = []
    private var activityDuration: TimeInterval = 0
    private var activityLaps: [LapRecord] = []
    private var showsStructuredWorkout = false
    private var activitySegments: [ActivityAnnotatedSegment] = []
    private var fitStartTime: TimeInterval = 0
    private var playhead: TimeInterval = 0
    private var visibleStartTime: TimeInterval = 0
    private var visibleEndTime: TimeInterval = 1
    private var selectedClipIDs: Set<TimelineClip.ID> = []
    private var mediaItemsAreAvailable = false
    private var isCollapsed = false
    private var pixelsPerSecond: Double = 1
    private var draggingClipID: TimelineClip.ID?
    private var dragInitialStart: TimeInterval = 0
    private var dragCurrentStart: TimeInterval = 0
    /// Clip that Shift-click ranges extend from.
    private var selectionAnchorClipID: TimelineClip.ID?
    private var isDraggingPlayhead = false
    private var pointer: TimelinePointer = .arrow
    private var disabledPreviewTrackNames: Set<String> = []
    private var cachedAccessibilityChildren: [Any]?
    private var marqueeAnchor: CGPoint?
    private var marqueeCurrentPoint: CGPoint?
    private var hoverPoint: CGPoint?
    /// Project time under the pointer, and its viewport position, captured
    /// before a pointer-driven zoom so the update can keep it in place.
    private var zoomAnchor: (time: TimeInterval, viewportX: CGFloat)?
    private var isMediaDragActive = false
    private var mediaDropTargetTrackName: String?
    private var trackingArea: NSTrackingArea?
    nonisolated(unsafe) private var keyEventMonitor: Any?

    private let hoverScrubKeyCode = CGKeyCode(TimelineHoverScrubKey.keyCode)
    private let minimumScrubTimeDelta: TimeInterval = 0.0001
    private let rulerScaleHeight: CGFloat = 28
    private let fitTrackHeight: CGFloat = 44
    private let trackHeight: CGFloat = 44
    private let trackGap: CGFloat = 0
    private let labelWidth: CGFloat = 84
    private let contentPadding: CGFloat = 8
    private let playheadLineWidth: CGFloat = 2
    private let playheadHeadSize = CGSize(width: 12, height: 8)
    /// The playhead line can be grabbed this far to either side.
    private let playheadGrabTolerance: CGFloat = 3
    private let trackVisibilityIconSize: CGFloat = 14

    weak var hostScrollView: NSScrollView? {
        didSet {
            registerScrollObserver()
        }
    }
    var onHoverChange: ((TimelineHoverInfo?) -> Void)?

    private var scrollOffsetX: CGFloat {
        hostScrollView?.documentVisibleRect.origin.x ?? 0
    }

    private func registerScrollObserver() {
        NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: nil)
        guard let clip = hostScrollView?.contentView else { return }
        clip.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: clip
        )
    }

    @objc private func scrollViewDidScroll(_ notification: Notification) {
        needsDisplay = true
    }

    private var rulerHeight: CGFloat { rulerScaleHeight }

    private var hasTimelineContent: Bool {
        activityDuration > 0 || !tracks.isEmpty || mediaItemsAreAvailable || isMediaDragActive
    }

    private var trackStartY: CGFloat {
        rulerHeight + (activityDuration > 0 ? fitTrackHeight : 0)
    }

    var playheadX: CGFloat {
        x(forProjectTime: playhead)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        registerForDraggedTypes([.string])
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Timeline")
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        if let keyEventMonitor {
            NSEvent.removeMonitor(keyEventMonitor)
        }
        NotificationCenter.default.removeObserver(self)
    }

    var displayTracks: [TimelineTrack] {
        if tracks.isEmpty, mediaItemsAreAvailable {
            return [TimelineTrack(name: "Layer 1", clips: [])]
        }
        if isMediaDragActive {
            return tracks + [TimelineTrack(name: TimelineModel(tracks: tracks).nextLayerName(), clips: [])]
        }
        return tracks
    }

    func update(
        project: ProjectDocument,
        activity: ActivityTimeline,
        timeline: TimelineModel,
        hasMediaItems: Bool,
        selection: EditorSelection,
        isCollapsed: Bool,
        viewportSize: CGSize
    ) {
        self.project = project
        tracks = timeline.tracks
        activityDuration = activity.duration
        activityLaps = activity.laps
        showsStructuredWorkout = activity.workoutStructure.kind == .structured
        activitySegments = activity.annotatedSegments
        fitStartTime = timeline.fitStartTime
        playhead = timeline.playhead
        mediaItemsAreAvailable = hasMediaItems
        self.isCollapsed = isCollapsed
        disabledPreviewTrackNames = project.settings.disabledPreviewTrackNames
        cachedAccessibilityChildren = nil
        if marqueeAnchor == nil {
            switch selection {
            case .timelineClip(let clipID):
                selectedClipIDs = [clipID]
            case .timelineClips(let clipIDs):
                selectedClipIDs = clipIDs
            case .overlayElement, .none:
                selectedClipIDs = []
            }
        }
        let displayBounds = timeline.displayBounds(activityDuration: activity.duration, collapsed: isCollapsed)
        visibleStartTime = displayBounds.lowerBound
        visibleEndTime = displayBounds.upperBound
        let fitPixelsPerSecond = resolvePixelsPerSecond(zoom: .fit, viewportWidth: viewportSize.width)
        project.fitPixelsPerSecond = fitPixelsPerSecond
        let rawPixelsPerSecond = resolvePixelsPerSecond(zoom: timeline.zoom, viewportWidth: viewportSize.width)
        pixelsPerSecond = max(rawPixelsPerSecond, fitPixelsPerSecond)

        let visibleDuration = max(visibleEndTime - visibleStartTime, 1)
        let timelineWidth = max(
            viewportSize.width,
            labelWidth + contentPadding * 2 + CGFloat(visibleDuration * pixelsPerSecond)
        )
        let trackCount = hasTimelineContent ? max(displayTracks.count, 1) : 0
        let timelineHeight = max(
            viewportSize.height,
            hasTimelineContent
                ? trackStartY + CGFloat(trackCount) * trackHeight + CGFloat(max(trackCount - 1, 0)) * trackGap
                : viewportSize.height
        )
        frame = CGRect(origin: .zero, size: CGSize(width: timelineWidth, height: timelineHeight))
        needsDisplay = true
    }

    override var isFlipped: Bool {
        true
    }

    // MARK: Accessibility

    /// Layers (each holding its clips) followed by the playhead slider.
    override func accessibilityChildren() -> [Any]? {
        if let cachedAccessibilityChildren {
            return cachedAccessibilityChildren
        }
        var children: [Any] = []
        let timelineStartX = labelWidth + contentPadding
        for (index, track) in tracks.enumerated() {
            let y = trackStartY + CGFloat(index) * (trackHeight + trackGap)
            let trackElement = TimelineAccessibilityElement(canvas: self, rect: CGRect(
                x: timelineStartX,
                y: y,
                width: max(bounds.width - timelineStartX, 1),
                height: trackHeight
            ))
            trackElement.setAccessibilityRole(.group)
            trackElement.setAccessibilityLabel(
                "\(track.name), \(track.clips.count == 1 ? "1 clip" : "\(track.clips.count) clips")"
            )
            trackElement.setAccessibilityParent(self)
            trackElement.setAccessibilityChildren(track.clips.map { clip in
                let clipElement = TimelineClipAccessibilityElement(canvas: self, rect: clipRect(clip, trackY: y))
                clipElement.setAccessibilityRole(.button)
                clipElement.setAccessibilityRoleDescription("clip")
                clipElement.setAccessibilityLabel(
                    "\(clip.title), starts at \(formatSignedDuration(clip.effectiveStartTime - fitStartTime)), duration \(formatDuration(clip.duration))"
                )
                clipElement.isSelectedClip = selectedClipIDs.contains(clip.id)
                clipElement.setAccessibilityParent(trackElement)
                clipElement.onPress = { [weak self] in
                    self?.selectedClipIDs = [clip.id]
                    self?.selectionAnchorClipID = clip.id
                    self?.project?.selectClip(clip.id)
                }
                return clipElement
            })
            children.append(trackElement)
        }
        if hasPlayhead {
            let playheadElement = TimelinePlayheadAccessibilityElement(canvas: self, rect: CGRect(
                x: playheadX - playheadGrabTolerance,
                y: 0,
                width: playheadGrabTolerance * 2,
                height: bounds.height
            ))
            playheadElement.setAccessibilityRole(.slider)
            playheadElement.setAccessibilityLabel("Playhead")
            playheadElement.setAccessibilityValue(formatSignedDuration(playhead - fitStartTime))
            playheadElement.setAccessibilityParent(self)
            playheadElement.step = { [weak self] frames in
                self?.project?.stepPlayheadByFrames(frames)
            }
            children.append(playheadElement)
        }
        cachedAccessibilityChildren = children
        return children
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == hoverScrubKeyCode {
            return
        }
        if TimelineDeleteKey.matches(keyCode: event.keyCode, modifiers: event.modifierFlags) {
            delete(nil)
            return
        }
        super.keyDown(with: event)
    }

    /// Delete is claimed before the main menu sees it. Otherwise a menu item
    /// that shares the key equivalent but is disabled for the current
    /// responder chain swallows the key with an error beep.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if window?.firstResponder === self,
           TimelineDeleteKey.matches(keyCode: event.keyCode, modifiers: event.modifierFlags) {
            delete(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    /// Edit > Delete and the Delete keys.
    @objc func delete(_ sender: Any?) {
        project?.deleteSelectedItem()
    }

    /// Edit > Select All (Command-A) while the timeline has focus.
    override func selectAll(_ sender: Any?) {
        let clipIDs = Set(tracks.flatMap(\.clips).map(\.id))
        selectedClipIDs = clipIDs
        project?.selectClips(clipIDs)
        needsDisplay = true
    }

    override func keyUp(with event: NSEvent) {
        if event.keyCode == hoverScrubKeyCode {
            return
        }
        super.keyUp(with: event)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            if let keyEventMonitor {
                NSEvent.removeMonitor(keyEventMonitor)
                self.keyEventMonitor = nil
            }
            return
        }
        guard keyEventMonitor == nil else {
            return
        }
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self,
                  TimelineHoverScrubKey.shouldConsume(
                    keyCode: event.keyCode,
                    isMouseOverTimeline: self.isMouseOverTimeline,
                    isTextInputFocused: self.isTextInputFocused
                  ) else {
                return event
            }
            return nil
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .activeInKeyWindow],
            owner: self
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.editorPanelBackground.setFill()
        bounds.fill()
        guard hasTimelineContent else {
            return
        }
        drawTimelineSections()
        drawRuler()
        if activityDuration > 0 {
            drawFitTrack()
        }
        drawTracks()
        drawMarqueeSelection()
        if activityDuration > 0 || !tracks.isEmpty {
            drawPlayhead()
        }
        drawStickyLabelColumn()
    }

    private func drawStickyLabelColumn() {
        let offsetX = scrollOffsetX
        guard offsetX > 0 else {
            return
        }
        let columnWidth = labelWidth + contentPadding

        let rulerCornerRect = CGRect(x: offsetX, y: 0, width: columnWidth, height: rulerHeight)
        NSColor.editorPanelHeader.setFill()
        rulerCornerRect.fill()

        let belowRect = CGRect(
            x: offsetX,
            y: rulerHeight,
            width: columnWidth,
            height: max(bounds.height - rulerHeight, 0)
        )
        NSColor.timelineLabelColumnBackground.setFill()
        belowRect.fill()

        NSColor.editorBorderSubtle.setStroke()
        NSBezierPath.strokeLine(
            from: CGPoint(x: offsetX + columnWidth - 0.5, y: 0),
            to: CGPoint(x: offsetX + columnWidth - 0.5, y: bounds.height)
        )
        NSBezierPath.strokeLine(
            from: CGPoint(x: offsetX, y: rulerHeight - 0.5),
            to: CGPoint(x: offsetX + columnWidth, y: rulerHeight - 0.5)
        )

        if activityDuration > 0 {
            let y = rulerHeight
            NSColor.editorBorderSubtle.withAlphaComponent(0.55).setStroke()
            NSBezierPath.strokeLine(
                from: CGPoint(x: offsetX, y: y + fitTrackHeight - 0.5),
                to: CGPoint(x: offsetX + columnWidth - 1, y: y + fitTrackHeight - 0.5)
            )
            drawText(
                "Activity",
                at: CGPoint(x: offsetX + 10, y: y + 16),
                color: .editorTextPrimary,
                font: .systemFont(ofSize: 11, weight: .semibold)
            )
        }

        for (index, track) in displayTracks.enumerated() {
            let y = trackStartY + CGFloat(index) * (trackHeight + trackGap)
            NSColor.editorBorderSubtle.withAlphaComponent(0.55).setStroke()
            NSBezierPath.strokeLine(
                from: CGPoint(x: offsetX, y: y + trackHeight - 0.5),
                to: CGPoint(x: offsetX + columnWidth - 1, y: y + trackHeight - 0.5)
            )
            drawTrackLabel(track, trackY: y, offsetX: offsetX)
        }
    }

    /// Layer name plus its preview visibility eye. Layers excluded from the
    /// preview draw dimmed.
    private func drawTrackLabel(_ track: TimelineTrack, trackY y: CGFloat, offsetX: CGFloat) {
        let isRealTrack = tracks.contains { $0.name == track.name }
        let isHidden = disabledPreviewTrackNames.contains(track.name)
        let eyeRect = trackVisibilityRect(trackY: y, offsetX: offsetX)
        let nameWidth = (isRealTrack ? eyeRect.minX - 4 : offsetX + labelWidth + contentPadding) - (offsetX + 10)
        drawText(
            track.name,
            in: CGRect(x: offsetX + 10, y: y + 16, width: max(nameWidth, 0), height: 16),
            color: isHidden ? .editorTextMuted : .editorTextPrimary,
            font: .systemFont(ofSize: 11, weight: .medium),
            lineBreakMode: .byTruncatingTail
        )
        guard isRealTrack,
              let symbol = NSImage(
                systemSymbolName: isHidden ? "eye.slash" : "eye",
                accessibilityDescription: isHidden ? "Show in Preview" : "Hide from Preview"
              ),
              let image = symbol.withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
                    .applying(NSImage.SymbolConfiguration(hierarchicalColor: isHidden ? .editorTextMuted : .editorTextSecondary))
              ) else {
            return
        }
        let size = image.size
        let imageRect = CGRect(
            x: eyeRect.midX - size.width / 2,
            y: eyeRect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    private func trackVisibilityRect(trackY y: CGFloat, offsetX: CGFloat) -> CGRect {
        let size = trackVisibilityIconSize + 6
        return CGRect(
            x: offsetX + labelWidth + contentPadding - size - 4,
            y: y + (trackHeight - size) / 2,
            width: size,
            height: size
        )
    }

    /// Name of the layer whose visibility eye is under `point`.
    private func trackVisibilityHit(at point: CGPoint) -> String? {
        for (index, track) in tracks.enumerated() {
            let y = trackStartY + CGFloat(index) * (trackHeight + trackGap)
            if trackVisibilityRect(trackY: y, offsetX: scrollOffsetX).contains(point) {
                return track.name
            }
        }
        return nil
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if scrubPlayheadIfNeeded(at: point) {
            return
        }

        let inRuler = point.y <= rulerHeight && activityDuration > 0
        let pauseHit = activitySegmentHit(at: point)
        let lapHit = pauseHit == nil ? lapHit(at: point) : nil
        hoverPoint = inRuler || pauseHit != nil || lapHit != nil ? point : nil
        if let pauseHit {
            let scrollOffsetX = hostScrollView?.documentVisibleRect.origin.x ?? 0
            let visibleX = point.x - scrollOffsetX
            let text = "\(pauseHit.kind.label) • \(formatDuration(pauseHit.startElapsedTime))-\(formatDuration(pauseHit.endElapsedTime)) • \(formatDuration(pauseHit.duration))"
            onHoverChange?(TimelineHoverInfo(visibleX: visibleX, text: text))
        } else if let lapHit {
            let scrollOffsetX = hostScrollView?.documentVisibleRect.origin.x ?? 0
            let visibleX = point.x - scrollOffsetX
            let text = "\(lapKindTitle(lapHit.kind)) #\(lapHit.lapIndex + 1) • \(formatDuration(lapHit.startElapsedTime))-\(formatDuration(lapHit.endElapsedTime)) • \(formatDuration(lapHit.totalElapsedTime))"
            onHoverChange?(TimelineHoverInfo(visibleX: visibleX, text: text))
        } else if inRuler, let project {
            let scrollOffsetX = hostScrollView?.documentVisibleRect.origin.x ?? 0
            let visibleX = point.x - scrollOffsetX
            let projectTime = time(atX: point.x)
            let elapsed = projectTime - fitStartTime
            let text = "\(formatSignedDuration(elapsed)) • \(project.activity.timestamp(at: elapsed).formatted(date: .omitted, time: .shortened)) • \(String(format: "%.2f km", project.activity.distance(at: elapsed) / 1000))"
            onHoverChange?(TimelineHoverInfo(visibleX: visibleX, text: text))
        } else {
            onHoverChange?(nil)
        }
        updatePointer(at: point)
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hoverPoint = nil
        onHoverChange?(nil)
        setPointer(.arrow, help: nil)
        needsDisplay = true
    }

    override func cursorUpdate(with event: NSEvent) {
        pointer.cursor.set()
    }

    private func updatePointer(at point: CGPoint) {
        let target: TimelinePointer.Target
        if !hasTimelineContent || point.x < scrollOffsetX + labelWidth + contentPadding {
            target = .none
        } else if point.y <= rulerHeight && activityDuration > 0 {
            target = .ruler
        } else if isNearPlayhead(point) {
            target = .playhead
        } else if clipHit(at: point) != nil {
            target = .clip
        } else {
            target = .none
        }
        let next = TimelinePointer.pointer(for: target, isCollapsed: isCollapsed, isDraggingClip: draggingClipID != nil)
        setPointer(next, help: next == .notAllowed ? TimelinePointer.collapsedClipHelp : nil)
    }

    private func setPointer(_ next: TimelinePointer, help: String?) {
        pointer = next
        next.cursor.set()
        if toolTip != help {
            toolTip = help
        }
    }

    private var hasPlayhead: Bool {
        activityDuration > 0 || !tracks.isEmpty
    }

    private func isNearPlayhead(_ point: CGPoint) -> Bool {
        hasPlayhead
            && point.y > rulerHeight
            && point.x >= scrollOffsetX + labelWidth + contentPadding
            && abs(point.x - playheadX) <= playheadGrabTolerance
    }

    override func mouseDown(with event: NSEvent) {
        guard let project else { return }
        window?.makeKey()
        window?.makeFirstResponder(self)
        project.clearMediaPoolPreview()
        let point = convert(event.locationInWindow, from: nil)
        if point.y <= rulerHeight {
            isDraggingPlayhead = true
            project.seekPlayheadFromTimeline(time(atX: point.x))
            return
        }

        if let trackName = trackVisibilityHit(at: point) {
            project.setPreviewTrackDisabled(trackName, disabled: !disabledPreviewTrackNames.contains(trackName))
            return
        }

        if isNearPlayhead(point) {
            isDraggingPlayhead = true
            project.seekPlayheadFromTimeline(time(atX: point.x))
            return
        }

        if fitTrackRects().contains(where: { $0.contains(point) }) {
            return
        }

        if let hit = clipHit(at: point) {
            let mode = TimelineClipSelection.mode(for: event.modifierFlags)
            let result = TimelineClipSelection.click(
                hit.clip.id,
                mode: mode,
                current: selectedClipIDs,
                anchor: selectionAnchorClipID,
                tracks: tracks
            )
            selectionAnchorClipID = result.anchor
            selectedClipIDs = result.selection
            project.selectClips(result.selection)
            if mode == .replace && !isCollapsed {
                draggingClipID = hit.clip.id
                dragInitialStart = hit.clip.effectiveStartTime
                dragCurrentStart = hit.clip.effectiveStartTime
                setPointer(.closedHand, help: nil)
            }
            needsDisplay = true
        } else {
            project.clearSelection()
            selectedClipIDs = []
            selectionAnchorClipID = nil
            if marqueeStartRegion.contains(point) {
                marqueeAnchor = point
                marqueeCurrentPoint = point
            }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let project else { return }
        let point = convert(event.locationInWindow, from: nil)
        if scrubPlayheadIfNeeded(at: point) {
            return
        }

        if isDraggingPlayhead {
            project.seekPlayheadFromTimeline(time(atX: point.x))
            return
        }

        if marqueeAnchor != nil {
            marqueeCurrentPoint = point
            selectedClipIDs = clipsIntersectingMarquee()
            needsDisplay = true
            return
        }

        guard draggingClipID != nil else {
            return
        }
        let delta = Double(event.deltaX) / max(pixelsPerSecond, 0.001)
        dragCurrentStart += delta
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        isDraggingPlayhead = false
        if marqueeAnchor != nil {
            project?.selectClips(selectedClipIDs)
            selectionAnchorClipID = nil
            marqueeAnchor = nil
            marqueeCurrentPoint = nil
            needsDisplay = true
            return
        }
        if let draggingClipID {
            project?.moveTimelineClipFromDrag(draggingClipID, toEffectiveStartTime: dragCurrentStart)
        }
        draggingClipID = nil
        project?.finishContinuousEdit()
        updatePointer(at: convert(event.locationInWindow, from: nil))
    }

    /// Clip menus hold clip commands only. Deleting a layer is offered from
    /// the layer's label or an empty part of its lane.
    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard point.y >= trackStartY else {
            return
        }
        let index = Int((point.y - trackStartY) / (trackHeight + trackGap))
        guard index >= 0, index < tracks.count else {
            return
        }
        let trackName = tracks[index].name
        let menu = NSMenu()
        let inLabelColumn = point.x < scrollOffsetX + labelWidth + contentPadding
        if !inLabelColumn, let hit = clipHit(at: point) {
            // Right-clicking inside the selection keeps it, so the menu acts
            // on every selected clip.
            if !selectedClipIDs.contains(hit.clip.id) {
                selectedClipIDs = [hit.clip.id]
                selectionAnchorClipID = hit.clip.id
                project?.selectClip(hit.clip.id)
                needsDisplay = true
            }
            addClipMenuItems(for: hit.clip, to: menu)
        } else {
            let item = NSMenuItem(
                title: "Delete \(trackName)…",
                action: #selector(deleteTrackMenuAction(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = trackName
            menu.addItem(item)
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    private func addClipMenuItems(for clip: TimelineClip, to menu: NSMenu) {
        let clipIDs = selectedClipIDs.contains(clip.id) ? selectedClipIDs : [clip.id]
        let clips = clipIDs.compactMap { id in tracks.lazy.flatMap(\.clips).first { $0.id == id } }
        // Menu validation is off so the item states below are honored.
        menu.autoenablesItems = false

        let applyOffset = NSMenuItem(
            title: "Apply Offset to Layer",
            action: #selector(applyOffsetToTrackMenuAction(_:)),
            keyEquivalent: ""
        )
        applyOffset.target = self
        applyOffset.representedObject = clip.id
        applyOffset.isEnabled = clipIDs.count == 1
        applyOffset.toolTip = String(format: "Apply this clip's %+.2f s offset to every clip in its layer.", clip.alignmentOffset)
        menu.addItem(applyOffset)

        let resetOffset = NSMenuItem(
            title: clipIDs.count == 1 ? "Reset Offset" : "Reset Offsets",
            action: #selector(resetClipOffsetMenuAction(_:)),
            keyEquivalent: ""
        )
        resetOffset.target = self
        resetOffset.representedObject = clipIDs
        resetOffset.isEnabled = clips.contains { $0.alignmentOffset != 0 }
        menu.addItem(resetOffset)

        menu.addItem(.separator())

        let delete = NSMenuItem(
            title: clipIDs.count == 1 ? "Delete Clip" : "Delete \(clipIDs.count) Clips",
            action: #selector(deleteClipMenuAction(_:)),
            keyEquivalent: String(UnicodeScalar(UInt8(NSBackspaceCharacter)))
        )
        delete.keyEquivalentModifierMask = []
        delete.target = self
        delete.representedObject = clipIDs
        menu.addItem(delete)
    }

    @objc private func applyOffsetToTrackMenuAction(_ sender: NSMenuItem) {
        guard let clipID = sender.representedObject as? TimelineClip.ID else { return }
        project?.applyOffsetToCurrentLayer(for: clipID)
    }

    @objc private func resetClipOffsetMenuAction(_ sender: NSMenuItem) {
        guard let clipIDs = sender.representedObject as? Set<TimelineClip.ID> else { return }
        project?.resetClipOffsets(clipIDs)
    }

    @objc private func deleteClipMenuAction(_ sender: NSMenuItem) {
        guard let clipIDs = sender.representedObject as? Set<TimelineClip.ID> else { return }
        project?.selectClips(clipIDs)
        project?.deleteSelectedItem()
    }

    @objc private func deleteTrackMenuAction(_ sender: NSMenuItem) {
        guard let trackName = sender.representedObject as? String, let project else {
            return
        }
        let clipCount = tracks.first { $0.name == trackName }?.clips.count ?? 0
        let alert = NSAlert()
        alert.messageText = "Delete \(trackName)?"
        alert.informativeText = switch clipCount {
        case 0: "The empty layer is removed. You can undo this."
        case 1: "The layer and its clip are removed from the timeline. You can undo this."
        default: "The layer and its \(clipCount) clips are removed from the timeline. You can undo this."
        }
        let deleteButton = alert.addButton(withTitle: "Delete")
        deleteButton.hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        guard let window else {
            project.removeTrack(named: trackName)
            return
        }
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            project.removeTrack(named: trackName)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            let delta = Double(event.scrollingDeltaY)
            guard delta != 0 else { return }
            // Trackpads report many small precise deltas; mouse wheels report notches.
            let factor = event.hasPreciseScrollingDeltas
                ? exp(delta * Self.preciseScrollZoomSensitivity)
                : (delta > 0 ? ProjectDocument.timelineZoomStep : 1 / ProjectDocument.timelineZoomStep)
            zoom(by: factor, around: event)
            return
        }
        super.scrollWheel(with: event)
    }

    override func magnify(with event: NSEvent) {
        zoom(by: 1 + max(Double(event.magnification), -0.9), around: event)
    }

    private static let preciseScrollZoomSensitivity = 0.01

    private func zoom(by factor: Double, around event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        zoomAnchor = (time(atX: point.x), point.x - scrollOffsetX)
        project?.zoomTimeline(by: factor)
    }

    func takeZoomAnchor() -> (time: TimeInterval, viewportX: CGFloat)? {
        defer { zoomAnchor = nil }
        return zoomAnchor
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        isMediaDragActive = true
        updateDropTarget(sender)
        needsDisplay = true
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateDropTarget(sender)
        needsDisplay = true
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isMediaDragActive = false
        mediaDropTargetTrackName = nil
        needsDisplay = true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer {
            isMediaDragActive = false
            mediaDropTargetTrackName = nil
            needsDisplay = true
        }

        guard let project,
              let string = sender.draggingPasteboard.string(forType: .string),
              let mediaID = UUID(uuidString: string) else {
            return false
        }

        let point = convert(sender.draggingLocation, from: nil)
        let trackName = mediaDropTargetTrackName ?? trackName(atY: point.y) ?? TimelineModel(tracks: tracks).nextLayerName()
        project.placeMediaItem(mediaID, onTrack: trackName, at: time(atX: point.x))
        return true
    }

    private func drawRuler() {
        NSColor.editorPanelHeader.setFill()
        CGRect(x: 0, y: 0, width: bounds.width, height: rulerHeight).fill()

        guard activityDuration > 0 else {
            return
        }

        let timelineStartX = labelWidth + contentPadding
        let timelineWidth = CGFloat(max(visibleEndTime - visibleStartTime, 1) * pixelsPerSecond)
        let scaleTopY: CGFloat = 0
        NSColor.editorBorderSubtle.setStroke()
        NSBezierPath.strokeLine(
            from: CGPoint(x: 0, y: rulerHeight - 0.5),
            to: CGPoint(x: bounds.width, y: rulerHeight - 0.5)
        )
        NSBezierPath.strokeLine(
            from: CGPoint(x: timelineStartX - 0.5, y: scaleTopY),
            to: CGPoint(x: timelineStartX - 0.5, y: rulerHeight)
        )

        let visibleDuration = max(visibleEndTime - visibleStartTime, 1)
        let approximateTickCount = max(Int((bounds.width - timelineStartX) / 110), 6)
        let tickStep = max(visibleDuration / Double(approximateTickCount), 1)
        let firstTick = floor(visibleStartTime / tickStep) * tickStep
        let lastTick = visibleEndTime + tickStep

        var tick = firstTick
        while tick <= lastTick {
            let progress = CGFloat((tick - visibleStartTime) / visibleDuration)
            if progress < -0.02 || progress > 1.02 {
                tick += tickStep
                continue
            }

            let displayTime = tick
            let projectTime = TimelineModel(tracks: tracks, zoom: .fit, playhead: playhead, fitStartTime: fitStartTime)
                .projectTime(forDisplayTime: displayTime, activityDuration: activityDuration, collapsed: isCollapsed)
            let x = timelineStartX + timelineWidth * progress
            NSColor.editorBorderSubtle.withAlphaComponent(0.6).setStroke()
            NSBezierPath.strokeLine(from: CGPoint(x: x, y: scaleTopY + 18), to: CGPoint(x: x, y: rulerHeight - 2))
            drawText(
                formatSignedDuration(projectTime - fitStartTime),
                at: CGPoint(x: x - 20, y: scaleTopY + 6),
                color: .editorTextMuted,
                font: .systemFont(ofSize: 10)
            )
            tick += tickStep
        }
    }

    private func drawFitTrack() {
        let y = rulerHeight
        let timelineStartX = labelWidth + contentPadding
        let labelRect = CGRect(x: 0, y: y, width: timelineStartX - 1, height: fitTrackHeight)
        NSColor.timelineLabelColumnBackground.setFill()
        labelRect.fill()
        NSColor.editorBorderSubtle.withAlphaComponent(0.55).setStroke()
        NSBezierPath.strokeLine(from: CGPoint(x: 0, y: y + fitTrackHeight - 0.5), to: CGPoint(x: timelineStartX - 1, y: y + fitTrackHeight - 0.5))
        drawText("Activity", at: CGPoint(x: 10, y: y + 16), color: .editorTextPrimary, font: .systemFont(ofSize: 11, weight: .semibold))

        let laneRect = CGRect(x: timelineStartX, y: y, width: max(bounds.width - timelineStartX, 1), height: fitTrackHeight)
        NSColor.timelineTrackBandA.setFill()
        laneRect.fill()
        NSColor.editorBorderSubtle.withAlphaComponent(0.45).setStroke()
        NSBezierPath.strokeLine(from: CGPoint(x: laneRect.minX, y: laneRect.maxY - 0.5), to: CGPoint(x: laneRect.maxX, y: laneRect.maxY - 0.5))

        guard activityDuration > 0 else {
            return
        }
        let fitRects = fitTrackRects()
        for fitRect in fitRects {
            let path = roundedPath(fitRect, radius: 4)
            if showsStructuredWorkout {
                drawIntervalFitTrack(in: fitRect, clippedBy: path)
            } else {
                NSColor.timelineFitGreen.withAlphaComponent(0.9).setFill()
                path.fill()
            }
            drawActivitySegments(in: fitRect, clippedBy: path)
            NSColor.timelineSpliceBorder.withAlphaComponent(0.9).setStroke()
            path.lineWidth = isCollapsed ? 1.3 : 1
            path.stroke()
        }
        if let fitRect = fitRects.first {
            drawText("00:00", in: fitRect.insetBy(dx: 8, dy: 6), color: .white, font: .systemFont(ofSize: 11, weight: .medium), lineBreakMode: .byTruncatingTail)
        }
    }

    private func drawIntervalFitTrack(in fitRect: CGRect, clippedBy clipPath: NSBezierPath) {
        NSGraphicsContext.saveGraphicsState()
        clipPath.addClip()
        NSColor.timelineFitGreen.withAlphaComponent(0.9).setFill()
        fitRect.fill()
        for lap in activityLaps where lap.endElapsedTime > lap.startElapsedTime {
            let color = lapKindColor(lap.kind).withAlphaComponent(0.92)
            color.setFill()
            for rect in lapRects(lap).map({ $0.intersection(fitRect) }) where !rect.isNull && rect.width > 0 {
                rect.fill()
            }
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawActivitySegments(in fitRect: CGRect, clippedBy clipPath: NSBezierPath) {
        NSGraphicsContext.saveGraphicsState()
        clipPath.addClip()
        for segment in activitySegments where segment.duration > 0 {
            let color = activitySegmentColor(segment)
            for rect in activitySegmentRects(segment).map({ $0.intersection(fitRect) }) where !rect.isNull && rect.width > 0 {
                color.withAlphaComponent(0.92).setFill()
                rect.fill()
            }
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawTimelineSections() {
        let timelineStartX = labelWidth + contentPadding
        NSColor.timelineLabelColumnBackground.setFill()
        CGRect(x: 0, y: 0, width: timelineStartX, height: bounds.height).fill()

        NSColor.editorPanelBackground.setFill()
        CGRect(x: timelineStartX, y: 0, width: max(bounds.width - timelineStartX, 0), height: bounds.height).fill()

        NSColor.editorBorderSubtle.setStroke()
        NSBezierPath.strokeLine(
            from: CGPoint(x: timelineStartX - 0.5, y: 0),
            to: CGPoint(x: timelineStartX - 0.5, y: bounds.height)
        )
    }

    private func drawTracks() {
        let tracks = displayTracks
        let timelineStartX = labelWidth + contentPadding
        let laneDuration = max(visibleEndTime - visibleStartTime, 1)
        let laneWidth = max(bounds.width - timelineStartX - contentPadding, CGFloat(laneDuration * pixelsPerSecond))

        for (index, track) in tracks.enumerated() {
            let y = trackStartY + CGFloat(index) * (trackHeight + trackGap)
            let labelRect = CGRect(x: 0, y: y, width: timelineStartX - 1, height: trackHeight)
            NSColor.timelineLabelColumnBackground.setFill()
            labelRect.fill()
            NSColor.editorBorderSubtle.withAlphaComponent(0.55).setStroke()
            NSBezierPath.strokeLine(from: CGPoint(x: 0, y: y + trackHeight - 0.5), to: CGPoint(x: timelineStartX - 1, y: y + trackHeight - 0.5))
            drawTrackLabel(track, trackY: y, offsetX: 0)

            let laneRect = CGRect(x: timelineStartX, y: y, width: laneWidth, height: trackHeight)
            (index % 2 == 0 ? NSColor.timelineTrackBandA : NSColor.timelineTrackBandB).setFill()
            laneRect.fill()
            NSColor.editorBorderSubtle.withAlphaComponent(0.45).setStroke()
            NSBezierPath.strokeLine(
                from: CGPoint(x: laneRect.minX, y: laneRect.maxY - 0.5),
                to: CGPoint(x: laneRect.maxX, y: laneRect.maxY - 0.5)
            )

            if mediaDropTargetTrackName == track.name {
                NSColor.timelineDropTargetBorder.withAlphaComponent(0.16).setFill()
                laneRect.insetBy(dx: 1, dy: 1).fill()
                NSColor.timelineDropTargetBorder.withAlphaComponent(0.9).setStroke()
                let path = NSBezierPath(rect: laneRect.insetBy(dx: 1.5, dy: 1.5))
                path.setLineDash([5, 4], count: 2, phase: 0)
                path.lineWidth = 1.5
                path.stroke()
            }

            for clip in track.clips {
                drawClip(clip, in: track, y: y, timelineStartX: timelineStartX)
            }

        }
    }

    private func drawPlayhead() {
        guard visibleEndTime > visibleStartTime else {
            return
        }

        let x = x(forProjectTime: playhead)
        let headTipY = rulerHeight - 2
        let headTopY = headTipY - playheadHeadSize.height

        let lineRect = CGRect(
            x: x - playheadLineWidth / 2,
            y: headTipY,
            width: playheadLineWidth,
            height: bounds.height - headTipY
        )
        NSColor.timelinePlayheadRed.withAlphaComponent(0.92).setFill()
        lineRect.fill()

        let headPath = NSBezierPath()
        headPath.move(to: CGPoint(x: x - playheadHeadSize.width / 2, y: headTopY))
        headPath.line(to: CGPoint(x: x + playheadHeadSize.width / 2, y: headTopY))
        headPath.line(to: CGPoint(x: x, y: headTipY))
        headPath.close()
        NSColor.timelinePlayheadRed.setFill()
        headPath.fill()
    }

    private func drawClip(_ clip: TimelineClip, in track: TimelineTrack, y: CGFloat, timelineStartX: CGFloat) {
        let effectiveStart = clip.id == draggingClipID ? dragCurrentStart : clip.effectiveStartTime
        let x = x(forProjectTime: effectiveStart)
        let width = max(CGFloat(clip.duration * pixelsPerSecond), 1)
        let rect = CGRect(x: x, y: y + 6, width: width, height: trackHeight - 12)
        let isSelected = selectedClipIDs.contains(clip.id)
        let previewAlpha: CGFloat = disabledPreviewTrackNames.contains(track.name) ? 0.45 : 1
        let color = (isSelected ? NSColor.timelineClipBlue : NSColor.timelineClipBlue.withAlphaComponent(0.72))
            .withAlphaComponent((isSelected ? 1 : 0.72) * previewAlpha)
        let roundedCorners = clipRoundedCorners(for: clip, in: track)
        let fillPath = roundedPath(rect, radius: 4, corners: roundedCorners)
        color.setFill()
        fillPath.fill()

        let borderPath = roundedPath(rect, radius: 4, corners: roundedCorners)
        if isSelected {
            NSColor.white.setStroke()
            borderPath.lineWidth = 2
        } else {
            NSColor.timelineSpliceBorder.withAlphaComponent(isCollapsed ? 0.9 : 0.7).setStroke()
            borderPath.lineWidth = 1.1
        }
        borderPath.stroke()

        if rect.width >= 36 {
            drawText(
                clip.title,
                in: rect.insetBy(dx: 8, dy: 8),
                color: .white,
                font: .systemFont(ofSize: 11),
                lineBreakMode: .byTruncatingMiddle
            )
        }
    }

    private func clipRoundedCorners(for clip: TimelineClip, in track: TimelineTrack) -> RectCorners {
        let joins = clipDisplayJoins(for: clip, in: track)

        var corners: RectCorners = []
        if !joins.previous {
            corners.insert(.topLeft)
            corners.insert(.bottomLeft)
        }
        if !joins.next {
            corners.insert(.topRight)
            corners.insert(.bottomRight)
        }
        return corners
    }

    private func clipDisplayJoins(for clip: TimelineClip, in track: TimelineTrack) -> (previous: Bool, next: Bool) {
        let timeline = TimelineModel(tracks: tracks, zoom: .fit, playhead: playhead, fitStartTime: fitStartTime)
        let displayStart = timeline.displayTime(forProjectTime: clip.effectiveStartTime, activityDuration: activityDuration, collapsed: isCollapsed)
        let displayEnd = displayStart + clip.duration
        var previous = false
        var next = false

        for otherClip in track.clips where otherClip.id != clip.id {
            let otherDisplayStart = timeline.displayTime(forProjectTime: otherClip.effectiveStartTime, activityDuration: activityDuration, collapsed: isCollapsed)
            let otherDisplayEnd = otherDisplayStart + otherClip.duration
            previous = previous || abs(otherDisplayEnd - displayStart) < 0.001
            next = next || abs(otherDisplayStart - displayEnd) < 0.001
        }

        return (previous, next)
    }

    private func drawRulerHover() {
        guard let project, let hoverPoint, activityDuration > 0 else {
            return
        }

        let projectTime = time(atX: hoverPoint.x)
        let elapsed = projectTime - fitStartTime
        let line = "\(formatSignedDuration(elapsed)) • \(project.activity.timestamp(at: elapsed).formatted(date: .omitted, time: .shortened)) • \(String(format: "%.2f km", project.activity.distance(at: elapsed) / 1000))"
        let width: CGFloat = 220
        let height: CGFloat = 22
        let arrowSize: CGFloat = 5
        let pillX = min(max(hoverPoint.x - width / 2, 4), bounds.width - width - 4)
        let rect = CGRect(x: pillX, y: 4, width: width, height: height)
        let arrowAnchorX = min(max(hoverPoint.x, rect.minX + 12), rect.maxX - 12)

        NSColor.editorPanelHeader.withAlphaComponent(0.96).setFill()
        roundedPath(rect, radius: 10).fill()
        NSColor.editorBorderSubtle.withAlphaComponent(0.9).setStroke()
        roundedPath(rect, radius: 10).stroke()

        let arrowPath = NSBezierPath()
        arrowPath.move(to: CGPoint(x: arrowAnchorX - arrowSize, y: rect.maxY))
        arrowPath.line(to: CGPoint(x: arrowAnchorX + arrowSize, y: rect.maxY))
        arrowPath.line(to: CGPoint(x: arrowAnchorX, y: rect.maxY + arrowSize))
        arrowPath.close()
        NSColor.editorPanelHeader.withAlphaComponent(0.96).setFill()
        arrowPath.fill()
        NSColor.editorBorderSubtle.withAlphaComponent(0.9).setStroke()
        let arrowStroke = NSBezierPath()
        arrowStroke.move(to: CGPoint(x: arrowAnchorX - arrowSize, y: rect.maxY))
        arrowStroke.line(to: CGPoint(x: arrowAnchorX, y: rect.maxY + arrowSize))
        arrowStroke.line(to: CGPoint(x: arrowAnchorX + arrowSize, y: rect.maxY))
        arrowStroke.lineWidth = 1
        arrowStroke.stroke()

        drawText(
            line,
            in: rect.insetBy(dx: 8, dy: 4),
            color: .editorTextPrimary,
            font: .systemFont(ofSize: 10, weight: .medium),
            lineBreakMode: .byTruncatingTail
        )
    }

    private func clipHit(at point: CGPoint) -> (track: TimelineTrack, clip: TimelineClip)? {
        for (index, track) in displayTracks.enumerated() {
            let y = trackStartY + CGFloat(index) * (trackHeight + trackGap)
            for clip in track.clips {
                let rect = clipRect(clip, trackY: y)
                if rect.contains(point) {
                    return (track, clip)
                }
            }
        }
        return nil
    }

    private func clipRect(_ clip: TimelineClip, trackY: CGFloat) -> CGRect {
        CGRect(
            x: x(forProjectTime: clip.effectiveStartTime),
            y: trackY + 6,
            width: max(CGFloat(clip.duration * pixelsPerSecond), 1),
            height: trackHeight - 12
        )
    }

    private var marqueeStartRegion: CGRect {
        let timelineStartX = labelWidth + contentPadding
        return TimelineMarqueeGeometry.startRegion(
            in: bounds,
            timelineStartX: timelineStartX,
            trackStartY: trackStartY
        )
    }

    private var marqueeRect: CGRect? {
        guard let marqueeAnchor, let marqueeCurrentPoint else {
            return nil
        }
        let timelineStartX = labelWidth + contentPadding
        let start = CGPoint(
            x: max(marqueeAnchor.x, timelineStartX),
            y: max(marqueeAnchor.y, trackStartY)
        )
        let current = CGPoint(
            x: max(marqueeCurrentPoint.x, timelineStartX),
            y: max(marqueeCurrentPoint.y, trackStartY)
        )
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }

    private func clipsIntersectingMarquee() -> Set<TimelineClip.ID> {
        guard let marqueeRect, marqueeRect.width > 2 || marqueeRect.height > 2 else {
            return []
        }
        var clipIDs: Set<TimelineClip.ID> = []
        for (index, track) in displayTracks.enumerated() {
            let y = trackStartY + CGFloat(index) * (trackHeight + trackGap)
            for clip in track.clips where clipRect(clip, trackY: y).intersects(marqueeRect) {
                clipIDs.insert(clip.id)
            }
        }
        return clipIDs
    }

    private func drawMarqueeSelection() {
        guard let marqueeRect, marqueeRect.width > 2 || marqueeRect.height > 2 else {
            return
        }
        NSColor.timelineDropTargetBorder.withAlphaComponent(0.14).setFill()
        marqueeRect.fill()

        NSColor.timelineDropTargetBorder.withAlphaComponent(0.9).setStroke()
        let path = NSBezierPath(rect: marqueeRect.insetBy(dx: 0.5, dy: 0.5))
        path.setLineDash([5, 3], count: 2, phase: 0)
        path.lineWidth = 1
        path.stroke()
    }

    private func trackName(atY y: CGFloat) -> String? {
        for (index, track) in displayTracks.enumerated() {
            let trackY = trackStartY + CGFloat(index) * (trackHeight + trackGap)
            if y >= trackY && y <= trackY + trackHeight {
                return track.name
            }
        }
        return displayTracks.last?.name
    }

    private func updateDropTarget(_ sender: NSDraggingInfo) {
        let point = convert(sender.draggingLocation, from: nil)
        mediaDropTargetTrackName = trackName(atY: point.y)
    }

    private func scrubPlayheadIfNeeded(at point: CGPoint) -> Bool {
        guard isHoverScrubKeyPressed,
              !isTextInputFocused,
              hasTimelineContent,
              draggingClipID == nil,
              !isMediaDragActive,
              timelineTimeAreaContains(point) else {
            return false
        }

        hoverPoint = nil
        onHoverChange?(nil)
        let scrubTime = time(atX: point.x)
        guard abs(scrubTime - playhead) >= minimumScrubTimeDelta else {
            return true
        }
        project?.clearMediaPoolPreview()
        playhead = scrubTime
        project?.seekPlayheadFromTimeline(scrubTime)
        needsDisplay = true
        return true
    }

    private var isHoverScrubKeyPressed: Bool {
        CGEventSource.keyState(.combinedSessionState, key: hoverScrubKeyCode)
    }

    private func timelineTimeAreaContains(_ point: CGPoint) -> Bool {
        let timelineStartX = labelWidth + contentPadding
        return point.x >= timelineStartX
            && point.x <= bounds.maxX
            && point.y >= 0
            && point.y <= bounds.maxY
    }

    private var isTextInputFocused: Bool {
        EditorEscapeKey.isTextInput(window?.firstResponder)
    }

    private var isMouseOverTimeline: Bool {
        guard let window else {
            return false
        }
        let pointInWindow = window.mouseLocationOutsideOfEventStream
        let point = convert(pointInWindow, from: nil)
        return bounds.contains(point)
    }

    private func time(atX x: CGFloat) -> TimeInterval {
        let timelineStartX = labelWidth + contentPadding
        let displayTime = visibleStartTime + Double(x - timelineStartX) / max(pixelsPerSecond, 0.001)
        let clampedDisplayTime = min(max(displayTime, visibleStartTime), visibleEndTime)
        let timeline = TimelineModel(tracks: tracks, zoom: .fit, playhead: playhead, fitStartTime: fitStartTime)
        return timeline.projectTime(forDisplayTime: clampedDisplayTime, activityDuration: activityDuration, collapsed: isCollapsed)
    }

    private func resolvePixelsPerSecond(zoom: TimelineZoom, viewportWidth: CGFloat) -> Double {
        switch zoom {
        case .fit:
            let fittedWidth = max(Double(viewportWidth - labelWidth - contentPadding * 2), 480)
            return fittedWidth / max(visibleEndTime - visibleStartTime, 1)
        case .pixelsPerSecond(let value):
            return value
        }
    }

    func x(forProjectTime time: TimeInterval) -> CGFloat {
        let timeline = TimelineModel(tracks: tracks, zoom: .fit, playhead: playhead, fitStartTime: fitStartTime)
        let displayTime = timeline.displayTime(forProjectTime: time, activityDuration: activityDuration, collapsed: isCollapsed)
        return labelWidth + contentPadding + CGFloat((displayTime - visibleStartTime) * pixelsPerSecond)
    }

    private func fitTrackRect() -> CGRect {
        fitTrackRects().first ?? CGRect(x: x(forProjectTime: fitStartTime), y: rulerHeight + 8, width: 54, height: fitTrackHeight - 16)
    }

    private func fitTrackRects() -> [CGRect] {
        let y = rulerHeight
        if isCollapsed {
            let timeline = TimelineModel(tracks: tracks, zoom: .fit, playhead: playhead, fitStartTime: fitStartTime)
            let segments = timeline.collapsedDisplaySegments()
            if !segments.isEmpty {
                let fitEndTime = fitStartTime + max(activityDuration, 0)
                return segments.compactMap { segment in
                    let start = max(segment.projectStartTime, fitStartTime)
                    let end = min(segment.projectEndTime, fitEndTime)
                    guard end > start else {
                        return nil
                    }

                    let displayStart = segment.displayStartTime + start - segment.projectStartTime
                    let displayEnd = segment.displayStartTime + end - segment.projectStartTime
                    let startX = labelWidth + contentPadding + CGFloat((displayStart - visibleStartTime) * pixelsPerSecond)
                    let width = CGFloat(max(displayEnd - displayStart, 0) * pixelsPerSecond)
                    return CGRect(x: startX, y: y + 8, width: max(width, 2), height: fitTrackHeight - 16)
                }
            }
        }

        let startX = x(forProjectTime: fitStartTime)
        let endX = x(forProjectTime: fitStartTime + max(activityDuration, 0))
        return [CGRect(x: startX, y: y + 8, width: max(endX - startX, 54), height: fitTrackHeight - 16)]
    }

    private func activitySegmentRects(_ segment: ActivityAnnotatedSegment) -> [CGRect] {
        let projectStart = fitStartTime + segment.startElapsedTime
        let projectEnd = fitStartTime + segment.endElapsedTime
        let y = rulerHeight + 8
        let height = fitTrackHeight - 16

        if isCollapsed {
            let timeline = TimelineModel(tracks: tracks, zoom: .fit, playhead: playhead, fitStartTime: fitStartTime)
            return timeline.collapsedDisplaySegments().compactMap { displaySegment in
                let start = max(projectStart, displaySegment.projectStartTime)
                let end = min(projectEnd, displaySegment.projectEndTime)
                guard end > start else {
                    return nil
                }
                let displayStart = displaySegment.displayStartTime + start - displaySegment.projectStartTime
                let displayEnd = displaySegment.displayStartTime + end - displaySegment.projectStartTime
                let x = labelWidth + contentPadding + CGFloat((displayStart - visibleStartTime) * pixelsPerSecond)
                let width = CGFloat((displayEnd - displayStart) * pixelsPerSecond)
                return CGRect(x: x, y: y, width: max(width, 2), height: height)
            }
        }

        let startX = x(forProjectTime: projectStart)
        let endX = x(forProjectTime: projectEnd)
        return [CGRect(x: startX, y: y, width: max(endX - startX, 2), height: height)]
    }

    private func lapRects(_ lap: LapRecord) -> [CGRect] {
        let projectStart = fitStartTime + max(lap.startElapsedTime, 0)
        let projectEnd = fitStartTime + min(lap.endElapsedTime, activityDuration)
        let y = rulerHeight + 8
        let height = fitTrackHeight - 16
        guard projectEnd > projectStart else {
            return []
        }

        if isCollapsed {
            let timeline = TimelineModel(tracks: tracks, zoom: .fit, playhead: playhead, fitStartTime: fitStartTime)
            return timeline.collapsedDisplaySegments().compactMap { displaySegment in
                let start = max(projectStart, displaySegment.projectStartTime)
                let end = min(projectEnd, displaySegment.projectEndTime)
                guard end > start else {
                    return nil
                }
                let displayStart = displaySegment.displayStartTime + start - displaySegment.projectStartTime
                let displayEnd = displaySegment.displayStartTime + end - displaySegment.projectStartTime
                let x = labelWidth + contentPadding + CGFloat((displayStart - visibleStartTime) * pixelsPerSecond)
                let width = CGFloat((displayEnd - displayStart) * pixelsPerSecond)
                return CGRect(x: x, y: y, width: max(width, 2), height: height)
            }
        }

        let startX = x(forProjectTime: projectStart)
        let endX = x(forProjectTime: projectEnd)
        return [CGRect(x: startX, y: y, width: max(endX - startX, 2), height: height)]
    }

    private func activitySegmentHit(at point: CGPoint) -> ActivityAnnotatedSegment? {
        guard activityDuration > 0, point.y >= rulerHeight, point.y <= rulerHeight + fitTrackHeight else {
            return nil
        }
        return activitySegments.first { segment in
            activitySegmentRects(segment).contains { $0.contains(point) }
        }
    }

    private func lapHit(at point: CGPoint) -> LapRecord? {
        guard showsStructuredWorkout,
              activityDuration > 0,
              point.y >= rulerHeight,
              point.y <= rulerHeight + fitTrackHeight else {
            return nil
        }
        return activityLaps.first { lap in
            lapRects(lap).contains { $0.contains(point) }
        }
    }

    private func lapKindColor(_ kind: LapKind) -> NSColor {
        let palette = IntervalKindColorPreferences.currentSnapshot()
        if let color = palette.color(for: kind) {
            return NSColor(
                srgbRed: CGFloat(color.red),
                green: CGFloat(color.green),
                blue: CGFloat(color.blue),
                alpha: CGFloat(color.alpha)
            )
        }
        return .timelineFitGreen
    }

    private func lapKindTitle(_ kind: LapKind) -> String {
        switch kind {
        case .warmup:
            "Warm Up"
        case .active:
            "Run"
        case .rest:
            "Rest"
        case .cooldown:
            "Cool Down"
        case .unknown:
            "Lap"
        }
    }

    private func activitySegmentColor(_ segment: ActivityAnnotatedSegment) -> NSColor {
        switch segment.kind {
        case .timerPaused:
            .timelineFitPausedGray
        }
    }

    private func roundedPath(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    }

    private func roundedPath(_ rect: CGRect, radius: CGFloat, corners: RectCorners) -> NSBezierPath {
        let radius = min(radius, rect.width / 2, rect.height / 2)
        let path = NSBezierPath()

        if corners.contains(.topLeft) {
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        }

        if corners.contains(.topRight) {
            path.line(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.curve(
                to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                controlPoint1: CGPoint(x: rect.maxX - radius * 0.45, y: rect.minY),
                controlPoint2: CGPoint(x: rect.maxX, y: rect.minY + radius * 0.45)
            )
        } else {
            path.line(to: CGPoint(x: rect.maxX, y: rect.minY))
        }

        if corners.contains(.bottomRight) {
            path.line(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.curve(
                to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                controlPoint1: CGPoint(x: rect.maxX, y: rect.maxY - radius * 0.45),
                controlPoint2: CGPoint(x: rect.maxX - radius * 0.45, y: rect.maxY)
            )
        } else {
            path.line(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }

        if corners.contains(.bottomLeft) {
            path.line(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.curve(
                to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                controlPoint1: CGPoint(x: rect.minX + radius * 0.45, y: rect.maxY),
                controlPoint2: CGPoint(x: rect.minX, y: rect.maxY - radius * 0.45)
            )
        } else {
            path.line(to: CGPoint(x: rect.minX, y: rect.maxY))
        }

        if corners.contains(.topLeft) {
            path.line(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.curve(
                to: CGPoint(x: rect.minX + radius, y: rect.minY),
                controlPoint1: CGPoint(x: rect.minX, y: rect.minY + radius * 0.45),
                controlPoint2: CGPoint(x: rect.minX + radius * 0.45, y: rect.minY)
            )
        } else {
            path.line(to: CGPoint(x: rect.minX, y: rect.minY))
        }

        path.close()
        return path
    }

    private func drawText(_ text: String, at point: CGPoint, color: NSColor, font: NSFont) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        (text as NSString).draw(at: point, withAttributes: attributes)
    }

    private func drawText(_ text: String, in rect: CGRect, color: NSColor, font: NSFont, lineBreakMode: NSLineBreakMode) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = lineBreakMode
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }

    private func formatDuration(_ elapsed: TimeInterval) -> String {
        let totalSeconds = Int(abs(elapsed).rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatSignedDuration(_ elapsed: TimeInterval) -> String {
        let prefix = elapsed < 0 ? "-" : ""
        return prefix + formatDuration(elapsed)
    }
}

/// Accessibility element whose frame follows a rect in the timeline canvas.
private class TimelineAccessibilityElement: NSAccessibilityElement {
    private weak var canvas: NSView?
    private let rect: CGRect

    init(canvas: NSView, rect: CGRect) {
        self.canvas = canvas
        self.rect = rect
        super.init()
    }

    override func accessibilityFrame() -> NSRect {
        guard let canvas else { return .zero }
        return NSAccessibility.screenRect(fromView: canvas, rect: rect)
    }
}

/// A clip: pressing it selects the clip.
private final class TimelineClipAccessibilityElement: TimelineAccessibilityElement {
    var isSelectedClip = false
    var onPress: (() -> Void)?

    override func isAccessibilitySelected() -> Bool {
        isSelectedClip
    }

    override func setAccessibilitySelected(_ selected: Bool) {
        if selected { onPress?() }
    }

    override func accessibilityPerformPress() -> Bool {
        onPress?()
        return onPress != nil
    }
}

/// The playhead: increment and decrement step one frame.
private final class TimelinePlayheadAccessibilityElement: TimelineAccessibilityElement {
    var step: ((Int) -> Void)?

    override func accessibilityPerformIncrement() -> Bool {
        step?(1)
        return step != nil
    }

    override func accessibilityPerformDecrement() -> Bool {
        step?(-1)
        return step != nil
    }
}
