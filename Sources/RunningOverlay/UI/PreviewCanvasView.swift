import AppKit
import SwiftUI

struct PreviewCanvasView: View {
    @EnvironmentObject private var project: ProjectDocument
    @State private var dragStartPositions: [OverlayElement.ID: CGPoint] = [:]

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
                            .fill(EditorTheme.appBackground)

                        if let previewMedia = project.activePreviewMedia() {
                            VideoPreviewPlayerView(
                                previewMedia: previewMedia,
                                isPlaying: project.isPlaying,
                                playbackRate: project.playbackRate
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

                        ForEach(project.overlayLayout.elements) { element in
                            let isSelected = project.selection == .overlayElement(element.id)
                            overlayView(element, canvasSize: canvasSize)
                                .overlay {
                                    if isSelected {
                                        PreviewSelectionAffordance()
                                    }
                                }
                                .position(
                                    x: canvasSize.width * element.position.x,
                                    y: canvasSize.height * element.position.y
                                )
                                .gesture(
                                    DragGesture(minimumDistance: 2)
                                        .onChanged { value in
                                            let initialPosition = dragStartPositions[element.id] ?? element.position
                                            dragStartPositions[element.id] = initialPosition
                                            let nextPosition = CGPoint(
                                                x: initialPosition.x + value.translation.width / max(canvasSize.width, 1),
                                                y: initialPosition.y + value.translation.height / max(canvasSize.height, 1)
                                            )
                                            project.moveOverlay(element.id, to: nextPosition)
                                            project.selectOverlay(element.id)
                                        }
                                        .onEnded { _ in
                                            dragStartPositions[element.id] = nil
                                            project.finishContinuousEdit()
                                        }
                                )
                                .onTapGesture {
                                    project.selectOverlay(element.id)
                                }
                        }
                    }
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        project.clearMediaPoolPreview()
                        project.clearSelection()
                    }
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

    private func overlayView(_ element: OverlayElement, canvasSize: CGSize) -> some View {
        let sampleTime = project.layerDataSampleTime
        let renderContext = OverlayRenderContext(
            canvasSize: canvasSize,
            activity: project.activity,
            elapsedTime: sampleTime
        )
        return Group {
            switch element.type {
            case .distanceTimeline:
                DistanceTimelineOverlayView(
                    element: element,
                    layout: OverlayRenderModel.distanceTimelineLayout(for: element, in: renderContext)
                )
            case .elevationChart:
                ElevationChartOverlayView(
                    element: element,
                    layout: OverlayRenderModel.elevationChartLayout(for: element, in: renderContext)
                )
            case .runningGauge:
                RunningGaugeOverlayView(
                    element: element,
                    layout: OverlayRenderModel.runningGaugeLayout(for: element, in: renderContext),
                    isSelected: project.selection == .overlayElement(element.id)
                )
            case .routeMap:
                RouteMapOverlayView(
                    element: element,
                    layout: OverlayRenderModel.routeMapLayout(for: element, in: renderContext),
                    isSelected: project.selection == .overlayElement(element.id)
                )
            case .lapList:
                LapListOverlayView(
                    element: element,
                    layout: OverlayRenderModel.lapListLayout(for: element, in: renderContext)
                )
            case .lapCard:
                LapCardOverlayView(
                    element: element,
                    layout: OverlayRenderModel.lapCardLayout(for: element, in: renderContext)
                )
            case .lapLive:
                LapLiveOverlayView(
                    element: element,
                    layout: OverlayRenderModel.lapLiveLayout(for: element, in: renderContext)
                )
            default:
                let layout = OverlayRenderModel.textLayout(for: element, in: renderContext)
                TextPresetOverlayView(
                    element: element,
                    layout: layout,
                    isSelected: project.selection == .overlayElement(element.id)
                )
            }
        }
    }

}

private enum PreviewLayout {
    static let headerHeight: CGFloat = EditorTheme.panelHeaderHeight
    static let playbackHeight: CGFloat = 44
    static let headerButtonSize: CGFloat = EditorTheme.iconButtonSize
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

            Menu {
                Button("Fit") {}
            } label: {
                HStack(spacing: EditorTheme.space1) {
                    Text("Fit")
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

private struct PreviewSelectionAffordance: View {
    private let handleSize: CGFloat = 7

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(EditorTheme.accentBlue.opacity(0.92), lineWidth: 1.4)

                handle
                    .position(x: 0, y: 0)
                handle
                    .position(x: proxy.size.width, y: 0)
                handle
                    .position(x: 0, y: proxy.size.height)
                handle
                    .position(x: proxy.size.width, y: proxy.size.height)
            }
            .allowsHitTesting(false)
        }
        .padding(-5)
    }

    private var handle: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(EditorTheme.accentBlue)
            .frame(width: handleSize, height: handleSize)
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white.opacity(0.85), lineWidth: 1)
            }
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

private struct RouteMapOverlayView: View {
    let element: OverlayElement
    let layout: OverlayRouteMapRenderLayout
    let isSelected: Bool
    @State private var mapSnapshot: NSImage?
    @State private var alphaMask: NSImage?

