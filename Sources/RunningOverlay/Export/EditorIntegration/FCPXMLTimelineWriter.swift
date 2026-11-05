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
            rate: sequenceRate
        )
        let spine = XMLElement(name: "spine")
        let spineElements = layout.spineElements(
            makeClip: { clip in
                guard let assetID = assetIDsByURL[clip.mediaURL] else { return nil }
                let element = XMLElement(name: "asset-clip")
                element.setAttribute("ref", assetID)
                element.setAttribute("name", clip.mediaName)
                element.setAttribute("start", "0s")
                element.setAttribute(
                    "duration",
                    sequenceRate.timeString(frames: framesAtLeastOne(sequenceRate, seconds: clip.duration))
                )
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
private struct TimelineLayout {
    struct Placement {
        var index: Int
        var clip: EditorPackageTimelineClip
        var start: TimeInterval
        var end: TimeInterval
    }

    struct OverlayPlacement {
        /// Connected clip offset inside its parent.
        var offsetFrames: Int
        /// Media time of the overlay movie at the connected clip's first frame.
        var startFrames: Int
        var durationFrames: Int
    }

    let rate: FCPXMLFrameRate
    let placements: [Placement]
    let spine: [Placement]
    let attached: [Placement]
    let origin: TimeInterval
    let sequenceFrames: Int
    let lanesByClipIndex: [Int: Int]
    let overlaysByClipIndex: [Int: OverlayPlacement]
    let overlayAbsoluteLaneByClipIndex: [Int: Int]
    /// Full-activity packages use one movie for many clips; with overlapping
    /// tracks it is attached once above the program instead of once per clip.
    let singleOverlayClipIndex: Int?
    let maxSourceLane: Int
    let overlayFramesByFileName: [String: Int]

    private static let epsilon: TimeInterval = 0.000_001

    init(clips: [EditorPackageTimelineClip], overlays: [EditorPackageTimelineOverlay], rate: FCPXMLFrameRate) {
        let overlayFrames = Dictionary(
            uniqueKeysWithValues: overlays.map { ($0.fileName, max(rate.frames(seconds: $0.duration), 1)) }
        )
        let origin = clips.map(\.startTime).min() ?? 0
        let normalized = clips.enumerated().map { index, clip -> Placement in
            let start = max(clip.startTime - origin, 0)
            return Placement(index: index, clip: clip, start: start, end: start + max(clip.duration, 0))
        }
        let sorted = normalized.sorted { lhs, rhs in
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            if lhs.clip.trackIndex != rhs.clip.trackIndex { return lhs.clip.trackIndex < rhs.clip.trackIndex }
            return lhs.index < rhs.index
        }

        var spine: [Placement] = []
        var attached: [Placement] = []
        var spineEnd = -TimeInterval.infinity
        for placement in sorted {
            if placement.start >= spineEnd - Self.epsilon {
                spine.append(placement)
                spineEnd = max(spineEnd, placement.end)
            } else {
                attached.append(placement)
            }
        }

        var sequenceEnd = spine.last?.end ?? 0
        for placement in attached {
            sequenceEnd = max(sequenceEnd, placement.end)
        }
        let sequenceFrames = max(rate.frames(seconds: sequenceEnd), spine.isEmpty ? 0 : 1)

        // Lane packing for attached clips, per parent spine item. Parents are
        // always spine items, so the absolute lane equals the relative lane.
        // Intervals are frame ranges so frame-aligned clips never collide by
        // floating-point drift.
        var lanesByParent: [Int: [Range<Int>]] = [:]
        var laneByClipIndex: [Int: Int] = [:]
        var maxSourceLane = 0
        for placement in attached {
            guard let parent = Self.parentIndex(of: placement, in: spine) else { continue }
            var lanes = lanesByParent[parent] ?? []
            let startFrame = rate.frames(seconds: placement.start)
            let durationFrames = max(rate.frames(seconds: placement.clip.duration), 1)
            let interval = startFrame..<(startFrame + durationFrames)
            var laneIndex = 0
            while laneIndex < lanes.count, lanes[laneIndex].overlaps(interval) {
                laneIndex += 1
            }
            if laneIndex == lanes.count {
                lanes.append(0..<0)
            }
            lanes[laneIndex] = interval
            lanesByParent[parent] = lanes
            laneByClipIndex[placement.index] = laneIndex + 1
            maxSourceLane = max(maxSourceLane, laneIndex + 1)
        }

        // Overlay placement per clip.
        var overlayPlacementByClipIndex: [Int: OverlayPlacement] = [:]
        for placement in sorted {
            let fileName = placement.clip.overlayFileName
            guard let totalFrames = overlayFrames[fileName], totalFrames > 0 else { continue }
            let sourceFrames = rate.frames(seconds: placement.clip.overlaySourceStart)
            let shiftFrames = max(-sourceFrames, 0)
            let startFrames = max(sourceFrames, 0)
            let clipFrames = max(rate.frames(seconds: placement.clip.duration), 1)
            let availableInOverlay = totalFrames - startFrames
            let availableInClip = clipFrames - shiftFrames
            let durationFrames = min(availableInOverlay, availableInClip)
            guard durationFrames > 0 else { continue }
            overlayPlacementByClipIndex[placement.index] = OverlayPlacement(
                offsetFrames: shiftFrames,
                startFrames: startFrames,
                durationFrames: durationFrames
            )
        }

        // A shared overlay movie across overlapping tracks covers the whole
        // activity; attach it once above the program instead of duplicating it
        // on every angle.
        var singleOverlayClipIndex: Int?
        if !attached.isEmpty, let firstSpine = spine.first {
            var sharedCounts: [String: Int] = [:]
            for placement in sorted {
                sharedCounts[placement.clip.overlayFileName, default: 0] += 1
            }
            let fileName = firstSpine.clip.overlayFileName
            if let totalFrames = overlayFrames[fileName],
               let count = sharedCounts[fileName], count > 1 {
                let sequenceStartFrames = rate.frames(seconds: firstSpine.start)
                let sequenceEndFrames = rate.frames(seconds: sequenceEnd)
                let durationFrames = min(totalFrames, max(sequenceEndFrames - sequenceStartFrames, 1))
                if durationFrames > 0 {
                    singleOverlayClipIndex = firstSpine.index
                    for placement in sorted where placement.clip.overlayFileName == fileName {
                        overlayPlacementByClipIndex.removeValue(forKey: placement.index)
                    }
                    overlayPlacementByClipIndex[firstSpine.index] = OverlayPlacement(
                        offsetFrames: 0,
                        startFrames: 0,
                        durationFrames: durationFrames
                    )
                }
            }
        }

        let overlayLanes = Self.packOverlayLanes(
            placements: sorted,
            overlaysByClipIndex: overlayPlacementByClipIndex,
            rate: rate,
            baseLane: maxSourceLane + 1
        )

        self.rate = rate
        self.overlayFramesByFileName = overlayFrames
        self.origin = origin
        self.placements = sorted
        self.spine = spine
        self.attached = attached
        self.sequenceFrames = sequenceFrames
        self.lanesByClipIndex = laneByClipIndex
        self.overlaysByClipIndex = overlayPlacementByClipIndex
        self.overlayAbsoluteLaneByClipIndex = overlayLanes
        self.singleOverlayClipIndex = singleOverlayClipIndex
        self.maxSourceLane = maxSourceLane
    }

    /// Builds the spine elements, nesting attached clips and overlays under
    /// their parent. `makeClip` and `makeOverlay` supply the resource `ref`;
    /// the layout supplies offsets, lanes, and durations.
    func spineElements(
        makeClip: (EditorPackageTimelineClip) -> XMLElement?,
        makeOverlay: (String) -> XMLElement?
    ) -> [XMLElement] {
        var elements: [XMLElement] = []
        var cursorFrames = 0

        for (parentIndex, placement) in spine.enumerated() {
            let startFrames = rate.frames(seconds: placement.start)
            let clipFrames = max(rate.frames(seconds: placement.clip.duration), 1)
            if startFrames > cursorFrames {
                elements.append(makeGap(startFrames: cursorFrames, durationFrames: startFrames - cursorFrames))
            }

            guard let element = makeClip(placement.clip) else {
                cursorFrames = max(cursorFrames, startFrames + clipFrames)
                continue
            }
            element.setAttribute("offset", rate.timeString(frames: startFrames))

            if let overlay = overlaysByClipIndex[placement.index],
               let overlayElement = makeOverlay(placement.clip.overlayFileName) {
                configureOverlay(
                    overlayElement,
                    placement: overlay,
                    lane: overlayAbsoluteLaneByClipIndex[placement.index] ?? (maxSourceLane + 1)
                )
                element.addChild(overlayElement)
            }

            for child in attached where Self.parentIndex(of: child, in: spine) == parentIndex {
                guard let childElement = makeClip(child.clip) else { continue }
                let childOffset = max(rate.frames(seconds: child.start) - startFrames, 0)
                childElement.setAttribute("offset", rate.timeString(frames: childOffset))
                if let lane = lanesByClipIndex[child.index] {
                    childElement.setAttribute("lane", String(lane))
                }
                if let overlay = overlaysByClipIndex[child.index],
                   let overlayElement = makeOverlay(child.clip.overlayFileName) {
                    // Lanes are relative to the parent clip, so put the overlay
                    // above every source lane.
                    let absoluteLane = overlayAbsoluteLaneByClipIndex[child.index] ?? (maxSourceLane + 1)
                    let relativeLane = max(absoluteLane - (lanesByClipIndex[child.index] ?? 0), 1)
                    configureOverlay(overlayElement, placement: overlay, lane: relativeLane)
                    childElement.addChild(overlayElement)
                }
                element.addChild(childElement)
            }

            elements.append(element)
            cursorFrames = max(cursorFrames, startFrames + clipFrames)
        }

        if sequenceFrames > cursorFrames {
            elements.append(makeGap(startFrames: cursorFrames, durationFrames: sequenceFrames - cursorFrames))
        }
        return elements
    }

    private func configureOverlay(_ element: XMLElement, placement: OverlayPlacement, lane: Int) {
        element.setAttribute("lane", String(max(lane, 1)))
        element.setAttribute("offset", rate.timeString(frames: placement.offsetFrames))
        element.setAttribute("start", rate.timeString(frames: placement.startFrames))
        element.setAttribute("duration", rate.timeString(frames: placement.durationFrames))
    }

    private func makeGap(startFrames: Int, durationFrames: Int) -> XMLElement {
        let element = XMLElement(name: "gap")
        element.setAttribute("offset", rate.timeString(frames: startFrames))
        element.setAttribute("duration", rate.timeString(frames: max(durationFrames, 1)))
        return element
    }

    private static func parentIndex(of placement: Placement, in spine: [Placement]) -> Int? {
        guard !spine.isEmpty else { return nil }
        if let containing = spine.firstIndex(where: {
            $0.start <= placement.start + epsilon && placement.start < $0.end - epsilon
        }) {
            return containing
        }
        if let before = spine.lastIndex(where: { $0.start <= placement.start }) {
            return before
        }
        return 0
    }

    private static func packOverlayLanes(
        placements: [Placement],
        overlaysByClipIndex: [Int: OverlayPlacement],
        rate: FCPXMLFrameRate,
        baseLane: Int
    ) -> [Int: Int] {
        var lanes: [Range<Int>] = []
        var lanesByClipIndex: [Int: Int] = [:]
        for placement in placements {
            guard let overlay = overlaysByClipIndex[placement.index] else { continue }
            let startFrame = rate.frames(seconds: placement.start) + overlay.offsetFrames
            let interval = startFrame..<(startFrame + overlay.durationFrames)
            var laneIndex = 0
            while laneIndex < lanes.count, lanes[laneIndex].overlaps(interval) {
                laneIndex += 1
            }
            if laneIndex == lanes.count {
                lanes.append(0..<0)
            }
            lanes[laneIndex] = interval
            lanesByClipIndex[placement.index] = baseLane + laneIndex
        }
        return lanesByClipIndex
    }
}

private extension XMLElement {
    func setAttribute(_ name: String, _ value: String) {
        addAttribute(XMLNode.attribute(withName: name, stringValue: value) as! XMLNode)
    }
}
