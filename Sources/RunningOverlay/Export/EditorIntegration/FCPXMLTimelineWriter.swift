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

    /// Rounds `seconds` to the nearest whole frame.
    func frames(seconds: TimeInterval) -> Int {
        let frameDuration = Double(numerator) / Double(denominator)
        guard frameDuration > 0, seconds.isFinite else { return 0 }
        return Int((seconds / frameDuration).rounded())
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

/// One source clip and its connected overlay placement, already in project
/// timeline order. `overlaySourceStart` is activity elapsed time in
/// full-activity mode (possibly negative) and zero in per-clip mode.
struct EditorPackageTimelineClip: Equatable {
    var mediaName: String
    var mediaURL: URL
    var duration: TimeInterval
    var overlayFileName: String
    var overlaySourceStart: TimeInterval
}

/// Writes an FCPXML 1.10 timeline Final Cut Pro imports directly and DaVinci
/// Resolve imports through File > Import > Timeline.
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

        // spine: source clips back-to-back, each with its overlay connected on
        // lane 1.
        var cursorFrames = 0
        var spineClips: [XMLElement] = []
        for clip in clips {
            let clipFrames = framesAtLeastOne(sequenceRate, seconds: clip.duration)
            let sourceClip = XMLElement(name: "asset-clip")
            guard let assetID = assetIDsByURL[clip.mediaURL] else { continue }
            sourceClip.setAttribute("ref", assetID)
            sourceClip.setAttribute("name", clip.mediaName)
            sourceClip.setAttribute("offset", sequenceRate.timeString(frames: cursorFrames))
            sourceClip.setAttribute("start", "0s")
            sourceClip.setAttribute("duration", sequenceRate.timeString(frames: clipFrames))

            if let overlay = overlayAssets[clip.overlayFileName] {
                let overlaySourceFrames = sequenceRate.frames(seconds: clip.overlaySourceStart)
                var startFrames = overlaySourceFrames
                var shiftFrames = 0
                if startFrames < 0 {
                    shiftFrames = -startFrames
                    startFrames = 0
                }
                let availableInOverlay = overlay.frames - startFrames
                let availableInClip = clipFrames - shiftFrames
                let connectedFrames = min(availableInOverlay, availableInClip)
                if connectedFrames > 0 {
                    let connected = XMLElement(name: "asset-clip")
                    connected.setAttribute("ref", overlay.id)
                    connected.setAttribute("lane", "1")
                    connected.setAttribute("name", clip.overlayFileName)
                    // A connected clip's offset is in its parent's local
                    // timeline, which begins at the parent's `start` (0s),
                    // not in sequence time.
                    connected.setAttribute("offset", sequenceRate.timeString(frames: shiftFrames))
                    connected.setAttribute("start", sequenceRate.timeString(frames: startFrames))
                    connected.setAttribute("duration", sequenceRate.timeString(frames: connectedFrames))
                    sourceClip.addChild(connected)
                }
            }

            spineClips.append(sourceClip)
            cursorFrames += clipFrames
        }

        let resourcesElement = XMLElement(name: "resources")
        for resource in resources {
            resourcesElement.addChild(resource)
        }

        let spine = XMLElement(name: "spine")
        for clip in spineClips {
            spine.addChild(clip)
        }

        let sequence = XMLElement(name: "sequence")
        sequence.setAttribute("format", sequenceFormatID)
        sequence.setAttribute("tcStart", "0s")
        sequence.setAttribute("tcFormat", "NDF")
        sequence.setAttribute("duration", sequenceRate.timeString(frames: cursorFrames))
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

private extension XMLElement {
    func setAttribute(_ name: String, _ value: String) {
        addAttribute(XMLNode.attribute(withName: name, stringValue: value) as! XMLNode)
    }
}
