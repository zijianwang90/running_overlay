import AppKit
import SwiftUI

enum PreviewFitMode: Hashable {
    case fit
    case fill

    var label: String {
        switch self {
        case .fit: return "Fit"
        case .fill: return "Fill"
        }
    }
}

struct PreviewCanvasView: View {
    @EnvironmentObject private var project: ProjectDocument
    // Start position captured once per drag gesture; cumulative translation applied each frame.
    @State private var dragStartPositions: [OverlayElement.ID: CGPoint] = [:]
    // Live position during drag — local state only, not written to document until drag ends.
    @State private var liveDragPosition: (id: OverlayElement.ID, pos: CGPoint)?
    @State private var dragGrabOffsets: [OverlayElement.ID: CGSize] = [:]
    @State private var overlayFrames: [OverlayElement.ID: CGRect] = [:]
    @State private var activeSnapLines: [PreviewSnapLine] = []

    var body: some View {
        GeometryReader { proxy in
            let canvasAvailableSize = CGSize(
                width: proxy.size.width,
                height: max(proxy.size.height - PreviewLayout.headerHeight - PreviewLayout.playbackHeight, 0)
            )
            let canvasSize = fittedCanvasSize(in: canvasAvailableSize)
            VStack(spacing: 0) {
                PreviewHeader()

                ZStack {
                    ZStack {
                        Rectangle()
                            .fill(project.previewCanvasBackground)

                        if let previewMedia = project.activePreviewMedia() {
                            VideoPreviewPlayerView(
                                previewMedia: previewMedia,
                                isPlaying: project.isPlaying,
                                playbackRate: project.playbackRate,
                                fitMode: project.previewFitMode
                            ) { activityTime in
                                if project.isPreviewingMediaPoolItem {
                                    project.setMediaPoolPreviewSourceTime(activityTime)
                                } else {
                                    project.setPlayheadFromPlayback(activityTime)
                                }
                            }
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "film")
                                    .font(.system(size: 54))
                                    .foregroundStyle(EditorTheme.textMuted.opacity(0.6))
                                Text(project.mediaItems.isEmpty ? "" : "No video at playhead")
                                    .font(EditorTheme.sectionTitleFont)
                                    .foregroundStyle(EditorTheme.textSecondary)
                            }
                        }

                        if project.showPreviewGuides {
                            PreviewSafetyGuidesView()
                                .allowsHitTesting(false)

                            PreviewGuidesHUD()
                                .allowsHitTesting(false)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }

                        PreviewSnapLinesView(lines: activeSnapLines)
                            .allowsHitTesting(false)

                        ForEach(project.overlayLayout.elements.filter(\.isVisible)) { element in
                            let isSelected = project.selection == .overlayElement(element.id)
                            // During drag: use local live position to avoid @Published mutation every frame.
                            let displayPos: CGPoint = liveDragPosition?.id == element.id
                                ? liveDragPosition!.pos
                                : element.position
                            OverlayElementContent(
                                element: element,
                                canvasSize: canvasSize,
                                sampleTime: project.layerDataSampleTime,
                                activity: project.activity,
                                isSelected: isSelected
                            )  // .equatable() skips body for unchanged elements (e.g., non-dragged)
                            .equatable()
                            .background(
                                GeometryReader { elementProxy in
                                    Color.clear.preference(
                                        key: PreviewOverlayFramePreferenceKey.self,
                                        value: [element.id: elementProxy.frame(in: .named(PreviewCanvasCoordinateSpace.name))]
                                    )
                                }
                            )
                            // `position` expands its layout container to the canvas proposal. Define
                            // the hit shape first so taps and drags remain limited to rendered content.
                            .contentShape(Rectangle())
                            .modifier(PreviewOverlayPositionModifier(
                                element: element,
                                canvasSize: canvasSize,
                                position: displayPos,
                                sampleTime: project.layerDataSampleTime,
                                activity: project.activity
                            ))
                            .gesture(
                                DragGesture(minimumDistance: 2, coordinateSpace: .named(PreviewCanvasCoordinateSpace.name))
                                    .onChanged { value in
                                        guard !element.isLocked else { return }
                                        // Capture start position and select exactly once per gesture.
                                        if dragStartPositions[element.id] == nil {
                                            dragStartPositions[element.id] = element.position
                                            if element.type.isNumericOverlay,
                                               let frame = overlayFrames[element.id] {
                                                dragGrabOffsets[element.id] = CGSize(
                                                    width: value.startLocation.x - frame.minX,
                                                    height: value.startLocation.y - frame.minY
                                                )
                                            }
                                            project.selectOverlay(element.id)
                                        }
                                        guard let start = dragStartPositions[element.id] else { return }
                                        let proposedPosition: CGPoint
                                        if element.type.isNumericOverlay,
                                           let grabOffset = dragGrabOffsets[element.id] {
                                            proposedPosition = CGPoint(
                                                x: (value.location.x - grabOffset.width) / max(canvasSize.width, 1),
                                                y: (value.location.y - grabOffset.height) / max(canvasSize.height, 1)
                                            )
                                        } else {
                                            proposedPosition = CGPoint(
                                                x: start.x + value.translation.width / max(canvasSize.width, 1),
                                                y: start.y + value.translation.height / max(canvasSize.height, 1)
                                            )
                                        }
                                        let snapResult: PreviewSnapResult
                                        if element.type.isNumericOverlay {
                                            snapResult = PreviewSnapResolver().snapTopLeading(
                                                movingElementID: element.id,
                                                proposedPosition: proposedPosition,
                                                currentFrame: overlayFrames[element.id],
                                                overlayFrames: overlayFrames,
                                                canvasSize: canvasSize,
                                                guidesEnabled: project.showPreviewGuides
                                            )
                                        } else {
                                            snapResult = PreviewSnapResolver().snap(
                                                movingElementID: element.id,
                                                proposedPosition: proposedPosition,
                                                currentFrame: overlayFrames[element.id],
                                                overlayFrames: overlayFrames,
                                                canvasSize: canvasSize,
                                                guidesEnabled: project.showPreviewGuides
                                            )
                                        }
                                        liveDragPosition = (element.id, snapResult.position)
                                        activeSnapLines = snapResult.lines
                                    }
                                    .onEnded { _ in
                                        // Commit final position to document once (single @Published update).
                                        if let live = liveDragPosition, live.id == element.id {
                                            project.moveOverlay(element.id, to: live.pos)
                                        }
                                        liveDragPosition = nil
                                        dragStartPositions[element.id] = nil
                                        dragGrabOffsets[element.id] = nil
                                        activeSnapLines = []
                                        project.finishContinuousEdit()
                                    }
                            )
                            .onTapGesture {
                                guard !element.isLocked else { return }
                                project.selectOverlay(element.id)
                            }
                            .contextMenu {
                                Button {
                                    project.copyOverlayProperties(from: element.id)
                                } label: {
                                    Label("Copy Properties", systemImage: "doc.on.doc")
                                }
                                Button {
                                    project.pasteOverlayProperties(to: element.id)
                                } label: {
                                    Label("Paste Properties", systemImage: "doc.on.clipboard")
                                }
                                .disabled(!project.canPasteOverlayProperties(to: element.id))
                            }
                        }
                    }
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .coordinateSpace(name: PreviewCanvasCoordinateSpace.name)
                    .onPreferenceChange(PreviewOverlayFramePreferenceKey.self) { frames in
                        overlayFrames = frames
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        SpatialTapGesture(coordinateSpace: .named(PreviewCanvasCoordinateSpace.name))
                            .onEnded { value in
                                handleCanvasTap(at: value.location)
                            }
                    )
                }
                .frame(width: proxy.size.width, height: canvasAvailableSize.height)

                PreviewPlaybackControls()
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(EditorTheme.appChrome)
        }
    }

    private func fittedCanvasSize(in availableSize: CGSize) -> CGSize {
        let aspectRatio = project.settings.resolution.widthRatio
        guard availableSize.width > 0, availableSize.height > 0, aspectRatio > 0 else {
            return .zero
        }

        let heightFromWidth = availableSize.width / aspectRatio
        if heightFromWidth <= availableSize.height {
            return CGSize(width: availableSize.width, height: heightFromWidth)
        }

        return CGSize(width: availableSize.height * aspectRatio, height: availableSize.height)
    }

    private func handleCanvasTap(at location: CGPoint) {
        let visibleElementIDs = Set(project.overlayLayout.elements.filter(\.isVisible).map(\.id))
        if !visibleElementIDs.isEmpty && overlayFrames.isEmpty {
            return
        }

        let hitPadding: CGFloat = 4
        let didHitOverlay = overlayFrames.contains { id, frame in
            visibleElementIDs.contains(id) && frame.insetBy(dx: -hitPadding, dy: -hitPadding).contains(location)
        }

        guard !didHitOverlay else { return }
        project.clearMediaPoolPreview()
        project.clearSelection()
    }

}

private enum PreviewLayout {
    static let headerHeight: CGFloat = EditorTheme.panelHeaderHeight
    static let playbackHeight: CGFloat = EditorTheme.previewPlaybackHeight
    static let headerButtonSize: CGFloat = EditorTheme.iconButtonSize
}

private enum PreviewCanvasCoordinateSpace {
    static let name = "PreviewCanvasCoordinateSpace"
}

private extension View {
    func overlayForegroundEffects(element: OverlayElement, shadowRadius: Double? = nil) -> some View {
        self
            .overlayForegroundGlow(element: element)
            .overlayLayeredShadow(
                color: Color(element.style.shadowColor),
                isEnabled: element.style.shadowEnabled,
                opacity: element.style.shadowOpacity,
                radius: shadowRadius ?? element.style.shadowRadius,
                x: element.style.shadowOffsetX,
                y: element.style.shadowOffsetY,
                thickness: element.style.shadowThickness
            )
    }

    func overlayForegroundGlow(element: OverlayElement) -> some View {
        self
            .shadow(
                color: Color(element.style.glowColor).opacity(element.style.glowEnabled ? element.style.glowIntensity * 0.72 : 0),
                radius: element.style.glowEnabled ? max(element.style.glowIntensity * 18, 0) : 0
            )
            .shadow(
                color: Color(element.style.glowColor).opacity(element.style.glowEnabled ? element.style.glowIntensity * 0.35 : 0),
                radius: element.style.glowEnabled ? max(element.style.glowIntensity * 34, 0) : 0
            )
    }

    func overlayLayeredShadow(
        color: Color,
        isEnabled: Bool,
        opacity: Double,
        radius: Double,
        x: Double,
        y: Double,
        thickness: Double
    ) -> some View {
        self
            .shadow(color: color.opacity(isEnabled ? opacity : 0), radius: radius, x: x, y: y)
            .shadow(color: color.opacity(isEnabled ? opacity * max(thickness - 1, 0) * 0.32 : 0), radius: radius * 0.72, x: x, y: y)
            .shadow(color: color.opacity(isEnabled ? opacity * max(thickness - 2, 0) * 0.22 : 0), radius: radius * 0.48, x: x, y: y)
    }

    func overlayGenericBorder(element: OverlayElement, cornerRadius: Double) -> some View {
        self.overlay {
            if element.style.borderEnabled {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color(element.style.borderColor).opacity(element.style.borderOpacity), lineWidth: element.style.borderWidth)
            }
        }
    }
}

private struct PreviewOverlayFramePreferenceKey: PreferenceKey {
    static let defaultValue: [OverlayElement.ID: CGRect] = [:]

