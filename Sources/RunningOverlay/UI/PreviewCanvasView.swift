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
        ZStack {
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .fill(background)
                .overlay {
                    if let mapSnapshot, layout.provider == .mapKit {
                        Image(nsImage: mapSnapshot)
                            .resizable()
                            .scaledToFill()
                            .opacity(0.82)
                            .clipped()
                    } else if layout.preset == .mapKit || element.style.routeMapBackgroundStyle != .none {
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

                if element.style.routeMapLegendVisible {
                    routeLegend
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
        }
        .frame(width: layout.rect.width, height: layout.rect.height)
        .mask {
            if let alphaMask {
                Image(nsImage: alphaMask)
                    .resizable()
                    .scaledToFill()
            } else {
                shapeFill
            }
        }
        .overlay {
            shapeStroke(
                color: isSelected ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.16),
                lineWidth: isSelected ? 2 : 1
            )
        }
        .shadow(color: Color.black.opacity(element.style.shadowOpacity), radius: element.style.shadowRadius, x: 0, y: 2)
        .task(id: renderIdentity) {
            await updateRenderAssets()
        }
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
        alphaMask = RouteMapMaskRenderer.makeNSImage(
            size: layout.rect.size,
            shape: layout.shape,
            cornerRadius: layout.cornerRadius,
            edgeFade: layout.edgeFade,
            fadeAmount: layout.fadeAmount
        )

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
        case .none, .dark:
            switch layout.preset {
            case .mapKit:
                return Color(red: 0.08, green: 0.10, blue: 0.11).opacity(max(element.style.backgroundOpacity, 0.72))
            case .glow:
                return Color.black.opacity(max(element.style.backgroundOpacity, 0.34))
            default:
                return Color.black.opacity(element.style.backgroundOpacity)
            }
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

    private var routeLegend: some View {
        VStack(alignment: .leading, spacing: 5) {
            legendRow(color: .green, text: "Start")
            legendRow(color: .red, text: "Finish")
            if element.style.routeMapLegendMode == .startFinishDistance {
                Text(distanceText)
                    .font(.custom(element.style.fontName, size: max(layout.lineWidth * 2.0, 10)).weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
            }
            if element.style.routeMapLegendMode == .gradientBand {
                LinearGradient(
                    colors: [
                        Color(element.style.routeMapGradientStart),
                        Color(element.style.routeMapGradientMiddle),
                        Color(element.style.routeMapGradientEnd)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 72, height: 7)
                .clipShape(Capsule())
                Text(distanceText)
                    .font(.custom(element.style.fontName, size: max(layout.lineWidth * 1.6, 9)).weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.88))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func legendRow(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: max(layout.lineWidth * 1.4, 6), height: max(layout.lineWidth * 1.4, 6))
            Text(text)
                .font(.custom(element.style.fontName, size: max(layout.lineWidth * 1.55, 9)).weight(.medium))
                .foregroundStyle(Color.white.opacity(0.85))
        }
    }

    private var distanceText: String {
        String(format: "%.2f km", (layout.geometry?.distanceMeters ?? 0) / 1000)
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

    var body: some View {
        ZStack {
            Circle()
                .fill(gaugeBackground)
                .overlay {
                    if layout.preset == .trailAdventure {
                        Circle()
                            .stroke(Color(element.style.foregroundColor).opacity(0.11), lineWidth: layout.ringWidth * 3.5)
                            .blur(radius: layout.ringWidth * 0.35)
                    }
                }

            Circle()
                .stroke(Color.white.opacity(trackOpacity), lineWidth: layout.ringWidth)
                .padding(layout.ringWidth * 1.2)

            Circle()
                .trim(from: 0, to: layout.progress)
                .stroke(
                    Color(element.style.foregroundColor),
                    style: StrokeStyle(lineWidth: layout.ringWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(layout.ringWidth * 1.2)

            GaugeTicksView(
                tickCount: tickCount,
                tickLength: layout.tickLength,
                tickWidth: max(layout.dividerWidth, 1),
                color: tickColor
            )
            .padding(layout.ringWidth * 2.8)

            GaugeDividersView(lineWidth: layout.dividerWidth, color: Color.white.opacity(dividerOpacity))
                .padding(layout.rect.width * 0.18)

            VStack(spacing: layout.rect.height * 0.035) {
                metricBlock(layout.distance, valueSize: layout.primaryFontSize, labelSize: layout.labelFontSize, unitSize: layout.unitFontSize)
                    .padding(.top, layout.rect.height * 0.08)

                Spacer(minLength: 0)

                HStack(spacing: 0) {
                    metricBlock(layout.elapsedTime, valueSize: layout.secondaryFontSize, labelSize: layout.labelFontSize, unitSize: layout.unitFontSize)
                        .frame(maxWidth: .infinity)
                    metricBlock(layout.pace, valueSize: layout.secondaryFontSize, labelSize: layout.labelFontSize, unitSize: layout.unitFontSize)
                        .frame(maxWidth: .infinity)
                }

                Spacer(minLength: 0)

                metricBlock(layout.heartRate, valueSize: layout.secondaryFontSize * 1.02, labelSize: layout.labelFontSize, unitSize: layout.unitFontSize)
                    .padding(.bottom, layout.rect.height * 0.06)
            }
            .padding(layout.rect.width * 0.19)
        }
        .frame(width: layout.rect.width, height: layout.rect.height)
        .overlay {
            if isSelected {
                Circle()
                    .stroke(Color.accentColor.opacity(0.85), lineWidth: max(layout.dividerWidth * 2, 2))
            }
        }
        .shadow(color: Color.black.opacity(element.style.shadowOpacity), radius: layout.rect.width * 0.035 + layout.ringWidth, x: 0, y: layout.ringWidth * 0.8)
        .monospacedDigit()
    }

    private func metricBlock(_ metric: OverlayValueComponents, valueSize: Double, labelSize: Double, unitSize: Double) -> some View {
        VStack(spacing: max(unitSize * 0.08, 1)) {
            Text(metric.shortLabel == "HR" ? "HEART RATE" : metric.label.uppercased())
                .font(.custom(element.style.fontName, size: labelSize).weight(.medium))
                .foregroundStyle(labelColor)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: max(unitSize * 0.25, 2)) {
                Text(metric.value)
                    .font(.custom(element.style.fontName, size: valueSize).weight(valueWeight))
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                if !metric.unit.isEmpty {
                    Text(metric.unit)
                        .font(.custom(element.style.fontName, size: unitSize).weight(.medium))
                        .foregroundStyle(labelColor)
                        .lineLimit(1)
                }
            }
        }
    }

    private var gaugeBackground: Color {
        let opacity = max(element.style.backgroundOpacity, 0.58)
        switch layout.preset {
        case .minimalSport:
            return Color.black.opacity(opacity)
        case .highContrast:
            return Color.black.opacity(max(opacity, 0.82))
        case .trailAdventure:
            return Color(red: 0.06, green: 0.07, blue: 0.04).opacity(max(opacity, 0.74))
        case .techFuture:
            return Color(red: 0.02, green: 0.04, blue: 0.07).opacity(max(opacity, 0.76))
        case .retroDigital:
            return Color(red: 0.05, green: 0.045, blue: 0.035).opacity(max(opacity, 0.78))
        }
    }

    private var valueColor: Color {
        switch layout.preset {
        case .trailAdventure:
            return Color(element.style.foregroundColor).opacity(0.92)
        case .retroDigital:
            return Color(element.style.foregroundColor).opacity(0.82)
        default:
            return .white
        }
    }

    private var labelColor: Color {
        switch layout.preset {
        case .highContrast:
            return Color(element.style.foregroundColor)
        case .techFuture:
            return Color(element.style.foregroundColor).opacity(0.9)
        default:
            return .white.opacity(0.72)
        }
    }

    private var tickColor: Color {
        switch layout.preset {
        case .highContrast:
            return .white.opacity(0.92)
        default:
            return Color(element.style.foregroundColor).opacity(0.78)
        }
    }

    private var trackOpacity: Double {
        layout.preset == .highContrast ? 0.78 : 0.26
    }

    private var dividerOpacity: Double {
        layout.preset == .retroDigital ? 0.20 : 0.16
    }

    private var tickCount: Int {
        layout.preset == .retroDigital ? 48 : 36
    }

    private var valueWeight: Font.Weight {
        layout.preset == .retroDigital ? .medium : .bold
    }
}

private struct GaugeTicksView: View {
    let tickCount: Int
    let tickLength: Double
    let tickWidth: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = size / 2
            ZStack {
                ForEach(0..<tickCount, id: \.self) { index in
                    Rectangle()
                        .fill(color.opacity(index.isMultiple(of: 3) ? 1 : 0.46))
                        .frame(width: tickWidth, height: index.isMultiple(of: 3) ? tickLength : tickLength * 0.55)
                        .offset(y: -radius + tickLength / 2)
                        .rotationEffect(.degrees(Double(index) / Double(tickCount) * 360))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct GaugeDividersView: View {
    let lineWidth: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let width = proxy.size.width
                let height = proxy.size.height
                path.move(to: CGPoint(x: width * 0.18, y: height * 0.44))
                path.addLine(to: CGPoint(x: width * 0.82, y: height * 0.44))
                path.move(to: CGPoint(x: width * 0.50, y: height * 0.44))
                path.addLine(to: CGPoint(x: width * 0.50, y: height * 0.72))
                path.move(to: CGPoint(x: width * 0.25, y: height * 0.72))
                path.addLine(to: CGPoint(x: width * 0.75, y: height * 0.72))
            }
            .stroke(color, lineWidth: lineWidth)
        }
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
        VStack(alignment: .leading, spacing: layout.verticalPadding * 0.75) {
            Text(layout.label)
                .font(.custom(element.style.fontName, size: layout.labelFontSize).weight(Font.Weight(element.style.fontWeight)))
                .foregroundStyle(Color(element.style.foregroundColor))
                .monospacedDigit()

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(element.style.foregroundColor).opacity(0.25))
                    Capsule()
                        .fill(Color(element.style.foregroundColor))
                        .frame(width: proxy.size.width * layout.progress)
                }
            }
            .frame(height: layout.trackHeight)
        }
        .frame(width: layout.rect.width - layout.horizontalPadding * 2)
        .padding(.horizontal, layout.horizontalPadding)
        .padding(.vertical, layout.verticalPadding)
        .background(Color.black.opacity(element.style.backgroundOpacity))
        .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius))
        .shadow(color: Color.black.opacity(element.style.shadowOpacity), radius: element.style.shadowRadius, x: 0, y: 2)
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

private extension Color {
    init(_ overlayColor: OverlayColor) {
        self.init(
            red: overlayColor.red,
            green: overlayColor.green,
            blue: overlayColor.blue,
            opacity: overlayColor.alpha
        )
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