    var body: some View {
        VStack(spacing: 0) {
            mapContent
                .frame(width: layout.rect.width, height: layout.rect.height)
                .mask {
                    if let alphaMask {
                        Image(nsImage: alphaMask)
                            .resizable()
                            .scaledToFill()
                            .luminanceToAlpha()
                    } else {
                        shapeFill
                    }
                }
                .overlay {
                    if isSelected || layout.borderVisible {
                        shapeStroke(
                            color: isSelected ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.16),
                            lineWidth: isSelected ? 2 : 1
                        )
                    }
                }
                .shadow(color: Color.black.opacity(element.style.shadowOpacity), radius: element.style.shadowRadius, x: 0, y: 2)

            if let statsBar = layout.statsBarLayout, !statsBar.items.isEmpty {
                statsBarView(statsBar)
                    .frame(width: layout.rect.width, height: statsBar.rect.height)
            }
        }
        .task(id: renderIdentity) {
            await updateRenderAssets()
        }
    }

    private var mapContent: some View {
        ZStack {
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .fill(background)
                .overlay {
                    if let mapSnapshot, layout.provider == .mapKit {
                        Image(nsImage: mapSnapshot)
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
                    .font(.custom(element.style.fontName, size: max(layout.rect.width * 0.09, 10)).weight(.semibold))
                    .foregroundStyle(Color(element.style.foregroundColor).opacity(0.72))
            } else {
                routePath(points: relativePoints)
                    .stroke(Color.black.opacity(0.55), style: StrokeStyle(lineWidth: layout.lineWidth + 3, lineCap: .round, lineJoin: .round))

                if layout.preset == .glow {
                    routePath(points: relativePoints)
                        .stroke(Color(element.style.foregroundColor).opacity(0.55), style: StrokeStyle(lineWidth: layout.lineWidth * 2.3, lineCap: .round, lineJoin: .round))
                        .blur(radius: layout.glowRadius)
                }

                routePath(points: relativePoints)
                    .stroke(routeStroke, style: StrokeStyle(lineWidth: layout.lineWidth, lineCap: .round, lineJoin: .round))

                routeMarker(relativePoints.first, color: .green, style: element.style.routeMapStartMarkerStyle)
                routeMarker(relativePoints.last, color: .red, style: element.style.routeMapEndMarkerStyle)
                marker(relativeCurrentPoint, color: Color(element.style.foregroundColor), sizeMultiplier: 1.18)
            }
        }
    }

    private func statsBarView(_ statsBar: OverlayRouteMapStatsBarLayout) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(statsBar.items.enumerated()), id: \.offset) { index, item in
                statsBarCell(item)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if index < statsBar.items.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 1)
                        .padding(.vertical, statsBar.rect.height * 0.15)
                }
            }
        }
        .background(Color.black.opacity(statsBar.backgroundOpacity))
    }

    private func statsBarCell(_ item: OverlayRouteMapStatsBarItemLayout) -> some View {
        let barHeight = layout.statsBarLayout?.rect.height ?? 48
        let valueFontSize = barHeight * 0.38
        let unitFontSize  = barHeight * 0.22
        let labelFontSize = barHeight * 0.20
        return VStack(spacing: 1) {
            Text(item.value)
                .font(.custom(element.style.fontName, size: valueFontSize).weight(.semibold))
                .foregroundStyle(Color.white)
            if !item.unit.isEmpty {
                Text(item.unit)
                    .font(.custom(element.style.fontName, size: unitFontSize).weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.70))
            }
            Text(item.label.uppercased())
                .font(.custom(element.style.fontName, size: labelFontSize).weight(.medium))
                .foregroundStyle(Color.white.opacity(0.50))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private var renderIdentity: String {
        "\(mapSnapshotRequest?.hashValue ?? 0)-\(layout.shape.rawValue)-\(layout.edgeFade.rawValue)-\(String(format: "%.2f", layout.fadeAmount))-\(Int(layout.rect.width.rounded()))x\(Int(layout.rect.height.rounded()))"
    }

    private var mapSnapshotRequest: MapSnapshotRequest? {
        guard layout.provider == .mapKit,
              element.style.routeMapBackgroundStyle != .none,
              let geometry = layout.geometry,
              layout.rect.width > 1,
              layout.rect.height > 1 else {
            return nil
        }
        return MapSnapshotRequest(
            bounds: geometry.bounds,
            size: layout.rect.size,
            style: layout.preset,
            backgroundStyle: element.style.routeMapBackgroundStyle
        )
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

        guard let request = mapSnapshotRequest else {
            mapSnapshot = nil
            return
        }

        let provider = MapKitMapSnapshotProvider()
        let result = await withCheckedContinuation { continuation in
            provider.snapshot(for: request) { result in
                continuation.resume(returning: result)
            }
        }

        if case .success(let image) = result {
            mapSnapshot = image
        }
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

    private var background: Color {
        if element.style.routeMapBackgroundStyle == .none {
            return Color.black.opacity(element.style.backgroundOpacity)
        }
        switch element.style.routeMapBackgroundStyle {
        case .light:
            return Color.white.opacity(max(element.style.backgroundOpacity, 0.48))
        case .terrain:
            return Color(red: 0.13, green: 0.17, blue: 0.13).opacity(max(element.style.backgroundOpacity, 0.66))
        case .satellite:
            return Color(red: 0.05, green: 0.07, blue: 0.06).opacity(max(element.style.backgroundOpacity, 0.74))
        case .none:
            switch layout.preset {
            case .glow:
                return Color.black.opacity(max(element.style.backgroundOpacity, 0.34))
            default:
                return Color.black.opacity(element.style.backgroundOpacity)
            }
        case .dark:
            return Color(red: 0.08, green: 0.10, blue: 0.11).opacity(max(element.style.backgroundOpacity, 0.72))
        }
    }

    private var routeStroke: AnyShapeStyle {
        if element.style.routeMapColorMode == .gradient || layout.preset == .gradient {
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
    private func marker(_ point: CGPoint?, color: Color, sizeMultiplier: Double = 1) -> some View {
        if let point {
            Circle()
                .fill(color)
                .frame(width: layout.lineWidth * 2.7 * sizeMultiplier, height: layout.lineWidth * 2.7 * sizeMultiplier)
                .overlay {
                    Circle().stroke(Color.white, lineWidth: max(layout.lineWidth * 0.45, 1))
                }
                .position(point)
        }
    }

    @ViewBuilder
    private func routeMarker(_ point: CGPoint?, color: Color, style: OverlayRouteMapMarkerStyle) -> some View {
        if let point {
            switch style {
            case .hidden:
                EmptyView()
            case .dot:
                marker(point, color: color)
            case .pin:
                RoutePinShape()
                    .fill(color)
                    .frame(width: layout.lineWidth * 2.9, height: layout.lineWidth * 3.5)
                    .overlay {
                        RoutePinShape().stroke(Color.white, lineWidth: max(layout.lineWidth * 0.35, 1))
                    }
                    .position(point)
            case .flag:
                RouteFlagShape()
                    .fill(color)
                    .frame(width: layout.lineWidth * 3, height: layout.lineWidth * 3)
                    .overlay {
                        RouteFlagShape().stroke(Color.white, lineWidth: max(layout.lineWidth * 0.32, 1))
                    }
                    .position(point)
            }
        }
    }
}

private struct RoutePinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) * 0.34
        let center = CGPoint(x: rect.midX, y: rect.minY + radius + 1)
        path.addArc(center: center, radius: radius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX - radius * 0.72, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX + radius * 0.72, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct RouteFlagShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.15))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.24))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.50))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.62))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.62))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.50))
        path.closeSubpath()
        return path
    }
}

