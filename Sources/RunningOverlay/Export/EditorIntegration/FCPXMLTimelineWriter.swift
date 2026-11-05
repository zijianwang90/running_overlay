import Foundation

/// Probed properties of one source video, kept separate from AVFoundation so
/// the FCPXML writer stays pure and testable.
struct EditorPackageSourceMediaInfo: Equatable {
    var width: Int
    var height: Int
    /// Nominal frame rate (for example 29.97).
    var frameRate: Double
    var hasAudio: Bool
    var duration: TimeInterval
}

/// Rational frame duration and the rational time strings FCPXML expects.
///
/// FCPXML times are rational seconds (`1001/30000s`). Every value the writer
/// emits is a whole number of sequence frames, so rounding happens in frames
/// rather than in seconds.
struct FCPXMLFrameRate: Equatable {
    let numerator: Int
    let denominator: Int

    init(numerator: Int, denominator: Int) {
        let denominator = denominator == 0 ? 1 : denominator
        guard numerator != 0 else {
            self.numerator = 0
            self.denominator = 1
            return
        }
        let divisor = Self.greatestCommonDivisor(abs(numerator), abs(denominator))
        let sign = denominator < 0 ? -1 : 1
        self.numerator = numerator / divisor * sign
        self.denominator = abs(denominator) / divisor
    }

    init(frameRate: ProjectFrameRate) {
        switch frameRate.id {
        case "23.976":
            self.init(numerator: 1001, denominator: 24000)
        case "29.97":
            self.init(numerator: 1001, denominator: 30000)
        case "59.94":
            self.init(numerator: 1001, denominator: 60000)
        default:
            let whole = max(Int(frameRate.value.rounded()), 1)
            self.init(numerator: 1, denominator: whole)
        }
    }

    init(framesPerSecond: Double) {
        guard framesPerSecond > 0, framesPerSecond.isFinite else {
            self.init(numerator: 1, denominator: 30)
            return
        }

        let knownRates: [(rate: Double, numerator: Int, denominator: Int)] = [
            (23.976, 1001, 24000),
            (24, 1, 24),
            (25, 1, 25),
            (29.97, 1001, 30000),
            (30, 1, 30),
            (50, 1, 50),
            (59.94, 1001, 60000),
            (60, 1, 60)
        ]
        if let known = knownRates.first(where: { abs($0.rate - framesPerSecond) < 0.02 }) {
            self.init(numerator: known.numerator, denominator: known.denominator)
            return
        }

        let rounded = framesPerSecond.rounded()
        if abs(framesPerSecond - rounded) < 0.001 {
            self.init(numerator: 1, denominator: max(Int(rounded), 1))
            return
        }

        // Unusual rate: keep six decimal places of the frame duration.
        let frameDurationMicros = Int((1_000_000 / framesPerSecond).rounded())
        self.init(numerator: frameDurationMicros, denominator: 1_000_000)
    }

    var frameDurationString: String {
        "\(numerator)/\(denominator)s"
    }

    var framesPerSecond: Double {
        Double(denominator) / Double(numerator)
    }

    /// Rounds `seconds` to the nearest whole frame.
    func frames(seconds: TimeInterval) -> Int {
        guard framesPerSecond > 0, seconds.isFinite else { return 0 }
        return Int((seconds * framesPerSecond).rounded())
    }

    func seconds(frames: Int) -> TimeInterval {
        Double(frames) / framesPerSecond
    }

    func timeString(frames: Int) -> String {
        guard frames != 0 else { return "0s" }
        let rational = FCPXMLFrameRate(numerator: frames * numerator, denominator: denominator)
        return rational.denominator == 1
            ? "\(rational.numerator)s"
            : "\(rational.numerator)/\(rational.denominator)s"
    }

    func timeString(seconds: TimeInterval) -> String {
        timeString(frames: frames(seconds: seconds))
    }

    private static func greatestCommonDivisor(_ lhs: Int, _ rhs: Int) -> Int {
        var a = lhs
        var b = rhs
        while b != 0 {
            let remainder = a % b
            a = b
            b = remainder
        }
        return max(a, 1)
    }
}

/// One alpha overlay movie inside the package.
struct EditorPackageTimelineOverlay: Equatable {
    var fileName: String
    var fileURL: URL
    var duration: TimeInterval
}

