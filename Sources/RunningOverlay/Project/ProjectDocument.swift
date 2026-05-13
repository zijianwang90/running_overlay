import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ProjectDocument: ObservableObject {
    @Published var settings = ProjectSettings()
    @Published var activity = ActivityTimeline.empty
    @Published var mediaItems: [MediaItem] = []
    @Published var mediaFolders: [MediaFolder] = []
    @Published var timeline = TimelineModel.empty
    @Published var overlayLayout = OverlayLayout.empty
    @Published var selection: EditorSelection = .none
    @Published var isPlaying = false
    @Published var playbackRate: Double = 1
    @Published var showingProjectSettings = false
    @Published var showingExportDialog = false
    @Published var overlayTemplates: [OverlayTemplate] = []
    @Published var userAssets: [UserAsset] = [] {
        didSet { IconAssetResolver.configure(userAssets: userAssets, projectURL: projectURL) }
    }
    @Published var showPreviewGuides = false
    @Published var isExporting = false
    @Published var exportProgress: ExportProgressState?
    @Published var mediaPoolPreviewItemID: MediaItem.ID?
    @Published var mediaPoolPreviewSourceTime: TimeInterval = 0
    @Published var fitSourceName: String = ""
    @Published var statusMessage = "Ready to import a FIT file."
    @Published var isTimelineCollapsed = false
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    private let overlayTemplateStore: OverlayTemplateStore
    private(set) var projectURL: URL?
    private var exportTask: Task<Void, Never>?
    private var undoStack: [ProjectSnapshot] = []
    private var redoStack: [ProjectSnapshot] = []
    private var activeUndoSnapshot: ProjectSnapshot?
    private var copiedOverlayConfiguration: CopiedOverlayConfiguration?

    init(overlayTemplateStore: OverlayTemplateStore = OverlayTemplateStore()) {
        self.overlayTemplateStore = overlayTemplateStore
        loadOverlayTemplates()
        IconAssetResolver.configure(userAssets: userAssets, projectURL: projectURL)
    }

    func assetURL(for assetID: UUID) -> URL? {
        guard let asset = userAssets.first(where: { $0.id == assetID }) else { return nil }
        return UserAssetStore.url(for: asset, projectURL: projectURL)
    }

    func importUserAsset(kind: UserAsset.Kind, allowedContentTypes: [UTType]) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = allowedContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let asset = try UserAssetStore.import(url: url, kind: kind, projectURL: projectURL)
            registerUndoPoint()
            userAssets.append(asset)
        } catch {
            statusMessage = "Failed to import asset: \(error.localizedDescription)"
        }
    }

    func importFitFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "fit")].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            print("[RunningOverlay] Importing FIT file: \(url.path)")
            registerUndoPoint()
            activity = try FitFileParser.parse(url: url)
            fitSourceName = url.lastPathComponent
            timeline.fitStartTime = 0
            timeline.playhead = timeline.fitStartTime
            statusMessage = "Loaded FIT: \(url.lastPathComponent), \(formatDuration(activity.duration)), \(formatDistance(activity.distanceMeters))."
            print("[RunningOverlay] FIT import succeeded: \(url.lastPathComponent), duration=\(formatDuration(activity.duration)), distance=\(formatDistance(activity.distanceMeters)), records=\(activity.records.count)")
        } catch {
            statusMessage = "FIT import failed: \(error.localizedDescription)"
            print("[RunningOverlay] FIT import failed: \(url.path)")
            print("[RunningOverlay] Error: \(error.localizedDescription)")
            print("[RunningOverlay] Debug: \(String(reflecting: error))")
        }
    }

    func importVideos() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .movie,
            .mpeg4Movie,
            .quickTimeMovie,
            .avi
        ].compactMap { $0 }
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK else {
            return
        }

        let urls = panel.urls
        guard !urls.isEmpty else {
            return
        }

        importVideoURLs(urls, replacingExisting: true)
    }

    func importVideoURLs(_ urls: [URL], replacingExisting: Bool = false, intoFolder folderID: MediaFolder.ID? = nil) {
        let videoURLs = urls.filter(Self.isSupportedVideoURL)
        guard !videoURLs.isEmpty else {
            statusMessage = "No supported video files were found."
            return
        }

        statusMessage = "Importing \(videoURLs.count) video file(s)..."
        let currentActivity = activity
        let targetFolderID: MediaFolder.ID? = {
            guard let folderID, mediaFolders.contains(where: { $0.id == folderID }) else { return nil }
            return folderID
        }()

        Task {
            let imported = await withTaskGroup(of: MediaItem.self) { group in
                for url in videoURLs {
                    group.addTask {
                        await MediaMetadataReader.read(url: url, activity: currentActivity)
                    }
                }

                var items: [MediaItem] = []
                for await item in group {
                    items.append(item)
                }
                return items.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
            }

            let stampedImported: [MediaItem]
            if let targetFolderID {
                stampedImported = imported.map {
                    var item = $0
                    item.folderID = targetFolderID
                    return item
                }
            } else {
                stampedImported = imported
            }

            registerUndoPoint()
            let importedMediaItems = replacingExisting ? stampedImported : mediaItems + stampedImported
            mediaItems = importedMediaItems

            if replacingExisting {
                timeline = TimelineModel.empty
                mediaPoolPreviewItemID = nil
            }

            let matchableCount = stampedImported.filter {
                if case .readyToMatch = $0.alignmentStatus {
                    return true
                }
                return false
            }.count
            let matchableSuffix = matchableCount > 0 ? ", \(matchableCount) ready for auto-match" : ""
            let destination = targetFolderID.flatMap { id in mediaFolders.first { $0.id == id }?.name }.map { " into \"\($0)\"" } ?? ""
            statusMessage = "Imported \(stampedImported.count) video file(s)\(destination)\(matchableSuffix)."
        }
    }

    func togglePlayback() {
        if isPreviewingMediaPoolItem {
            isPlaying.toggle()
            if isPlaying {
                playbackRate = max(playbackRate, 1)
            } else {
                playbackRate = 1
            }
            statusMessage = isPlaying ? "Source preview started." : "Source preview paused."
            return
        }

        if isTimelineCollapsed, let visibleTime = timeline.visiblePlaybackTime(atOrAfter: timeline.playhead), visibleTime != timeline.playhead {
            setPlayhead(visibleTime)
        }
        isPlaying.toggle()
        if !isPlaying {
            playbackRate = 1
        } else {
            playbackRate = max(playbackRate, 1)
        }
        statusMessage = isPlaying ? "Playback started." : "Playback paused."
    }

    func stopPlayback() {
        isPlaying = false
        playbackRate = 1
        if isPreviewingMediaPoolItem {
            mediaPoolPreviewSourceTime = 0
            statusMessage = "Source preview stopped."
        } else {
            statusMessage = "Playback stopped."
        }
    }

    func increaseForwardPlaybackRate() {
        if !isPlaying {
            isPlaying = true
            playbackRate = 1
        } else {
            playbackRate = min(playbackRate * 2, 8)
        }
        statusMessage = playbackRate == 1 ? "Playback started." : "Playback \(Int(playbackRate))x."
    }

    func setPlaybackRate(_ rate: Double) {
        let clampedRate = min(max(rate, 1), 8)
        playbackRate = clampedRate
        if isPlaying {
            statusMessage = clampedRate == 1 ? "Playback started." : "Playback \(Int(clampedRate))x."
        } else {
            statusMessage = "Playback speed \(Int(clampedRate))x."
        }
    }

    func advancePlayback(by delta: TimeInterval) {
        guard isPlaying else {
            return
        }

        let targetTime = timeline.playhead + delta * playbackRate
        if isTimelineCollapsed {
            guard let visibleTime = timeline.visiblePlaybackTime(atOrAfter: targetTime) else {
                let bounds = timeline.projectBounds(activityDuration: activity.duration)
                setPlayhead(bounds.upperBound)
                isPlaying = false
                playbackRate = 1
                statusMessage = "Playback reached the end."
                return
            }
            setPlayhead(visibleTime)
            return
        }

        setPlayhead(targetTime)
        if timeline.playhead >= timeline.projectBounds(activityDuration: activity.duration).upperBound {
            setPlayhead(timeline.projectBounds(activityDuration: activity.duration).upperBound)
            isPlaying = false
            playbackRate = 1
            statusMessage = "Playback reached the end."
        }
    }

    func setPlayhead(_ elapsedTime: TimeInterval) {
        var updatedTimeline = timeline
        let bounds = updatedTimeline.projectBounds(activityDuration: activity.duration)
        updatedTimeline.playhead = min(max(elapsedTime, bounds.lowerBound), bounds.upperBound)
        timeline = updatedTimeline
    }

    func stepPlayheadByFrames(_ frameCount: Int) {
        guard frameCount != 0 else {
            return
        }
        clearMediaPoolPreview()
        isPlaying = false
        playbackRate = 1
        let frameDuration = 1.0 / max(settings.frameRate.value, 1)
        setPlayhead(timeline.playhead + Double(frameCount) * frameDuration)
        statusMessage = frameCount > 0 ? "Stepped forward \(abs(frameCount)) frame." : "Stepped back \(abs(frameCount)) frame."
    }

    func setPlayheadFromPlayback(_ elapsedTime: TimeInterval) {
        guard isPlaying else {
            return
        }
        if isTimelineCollapsed {
            guard let visibleTime = timeline.visiblePlaybackTime(atOrAfter: elapsedTime) else {
                isPlaying = false
                playbackRate = 1
                statusMessage = "Playback reached the end."
                return
            }
            setPlayhead(visibleTime)
            return
        }
        setPlayhead(elapsedTime)
        if timeline.playhead >= timeline.projectBounds(activityDuration: activity.duration).upperBound {
            isPlaying = false
            playbackRate = 1
            statusMessage = "Playback reached the end."
        }
    }

    func zoomTimelineIn() {
        var updatedTimeline = timeline
        updatedTimeline.zoomIn()
        timeline = updatedTimeline
    }

    func zoomTimelineOut() {
        var updatedTimeline = timeline
        updatedTimeline.zoomOut()
        timeline = updatedTimeline
    }

    var timelineZoomSliderValue: Double {
        switch timeline.zoom {
        case .fit:
            return 0
        case .pixelsPerSecond(let value):
            return Self.sliderValue(forPixelsPerSecond: value)
        }
    }

    var layerDataSampleTime: TimeInterval {
        quantizedLayerDataTime(for: timeline.activityElapsed(atProjectTime: timeline.playhead))
    }

    var defaultExportDestinationURL: URL {
        mediaItems.first?.fileURL?.deletingLastPathComponent()
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies")
    }

    func quantizedLayerDataTime(for elapsedTime: TimeInterval) -> TimeInterval {
        let fps = max(settings.layerDataFrameRate.value, 1)
        let frame = floor(max(elapsedTime, 0) * fps)
        return min(frame / fps, activity.duration)
    }

    var timelineBounds: ClosedRange<TimeInterval> {
        timeline.projectBounds(activityDuration: activity.duration)
    }

    func toggleTimelineCollapse() {
        isTimelineCollapsed.toggle()
        if isTimelineCollapsed, let visibleTime = timeline.visiblePlaybackTime(atOrAfter: timeline.playhead) {
            setPlayhead(visibleTime)
        }
        statusMessage = isTimelineCollapsed ? "Timeline gaps hidden." : "Timeline gaps expanded."
    }

    func setTimelineZoomSliderValue(_ value: Double) {
        var updatedTimeline = timeline
        if value <= 2 {
            updatedTimeline.zoom = .fit
        } else {
            updatedTimeline.zoom = .pixelsPerSecond(Self.pixelsPerSecond(forSliderValue: value))
        }
        timeline = updatedTimeline
    }

    func addOverlayElement(_ type: OverlayElementType) {
        registerUndoPoint()
        let element = makeOverlayElement(type: type, position: CGPoint(x: 0.5, y: 0.5), scale: 1.0)
        overlayLayout.elements.append(element)
        selection = .overlayElement(element.id)
        statusMessage = "Added \(type.label) overlay."
    }

    private func makeOverlayElement(type: OverlayElementType, position: CGPoint, scale: Double) -> OverlayElement {
        let style = defaultOverlayStyle(for: type)
        return OverlayElement(
            type: type,
            position: position,
            scale: scale,
            opacity: 1,
            isVisible: true,
            isLocked: false,
            style: style
        )
    }

    private func defaultOverlayStyle(for type: OverlayElementType) -> OverlayStyle {
        var style = OverlayStyle.default
        let defaultFont = FontLibraryManager.shared.defaultFamily
        style.fontName = defaultFont
        style.labelFontName = defaultFont
        style.unitFontName = defaultFont
        style.unitOption = type.defaultUnitOption
        if type == .routeMap {
            // Route Style preset describes the polyline appearance only; map
            // visibility is driven by `routeMapBackgroundStyle` (see
            // `docs/design/overlays/route-map/route-map-overlay-ui.md`). The default is to show
            // the dark MapKit background with a Gradient route line on top.
            style.routeMapPreset = .gradient
            style.routeMapProvider = .mapKit
            style.routeMapBackgroundStyle = .dark
            style.backgroundOpacity = 0.74
            style.foregroundColor = .cyan
        }
        if type == .decorSolidColor {
            style.decor = DecorStyle(
                shape: .roundedRectangle,
                fillColor: .white,
                width: 240,
                height: 80,
                cornerRadius: 12
            )
            style.backgroundEnabled = false
        }
        if type == .decorIcon {
            style.decor = DecorStyle(
                shape: .roundedRectangle,
                fillColor: OverlayColor(red: 0, green: 0, blue: 0, alpha: 0),
                width: 80,
                height: 80,
                cornerRadius: 0,
                iconAsset: .sfSymbol(name: "star.fill", weight: .medium, scale: .large),
                iconTint: .white,
                iconPreserveSVGColors: false,
                iconContentMode: .fit
            )
            style.backgroundEnabled = false
        }
        if type == .weatherWidget {
            style.weatherWidget = WeatherWidgetStyle.preset(.simpleCard)
        }
        if type == .decorText {
            style.decor = DecorStyle(
                shape: .rectangle,
                fillColor: OverlayColor(red: 0, green: 0, blue: 0, alpha: 0),
                width: 320,
                height: 60,
                cornerRadius: 0,
                textContent: "Hello",
                textFont: .system(family: FontLibraryManager.shared.defaultFamily),
                textSize: 36,
                textAlignment: .center,
                textLineHeight: 1.2,
                textLetterSpacing: 0,
                textFillMode: .solid(color: .white),
                textStrokeWidth: 0,
                textStrokeColor: .white,
                textAutoFit: false
            )
            style.backgroundEnabled = false
        }
        if let recommended = type.defaultNumericPreset {
            style.textPreset = recommended
            if let tokens = recommended.recommendedTokens {
                style.fontName = tokens.fontName
                style.fontWeight = tokens.fontWeight
                style.fontSize = tokens.fontSize
                style.textAlignment = tokens.textAlignment
                style.showLabel = tokens.showLabel
                style.showUnit = tokens.showUnit
                style.labelPosition = tokens.labelPosition
                style.unitPosition = tokens.unitPosition
                if let size = tokens.labelFontSize {
                    style.labelFontSize = size
                }
                if let weight = tokens.labelFontWeight {
                    style.labelFontWeight = weight
                }
                if let size = tokens.unitFontSize {
                    style.unitFontSize = size
                }
                if let weight = tokens.unitFontWeight {
                    style.unitFontWeight = weight
                }
                style.backgroundEnabled = tokens.backgroundEnabled
                if let bg = tokens.backgroundColor {
                    style.backgroundColor = bg
                }
                if let opacity = tokens.backgroundOpacity {
                    style.backgroundOpacity = opacity
                }
                style.backgroundRadius = tokens.backgroundRadius
                if let accent = tokens.accentColor {
                    style.accentColor = accent
                }
            }
        }
        return style
    }

    func selectClip(_ clipID: TimelineClip.ID) {
        selection = .timelineClip(clipID)
    }

    func selectedClip(_ clipID: TimelineClip.ID) -> TimelineClip? {
        timeline.clip(with: clipID)
    }

    func isAutoMatchedClip(_ clipID: TimelineClip.ID) -> Bool {
        guard let mediaItemID = timeline.clip(with: clipID)?.mediaItemID,
              let mediaItem = mediaItems.first(where: { $0.id == mediaItemID }) else {
            return false
        }
        switch mediaItem.alignmentStatus {
        case .aligned(let source):
            return source != "manual"
        case .readyToMatch:
            return true
        case .needsManualPlacement:
            return false
        }
    }

    func placeMediaItem(_ mediaItemID: MediaItem.ID, onTrack trackName: String, at elapsedTime: TimeInterval) {
        guard let mediaIndex = mediaItems.firstIndex(where: { $0.id == mediaItemID }) else {
            statusMessage = "Could not place media: item not found."
            return
        }

        let mediaItem = mediaItems[mediaIndex]
        if timeline.wouldClipOverlap(
            mediaItemID: mediaItem.id,
            trackName: trackName,
            startTime: elapsedTime,
            duration: mediaItem.duration
        ) {
            statusMessage = "Cannot place \"\(mediaItem.displayName)\" on \(trackName): it overlaps an existing clip. Try \"Match to New Layer\" instead."
            return
        }

        registerUndoPoint()
        var updatedTimeline = timeline
        guard let clipID = updatedTimeline.addOrMoveClip(
            mediaItem: mediaItem,
            trackName: trackName,
            startTime: elapsedTime,
            activity: activity
        ) else {
            statusMessage = "Could not place \(mediaItem.displayName)."
            return
        }
        timeline = updatedTimeline

        mediaItems[mediaIndex].alignmentStatus = .aligned(source: "manual")
        mediaItems[mediaIndex].cameraGroupID = trackName
        selection = .timelineClip(clipID)
        statusMessage = "Placed \(mediaItem.displayName) at \(formatDuration(elapsedTime))."
    }

    func matchMediaItemsToCurrentLayer(_ mediaItemIDs: Set<MediaItem.ID>) {
        matchMediaItems(mediaItemIDs, toTrackName: currentLayerName())
    }

    func matchMediaItemsToNewLayer(_ mediaItemIDs: Set<MediaItem.ID>) {
        matchMediaItems(mediaItemIDs, toTrackName: timeline.nextLayerName())
    }

    @discardableResult
    func createMediaFolder(name: String = "New Folder", containing mediaItemIDs: Set<MediaItem.ID> = []) -> MediaFolder.ID {
        registerUndoPoint()
        let folder = MediaFolder(name: uniqueFolderName(from: name))
        mediaFolders.append(folder)
        if !mediaItemIDs.isEmpty {
            for index in mediaItems.indices where mediaItemIDs.contains(mediaItems[index].id) {
                mediaItems[index].folderID = folder.id
            }
            statusMessage = "Created folder \"\(folder.name)\" with \(mediaItemIDs.count) item(s)."
        } else {
            statusMessage = "Created folder \"\(folder.name)\"."
        }
        return folder.id
    }

    func renameMediaFolder(_ folderID: MediaFolder.ID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = mediaFolders.firstIndex(where: { $0.id == folderID }),
              mediaFolders[index].name != trimmed else {
            return
        }
        registerUndoPoint()
        mediaFolders[index].name = uniqueFolderName(from: trimmed, excluding: folderID)
        statusMessage = "Renamed folder to \"\(mediaFolders[index].name)\"."
    }

    func deleteMediaFolder(_ folderID: MediaFolder.ID) {
        guard let folderIndex = mediaFolders.firstIndex(where: { $0.id == folderID }) else {
            return
        }
        registerUndoPoint()
        let folderName = mediaFolders[folderIndex].name
        for index in mediaItems.indices where mediaItems[index].folderID == folderID {
            mediaItems[index].folderID = nil
        }
        mediaFolders.remove(at: folderIndex)
        statusMessage = "Deleted folder \"\(folderName)\". Contained items returned to the root."
    }

    func moveMediaItems(_ mediaItemIDs: Set<MediaItem.ID>, toFolder folderID: MediaFolder.ID?) {
        guard !mediaItemIDs.isEmpty else {
            return
        }
        if let folderID, !mediaFolders.contains(where: { $0.id == folderID }) {
            return
        }
        let changed = mediaItems.contains { mediaItemIDs.contains($0.id) && $0.folderID != folderID }
        guard changed else {
            return
        }
        registerUndoPoint()
        for index in mediaItems.indices where mediaItemIDs.contains(mediaItems[index].id) {
            mediaItems[index].folderID = folderID
        }
        if let folderID, let folder = mediaFolders.first(where: { $0.id == folderID }) {
            statusMessage = "Moved \(mediaItemIDs.count) item(s) to \"\(folder.name)\"."
        } else {
            statusMessage = "Moved \(mediaItemIDs.count) item(s) to the root."
        }
    }

    private func uniqueFolderName(from name: String, excluding folderID: MediaFolder.ID? = nil) -> String {
        let base = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New Folder" : name.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = Set(mediaFolders.filter { $0.id != folderID }.map(\.name))
        if !existing.contains(base) {
            return base
        }
        var counter = 2
        while existing.contains("\(base) \(counter)") {
            counter += 1
        }
        return "\(base) \(counter)"
    }

    func deleteMediaItems(_ mediaItemIDs: Set<MediaItem.ID>) {
        guard !mediaItemIDs.isEmpty else {
            return
        }
        registerUndoPoint()
        mediaItems.removeAll { mediaItemIDs.contains($0.id) }
        if let mediaPoolPreviewItemID, mediaItemIDs.contains(mediaPoolPreviewItemID) {
            self.mediaPoolPreviewItemID = nil
            mediaPoolPreviewSourceTime = 0
            isPlaying = false
            playbackRate = 1
        }
        var updatedTimeline = timeline
        updatedTimeline.deleteClips(forMediaItemIDs: mediaItemIDs)
        timeline = updatedTimeline
        if case .timelineClip(let clipID) = selection, timeline.clip(with: clipID) == nil {
            selection = .none
        }
        statusMessage = "Deleted \(mediaItemIDs.count) media item(s) from the media pool."
    }

    func setSelectedClipOffset(_ clipID: TimelineClip.ID, offset: TimeInterval) {
        registerContinuousUndoPoint()
        let pausedSourceTime = stationarySourceTime(for: clipID)
        var updatedTimeline = timeline
        updatedTimeline.setClipOffset(clipID, offset: offset, activityDuration: activity.duration)
        if let pausedSourceTime, let updatedClip = updatedTimeline.clip(with: clipID) {
            updatedTimeline.playhead = updatedClip.effectiveStartTime + pausedSourceTime
        }
        timeline = updatedTimeline
    }

    func moveClip(_ clipID: TimelineClip.ID, toEffectiveStartTime effectiveStartTime: TimeInterval) {
        registerContinuousUndoPoint()
        var updatedTimeline = timeline
        updatedTimeline.moveClip(clipID, toEffectiveStartTime: effectiveStartTime, activityDuration: activity.duration)
        timeline = updatedTimeline
    }

    func moveTimelineClipFromDrag(_ clipID: TimelineClip.ID, toEffectiveStartTime effectiveStartTime: TimeInterval) {
        if isAutoMatchedClip(clipID), let clip = timeline.clip(with: clipID) {
            setSelectedClipOffset(clipID, offset: effectiveStartTime - clip.startTime)
        } else {
            moveClip(clipID, toEffectiveStartTime: effectiveStartTime)
        }
    }

    func setClipDuration(_ clipID: TimelineClip.ID, duration: TimeInterval) {
        registerContinuousUndoPoint()
        var updatedTimeline = timeline
        updatedTimeline.setClipDuration(clipID, duration: duration, activityDuration: activity.duration)
        timeline = updatedTimeline
    }

    func moveFitStart(to startTime: TimeInterval) {
        registerContinuousUndoPoint()
        var updatedTimeline = timeline
        updatedTimeline.moveFitStart(to: startTime)
        timeline = updatedTimeline
        statusMessage = "Moved FIT axis to \(formatSignedDuration(startTime))."
    }

    func removeTrack(named name: String) {
        guard timeline.tracks.contains(where: { $0.name == name }) else {
            return
        }
        registerUndoPoint()
        var updatedTimeline = timeline
        updatedTimeline.removeTrack(named: name)
        timeline = updatedTimeline
        if settings.previewTrackName == name {
            settings.previewTrackName = nil
        }
        settings.disabledPreviewTrackNames.remove(name)
        if case .timelineClip(let clipID) = selection, timeline.clip(with: clipID) == nil {
            selection = .none
        }
        statusMessage = "Deleted timeline layer: \(name)."
    }

    func renameTrack(containing clipID: TimelineClip.ID, to name: String) {
        registerUndoPoint()
        var updatedTimeline = timeline
        updatedTimeline.renameTrack(containing: clipID, to: name)
        timeline = updatedTimeline
        if let clip = timeline.clip(with: clipID),
           let mediaIndex = mediaItems.firstIndex(where: { $0.id == clip.mediaItemID }) {
            mediaItems[mediaIndex].cameraGroupID = clip.cameraGroupID
        }
    }

    func finishContinuousEdit() {
        activeUndoSnapshot = nil
        updateUndoRedoFlags()
    }

    private func stationarySourceTime(for clipID: TimelineClip.ID) -> TimeInterval? {
        guard !isPlaying, let clip = timeline.clip(with: clipID) else {
            return nil
        }
        let sourceTime = timeline.playhead - clip.effectiveStartTime
        guard sourceTime >= 0, sourceTime <= clip.duration else {
            return nil
        }
        return sourceTime
    }

    func applyOffsetToCurrentLayer(for clipID: TimelineClip.ID) {
        guard let clip = timeline.clip(with: clipID) else {
            return
        }
        registerUndoPoint()
        var updatedTimeline = timeline
        updatedTimeline.applyOffset(
            clip.alignmentOffset,
            toTrackContaining: clipID,
            activityDuration: activity.duration
        )
        timeline = updatedTimeline
        let clipCount = timeline.tracks.first(where: { $0.clips.contains(where: { $0.id == clipID }) })?.clips.count ?? 0
        let trackName = timeline.tracks.first(where: { $0.clips.contains(where: { $0.id == clipID }) })?.name ?? "layer"
        statusMessage = "Applied \(String(format: "%.1f", clip.alignmentOffset))s offset to all \(clipCount) clips in \(trackName)."
    }

    func previewMediaAtPlayhead() -> PreviewMedia? {
        guard let clip = timeline.visibleClip(
                at: timeline.playhead,
                preferredTrackName: settings.previewTrackName,
                disabledTrackNames: settings.disabledPreviewTrackNames
              ),
              let mediaItemID = clip.mediaItemID,
              let mediaItem = mediaItems.first(where: { $0.id == mediaItemID }),
              let fileURL = mediaItem.fileURL else {
            return nil
        }

        return PreviewMedia(
            url: fileURL,
            sourceTime: timeline.playhead - clip.effectiveStartTime,
            clipStartTime: clip.effectiveStartTime,
            clipID: clip.id
        )
    }

    func activePreviewMedia() -> PreviewMedia? {
        if let mediaPoolPreviewItemID,
           let mediaItem = mediaItems.first(where: { $0.id == mediaPoolPreviewItemID }),
           let fileURL = mediaItem.fileURL {
            return PreviewMedia(
                url: fileURL,
                sourceTime: mediaPoolPreviewSourceTime,
                clipStartTime: 0,
                clipID: mediaItem.id,
                syncsToSourceTime: false
            )
        }
        return previewMediaAtPlayhead()
    }

    var isPreviewingMediaPoolItem: Bool {
        guard let mediaPoolPreviewItemID else {
            return false
        }
        return mediaItems.contains { $0.id == mediaPoolPreviewItemID && $0.fileURL != nil }
    }

    func previewMediaPoolItem(_ mediaItemID: MediaItem.ID) {
        guard let mediaItem = mediaItems.first(where: { $0.id == mediaItemID }),
              mediaItem.fileURL != nil else {
            statusMessage = "Could not preview media: file not found."
            return
        }
        mediaPoolPreviewItemID = mediaItemID
        mediaPoolPreviewSourceTime = 0
        playbackRate = 1
        isPlaying = true
        statusMessage = "Previewing media: \(mediaItem.displayName)."
    }

    func clearMediaPoolPreview() {
        guard mediaPoolPreviewItemID != nil else {
            return
        }
        mediaPoolPreviewItemID = nil
        mediaPoolPreviewSourceTime = 0
        isPlaying = false
        playbackRate = 1
        statusMessage = "Timeline preview."
    }

    func setMediaPoolPreviewSourceTime(_ sourceTime: TimeInterval) {
        guard isPreviewingMediaPoolItem else {
            return
        }
        mediaPoolPreviewSourceTime = max(sourceTime, 0)
    }

    func jumpToPreviousPreviewItem() {
        if let mediaPoolPreviewItemID,
           let currentIndex = mediaItems.firstIndex(where: { $0.id == mediaPoolPreviewItemID }),
           !mediaItems.isEmpty {
            let nextIndex = currentIndex == mediaItems.startIndex ? mediaItems.index(before: mediaItems.endIndex) : mediaItems.index(before: currentIndex)
            previewMediaPoolItem(mediaItems[nextIndex].id)
            return
        }

        let clips = timeline.tracks.flatMap(\.clips).sorted { $0.effectiveStartTime < $1.effectiveStartTime }
        guard let previousClip = clips.last(where: { $0.effectiveStartTime < timeline.playhead - 0.01 }) ?? clips.last else {
            return
        }
        setPlayhead(previousClip.effectiveStartTime)
    }

    func jumpToNextPreviewItem() {
        if let mediaPoolPreviewItemID,
           let currentIndex = mediaItems.firstIndex(where: { $0.id == mediaPoolPreviewItemID }),
           !mediaItems.isEmpty {
            let nextIndex = mediaItems.index(after: currentIndex) == mediaItems.endIndex ? mediaItems.startIndex : mediaItems.index(after: currentIndex)
            previewMediaPoolItem(mediaItems[nextIndex].id)
            return
        }

        let clips = timeline.tracks.flatMap(\.clips).sorted { $0.effectiveStartTime < $1.effectiveStartTime }
        guard let nextClip = clips.first(where: { $0.effectiveStartTime > timeline.playhead + 0.01 }) ?? clips.first else {
            return
        }
        setPlayhead(nextClip.effectiveStartTime)
    }

    func setPreviewTrackName(_ trackName: String?) {
        settings.previewTrackName = trackName
        statusMessage = trackName.map { "Preview track: \($0)." } ?? "Preview track: Auto."
    }

    func setPreviewTrackDisabled(_ trackName: String, disabled: Bool) {
        if disabled {
            settings.disabledPreviewTrackNames.insert(trackName)
            if settings.previewTrackName == trackName {
                settings.previewTrackName = nil
            }
        } else {
            settings.disabledPreviewTrackNames.remove(trackName)
        }
        statusMessage = disabled ? "Disabled preview track: \(trackName)." : "Enabled preview track: \(trackName)."
    }

    func selectOverlay(_ elementID: OverlayElement.ID) {
        selection = .overlayElement(elementID)
    }

    func openOverlayDetailFromList(_ elementID: OverlayElement.ID) {
        guard let element = selectedOverlay(elementID) else {
            statusMessage = "Overlay not found."
            return
        }
        guard !element.isLocked else {
            statusMessage = "Element is locked. Unlock it before editing."
            return
        }
        selection = .overlayElement(elementID)
    }

    func selectedOverlay(_ elementID: OverlayElement.ID) -> OverlayElement? {
        overlayLayout.elements.first { $0.id == elementID }
    }

    func copyOverlayProperties(from elementID: OverlayElement.ID) {
        guard let element = selectedOverlay(elementID) else {
            statusMessage = "Unable to copy overlay properties."
            return
        }
        copiedOverlayConfiguration = CopiedOverlayConfiguration(element: element)
        statusMessage = "Copied \(element.type.label) properties."
    }

    func canPasteOverlayProperties(to elementID: OverlayElement.ID) -> Bool {
        guard let target = selectedOverlay(elementID),
              let copiedOverlayConfiguration else {
            return false
        }
        return target.type.pasteCategory == copiedOverlayConfiguration.category
    }

    func pasteOverlayProperties(to elementID: OverlayElement.ID) {
        guard let copiedOverlayConfiguration else {
            statusMessage = "No copied overlay properties."
            return
        }
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            statusMessage = "Unable to paste overlay properties."
            return
        }
        let targetType = overlayLayout.elements[index].type
        guard targetType.pasteCategory == copiedOverlayConfiguration.category else {
            statusMessage = "Paste is only available for the same overlay category."
            return
        }

        registerUndoPoint()
        overlayLayout.elements[index].scale = copiedOverlayConfiguration.scale
        overlayLayout.elements[index].opacity = copiedOverlayConfiguration.opacity
        overlayLayout.elements[index].isVisible = copiedOverlayConfiguration.isVisible
        overlayLayout.elements[index].isLocked = copiedOverlayConfiguration.isLocked
        overlayLayout.elements[index].style = copiedOverlayConfiguration.style
        statusMessage = "Pasted properties to \(targetType.label)."
    }

    func moveOverlay(_ elementID: OverlayElement.ID, to position: CGPoint) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        guard !overlayLayout.elements[index].isLocked else {
            return
        }
        overlayLayout.elements[index].position = CGPoint(
            x: min(max(position.x, 0), 1),
            y: min(max(position.y, 0), 1)
        )
    }

    func nudgeSelectedOverlay(dx: Double, dy: Double) {
        guard case .overlayElement(let elementID) = selection,
              let element = selectedOverlay(elementID) else {
            return
        }
        moveOverlay(
            elementID,
            to: CGPoint(
                x: element.position.x + dx,
                y: element.position.y + dy
            )
        )
        finishContinuousEdit()
    }

    func setOverlayScale(_ elementID: OverlayElement.ID, scale: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].scale = min(max(scale, 0.25), 4)
    }

    func setOverlayOpacity(_ elementID: OverlayElement.ID, opacity: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].opacity = min(max(opacity, 0), 1)
    }

    func setOverlayFontSize(_ elementID: OverlayElement.ID, fontSize: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.fontSize = fontSize
    }

    func setOverlayTextPreset(_ elementID: OverlayElement.ID, textPreset: OverlayTextPreset) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.textPreset = textPreset
    }

    func setOverlayDistanceTimelinePreset(_ elementID: OverlayElement.ID, preset: DistanceTimelinePreset) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.distanceTimeline = DistanceTimelineStyle.preset(preset)
    }

    func mutateDistanceTimelineStyle(_ elementID: OverlayElement.ID, _ mutate: (inout DistanceTimelineStyle) -> Void) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        mutate(&overlayLayout.elements[index].style.distanceTimeline)
    }

    func setOverlayElevationChartPreset(_ elementID: OverlayElement.ID, preset: ElevationChartPreset) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.elevationChart = ElevationChartStyle.preset(preset)
    }

    func mutateElevationChartStyle(_ elementID: OverlayElement.ID, _ mutate: (inout ElevationChartStyle) -> Void) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        mutate(&overlayLayout.elements[index].style.elevationChart)
    }

    func mutateElevationChartStyleContinuous(_ elementID: OverlayElement.ID, _ mutate: (inout ElevationChartStyle) -> Void) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        mutate(&overlayLayout.elements[index].style.elevationChart)
    }

    func importDistanceTimelineIconAsset(_ elementID: OverlayElement.ID) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "svg")].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let source = try String(contentsOf: url, encoding: .utf8)
            let isAnimated = source.localizedCaseInsensitiveContains("<animate")
                || source.localizedCaseInsensitiveContains("animateTransform")
            registerUndoPoint()
            guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
                return
            }
            var slot = overlayLayout.elements[index].style.distanceTimeline.mediaSlot
            slot.mode = isAnimated ? .animatedSVG : .staticSVG
            slot.assetName = url.lastPathComponent
            slot.svgSource = source
            slot.animationDuration = Self.svgDuration(from: source) ?? slot.animationDuration
            overlayLayout.elements[index].style.distanceTimeline.mediaSlot = slot
            overlayLayout.elements[index].style.distanceTimeline.mediaSlotMode = slot.mode
            overlayLayout.elements[index].style.distanceTimeline.mediaSlotEnabled = true
            statusMessage = "Imported icon asset: \(url.lastPathComponent)."
        } catch {
            statusMessage = "Icon import failed: \(error.localizedDescription)"
        }
    }

    /// Applies an `OverlayTextPreset` and, when the preset declares
    /// recommended typography/style tokens, snaps fontName/fontSize/
    /// fontWeight/textAlignment/showLabel/showUnit/backgroundEnabled/
    /// accentColor to those tokens so users get the intended look.
    func applyOverlayTextPreset(_ elementID: OverlayElement.ID, textPreset: OverlayTextPreset) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.textPreset = textPreset
        guard let tokens = textPreset.recommendedTokens else { return }
        var style = overlayLayout.elements[index].style
        style.fontName = tokens.fontName
        style.fontWeight = tokens.fontWeight
        style.fontSize = tokens.fontSize
        style.textAlignment = tokens.textAlignment
        style.showLabel = tokens.showLabel
        style.showUnit = tokens.showUnit
        style.labelPosition = tokens.labelPosition
        style.unitPosition = tokens.unitPosition
        if let size = tokens.labelFontSize {
            style.labelFontSize = size
        }
        if let weight = tokens.labelFontWeight {
            style.labelFontWeight = weight
        }
        if let size = tokens.unitFontSize {
            style.unitFontSize = size
        }
        if let weight = tokens.unitFontWeight {
            style.unitFontWeight = weight
        }
        style.backgroundEnabled = tokens.backgroundEnabled
        if let bg = tokens.backgroundColor {
            style.backgroundColor = bg
        }
        if let opacity = tokens.backgroundOpacity {
            style.backgroundOpacity = opacity
        }
        style.backgroundRadius = tokens.backgroundRadius
        if let accent = tokens.accentColor {
            style.accentColor = accent
            if textPreset == .splitLabel || textPreset == .racingStripe || textPreset == .editorial {
                style.labelColor = accent
            }
        }
        if let divider = tokens.divider {
            style.dividerEnabled = true
            style.dividerColor = divider.color
            style.dividerThickness = divider.thickness
            style.dividerOpacity = divider.opacity
        } else {
            // Preset has no built-in divider; collapse the section by default.
            // The user can still toggle it on if they want a custom one.
            style.dividerEnabled = false
        }
        overlayLayout.elements[index].style = style
    }

    private static func svgDuration(from source: String) -> Double? {
        let pattern = #"\bdur\s*=\s*("[^"]*"|'[^']*')"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: source, range: NSRange(source.startIndex..<source.endIndex, in: source)),
              let range = Range(match.range(at: 1), in: source) else {
            return nil
        }
        var value = String(source[range])
        value.removeFirst()
        value.removeLast()
        if value.hasSuffix("ms") {
            return Double(value.dropLast(2)).map { $0 / 1000 }
        }
        if value.hasSuffix("s") {
            return Double(value.dropLast())
        }
        return Double(value)
    }

    func setOverlayGaugePreset(_ elementID: OverlayElement.ID, gaugePreset: OverlayGaugePreset) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.gaugePreset = gaugePreset
        // Re-seed the gauge style block so visual parameters track the picked
        // preset. The user can then continue tweaking individual fields via
        // `mutateGaugeStyle(_:_:)`.
        overlayLayout.elements[index].style.gauge = RunningGaugeStyle.preset(gaugePreset)
    }

    /// Generic mutator for the Running Gauge sub-style. Used by the gauge
    /// inspector to update individual fields (layout, region configs, dial,
    /// ring, ticks, dividers, color, effects). Registers a single undo
    /// checkpoint per call so continuous controls (sliders) should still
    /// route through `finishContinuousEdit()` when committing.
    func mutateGaugeStyle(_ elementID: OverlayElement.ID, _ mutate: (inout RunningGaugeStyle) -> Void) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        mutate(&overlayLayout.elements[index].style.gauge)
    }

    /// Updates the layout preset and regenerates the per-region defaults.
    func setOverlayGaugeLayout(_ elementID: OverlayElement.ID, layout: RunningGaugeLayoutPreset) {
        mutateGaugeStyle(elementID) { gauge in
            gauge.layoutPreset = layout
            gauge.regions = RunningGaugeStyle.defaultRegions(for: layout)
        }
    }

    /// Updates a single region config in place. The region is identified by
    /// its `RunningGaugeRegion` since each region appears at most once per
    /// layout preset.
    func updateOverlayGaugeRegion(
        _ elementID: OverlayElement.ID,
        region: RunningGaugeRegion,
        _ mutate: (inout RunningGaugeRegionConfig) -> Void
    ) {
        mutateGaugeStyle(elementID) { gauge in
            guard let regionIndex = gauge.regions.firstIndex(where: { $0.region == region }) else {
                return
            }
            mutate(&gauge.regions[regionIndex])
        }
    }

    func setOverlayRouteMapPreset(_ elementID: OverlayElement.ID, routeMapPreset: OverlayRouteMapPreset) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.routeMapPreset = routeMapPreset
    }

    /// Toggle the map background visibility. Off → `.none`, on → restore the
    /// previously selected map style (or `.dark` if the previous value was
    /// already `.none`). Map provider is recomputed by the layout from the
    /// background style, so we only need to mutate one field.
    func setOverlayRouteMapShowMap(_ elementID: OverlayElement.ID, showMap: Bool) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        if showMap {
            if overlayLayout.elements[index].style.routeMapBackgroundStyle == .none {
                overlayLayout.elements[index].style.routeMapBackgroundStyle = .dark
            }
        } else {
            overlayLayout.elements[index].style.routeMapBackgroundStyle = .none
        }
    }

    func setOverlayRouteMapWidth(_ elementID: OverlayElement.ID, width: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.routeMapWidth = min(max(width, 80), 1200)
    }

    func setOverlayRouteMapHeight(_ elementID: OverlayElement.ID, height: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.routeMapHeight = min(max(height, 80), 1200)
    }

    func setOverlayRouteMapShape(_ elementID: OverlayElement.ID, shape: OverlayRouteMapShape) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.routeMapShape = shape
        // Picking circle collapses width and height to the shorter edge so
        // resizing handles in the editor don't desync from the rendered
        // diameter. Square keeps the previous width/height as-is so the user
        // can still drag a non-square rectangle.
        if shape == .circle {
            let side = min(overlayLayout.elements[index].style.routeMapWidth,
                           overlayLayout.elements[index].style.routeMapHeight)
            overlayLayout.elements[index].style.routeMapWidth = side
            overlayLayout.elements[index].style.routeMapHeight = side
        }
    }

    func setOverlayRouteMapCornerRadius(_ elementID: OverlayElement.ID, radius: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.routeMapCornerRadius = min(max(radius, 0), 120)
    }

    func setOverlayRouteMapEdgeFade(_ elementID: OverlayElement.ID, edgeFade: OverlayRouteMapEdgeFade) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.routeMapEdgeFade = edgeFade
    }

    func setOverlayRouteMapFadeAmount(_ elementID: OverlayElement.ID, amount: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.routeMapFadeAmount = min(max(amount, 0), 0.45)
    }

    /// Apply a Route Map container preset (Square / Circle × Hard / Gradient
    /// edge). Writes the bundled defaults declared by
    /// `OverlayRouteMapContainerPreset` onto a single undo point so the
    /// preset switch is reversible in one step.
    ///
    /// See `docs/design/overlays/route-map/route-map-overlay-ui.md` for the value table.
    func setOverlayRouteMapContainerPreset(_ elementID: OverlayElement.ID, containerPreset: OverlayRouteMapContainerPreset) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.routeMapContainerPreset = containerPreset
        overlayLayout.elements[index].style.routeMapShape = containerPreset.shape
        overlayLayout.elements[index].style.routeMapEdgeFade = containerPreset.edgeFade
        overlayLayout.elements[index].style.routeMapFadeAmount = containerPreset.fadeAmount
        overlayLayout.elements[index].style.routeMapMapOpacity = containerPreset.mapOpacity
        overlayLayout.elements[index].style.shadowEnabled = containerPreset.shadowEnabled
        overlayLayout.elements[index].style.shadowOpacity = containerPreset.shadowOpacity
        overlayLayout.elements[index].style.shadowRadius = containerPreset.shadowRadius
        overlayLayout.elements[index].style.shadowOffsetX = containerPreset.shadowOffsetX
        overlayLayout.elements[index].style.shadowOffsetY = containerPreset.shadowOffsetY
    }

    func setOverlayRouteMapMapOpacity(_ elementID: OverlayElement.ID, opacity: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.routeMapMapOpacity = min(max(opacity, 0), 1)
    }

    func setOverlayRouteMapBorderVisible(_ elementID: OverlayElement.ID, isVisible: Bool) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.routeMapBorderVisible = isVisible
    }

    func setOverlayRouteMapEdgeSoftness(_ elementID: OverlayElement.ID, amount: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        let clamped = min(max(amount, 0), 0.45)
        overlayLayout.elements[index].style.routeMapFadeAmount = clamped
        overlayLayout.elements[index].style.routeMapEdgeFade = clamped > 0 ? .fadeOut : .solid
    }

    func setOverlayRouteMapColorMode(_ elementID: OverlayElement.ID, colorMode: OverlayRouteMapColorMode) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.routeMapColorMode = colorMode
    }

    func setOverlayRouteMapGradientStart(_ elementID: OverlayElement.ID, color: OverlayColor) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.routeMapGradientStart = color
    }

    func setOverlayRouteMapGradientMiddle(_ elementID: OverlayElement.ID, color: OverlayColor) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.routeMapGradientMiddle = color
    }

    func setOverlayRouteMapGradientEnd(_ elementID: OverlayElement.ID, color: OverlayColor) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.routeMapGradientEnd = color
    }

    func setOverlayRouteMapMarkerStyle(_ elementID: OverlayElement.ID, markerStyle: OverlayRouteMapMarkerStyle) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.routeMapMarkerStyle = markerStyle
        overlayLayout.elements[index].style.routeMapStartMarkerStyle = markerStyle
        overlayLayout.elements[index].style.routeMapEndMarkerStyle = markerStyle
    }

    func setOverlayRouteMapBackgroundStyle(_ elementID: OverlayElement.ID, backgroundStyle: OverlayRouteMapBackgroundStyle) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.routeMapBackgroundStyle = backgroundStyle
        overlayLayout.elements[index].style.routeMapProvider = backgroundStyle == .none ? .none : .mapKit
    }

    func setOverlayRouteMapLegendVisible(_ elementID: OverlayElement.ID, isVisible: Bool) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.routeMapLegendVisible = isVisible
    }

    func setOverlayRouteMapStatsBarVisible(_ elementID: OverlayElement.ID, isVisible: Bool) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.routeMapStatsBar.visible = isVisible
    }

    func setOverlayRouteMapStatsBarBackgroundOpacity(_ elementID: OverlayElement.ID, opacity: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.routeMapStatsBar.backgroundOpacity = min(max(opacity, 0), 1)
    }

    func setOverlayRouteMapStatsBarSlotMetric(_ elementID: OverlayElement.ID, slotIndex: Int, metric: RouteMapStatsMetric) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        guard overlayLayout.elements[index].style.routeMapStatsBar.slots.indices.contains(slotIndex) else { return }
        overlayLayout.elements[index].style.routeMapStatsBar.slots[slotIndex].metric = metric
    }

    func setOverlayRouteMapStatsBarSlotVisible(_ elementID: OverlayElement.ID, slotIndex: Int, isVisible: Bool) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        guard overlayLayout.elements[index].style.routeMapStatsBar.slots.indices.contains(slotIndex) else { return }
        overlayLayout.elements[index].style.routeMapStatsBar.slots[slotIndex].visible = isVisible
    }

    func setOverlayRouteMapStatsBarPlacement(_ elementID: OverlayElement.ID, placement: RouteMapStatsBarPlacement) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.routeMapStatsBar.placement = placement
    }

    func setOverlayRouteMapStatsBarLayoutMode(_ elementID: OverlayElement.ID, layoutMode: RouteMapStatsBarLayoutMode) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.routeMapStatsBar.layoutMode = layoutMode
    }

    func setOverlayRouteMapStatsBarHeight(_ elementID: OverlayElement.ID, height: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.routeMapStatsBar.height = min(max(height, 32), 160)
    }

    func setOverlayRouteMapStatsBarInside(_ elementID: OverlayElement.ID, isInside: Bool) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.routeMapStatsBar.inside = isInside
    }

    func setOverlayRouteMapStatsBarWidth(_ elementID: OverlayElement.ID, width: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.routeMapStatsBar.width = max(width, 0)
    }

    func setOverlayRouteMapStatsBarOffsetX(_ elementID: OverlayElement.ID, offsetX: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.routeMapStatsBar.offsetX = offsetX
    }

    func setOverlayRouteMapStatsBarOffsetY(_ elementID: OverlayElement.ID, offsetY: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.routeMapStatsBar.offsetY = offsetY
    }

    func setOverlayRouteMapStatsBarItemSpacing(_ elementID: OverlayElement.ID, spacing: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.routeMapStatsBar.itemSpacing = min(max(spacing, 0), 32)
    }

    func setOverlayRouteMapStatsBarDividerOpacity(_ elementID: OverlayElement.ID, opacity: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.routeMapStatsBar.dividerOpacity = min(max(opacity, 0), 1)
    }

    func setOverlayRouteMapStatsBarCornerRadius(_ elementID: OverlayElement.ID, radius: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.routeMapStatsBar.cornerRadius = min(max(radius, 0), 40)
    }

    func setOverlayRouteMapStatsBarValueFontName(_ elementID: OverlayElement.ID, fontName: String) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.routeMapStatsBar.valueFontName = fontName
    }

    func setOverlayRouteMapStatsBarValueFontSize(_ elementID: OverlayElement.ID, fontSize: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.routeMapStatsBar.valueFontSize = min(max(fontSize, 8), 96)
    }

    func setOverlayRouteMapStatsBarValueFontWeight(_ elementID: OverlayElement.ID, fontWeight: OverlayFontWeight) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.routeMapStatsBar.valueFontWeight = fontWeight
    }

    func setOverlayRouteMapStatsBarValueColor(_ elementID: OverlayElement.ID, color: OverlayColor) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.routeMapStatsBar.valueColor = color
    }

    func setOverlayRouteMapStatsBarLabelFontName(_ elementID: OverlayElement.ID, fontName: String) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.routeMapStatsBar.labelFontName = fontName
    }

    func setOverlayRouteMapStatsBarLabelFontSize(_ elementID: OverlayElement.ID, fontSize: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.routeMapStatsBar.labelFontSize = min(max(fontSize, 8), 96)
    }

    func setOverlayRouteMapStatsBarLabelFontWeight(_ elementID: OverlayElement.ID, fontWeight: OverlayFontWeight) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.routeMapStatsBar.labelFontWeight = fontWeight
    }

    func setOverlayRouteMapStatsBarLabelColor(_ elementID: OverlayElement.ID, color: OverlayColor) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.routeMapStatsBar.labelColor = color
    }

    func setOverlayRouteMapStatsBarBlurRadius(_ elementID: OverlayElement.ID, radius: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.routeMapStatsBar.blurRadius = min(max(radius, 0), 32)
    }

    func mutateLapListStyle(_ elementID: OverlayElement.ID, _ mutate: (inout LapListStyle) -> Void) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        mutate(&overlayLayout.elements[index].style.lapList)
    }

    func mutateLapListStyleContinuous(_ elementID: OverlayElement.ID, _ mutate: (inout LapListStyle) -> Void) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        mutate(&overlayLayout.elements[index].style.lapList)
    }

    func mutateLapCardStyle(_ elementID: OverlayElement.ID, _ mutate: (inout LapCardStyle) -> Void) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        mutate(&overlayLayout.elements[index].style.lapCard)
    }

    func mutateLapCardStyleContinuous(_ elementID: OverlayElement.ID, _ mutate: (inout LapCardStyle) -> Void) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        mutate(&overlayLayout.elements[index].style.lapCard)
    }

    func mutateLapLiveStyle(_ elementID: OverlayElement.ID, _ mutate: (inout LapLiveStyle) -> Void) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        mutate(&overlayLayout.elements[index].style.lapLive)
    }

    func mutateLapLiveStyleContinuous(_ elementID: OverlayElement.ID, _ mutate: (inout LapLiveStyle) -> Void) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        mutate(&overlayLayout.elements[index].style.lapLive)
    }

    func mutateDecorStyle(_ elementID: OverlayElement.ID, _ mutate: (inout DecorStyle) -> Void) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        mutate(&overlayLayout.elements[index].style.decor)
    }

    func mutateDecorStyleContinuous(_ elementID: OverlayElement.ID, _ mutate: (inout DecorStyle) -> Void) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        mutate(&overlayLayout.elements[index].style.decor)
    }

    func mutateWeatherWidgetStyle(_ elementID: OverlayElement.ID, _ mutate: (inout WeatherWidgetStyle) -> Void) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        mutate(&overlayLayout.elements[index].style.weatherWidget)
    }

    func mutateWeatherWidgetStyleContinuous(_ elementID: OverlayElement.ID, _ mutate: (inout WeatherWidgetStyle) -> Void) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        mutate(&overlayLayout.elements[index].style.weatherWidget)
    }

    func applyWeatherWidgetPreset(_ elementID: OverlayElement.ID, preset: WeatherWidgetPreset) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        let existing = overlayLayout.elements[index].style.weatherWidget
        var next = WeatherWidgetStyle.preset(preset)
        next.dataSource = existing.dataSource
        next.manualCondition = existing.manualCondition
        next.manualTemperatureCelsius = existing.manualTemperatureCelsius
        next.manualHumidity = existing.manualHumidity
        next.manualHigh = existing.manualHigh
        next.manualLow = existing.manualLow
        next.manualWind = existing.manualWind
        next.manualFeelsLike = existing.manualFeelsLike
        next.conditionLabelOverride = existing.conditionLabelOverride
        next.humiditySuffix = existing.humiditySuffix
        next.humidityMetricLabel = existing.humidityMetricLabel
        next.windMetricLabel = existing.windMetricLabel
        next.feelsLikeMetricLabel = existing.feelsLikeMetricLabel
        next.dividerEnabled = existing.dividerEnabled
        next.dividerColor = existing.dividerColor
        next.dividerThickness = existing.dividerThickness
        next.dividerOpacity = existing.dividerOpacity
        next.temperatureUnit = existing.temperatureUnit
        next.locationText = existing.locationText
        next.showIcon = existing.showIcon
        next.metricSlots = WeatherWidgetStyle.normalizedMetricSlots(existing.metricSlots, for: preset)
        next.cachedWeather = existing.cachedWeather
        overlayLayout.elements[index].style.weatherWidget = next
    }

    func fetchWeatherForActivityLocation(_ elementID: OverlayElement.ID) {
        fetchWeather(elementID, mode: .activityLocation)
    }

    func fetchWeatherForCurrentLocation(_ elementID: OverlayElement.ID) {
        fetchWeather(elementID, mode: .currentLocation)
    }

    private func fetchWeather(_ elementID: OverlayElement.ID, mode: WeatherFetchLocationMode) {
        guard overlayLayout.elements.contains(where: { $0.id == elementID }) else {
            return
        }

        let activity = activity
        statusMessage = "Fetching weather from \(mode.label)..."

        Task {
            do {
                let coordinate: WeatherCoordinate
                switch mode {
                case .activityLocation:
                    coordinate = try WeatherLocationResolver.activityStartCoordinate(from: activity)
                case .currentLocation:
                    coordinate = try await WeatherLocationResolver.currentCoordinate()
                }

                async let resolvedLocation = WeatherLocationResolver.displayName(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
                var payload = try await WeatherFetcher.fetch(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    date: activity.startDate,
                    resolvedLocation: nil
                )
                payload.resolvedLocation = await resolvedLocation
                payload.fetchLocationMode = mode
                applyFetchedWeatherPayload(payload, to: elementID)
            } catch {
                statusMessage = "Weather fetch failed: \(error.localizedDescription)"
            }
        }
    }

    private func applyFetchedWeatherPayload(_ payload: WeatherPayload, to elementID: OverlayElement.ID) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.weatherWidget.dataSource = .openMeteo
        overlayLayout.elements[index].style.weatherWidget.cachedWeather = payload
        if let location = payload.resolvedLocation, !location.isEmpty {
            overlayLayout.elements[index].style.weatherWidget.locationText = location
        }
        statusMessage = "Weather updated from \(payload.fetchLocationMode?.label ?? "Open-Meteo")."
    }

    func setDecorShape(_ elementID: OverlayElement.ID, shape: DecorShape) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.decor.shape = shape
        if shape == .circle {
            let side = min(overlayLayout.elements[index].style.decor.width,
                           overlayLayout.elements[index].style.decor.height)
            overlayLayout.elements[index].style.decor.width = side
            overlayLayout.elements[index].style.decor.height = side
        }
    }

    func setDecorFillColor(_ elementID: OverlayElement.ID, color: OverlayColor) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.decor.fillColor = color
    }

    func setDecorSize(_ elementID: OverlayElement.ID, width: Double? = nil, height: Double? = nil) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        if let width {
            overlayLayout.elements[index].style.decor.width = min(max(width, 4), 4096)
        }
        if let height {
            overlayLayout.elements[index].style.decor.height = min(max(height, 4), 4096)
        }
        if overlayLayout.elements[index].style.decor.shape == .circle {
            let side = min(overlayLayout.elements[index].style.decor.width,
                           overlayLayout.elements[index].style.decor.height)
            overlayLayout.elements[index].style.decor.width = side
            overlayLayout.elements[index].style.decor.height = side
        }
    }

    func setDecorCornerRadius(_ elementID: OverlayElement.ID, radius: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.decor.cornerRadius = min(max(radius, 0), 512)
    }

    func setDecorIconAsset(_ elementID: OverlayElement.ID, asset: IconAsset) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.decor.iconAsset = asset
    }

    func setDecorIconTint(_ elementID: OverlayElement.ID, color: OverlayColor) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.decor.iconTint = color
    }

    func setDecorIconPreserveSVGColors(_ elementID: OverlayElement.ID, enabled: Bool) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.decor.iconPreserveSVGColors = enabled
    }

    func setDecorIconContentMode(_ elementID: OverlayElement.ID, mode: IconContentMode) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.decor.iconContentMode = mode
    }

    // MARK: Decor Text mutators

    func setDecorTextContent(_ elementID: OverlayElement.ID, content: String) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.decor.textContent = content
    }

    func setDecorTextFont(_ elementID: OverlayElement.ID, font: DecorFontRef) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.decor.textFont = font
    }

    func setDecorTextSize(_ elementID: OverlayElement.ID, size: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.decor.textSize = min(max(size, 4), 512)
    }

    func setDecorTextAlignment(_ elementID: OverlayElement.ID, alignment: DecorTextAlignment) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.decor.textAlignment = alignment
    }

    func setDecorTextLineHeight(_ elementID: OverlayElement.ID, lineHeight: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.decor.textLineHeight = min(max(lineHeight, 0.5), 8)
    }

    func setDecorTextLetterSpacing(_ elementID: OverlayElement.ID, spacing: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.decor.textLetterSpacing = min(max(spacing, -20), 80)
    }

    func setDecorTextFillMode(_ elementID: OverlayElement.ID, fillMode: DecorTextFill) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.decor.textFillMode = fillMode
    }

    func setDecorTextStrokeWidth(_ elementID: OverlayElement.ID, width: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.decor.textStrokeWidth = min(max(width, 0), 60)
    }

    func setDecorTextStrokeColor(_ elementID: OverlayElement.ID, color: OverlayColor) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.decor.textStrokeColor = color
    }

    func setDecorTextAutoFit(_ elementID: OverlayElement.ID, enabled: Bool) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.decor.textAutoFit = enabled
    }

    func setOverlayRouteMapStartMarkerStyle(_ elementID: OverlayElement.ID, markerStyle: OverlayRouteMapMarkerStyle) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.routeMapStartMarkerStyle = markerStyle
    }

    func setOverlayRouteMapEndMarkerStyle(_ elementID: OverlayElement.ID, markerStyle: OverlayRouteMapMarkerStyle) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.routeMapEndMarkerStyle = markerStyle
    }

    func setOverlayRouteMapRunnerDotColor(_ elementID: OverlayElement.ID, color: OverlayColor) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.routeMapRunnerDotColor = color
    }

    func setOverlayRouteMapLegendMode(_ elementID: OverlayElement.ID, legendMode: OverlayRouteMapLegendMode) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.routeMapLegendMode = legendMode
    }

    func setOverlayFontName(_ elementID: OverlayElement.ID, fontName: String) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.fontName = fontName
    }

    func setOverlayFontWeight(_ elementID: OverlayElement.ID, fontWeight: OverlayFontWeight) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.fontWeight = fontWeight
    }

    func setOverlayForegroundColor(_ elementID: OverlayElement.ID, color: OverlayColor) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.foregroundColor = color
        overlayLayout.elements[index].style.valueColor = color
        overlayLayout.elements[index].style.labelColor = color
        overlayLayout.elements[index].style.unitColor = color
    }

    func setOverlayValueColor(_ elementID: OverlayElement.ID, color: OverlayColor) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.valueColor = color
    }

    func setOverlayValueOpacity(_ elementID: OverlayElement.ID, opacity: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.valueOpacity = min(max(opacity, 0), 1)
    }

    func setOverlayLabelColor(_ elementID: OverlayElement.ID, color: OverlayColor) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.labelColor = color
    }

    func setOverlayLabelOpacity(_ elementID: OverlayElement.ID, opacity: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.labelOpacity = min(max(opacity, 0), 1)
    }

    func setOverlayUnitColor(_ elementID: OverlayElement.ID, color: OverlayColor) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.unitColor = color
    }

    func setOverlayUnitOpacity(_ elementID: OverlayElement.ID, opacity: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.unitOpacity = min(max(opacity, 0), 1)
    }

    func setOverlayBackgroundOpacity(_ elementID: OverlayElement.ID, opacity: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.backgroundOpacity = min(max(opacity, 0), 1)
    }

    func setOverlayShadowOpacity(_ elementID: OverlayElement.ID, opacity: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.shadowOpacity = min(max(opacity, 0), 1)
    }

    func setOverlayUnitOption(_ elementID: OverlayElement.ID, unitOption: OverlayUnitOption) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.unitOption = unitOption
    }

    func setOverlayShowLabel(_ elementID: OverlayElement.ID, showLabel: Bool) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.showLabel = showLabel
    }

    func setOverlayShowUnit(_ elementID: OverlayElement.ID, showUnit: Bool) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.showUnit = showUnit
    }

    func setOverlayCustomLabel(_ elementID: OverlayElement.ID, label: String) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.customLabel = label
    }

    func setOverlayLabelPosition(_ elementID: OverlayElement.ID, position: OverlayTextAttachmentPosition) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.labelPosition = position
    }

    func setOverlayUnitPosition(_ elementID: OverlayElement.ID, position: OverlayTextAttachmentPosition) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.unitPosition = position
    }

    func setOverlayLabelFontName(_ elementID: OverlayElement.ID, fontName: String) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.labelFontName = fontName
    }

    func setOverlayLabelFontSize(_ elementID: OverlayElement.ID, fontSize: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.labelFontSize = min(max(fontSize, 8), 72)
    }

    func setOverlayLabelFontWeight(_ elementID: OverlayElement.ID, fontWeight: OverlayFontWeight) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.labelFontWeight = fontWeight
    }

    func setOverlayLabelSpacing(_ elementID: OverlayElement.ID, spacing: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.labelSpacing = min(max(spacing, 0), 60)
    }

    func setOverlayUnitFontName(_ elementID: OverlayElement.ID, fontName: String) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.unitFontName = fontName
    }

    func setOverlayUnitFontSize(_ elementID: OverlayElement.ID, fontSize: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.unitFontSize = min(max(fontSize, 8), 72)
    }

    func setOverlayUnitFontWeight(_ elementID: OverlayElement.ID, fontWeight: OverlayFontWeight) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.unitFontWeight = fontWeight
    }

    func setOverlayUnitSpacing(_ elementID: OverlayElement.ID, spacing: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.unitSpacing = min(max(spacing, 0), 60)
    }

    func setOverlayPosition(_ elementID: OverlayElement.ID, position: CGPoint) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        guard !overlayLayout.elements[index].isLocked else {
            return
        }
        overlayLayout.elements[index].position = CGPoint(
            x: min(max(position.x, 0), 1),
            y: min(max(position.y, 0), 1)
        )
    }

    func setOverlayVisibility(_ elementID: OverlayElement.ID, isVisible: Bool) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].isVisible = isVisible
        statusMessage = isVisible ? "Overlay is now visible." : "Overlay is now hidden."
    }

    func setOverlayLocked(_ elementID: OverlayElement.ID, isLocked: Bool) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].isLocked = isLocked
        statusMessage = isLocked ? "Overlay locked." : "Overlay unlocked."
    }

    func setOverlayRotation(_ elementID: OverlayElement.ID, degrees: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.rotationDegrees = degrees
    }

    func setOverlayTextAlignment(_ elementID: OverlayElement.ID, alignment: OverlayTextAlignment) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.textAlignment = alignment
    }

    func setOverlayAccentColor(_ elementID: OverlayElement.ID, color: OverlayColor) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.accentColor = color
    }

    func setOverlayLabelTextAlignment(_ elementID: OverlayElement.ID, alignment: OverlayTextAlignment) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.labelTextAlignment = alignment
    }

    func setOverlayDividerEnabled(_ elementID: OverlayElement.ID, enabled: Bool) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.dividerEnabled = enabled
    }

    func setOverlayDividerColor(_ elementID: OverlayElement.ID, color: OverlayColor) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.dividerColor = color
    }

    func setOverlayDividerThickness(_ elementID: OverlayElement.ID, thickness: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.dividerThickness = min(max(thickness, 0), 16)
    }

    func setOverlayDividerOpacity(_ elementID: OverlayElement.ID, opacity: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.dividerOpacity = min(max(opacity, 0), 1)
    }

    func setOverlayBackgroundEnabled(_ elementID: OverlayElement.ID, enabled: Bool) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.backgroundEnabled = enabled
    }

    func setOverlayBackgroundColor(_ elementID: OverlayElement.ID, color: OverlayColor) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.backgroundColor = color
    }

    func setOverlayBackgroundRadius(_ elementID: OverlayElement.ID, radius: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.backgroundRadius = max(0, min(radius, 64))
    }

    func setOverlayBackgroundPadding(_ elementID: OverlayElement.ID, x: Double? = nil, y: Double? = nil) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        if let x {
            overlayLayout.elements[index].style.backgroundPaddingX = max(0, min(x, 80))
        }
        if let y {
            overlayLayout.elements[index].style.backgroundPaddingY = max(0, min(y, 80))
        }
    }

    func setOverlayBackgroundFadeOutEnabled(_ elementID: OverlayElement.ID, enabled: Bool) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.backgroundFadeOutEnabled = enabled
    }

    func setOverlayBackgroundFadeOutAmount(_ elementID: OverlayElement.ID, amount: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.backgroundFadeOutAmount = min(max(amount, 0), 1)
    }

    func setOverlayBackgroundBlurRadius(_ elementID: OverlayElement.ID, radius: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else { return }
        overlayLayout.elements[index].style.backgroundBlurRadius = min(max(radius, 0), 40)
    }

    func setOverlayBorderEnabled(_ elementID: OverlayElement.ID, enabled: Bool) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.borderEnabled = enabled
    }

    func setOverlayBorderColor(_ elementID: OverlayElement.ID, color: OverlayColor) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.borderColor = color
    }

    func setOverlayBorderOpacity(_ elementID: OverlayElement.ID, opacity: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.borderOpacity = min(max(opacity, 0), 1)
    }

    func setOverlayBorderWidth(_ elementID: OverlayElement.ID, width: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.borderWidth = min(max(width, 0.5), 12)
    }

    func setOverlayShadowEnabled(_ elementID: OverlayElement.ID, enabled: Bool) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.shadowEnabled = enabled
    }

    func setOverlayShadowColor(_ elementID: OverlayElement.ID, color: OverlayColor) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.shadowColor = color
    }

    func setOverlayShadowOffset(_ elementID: OverlayElement.ID, x: Double? = nil, y: Double? = nil) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        if let x {
            overlayLayout.elements[index].style.shadowOffsetX = max(-32, min(x, 32))
        }
        if let y {
            overlayLayout.elements[index].style.shadowOffsetY = max(-32, min(y, 32))
        }
    }

    func setOverlayShadowThickness(_ elementID: OverlayElement.ID, thickness: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.shadowThickness = min(max(thickness, 1), 4)
    }

    func setOverlayGlowEnabled(_ elementID: OverlayElement.ID, enabled: Bool) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.glowEnabled = enabled
    }

    func setOverlayGlowColor(_ elementID: OverlayElement.ID, color: OverlayColor) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.glowColor = color
    }

    func setOverlayGlowIntensity(_ elementID: OverlayElement.ID, intensity: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.glowIntensity = min(max(intensity, 0), 1)
    }

    func resetOverlayStyle(_ elementID: OverlayElement.ID) {
        registerUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        let type = overlayLayout.elements[index].type
        var style = OverlayStyle.default
        style.unitOption = type.defaultUnitOption
        if type == .routeMap {
            style.routeMapPreset = .gradient
            style.routeMapProvider = .mapKit
            style.routeMapBackgroundStyle = .dark
            style.backgroundOpacity = 0.74
            style.foregroundColor = .cyan
        }
        overlayLayout.elements[index].style = style
        overlayLayout.elements[index].scale = 1.0
        statusMessage = "Reset overlay style."
    }

    func setOverlayShadowRadius(_ elementID: OverlayElement.ID, radius: Double) {
        registerContinuousUndoPoint()
        guard let index = overlayLayout.elements.firstIndex(where: { $0.id == elementID }) else {
            return
        }
        overlayLayout.elements[index].style.shadowRadius = min(max(radius, 0), 24)
    }

    func deleteOverlay(_ elementID: OverlayElement.ID) {
        guard overlayLayout.elements.contains(where: { $0.id == elementID }) else {
            return
        }
        registerUndoPoint()
        overlayLayout.elements.removeAll { $0.id == elementID }
        if selection == .overlayElement(elementID) {
            selection = .none
        }
        statusMessage = "Deleted overlay element."
    }

    func deleteSelectedItem() {
        switch selection {
        case .timelineClip(let clipID):
            guard timeline.clip(with: clipID) != nil else {
                return
            }
            registerUndoPoint()
            var updatedTimeline = timeline
            updatedTimeline.deleteClip(clipID)
            timeline = updatedTimeline
            selection = .none
            statusMessage = "Deleted timeline clip."
        case .overlayElement(let elementID):
            deleteOverlay(elementID)
        case .none:
            break
        }
    }

    func saveOverlayTemplate(named name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            statusMessage = "Template name is required."
            return
        }
        guard !overlayLayout.elements.isEmpty else {
            statusMessage = "Add overlay elements before saving a template."
            return
        }

        let now = Date()
        if let index = overlayTemplates.firstIndex(where: { $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame }) {
            let existingTemplate = overlayTemplates[index]
            overlayTemplates[index] = OverlayTemplate(
                id: existingTemplate.id,
                name: trimmedName,
                createdAt: existingTemplate.createdAt,
                updatedAt: now,
                referenceResolution: overlayTemplateReferenceResolution,
                elements: overlayLayout.elements.map(OverlayTemplateElement.init(element:))
            )
            statusMessage = "Updated overlay template: \(trimmedName)."
        } else {
            overlayTemplates.insert(
                OverlayTemplate(
                    name: trimmedName,
                    layout: overlayLayout,
                    referenceResolution: overlayTemplateReferenceResolution,
                    now: now
                ),
                at: 0
            )
            statusMessage = "Saved overlay template: \(trimmedName)."
        }
        persistOverlayTemplates()
    }

    func saveCurrentOverlayTemplateWithGeneratedName() {
        guard !overlayLayout.elements.isEmpty else {
            statusMessage = "Add overlay elements before saving a template."
            return
        }
        saveOverlayTemplate(named: nextOverlayTemplateName(base: "Template"))
    }

    func applyOverlayTemplate(_ templateID: OverlayTemplate.ID) {
        guard let template = overlayTemplates.first(where: { $0.id == templateID }) else {
            statusMessage = "Overlay template not found."
            return
        }
        registerUndoPoint()
        overlayLayout = template.layout
        selection = .none
        statusMessage = "Applied overlay template: \(template.name)."
    }

    func applyBuiltInOverlayTemplate(_ template: BuiltInOverlayTemplate) {
        if let resourceTemplate = loadBuiltInOverlayTemplateResource(template) {
            applyOverlayTemplateLayout(resourceTemplate.layout, name: template.name)
            return
        }

        guard !template.elements.isEmpty else {
            statusMessage = "Built-in template not found: \(template.name)."
            return
        }

        registerUndoPoint()
        overlayLayout = OverlayLayout(
            elements: template.elements.map { entry in
                makeOverlayElement(
                    type: entry.type,
                    position: CGPoint(x: entry.positionX, y: entry.positionY),
                    scale: entry.scale
                )
            }
        )
        selection = .none
        statusMessage = "Applied overlay template: \(template.name)."
    }

    private func applyOverlayTemplateLayout(_ layout: OverlayLayout, name: String) {
        registerUndoPoint()
        overlayLayout = layout
        selection = .none
        statusMessage = "Applied overlay template: \(name)."
    }

    private func loadBuiltInOverlayTemplateResource(_ template: BuiltInOverlayTemplate) -> OverlayTemplate? {
        guard let resourceName = template.resourceName else {
            return nil
        }

        let url = Bundle.module.url(
                forResource: resourceName,
                withExtension: OverlayTemplateStore.fileExtension,
                subdirectory: "Templates"
              )
            ?? Bundle.module.url(
                forResource: resourceName,
                withExtension: OverlayTemplateStore.fileExtension
            )

        guard let url else {
            return nil
        }

        do {
            return try overlayTemplateStore.loadTemplateFile(from: url)
        } catch {
            statusMessage = "Built-in template load failed: \(template.name)."
            print("[RunningOverlay] Built-in template load failed: \(template.name), \(String(reflecting: error))")
            return nil
        }
    }

    func renameOverlayTemplate(_ templateID: OverlayTemplate.ID, to name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            statusMessage = "Template name is required."
            return
        }
        guard let index = overlayTemplates.firstIndex(where: { $0.id == templateID }) else {
            statusMessage = "Overlay template not found."
            return
        }
        guard !overlayTemplates.contains(where: { $0.id != templateID && $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame }) else {
            statusMessage = "A template named \(trimmedName) already exists."
            return
        }

        overlayTemplates[index].name = trimmedName
        overlayTemplates[index].updatedAt = Date()
        persistOverlayTemplates()
        statusMessage = "Renamed overlay template: \(trimmedName)."
    }

    func duplicateOverlayTemplate(_ templateID: OverlayTemplate.ID) {
        guard let template = overlayTemplates.first(where: { $0.id == templateID }) else {
            statusMessage = "Overlay template not found."
            return
        }
        let now = Date()
        let copyName = nextOverlayTemplateName(base: "\(template.name) Copy")
        overlayTemplates.insert(
            OverlayTemplate(
                id: UUID(),
                name: copyName,
                createdAt: now,
                updatedAt: now,
                referenceResolution: template.referenceResolution,
                elements: template.elements
            ),
            at: 0
        )
        persistOverlayTemplates()
        statusMessage = "Duplicated overlay template: \(copyName)."
    }

    func deleteOverlayTemplate(_ templateID: OverlayTemplate.ID) {
        guard let template = overlayTemplates.first(where: { $0.id == templateID }) else {
            return
        }
        overlayTemplates.removeAll { $0.id == templateID }
        persistOverlayTemplates()
        statusMessage = "Deleted overlay template: \(template.name)."
    }

    func importOverlayTemplateFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: OverlayTemplateStore.fileExtension)].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            var template = try overlayTemplateStore.loadTemplateFile(from: url)
            if overlayTemplates.contains(where: { $0.name.localizedCaseInsensitiveCompare(template.name) == .orderedSame }) {
                template.name = nextOverlayTemplateName(base: "\(template.name) Copy")
            }
            overlayTemplates.insert(template, at: 0)
            persistOverlayTemplates()
            statusMessage = "Imported overlay template: \(template.name)."
        } catch {
            statusMessage = "Overlay template import failed: \(error.localizedDescription)"
            print("[RunningOverlay] Overlay template import failed: \(String(reflecting: error))")
        }
    }

    func exportOverlayTemplateFile(_ templateID: OverlayTemplate.ID) {
        guard let template = overlayTemplates.first(where: { $0.id == templateID }) else {
            statusMessage = "Overlay template not found."
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: OverlayTemplateStore.fileExtension)].compactMap { $0 }
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(template.name).\(OverlayTemplateStore.fileExtension)"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try overlayTemplateStore.exportTemplate(template, to: url)
            statusMessage = "Exported overlay template: \(template.name)."
        } catch {
            statusMessage = "Overlay template export failed: \(error.localizedDescription)"
            print("[RunningOverlay] Overlay template export failed: \(String(reflecting: error))")
        }
    }

    private func nextOverlayTemplateName(base: String) -> String {
        let existingNames = Set(overlayTemplates.map { $0.name.lowercased() })
        let trimmedBase = base.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Template" : base.trimmingCharacters(in: .whitespacesAndNewlines)
        if !existingNames.contains(trimmedBase.lowercased()) {
            return trimmedBase
        }

        var index = 1
        while true {
            let candidate = "\(trimmedBase) \(index)"
            if !existingNames.contains(candidate.lowercased()) {
                return candidate
            }
            index += 1
        }
    }

    func exportOverlays(to destinationURL: URL) {
        guard !isExporting else {
            return
        }

        let segments = timeline.tracks.flatMap(\.clips).compactMap { clip -> OverlayExportSegment? in
            guard let mediaItemID = clip.mediaItemID,
                  let mediaItem = mediaItems.first(where: { $0.id == mediaItemID }) else {
                return nil
            }
            return OverlayExportSegment(
                startTime: clip.effectiveStartTime,
                duration: clip.duration,
                sourceFileName: mediaItem.displayName
            )
        }
        let job = OverlayExportJob(
            destinationURL: destinationURL,
            settings: settings,
            activity: activity,
            overlayLayout: overlayLayout,
            fitStartTime: timeline.fitStartTime,
            segments: segments
        )

        runSwiftUIExport(
            job: job,
            title: "Clip Overlay Export",
            completedMessage: "Overlay export completed.",
            failurePrefix: "Overlay export failed"
        )
    }

    func cancelExport() {
        guard isExporting else {
            return
        }
        exportTask?.cancel()
        exportProgress = nil
        statusMessage = "Cancelling export..."
    }

    func exportFullActivityOverlay(to destinationURL: URL) {
        guard !isExporting else {
            return
        }
        guard activity.duration > 0 else {
            statusMessage = "Import a FIT file before exporting full activity overlay."
            return
        }

        let job = OverlayExportJob(
            destinationURL: destinationURL,
            settings: settings,
            activity: activity,
            overlayLayout: overlayLayout,
            fitStartTime: timeline.fitStartTime,
            segments: [
                OverlayExportSegment(
                    startTime: timeline.fitStartTime,
                    duration: activity.duration,
                    sourceFileName: "full_activity.mov"
                )
            ]
        )

        runSwiftUIExport(
            job: job,
            title: "Full Activity Export",
            completedMessage: "Full activity overlay export completed.",
            failurePrefix: "Full activity overlay export failed"
        )
    }

    func exportTestClip(to destinationURL: URL) {
        guard !isExporting else {
            return
        }

        let exportActivity = activity.duration > 0 ? activity : Self.calibrationActivity()
        let playheadActivityTime = timeline.activityElapsed(atProjectTime: timeline.playhead)
        let segmentStart = exportActivity.duration > 3
            ? min(max(playheadActivityTime, 0), exportActivity.duration - 3)
            : 0
        let job = OverlayExportJob(
            destinationURL: destinationURL,
            settings: settings,
            activity: exportActivity,
            overlayLayout: overlayLayout,
            fitStartTime: 0,
            segments: [
                OverlayExportSegment(
                    startTime: segmentStart,
                    duration: 3,
                    sourceFileName: "overlay_test_clip.mov"
                )
            ]
        )

        runSwiftUIExport(
            job: job,
            title: "Test Clip Export",
            completedMessage: "Test clip export completed.",
            failurePrefix: "Test clip export failed"
        )
    }

    func exportSwiftUITestClip(to destinationURL: URL) {
        exportTestClip(to: destinationURL)
    }

    func exportSwiftUITestFrame(to destinationURL: URL) {
        exportTestFrame(to: destinationURL)
    }

    func exportCurrentOverlayConfigurationJSON(to destinationURL: URL) {
        let outputURL = destinationURL.appendingPathComponent("overlay_configuration.json")
        do {
            try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
            let snapshot = OverlayTemplate(
                name: "Current Overlay Configuration",
                layout: overlayLayout,
                referenceResolution: overlayTemplateReferenceResolution
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            try data.write(to: outputURL)
            statusMessage = "Overlay configuration exported: \(outputURL.lastPathComponent)."
        } catch {
            statusMessage = "Overlay configuration export failed: \(error.localizedDescription)"
            print("[RunningOverlay] Overlay configuration export failed: \(String(reflecting: error))")
        }
    }

    func saveProjectSnapshot() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "running_overlay_project_snapshot.json"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        saveProjectSnapshot(to: url)
    }

    func restoreProjectSnapshot() {
        guard !isExporting else {
            statusMessage = "Cancel the active export before restoring a project snapshot."
            return
        }

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        restoreProjectSnapshot(from: url)
    }

    func saveProjectSnapshot(to outputURL: URL) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(makePersistentSnapshot())
            try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: outputURL)
            statusMessage = "Project snapshot saved: \(outputURL.lastPathComponent)."
        } catch {
            statusMessage = "Project snapshot save failed: \(error.localizedDescription)"
            print("[RunningOverlay] Project snapshot save failed: \(String(reflecting: error))")
        }
    }

    func restoreProjectSnapshot(from inputURL: URL) {
        guard !isExporting else {
            statusMessage = "Cancel the active export before restoring a project snapshot."
            return
        }

        do {
            let data = try Data(contentsOf: inputURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshot = try decoder.decode(ProjectPerformanceSnapshot.self, from: data)
            restorePersistentSnapshot(snapshot)
            statusMessage = "Project snapshot restored: \(inputURL.lastPathComponent)."
        } catch {
            statusMessage = "Project snapshot restore failed: \(error.localizedDescription)"
            print("[RunningOverlay] Project snapshot restore failed: \(String(reflecting: error))")
        }
    }

    func exportTestFrame(to destinationURL: URL) {
        let exportActivity = activity.duration > 0 ? activity : Self.calibrationActivity()
        let playheadActivityTime = timeline.activityElapsed(atProjectTime: timeline.playhead)
        let sampleTime = exportActivity.duration > 0
            ? min(max(playheadActivityTime, 0), exportActivity.duration)
            : 0
        let outputURL = destinationURL.appendingPathComponent("overlay_test_frame.png")

        Task {
            do {
                try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
                try? FileManager.default.removeItem(at: outputURL)
                try await SwiftUIOverlayVideoExporter.exportFramePNG(
                    overlayLayout: overlayLayout,
                    activity: exportActivity,
                    elapsedTime: quantizedLayerDataTime(for: sampleTime),
                    size: CGSize(width: settings.resolution.width, height: settings.resolution.height),
                    outputURL: outputURL
                )
                statusMessage = "Test frame exported: \(outputURL.lastPathComponent)."
            } catch {
                statusMessage = "Test frame export failed: \(error.localizedDescription)"
                print("[RunningOverlay] Test frame export failed: \(String(reflecting: error))")
            }
        }
    }

    func undo() {
        guard let snapshot = undoStack.popLast() else {
            updateUndoRedoFlags()
            return
        }
        redoStack.append(makeSnapshot())
        restore(snapshot)
        activeUndoSnapshot = nil
        statusMessage = "Undo."
        updateUndoRedoFlags()
    }

    func redo() {
        guard let snapshot = redoStack.popLast() else {
            updateUndoRedoFlags()
            return
        }
        undoStack.append(makeSnapshot())
        restore(snapshot)
        activeUndoSnapshot = nil
        statusMessage = "Redo."
        updateUndoRedoFlags()
    }

    func clearSelection() {
        selection = .none
    }

    private func loadOverlayTemplates() {
        do {
            overlayTemplates = try overlayTemplateStore.load()
        } catch {
            overlayTemplates = []
            statusMessage = "Overlay template load failed: \(error.localizedDescription)"
            print("[RunningOverlay] Overlay template load failed: \(String(reflecting: error))")
        }
    }

    private func persistOverlayTemplates() {
        do {
            try overlayTemplateStore.save(overlayTemplates)
        } catch {
            statusMessage = "Overlay template save failed: \(error.localizedDescription)"
            print("[RunningOverlay] Overlay template save failed: \(String(reflecting: error))")
        }
    }

    private var overlayTemplateReferenceResolution: OverlayTemplateResolution {
        OverlayTemplateResolution(width: settings.resolution.width, height: settings.resolution.height)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatDistance(_ meters: Double) -> String {
        String(format: "%.2f km", meters / 1000)
    }

    private func formatSignedDuration(_ duration: TimeInterval) -> String {
        let sign = duration < 0 ? "-" : ""
        return sign + formatDuration(abs(duration))
    }

    private func currentLayerName() -> String {
        if case .timelineClip(let clipID) = selection,
           let clip = timeline.clip(with: clipID) {
            return clip.cameraGroupID
        }
        if let previewTrackName = settings.previewTrackName,
           timeline.tracks.contains(where: { $0.name == previewTrackName }) {
            return previewTrackName
        }
        return timeline.tracks.first?.name ?? "Layer 1"
    }

    private func matchMediaItems(_ mediaItemIDs: Set<MediaItem.ID>, toTrackName trackName: String) {
        let targetIDs = mediaItemIDs.filter { id in
            mediaItems.contains { $0.id == id }
        }
        guard !targetIDs.isEmpty else {
            statusMessage = "No media items selected."
            return
        }

        registerUndoPoint()
        var updatedTimeline = timeline
        var lastClipID: TimelineClip.ID?
        var matchedCount = 0
        var skippedIDs: [MediaItem.ID] = []
        var skippedNames: [String] = []

        for mediaIndex in mediaItems.indices where targetIDs.contains(mediaItems[mediaIndex].id) {
            let mediaItem = mediaItems[mediaIndex]
            let startTime: TimeInterval
            let source: String
            if let inferredStartDate = mediaItem.inferredStartDate {
                startTime = timeline.fitStartTime + inferredStartDate.timeIntervalSince(activity.startDate)
                source = "timestamp"
            } else {
                startTime = timeline.playhead
                source = "manual"
            }

            if updatedTimeline.wouldClipOverlap(
                mediaItemID: mediaItem.id,
                trackName: trackName,
                startTime: startTime,
                duration: mediaItem.duration
            ) {
                skippedIDs.append(mediaItem.id)
                skippedNames.append(mediaItem.displayName)
                continue
            }

            if let clipID = updatedTimeline.addOrMoveClip(
                mediaItem: mediaItem,
                trackName: trackName,
                startTime: startTime,
                activity: activity
            ) {
                mediaItems[mediaIndex].alignmentStatus = .aligned(source: source)
                mediaItems[mediaIndex].cameraGroupID = trackName
                lastClipID = clipID
                matchedCount += 1
            }
        }

        timeline = updatedTimeline
        if let lastClipID {
            selection = .timelineClip(lastClipID)
        }
        let summary: String
        if matchedCount == 0 {
            summary = "No items matched to \(trackName): \(skippedNames.count) overlap existing clip(s). Try \"Match to New Layer\"."
        } else if skippedNames.isEmpty {
            summary = "Matched \(matchedCount) media item(s) to \(trackName)."
        } else {
            summary = "Matched \(matchedCount) media item(s) to \(trackName); skipped \(skippedNames.count) due to overlap. Try \"Match to New Layer\" for those."
        }
        statusMessage = summary

        if !skippedIDs.isEmpty {
            let skippedSet = Set(skippedIDs)
            let names = skippedNames
            let matched = matchedCount
            let layerName = trackName
            DispatchQueue.main.async { [weak self] in
                self?.presentOverlapSkippedAlert(
                    matchedCount: matched,
                    skippedNames: names,
                    trackName: layerName,
                    skippedIDs: skippedSet
                )
            }
        }
    }

    private func presentOverlapSkippedAlert(
        matchedCount: Int,
        skippedNames: [String],
        trackName: String,
        skippedIDs: Set<MediaItem.ID>
    ) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        if matchedCount == 0 {
            alert.messageText = "No items placed on \(trackName)"
        } else {
            alert.messageText = "\(skippedNames.count) item(s) skipped on \(trackName)"
        }

        let preview = skippedNames.prefix(5).map { "• \($0)" }.joined(separator: "\n")
        let suffix = skippedNames.count > 5 ? "\n…and \(skippedNames.count - 5) more" : ""
        let intro = matchedCount == 0
            ? "These media items overlap clips already on \(trackName) and were not placed:"
            : "Matched \(matchedCount) item(s); these overlap clips already on \(trackName) and were not placed:"
        alert.informativeText = "\(intro)\n\n\(preview)\(suffix)\n\nPlace the skipped item(s) on a brand-new layer?"

        alert.addButton(withTitle: "Match to New Layer")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            matchMediaItemsToNewLayer(skippedIDs)
        }
    }

    private static func isSupportedVideoURL(_ url: URL) -> Bool {
        let supportedExtensions: Set<String> = ["mov", "mp4", "m4v", "avi"]
        return supportedExtensions.contains(url.pathExtension.lowercased())
    }

    static func calibrationOverlayLayout() -> OverlayLayout {
        OverlayLayout(elements: [
            OverlayElement(type: .distanceTimeline, position: CGPoint(x: 0.5, y: 0.14), scale: 1.15, isVisible: true, isLocked: false, style: .default),
            OverlayElement(type: .elevationChart, position: CGPoint(x: 0.5, y: 0.30), scale: 1.0, isVisible: true, isLocked: false, style: .default),
            OverlayElement(type: .heartRate, position: CGPoint(x: 0.12, y: 0.86), scale: 1.25, isVisible: true, isLocked: false, style: .default),
            OverlayElement(type: .distance, position: CGPoint(x: 0.50, y: 0.68), scale: 1.35, isVisible: true, isLocked: false, style: .default),
            OverlayElement(type: .pace, position: CGPoint(x: 0.86, y: 0.86), scale: 1.25, isVisible: true, isLocked: false, style: .default),
            OverlayElement(type: .elapsedTime, position: CGPoint(x: 0.86, y: 0.14), scale: 1.0, isVisible: true, isLocked: false, style: .default)
        ])
    }

    static func calibrationActivity() -> ActivityTimeline {
        let startDate = Date(timeIntervalSince1970: 1_776_000_000)
        return ActivityTimeline(
            startDate: startDate,
            duration: 3,
            distanceMeters: 750,
            records: [
                ActivityRecord(
                    elapsedTime: 0,
                    timestamp: startDate,
                    distanceMeters: 0,
                    heartRate: 148,
                    paceSecondsPerKilometer: 270,
                    elevationMeters: 100,
                    cadence: 178,
                    powerWatts: 260,
                    calories: 0
                ),
                ActivityRecord(
                    elapsedTime: 1.5,
                    timestamp: startDate.addingTimeInterval(1.5),
                    distanceMeters: 375,
                    heartRate: 160,
                    paceSecondsPerKilometer: 252,
                    elevationMeters: 112,
                    cadence: 184,
                    powerWatts: 285,
                    calories: 8
                ),
                ActivityRecord(
                    elapsedTime: 3,
                    timestamp: startDate.addingTimeInterval(3),
                    distanceMeters: 750,
                    heartRate: 172,
                    paceSecondsPerKilometer: 245,
                    elevationMeters: 106,
                    cadence: 188,
                    powerWatts: 302,
                    calories: 16
                )
            ],
            laps: []
        )
    }

    private func runSwiftUIExport(job: OverlayExportJob, title: String, completedMessage: String, failurePrefix: String) {
        guard !isExporting else {
            return
        }

        isExporting = true
        exportProgress = ExportProgressState(
            title: title,
            items: job.segments.enumerated().map { index, segment in
                ExportProgressItem(index: index, name: segment.sourceFileName, progress: 0, status: .queued)
            }
        )
        statusMessage = title

        exportTask = Task {
            do {
                try await SwiftUIOverlayVideoExporter.export(job: job) { [weak self] progress in
                    self?.updateExportProgress(progress)
                }
                exportProgress?.markCompleted()
                statusMessage = completedMessage
            } catch OverlayExportError.cancelled {
                exportProgress?.markCancelled()
                statusMessage = "Export cancelled."
            } catch is CancellationError {
                exportProgress?.markCancelled()
                statusMessage = "Export cancelled."
            } catch {
                exportProgress?.markFailed(message: error.localizedDescription)
                statusMessage = "\(failurePrefix): \(error.localizedDescription)"
                print("[RunningOverlay] \(failurePrefix): \(String(reflecting: error))")
            }
            isExporting = false
            exportTask = nil
        }
    }

    private func updateExportProgress(_ progress: OverlayExportProgress) {
        guard var currentProgress = exportProgress else {
            return
        }
        currentProgress.update(progress)
        exportProgress = currentProgress
        statusMessage = progress.message
    }

    private static let zoomSliderFitThreshold = 2.0
    private static let zoomSliderMaximum = 100.0
    private static let minimumTimelinePixelsPerSecond = 0.25
    private static let maximumTimelinePixelsPerSecond = 200.0

    private static func pixelsPerSecond(forSliderValue sliderValue: Double) -> Double {
        let normalized = min(
            max((sliderValue - zoomSliderFitThreshold) / (zoomSliderMaximum - zoomSliderFitThreshold), 0),
            1
        )
        return minimumTimelinePixelsPerSecond
            + pow(normalized, 2) * (maximumTimelinePixelsPerSecond - minimumTimelinePixelsPerSecond)
    }

    private static func sliderValue(forPixelsPerSecond pixelsPerSecond: Double) -> Double {
        let normalized = min(
            max((pixelsPerSecond - minimumTimelinePixelsPerSecond) / (maximumTimelinePixelsPerSecond - minimumTimelinePixelsPerSecond), 0),
            1
        )
        return zoomSliderFitThreshold + sqrt(normalized) * (zoomSliderMaximum - zoomSliderFitThreshold)
    }

    private func registerUndoPoint() {
        undoStack.append(makeSnapshot())
        redoStack.removeAll()
        activeUndoSnapshot = nil
        updateUndoRedoFlags()
    }

    private func registerContinuousUndoPoint() {
        if let activeUndoSnapshot {
            if undoStack.last != activeUndoSnapshot {
                undoStack.append(activeUndoSnapshot)
                redoStack.removeAll()
                updateUndoRedoFlags()
            }
            return
        }
        let snapshot = makeSnapshot()
        activeUndoSnapshot = snapshot
        undoStack.append(snapshot)
        redoStack.removeAll()
        updateUndoRedoFlags()
    }

    private func makeSnapshot() -> ProjectSnapshot {
        ProjectSnapshot(
            settings: settings,
            activity: activity,
            mediaItems: mediaItems,
            mediaFolders: mediaFolders,
            timeline: timeline,
            overlayLayout: overlayLayout,
            userAssets: userAssets,
            selection: selection
        )
    }

    private func restore(_ snapshot: ProjectSnapshot) {
        settings = snapshot.settings
        activity = snapshot.activity
        mediaItems = snapshot.mediaItems
        mediaFolders = snapshot.mediaFolders
        timeline = snapshot.timeline
        overlayLayout = snapshot.overlayLayout
        userAssets = snapshot.userAssets
        selection = snapshot.selection
    }

    private func makePersistentSnapshot() -> ProjectPerformanceSnapshot {
        ProjectPerformanceSnapshot(
            settings: settings,
            activity: activity,
            mediaItems: mediaItems,
            mediaFolders: mediaFolders,
            timeline: timeline,
            overlayElements: overlayLayout.elements.map(OverlayTemplateElement.init(element:)),
            userAssets: userAssets,
            fitSourceName: fitSourceName
        )
    }

    private func restorePersistentSnapshot(_ snapshot: ProjectPerformanceSnapshot) {
        settings = snapshot.settings
        activity = snapshot.activity
        mediaItems = snapshot.mediaItems
        mediaFolders = snapshot.mediaFolders
        timeline = snapshot.timeline
        overlayLayout = OverlayLayout(elements: snapshot.overlayElements.map(\.overlayElement))
        userAssets = snapshot.userAssets
        fitSourceName = snapshot.fitSourceName

        selection = .none
        isPlaying = false
        playbackRate = 1
        mediaPoolPreviewItemID = nil
        mediaPoolPreviewSourceTime = 0
        exportProgress = nil
        exportTask = nil
        isExporting = false
        activeUndoSnapshot = nil
        undoStack.removeAll()
        redoStack.removeAll()
        updateUndoRedoFlags()
    }

    private func updateUndoRedoFlags() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}