private struct TextPresetOverlayView: View {
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
                VStack(spacing: 0) {
                    valueText
                        .font(.custom(element.style.fontName, size: layout.fontSize * 1.95).weight(.bold))
                    unitText
                        .font(.custom(element.style.fontName, size: layout.unitFontSize * 1.25).weight(.bold))
                }
                .foregroundStyle(Color(element.style.foregroundColor))
            case .sportWatch:
                VStack(spacing: layout.verticalPadding * 0.65) {
                    Text(layout.components.shortLabel)
                        .font(labelFont.weight(.bold))
                    divider
                    valueText
                    divider
                    unitText
                        .font(labelFont.weight(.bold))
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
        .foregroundStyle(Color(element.style.foregroundColor))
        .monospacedDigit()
        .shadow(
            color: element.style.shadowEnabled ? Color.black.opacity(element.style.shadowOpacity) : Color.clear,
            radius: element.style.shadowEnabled ? layout.shadowRadius : 0,
            x: element.style.shadowEnabled ? element.style.shadowOffsetX : 0,
            y: element.style.shadowEnabled ? element.style.shadowOffsetY : 0
        )
    }

    // MARK: - Canonical 10 numeric overlay presets

    @ViewBuilder
    private var minimalCleanView: some View {
        let foreground = Color(element.style.foregroundColor)
        VStack(alignment: .leading, spacing: layout.fontSize * 0.10) {
            if element.style.showLabel, !layout.components.label.isEmpty {
                Text(layout.components.label.uppercased())
                    .font(.custom(element.style.fontName, size: layout.labelFontSize).weight(.medium))
                    .tracking(layout.labelFontSize * 0.10)
                    .foregroundStyle(foreground.opacity(0.70))
            }
            HStack(alignment: .lastTextBaseline, spacing: layout.fontSize * 0.14) {
                Text(layout.components.value)
                    .font(.custom(element.style.fontName, size: layout.fontSize).weight(.semibold))
                    .tracking(-layout.fontSize * 0.012)
                    .foregroundStyle(foreground)
                if element.style.showUnit, !layout.components.unit.isEmpty {
                    Text(layout.components.unit)
                        .font(.custom(element.style.fontName, size: layout.unitFontSize).weight(.medium))
                        .foregroundStyle(foreground.opacity(0.92))
                }
            }
        }
        .padding(.horizontal, element.style.backgroundEnabled ? layout.horizontalPadding : 0)
        .padding(.vertical, element.style.backgroundEnabled ? layout.verticalPadding : 0)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius))
    }

    @ViewBuilder
    private var minimalLabelView: some View {
        let foreground = Color(element.style.foregroundColor)
        VStack(alignment: .leading, spacing: layout.fontSize * 0.10) {
            if element.style.showLabel, !layout.components.label.isEmpty {
                Text(layout.components.label.uppercased())
                    .font(.custom(element.style.fontName, size: layout.labelFontSize).weight(.medium))
                    .tracking(layout.labelFontSize * 0.10)
                    .foregroundStyle(foreground.opacity(0.72))
            }
            HStack(alignment: .lastTextBaseline, spacing: layout.fontSize * 0.14) {
                Text(layout.components.value)
                    .font(.custom(element.style.fontName, size: layout.fontSize).weight(.semibold))
                    .tracking(-layout.fontSize * 0.012)
                    .foregroundStyle(foreground)
                if element.style.showUnit, !layout.components.unit.isEmpty {
                    Text(layout.components.unit)
                        .font(.custom(element.style.fontName, size: layout.unitFontSize).weight(.medium))
                        .foregroundStyle(foreground.opacity(0.92))
                }
            }
        }
    }

    @ViewBuilder
    private var pillView: some View {
        let foreground = Color(element.style.foregroundColor)
        let accent = Color(element.style.accentColor)
        let valueAndUnit = HStack(alignment: .lastTextBaseline, spacing: layout.fontSize * 0.14) {
            Text(layout.components.value)
                .font(.custom(element.style.fontName, size: layout.fontSize * 0.92).weight(.bold))
                .tracking(-layout.fontSize * 0.009)
                .foregroundStyle(foreground)
            if element.style.showUnit, !layout.components.unit.isEmpty {
                Text(layout.components.unit)
                    .font(.custom(element.style.fontName, size: layout.unitFontSize).weight(.medium))
                    .foregroundStyle(foreground.opacity(0.92))
            }
        }
        Group {
            if element.style.showLabel, !layout.components.label.isEmpty {
                HStack(spacing: layout.fontSize * 0.32) {
                    Text(layout.components.label.uppercased())
                        .font(.custom(element.style.fontName, size: layout.labelFontSize).weight(.medium))
                        .tracking(layout.labelFontSize * 0.10)
                        .foregroundStyle(accent.opacity(0.92))
                    Rectangle()
                        .fill(foreground.opacity(0.32))
                        .frame(width: 1, height: layout.fontSize * 0.78)
                    valueAndUnit
                }
            } else {
                valueAndUnit
            }
        }
        .padding(.horizontal, layout.horizontalPadding)
        .padding(.vertical, layout.verticalPadding)
        .background(
            Group {
                if isSelected {
                    Capsule().fill(Color.accentColor.opacity(0.45))
                } else if element.style.backgroundEnabled {
                    Capsule().fill(Color(element.style.backgroundColor).opacity(element.style.backgroundOpacity))
                }
            }
        )
        .overlay(
            Capsule().stroke(foreground.opacity(0.16), lineWidth: 1)
                .opacity(element.style.backgroundEnabled ? 1 : 0)
        )
    }

    @ViewBuilder
    private var splitLabelView: some View {
        let foreground = Color(element.style.foregroundColor)
        let accent = Color(element.style.accentColor)
        VStack(alignment: .leading, spacing: layout.fontSize * 0.10) {
            if element.style.showLabel, !layout.components.label.isEmpty {
                Text(layout.components.label.uppercased())
                    .font(.custom(element.style.fontName, size: layout.labelFontSize).weight(.semibold))
                    .tracking(layout.labelFontSize * 0.18)
                    .foregroundStyle(accent.opacity(0.95))
            }
            Rectangle()
                .fill(accent)
                .frame(width: layout.fontSize * 2.4, height: 2)
            HStack(alignment: .lastTextBaseline, spacing: layout.fontSize * 0.14) {
                Text(layout.components.value)
                    .font(.custom(element.style.fontName, size: layout.fontSize).weight(.bold))
                    .tracking(-layout.fontSize * 0.012)
                    .foregroundStyle(foreground)
                if element.style.showUnit, !layout.components.unit.isEmpty {
                    Text(layout.components.unit)
                        .font(.custom(element.style.fontName, size: layout.unitFontSize).weight(.medium))
                        .foregroundStyle(foreground.opacity(0.92))
                }
            }
        }
    }

    @ViewBuilder
    private var neonGlowView: some View {
        let accent = Color(element.style.accentColor)
        let foreground = Color(element.style.foregroundColor)
        HStack(alignment: .lastTextBaseline, spacing: layout.fontSize * 0.14) {
            Text(layout.components.value)
                .font(.custom(element.style.fontName, size: layout.fontSize).weight(.bold))
                .tracking(-layout.fontSize * 0.010)
                .foregroundStyle(foreground)
                .shadow(color: accent.opacity(0.80), radius: layout.fontSize * 0.34)
                .shadow(color: accent.opacity(0.36), radius: layout.fontSize * 0.62)
            if element.style.showUnit, !layout.components.unit.isEmpty {
                Text(layout.components.unit)
                    .font(.custom(element.style.fontName, size: layout.unitFontSize).weight(.semibold))
                    .foregroundStyle(accent.opacity(0.95))
                    .shadow(color: accent.opacity(0.65), radius: layout.fontSize * 0.24)
            }
        }
    }

    @ViewBuilder
    private var racingStripeView: some View {
        let accent = Color(element.style.accentColor)
        let foreground = Color(element.style.foregroundColor)
        let stripeWidth = max(layout.fontSize * 0.12, 4)
        let stripeGap = layout.fontSize * 0.34
        VStack(alignment: .leading, spacing: layout.fontSize * 0.10) {
            if element.style.showLabel, !layout.components.label.isEmpty {
                Text(layout.components.label.uppercased())
                    .font(.custom(element.style.fontName, size: layout.labelFontSize).weight(.bold))
                    .tracking(layout.labelFontSize * 0.10)
                    .foregroundStyle(accent.opacity(0.95))
            }
            HStack(alignment: .lastTextBaseline, spacing: layout.fontSize * 0.14) {
                Text(layout.components.value)
                    .font(.custom(element.style.fontName, size: layout.fontSize).weight(.bold))
                    .tracking(-layout.fontSize * 0.010)
                    .foregroundStyle(foreground)
                if element.style.showUnit, !layout.components.unit.isEmpty {
                    Text(layout.components.unit)
                        .font(.custom(element.style.fontName, size: layout.unitFontSize).weight(.medium))
                        .foregroundStyle(foreground.opacity(0.92))
                }
            }
        }
        .padding(.leading, stripeWidth + stripeGap)
        .overlay(alignment: .leading) {
            // Stripe lives inside the text block so it auto-sizes to the
            // label + value height instead of stretching to the canvas.
            RoundedRectangle(cornerRadius: 2)
                .fill(accent)
                .frame(width: stripeWidth)
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
        let foreground = Color(element.style.foregroundColor)
        let accent = Color(element.style.accentColor)
        VStack(alignment: .leading, spacing: layout.fontSize * 0.04) {
            if element.style.showLabel, !layout.components.label.isEmpty {
                Text(layout.components.label.uppercased())
                    .font(.custom(element.style.fontName, size: layout.labelFontSize).weight(.bold))
                    .tracking(layout.labelFontSize * 0.18)
                    .foregroundStyle(accent)
            }
            HStack(alignment: .lastTextBaseline, spacing: layout.fontSize * 0.10) {
                Text(layout.components.value)
                    .font(.custom(element.style.fontName, size: layout.fontSize).weight(.heavy))
                    .tracking(-layout.fontSize * 0.018)
                    .foregroundStyle(foreground)
                if element.style.showUnit, !layout.components.unit.isEmpty {
                    Text(layout.components.unit)
                        .font(.custom(element.style.fontName, size: layout.unitFontSize).weight(.medium))
                        .foregroundStyle(foreground.opacity(0.92))
                }
            }
            Rectangle()
                .fill(accent)
                .frame(width: layout.fontSize * 2.2, height: 3)
                .padding(.top, layout.fontSize * 0.04)
        }
    }

    @ViewBuilder
    private var digitalWatchView: some View {
        let accent = Color(element.style.accentColor)
        // Brian Cavalier's HTML5 digital-clock uses BankGothic Medium with
        // saturated green + a soft glow to fake the LCD look. We do the same
        // here: bundled BankGothic for the value, intensified accent halo.
        let digitalFont = BundledFontName.digitalWatch
        VStack(alignment: .leading, spacing: layout.fontSize * 0.10) {
            if element.style.showLabel, !layout.components.label.isEmpty {
                Text(layout.components.label.uppercased())
                    .font(.custom(digitalFont, size: layout.labelFontSize))
                    .tracking(layout.labelFontSize * 0.18)
                    .foregroundStyle(accent.opacity(0.90))
            }
            HStack(alignment: .lastTextBaseline, spacing: layout.fontSize * 0.14) {
                Text(layout.components.value)
                    .font(.custom(digitalFont, size: layout.fontSize))
                    .tracking(layout.fontSize * 0.020)
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.85), radius: layout.fontSize * 0.18)
                    .shadow(color: accent.opacity(0.45), radius: layout.fontSize * 0.42)
                if element.style.showUnit, !layout.components.unit.isEmpty {
                    Text(layout.components.unit)
                        .font(.custom(digitalFont, size: layout.unitFontSize))
                        .foregroundStyle(accent.opacity(0.95))
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
                    .font(.custom(element.style.fontName, size: layout.labelFontSize).weight(.regular))
                    .tracking(layout.labelFontSize * 0.12)
                    .foregroundStyle(foreground.opacity(0.28))
            }
            HStack(alignment: .firstTextBaseline, spacing: layout.fontSize * 0.18) {
                Text(layout.components.value)
                    .font(.custom(element.style.fontName, size: layout.fontSize).weight(.light))
                    .tracking(-layout.fontSize * 0.02)
                    .foregroundStyle(foreground.opacity(0.88))
                if element.style.showUnit, !layout.components.unit.isEmpty {
                    Text(layout.components.unit)
                        .font(.custom(element.style.fontName, size: layout.unitFontSize).weight(.regular))
                        .foregroundStyle(foreground.opacity(0.30))
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
                        .font(.custom(element.style.fontName, size: layout.labelFontSize).weight(.regular))
                        .tracking(layout.labelFontSize * 0.12)
                        .foregroundStyle(foreground.opacity(0.32))
                }
                Text(layout.components.value)
                    .font(.custom(element.style.fontName, size: layout.fontSize).weight(.bold))
                    .tracking(-layout.fontSize * 0.05)
                    .foregroundStyle(foreground)
                if element.style.showUnit, !layout.components.unit.isEmpty {
                    Text(layout.components.unit)
                        .font(.custom(element.style.fontName, size: layout.unitFontSize).weight(.regular))
                        .foregroundStyle(foreground.opacity(0.38))
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
                    .font(.custom(element.style.fontName, size: layout.labelFontSize).weight(.bold))
                    .tracking(layout.labelFontSize * 0.16)
                    .foregroundStyle(accent)
            }
            Text(layout.components.value)
                .font(.custom(element.style.fontName, size: layout.fontSize).weight(.heavy))
                .tracking(-layout.fontSize * 0.06)
                .foregroundStyle(foreground)
            if element.style.showUnit, !layout.components.unit.isEmpty {
                HStack(alignment: .center, spacing: layout.fontSize * 0.18) {
                    Rectangle()
                        .fill(foreground.opacity(0.10))
                        .frame(width: layout.fontSize * 0.6, height: 0.5)
                    Circle()
                        .fill(accent)
                        .frame(width: max(layout.fontSize * 0.14, 4), height: max(layout.fontSize * 0.14, 4))
                    Text(layout.components.unit)
                        .font(.custom(element.style.fontName, size: layout.unitFontSize).weight(.regular))
                        .foregroundStyle(foreground.opacity(0.35))
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
                    .foregroundStyle(foreground.opacity(0.30))
            }
            Text(layout.components.value)
                .font(.custom(serifFont, size: layout.fontSize))
                .tracking(-layout.fontSize * 0.01)
                .foregroundStyle(foreground.opacity(0.92))
            if element.style.showUnit, !layout.components.unit.isEmpty {
                Rectangle()
                    .fill(foreground.opacity(0.20))
                    .frame(width: layout.fontSize * 0.78, height: 0.5)
                    .padding(.vertical, layout.fontSize * 0.18)
                Text(layout.components.unit)
                    .font(.system(size: layout.unitFontSize, weight: .regular))
                    .tracking(layout.unitFontSize * 0.1)
                    .foregroundStyle(foreground.opacity(0.28))
            }
        }
    }

    private var valueText: Text {
        Text(layout.components.value)
            .font(.custom(element.style.fontName, size: layout.fontSize).weight(Font.Weight(element.style.fontWeight)))
    }

    private var unitText: Text {
        Text(layout.components.unit)
            .font(.custom(element.style.fontName, size: layout.unitFontSize).weight(Font.Weight(element.style.fontWeight)))
    }

    private var labelFont: Font {
        .custom(element.style.fontName, size: layout.labelFontSize).weight(Font.Weight(element.style.fontWeight))
    }

    private var background: Color {
        if isSelected {
            return Color.accentColor.opacity(0.45)
        }
        guard element.style.backgroundEnabled else { return Color.clear }
        return Color(element.style.backgroundColor).opacity(element.style.backgroundOpacity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(element.style.foregroundColor).opacity(0.28))
            .frame(width: layout.fontSize * 2.7, height: max(layout.fontSize / 26, 1))
    }
}

private struct RunningGaugeOverlayView: View {
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
        .shadow(
            color: Color.black.opacity(style.shadowEnabled ? style.shadowOpacity : 0),
            radius: style.shadowRadius,
            x: 0,
            y: max(style.shadowRadius * 0.25, 1)
        )
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
                    .font(.custom(style.fontName, size: region.labelFontSize).weight(swiftFontWeight(config.labelWeight)))
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Text(region.components.value)
                .font(.custom(style.fontName, size: region.valueFontSize).weight(swiftFontWeight(config.valueWeight)))
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
                    .font(.custom(style.fontName, size: region.unitFontSize).weight(.medium))
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

private struct DistanceTimelineOverlayView: View {
    let element: OverlayElement
    let layout: OverlayDistanceTimelineRenderLayout

    var body: some View {
        ZStack {
            if layout.style.backgroundEnabled {
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(Color(distanceTimeline: layout.style.backgroundColor).opacity(layout.style.backgroundOpacity))
                    .overlay {
                        if layout.style.preset == .glass {
                            RoundedRectangle(cornerRadius: layout.cornerRadius)
                                .fill(.white.opacity(0.08))
                        }
                    }
            }

            if layout.style.borderEnabled {
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .stroke(Color(distanceTimeline: layout.style.borderColor).opacity(layout.style.borderOpacity), lineWidth: layout.borderWidth)
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

            if layout.style.showStartFinishLabels {
                startFinishLabels
            }
        }
        .frame(width: layout.rect.width, height: layout.rect.height)
        .shadow(
            color: Color.black.opacity(element.style.shadowEnabled ? element.style.shadowOpacity : 0),
            radius: element.style.shadowRadius,
            x: element.style.shadowOffsetX,
            y: element.style.shadowOffsetY
        )
        .opacity(layout.style.fadeEnabled ? max(1 - layout.style.fadeAmount * 0.35, 0.72) : 1)
    }

    private var valueLayer: some View {
        let content = localRect(layout.contentRect)
        let align: Alignment = layout.style.preset == .lowerThird ? .leading : .leading
        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if layout.style.showLabel {
                    Text(layout.label.uppercased())
                        .font(.custom(element.style.fontName, size: layout.labelFontSize).weight(.medium))
                        .foregroundStyle(labelColor)
                }
                Spacer(minLength: 6)
                if layout.style.showPercent {
                    Text(layout.percentText)
                        .font(.custom(element.style.fontName, size: layout.percentFontSize).weight(.semibold))
                        .foregroundStyle(accentColor)
                }
            }
            Text(layout.valueText)
                .font(.custom(element.style.fontName, size: valueFontSize).weight(valueWeight))
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(width: content.width, height: max(layout.trackRect.minY - layout.contentRect.minY - 2, layout.valueFontSize * 1.2), alignment: align)
        .position(x: content.midX, y: content.minY + max(layout.trackRect.minY - layout.contentRect.minY, layout.valueFontSize * 1.2) / 2)
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
            } else if layout.style.preset == .dense || layout.style.preset == .splits {
                segmentedFill(in: track.size)
                    .fill(accentColor)
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
                let markerPoint = layout.style.preset == .route
                    ? localPoint(layout.routeCurrentPoint ?? progressedRoutePoints.last ?? CGPoint(x: layout.trackRect.minX + layout.trackRect.width * layout.progress, y: layout.trackRect.midY))
                    : CGPoint(x: max(track.width * layout.progress, 0), y: track.height * 0.5)
                Circle()
                    .fill(accentColor)
                    .frame(width: track.height * 2.2, height: track.height * 2.2)
                    .shadow(color: glowColor, radius: layout.style.glowEnabled ? track.height * 2.3 : 0)
                    .position(x: markerPoint.x, y: markerPoint.y)
            }
        }
        .frame(width: track.width, height: track.height)
        .position(x: track.midX, y: track.midY)
    }

    private var startFinishLabels: some View {
        let track = localRect(layout.trackRect)
        return HStack {
            Text("START")
            Spacer()
            Text("FINISH")
        }
        .font(.custom(element.style.fontName, size: layout.unitFontSize).weight(.medium))
        .foregroundStyle(labelColor.opacity(0.78))
        .frame(width: track.width)
        .position(x: track.midX, y: min(track.maxY + layout.unitFontSize * 0.9, layout.rect.height - layout.unitFontSize))
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

    private func segmentedFill(in size: CGSize) -> Path {
        var path = Path()
        let segmentCount = 12
        let gap = max(size.width * 0.012, 2)
        let segmentWidth = (size.width - gap * Double(segmentCount - 1)) / Double(segmentCount)
        let filled = layout.progress * Double(segmentCount)
        for index in 0..<segmentCount {
            let fillFraction = min(max(filled - Double(index), 0), 1)
            guard fillFraction > 0 else { continue }
            let x = Double(index) * (segmentWidth + gap)
            path.addRoundedRect(
                in: CGRect(x: x, y: 0, width: segmentWidth * fillFraction, height: size.height),
                cornerSize: CGSize(width: size.height / 2, height: size.height / 2)
            )
        }
        return path
    }

    private func tickMarks(in size: CGSize) -> Path {
        var path = Path()
        let count = layout.style.preset == .splits ? 10 : 16
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

private struct ElevationChartOverlayView: View {
    let element: OverlayElement
    let layout: OverlayElevationChartRenderLayout

    var body: some View {
        VStack(alignment: .leading, spacing: layout.verticalPadding * 0.75) {
            Text(layout.label)
                .font(.custom(element.style.fontName, size: layout.labelFontSize).weight(Font.Weight(element.style.fontWeight)))
                .foregroundStyle(Color(element.style.foregroundColor))
                .monospacedDigit()

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    chartPath(in: proxy.size)
                        .stroke(Color(element.style.foregroundColor).opacity(0.85), lineWidth: layout.lineWidth)
                    Rectangle()
                        .fill(Color(element.style.foregroundColor).opacity(0.45))
                        .frame(width: 2, height: proxy.size.height)
                        .offset(x: proxy.size.width * layout.progress)
                }
            }
            .frame(height: layout.chartHeight)
        }
        .frame(width: layout.rect.width - layout.horizontalPadding * 2)
        .padding(.horizontal, layout.horizontalPadding)
        .padding(.vertical, layout.verticalPadding)
        .background(Color.black.opacity(element.style.backgroundOpacity))
        .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius))
        .shadow(color: Color.black.opacity(element.style.shadowOpacity), radius: element.style.shadowRadius, x: 0, y: 2)
    }

    private func chartPath(in size: CGSize) -> Path {
        var path = Path()
        guard layout.samples.count > 1 else {
            path.move(to: CGPoint(x: 0, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            return path
        }

        let minValue = layout.samples.min() ?? 0
        let maxValue = layout.samples.max() ?? minValue
        let range = max(maxValue - minValue, 1)

        for index in layout.samples.indices {
            let x = size.width * CGFloat(index) / CGFloat(max(layout.samples.count - 1, 1))
            let normalized = (layout.samples[index] - minValue) / range
            let y = size.height - size.height * CGFloat(normalized)
            if index == layout.samples.startIndex {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}

private struct LapListOverlayView: View {
    let element: OverlayElement
    let layout: LapListRenderLayout

    var body: some View {
        VStack(spacing: layout.rowSpacing) {
            ForEach(layout.rows, id: \.lapRecord.id) { row in
                lapRow(row)
            }
        }
        .frame(width: layout.rect.width)
    }

    private func lapRow(_ row: LapListRowRenderLayout) -> some View {
        ZStack(alignment: .leading) {
            // Background
            RoundedRectangle(cornerRadius: layout.rowCornerRadius)
                .fill(Color.black.opacity(layout.backgroundOpacity * row.rowOpacity))

            // Progress bar
            if layout.progressBarEnabled && row.progressFraction > 0 {
                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: layout.rowCornerRadius)
                        .fill(Color(element.style.lapList.progressColor)
                            .opacity(layout.progressOpacity * row.rowOpacity))
                        .frame(width: proxy.size.width * row.progressFraction)
                }
            }

            // Border for current lap
            if row.isCurrent {
                RoundedRectangle(cornerRadius: layout.rowCornerRadius)
                    .stroke(Color(element.style.foregroundColor).opacity(0.55), lineWidth: 1)
            }

            // Columns
            HStack(spacing: 0) {
                ForEach(Array(zip(layout.columns, row.columnTexts).enumerated()), id: \.offset) { _, pair in
                    let (_, text) = pair
                    Text(text)
                        .font(.custom(element.style.fontName, size: layout.fontSize)
                            .weight(Font.Weight(element.style.fontWeight)))
                        .foregroundStyle(Color(element.style.foregroundColor).opacity(row.rowOpacity))
                        .monospacedDigit()
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, layout.rowHeight * 0.25)
        }
        .frame(height: layout.rowHeight)
    }
}

private struct LapCardOverlayView: View {
    let element: OverlayElement
    let layout: LapCardRenderLayout

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .fill(Color.black.opacity(layout.backgroundOpacity))

            VStack(alignment: .leading, spacing: 0) {
                // Header
                Text(layout.headerText)
                    .font(.custom(element.style.fontName, size: layout.fontSize)
                        .weight(Font.Weight(element.style.fontWeight)))
                    .foregroundStyle(Color(element.style.foregroundColor))
                    .lineLimit(1)
                    .frame(height: layout.headerHeight)
                    .padding(.horizontal, layout.horizontalPadding)

                // Stat rows
                ForEach(Array(layout.columnRows.enumerated()), id: \.offset) { _, pair in
                    HStack {
                        Text(pair.label)
                            .font(.custom(element.style.fontName, size: layout.fontSize * 0.78))
                            .foregroundStyle(Color(element.style.foregroundColor).opacity(0.6))
                        Spacer()
                        Text(pair.value)
                            .font(.custom(element.style.fontName, size: layout.fontSize)
                                .weight(Font.Weight(element.style.fontWeight)))
                            .foregroundStyle(Color(element.style.foregroundColor))
                            .monospacedDigit()
                    }
                    .frame(height: layout.rowHeight)
                    .padding(.horizontal, layout.horizontalPadding)
                }

                // Recovery section
                if layout.showRecoverySection {
                    Divider()
                        .background(Color(element.style.foregroundColor).opacity(0.25))
                        .padding(.horizontal, layout.horizontalPadding)
                        .padding(.vertical, layout.dividerHeight / 2)

                    Text("Recovery")
                        .font(.custom(element.style.fontName, size: layout.fontSize * 0.78))
                        .foregroundStyle(Color(element.style.foregroundColor).opacity(0.55))
                        .frame(height: layout.recoveryHeaderHeight)
                        .padding(.horizontal, layout.horizontalPadding)

                    ForEach(Array(layout.recoveryRows.enumerated()), id: \.offset) { _, pair in
                        HStack {
                            Text(pair.label)
                                .font(.custom(element.style.fontName, size: layout.fontSize * 0.78))
                                .foregroundStyle(Color(element.style.foregroundColor).opacity(0.6))
                            Spacer()
                            Text(pair.value)
                                .font(.custom(element.style.fontName, size: layout.fontSize)
                                    .weight(Font.Weight(element.style.fontWeight)))
                                .foregroundStyle(Color(element.style.accentColor))
                                .monospacedDigit()
                        }
                        .frame(height: layout.rowHeight)
                        .padding(.horizontal, layout.horizontalPadding)
                    }

                    if let progress = layout.recoveryProgress {
                        GeometryReader { proxy in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(layout.progressColor).opacity(0.55))
                                .frame(width: proxy.size.width * progress, height: 6)
                        }
                        .frame(height: 6)
                        .padding(.horizontal, layout.horizontalPadding)
                    }
                }

                Spacer(minLength: layout.verticalPadding)
            }
            .padding(.top, layout.verticalPadding)
        }
        .frame(width: layout.rect.width, height: layout.rect.height)
    }
}