/// One source clip and its connected overlay placement.
///
/// `startTime` is project timeline time; the writer normalizes it against the
/// earliest clip. `trackIndex` is the app track the clip sits on, which becomes
/// a connected lane when tracks overlap. `overlaySourceStart` is media time in
/// the overlay movie at the clip's first frame, and may be negative when the
/// clip starts before the activity.
struct EditorPackageTimelineClip: Equatable {
    var mediaName: String
    var mediaURL: URL
    var duration: TimeInterval
    var overlayFileName: String
    var overlaySourceStart: TimeInterval
    var startTime: TimeInterval = 0
    var trackIndex: Int = 0
}

/// Writes an FCPXML 1.10 timeline Final Cut Pro imports directly and DaVinci
/// Resolve imports through File > Import > Timeline.
///
/// Layout:
/// - The spine takes clips in time order whenever they do not overlap what
///   precedes them, so every covered region is anchored to a real clip. Gaps
///   appear only where no clip exists, because FCPXML gaps cannot carry
///   connected clips.
/// - By default empty stretches between clips are removed so the timeline
///   imports as a packed sequence. Set `preservesTimelinePositions` to keep
///   the project's empty stretches as gaps; a continuous full-activity overlay
///   needs them to stay aligned.
/// - Overlapping clips from other tracks become connected clips on lanes above
///   the spine item that contains their start. Lanes are packed so clips that
///   overlap in time never share a lane.
/// - Overlays sit above every source lane. Overlays that overlap in time stack
///   on separate lanes; sequential ones share the lowest lane.
///
/// The asset media URLs are absolute and percent-encoded; FCPXML has no way to
/// express package-relative media paths.
struct FCPXMLTimelineWriter {
    var projectName: String
    var frameRate: ProjectFrameRate
    var canvasWidth: Int
    var canvasHeight: Int
    var overlays: [EditorPackageTimelineOverlay]
    var clips: [EditorPackageTimelineClip]
    var mediaInfo: [URL: EditorPackageSourceMediaInfo] = [:]
    /// When false, stretches of the project timeline that no clip covers are
    /// removed. Defaults to false so imported clips sit back to back.
    var preservesTimelinePositions: Bool = false

    private static let epsilon: TimeInterval = 0.000_001

