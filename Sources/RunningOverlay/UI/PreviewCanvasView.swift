import AppKit
import CoreText
import SwiftUI

enum PreviewFitMode: Hashable, CaseIterable {
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
    @State private var draggingElementID: OverlayElement.ID?
    // Briefly marks a locked overlay the user clicked, since it cannot be selected.
    @State private var lockedFeedback: (id: OverlayElement.ID, token: Int)?
    @State private var lockedFeedbackToken = 0

    #if DEBUG && canImport(CSkiaBridge)
    /// Debug-only comparison override; product builds always use Skia.
    @State private var usesSkiaPreview: Bool
    #endif

    init() {
        #if DEBUG && canImport(CSkiaBridge)
        _usesSkiaPreview = State(
            initialValue: OverlayRendererBackendKind.selected == .skia
        )
        #endif
    }

    var body: some View {
        GeometryReader { proxy in
            let canvasAvailableSize = CGSize(
                width: proxy.size.width,
                height: max(proxy.size.height - PreviewLayout.headerHeight - PreviewLayout.playbackHeight, 0)
            )
            let canvasSize = fittedCanvasSize(in: canvasAvailableSize)
            let frames = activeOverlayFrames(canvasSize: canvasSize)
            VStack(spacing: 0) {
                PreviewHeader(
                    usesSkiaPreview: isSkiaPreviewActive,
                    onToggleSkiaPreview: skiaToggleAction
                )

                ZStack {
                    ZStack {
                        Rectangle()
                            .fill(project.previewCanvasBackground)

                        if let previewMedia = project.activePreviewMedia() {
                            VideoPreviewPlayerView(
                                previewMedia: previewMedia,
                                isPlaying: project.isPlaying,
                                playbackRate: project.playbackRate,
                                seekToken: project.playbackSeekToken,
                                fitMode: project.previewFitMode
                            ) { [seekToken = project.playbackSeekToken] activityTime in
                                if project.isPreviewingMediaPoolItem {
                                    project.setMediaPoolPreviewSourceTime(activityTime)
                                } else {
                                    project.setPlayheadFromPlayback(activityTime, seekToken: seekToken)
                                }
                            }
                        } else {
                            PreviewEmptyState(
                                hint: PreviewEmptyState.hint(hasMedia: !project.mediaItems.isEmpty)
                            )
                        }

                        #if canImport(CSkiaBridge)
                        if isSkiaPreviewActive {
                            // Transparent overlay canvas composited above the
                            // video layer. Selection and drag affordances stay
                            // in SwiftUI above this view.
                            SkiaPreviewCanvasView(
                                layout: skiaPreviewLayout,
                                activity: project.activity,
                                elapsedTime: project.layerDataSampleTime,
                                canvasSize: projectCanvasPixelSize,
                                weatherPayload: project.weatherPayloadForComponents,
                                isPaused: !project.isPlaying
                            )
                            .frame(width: canvasSize.width, height: canvasSize.height)
                            .allowsHitTesting(false)
                        }
                        #endif

                        if project.showPreviewGuides {
                            PreviewSafetyGuidesView()
                                .allowsHitTesting(false)

                        }

                        PreviewSnapLinesView(lines: activeSnapLines)
                            .allowsHitTesting(false)

                        if isSkiaPreviewActive {
                            skiaOverlayLayer(canvasSize: canvasSize, frames: frames)
                        } else {
                            swiftUIOverlayLayer(canvasSize: canvasSize, frames: frames)
                        }

                        if let lockedFeedback, let frame = frames[lockedFeedback.id] {
                            PreviewLockedMark()
                                .position(x: frame.maxX, y: frame.minY)
                                .allowsHitTesting(false)
                                .transition(.opacity)
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
                                handleCanvasTap(at: value.location, frames: frames)
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

    private func handleCanvasTap(
        at location: CGPoint,
        frames: [OverlayElement.ID: CGRect]
    ) {
        let visibleElementIDs = Set(project.overlayLayout.elements.filter(\.isVisible).map(\.id))
        if !visibleElementIDs.isEmpty && frames.isEmpty {
            return
        }

        let didHitOverlay = PreviewCanvasHitTesting.isOverlayHit(
            at: location,
            frames: frames,
            visibleElementIDs: visibleElementIDs
        )

        guard !didHitOverlay else { return }
        project.clearMediaPoolPreview()
        project.clearSelection()
    }

    // MARK: - Overlay rendering layers

    /// Shipping SwiftUI overlay layer. Elements are real SwiftUI views and their
    /// measured frames drive snapping and hit testing.
    @ViewBuilder
    private func swiftUIOverlayLayer(
        canvasSize: CGSize,
        frames: [OverlayElement.ID: CGRect]
    ) -> some View {
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
            .gesture(overlayDragGesture(for: element, canvasSize: canvasSize, frames: frames))
            .modifier(PreviewOverlayPointerModifier(
                pointer: .resolve(isLocked: element.isLocked, isDragging: draggingElementID == element.id)
            ))
            .onTapGesture {
                handleOverlayTap(element)
            }
            .contextMenu {
                OverlayElementContextMenu(element: element)
            }
        }
    }

    /// Skia overlay layer: pixels come from `SkiaPreviewCanvasView`; this layer
    /// keeps SwiftUI selection and drag affordances above it. Hit shapes come
    /// from `OverlayRenderModel` rects rather than view measurement.
    @ViewBuilder
    private func skiaOverlayLayer(
        canvasSize: CGSize,
        frames: [OverlayElement.ID: CGRect]
    ) -> some View {
        if let selectedID = project.selectedOverlayID,
           let frame = frames[selectedID] {
            PreviewSelectionAffordance()
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .allowsHitTesting(false)
        }

        ForEach(project.overlayLayout.elements.filter(\.isVisible)) { element in
            let hitFrame = (frames[element.id] ?? .zero).insetBy(dx: -4, dy: -4)
            Color.clear
                .frame(width: max(hitFrame.width, 12), height: max(hitFrame.height, 12))
                .contentShape(Rectangle())
                .position(x: hitFrame.midX, y: hitFrame.midY)
                .gesture(overlayDragGesture(for: element, canvasSize: canvasSize, frames: frames))
                .modifier(PreviewOverlayPointerModifier(
                    pointer: .resolve(isLocked: element.isLocked, isDragging: draggingElementID == element.id)
                ))
                .onTapGesture {
                    handleOverlayTap(element)
                }
                .contextMenu {
                    OverlayElementContextMenu(element: element)
                }
        }
    }

    private func handleOverlayTap(_ element: OverlayElement) {
        guard element.isLocked else {
            project.selectOverlay(element.id)
            return
        }
        lockedFeedbackToken &+= 1
        let token = lockedFeedbackToken
        withAnimation(.easeOut(duration: 0.12)) {
            lockedFeedback = (element.id, token)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard lockedFeedback?.token == token else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                lockedFeedback = nil
            }
        }
    }

    private func overlayDragGesture(
        for element: OverlayElement,
        canvasSize: CGSize,
        frames: [OverlayElement.ID: CGRect]
    ) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(PreviewCanvasCoordinateSpace.name))
            .onChanged { value in
                guard !element.isLocked else { return }
                // Capture start position and select exactly once per gesture.
                if dragStartPositions[element.id] == nil {
                    draggingElementID = element.id
                    dragStartPositions[element.id] = element.position
                    if element.type == .component,
                       let frame = frames[element.id] {
                        dragGrabOffsets[element.id] = CGSize(
                            width: value.startLocation.x - frame.minX,
                            height: value.startLocation.y - frame.minY
                        )
                    }
                    project.selectOverlay(element.id)
                }
                guard let start = dragStartPositions[element.id] else { return }
                let proposedPosition: CGPoint
                if element.type == .component,
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
                // Holding Command bypasses snapping for free placement.
                let isSnappingEnabled = !NSEvent.modifierFlags.contains(.command)
                let snapResult: PreviewSnapResult
                if element.type == .component {
                    snapResult = PreviewSnapResolver().snapTopLeading(
                        movingElementID: element.id,
                        proposedPosition: proposedPosition,
                        currentFrame: frames[element.id],
                        overlayFrames: frames,
                        canvasSize: canvasSize,
                        guidesEnabled: project.showPreviewGuides,
                        isSnappingEnabled: isSnappingEnabled
                    )
                } else {
                    snapResult = PreviewSnapResolver().snap(
                        movingElementID: element.id,
                        proposedPosition: proposedPosition,
                        currentFrame: frames[element.id],
                        overlayFrames: frames,
                        canvasSize: canvasSize,
                        guidesEnabled: project.showPreviewGuides,
                        isSnappingEnabled: isSnappingEnabled
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
                draggingElementID = nil
                dragStartPositions[element.id] = nil
                dragGrabOffsets[element.id] = nil
                activeSnapLines = []
                project.finishContinuousEdit()
            }
    }

    // MARK: - Skia preview state

    private var isSkiaPreviewActive: Bool {
        #if DEBUG && canImport(CSkiaBridge)
        return usesSkiaPreview
        #elseif canImport(CSkiaBridge)
        return true
        #else
        return false
        #endif
    }

    private var skiaToggleAction: (() -> Void)? {
        #if DEBUG && canImport(CSkiaBridge)
        return { usesSkiaPreview.toggle() }
        #else
        return nil
        #endif
    }

    private var projectCanvasPixelSize: CGSize {
        CGSize(
            width: CGFloat(project.settings.resolution.width),
            height: CGFloat(project.settings.resolution.height)
        )
    }

    /// The Skia canvas consumes the document layout with the live drag position
    /// applied, so rendered pixels follow the pointer before the drag commits.
    private var skiaPreviewLayout: OverlayLayout {
        guard let live = liveDragPosition else { return project.overlayLayout }
        var layout = project.overlayLayout
        guard let index = layout.elements.firstIndex(where: { $0.id == live.id }) else {
            return layout
        }
        layout.elements[index].position = live.pos
        return layout
    }

    private func activeOverlayFrames(
        canvasSize: CGSize
    ) -> [OverlayElement.ID: CGRect] {
        #if canImport(CSkiaBridge)
        if isSkiaPreviewActive {
            return skiaOverlayFrames(canvasSize: canvasSize)
        }
        #endif
        return overlayFrames
    }

    #if canImport(CSkiaBridge)
    private func skiaOverlayFrames(
        canvasSize: CGSize
    ) -> [OverlayElement.ID: CGRect] {
        let context = OverlayRenderContext(
            canvasSize: canvasSize,
            activity: project.activity,
            elapsedTime: project.layerDataSampleTime,
            weatherPayload: project.weatherPayloadForComponents
        )
        var frames: [OverlayElement.ID: CGRect] = [:]
        for element in skiaPreviewLayout.elements where element.isVisible {
            frames[element.id] = PreviewElementGeometry.frame(for: element, in: context)
        }
        return frames
    }
    #endif

}

/// Canvas tap resolution shared by both overlay rendering modes. A tap inside
/// any visible element's frame keeps the selection; a tap in empty canvas
/// clears it.
enum PreviewCanvasHitTesting {
    static let hitPadding: CGFloat = 4

    static func isOverlayHit(
        at location: CGPoint,
        frames: [OverlayElement.ID: CGRect],
        visibleElementIDs: Set<OverlayElement.ID>,
        padding: CGFloat = hitPadding
    ) -> Bool {
        frames.contains { id, frame in
            visibleElementIDs.contains(id)
                && frame.insetBy(dx: -padding, dy: -padding).contains(location)
        }
    }
}

/// Canvas-space hit and selection geometry for overlay elements when the
/// SwiftUI element views are not present (Skia preview). Consumes the same
/// `OverlayRenderModel` layouts as preview and export so hit testing follows
/// rendered geometry instead of measured SwiftUI frames.
enum PreviewElementGeometry {
    static func frame(
        for element: OverlayElement,
        in context: OverlayRenderContext
    ) -> CGRect {
        switch element.type {
        case .distanceTimeline:
            return OverlayRenderModel.distanceTimelineLayout(for: element, in: context).rect
        case .elevationChart:
            return OverlayRenderModel.elevationChartLayout(for: element, in: context).rect
        case .intervalHUDBar:
            return OverlayRenderModel.intervalHUDBarLayout(for: element, in: context).rect
        case .intervalTimeline:
            return OverlayRenderModel.intervalTimelineLayout(for: element, in: context).rect
        case .zoneEdgeBar:
            return OverlayRenderModel.zoneEdgeBarLayout(for: element, in: context).rect
        case .routeMap:
            return OverlayRenderModel.routeMapLayout(for: element, in: context).rect
        case .weatherWidget:
            return OverlayRenderModel.weatherWidgetLayout(for: element, in: context).rect
        case .component:
            return componentFrame(for: element, in: context)
        }
    }

    /// Components use a top-leading normalized anchor and their own declared
    /// size, scaled by the existing reference-canvas factor.
    static func componentFrame(
        for element: OverlayElement,
        in context: OverlayRenderContext
    ) -> CGRect {
        #if canImport(CSkiaBridge)
        if let frame = OverlayComponentSkiaRenderer.frame(for: element, renderContext: context) {
            return frame
        }
        #endif
        let size = componentSize(for: element) ?? CGSize(width: 160, height: 48)
        let scale = element.scale * context.canvasScale
        return CGRect(
            x: context.canvasSize.width * element.position.x,
            y: context.canvasSize.height * element.position.y,
            width: size.width * scale,
            height: size.height * scale
        )
    }

    /// Design-unit size of the instance's resolved definition; `nil` for a
    /// content-sized definition, whose size depends on measured content.
    static func componentSize(for element: OverlayElement) -> CGSize? {
        guard let instance = element.component,
              let definition = OverlayComponentRegistry.definition(for: instance.reference),
              definition.contentLayout == nil
        else {
            return nil
        }
        return CGSize(width: definition.size.width, height: definition.size.height)
    }

    private static func centeredRect(
        position: CGPoint,
        size: CGSize,
        canvasSize: CGSize
    ) -> CGRect {
        CGRect(
            x: canvasSize.width * position.x - size.width / 2,
            y: canvasSize.height * position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
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

struct PreviewSnapLine: Identifiable, Equatable {
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

struct PreviewSnapResult {
    var position: CGPoint
    var lines: [PreviewSnapLine]
}

struct PreviewSnapResolver {
    private let threshold: CGFloat = 6

    func snap(
        movingElementID: OverlayElement.ID,
        proposedPosition: CGPoint,
        currentFrame: CGRect?,
        overlayFrames: [OverlayElement.ID: CGRect],
        canvasSize: CGSize,
        guidesEnabled: Bool,
        isSnappingEnabled: Bool = true
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

        if isSnappingEnabled, let match = bestMatch(
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

        if isSnappingEnabled, let match = bestMatch(
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
        guidesEnabled: Bool,
        isSnappingEnabled: Bool = true
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

        if isSnappingEnabled, let match = bestMatch(
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

        if isSnappingEnabled, let match = bestMatch(
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
    var usesSkiaPreview: Bool = false
    var onToggleSkiaPreview: (() -> Void)? = nil

    var body: some View {
        EditorPanelHeader(title: "Preview") {
            Text(metadata)
                .font(EditorTheme.captionFont)
                .foregroundStyle(EditorTheme.textMuted)
                .lineLimit(1)

            if let onToggleSkiaPreview {
                Button(action: onToggleSkiaPreview) {
                    Image(systemName: usesSkiaPreview ? "bolt.fill" : "bolt")
                }
                .buttonStyle(PreviewIconButtonStyle(isActive: usesSkiaPreview))
                .help("Use Skia Overlay Renderer (debug)")
                .accessibilityLabel("Use Skia Overlay Renderer")
            }

            // A button-style Toggle reports its on/off state to accessibility.
            Toggle(isOn: $project.showPreviewGuides) {
                Image(systemName: "viewfinder")
            }
            .toggleStyle(.button)
            .buttonStyle(PreviewIconButtonStyle(isActive: project.showPreviewGuides))
            .help(project.showPreviewGuides ? "Hide Safe Frames" : "Show Safe Frames")
            .accessibilityLabel("Safe Frames")

            ColorPicker(
                "Canvas Background",
                selection: $project.previewCanvasBackground,
                supportsOpacity: false
            )
            .labelsHidden()
            .frame(height: PreviewLayout.headerButtonSize)
            .help("Canvas Background Color")
            .accessibilityLabel("Canvas Background Color")

            Picker("Fit Mode", selection: $project.previewFitMode) {
                ForEach(PreviewFitMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.regular)
            .frame(width: 82)
            .help("Fit Mode")
        }
    }

    private var metadata: String {
        let resolution = project.settings.resolution
        let fps = project.settings.frameRate.value
        let fpsText = fps.rounded() == fps ? "\(Int(fps)) fps" : "\(fps.formatted(.number.precision(.fractionLength(2)))) fps"
        return "\(resolution.width) x \(resolution.height) • \(fpsText)"
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
            case .weatherWidget:
                OverlaySharedWeatherWidgetView(
                    element: element,
                    layout: OverlayRenderModel.weatherWidgetLayout(for: element, in: renderContext)
                )
            case .component:
                // Components render only through the shared Skia pipeline.
                EmptyView()
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

/// Pointer shape over an overlay hit area: movable overlays show a hand,
/// locked overlays keep the arrow and explain why in a help tag.
enum PreviewOverlayPointer: Equatable {
    case arrow
    case openHand
    case closedHand

    static func resolve(isLocked: Bool, isDragging: Bool) -> PreviewOverlayPointer {
        if isLocked { return .arrow }
        return isDragging ? .closedHand : .openHand
    }

    var helpText: String {
        self == .arrow ? "Locked" : ""
    }
}

private struct PreviewOverlayPointerModifier: ViewModifier {
    let pointer: PreviewOverlayPointer

    func body(content: Content) -> some View {
        content
            .pointerStyle(pointerStyle)
            .help(pointer.helpText)
    }

    private var pointerStyle: PointerStyle {
        switch pointer {
        case .arrow: return .default
        case .openHand: return .grabIdle
        case .closedHand: return .grabActive
        }
    }
}

private struct PreviewLockedMark: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(EditorTheme.textPrimary)
            .frame(width: 18, height: 18)
            .background(Circle().fill(Color.black.opacity(0.78)))
            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
            .accessibilityLabel("Locked")
    }
}

private struct PreviewSelectionAffordance: View {
    var body: some View {
        // The dark outer stroke keeps the blue border visible on bright video.
        RoundedRectangle(cornerRadius: 4)
            .stroke(EditorTheme.accentBlue.opacity(0.92), lineWidth: 1.4)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.black.opacity(0.55), lineWidth: 1)
                    .padding(-1.2)
            }
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
        if element.type == .component {
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
        PreviewIconButtonBody(configuration: configuration, isActive: isActive)
    }
}

private struct PreviewIconButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isActive: Bool
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: PreviewLayout.headerButtonSize, height: PreviewLayout.headerButtonSize)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: EditorTheme.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: EditorTheme.controlRadius)
                    .stroke(isActive ? EditorTheme.accentBlue.opacity(0.58) : EditorTheme.borderSubtle, lineWidth: 1)
            }
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
    }

    private var foreground: Color {
        if isActive { return EditorTheme.accentBlue }
        return configuration.isPressed || isHovered ? EditorTheme.textPrimary : EditorTheme.textSecondary
    }

    private var background: Color {
        if configuration.isPressed {
            return EditorTheme.surfacePressed
        }
        if isActive {
            return EditorTheme.accentBlueSoft
        }
        return isHovered ? EditorTheme.surfaceHover : EditorTheme.surfaceControl
    }
}

/// Shown in the canvas when no video covers the playhead.
private struct PreviewEmptyState: View {
    let hint: String

    static func hint(hasMedia: Bool) -> String {
        hasMedia
            ? "Move the playhead over a clip to see its video."
            : "Choose File > Import Videos to add footage."
    }

    var body: some View {
        VStack(spacing: EditorTheme.space1) {
            Text("No Video")
                .font(EditorTheme.sectionTitleFont)
                .foregroundStyle(EditorTheme.textSecondary)
            Text(hint)
                .font(EditorTheme.captionFont)
                .foregroundStyle(EditorTheme.textMuted)
        }
        .multilineTextAlignment(.center)
        .padding(EditorTheme.space4)
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

        if let image = await MapSnapshotCache.shared.image(for: request) {
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

private struct PreviewPlaybackControls: View {
    @EnvironmentObject private var project: ProjectDocument

    var body: some View {
        ZStack {
            HStack(spacing: EditorTheme.space4) {
                ForEach(PreviewPlaybackButton.allCases, id: \.self) { button in
                    playbackButton(button)
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

    private func playbackButton(_ button: PreviewPlaybackButton) -> some View {
        let label = button.label(isPlaying: project.isPlaying)
        return Button {
            switch button {
            case .previousClip: project.jumpToPreviousPreviewItem()
            case .playPause: project.togglePlayback()
            case .nextClip: project.jumpToNextPreviewItem()
            }
        } label: {
            Image(systemName: button.systemImage(isPlaying: project.isPlaying))
        }
        .buttonStyle(PreviewPlaybackButtonStyle(isPrimary: button == .playPause))
        .help(label)
        .accessibilityLabel(label)
    }
}

/// The Preview transport, in display order. Pause replaces Play while
/// playing, so there is no separate Stop.
enum PreviewPlaybackButton: CaseIterable {
    case previousClip
    case playPause
    case nextClip

    /// Previous and Next step between timeline clip starts, or between
    /// media-pool items while one is being previewed.
    func label(isPlaying: Bool) -> String {
        switch self {
        case .previousClip: return "Previous Clip"
        case .playPause: return isPlaying ? "Pause" : "Play"
        case .nextClip: return "Next Clip"
        }
    }

    func systemImage(isPlaying: Bool) -> String {
        switch self {
        case .previousClip: return "backward.end.fill"
        case .playPause: return isPlaying ? "pause.fill" : "play.fill"
        case .nextClip: return "forward.end.fill"
        }
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
        Picker("Playback Speed", selection: Binding(
            get: { project.playbackRate },
            set: { project.setPlaybackRate($0) }
        )) {
            ForEach(ProjectDocument.playbackRateOptions, id: \.self) { rate in
                Text(ProjectDocument.playbackRateLabel(rate)).tag(rate)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .controlSize(.regular)
        .frame(width: 82)
        .help("Playback Speed")
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
    var visibility = ElevationChartLayerVisibility()

    var body: some View {
        ZStack {
            if visibility.showsContainerChrome, element.style.backgroundEnabled {
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
            if visibility.showsContainerChrome, element.style.borderEnabled {
                RoundedRectangle(cornerRadius: sharedBackgroundCornerRadius)
                    .stroke(Color(element.style.borderColor).opacity(element.style.borderOpacity), lineWidth: element.style.borderWidth)
                    .frame(width: backgroundLocalRect.width, height: backgroundLocalRect.height)
                    .position(x: backgroundLocalRect.midX, y: backgroundLocalRect.midY)
            }

            VStack(alignment: .leading, spacing: layout.verticalPadding) {
                if visibility.showsBigNumbers, layout.style.bigNumbersEnabled {
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
                        if visibility.showsGrid, layout.style.gridEnabled {
                            gridPath(in: proxy.size)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        }
                        if visibility.showsAxisLine, layout.style.axisLineEnabled {
                            axisLine(in: proxy.size)
                                .stroke(Color(element.style.foregroundColor).opacity(0.22), lineWidth: 1)
                        }
                        if layout.style.fillEnabled && layout.style.chartStyle == .area {
                            fillLayers(in: proxy.size)
                        }
                        if visibility.showsLine, layout.style.glowEnabled {
                            chartPath(in: proxy.size)
                                .stroke(Color(layout.style.lineColor).opacity(layout.style.glowOpacity), style: StrokeStyle(lineWidth: layout.lineWidth + 7, lineCap: .round, lineJoin: .round))
                                .blur(radius: 5)
                        }
                        if visibility.showsLine {
                            chartPath(in: proxy.size)
                                .stroke(Color(layout.style.lineColor).opacity(layout.style.lineOpacity), style: StrokeStyle(lineWidth: layout.lineWidth, lineCap: .round, lineJoin: .round))
                        }
                        if visibility.showsMarker, layout.style.currentMarkerEnabled {
                            marker(in: proxy.size)
                        }
                        if visibility.showsAxisLabels, layout.style.axisLabelsEnabled {
                            axisLabels(in: proxy.size)
                        }
                    }
                }
                .frame(height: layout.chartHeight)
            }
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.vertical, layout.verticalPadding)
            .frame(width: layout.rect.width, height: layout.rect.height, alignment: .topLeading)

            if visibility.showsStatsBar, let statsBar = layout.statsBarLayout {
                statsBarContent(statsBar)
                    .frame(width: statsBar.rect.width, height: statsBar.rect.height)
                    .position(x: statsBar.rect.midX, y: statsBar.rect.midY)
            }
        }
        .frame(width: layout.rect.width, height: layout.rect.height)
        .overlayLayeredShadow(
            color: Color(element.style.shadowColor),
            isEnabled: visibility.appliesOuterEffects && element.style.shadowEnabled,
            opacity: element.style.shadowOpacity,
            radius: element.style.shadowRadius,
            x: element.style.shadowOffsetX,
            y: element.style.shadowOffsetY,
            thickness: element.style.shadowThickness
        )
        .overlayForegroundGlow(element: visibility.appliesOuterEffects ? element : effectsDisabledElement)
    }

    /// Element copy with foreground glow disabled, used when baking static
    /// export layers so the outer glow is applied only once (on the base
    /// layer) rather than re-applied by every cached sub-layer.
    private var effectsDisabledElement: OverlayElement {
        var copy = element
        copy.style.glowEnabled = false
        return copy
    }

    @ViewBuilder
    private func fillLayers(in size: CGSize) -> some View {
        switch visibility.fillMode {
        case .none:
            EmptyView()
        case .baseFill:
            if layout.style.dualAreaEnabled {
                areaPath(in: size)
                    .fill(elevationFillGradient(start: layout.style.upperFillColor, end: layout.style.fillEndColor))
            } else {
                areaPath(in: size)
                    .fill(elevationFillGradient(start: layout.style.fillStartColor, end: layout.style.fillEndColor))
            }
        case .lowerOnly:
            if layout.style.dualAreaEnabled {
                areaPath(in: size)
                    .fill(elevationFillGradient(start: layout.style.lowerFillColor, end: layout.style.fillEndColor))
            }
        case .standard:
            if layout.style.dualAreaEnabled {
                areaPath(in: size)
                    .fill(elevationFillGradient(start: layout.style.upperFillColor, end: layout.style.fillEndColor))
                areaPath(in: size)
                    .fill(elevationFillGradient(start: layout.style.lowerFillColor, end: layout.style.fillEndColor))
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(width: size.width * max(0, min(1, 1 - layout.progress)))
                            .offset(x: size.width * max(0, min(1, layout.progress)))
                    }
            } else {
                areaPath(in: size)
                    .fill(elevationFillGradient(start: layout.style.fillStartColor, end: layout.style.fillEndColor))
            }
        }
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
                .frame(width: layout.markerHaloSize, height: layout.markerHaloSize)
                .blur(radius: layout.markerGlowBlurRadius)
                .position(point)
            Circle()
                .fill(Color(layout.style.markerColor))
                .frame(width: layout.markerDotSize, height: layout.markerDotSize)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.95), lineWidth: layout.markerRingStrokeWidth)
                        .frame(width: layout.markerRingSize, height: layout.markerRingSize)
                )
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