private struct ProjectSnapshot: Equatable {
    var settings: ProjectSettings
    var activity: ActivityTimeline
    var mediaItems: [MediaItem]
    var mediaFolders: [MediaFolder]
    var timeline: TimelineModel
    var overlayLayout: OverlayLayout
    var userAssets: [UserAsset]
    var selection: EditorSelection
}

struct ProjectPerformanceSnapshot: Codable, Equatable {
    var schemaVersion: Int = 1
    var settings: ProjectSettings
    var activity: ActivityTimeline
    var mediaItems: [MediaItem]
    var mediaFolders: [MediaFolder]
    var timeline: TimelineModel
    var overlayElements: [OverlayTemplateElement]
    var userAssets: [UserAsset]
    var fitSourceName: String
}

private struct CopiedOverlayConfiguration {
    var category: OverlayPasteCategory
    var scale: Double
    var opacity: Double
    var isVisible: Bool
    var isLocked: Bool
    var style: OverlayStyle

    init(element: OverlayElement) {
        category = element.type.pasteCategory
        scale = element.scale
        opacity = element.opacity
        isVisible = element.isVisible
        isLocked = element.isLocked
        style = element.style
    }
}

enum EditorSelection: Equatable {
    case none
    case timelineClip(TimelineClip.ID)
    case overlayElement(OverlayElement.ID)
}