    func xmlString() -> String {
        let sequenceRate = FCPXMLFrameRate(frameRate: frameRate)
        var resources: [XMLElement] = []
        var nextResourceNumber = 1

        func makeResourceID() -> String {
            defer { nextResourceNumber += 1 }
            return "r\(nextResourceNumber)"
        }

        let sequenceFormatID = makeResourceID()
        let sequenceFormatKey = formatKey(
            width: canvasWidth,
            height: canvasHeight,
            frameDuration: sequenceRate
        )
        var formatIDs: [String: String] = [sequenceFormatKey: sequenceFormatID]
        resources.append(makeFormat(
            id: sequenceFormatID,
            name: "\(canvasWidth)x\(canvasHeight) \(frameRate.id)fps",
            width: canvasWidth,
            height: canvasHeight,
            frameDuration: sequenceRate
        ))

        var assetIDsByURL: [URL: String] = [:]
        var sourceDurations: [URL: TimeInterval] = [:]
        var sourceNames: [URL: String] = [:]
        var sourceOrder: [URL] = []
        for clip in clips {
            if sourceDurations[clip.mediaURL] == nil {
                sourceOrder.append(clip.mediaURL)
                sourceNames[clip.mediaURL] = clip.mediaName
            }
            sourceDurations[clip.mediaURL] = max(sourceDurations[clip.mediaURL] ?? 0, clip.duration)
        }

        for url in sourceOrder {
            let info = mediaInfo[url]
            let sourceRate = info.map { FCPXMLFrameRate(framesPerSecond: $0.frameRate) } ?? sequenceRate
            let sourceWidth = info?.width ?? canvasWidth
            let sourceHeight = info?.height ?? canvasHeight
            let key = formatKey(width: sourceWidth, height: sourceHeight, frameDuration: sourceRate)
            let formatID: String
            if let existing = formatIDs[key] {
                formatID = existing
            } else {
                let newID = makeResourceID()
                formatIDs[key] = newID
                resources.append(makeFormat(
                    id: newID,
                    name: "\(sourceWidth)x\(sourceHeight) \(sourceRate.frameDurationString)",
                    width: sourceWidth,
                    height: sourceHeight,
                    frameDuration: sourceRate
                ))
                formatID = newID
            }

            let durationSeconds = max(sourceDurations[url] ?? 0, info?.duration ?? 0)
            let assetID = makeResourceID()
            assetIDsByURL[url] = assetID
            resources.append(makeAsset(
                id: assetID,
                name: sourceNames[url] ?? url.lastPathComponent,
                duration: sequenceRate.timeString(frames: framesAtLeastOne(sequenceRate, seconds: durationSeconds)),
                hasAudio: info?.hasAudio == true,
                formatID: formatID,
                mediaURL: url
            ))
        }

        var overlayAssets: [String: (id: String, frames: Int)] = [:]
        for overlay in overlays where overlayAssets[overlay.fileName] == nil {
            let assetID = makeResourceID()
            let frames = framesAtLeastOne(sequenceRate, seconds: overlay.duration)
            overlayAssets[overlay.fileName] = (assetID, frames)
            resources.append(makeAsset(
                id: assetID,
                name: overlay.fileName,
                duration: sequenceRate.timeString(frames: frames),
                hasAudio: false,
                formatID: sequenceFormatID,
                mediaURL: overlay.fileURL
            ))
        }

        let layout = TimelineLayout(
            clips: clips,
            overlays: overlays,
            rate: sequenceRate,
            preservesTimelinePositions: preservesTimelinePositions
        )
        let spine = XMLElement(name: "spine")
        let spineElements = layout.spineElements(
            makeClip: { clip in
                guard let assetID = assetIDsByURL[clip.mediaURL] else { return nil }
                let element = XMLElement(name: "asset-clip")
                element.setAttribute("ref", assetID)
                element.setAttribute("name", clip.mediaName)
                return element
            },
            makeOverlay: { fileName in
                guard let asset = overlayAssets[fileName] else { return nil }
                let element = XMLElement(name: "asset-clip")
                element.setAttribute("ref", asset.id)
                element.setAttribute("name", fileName)
                return element
            }
        )
        for element in spineElements {
            spine.addChild(element)
        }

        let resourcesElement = XMLElement(name: "resources")
        for resource in resources {
            resourcesElement.addChild(resource)
        }

        let sequence = XMLElement(name: "sequence")
        sequence.setAttribute("format", sequenceFormatID)
        sequence.setAttribute("tcStart", "0s")
        sequence.setAttribute("tcFormat", "NDF")
        sequence.setAttribute("duration", sequenceRate.timeString(frames: layout.sequenceFrames))
        sequence.addChild(spine)

        let project = XMLElement(name: "project")
        project.setAttribute("name", projectName)
        project.addChild(sequence)

        let event = XMLElement(name: "event")
        event.setAttribute("name", "\(projectName) Event")
        event.addChild(project)

        let library = XMLElement(name: "library")
        library.addChild(event)

        let root = XMLElement(name: "fcpxml")
        root.setAttribute("version", "1.10")
        root.addChild(resourcesElement)
        root.addChild(library)

        let document = XMLDocument()
        document.version = "1.0"
        document.characterEncoding = "UTF-8"
        document.isStandalone = false
        let dtd = XMLDTD()
        dtd.name = "fcpxml"
        document.dtd = dtd
        document.setRootElement(root)

        let data = document.xmlData(options: [.nodePrettyPrint])
        return String(decoding: data, as: UTF8.self)
    }

    private func makeFormat(
        id: String,
        name: String,
        width: Int,
        height: Int,
        frameDuration: FCPXMLFrameRate
    ) -> XMLElement {
        let format = XMLElement(name: "format")
        format.setAttribute("id", id)
        format.setAttribute("name", name)
        format.setAttribute("frameDuration", frameDuration.frameDurationString)
        format.setAttribute("width", String(width))
        format.setAttribute("height", String(height))
        format.setAttribute("colorSpace", "1-1-1 (Rec. 709)")
        return format
    }