    static func reduce(value: inout [OverlayElement.ID: CGRect], nextValue: () -> [OverlayElement.ID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct PreviewSnapLine: Identifiable, Equatable {
    enum Axis: Equatable {
        case horizontal
        case vertical
    }

    let axis: Axis
    let position: CGFloat

    var id: String {
        "\(axis)-\(Int(position.rounded()))"
    }
}

private struct PreviewSnapResult {
    var position: CGPoint
    var lines: [PreviewSnapLine]
}

private struct PreviewSnapResolver {
    private let threshold: CGFloat = 6

    func snap(
        movingElementID: OverlayElement.ID,
        proposedPosition: CGPoint,
        currentFrame: CGRect?,
        overlayFrames: [OverlayElement.ID: CGRect],
        canvasSize: CGSize,
        guidesEnabled: Bool
    ) -> PreviewSnapResult {
        guard canvasSize.width > 0, canvasSize.height > 0, let currentFrame, !currentFrame.isEmpty else {
            return PreviewSnapResult(position: clampNormalized(proposedPosition), lines: [])
        }

        let proposedCenter = CGPoint(
            x: proposedPosition.x * canvasSize.width,
            y: proposedPosition.y * canvasSize.height
        )
        let proposedFrame = CGRect(
            x: proposedCenter.x - currentFrame.width / 2,
            y: proposedCenter.y - currentFrame.height / 2,
            width: currentFrame.width,
            height: currentFrame.height
        )

        var snappedCenter = proposedCenter
        var lines: [PreviewSnapLine] = []

        if let match = bestMatch(
            movingAnchors: xAnchors(for: proposedFrame),
            targets: xTargets(
                movingElementID: movingElementID,
                overlayFrames: overlayFrames,
                canvasSize: canvasSize,
                guidesEnabled: guidesEnabled
            )
        ) {
            snappedCenter.x += match.delta
            lines.append(PreviewSnapLine(axis: .vertical, position: match.targetPosition))
        }

        if let match = bestMatch(
            movingAnchors: yAnchors(for: proposedFrame),
            targets: yTargets(
                movingElementID: movingElementID,
                overlayFrames: overlayFrames,
                canvasSize: canvasSize,
                guidesEnabled: guidesEnabled
            )
        ) {
            snappedCenter.y += match.delta
            lines.append(PreviewSnapLine(axis: .horizontal, position: match.targetPosition))
        }

        let clampedCenter = clampCenter(snappedCenter, frameSize: currentFrame.size, canvasSize: canvasSize)
        return PreviewSnapResult(
            position: CGPoint(
                x: clampedCenter.x / canvasSize.width,
                y: clampedCenter.y / canvasSize.height
            ),
            lines: lines
        )
    }

    func snapTopLeading(
        movingElementID: OverlayElement.ID,
        proposedPosition: CGPoint,
        currentFrame: CGRect?,
        overlayFrames: [OverlayElement.ID: CGRect],
        canvasSize: CGSize,
        guidesEnabled: Bool
    ) -> PreviewSnapResult {
        guard canvasSize.width > 0, canvasSize.height > 0, let currentFrame, !currentFrame.isEmpty else {
            return PreviewSnapResult(position: clampNormalized(proposedPosition), lines: [])
        }

        var proposedFrame = CGRect(
            x: proposedPosition.x * canvasSize.width,
            y: proposedPosition.y * canvasSize.height,
            width: currentFrame.width,
            height: currentFrame.height
        )
        var lines: [PreviewSnapLine] = []

        if let match = bestMatch(
            movingAnchors: xAnchors(for: proposedFrame),
            targets: xTargets(
                movingElementID: movingElementID,
                overlayFrames: overlayFrames,
                canvasSize: canvasSize,
                guidesEnabled: guidesEnabled
            )
        ) {
            proposedFrame.origin.x += match.delta
            lines.append(PreviewSnapLine(axis: .vertical, position: match.targetPosition))
        }

        if let match = bestMatch(
            movingAnchors: yAnchors(for: proposedFrame),
            targets: yTargets(
                movingElementID: movingElementID,
                overlayFrames: overlayFrames,
                canvasSize: canvasSize,
                guidesEnabled: guidesEnabled
            )
        ) {
            proposedFrame.origin.y += match.delta
            lines.append(PreviewSnapLine(axis: .horizontal, position: match.targetPosition))
        }

        let clampedOrigin = clampOrigin(proposedFrame.origin, frameSize: currentFrame.size, canvasSize: canvasSize)
        return PreviewSnapResult(
            position: CGPoint(
                x: clampedOrigin.x / canvasSize.width,
                y: clampedOrigin.y / canvasSize.height
            ),
            lines: lines
        )
    }

    private struct Anchor {
        let position: CGFloat
    }

    private struct Target {
        let position: CGFloat
        let priority: Int
    }

    private struct Match {
        let delta: CGFloat
        let targetPosition: CGFloat
        let distance: CGFloat
        let priority: Int
    }

    private func bestMatch(movingAnchors: [Anchor], targets: [Target]) -> Match? {
        var best: Match?
        for anchor in movingAnchors {
            for target in targets {
                let delta = target.position - anchor.position
                let distance = abs(delta)
                guard distance <= threshold else { continue }
                let match = Match(delta: delta, targetPosition: target.position, distance: distance, priority: target.priority)
                if let current = best {
                    if match.distance < current.distance || (match.distance == current.distance && match.priority < current.priority) {
                        best = match
                    }
                } else {
                    best = match
                }
            }
        }
        return best
    }

    private func xAnchors(for frame: CGRect) -> [Anchor] {
        [
            Anchor(position: frame.minX),
            Anchor(position: frame.midX),
            Anchor(position: frame.maxX)
        ]
    }

    private func yAnchors(for frame: CGRect) -> [Anchor] {
        [
            Anchor(position: frame.minY),
            Anchor(position: frame.midY),
            Anchor(position: frame.maxY)
        ]
    }

    private func xTargets(
        movingElementID: OverlayElement.ID,
        overlayFrames: [OverlayElement.ID: CGRect],
        canvasSize: CGSize,
        guidesEnabled: Bool
    ) -> [Target] {
        var targets: [Target] = []
        if guidesEnabled {
            targets.append(Target(position: canvasSize.width / 2, priority: 0))
            targets.append(contentsOf: previewGuideXPositions(canvasWidth: canvasSize.width).map { Target(position: $0, priority: 1) })
        }
        targets.append(contentsOf: overlayFrames.compactMap { id, frame in
            id == movingElementID ? nil : [
                Target(position: frame.minX, priority: 2),
                Target(position: frame.midX, priority: 2),
                Target(position: frame.maxX, priority: 2)
            ]
        }.flatMap { $0 })
        return targets
    }

    private func yTargets(
        movingElementID: OverlayElement.ID,
        overlayFrames: [OverlayElement.ID: CGRect],
        canvasSize: CGSize,
        guidesEnabled: Bool
    ) -> [Target] {
        var targets: [Target] = []
        if guidesEnabled {
            targets.append(Target(position: canvasSize.height / 2, priority: 0))
            targets.append(contentsOf: previewGuideYPositions(canvasHeight: canvasSize.height).map { Target(position: $0, priority: 1) })
        }
        targets.append(contentsOf: overlayFrames.compactMap { id, frame in
            id == movingElementID ? nil : [
                Target(position: frame.minY, priority: 2),
                Target(position: frame.midY, priority: 2),
                Target(position: frame.maxY, priority: 2)
            ]
        }.flatMap { $0 })
        return targets
    }

    private func previewGuideXPositions(canvasWidth: CGFloat) -> [CGFloat] {
        [
            canvasWidth * 0.05,
            canvasWidth * 0.10,
            canvasWidth * 0.90,
            canvasWidth * 0.95
        ]
    }

    private func previewGuideYPositions(canvasHeight: CGFloat) -> [CGFloat] {
        [
            canvasHeight * 0.05,
            canvasHeight * 0.10,
            canvasHeight * 0.90,
            canvasHeight * 0.95
        ]
    }

    private func clampNormalized(_ position: CGPoint) -> CGPoint {
        CGPoint(x: min(max(position.x, 0), 1), y: min(max(position.y, 0), 1))
    }

    private func clampCenter(_ center: CGPoint, frameSize: CGSize, canvasSize: CGSize) -> CGPoint {
        let minX = min(frameSize.width / 2, canvasSize.width / 2)
        let maxX = max(canvasSize.width - frameSize.width / 2, canvasSize.width / 2)
        let minY = min(frameSize.height / 2, canvasSize.height / 2)
        let maxY = max(canvasSize.height - frameSize.height / 2, canvasSize.height / 2)
        return CGPoint(
            x: min(max(center.x, minX), maxX),
            y: min(max(center.y, minY), maxY)
        )
    }

    private func clampOrigin(_ origin: CGPoint, frameSize: CGSize, canvasSize: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(origin.x, 0), max(0, canvasSize.width - frameSize.width)),
            y: min(max(origin.y, 0), max(0, canvasSize.height - frameSize.height))
        )
    }
}

private struct PreviewSnapLinesView: View {
    let lines: [PreviewSnapLine]

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                for line in lines {
                    switch line.axis {
                    case .vertical:
                        path.move(to: CGPoint(x: line.position, y: 0))
                        path.addLine(to: CGPoint(x: line.position, y: proxy.size.height))
                    case .horizontal:
                        path.move(to: CGPoint(x: 0, y: line.position))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: line.position))
                    }
                }
            }
            .stroke(EditorTheme.accentBlue.opacity(0.72), style: StrokeStyle(lineWidth: 1.4, dash: [5, 4]))
        }
    }
}

private struct PreviewHeader: View {
    @EnvironmentObject private var project: ProjectDocument

    var body: some View {
        EditorPanelHeader(title: "Preview") {
            Text(metadata)
                .font(EditorTheme.captionFont)
                .foregroundStyle(EditorTheme.textMuted)
                .lineLimit(1)

            Button {
                project.showPreviewGuides.toggle()
            } label: {
                Image(systemName: "viewfinder")
            }
            .buttonStyle(PreviewIconButtonStyle(isActive: project.showPreviewGuides))
            .help("Show Safe Frames")
            .accessibilityLabel("Show Safe Frames")

            ColorPicker(
                "Canvas Background",
                selection: $project.previewCanvasBackground,
                supportsOpacity: false
            )
            .labelsHidden()
            .frame(height: PreviewLayout.headerButtonSize)
            .help("Canvas Background Color")
            .accessibilityLabel("Canvas Background Color")

            Menu {
                ForEach([PreviewFitMode.fit, .fill], id: \.self) { mode in
                    Button {
                        project.previewFitMode = mode
                    } label: {
                        if project.previewFitMode == mode {
                            Label(mode.label, systemImage: "checkmark")
                        } else {
                            Text(mode.label)
                        }
                    }
                }
            } label: {
                HStack(spacing: EditorTheme.space1) {
                    Text(project.previewFitMode.label)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .font(EditorTheme.bodyStrongFont)
                .foregroundStyle(EditorTheme.textSecondary)
                .frame(height: PreviewLayout.headerButtonSize)
                .padding(.horizontal, EditorTheme.space2)
                .background(EditorTheme.surfaceControl)
                .clipShape(RoundedRectangle(cornerRadius: EditorTheme.controlRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: EditorTheme.controlRadius)
                        .stroke(EditorTheme.borderSubtle, lineWidth: 1)
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Preview Zoom")
            .accessibilityLabel("Preview Zoom")
        }
    }

    private var metadata: String {
        let resolution = project.settings.resolution
        let fps = project.settings.frameRate.value
        let fpsText = fps.rounded() == fps ? "\(Int(fps)) fps" : "\(fps.formatted(.number.precision(.fractionLength(2)))) fps"
        return "\(resolution.width) x \(resolution.height) • \(fpsText)"
    }
}

private struct PreviewGuidesHUD: View {
    var body: some View {
        Text("Guides On")
            .font(EditorTheme.captionFont)
            .foregroundStyle(EditorTheme.accentBlue)
            .padding(.horizontal, EditorTheme.space2)
            .padding(.vertical, EditorTheme.space1)
            .background(EditorTheme.accentBlueSoft.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: EditorTheme.controlRadius))
            .padding(EditorTheme.space3)
    }
}

// Equatable wrapper so SwiftUI can skip body re-execution for elements whose
// inputs haven't changed (e.g., all non-dragged elements during a drag gesture).
// activity is excluded from == because comparing large FIT sample arrays is expensive;
// sampleTime serves as a proxy — the same elapsed time always yields the same layout.
private struct OverlayElementContent: View, @preconcurrency Equatable {
    let element: OverlayElement
    let canvasSize: CGSize
    let sampleTime: Double
    let activity: ActivityTimeline
    let isSelected: Bool

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.element == rhs.element
            && lhs.canvasSize == rhs.canvasSize
            && lhs.sampleTime == rhs.sampleTime
            && lhs.isSelected == rhs.isSelected
    }

    var body: some View {
        let renderContext = OverlayRenderContext(
            canvasSize: canvasSize,
            activity: activity,
            elapsedTime: sampleTime
        )
        Group {
            switch element.type {
            case .distanceTimeline:
                OverlaySharedDistanceTimelineView(
                    element: element,
                    layout: OverlayRenderModel.distanceTimelineLayout(for: element, in: renderContext),
                    isInteractive: isSelected
                )
            case .elevationChart:
                OverlaySharedElevationChartView(
                    element: element,
                    layout: OverlayRenderModel.elevationChartLayout(for: element, in: renderContext)
                )
            case .runningGauge:
                OverlaySharedRunningGaugeView(
                    element: element,
                    layout: OverlayRenderModel.runningGaugeLayout(for: element, in: renderContext),
                    isInteractive: isSelected
                )
            case .intervalHUDBar:
                OverlaySharedIntervalHUDBarView(
                    element: element,
                    layout: OverlayRenderModel.intervalHUDBarLayout(for: element, in: renderContext)
                )
            case .intervalTimeline:
                OverlaySharedIntervalTimelineView(
                    element: element,
                    layout: OverlayRenderModel.intervalTimelineLayout(for: element, in: renderContext)
                )
            case .zoneEdgeBar:
                OverlaySharedZoneEdgeBarView(
                    element: element,
                    layout: OverlayRenderModel.zoneEdgeBarLayout(for: element, in: renderContext)
                )
            case .routeMap:
                OverlaySharedRouteMapView(
                    element: element,
                    layout: OverlayRenderModel.routeMapLayout(for: element, in: renderContext),
                    isInteractive: isSelected
                )
            case .decorSolidColor:
                OverlaySharedDecorSolidColorView(
                    element: element,
                    layout: OverlayRenderModel.decorSolidColorLayout(for: element, in: renderContext)
                )
            case .decorIcon:
                OverlaySharedDecorIconView(
                    element: element,
                    layout: OverlayRenderModel.decorIconLayout(for: element, in: renderContext)
                )
            case .decorText:
                OverlaySharedDecorTextView(
                    element: element,
                    layout: OverlayRenderModel.decorTextLayout(for: element, in: renderContext)
                )
            case .weatherWidget:
                OverlaySharedWeatherWidgetView(
                    element: element,
                    layout: OverlayRenderModel.weatherWidgetLayout(for: element, in: renderContext)
                )
            default:
                OverlaySharedTextPresetView(
                    element: element,
                    layout: OverlayRenderModel.textLayout(for: element, in: renderContext),
                    isInteractive: isSelected
                )
            }
        }
        .opacity(element.opacity)
        .overlay {
            if isSelected, element.type != .distanceTimeline {
                PreviewSelectionAffordance()
            }
        }
    }
}

private struct PreviewSelectionAffordance: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(EditorTheme.accentBlue.opacity(0.92), lineWidth: 1.4)
            .padding(-5)
            .allowsHitTesting(false)
    }
}

private struct PreviewOverlayPositionModifier: ViewModifier {
    let element: OverlayElement
    let canvasSize: CGSize
    let position: CGPoint
    let sampleTime: TimeInterval
    let activity: ActivityTimeline

    func body(content: Content) -> some View {
        if element.type.isNumericOverlay {
            content
                .alignmentGuide(HorizontalAlignment.center) { _ in
                    canvasSize.width * (0.5 - position.x)
                }
                .alignmentGuide(VerticalAlignment.center) { _ in
                    canvasSize.height * (0.5 - position.y)
                }
        } else {
            content
                .position(resolvedPosition)
        }
    }

    private var resolvedPosition: CGPoint {
        guard element.type == .zoneEdgeBar else {
            return CGPoint(
                x: canvasSize.width * position.x,
                y: canvasSize.height * position.y
            )
        }

        var positionedElement = element
        positionedElement.position = position
        let context = OverlayRenderContext(canvasSize: canvasSize, activity: activity, elapsedTime: sampleTime)
        let rect = OverlayRenderModel.zoneEdgeBarLayout(for: positionedElement, in: context).rect
        return CGPoint(x: rect.midX, y: rect.midY)
    }
}

private struct PreviewIconButtonStyle: ButtonStyle {
    var isActive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(isActive ? EditorTheme.accentBlue : EditorTheme.textSecondary)
            .frame(width: PreviewLayout.headerButtonSize, height: PreviewLayout.headerButtonSize)
            .background(background(isPressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: EditorTheme.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: EditorTheme.controlRadius)
                    .stroke(isActive ? EditorTheme.accentBlue.opacity(0.58) : EditorTheme.borderSubtle, lineWidth: 1)
            }
    }

    private func background(isPressed: Bool) -> Color {
        if isPressed {
            return EditorTheme.surfacePressed
        }
        return isActive ? EditorTheme.accentBlueSoft : EditorTheme.surfaceControl
    }
}

private struct SharedStatsBarItemData {
    let value: String
    let unit: String
    let label: String
}