struct PreviewMedia: Equatable {
    var url: URL
    var sourceTime: TimeInterval
    var clipStartTime: TimeInterval
    var clipID: TimelineClip.ID
    var syncsToSourceTime = true

    init(
        url: URL,
        sourceTime: TimeInterval,
        clipStartTime: TimeInterval,
        clipID: TimelineClip.ID,
        syncsToSourceTime: Bool = true
    ) {
        self.url = url
        self.sourceTime = sourceTime
        self.clipStartTime = clipStartTime
        self.clipID = clipID
        self.syncsToSourceTime = syncsToSourceTime
    }
}

struct ExportProgressState: Equatable {
    var title: String
    var items: [ExportProgressItem]
    var failureMessage: String?

    var overallProgress: Double {
        guard !items.isEmpty else {
            return 0
        }
        return items.map(\.progress).reduce(0, +) / Double(items.count)
    }

    var completedCount: Int {
        items.filter { $0.status == .completed }.count
    }

    mutating func update(_ progress: OverlayExportProgress) {
        for index in items.indices {
            if items[index].index < progress.segmentIndex, items[index].status != .completed {
                items[index].progress = 1
                items[index].status = .completed
            } else if items[index].index == progress.segmentIndex {
                items[index].progress = min(max(progress.segmentProgress, 0), 1)
                items[index].status = items[index].progress >= 1 ? .completed : .exporting
            }
        }
    }

    mutating func markCompleted() {
        for index in items.indices {
            items[index].progress = 1
            items[index].status = .completed
        }
    }

    mutating func markFailed(message: String) {
        failureMessage = message
        if let exportingIndex = items.firstIndex(where: { $0.status == .exporting || $0.status == .queued }) {
            items[exportingIndex].status = .failed
        }
    }

    mutating func markCancelled() {
        failureMessage = "Cancelled"
        for index in items.indices where items[index].status == .exporting || items[index].status == .queued {
            items[index].status = .cancelled
        }
    }
}

struct ExportProgressItem: Identifiable, Equatable {
    var index: Int
    var name: String
    var progress: Double
    var status: ExportProgressItemStatus

    var id: Int { index }
}

enum ExportProgressItemStatus: String, Equatable {
    case queued = "Queued"
    case exporting = "Exporting"
    case completed = "Done"
    case failed = "Failed"
    case cancelled = "Cancelled"
}