    private func makeAsset(
        id: String,
        name: String,
        duration: String,
        hasAudio: Bool,
        formatID: String,
        mediaURL: URL
    ) -> XMLElement {
        let asset = XMLElement(name: "asset")
        asset.setAttribute("id", id)
        asset.setAttribute("name", name)
        asset.setAttribute("start", "0s")
        asset.setAttribute("duration", duration)
        asset.setAttribute("hasVideo", "1")
        asset.setAttribute("hasAudio", hasAudio ? "1" : "0")
        asset.setAttribute("format", formatID)

        let mediaRep = XMLElement(name: "media-rep")
        mediaRep.setAttribute("kind", "original-media")
        mediaRep.setAttribute("src", mediaURL.absoluteString)
        asset.addChild(mediaRep)
        return asset
    }

    private func formatKey(width: Int, height: Int, frameDuration: FCPXMLFrameRate) -> String {
        "\(width)x\(height)@\(frameDuration.numerator)/\(frameDuration.denominator)"
    }

    private func framesAtLeastOne(_ rate: FCPXMLFrameRate, seconds: TimeInterval) -> Int {
        max(rate.frames(seconds: seconds), 1)
    }
}

// MARK: - Timeline layout

/// Places source clips into a spine plus connected lanes and attaches overlay
/// movies above them. Pure value logic so it can be tested without XML.
///
/// The layout splits the timeline into frame-aligned segments. The
/// highest-priority clip covering a segment owns it in the spine; every other
/// covering clip becomes a connected clip inside that spine item. A clip that
/// spans a spine boundary is emitted as trimmed pieces with the matching media
/// start time, so no connected clip ever runs past its parent. Final Cut Pro
/// tolerates that overflow, but DaVinci Resolve truncates it.
private struct TimelineLayout {
    struct Placement {
        var index: Int
        var clip: EditorPackageTimelineClip
        var start: TimeInterval
        var end: TimeInterval
        var startFrame: Int
        var endFrame: Int
    }

    struct ChildPiece {
        var placement: Placement
        var offsetFrames: Int
        var sourceStartFrames: Int
        var durationFrames: Int
        var lane: Int
    }

    struct OverlayPiece {
        var fileName: String
        var lane: Int
        var offsetFrames: Int
        var sourceStartFrames: Int
        var durationFrames: Int
    }

    struct SpineItem {
        var placement: Placement?
        var startFrame: Int
        var durationFrames: Int
        var sourceStartFrames: Int
        var children: [ChildPiece] = []
        var overlays: [OverlayPiece] = []
        /// A gap region of a full-activity package: the overlay movie becomes
        /// the spine item so the data layer stays continuous there.
        var overlayOnly: OverlayPiece?
    }

    private struct Segment {
        var startFrame: Int
        var endFrame: Int
        /// Covering placements in priority order.
        var covering: [Placement]
        var primary: Placement? { covering.first }
    }

    private struct Run {
        var startFrame: Int
        var endFrame: Int
        var primary: Placement?
        var segments: [Segment]
    }

    private struct ChildBuilder {
        var placement: Placement
        var startFrame: Int
        var endFrame: Int
    }

    let rate: FCPXMLFrameRate
    let items: [SpineItem]
    let sequenceFrames: Int

    private static let epsilon: TimeInterval = 0.000_001