private struct SharedStatsBarContentView: View {
    let items: [SharedStatsBarItemData]
    let stacked: Bool
    let itemSpacing: Double
    let dividerOpacity: Double
    let cornerRadius: Double
    let backgroundOpacity: Double
    let valueFontName: String
    let valueFontWeight: OverlayFontWeight
    let valueColor: Color
    let labelFontName: String
    let labelFontWeight: OverlayFontWeight
    let labelColor: Color
    let valueFontSize: Double
    let labelFontSize: Double

    var body: some View {
        Group {
            if stacked {
                VStack(spacing: itemSpacing) {
                    rows
                }
            } else {
                HStack(spacing: itemSpacing) {
                    rows
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(backgroundOpacity))
        )
        .clipped()
    }

    @ViewBuilder
    private var rows: some View {
        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
            itemView(item)
            if index < items.count - 1 && dividerOpacity > 0 {
                if stacked {
                    Rectangle()
                        .fill(labelColor.opacity(dividerOpacity))
                        .frame(height: 1)
                        .padding(.horizontal, 6)
                } else {
                    Rectangle()
                        .fill(labelColor.opacity(dividerOpacity))
                        .frame(width: 1)
                        .padding(.vertical, 6)
                }
            }
        }
    }

    private func itemView(_ item: SharedStatsBarItemData) -> some View {
        VStack(alignment: .center, spacing: 1) {
            Text(item.value + (item.unit.isEmpty ? "" : " \(item.unit)"))
                .font(.overlayFont(family: valueFontName, size: valueFontSize, weight: Font.Weight(valueFontWeight)))
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(item.label.uppercased())
                .font(.overlayFont(family: labelFontName, size: labelFontSize, weight: Font.Weight(labelFontWeight)))
                .foregroundStyle(labelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct RouteMapOverlayView: View {
    let element: OverlayElement
    let layout: OverlayRouteMapRenderLayout
    let isSelected: Bool
    var staticMapSnapshot: NSImage?
    var showsBaseContent = true
    var showsCurrentMarker = true
    var showsContainerEffects = true
    @State private var mapSnapshot: NSImage?
    @State private var alphaMask: NSImage?

    var body: some View {
        placementContainer
            .task(id: renderIdentity) { await updateRenderAssets() }
    }

    @ViewBuilder
    private var placementContainer: some View {
        if showsBaseContent, let statsBar = layout.statsBarLayout, !statsBar.items.isEmpty {
            if statsBar.isInside {
                switch statsBar.placement {
                case .topAttached, .insideTop:
                    maskedMapView.overlay(alignment: .top) {
                        statsBarContent(statsBar).frame(width: statsBar.rect.width, height: statsBar.rect.height)
                    }
                    .compositingGroup()
                    .mask { shapeFill }
                case .bottomAttached, .insideBottom:
                    maskedMapView.overlay(alignment: .bottom) {
                        statsBarContent(statsBar).frame(width: statsBar.rect.width, height: statsBar.rect.height)
                    }
                    .compositingGroup()
                    .mask { shapeFill }
                case .leftAttached:
                    maskedMapView.overlay(alignment: .leading) {
                        statsBarContent(statsBar).frame(width: statsBar.rect.width, height: statsBar.rect.height)
                    }
                    .compositingGroup()
                    .mask { shapeFill }
                case .rightAttached:
                    maskedMapView.overlay(alignment: .trailing) {
                        statsBarContent(statsBar).frame(width: statsBar.rect.width, height: statsBar.rect.height)
                    }
                    .compositingGroup()
                    .mask { shapeFill }
                }
            } else {
                switch statsBar.placement {
                case .bottomAttached:
                    VStack(spacing: 0) {
                        maskedMapView
                        statsBarContent(statsBar).frame(width: statsBar.rect.width, height: statsBar.rect.height)
                    }
                case .topAttached:
                    VStack(spacing: 0) {
                        statsBarContent(statsBar).frame(width: statsBar.rect.width, height: statsBar.rect.height)
                        maskedMapView
                    }
                case .leftAttached:
                    HStack(spacing: 0) {
                        statsBarContent(statsBar).frame(width: statsBar.rect.width, height: statsBar.rect.height)
                        maskedMapView
                    }
                case .rightAttached:
                    HStack(spacing: 0) {
                        maskedMapView
                        statsBarContent(statsBar).frame(width: statsBar.rect.width, height: statsBar.rect.height)
                    }
                case .insideBottom:
                    maskedMapView.overlay(alignment: .bottom) {
                        statsBarContent(statsBar).frame(width: statsBar.rect.width, height: statsBar.rect.height)
                    }
                case .insideTop:
                    maskedMapView.overlay(alignment: .top) {
                        statsBarContent(statsBar).frame(width: statsBar.rect.width, height: statsBar.rect.height)
                    }
                }
            }
        } else {
            maskedMapView
        }
    }

    private var maskedMapView: some View {
        mapContent
            .frame(width: layout.rect.width, height: layout.rect.height)
            .mask {
                if let alphaMask {
                    Image(nsImage: alphaMask).resizable().scaledToFill().luminanceToAlpha()
                } else {
                    shapeFill
                }
            }
            .overlay {
                if showsContainerEffects && isSelected {
                    shapeStroke(
                        color: Color.accentColor.opacity(0.85),
                        lineWidth: 2
                    )
                } else if showsContainerEffects && element.style.borderEnabled {
                    shapeStroke(
                        color: Color(element.style.borderColor).opacity(element.style.borderOpacity),
                        lineWidth: element.style.borderWidth * element.scale
                    )
                }
            }
            .overlayLayeredShadow(
                color: Color(element.style.shadowColor),
                isEnabled: showsContainerEffects && element.style.shadowEnabled,
                opacity: element.style.shadowOpacity,
                radius: element.style.shadowRadius,
                x: element.style.shadowOffsetX,
                y: element.style.shadowOffsetY,
                thickness: element.style.shadowThickness
            )
    }

    private var mapContent: some View {
        ZStack {
            if showsBaseContent {
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(containerBackground)
                    .overlay {
                        if let resolvedMapSnapshot, layout.provider == .mapKit {
                            Image(nsImage: resolvedMapSnapshot)
                                .resizable()
                                .scaledToFill()
                                .opacity(layout.mapOpacity)
                                .clipped()
                        } else if element.style.routeMapBackgroundStyle != .none {
                            mapGrid
                        }
                    }

                if layout.projectedPoints.isEmpty {
                    Text("NO GPS")
                        .font(.overlayFont(family: element.style.fontName, size: max(layout.rect.width * 0.09, 10), weight: .semibold))
                        .foregroundStyle(Color(element.style.foregroundColor).opacity(0.72))
                } else {
                    routePath(points: relativePoints)
                        .stroke(Color.black.opacity(0.55), style: StrokeStyle(lineWidth: layout.lineWidth + 3, lineCap: .round, lineJoin: .round))

                    if layout.glowEnabled {
                        routePath(points: relativePoints)
                            .stroke(Color(element.style.foregroundColor).opacity(0.55), style: StrokeStyle(lineWidth: layout.lineWidth * 2.3, lineCap: .round, lineJoin: .round))
                            .blur(radius: layout.glowRadius)
                    }

                    routePath(points: relativePoints)
                        .stroke(routeStroke, style: StrokeStyle(lineWidth: layout.lineWidth, lineCap: .round, lineJoin: .round))

                    routeMarker(relativePoints.first, color: element.style.routeMapStartMarkerColor, style: element.style.routeMapStartMarkerStyle)
                    routeMarker(relativePoints.last, color: element.style.routeMapEndMarkerColor, style: element.style.routeMapEndMarkerStyle)
                }
            }

            if showsCurrentMarker, !layout.projectedPoints.isEmpty {
                routeMarker(
                    relativeCurrentPoint,
                    color: element.style.routeMapRunnerDotColor,
                    style: element.style.routeMapRunnerMarkerStyle,
                    sizeMultiplier: 1.18
                )
            }
        }
    }

    @ViewBuilder
    private func statsBarContent(_ statsBar: OverlayRouteMapStatsBarLayout) -> some View {
        SharedStatsBarContentView(
            items: statsBar.items.map { .init(value: $0.value, unit: $0.unit, label: $0.label) },
            stacked: statsBar.placement.isVertical || statsBar.layoutMode == .stack,
            itemSpacing: statsBar.itemSpacing,
            dividerOpacity: statsBar.dividerOpacity,
            cornerRadius: statsBar.cornerRadius,
            backgroundOpacity: statsBar.backgroundOpacity,
            valueFontName: statsBar.valueFontName,
            valueFontWeight: statsBar.valueFontWeight,
            valueColor: Color(statsBar.valueColor),
            labelFontName: statsBar.labelFontName,
            labelFontWeight: statsBar.labelFontWeight,
            labelColor: Color(statsBar.labelColor),
            valueFontSize: statsBar.valueFontSize,
            labelFontSize: statsBar.labelFontSize
        )
    }

    private var renderIdentity: String {
        "\(mapSnapshotRequest?.hashValue ?? 0)-\(layout.shape.rawValue)-\(layout.edgeFade.rawValue)-\(String(format: "%.2f", layout.fadeAmount))-\(Int(layout.rect.width.rounded()))x\(Int(layout.rect.height.rounded()))"
    }

    private var mapSnapshotRequest: MapSnapshotRequest? {
        RouteMapSnapshotRequestBuilder.request(for: element, layout: layout)
    }

    @MainActor
    private func updateRenderAssets() async {
        if layout.edgeFade == .fadeOut, layout.fadeAmount > 0.001 {
            alphaMask = RouteMapMaskRenderer.makeNSImage(
                size: layout.rect.size,
                shape: layout.shape,
                cornerRadius: layout.cornerRadius,
                edgeFade: layout.edgeFade,
                fadeAmount: layout.fadeAmount
            )
        } else {
            alphaMask = nil
        }

        if let staticMapSnapshot {
            mapSnapshot = staticMapSnapshot
            return
        }

        guard let request = mapSnapshotRequest else {
            mapSnapshot = nil
            return
        }

        let provider = MapKitMapSnapshotProvider()
        if let image = await provider.snapshotImage(for: request).image {
            mapSnapshot = image
        }
    }

    private var resolvedMapSnapshot: NSImage? {
        staticMapSnapshot ?? mapSnapshot
    }

    @ViewBuilder
    private var shapeFill: some View {
        switch layout.shape {
        case .circle:
            Circle().fill(Color.white)
        case .square:
            RoundedRectangle(cornerRadius: layout.cornerRadius).fill(Color.white)
        }
    }

    @ViewBuilder
    private func shapeStroke(color: Color, lineWidth: Double) -> some View {
        switch layout.shape {
        case .circle:
            Circle().stroke(color, lineWidth: lineWidth)
        case .square:
            RoundedRectangle(cornerRadius: layout.cornerRadius).stroke(color, lineWidth: lineWidth)
        }
    }

    private var relativePoints: [CGPoint] {
        layout.projectedPoints.map { CGPoint(x: $0.x - layout.rect.minX, y: $0.y - layout.rect.minY) }
    }

    private var relativeCurrentPoint: CGPoint? {
        layout.projectedCurrentPoint.map { CGPoint(x: $0.x - layout.rect.minX, y: $0.y - layout.rect.minY) }
    }

    private var containerBackground: Color {
        guard element.style.backgroundEnabled else {
            return Color.clear
        }
        return background
    }

    private var background: Color {
        if element.style.routeMapBackgroundStyle == .none {
            return Color(element.style.backgroundColor).opacity(element.style.backgroundOpacity)
        }
        switch element.style.routeMapBackgroundStyle {
        case .light:
            return Color(element.style.backgroundColor).opacity(element.style.backgroundOpacity)
        case .terrain:
            return Color(element.style.backgroundColor).opacity(element.style.backgroundOpacity)
        case .satellite:
            return Color(element.style.backgroundColor).opacity(element.style.backgroundOpacity)
        case .none:
            return Color(element.style.backgroundColor).opacity(element.style.backgroundOpacity)
        case .dark:
            return Color(element.style.backgroundColor).opacity(element.style.backgroundOpacity)
        }
    }

    private var routeStroke: AnyShapeStyle {
        if element.style.routeMapColorMode == .gradient {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(element.style.routeMapGradientStart),
                        Color(element.style.routeMapGradientMiddle),
                        Color(element.style.routeMapGradientEnd)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        return AnyShapeStyle(Color(element.style.foregroundColor))
    }

    private var mapGrid: some View {
        GeometryReader { proxy in
            Path { path in
                let step = max(proxy.size.width / 6, 18)
                var x = step
                while x < proxy.size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                    x += step
                }
                var y = step
                while y < proxy.size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    y += step
                }
            }
            .stroke(mapGridColor, lineWidth: 1)
        }
    }

    private var mapGridColor: Color {
        switch element.style.routeMapBackgroundStyle {
        case .light:
            return Color.black.opacity(0.10)
        case .terrain:
            return Color.green.opacity(0.18)
        case .satellite:
            return Color.white.opacity(0.06)
        case .none, .dark:
            return Color.white.opacity(0.08)
        }
    }

    private func routePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else {
            return path
        }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    @ViewBuilder
    private func marker(_ point: CGPoint?, color: OverlayColor, sizeMultiplier: Double = 1) -> some View {
        if let point {
            let diameter = layout.lineWidth * 2.7 * sizeMultiplier
            Circle()
                .fill(color.isRouteMapEndCheckerboard ? Color.clear : Color(color))
                .frame(width: diameter, height: diameter)
                .overlay {
                    if color.isRouteMapEndCheckerboard {
                        RouteMapCheckerboardSwatch(cornerRadius: diameter / 2)
                            .clipShape(Circle())
                    }
                }
                .overlay {
                    Circle().stroke(Color.white, lineWidth: max(layout.lineWidth * 0.45, 1))
                }
                .position(point)
        }
    }

    @ViewBuilder
    private func routeMarker(
        _ point: CGPoint?,
        color: OverlayColor,
        style: OverlayRouteMapMarkerStyle,
        sizeMultiplier: Double = 1
    ) -> some View {
        if let point {
            switch style {
            case .hidden:
                EmptyView()
            case .dot, .pin, .flag:
                marker(point, color: color, sizeMultiplier: sizeMultiplier)
            }
        }
    }
}

struct TextPresetOverlayView: View {
    let element: OverlayElement
    let layout: OverlayTextRenderLayout
    let isSelected: Bool

    var body: some View {
        Group {
            switch layout.preset {
            case .minimal:
                minimalCleanView
            case .minimalLabel:
                minimalLabelView
            case .pillBadge:
                pillView
            case .metricCard:
                VStack(alignment: .leading, spacing: layout.verticalPadding * 0.7) {
                    Text(layout.components.label)
                        .font(labelFont)
                        .foregroundStyle(labelTextColor)
                    HStack(alignment: .firstTextBaseline, spacing: layout.horizontalPadding * 0.35) {
                        valueText
                        unitText
                    }
                }
                .padding(.horizontal, layout.horizontalPadding)
                .padding(.vertical, layout.verticalPadding)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius))
            case .bigNumber:
                bigNumberView
            case .sportWatch:
                VStack(spacing: layout.verticalPadding * 0.65) {
                    Text(layout.components.shortLabel)
                        .font(labelFont.weight(.bold))
                        .foregroundStyle(labelTextColor)
                    divider
                    valueText
                    divider
                    unitText
                        .font(labelFont.weight(.bold))
                        .foregroundStyle(unitTextColor)
                }
                .frame(minWidth: layout.fontSize * 3.2)
                .padding(.horizontal, layout.horizontalPadding)
                .padding(.vertical, layout.verticalPadding)
                .background(background)
                .overlay {
                    RoundedRectangle(cornerRadius: layout.cornerRadius)
                        .stroke(Color(element.style.foregroundColor).opacity(0.35), lineWidth: max(layout.fontSize / 28, 1))
                }
                .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius))
            case .splitLabel:
                splitLabelView
            case .neonGlow:
                neonGlowView
            case .racingStripe:
                racingStripeView
            case .editorial:
                editorialView
            case .digitalWatch:
                digitalWatchView
            case .inlineGhost:
                inlineGhostView
            case .accentBar:
                accentBarView
            case .sportNeon:
                sportNeonView
            case .serifEditorial:
                serifEditorialView
            }
        }
        .frame(minWidth: layout.minimumWidth, minHeight: layout.minimumHeight, alignment: .topLeading)
        .foregroundStyle(overlayGroupForegroundColor)
        .monospacedDigit()
        .overlayGenericBorder(element: element, cornerRadius: layout.cornerRadius)
        .overlayForegroundEffects(element: element, shadowRadius: layout.shadowRadius)
    }

    // MARK: - Canonical 10 numeric overlay presets

    @ViewBuilder
    private var minimalCleanView: some View {
        metricCoreContent
        .frame(minWidth: layout.minimumWidth, minHeight: layout.minimumHeight, alignment: .topLeading)
        .padding(.horizontal, element.style.backgroundEnabled ? layout.horizontalPadding : 0)
        .padding(.vertical, element.style.backgroundEnabled ? layout.verticalPadding : 0)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(Color.accentColor.opacity(0.45))
            } else if element.style.backgroundEnabled {
                OverlayFeatheredBackground(
                    isSelected: false,
                    backgroundEnabled: element.style.backgroundEnabled,
                    color: Color(element.style.backgroundColor),
                    opacity: element.style.backgroundOpacity,
                    cornerRadius: layout.cornerRadius,
                    fadeEnabled: layout.backgroundFadeOutEnabled,
                    fadeAmount: layout.backgroundFadeOutAmount,
                    blurRadius: layout.backgroundBlurRadius
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius))
    }

    @ViewBuilder
    private var minimalLabelView: some View {
        metricCoreContent
    }

    @ViewBuilder
    private var pillView: some View {
        let foreground = Color(element.style.foregroundColor)
        let valueAndUnit = HStack(alignment: .lastTextBaseline, spacing: layout.fontSize * 0.14) {
            Text(layout.components.value)
                .font(.overlayFont(family: element.style.fontName, size: layout.fontSize * 0.92, weight: .bold))
                .tracking(-layout.fontSize * 0.009)
                .foregroundStyle(valueTextColor)
            if element.style.showUnit, !layout.components.unit.isEmpty {
                Text(layout.components.unit)
                    .font(.overlayFont(family: element.style.fontName, size: layout.unitFontSize, weight: .medium))
                    .foregroundStyle(unitTextColor)
            }
        }
        Group {
            if element.style.showLabel, !layout.components.label.isEmpty {
                HStack(alignment: labelVAlignment, spacing: layout.fontSize * 0.32) {
                    Text(layout.components.label.uppercased())
                        .font(.overlayFont(family: element.style.fontName, size: layout.labelFontSize, weight: .medium))
                        .tracking(layout.labelFontSize * 0.10)
                        .foregroundStyle(labelTextColor)
                        .multilineTextAlignment(labelTextAlignmentSwiftUI)
                    if layout.dividerEnabled {
                        Rectangle()
                            .fill(dividerColor)
                            .frame(width: max(layout.dividerThickness, 0), height: layout.fontSize * 0.78)
                    }
                    valueAndUnit
                }
            } else {
                valueAndUnit
            }
        }
        .padding(.horizontal, layout.horizontalPadding)
        .padding(.vertical, layout.verticalPadding)
        .background(
            OverlayFeatheredBackground(
                isSelected: isSelected,
                backgroundEnabled: element.style.backgroundEnabled,
                color: Color(element.style.backgroundColor),
                opacity: element.style.backgroundOpacity,
                cornerRadius: layout.cornerRadius,
                usesCapsuleRadius: true,
                fadeEnabled: layout.backgroundFadeOutEnabled,
                fadeAmount: layout.backgroundFadeOutAmount,
                blurRadius: layout.backgroundBlurRadius
            )
        )
        .overlay(
            Capsule().stroke(foreground.opacity(0.16), lineWidth: 1)
                .opacity(element.style.backgroundEnabled ? 1 : 0)
        )
    }

    @ViewBuilder
    private var splitLabelView: some View {
        let labelColor = Color(element.style.labelColor).opacity(element.style.labelOpacity)
        VStack(alignment: .leading, spacing: layout.fontSize * 0.10) {
            if element.style.showLabel, !layout.components.label.isEmpty {
                Text(layout.components.label.uppercased())
                    .font(.overlayFont(family: element.style.fontName, size: layout.labelFontSize, weight: .semibold))
                    .tracking(layout.labelFontSize * 0.18)
                    .foregroundStyle(labelColor)
                    .multilineTextAlignment(labelTextAlignmentSwiftUI)
                    .frame(maxWidth: .infinity, alignment: labelStackFrameAlignment)
            }
            if layout.dividerEnabled {
                Rectangle()
                    .fill(dividerColor)
                    .frame(width: layout.fontSize * 2.4, height: max(layout.dividerThickness, 0))
                    .frame(maxWidth: .infinity, alignment: valueStackFrameAlignment)
            }
            // Value and unit live on their own rows so each can drive its own
            // frame alignment. The user wants unit-align to behave independently
            // from value-align — sharing an HStack would glue them together.
            Text(layout.components.value)
                .font(.overlayFont(family: element.style.fontName, size: layout.fontSize, weight: .bold))
                .tracking(-layout.fontSize * 0.012)
                .foregroundStyle(valueTextColor)
                .frame(maxWidth: .infinity, alignment: valueStackFrameAlignment)
            if element.style.showUnit, !layout.components.unit.isEmpty {
                Text(layout.components.unit)
                    .font(.overlayFont(family: element.style.fontName, size: layout.unitFontSize, weight: .medium))
                    .foregroundStyle(unitTextColor)
                    .frame(maxWidth: .infinity, alignment: unitStackFrameAlignment)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var neonGlowView: some View {
        let accent = Color(element.style.accentColor)
        HStack(alignment: .lastTextBaseline, spacing: layout.fontSize * 0.14) {
            Text(layout.components.value)
                .font(.overlayFont(family: element.style.fontName, size: layout.fontSize, weight: .bold))
                .tracking(-layout.fontSize * 0.010)
                .foregroundStyle(valueTextColor)
                .shadow(color: accent.opacity(0.80), radius: layout.fontSize * 0.34)
                .shadow(color: accent.opacity(0.36), radius: layout.fontSize * 0.62)
            if element.style.showUnit, !layout.components.unit.isEmpty {
                Text(layout.components.unit)
                    .font(.overlayFont(family: element.style.fontName, size: layout.unitFontSize, weight: .semibold))
                    .foregroundStyle(unitTextColor)
                    .shadow(color: accent.opacity(0.65), radius: layout.fontSize * 0.24)
            }
        }
    }

    @ViewBuilder
    private var racingStripeView: some View {
        let foreground = Color(element.style.foregroundColor)
        let labelColor = Color(element.style.labelColor).opacity(element.style.labelOpacity)
        // Stripe is the racing-stripe preset's divider — drive width from the
        // shared divider thickness so users can scale or hide it from the
        // Inspector along with the other divider-bearing presets.
        let stripeWidth = layout.dividerEnabled ? max(layout.dividerThickness * 2.4, 4) : 0
        let stripeGap = layout.fontSize * 0.34
        VStack(alignment: .leading, spacing: layout.fontSize * 0.10) {
            if element.style.showLabel, !layout.components.label.isEmpty {
                Text(layout.components.label.uppercased())
                    .font(.overlayFont(family: element.style.fontName, size: layout.labelFontSize, weight: .bold))
                    .tracking(layout.labelFontSize * 0.10)
                    .foregroundStyle(labelColor)
                    .multilineTextAlignment(labelTextAlignmentSwiftUI)
                    .frame(maxWidth: .infinity, alignment: labelStackFrameAlignment)
            }
            Text(layout.components.value)
                .font(.overlayFont(family: element.style.fontName, size: layout.fontSize, weight: .bold))
                .tracking(-layout.fontSize * 0.010)
                .foregroundStyle(valueTextColor)
                .frame(maxWidth: .infinity, alignment: valueStackFrameAlignment)
            if element.style.showUnit, !layout.components.unit.isEmpty {
                Text(layout.components.unit)
                    .font(.overlayFont(family: element.style.fontName, size: layout.unitFontSize, weight: .medium))
                    .foregroundStyle(unitTextColor)
                    .frame(maxWidth: .infinity, alignment: unitStackFrameAlignment)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.leading, stripeWidth + (layout.dividerEnabled ? stripeGap : 0))
        .overlay(alignment: .leading) {
            if layout.dividerEnabled {
                RoundedRectangle(cornerRadius: 2)
                    .fill(dividerColor)
                    .frame(width: stripeWidth)
            }
        }
        .padding(.horizontal, layout.horizontalPadding)
        .padding(.vertical, layout.verticalPadding)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .stroke(foreground.opacity(0.14), lineWidth: 1)
                .opacity(element.style.backgroundEnabled ? 1 : 0)
        )
    }

    @ViewBuilder
    private var editorialView: some View {
        let labelColor = Color(element.style.labelColor).opacity(element.style.labelOpacity)
        VStack(alignment: .leading, spacing: layout.fontSize * 0.04) {
            if element.style.showLabel, !layout.components.label.isEmpty {
                Text(layout.components.label.uppercased())
                    .font(.overlayFont(family: element.style.fontName, size: layout.labelFontSize, weight: .bold))
                    .tracking(layout.labelFontSize * 0.18)
                    .foregroundStyle(labelColor)
                    .multilineTextAlignment(labelTextAlignmentSwiftUI)
                    .frame(maxWidth: .infinity, alignment: labelStackFrameAlignment)
            }
            Text(layout.components.value)
                .font(.overlayFont(family: element.style.fontName, size: layout.fontSize, weight: .heavy))
                .tracking(-layout.fontSize * 0.018)
                .foregroundStyle(valueTextColor)
                .frame(maxWidth: .infinity, alignment: valueStackFrameAlignment)
            if element.style.showUnit, !layout.components.unit.isEmpty {
                Text(layout.components.unit)
                    .font(.overlayFont(family: element.style.fontName, size: layout.unitFontSize, weight: .medium))
                    .foregroundStyle(unitTextColor)
                    .frame(maxWidth: .infinity, alignment: unitStackFrameAlignment)
            }
            if layout.dividerEnabled {
                Rectangle()
                    .fill(dividerColor)
                    .frame(width: layout.fontSize * 2.2, height: max(layout.dividerThickness, 0))
                    .frame(maxWidth: .infinity, alignment: valueStackFrameAlignment)
                    .padding(.top, layout.fontSize * 0.04)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var digitalWatchView: some View {
        let accent = Color(element.style.accentColor)
        // Menlo Bold provides stable monospaced digits on every supported
        // macOS version. Wide tracking and the layered accent glow preserve
        // the compact electronic instrument-panel character.
        let digitalFont = PresetFontName.digitalWatch
        VStack(alignment: .leading, spacing: layout.fontSize * 0.10) {
            if element.style.showLabel, !layout.components.label.isEmpty {
                Text(layout.components.label.uppercased())
                    .font(.custom(digitalFont, size: layout.labelFontSize))
                    .tracking(layout.labelFontSize * 0.18)
                    .foregroundStyle(labelTextColor)
            }
            HStack(alignment: .lastTextBaseline, spacing: layout.fontSize * 0.14) {
                Text(layout.components.value)
                    .font(.custom(digitalFont, size: layout.fontSize))
                    .tracking(layout.fontSize * 0.020)
                    .foregroundStyle(valueTextColor)
                    .shadow(color: accent.opacity(0.85), radius: layout.fontSize * 0.18)
                    .shadow(color: accent.opacity(0.45), radius: layout.fontSize * 0.42)
                if element.style.showUnit, !layout.components.unit.isEmpty {
                    Text(layout.components.unit)
                        .font(.custom(digitalFont, size: layout.unitFontSize))
                        .foregroundStyle(unitTextColor)
                        .shadow(color: accent.opacity(0.55), radius: layout.fontSize * 0.14)
                }
            }
        }
        .padding(.horizontal, layout.horizontalPadding)
        .padding(.vertical, layout.verticalPadding)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .stroke(accent.opacity(0.70), lineWidth: 1)
        )
    }

    // MARK: - Legacy / deprecated previews kept for backward compatibility

    @ViewBuilder
    private var inlineGhostView: some View {
        let foreground = Color(element.style.foregroundColor)
        VStack(alignment: .leading, spacing: layout.fontSize * 0.06) {
            if element.style.showLabel, !layout.components.label.isEmpty {
                Text(layout.components.label.uppercased())
                    .font(.overlayFont(family: element.style.fontName, size: layout.labelFontSize, weight: .regular))
                    .tracking(layout.labelFontSize * 0.12)
                    .foregroundStyle(heartRateZoneTextPaletteActive ? labelTextColor : foreground.opacity(0.28))
            }
            HStack(alignment: .firstTextBaseline, spacing: layout.fontSize * 0.18) {
                Text(layout.components.value)
                    .font(.overlayFont(family: element.style.fontName, size: layout.fontSize, weight: .light))
                    .tracking(-layout.fontSize * 0.02)
                    .foregroundStyle(
                        heartRateZoneTextPaletteActive
                            ? valueTextColor
                            : Color(element.style.valueColor).opacity(element.style.valueOpacity * 0.88)
                    )
                if element.style.showUnit, !layout.components.unit.isEmpty {
                    Text(layout.components.unit)
                        .font(.overlayFont(family: element.style.fontName, size: layout.unitFontSize, weight: .regular))
                        .foregroundStyle(heartRateZoneTextPaletteActive ? unitTextColor : foreground.opacity(0.30))
                }
            }
        }
    }

    @ViewBuilder
    private var accentBarView: some View {
        let bar = Color(element.style.accentColor)
        let foreground = Color(element.style.foregroundColor)
        HStack(alignment: .center, spacing: layout.fontSize * 0.33) {
            RoundedRectangle(cornerRadius: max(layout.fontSize * 0.06, 1))
                .fill(bar)
                .frame(width: max(layout.fontSize * 0.083, 1.5), height: layout.fontSize * 1.55)
            VStack(alignment: .leading, spacing: layout.fontSize * 0.06) {
                if element.style.showLabel, !layout.components.label.isEmpty {
                    Text(layout.components.label.uppercased())
                        .font(.overlayFont(family: element.style.fontName, size: layout.labelFontSize, weight: .regular))
                        .tracking(layout.labelFontSize * 0.12)
                        .foregroundStyle(heartRateZoneTextPaletteActive ? labelTextColor : foreground.opacity(0.32))
                }
                Text(layout.components.value)
                    .font(.overlayFont(family: element.style.fontName, size: layout.fontSize, weight: .bold))
                    .tracking(-layout.fontSize * 0.05)
                    .foregroundStyle(valueTextColor)
                if element.style.showUnit, !layout.components.unit.isEmpty {
                    Text(layout.components.unit)
                        .font(.overlayFont(family: element.style.fontName, size: layout.unitFontSize, weight: .regular))
                        .foregroundStyle(heartRateZoneTextPaletteActive ? unitTextColor : foreground.opacity(0.38))
                }
            }
        }
    }

    @ViewBuilder
    private var sportNeonView: some View {
        let accent = Color(element.style.accentColor)
        let foreground = Color(element.style.foregroundColor)
        VStack(alignment: .leading, spacing: layout.fontSize * 0.05) {
            if element.style.showLabel, !layout.components.label.isEmpty {
                Text(layout.components.label.uppercased())
                    .font(.overlayFont(family: element.style.fontName, size: layout.labelFontSize, weight: .bold))
                    .tracking(layout.labelFontSize * 0.16)
                    .foregroundStyle(heartRateZoneTextPaletteActive ? labelTextColor : accent)
            }
            Text(layout.components.value)
                .font(.overlayFont(family: element.style.fontName, size: layout.fontSize, weight: .heavy))
                .tracking(-layout.fontSize * 0.06)
                .foregroundStyle(valueTextColor)
            if element.style.showUnit, !layout.components.unit.isEmpty {
                HStack(alignment: .center, spacing: layout.fontSize * 0.18) {
                    Rectangle()
                        .fill(foreground.opacity(0.10))
                        .frame(width: layout.fontSize * 0.6, height: 0.5)
                    Circle()
                        .fill(accent)
                        .frame(width: max(layout.fontSize * 0.14, 4), height: max(layout.fontSize * 0.14, 4))
                    Text(layout.components.unit)
                        .font(.overlayFont(family: element.style.fontName, size: layout.unitFontSize, weight: .regular))
                        .foregroundStyle(heartRateZoneTextPaletteActive ? unitTextColor : foreground.opacity(0.35))
                }
            }
        }
    }

    @ViewBuilder
    private var serifEditorialView: some View {
        let foreground = Color(element.style.foregroundColor)
        let serifFont = "Georgia"
        VStack(spacing: layout.fontSize * 0.05) {
            if element.style.showLabel, !layout.components.label.isEmpty {
                Text(layout.components.label.uppercased())
                    .font(.system(size: layout.labelFontSize, weight: .regular))
                    .tracking(layout.labelFontSize * 0.2)
                    .foregroundStyle(heartRateZoneTextPaletteActive ? labelTextColor : foreground.opacity(0.30))
            }
            Text(layout.components.value)
                .font(.custom(serifFont, size: layout.fontSize))
                .tracking(-layout.fontSize * 0.01)
                .foregroundStyle(valueTextColor)
            if element.style.showUnit, !layout.components.unit.isEmpty {
                Rectangle()
                    .fill(foreground.opacity(0.20))
                    .frame(width: layout.fontSize * 0.78, height: 0.5)
                    .padding(.vertical, layout.fontSize * 0.18)
                Text(layout.components.unit)
                    .font(.system(size: layout.unitFontSize, weight: .regular))
                    .tracking(layout.unitFontSize * 0.1)
                    .foregroundStyle(heartRateZoneTextPaletteActive ? unitTextColor : foreground.opacity(0.28))
            }
        }
    }

    private var valueText: Text {
        Text(layout.components.value)
            .font(.overlayFont(family: element.style.fontName, size: layout.fontSize, weight: Font.Weight(element.style.fontWeight)))
            .foregroundColor(valueTextColor)
    }

    private var unitText: Text {
        Text(layout.components.unit)
            .font(.overlayFont(family: layout.unitFontName, size: layout.unitFontSize, weight: Font.Weight(layout.unitFontWeight)))
    }

    private var labelFont: Font {
        .overlayFont(family: layout.labelFontName, size: layout.labelFontSize, weight: Font.Weight(layout.labelFontWeight))
    }

    private var background: some View {
        OverlayFeatheredBackground(
            isSelected: isSelected,
            backgroundEnabled: element.style.backgroundEnabled,
            color: Color(element.style.backgroundColor),
            opacity: element.style.backgroundOpacity,
            cornerRadius: layout.cornerRadius,
            fadeEnabled: layout.backgroundFadeOutEnabled,
            fadeAmount: layout.backgroundFadeOutAmount,
            blurRadius: layout.backgroundBlurRadius
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(dividerColor)
            .frame(width: layout.fontSize * 2.7, height: max(layout.dividerThickness, 1))
    }

    /// Style-fed divider color (with opacity applied). Returns `.clear` when
    /// the user has disabled the divider for this overlay — keeps the layout
    /// rect intact while making the line invisible.
    private var dividerColor: Color {
        guard layout.dividerEnabled else { return .clear }
        return Color(layout.dividerColor).opacity(layout.dividerOpacity)
    }

    /// Maps the label text alignment to a SwiftUI `HorizontalAlignment` for
    /// VStack stacks (used when the label sits above/below the value).
    private var labelHAlignment: HorizontalAlignment {
        horizontalAlignment(layout.labelTextAlignment)
    }

    /// Maps the label text alignment to a SwiftUI `VerticalAlignment` for
    /// HStack stacks (used when the label sits to the left/right of the value;
    /// leading → top, center → middle, trailing → bottom).
    private var labelVAlignment: VerticalAlignment {
        verticalAlignment(layout.labelTextAlignment)
    }

    private var labelTextAlignmentSwiftUI: TextAlignment {
        textAlignment(layout.labelTextAlignment)
    }

    /// Frame-anchor for the label row inside a stacked layout. We pin the row
    /// at `maxWidth: .infinity` and let this alignment do the actual visual
    /// positioning — that way the label can move horizontally without
    /// influencing the value row above/below it.
    private var labelStackFrameAlignment: Alignment {
        alignmentForFrame(layout.labelTextAlignment)
    }

    private var valueStackFrameAlignment: Alignment {
        alignmentForFrame(layout.valueTextAlignment)
    }

    /// Frame-anchor for the unit row when the unit sits on its own line. Inline
    /// unit positions (`.leading`/`.trailing` of the value) stay baseline-locked
    /// to the value and ignore this anchor.
    private var unitStackFrameAlignment: Alignment {
        alignmentForFrame(layout.unitTextAlignment)
    }

    private var iconStackFrameAlignment: Alignment {
        alignmentForFrame(layout.iconTextAlignment)
    }

    private var iconVAlignment: VerticalAlignment {
        verticalAlignment(layout.iconTextAlignment)
    }

    private func horizontalAlignment(_ a: OverlayTextAlignment) -> HorizontalAlignment {
        switch a {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    private func verticalAlignment(_ a: OverlayTextAlignment) -> VerticalAlignment {
        switch a {
        case .leading: .top
        case .center: .center
        case .trailing: .bottom
        }
    }

    private func textAlignment(_ a: OverlayTextAlignment) -> TextAlignment {
        switch a {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    private func alignmentForFrame(_ a: OverlayTextAlignment) -> Alignment {
        switch a {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    @ViewBuilder
    private var bigNumberView: some View {
        let value = Text(layout.components.value)
            .font(.overlayFont(family: element.style.fontName, size: layout.fontSize * 1.95, weight: .bold))
            .foregroundStyle(valueTextColor)
        let unit = Text(layout.components.unit)
            .font(.overlayFont(family: element.style.fontName, size: layout.unitFontSize * 1.25, weight: .bold))
            .foregroundStyle(unitTextColor)
        let label = Text(layout.components.label)
            .font(labelFont)
            .tracking(layout.labelFontSize * 0.10)
            .foregroundStyle(labelTextColor)
            .multilineTextAlignment(labelTextAlignmentSwiftUI)
        let showLabel = element.style.showLabel && !layout.components.label.isEmpty
        let showUnit = element.style.showUnit && !layout.components.unit.isEmpty
        switch layout.labelPosition {
        case .top, .bottom:
            // Flatten value+unit into the outer leading-anchored VStack so each
            // row gets its own `frame(maxWidth:, alignment:)`. That keeps unit
            // alignment independent from both label and value.
            VStack(alignment: .leading, spacing: 0) {
                if showLabel && layout.labelPosition == .top {
                    label
                        .frame(maxWidth: .infinity, alignment: labelStackFrameAlignment)
                        .padding(.bottom, layout.labelSpacing)
                }
                value
                    .frame(maxWidth: .infinity, alignment: valueStackFrameAlignment)
                if showUnit {
                    unit
                        .frame(maxWidth: .infinity, alignment: unitStackFrameAlignment)
                }
                if showLabel && layout.labelPosition == .bottom {
                    label
                        .frame(maxWidth: .infinity, alignment: labelStackFrameAlignment)
                        .padding(.top, layout.labelSpacing)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        case .leading, .trailing:
            HStack(alignment: labelVAlignment, spacing: 0) {
                if showLabel && layout.labelPosition == .leading {
                    label.padding(.trailing, layout.labelSpacing)
                }
                VStack(alignment: .leading, spacing: 0) {
                    value
                        .frame(maxWidth: .infinity, alignment: valueStackFrameAlignment)
                    if showUnit {
                        unit
                            .frame(maxWidth: .infinity, alignment: unitStackFrameAlignment)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                if showLabel && layout.labelPosition == .trailing {
                    label.padding(.leading, layout.labelSpacing)
                }
            }
        }
    }

    @ViewBuilder
    private var metricCoreContent: some View {
        let showIcon = layout.iconEnabled && !layout.iconSystemName.isEmpty
        if showIcon {
            switch layout.iconPosition {
            case .top:
                VStack(alignment: .leading, spacing: 0) {
                    metricIconView
                        .frame(maxWidth: .infinity, alignment: iconStackFrameAlignment)
                        .padding(.bottom, layout.iconSpacing)
                    metricTextContent
                }
                .fixedSize(horizontal: true, vertical: false)
            case .bottom:
                VStack(alignment: .leading, spacing: 0) {
                    metricTextContent
                    metricIconView
                        .frame(maxWidth: .infinity, alignment: iconStackFrameAlignment)
                        .padding(.top, layout.iconSpacing)
                }
                .fixedSize(horizontal: true, vertical: false)
            case .leading:
                HStack(alignment: iconVAlignment, spacing: 0) {
                    metricIconView
                        .padding(.trailing, layout.iconSpacing)
                    metricTextContent
                }
                .fixedSize(horizontal: true, vertical: false)
            case .trailing:
                HStack(alignment: iconVAlignment, spacing: 0) {
                    metricTextContent
                    metricIconView
                        .padding(.leading, layout.iconSpacing)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        } else {
            metricTextContent
        }
    }

    private var metricIconView: some View {
        Image(systemName: layout.iconSystemName)
            .font(.system(size: layout.iconSize, weight: .medium))
            .foregroundStyle(iconTextColor)
            .frame(width: layout.iconSize, height: layout.iconSize)
            .fixedSize(horizontal: true, vertical: true)
    }

    @ViewBuilder
    private var metricTextContent: some View {
        let label = Text(layout.components.label)
            .font(labelFont)
            .tracking(layout.labelFontSize * 0.10)
            .foregroundStyle(labelTextColor)
            .multilineTextAlignment(labelTextAlignmentSwiftUI)
        let unit = Text(layout.components.unit)
            .font(.overlayFont(family: layout.unitFontName, size: layout.unitFontSize, weight: Font.Weight(layout.unitFontWeight)))
            .foregroundStyle(unitTextColor)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
        let value = Text(layout.components.value)
            .font(.overlayFont(family: element.style.fontName, size: layout.fontSize, weight: .semibold))
            .tracking(-layout.fontSize * 0.012)
            .foregroundStyle(valueTextColor)
        let showLabel = element.style.showLabel && !layout.components.label.isEmpty
        let showUnitFlag = element.style.showUnit && !layout.components.unit.isEmpty
        let hasSideLabel = showLabel && (layout.labelPosition == .leading || layout.labelPosition == .trailing)
        let hasInlineUnit = showUnitFlag && (layout.unitPosition == .leading || layout.unitPosition == .trailing)
        let valueUnitClusterAlignment: VerticalAlignment = hasInlineUnit
            ? verticalAlignment(layout.unitTextAlignment)
            : .center

        // The outer VStack pins on `.leading` so that the per-row
        // `frame(maxWidth: .infinity, alignment:)` modifiers on the label and
        // value rows each take effect independently. If we set the VStack
        // alignment to either label's or value's alignment, the shorter row
        // would inherit the other's offset and the two controls would couple.
        VStack(alignment: .leading, spacing: 0) {
            if showLabel && layout.labelPosition == .top {
                label
                    .frame(maxWidth: .infinity, alignment: labelStackFrameAlignment)
                    .padding(.bottom, layout.labelSpacing)
            }
            Group {
                let valueUnitCluster = HStack(alignment: valueUnitClusterAlignment, spacing: 0) {
                    if showUnitFlag && layout.unitPosition == .leading {
                        unit
                            .padding(.trailing, layout.unitSpacing)
                    }
                    value
                        .frame(maxWidth: .infinity, alignment: valueStackFrameAlignment)
                    if showUnitFlag && layout.unitPosition == .trailing {
                        unit
                            .padding(.leading, layout.unitSpacing)
                    }
                }
                if hasSideLabel {
                    HStack(alignment: labelVAlignment, spacing: 0) {
                        if showLabel && layout.labelPosition == .leading {
                            label
                                .padding(.trailing, layout.labelSpacing)
                        }
                        valueUnitCluster
                        if showLabel && layout.labelPosition == .trailing {
                            label
                                .padding(.leading, layout.labelSpacing)
                        }
                    }
                } else {
                    valueUnitCluster
                }
            }
            // Expand the row to the VStack width with a neutral cluster anchor so
            // `valueTextAlignment` only affects the value slot — inline units are
            // not shifted when the value alignment changes.
            .frame(maxWidth: .infinity, alignment: .leading)
            if showUnitFlag && layout.unitPosition == .bottom {
                unit
                    .frame(maxWidth: .infinity, alignment: unitStackFrameAlignment)
                    .padding(.top, layout.unitSpacing)
            }
            if showLabel && layout.labelPosition == .bottom {
                label
                    .frame(maxWidth: .infinity, alignment: labelStackFrameAlignment)
                    .padding(.top, layout.labelSpacing)
            }
        }
        // Let the stack collapse to its natural width so the overlay doesn't
        // stretch across the canvas; `maxWidth: .infinity` on the row frames
        // expands them only as wide as the widest sibling.
        .fixedSize(horizontal: true, vertical: false)
    }

    private var dynamicHeartRateZoneColor: OverlayColor? {
        layout.dynamicHeartRateZoneColor
    }

    private var heartRateZoneTextPaletteActive: Bool {
        dynamicHeartRateZoneColor != nil
            && (layout.valueColorsFollowHeartRateZones
                || layout.labelColorsFollowHeartRateZones
                || layout.unitColorsFollowHeartRateZones)
    }

    private var overlayGroupForegroundColor: Color {
        if layout.valueColorsFollowHeartRateZones, let base = dynamicHeartRateZoneColor {
            return Color(base).opacity(element.style.valueOpacity)
        }
        return Color(element.style.foregroundColor)
    }

    private var valueTextColor: Color {
        if layout.valueColorsFollowHeartRateZones, let base = dynamicHeartRateZoneColor {
            return Color(base).opacity(element.style.valueOpacity)
        }
        return Color(element.style.valueColor).opacity(element.style.valueOpacity)
    }

    private var labelTextColor: Color {
        if layout.labelColorsFollowHeartRateZones, let base = dynamicHeartRateZoneColor {
            return Color(base).opacity(element.style.labelOpacity)
        }
        return Color(element.style.labelColor).opacity(element.style.labelOpacity)
    }

    private var unitTextColor: Color {
        if layout.unitColorsFollowHeartRateZones, let base = dynamicHeartRateZoneColor {
            return Color(base).opacity(element.style.unitOpacity)
        }
        return Color(element.style.unitColor).opacity(element.style.unitOpacity)
    }

    private var iconTextColor: Color {
        if layout.iconColorsFollowHeartRateZones, let base = dynamicHeartRateZoneColor {
            return Color(base).opacity(layout.iconOpacity)
        }
        return Color(layout.iconColor).opacity(layout.iconOpacity)
    }
}

struct RunningGaugeOverlayView: View {
    let element: OverlayElement
    let layout: OverlayRunningGaugeRenderLayout
    let isSelected: Bool

    private var style: RunningGaugeStyle { layout.style }
    private var diameter: Double { layout.rect.width }

    var body: some View {
        ZStack {
            // Dial background.
            Circle()
                .fill(Color(style.dialBackgroundColor).opacity(style.dialBackgroundOpacity))
                .overlay {
                    if style.glassEffectEnabled {
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: max(layout.outerRingWidth * 0.5, 1))
                            .blur(radius: layout.outerRingWidth * 0.4)
                    }
                }

            // Outer ring.
            if style.outerRingEnabled {
                Circle()
                    .strokeBorder(
                        Color(style.outerRingColor).opacity(style.outerRingOpacity),
                        lineWidth: layout.outerRingWidth
                    )
            }

            // Tick marks.
            if style.tickMarksEnabled {
                GaugeTicksView(
                    tickCount: max(style.tickCount, 6),
                    majorEvery: max(style.majorTickEvery, 1),
                    tickLength: diameter * 0.025,
                    majorTickLength: diameter * 0.040,
                    tickWidth: max(style.dividerWidth, 1),
                    color: Color(style.tickColor),
                    tickOpacity: style.tickOpacity,
                    majorOpacity: style.majorTickOpacity
                )
                .padding(layout.outerRingWidth + 2)
            }

            // Progress ring (track + arc).
            if style.progressRingEnabled {
                let inset = layout.outerRingWidth + layout.progressRingWidth + 2
                Circle()
                    .stroke(
                        Color(style.progressTrackColor).opacity(style.progressTrackOpacity),
                        lineWidth: layout.progressRingWidth
                    )
                    .padding(inset)
                Circle()
                    .trim(from: 0, to: max(min(layout.progress, 1), 0))
                    .stroke(
                        Color(style.progressColor),
                        style: StrokeStyle(
                            lineWidth: layout.progressRingWidth,
                            lineCap: style.progressRoundedCaps ? .round : .butt
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(inset)
            }

            // Dividers.
            if style.dividerEnabled {
                GaugeDividersView(
                    segments: RunningGaugeLayoutEngine.dividerSegments(for: style.layoutPreset),
                    lineWidth: max(style.dividerWidth, 1),
                    color: Color(style.dividerColor).opacity(style.dividerOpacity),
                    safeRadius: layout.safeRadius / (diameter / 2)
                )
            }

            // Data regions.
            ForEach(layout.regions, id: \.config.id) { region in
                regionView(region)
                    .frame(width: region.rect.width, height: region.rect.height)
                    .position(
                        x: region.rect.midX - layout.rect.minX,
                        y: region.rect.midY - layout.rect.minY
                    )
            }
        }
        .frame(width: diameter, height: diameter)
        .overlay {
            if isSelected {
                Circle()
                    .stroke(Color.accentColor.opacity(0.85), lineWidth: 2)
            }
        }
        .overlayLayeredShadow(
            color: Color(element.style.shadowColor),
            isEnabled: element.style.shadowEnabled,
            opacity: element.style.shadowOpacity,
            radius: element.style.shadowRadius,
            x: element.style.shadowOffsetX,
            y: element.style.shadowOffsetY,
            thickness: element.style.shadowThickness
        )
        .overlayForegroundGlow(element: element)
        .modifier(GaugeMonospacedDigit(enabled: style.monospacedDigits))
    }

    @ViewBuilder
    private func regionView(_ region: OverlayRunningGaugeRegionLayout) -> some View {
        let config = region.config
        let label = config.customLabel.isEmpty ? config.metric.compactLabel : config.customLabel.uppercased()
        let valueColor = Color(config.valueColor ?? style.primaryTextColor)
        let labelColor = Color(config.labelColor ?? style.secondaryTextColor).opacity(0.78)

        VStack(spacing: max(region.unitFontSize * 0.10, 1)) {
            if config.showLabel {
                Text(label)
                    .font(.overlayFont(family: style.fontName, size: region.labelFontSize, weight: swiftFontWeight(config.labelWeight)))
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Text(region.components.value)
                .font(.overlayFont(family: style.fontName, size: region.valueFontSize, weight: swiftFontWeight(config.valueWeight)))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .modifier(
                    GaugeGlow(
                        enabled: style.glowEnabled,
                        color: Color(style.glowColor).opacity(style.glowOpacity),
                        radius: style.glowRadius
                    )
                )
            if config.showUnit, !region.components.unit.isEmpty {
                Text(region.components.unit)
                    .font(.overlayFont(family: style.fontName, size: region.unitFontSize, weight: .medium))
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
            }
        }
    }
}

private struct GaugeTicksView: View {
    let tickCount: Int
    let majorEvery: Int
    let tickLength: Double
    let majorTickLength: Double
    let tickWidth: Double
    let color: Color
    let tickOpacity: Double
    let majorOpacity: Double

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = size / 2
            ZStack {
                ForEach(0..<tickCount, id: \.self) { index in
                    let isMajor = index.isMultiple(of: majorEvery)
                    let length = isMajor ? majorTickLength : tickLength
                    Rectangle()
                        .fill(color.opacity(isMajor ? majorOpacity : tickOpacity))
                        .frame(width: tickWidth, height: length)
                        .offset(y: -radius + length / 2)
                        .rotationEffect(.degrees(Double(index) / Double(tickCount) * 360))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct GaugeDividersView: View {
    let segments: [(CGPoint, CGPoint)]
    let lineWidth: Double
    let color: Color
    /// Fraction of half-side (0...1) describing the safe inset within which
    /// dividers are drawn — keeps lines off the dial bezel.
    let safeRadius: Double

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let width = proxy.size.width
                let height = proxy.size.height
                let safeW = width * safeRadius
                let safeH = height * safeRadius
                let originX = (width - safeW) / 2
                let originY = (height - safeH) / 2
                for (start, end) in segments {
                    path.move(to: CGPoint(x: originX + start.x * safeW, y: originY + start.y * safeH))
                    path.addLine(to: CGPoint(x: originX + end.x * safeW, y: originY + end.y * safeH))
                }
            }
            .stroke(color, lineWidth: lineWidth)
        }
    }
}

private struct GaugeMonospacedDigit: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled { content.monospacedDigit() } else { content }
    }
}

private struct GaugeGlow: ViewModifier {
    let enabled: Bool
    let color: Color
    let radius: Double
    func body(content: Content) -> some View {
        if enabled, radius > 0 {
            content.shadow(color: color, radius: radius)
        } else {
            content
        }
    }
}

private func swiftFontWeight(_ w: OverlayFontWeight) -> Font.Weight {
    switch w {
    case .regular: .regular
    case .medium: .medium
    case .semibold: .semibold
    case .bold: .bold
    }
}

private struct PreviewPlaybackControls: View {
    @EnvironmentObject private var project: ProjectDocument

    var body: some View {
        ZStack {
            HStack(spacing: EditorTheme.space4) {
                playbackButton(
                    systemImage: "backward.end.fill",
                    label: "Previous"
                ) {
                    project.jumpToPreviousPreviewItem()
                }

                playbackButton(
                    systemImage: "stop.fill",
                    label: "Stop"
                ) {
                    project.stopPlayback()
                }

                playbackButton(
                    systemImage: project.isPlaying ? "pause.fill" : "play.fill",
                    label: project.isPlaying ? "Pause" : "Play",
                    isPrimary: true
                ) {
                    project.togglePlayback()
                }

                playbackButton(
                    systemImage: "forward.end.fill",
                    label: "Next"
                ) {
                    project.jumpToNextPreviewItem()
                }
            }
            .frame(maxWidth: .infinity)

            HStack {
                Spacer()
                PreviewRateMenu()
            }
            .padding(.horizontal, EditorTheme.panelPaddingX)
        }
        .frame(height: PreviewLayout.playbackHeight)
        .frame(maxWidth: .infinity)
        .background(EditorTheme.panelHeader)
        .overlay(alignment: .top) {
            Divider()
                .overlay(EditorTheme.borderSubtle)
        }
    }

    private func playbackButton(
        systemImage: String,
        label: String,
        isPrimary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
        }
        .buttonStyle(PreviewPlaybackButtonStyle(isPrimary: isPrimary))
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct PreviewPlaybackButtonStyle: ButtonStyle {
    var isPrimary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: isPrimary ? 16 : 15, weight: .semibold))
            .foregroundStyle(isPrimary ? EditorTheme.textPrimary : EditorTheme.textSecondary)
            .frame(width: EditorTheme.iconButtonSize, height: EditorTheme.iconButtonSize)
            .background(configuration.isPressed ? EditorTheme.surfacePressed : (isPrimary ? EditorTheme.surfaceControl : Color.clear))
            .clipShape(RoundedRectangle(cornerRadius: EditorTheme.controlRadius))
            .overlay {
                if isPrimary {
                    RoundedRectangle(cornerRadius: EditorTheme.controlRadius)
                        .stroke(EditorTheme.borderSubtle, lineWidth: 1)
                }
            }
    }
}

private struct PreviewRateMenu: View {
    @EnvironmentObject private var project: ProjectDocument

    var body: some View {
        Menu {
            ForEach([1, 2, 4, 8], id: \.self) { rate in
                Button {
                    project.setPlaybackRate(Double(rate))
                } label: {
                    if Int(project.playbackRate) == rate {
                        Label("\(rate)x", systemImage: "checkmark")
                    } else {
                        Text("\(rate)x")
                    }
                }
            }
        } label: {
            HStack(spacing: EditorTheme.space1) {
                Text("\(Int(project.playbackRate))x")
                    .font(EditorTheme.numericFont)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(EditorTheme.textSecondary)
            .frame(minWidth: 54, minHeight: EditorTheme.iconButtonSize)
            .padding(.horizontal, EditorTheme.space2)
            .background(EditorTheme.surfaceControl)
            .clipShape(RoundedRectangle(cornerRadius: EditorTheme.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: EditorTheme.controlRadius)
                    .stroke(EditorTheme.borderSubtle, lineWidth: 1)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Playback Speed")
        .accessibilityLabel("Playback Speed")
    }
}

private struct PreviewSafetyGuidesView: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let guideColor = EditorTheme.accentBlue
            ZStack {
                Rectangle()
                    .stroke(guideColor.opacity(0.42), lineWidth: max(size.width / 900, 1))
                    .padding(.horizontal, size.width * 0.05)
                    .padding(.vertical, size.height * 0.05)

                Rectangle()
                    .stroke(guideColor.opacity(0.28), lineWidth: max(size.width / 1200, 1))
                    .padding(.horizontal, size.width * 0.10)
                    .padding(.vertical, size.height * 0.10)

                Path { path in
                    path.move(to: CGPoint(x: size.width / 2, y: 0))
                    path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                    path.move(to: CGPoint(x: 0, y: size.height / 2))
                    path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                }
                .stroke(guideColor.opacity(0.22), lineWidth: max(size.width / 1500, 1))
            }
        }
    }
}

private extension ProjectResolution {
    var widthRatio: CGFloat {
        CGFloat(width) / CGFloat(height)
    }
}

struct DistanceTimelineOverlayView: View {
    let element: OverlayElement
    let layout: OverlayDistanceTimelineRenderLayout
    let isSelected: Bool

    var body: some View {
        ZStack {
            if element.style.backgroundEnabled {
                let background = backgroundLocalRect
                OverlayFeatheredBackground(
                    isSelected: false,
                    backgroundEnabled: element.style.backgroundEnabled,
                    color: Color(element.style.backgroundColor),
                    opacity: element.style.backgroundOpacity,
                    cornerRadius: layout.cornerRadius,
                    fadeEnabled: element.style.backgroundFadeOutEnabled,
                    fadeAmount: element.style.backgroundFadeOutAmount,
                    blurRadius: element.style.backgroundBlurRadius
                )
                    .frame(width: background.width, height: background.height)
                    .position(x: background.midX, y: background.midY)
            }

            if element.style.borderEnabled {
                let background = backgroundLocalRect
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .stroke(Color(element.style.borderColor).opacity(element.style.borderOpacity), lineWidth: element.style.borderWidth)
                    .frame(width: background.width, height: background.height)
                    .position(x: background.midX, y: background.midY)
            }

            if let mediaSlotRect = layout.mediaSlotRect {
                let local = localRect(mediaSlotRect)
                ZStack {
                    RoundedRectangle(cornerRadius: local.width * 0.28)
                        .fill(Color(distanceTimeline: layout.style.fillColor).opacity(0.18))
                    DistanceTimelineMediaSlotView(
                        style: layout.style,
                        size: local.size,
                        elapsedTime: layout.elapsedTime,
                        accentColor: layout.style.fillColor,
                        textColor: element.style.foregroundColor
                    )
                }
                .frame(width: local.width, height: local.height)
                .position(x: local.midX, y: local.midY)
            }

            if layout.style.preset == .route, layout.style.elevationProfileVisible {
                elevationProfile
                    .fill(Color(distanceTimeline: layout.style.fillColor).opacity(0.16))
                    .frame(width: localRect(layout.contentRect).width, height: localRect(layout.contentRect).height * 0.30)
                    .position(x: localRect(layout.contentRect).midX, y: localRect(layout.contentRect).maxY - localRect(layout.contentRect).height * 0.22)
            }

            valueLayer
            progressLayer

            if layout.style.showAxisLabels || layout.style.showDistancePoints {
                axisLabels
            }

            if layout.style.markerDistanceLabelEnabled, layout.style.currentMarkerEnabled {
                markerDistanceLabelLayer
            }

            if layout.style.statsBar.visible {
                statsBar
            }

            if isSelected {
                let selection = backgroundLocalRect
                RoundedRectangle(cornerRadius: 4)
                    .stroke(EditorTheme.accentBlue.opacity(0.92), lineWidth: 1.4)
                    .frame(width: selection.width + 10, height: selection.height + 10)
                    .position(x: selection.midX, y: selection.midY)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: layout.rect.width, height: layout.rect.height)
        .overlayLayeredShadow(
            color: Color(element.style.shadowColor),
            isEnabled: element.style.shadowEnabled,
            opacity: element.style.shadowOpacity,
            radius: element.style.shadowRadius,
            x: element.style.shadowOffsetX,
            y: element.style.shadowOffsetY,
            thickness: element.style.shadowThickness
        )
        .overlayForegroundGlow(element: element)
        .opacity(layout.style.fadeEnabled ? max(1 - layout.style.fadeAmount * 0.35, 0.72) : 1)
    }

    private var backgroundLocalRect: CGRect {
        let padX = scaled(element.style.backgroundPaddingX)
        let padY = scaled(element.style.backgroundPaddingY)
        var rect = localRect(layout.distanceTimelineContentBounds()).insetBy(dx: -padX, dy: -padY)
        if layout.style.statsBar.visible,
           layout.style.statsBar.inside,
           let statsRect = statsBarDisplayRect {
            rect = rect.union(statsRect.insetBy(dx: -padX, dy: -padY))
        }
        return rect
    }

    private var valueLayer: some View {
        let content = localRect(layout.contentRect)
        let valueSlotHeight = max(layout.trackRect.minY - layout.contentRect.minY - 2, layout.valueFontSize * 1.2)
        return VStack(alignment: .leading, spacing: scaled(layout.style.labelValueSpacing)) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if layout.style.showLabel {
                    Text(layout.label.uppercased())
                        .font(.overlayFont(family: layout.style.labelFontName, size: layout.labelFontSize, weight: Font.Weight(layout.style.labelFontWeight)))
                        .foregroundStyle(Color(distanceTimeline: layout.style.labelColor))
                }
                Spacer(minLength: 6)
            }
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                if layout.style.showValue {
                    Text(layout.valueText)
                        .font(.overlayFont(family: element.style.fontName, size: valueFontSize, weight: valueWeight))
                        .foregroundStyle(valueColor)
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                if !layout.customValues.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: scaled(layout.style.customValueSpacing)) {
                        ForEach(Array(layout.customValues.enumerated()), id: \.offset) { _, item in
                            Text(item.value.isEmpty ? item.label : item.value)
                                .font(.overlayFont(family: element.style.fontName, size: scaled(layout.style.customValueFontSize), weight: .semibold))
                                .foregroundStyle(Color(distanceTimeline: layout.style.customValueColor).opacity(layout.style.customValueOpacity))
                                .monospacedDigit()
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    .padding(.leading, layout.style.showValue ? scaled(layout.style.customValuesGroupSpacing) : 0)
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: content.width, height: valueSlotHeight, alignment: .topLeading)
        .position(x: content.midX, y: content.minY + valueSlotHeight / 2)
    }

    private var progressLayer: some View {
        let track = localRect(layout.trackRect)
        return ZStack(alignment: .leading) {
            trackShape
                .fill(trackColor)
            if layout.style.preset == .route {
                routePath(points: layout.routePoints.map(localPoint))
                    .stroke(trackColor, style: StrokeStyle(lineWidth: max(track.height, 2), lineCap: .round, lineJoin: .round))
                routePath(points: progressedRoutePoints.map(localPoint))
                    .stroke(accentColor, style: StrokeStyle(lineWidth: max(track.height, 2), lineCap: .round, lineJoin: .round))
            } else {
                trackShape
                    .fill(accentColor)
                    .frame(width: max(track.width * layout.progress, track.height))
                    .shadow(color: glowColor, radius: layout.style.glowEnabled ? track.height * 2.8 : 0)
            }

            if layout.style.tickMarksEnabled {
                tickMarks(in: track.size)
                    .stroke(labelColor.opacity(0.52), lineWidth: 1)
            }

            if layout.style.currentMarkerEnabled {
                let markerPoint = markerPointInTrackLocal(track: track)
                markerView
                    .frame(width: markerSize.width, height: markerSize.height)
                    .shadow(color: glowColor, radius: layout.style.glowEnabled ? track.height * 2.3 : 0)
                    .position(x: markerPoint.x, y: markerPoint.y)
            }
        }
        .frame(width: track.width, height: track.height)
        .position(x: track.midX, y: track.midY)
    }

    private func markerPointInTrackLocal(track: CGRect) -> CGPoint {
        if layout.style.preset == .route {
            localPoint(layout.routeCurrentPoint ?? progressedRoutePoints.last ?? CGPoint(x: layout.trackRect.minX + layout.trackRect.width * layout.progress, y: layout.trackRect.midY))
        } else {
            CGPoint(x: max(track.width * layout.progress, 0), y: track.height * 0.5)
        }
    }

    private func markerDisplayPoint(track: CGRect) -> CGPoint {
        let lp = markerPointInTrackLocal(track: track)
        return CGPoint(x: track.minX + lp.x, y: track.minY + lp.y)
    }

    private var markerDistanceLabelLayer: some View {
        let track = localRect(layout.trackRect)
        let textH = CGFloat(layout.unitFontSize * 1.3)
        let gap = CGFloat(scaled(layout.style.markerDistanceLabelOffset))
        let yCenter = layout.style.distanceTimelineAxisLabelTextTopY(
            trackRect: track,
            placement: layout.style.markerDistanceLabelPlacement,
            scaledGap: gap,
            textLineHeight: textH
        ) + textH / 2
        let pt = markerDisplayPoint(track: track)
        let axisFont = Font.overlayFont(family: layout.style.axisLabelFontName, size: layout.unitFontSize, weight: Font.Weight(layout.style.axisLabelFontWeight))
        return Text(layout.markerDistanceText)
            .font(axisFont)
            .foregroundStyle(Color(distanceTimeline: layout.style.axisLabelColor))
            .monospacedDigit()
            .lineLimit(1)
            .position(x: pt.x, y: yCenter)
            .frame(width: layout.rect.width, height: layout.rect.height)
    }

    private var axisLabels: some View {
        let track = localRect(layout.trackRect)
        let textH = CGFloat(layout.unitFontSize * 1.3)
        let axisFont = Font.overlayFont(family: layout.style.axisLabelFontName, size: layout.unitFontSize, weight: Font.Weight(layout.style.axisLabelFontWeight))
        let axisColor = Color(distanceTimeline: layout.style.axisLabelColor)
        return ZStack {
            if layout.style.showAxisLabels {
                let gap = CGFloat(scaled(layout.style.distancePointOffset))
                let yEndpointsCenter = layout.style.distanceTimelineAxisLabelTextTopY(
                    trackRect: track,
                    placement: layout.style.axisEndpointLabelPlacement,
                    scaledGap: gap,
                    textLineHeight: textH
                ) + textH / 2
                HStack(spacing: 0) {
                    Text(layout.startText)
                        .font(axisFont)
                        .foregroundStyle(axisColor)
                        .frame(width: track.width / 2, alignment: .leading)
                    Text(layout.finishText)
                        .font(axisFont)
                        .foregroundStyle(axisColor)
                        .frame(width: track.width / 2, alignment: .trailing)
                }
                .frame(width: track.width)
                .position(x: track.midX, y: yEndpointsCenter)
            }
            if layout.style.showDistancePoints, !layout.distancePointLabels.isEmpty {
                let gapMid = CGFloat(scaled(layout.style.midpointAxisLabelOffset))
                let yMidpointsCenter = layout.style.distanceTimelineAxisLabelTextTopY(
                    trackRect: track,
                    placement: layout.style.axisMidpointLabelPlacement,
                    scaledGap: gapMid,
                    textLineHeight: textH
                ) + textH / 2
                ForEach(Array(layout.distancePointLabels.enumerated()), id: \.offset) { index, label in
                    let denominator = Double(layout.distancePointLabels.count + 1)
                    let x = track.width * Double(index + 1) / denominator
                    Text(label)
                        .font(axisFont)
                        .foregroundStyle(axisColor)
                        .monospacedDigit()
                        .position(x: track.minX + x, y: yMidpointsCenter)
                }
            }
        }
        .frame(width: layout.rect.width, height: layout.rect.height)
    }

    private var statsBar: some View {
        guard let rect = statsBarDisplayRect else {
            return AnyView(EmptyView())
        }
        let config = layout.style.statsBar
        return AnyView(
            SharedStatsBarContentView(
                items: layout.statsBarItems.map { .init(value: $0.value, unit: $0.unit, label: $0.label) },
                stacked: config.placement.isVertical || config.layoutMode == .stack,
                itemSpacing: scaled(config.itemSpacing),
                dividerOpacity: config.dividerOpacity,
                cornerRadius: config.cornerRadius,
                backgroundOpacity: config.backgroundOpacity,
                valueFontName: config.valueFontName,
                valueFontWeight: config.valueFontWeight,
                valueColor: Color(config.valueColor),
                labelFontName: config.labelFontName,
                labelFontWeight: config.labelFontWeight,
                labelColor: Color(config.labelColor),
                valueFontSize: scaled(config.valueFontSize),
                labelFontSize: scaled(config.labelFontSize)
            )
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
        )
    }

    private var trackShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: layout.trackRect.height / 2)
    }

    private var valueFontSize: Double {
        switch layout.style.preset {
        case .lowerThird: layout.valueFontSize * 1.05
        case .sport: layout.valueFontSize * 1.12
        case .dense: layout.valueFontSize * 0.86
        default: layout.valueFontSize
        }
    }

    private var valueWeight: Font.Weight {
        switch layout.style.preset {
        case .dense, .neon: .medium
        default: .bold
        }
    }

    private var valueColor: Color {
        layout.style.preset == .neon ? Color.white.opacity(0.92) : Color(distanceTimeline: element.style.foregroundColor)
    }

    private var labelColor: Color {
        layout.style.preset == .neon ? accentColor.opacity(0.86) : Color(distanceTimeline: element.style.foregroundColor).opacity(0.64)
    }

    private var accentColor: Color {
        Color(distanceTimeline: layout.style.fillColor)
    }

    private var markerColor: Color {
        Color(distanceTimeline: layout.style.currentMarkerColor)
    }

    private var markerSize: CGSize {
        let track = localRect(layout.trackRect)
        let m = layout.style.currentMarkerSizeMultiplier
        return switch layout.style.currentMarkerStyle {
        case .dot:
            CGSize(width: track.height * 2.2 * m, height: track.height * 2.2 * m)
        case .pill:
            CGSize(width: track.height * 3.4 * m, height: track.height * 1.75 * m)
        case .triangle:
            CGSize(width: track.height * 2.6 * m, height: track.height * 2.4 * m)
        }
    }

    @ViewBuilder
    private var markerView: some View {
        switch layout.style.currentMarkerStyle {
        case .dot:
            Circle().fill(markerColor)
        case .pill:
            Capsule().fill(markerColor)
        case .triangle:
            DistanceTimelineTriangleMarkerShape().fill(markerColor)
        }
    }

    private var trackColor: Color {
        Color(distanceTimeline: element.style.foregroundColor).opacity(layout.style.trackOpacity)
    }

    private var glowColor: Color {
        accentColor.opacity(0.75)
    }

    private func localRect(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX - layout.rect.minX, y: rect.minY - layout.rect.minY, width: rect.width, height: rect.height)
    }

    private func localPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - layout.trackRect.minX, y: point.y - layout.trackRect.minY)
    }

    private var statsBarDisplayRect: CGRect? {
        layout.distanceTimelineStatsBarRect().map(localRect)
    }

    private var styleScale: Double {
        layout.distanceTimelineStyleScale
    }

    private func scaled(_ value: Double) -> Double {
        value * styleScale
    }

    private var progressedRoutePoints: [CGPoint] {
        guard layout.routePoints.count > 1 else {
            let track = layout.trackRect
            return [
                CGPoint(x: track.minX, y: track.minY + track.height * 0.70),
                CGPoint(x: track.minX + track.width * layout.progress, y: track.minY + track.height * 0.36)
            ]
        }
        let targetCount = max(Int((Double(layout.routePoints.count - 1) * layout.progress).rounded(.down)) + 1, 1)
        var points = Array(layout.routePoints.prefix(min(targetCount, layout.routePoints.count)))
        if let current = layout.routeCurrentPoint, points.last != current {
            points.append(current)
        }
        return points
    }

    private func routePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else {
            let track = localRect(layout.trackRect)
            path.move(to: CGPoint(x: 0, y: track.height * 0.70))
            path.addCurve(
                to: CGPoint(x: track.width * layout.progress, y: track.height * 0.36),
                control1: CGPoint(x: track.width * 0.25, y: -track.height * 0.4),
                control2: CGPoint(x: track.width * 0.58, y: track.height * 1.6)
            )
            return path
        }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private func tickMarks(in size: CGSize) -> Path {
        var path = Path()
        let count = max(layout.style.tickDensity, 2)
        for index in 0...count {
            let x = size.width * Double(index) / Double(max(count, 1))
            path.move(to: CGPoint(x: x, y: -size.height * 0.45))
            path.addLine(to: CGPoint(x: x, y: size.height * 1.45))
        }
        return path
    }

    private var elevationProfile: Path {
        var path = Path()
        let samples = layout.elevationSamples
        guard samples.count > 1 else { return path }
        let minValue = samples.min() ?? 0
        let maxValue = samples.max() ?? minValue
        let range = max(maxValue - minValue, 1)
        let width = localRect(layout.contentRect).width
        let height = localRect(layout.contentRect).height * 0.30
        path.move(to: CGPoint(x: 0, y: height))
        for index in samples.indices {
            let x = width * Double(index) / Double(max(samples.count - 1, 1))
            let normalized = (samples[index] - minValue) / range
            let y = height - height * normalized
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        return path
    }
}

private struct DistanceTimelineMediaSlotView: View {
    let style: DistanceTimelineStyle
    let size: CGSize
    let elapsedTime: TimeInterval
    let accentColor: OverlayColor
    let textColor: OverlayColor

    var body: some View {
        let slot = style.mediaSlot
        Group {
            if (slot.mode == .staticSVG || slot.mode == .animatedSVG),
               let image = OverlayIconRenderer.image(
                slot: slot,
                size: size,
                elapsedTime: elapsedTime,
                tintColor: NSColor(previewOverlay: slot.tintMode == .text ? textColor : accentColor)
               ) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: slot.systemImage.isEmpty ? style.mediaSystemImage : slot.systemImage)
                    .font(.system(size: size.width * 0.48, weight: .semibold))
                    .foregroundStyle(Color(distanceTimeline: slot.tintMode == .text ? textColor : accentColor))
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

private struct DistanceTimelineTriangleMarkerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct ElevationChartOverlayView: View {
    let element: OverlayElement
    let layout: OverlayElevationChartRenderLayout

    var body: some View {
        ZStack {
            if element.style.backgroundEnabled {
                OverlayFeatheredBackground(
                    isSelected: false,
                    backgroundEnabled: element.style.backgroundEnabled,
                    color: Color(element.style.backgroundColor),
                    opacity: element.style.backgroundOpacity,
                    cornerRadius: sharedBackgroundCornerRadius,
                    fadeEnabled: element.style.backgroundFadeOutEnabled,
                    fadeAmount: element.style.backgroundFadeOutAmount,
                    blurRadius: element.style.backgroundBlurRadius
                )
                .frame(width: backgroundLocalRect.width, height: backgroundLocalRect.height)
                .position(x: backgroundLocalRect.midX, y: backgroundLocalRect.midY)
            }
            if element.style.borderEnabled {
                RoundedRectangle(cornerRadius: sharedBackgroundCornerRadius)
                    .stroke(Color(element.style.borderColor).opacity(element.style.borderOpacity), lineWidth: element.style.borderWidth)
                    .frame(width: backgroundLocalRect.width, height: backgroundLocalRect.height)
                    .position(x: backgroundLocalRect.midX, y: backgroundLocalRect.midY)
            }

            VStack(alignment: .leading, spacing: layout.verticalPadding) {
                if layout.style.bigNumbersEnabled {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(layout.bigNumberText.value)
                            .font(.overlayFont(family: layout.style.bigNumberFontName, size: layout.valueFontSize, overlayWeight: layout.style.bigNumberFontWeight))
                            .foregroundStyle(Color(element.style.foregroundColor))
                            .monospacedDigit()
                        Text(layout.bigNumberText.unit)
                            .font(.overlayFont(family: layout.style.bigNumberFontName, size: layout.unitFontSize, overlayWeight: layout.style.bigNumberFontWeight))
                            .foregroundStyle(Color(element.style.foregroundColor).opacity(0.86))
                        Text(layout.bigNumberText.shortLabel)
                            .font(.overlayFont(family: layout.style.bigNumberFontName, size: layout.labelFontSize, weight: .medium))
                            .foregroundStyle(Color(element.style.foregroundColor).opacity(0.62))
                            .padding(.leading, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        if layout.style.gridEnabled {
                            gridPath(in: proxy.size)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        }
                        if layout.style.axisLineEnabled {
                            axisLine(in: proxy.size)
                                .stroke(Color(element.style.foregroundColor).opacity(0.22), lineWidth: 1)
                        }
                        if layout.style.fillEnabled && layout.style.chartStyle == .area {
                            if layout.style.dualAreaEnabled {
                                areaPath(in: proxy.size)
                                    .fill(elevationFillGradient(start: layout.style.upperFillColor, end: layout.style.fillEndColor))
                                areaPath(in: proxy.size)
                                    .fill(elevationFillGradient(start: layout.style.lowerFillColor, end: layout.style.fillEndColor))
                                    .mask(alignment: .leading) {
                                        Rectangle()
                                            .frame(width: proxy.size.width * max(0, min(1, 1 - layout.progress)))
                                            .offset(x: proxy.size.width * max(0, min(1, layout.progress)))
                                    }
                            } else {
                                areaPath(in: proxy.size)
                                    .fill(elevationFillGradient(start: layout.style.fillStartColor, end: layout.style.fillEndColor))
                            }
                        }
                        if layout.style.glowEnabled {
                            chartPath(in: proxy.size)
                                .stroke(Color(layout.style.lineColor).opacity(layout.style.glowOpacity), style: StrokeStyle(lineWidth: layout.lineWidth + 7, lineCap: .round, lineJoin: .round))
                                .blur(radius: 5)
                        }
                        chartPath(in: proxy.size)
                            .stroke(Color(layout.style.lineColor).opacity(layout.style.lineOpacity), style: StrokeStyle(lineWidth: layout.lineWidth, lineCap: .round, lineJoin: .round))
                        if layout.style.currentMarkerEnabled {
                            marker(in: proxy.size)
                        }
                        if layout.style.axisLabelsEnabled {
                            axisLabels(in: proxy.size)
                        }
                    }
                }
                .frame(height: layout.chartHeight)
            }
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.vertical, layout.verticalPadding)
            .frame(width: layout.rect.width, height: layout.rect.height, alignment: .topLeading)

            if let statsBar = layout.statsBarLayout {
                statsBarContent(statsBar)
                    .frame(width: statsBar.rect.width, height: statsBar.rect.height)
                    .position(x: statsBar.rect.midX, y: statsBar.rect.midY)
            }
        }
        .frame(width: layout.rect.width, height: layout.rect.height)
        .overlayLayeredShadow(
            color: Color(element.style.shadowColor),
            isEnabled: element.style.shadowEnabled,
            opacity: element.style.shadowOpacity,
            radius: element.style.shadowRadius,
            x: element.style.shadowOffsetX,
            y: element.style.shadowOffsetY,
            thickness: element.style.shadowThickness
        )
        .overlayForegroundGlow(element: element)
    }

    private var backgroundLocalRect: CGRect {
        let padX = element.style.backgroundPaddingX * element.scale
        let padY = element.style.backgroundPaddingY * element.scale
        return CGRect(
            x: -padX,
            y: -padY,
            width: layout.rect.width + padX * 2,
            height: layout.rect.height + padY * 2
        )
    }

    private var sharedBackgroundCornerRadius: Double {
        element.style.backgroundRadius * element.scale
    }

    private func statsBarContent(_ statsBar: OverlayElevationChartStatsBarLayout) -> some View {
        SharedStatsBarContentView(
            items: statsBar.items.map { .init(value: $0.value, unit: $0.unit, label: $0.label) },
            stacked: statsBar.stacked,
            itemSpacing: statsBar.itemSpacing,
            dividerOpacity: statsBar.dividerOpacity,
            cornerRadius: statsBar.cornerRadius,
            backgroundOpacity: statsBar.backgroundOpacity,
            valueFontName: statsBar.valueFontName,
            valueFontWeight: statsBar.valueFontWeight,
            valueColor: Color(statsBar.valueColor),
            labelFontName: statsBar.labelFontName,
            labelFontWeight: statsBar.labelFontWeight,
            labelColor: Color(statsBar.labelColor),
            valueFontSize: statsBar.valueFontSize,
            labelFontSize: statsBar.labelFontSize
        )
    }

    private func elevationFillGradient(start: OverlayColor, end: OverlayColor) -> LinearGradient {
        LinearGradient(
            colors: [
                Color(start).opacity(layout.style.fillOpacity),
                Color(end).opacity(max(layout.style.fillOpacity * 0.15, 0.04))
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func chartPath(in size: CGSize) -> Path {
        var path = Path()
        let points = chartPoints(in: size)
        guard points.count > 1 else {
            path.move(to: CGPoint(x: 0, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            return path
        }

        path.move(to: points[0])
        guard layout.style.smoothingEnabled, points.count > 2 else {
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            return path
        }

        for index in 0..<(points.count - 1) {
            let start = points[index]
            let end = points[index + 1]
            let previous = index > 0 ? points[index - 1] : start
            let next = index + 2 < points.count ? points[index + 2] : end
            path.addCurve(
                to: end,
                control1: CGPoint(
                    x: start.x + (end.x - previous.x) / 6,
                    y: start.y + (end.y - previous.y) / 6
                ),
                control2: CGPoint(
                    x: end.x - (next.x - start.x) / 6,
                    y: end.y - (next.y - start.y) / 6
                )
            )
        }

        return path
    }

    private func areaPath(in size: CGSize) -> Path {
        var path = chartPath(in: size)
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }

    private func marker(in size: CGSize) -> some View {
        let point = chartPoint(at: layout.progress, in: size)
        return ZStack {
            if showsMarkerPlayheadLine(at: point) {
                VerticalDashedLine()
                    .stroke(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .frame(width: 1, height: size.height)
                    .position(x: point.x, y: size.height / 2)
            }
            Circle()
                .fill(Color(layout.style.markerColor).opacity(0.24))
                .frame(width: 27, height: 27)
                .blur(radius: 6)
                .position(point)
            Circle()
                .fill(Color(layout.style.markerColor))
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(Color.white.opacity(0.95), lineWidth: 2).frame(width: 13, height: 13))
                .position(point)
            if layout.style.markerLabelEnabled {
                Text(markerLabelText)
                    .font(.overlayFont(family: element.style.fontName, size: max(layout.labelFontSize * 0.92, 10), weight: .semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.black.opacity(0.68))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.16), lineWidth: 1))
                    )
                    .position(x: min(max(point.x, 28), size.width - 28), y: max(point.y - 25, 12))
            }
        }
    }

    private var markerLabelText: String {
        layout.label.replacingOccurrences(of: "Elevation ", with: "")
    }

    private func showsMarkerPlayheadLine(at point: CGPoint) -> Bool {
        guard layout.style.markerPlayheadLineEnabled, !layout.style.bigNumbersEnabled else { return false }
        // Hide the playhead guide on the chart's left edge so it does not duplicate
        // (or masquerade as) the optional Y-axis line.
        return point.x > 1.5
    }

    private func axisLabels(in size: CGSize) -> some View {
        let minValue = layout.samples.min() ?? 0
        let maxValue = layout.samples.max() ?? minValue
        return ZStack {
            Text("\(Int(maxValue.rounded()))")
                .position(x: 14, y: 8)
            Text("\(Int(minValue.rounded()))")
                .position(x: 10, y: size.height - 8)
            Text("m")
                .position(x: size.width - 10, y: 8)
        }
        .font(.overlayFont(family: element.style.fontName, size: max(layout.labelFontSize * 0.78, 8), weight: .medium))
        .foregroundStyle(Color(element.style.foregroundColor).opacity(0.58))
    }

    private func gridPath(in size: CGSize) -> Path {
        var path = Path()
        for fraction in [0.25, 0.5, 0.75] {
            let y = size.height * fraction
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }
        return path
    }

    private func axisLine(in size: CGSize) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        return path
    }

    private func chartPoint(at progress: Double, in size: CGSize) -> CGPoint {
        let points = chartPoints(in: size)
        guard !points.isEmpty else {
            return CGPoint(x: size.width * progress, y: size.height / 2)
        }
        let index = min(max(Int((Double(points.count - 1) * progress).rounded()), 0), points.count - 1)
        return points[index]
    }

    private func chartPoints(in size: CGSize) -> [CGPoint] {
        guard !layout.samples.isEmpty else { return [] }
        let minValue = layout.samples.min() ?? 0
        let maxValue = layout.samples.max() ?? minValue
        let range = max(maxValue - minValue, 1)
        return layout.samples.indices.map { index in
            let x = size.width * CGFloat(index) / CGFloat(max(layout.samples.count - 1, 1))
            let y = size.height - size.height * CGFloat((layout.samples[index] - minValue) / range)
            return CGPoint(x: x, y: y)
        }
    }
}

private struct VerticalDashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

private extension Color {
    init(distanceTimeline overlayColor: OverlayColor) {
        self.init(overlayColor)
    }

    init(_ overlayColor: OverlayColor) {
        self.init(
            red: overlayColor.red,
            green: overlayColor.green,
            blue: overlayColor.blue,
            opacity: overlayColor.alpha
        )
    }
}

private extension NSColor {
    convenience init(previewOverlay color: OverlayColor) {
        self.init(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }
}

private extension Font.Weight {
    init(_ overlayWeight: OverlayFontWeight) {
        switch overlayWeight {
        case .regular:
            self = .regular
        case .medium:
            self = .medium
        case .semibold:
            self = .semibold
        case .bold:
            self = .bold
        }
    }
}