private struct LapLiveOverlayView: View {
    let element: OverlayElement
    let layout: LapLiveRenderLayout

    var body: some View {
        if layout.isHidden { return AnyView(EmptyView()) }
        return AnyView(
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(Color.black.opacity(layout.backgroundOpacity))

                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    Text(layout.headerText)
                        .font(.custom(element.style.fontName, size: layout.fontSize)
                            .weight(Font.Weight(element.style.fontWeight)))
                        .foregroundStyle(Color(element.style.foregroundColor))
                        .lineLimit(1)
                        .frame(height: layout.headerHeight)
                        .padding(.horizontal, layout.horizontalPadding)

                    // Progress bar
                    if layout.showProgressBar {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.black.opacity(0.3))
                                Rectangle()
                                    .fill(Color(layout.progressColor).opacity(layout.progressOpacity))
                                    .frame(width: proxy.size.width * layout.progressFraction)
                            }
                        }
                        .frame(height: layout.progressBarHeight)
                    }

                    // Active metric rows
                    ForEach(Array(layout.metricRows.enumerated()), id: \.offset) { _, pair in
                        HStack {
                            Text(pair.label)
                                .font(.custom(element.style.fontName, size: layout.fontSize * 0.78))
                                .foregroundStyle(Color(element.style.foregroundColor).opacity(0.6))
                            Spacer()
                            Text(pair.value)
                                .font(.custom(element.style.fontName, size: layout.fontSize)
                                    .weight(Font.Weight(element.style.fontWeight)))
                                .foregroundStyle(Color(element.style.foregroundColor))
                                .monospacedDigit()
                        }
                        .frame(height: layout.rowHeight)
                        .padding(.horizontal, layout.horizontalPadding)
                    }

                    // Recovery rows (rest mode)
                    if layout.isRestMode && !layout.recoveryRows.isEmpty {
                        if layout.recoveryHeaderHeight > 0 {
                            Text("Recovery")
                                .font(.custom(element.style.fontName, size: layout.fontSize * 0.78))
                                .foregroundStyle(Color(element.style.foregroundColor).opacity(0.55))
                                .frame(height: layout.recoveryHeaderHeight)
                                .padding(.horizontal, layout.horizontalPadding)
                        }
                        ForEach(Array(layout.recoveryRows.enumerated()), id: \.offset) { _, pair in
                            HStack {
                                Text(pair.label)
                                    .font(.custom(element.style.fontName, size: layout.fontSize * 0.78))
                                    .foregroundStyle(Color(element.style.foregroundColor).opacity(0.6))
                                Spacer()
                                Text(pair.value)
                                    .font(.custom(element.style.fontName, size: layout.fontSize)
                                        .weight(Font.Weight(element.style.fontWeight)))
                                    .foregroundStyle(Color(element.style.accentColor))
                                    .monospacedDigit()
                            }
                            .frame(height: layout.rowHeight)
                            .padding(.horizontal, layout.horizontalPadding)
                        }
                        if let progress = layout.recoveryProgress {
                            GeometryReader { proxy in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(layout.progressColor).opacity(0.55))
                                    .frame(width: proxy.size.width * progress, height: 5)
                            }
                            .frame(height: 5)
                            .padding(.horizontal, layout.horizontalPadding)
                        }
                    }

                    Spacer(minLength: layout.verticalPadding)
                }
                .padding(.top, layout.verticalPadding)
            }
            .frame(width: layout.rect.width, height: layout.rect.height)
        )
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