    init(
        clips: [EditorPackageTimelineClip],
        overlays: [EditorPackageTimelineOverlay],
        rate: FCPXMLFrameRate,
        preservesTimelinePositions: Bool
    ) {
        self.rate = rate
        let overlayFrames = Dictionary(
            uniqueKeysWithValues: overlays.map { ($0.fileName, max(rate.frames(seconds: $0.duration), 1)) }
        )
        let origin = clips.map(\.startTime).min() ?? 0
        let normalized = clips.enumerated().map { index, clip -> Placement in
            let start = max(clip.startTime - origin, 0)
            let end = start + max(clip.duration, 0)
            return Placement(
                index: index,
                clip: clip,
                start: start,
                end: end,
                startFrame: rate.frames(seconds: start),
                endFrame: rate.frames(seconds: end)
            )
        }
        let placements = (preservesTimelinePositions ? normalized : Self.compacted(normalized, rate: rate))
            .filter { $0.endFrame > $0.startFrame }
            .sorted { lhs, rhs in
                if lhs.clip.trackIndex != rhs.clip.trackIndex {
                    return lhs.clip.trackIndex < rhs.clip.trackIndex
                }
                if lhs.startFrame != rhs.startFrame { return lhs.startFrame < rhs.startFrame }
                return lhs.index < rhs.index
            }

        guard let sequenceEndFrame = placements.map(\.endFrame).max(), sequenceEndFrame > 0 else {
            self.items = []
            self.sequenceFrames = 0
            return
        }

        var boundarySet = Set(placements.map(\.startFrame))
        boundarySet.formUnion(placements.map(\.endFrame))
        boundarySet.insert(0)
        let boundaries = boundarySet.filter { $0 <= sequenceEndFrame }.sorted()

        var segments: [Segment] = []
        if boundaries.count > 1 {
            for index in 0..<(boundaries.count - 1) {
                let startFrame = boundaries[index]
                let endFrame = boundaries[index + 1]
                guard endFrame > startFrame else { continue }
                let covering = placements.filter {
                    $0.startFrame <= startFrame && $0.endFrame >= endFrame
                }
                segments.append(Segment(startFrame: startFrame, endFrame: endFrame, covering: covering))
            }
        }

        var runs: [Run] = []
        for segment in segments {
            if var last = runs.last,
               last.endFrame == segment.startFrame,
               last.primary?.index == segment.primary?.index {
                last.endFrame = segment.endFrame
                last.segments.append(segment)
                runs[runs.count - 1] = last
            } else {
                runs.append(Run(
                    startFrame: segment.startFrame,
                    endFrame: segment.endFrame,
                    primary: segment.primary,
                    segments: [segment]
                ))
            }
        }

        let sharedOverlay = Self.sharedOverlay(placements, rate: rate, overlayFrames: overlayFrames)
        var items: [SpineItem] = []

        for run in runs {
            guard let primary = run.primary else {
                Self.appendGapRun(
                    run,
                    sharedOverlay: sharedOverlay,
                    overlayFrames: overlayFrames,
                    to: &items
                )
                continue
            }

            var item = SpineItem(
                placement: primary,
                startFrame: run.startFrame,
                durationFrames: run.endFrame - run.startFrame,
                sourceStartFrames: run.startFrame - primary.startFrame
            )

            var childBuilders: [Int: ChildBuilder] = [:]
            var childOrder: [Int] = []
            for segment in run.segments {
                for covering in segment.covering where covering.index != primary.index {
                    if var builder = childBuilders[covering.index], builder.endFrame == segment.startFrame {
                        builder.endFrame = segment.endFrame
                        childBuilders[covering.index] = builder
                    } else {
                        if childBuilders[covering.index] == nil {
                            childOrder.append(covering.index)
                        }
                        childBuilders[covering.index] = ChildBuilder(
                            placement: covering,
                            startFrame: segment.startFrame,
                            endFrame: segment.endFrame
                        )
                    }
                }
            }

            var lanes: [Range<Int>] = []
            for childIndex in childOrder {
                guard let builder = childBuilders[childIndex] else { continue }
                let offset = builder.startFrame - run.startFrame
                let interval = offset..<(offset + builder.endFrame - builder.startFrame)
                var laneIndex = 0
                while laneIndex < lanes.count, lanes[laneIndex].overlaps(interval) {
                    laneIndex += 1
                }
                if laneIndex == lanes.count {
                    lanes.append(0..<0)
                }
                lanes[laneIndex] = interval
                item.children.append(ChildPiece(
                    placement: builder.placement,
                    offsetFrames: offset,
                    sourceStartFrames: builder.startFrame - builder.placement.startFrame,
                    durationFrames: builder.endFrame - builder.startFrame,
                    lane: laneIndex + 1
                ))
            }

            // One overlay per segment: the highest-priority clip that has
            // overlay frames there. Overlapping angles therefore never stack
            // duplicate overlays.
            let overlayLane = (item.children.map(\.lane).max() ?? 0) + 1
            var pendingOverlay: OverlayPiece?
            for segment in run.segments {
                guard let piece = Self.overlayPiece(
                    for: segment,
                    parentStartFrame: run.startFrame,
                    rate: rate,
                    overlayFrames: overlayFrames
                ) else { continue }
                if var pending = pendingOverlay,
                   pending.fileName == piece.fileName,
                   pending.offsetFrames + pending.durationFrames == piece.offsetFrames,
                   pending.sourceStartFrames + pending.durationFrames == piece.sourceStartFrames {
                    pending.durationFrames += piece.durationFrames
                    pendingOverlay = pending
                } else {
                    if var pending = pendingOverlay {
                        pending.lane = overlayLane
                        item.overlays.append(pending)
                    }
                    pendingOverlay = piece
                }
            }
            if var pending = pendingOverlay {
                pending.lane = overlayLane
                item.overlays.append(pending)
            }
            items.append(item)
        }

        self.items = items
        self.sequenceFrames = items.last.map { $0.startFrame + $0.durationFrames } ?? 0
    }

    /// Removes the stretches no clip covers. Overlapping clips keep their
    /// relative offsets, so multi-track lanes are unaffected; only empty
    /// project-timeline stretches disappear.
    private static func compacted(_ placements: [Placement], rate: FCPXMLFrameRate) -> [Placement] {
        guard placements.count > 1 else { return placements }
        let intervals = placements
            .map { (start: $0.start, end: $0.end) }
            .filter { $0.end > $0.start }
            .sorted { $0.start < $1.start }
        guard let first = intervals.first else { return placements }

        var gaps: [(start: TimeInterval, end: TimeInterval)] = []
        var coveredEnd = first.end
        for interval in intervals.dropFirst() {
            if interval.start > coveredEnd + epsilon {
                gaps.append((coveredEnd, interval.start))
                coveredEnd = interval.end
            } else {
                coveredEnd = max(coveredEnd, interval.end)
            }
        }
        guard !gaps.isEmpty else { return placements }

        func shifted(_ time: TimeInterval) -> TimeInterval {
            var removed: TimeInterval = 0
            for gap in gaps where gap.start < time - epsilon {
                removed += min(gap.end, time) - gap.start
            }
            return max(time - removed, 0)
        }

        return placements.map { placement in
            var placement = placement
            placement.start = shifted(placement.start)
            placement.end = shifted(placement.end)
            placement.startFrame = rate.frames(seconds: placement.start)
            placement.endFrame = rate.frames(seconds: placement.end)
            return placement
        }
    }

    /// Overlay frames for one segment, owned by the highest-priority covering
    /// clip that has frames there. `offsetFrames` is relative to the parent
    /// spine item.
    private static func overlayPiece(
        for segment: Segment,
        parentStartFrame: Int,
        rate: FCPXMLFrameRate,
        overlayFrames: [String: Int]
    ) -> OverlayPiece? {
        for covering in segment.covering {
            let fileName = covering.clip.overlayFileName
            guard !fileName.isEmpty,
                  let totalFrames = overlayFrames[fileName],
                  totalFrames > 0 else { continue }

            let pieceOffset = segment.startFrame - covering.startFrame
            let rawSource = rate.frames(seconds: covering.clip.overlaySourceStart) + pieceOffset
            let shift = max(-rawSource, 0)
            let startFrames = max(rawSource, 0)
            let pieceFrames = segment.endFrame - segment.startFrame
            let durationFrames = min(totalFrames - startFrames, pieceFrames - shift)
            guard durationFrames > 0 else { continue }

            return OverlayPiece(
                fileName: fileName,
                lane: 0,
                offsetFrames: segment.startFrame - parentStartFrame + shift,
                sourceStartFrames: startFrames,
                durationFrames: durationFrames
            )
        }
        return nil
    }

    /// One overlay movie shared by every clip (full-activity layout) maps
    /// project time to activity time with a constant offset.
    private static func sharedOverlay(
        _ placements: [Placement],
        rate: FCPXMLFrameRate,
        overlayFrames: [String: Int]
    ) -> (fileName: String, offsetFrames: Int)? {
        guard placements.count > 1 else { return nil }
        let names = Set(placements.map(\.clip.overlayFileName).filter { !$0.isEmpty })
        guard names.count == 1,
              let fileName = names.first,
              overlayFrames[fileName] != nil else { return nil }

        let offsets = Set(placements.map {
            rate.frames(seconds: $0.clip.overlaySourceStart) - $0.startFrame
        })
        guard offsets.count == 1, let offsetFrames = offsets.first else { return nil }
        return (fileName, offsetFrames)
    }

    /// A stretch no clip covers. With a shared full-activity overlay the
    /// overlay movie itself fills the spine there, so the data layer keeps
    /// running across the empty stretch instead of stopping at the last clip.
    private static func appendGapRun(
        _ run: Run,
        sharedOverlay: (fileName: String, offsetFrames: Int)?,
        overlayFrames: [String: Int],
        to items: inout [SpineItem]
    ) {
        let length = run.endFrame - run.startFrame
        guard length > 0 else { return }

        if let sharedOverlay, let totalFrames = overlayFrames[sharedOverlay.fileName] {
            let sourceStart = run.startFrame + sharedOverlay.offsetFrames
            if sourceStart >= 0, sourceStart < totalFrames {
                let durationFrames = min(length, totalFrames - sourceStart)
                var item = SpineItem(
                    placement: nil,
                    startFrame: run.startFrame,
                    durationFrames: durationFrames,
                    sourceStartFrames: sourceStart
                )
                item.overlayOnly = OverlayPiece(
                    fileName: sharedOverlay.fileName,
                    lane: 1,
                    offsetFrames: 0,
                    sourceStartFrames: sourceStart,
                    durationFrames: durationFrames
                )
                items.append(item)
                if durationFrames < length {
                    items.append(SpineItem(
                        placement: nil,
                        startFrame: run.startFrame + durationFrames,
                        durationFrames: length - durationFrames,
                        sourceStartFrames: 0
                    ))
                }
                return
            }
        }

        items.append(SpineItem(
            placement: nil,
            startFrame: run.startFrame,
            durationFrames: length,
            sourceStartFrames: 0
        ))
    }

    /// Builds the spine elements, nesting connected clips and overlays under
    /// their parent. `makeClip` and `makeOverlay` supply the resource `ref`;
    /// the layout supplies offsets, starts, lanes, and durations.
    func spineElements(
        makeClip: (EditorPackageTimelineClip) -> XMLElement?,
        makeOverlay: (String) -> XMLElement?
    ) -> [XMLElement] {
        var elements: [XMLElement] = []
        for item in items {
            if let overlay = item.overlayOnly, let element = makeOverlay(overlay.fileName) {
                configure(
                    element,
                    offsetFrames: item.startFrame,
                    startFrames: overlay.sourceStartFrames,
                    durationFrames: overlay.durationFrames
                )
                elements.append(element)
                continue
            }

            if let placement = item.placement, let element = makeClip(placement.clip) {
                configure(
                    element,
                    offsetFrames: item.startFrame,
                    startFrames: item.sourceStartFrames,
                    durationFrames: item.durationFrames
                )
                for child in item.children {
                    guard let childElement = makeClip(child.placement.clip) else { continue }
                    configure(
                        childElement,
                        offsetFrames: child.offsetFrames,
                        startFrames: child.sourceStartFrames,
                        durationFrames: child.durationFrames
                    )
                    childElement.setAttribute("lane", String(child.lane))
                    element.addChild(childElement)
                }
                for overlay in item.overlays {
                    guard let overlayElement = makeOverlay(overlay.fileName) else { continue }
                    configure(
                        overlayElement,
                        offsetFrames: overlay.offsetFrames,
                        startFrames: overlay.sourceStartFrames,
                        durationFrames: overlay.durationFrames
                    )
                    overlayElement.setAttribute("lane", String(max(overlay.lane, 1)))
                    element.addChild(overlayElement)
                }
                elements.append(element)
                continue
            }

            elements.append(makeGap(startFrames: item.startFrame, durationFrames: item.durationFrames))
        }
        return elements
    }

    private func configure(
        _ element: XMLElement,
        offsetFrames: Int,
        startFrames: Int,
        durationFrames: Int
    ) {
        element.setAttribute("offset", rate.timeString(frames: offsetFrames))
        element.setAttribute("start", rate.timeString(frames: startFrames))
        element.setAttribute("duration", rate.timeString(frames: max(durationFrames, 1)))
    }

    private func makeGap(startFrames: Int, durationFrames: Int) -> XMLElement {
        let element = XMLElement(name: "gap")
        element.setAttribute("offset", rate.timeString(frames: startFrames))
        element.setAttribute("duration", rate.timeString(frames: max(durationFrames, 1)))
        return element
    }
}

private extension XMLElement {
    func setAttribute(_ name: String, _ value: String) {
        addAttribute(XMLNode.attribute(withName: name, stringValue: value) as! XMLNode)
    }
}
