import AVFoundation
import CoreVideo
import Foundation
import SwiftUI

enum SwiftUIOverlayExportError: LocalizedError {
    case noSupportedOverlays
    case cannotCreatePixelBuffer
    case cannotStartWriting(String)
    case appendFailed(String)

    var errorDescription: String? {
        switch self {
        case .noSupportedOverlays:
            "No supported overlays are available for SwiftUI experimental export."
        case .cannotCreatePixelBuffer:
            "Could not create an export pixel buffer."
        case .cannotStartWriting(let reason):
            "Could not start writing SwiftUI overlay video: \(reason)"
        case .appendFailed(let reason):
            "Could not append SwiftUI overlay frame: \(reason)"
        }
    }
}

struct SwiftUIOverlayVideoExporter {
    static func export(job: OverlayExportJob, progress: @escaping @MainActor (OverlayExportProgress) -> Void) async throws {
        guard !job.segments.isEmpty else {
            throw OverlayExportError.noSegments
        }

        let supportedOverlays = job.overlayLayout.elements.filter {
            $0.isVisible && ($0.type.isNumericOverlay || $0.type == .distanceTimeline || $0.type == .routeMap)
        }
        guard !supportedOverlays.isEmpty else {
            throw SwiftUIOverlayExportError.noSupportedOverlays
        }

        try FileManager.default.createDirectory(at: job.destinationURL, withIntermediateDirectories: true)

        for (index, segment) in job.segments.enumerated() {
            if Task.isCancelled {
                throw OverlayExportError.cancelled
            }
            await progress(OverlayExportProgress(segmentIndex: index, segmentCount: job.segments.count, segmentName: segment.sourceFileName, segmentProgress: 0))
            try await export(
                segment: segment,
                segmentIndex: index,
                segmentCount: job.segments.count,
                job: job,
                overlays: supportedOverlays,
                progress: progress
            )
            await progress(OverlayExportProgress(segmentIndex: index, segmentCount: job.segments.count, segmentName: segment.sourceFileName, segmentProgress: 1))
        }
    }

    static func exportFramePNG(
        overlayLayout: OverlayLayout,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        size: CGSize,
        outputURL: URL
    ) async throws {
        let supportedOverlays = overlayLayout.elements.filter {
            $0.isVisible && ($0.type.isNumericOverlay || $0.type == .distanceTimeline || $0.type == .routeMap)
        }
        guard !supportedOverlays.isEmpty else {
            throw SwiftUIOverlayExportError.noSupportedOverlays
        }

        let frameView = SwiftUIOverlayFrameView(
            size: size,
            overlays: supportedOverlays,
            activity: activity,
            elapsedTime: elapsedTime
        )
        guard let cgImage = await MainActor.run(body: {
            let renderer = ImageRenderer(content: frameView)
            renderer.isOpaque = false
            renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
            renderer.scale = 1
            return renderer.cgImage
        }) else {
            throw SwiftUIOverlayExportError.appendFailed("ImageRenderer did not produce a frame image.")
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw SwiftUIOverlayExportError.appendFailed("Could not convert SwiftUI frame to PNG data.")
        }
        try data.write(to: outputURL)
    }

    private static func export(
        segment: OverlayExportSegment,
        segmentIndex: Int,
        segmentCount: Int,
        job: OverlayExportJob,
        overlays: [OverlayElement],
        progress: @escaping @MainActor (OverlayExportProgress) -> Void
    ) async throws {
        let outputURL = outputURL(for: segment, destinationURL: job.destinationURL)
        try? FileManager.default.removeItem(at: outputURL)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        let width = job.settings.resolution.width
        let height = job.settings.resolution.height
        let frameRate = job.settings.frameRate.value

        let outputSettings = [
            AVVideoCodecKey: AVVideoCodecType.hevcWithAlpha,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ] as [String: Any]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
            ]
        )

        guard writer.canAdd(input) else {
            throw SwiftUIOverlayExportError.cannotStartWriting("writer input is not supported")
        }
        writer.add(input)

        guard writer.startWriting() else {
            throw SwiftUIOverlayExportError.cannotStartWriting(writer.error?.localizedDescription ?? "unknown error")
        }
        writer.startSession(atSourceTime: .zero)

        guard let pixelBufferPool = adaptor.pixelBufferPool else {
            throw SwiftUIOverlayExportError.cannotCreatePixelBuffer
        }

        let frameCount = max(1, Int(ceil(segment.duration * frameRate)))
        let progressInterval = max(frameCount / 100, 1)

        for frameIndex in 0..<frameCount {
            if Task.isCancelled {
                writer.cancelWriting()
                throw OverlayExportError.cancelled
            }
            while !input.isReadyForMoreMediaData {
                if Task.isCancelled {
                    writer.cancelWriting()
                    throw OverlayExportError.cancelled
                }
                try await Task.sleep(nanoseconds: 1_000_000)
            }

            guard let pixelBuffer = makePixelBuffer(from: pixelBufferPool) else {
                throw SwiftUIOverlayExportError.cannotCreatePixelBuffer
            }

            let clipElapsed = Double(frameIndex) / frameRate
            let activityElapsed = segment.startTime + clipElapsed
            let sampleElapsed = quantizedLayerDataTime(
                activityElapsed - job.fitStartTime,
                activityDuration: job.activity.duration,
                layerDataFrameRate: job.settings.layerDataFrameRate.value
            )

            let frameView = SwiftUIOverlayFrameView(
                size: CGSize(width: width, height: height),
                overlays: overlays,
                activity: job.activity,
                elapsedTime: sampleElapsed
            )
            guard let cgImage = await MainActor.run(body: {
                let renderer = ImageRenderer(content: frameView)
                renderer.isOpaque = false
                renderer.proposedSize = ProposedViewSize(width: CGFloat(width), height: CGFloat(height))
                renderer.scale = 1
                return renderer.cgImage
            }) else {
                throw SwiftUIOverlayExportError.appendFailed("ImageRenderer did not produce a CGImage.")
            }
            try draw(cgImage: cgImage, into: pixelBuffer, size: CGSize(width: width, height: height))

            let presentationTime = CMTime(seconds: clipElapsed, preferredTimescale: 600)
            guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                throw SwiftUIOverlayExportError.appendFailed(writer.error?.localizedDescription ?? "unknown error")
            }

            if frameIndex % progressInterval == 0 || frameIndex == frameCount - 1 {
                await progress(OverlayExportProgress(
                    segmentIndex: segmentIndex,
                    segmentCount: segmentCount,
                    segmentName: segment.sourceFileName,
                    segmentProgress: Double(frameIndex + 1) / Double(frameCount)
                ))
            }
        }

        input.markAsFinished()
        await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume()
            }
        }

        if let error = writer.error {
            throw SwiftUIOverlayExportError.appendFailed(error.localizedDescription)
        }
    }

    private static func draw(cgImage: CGImage, into pixelBuffer: CVPixelBuffer, size: CGSize) throws {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            throw SwiftUIOverlayExportError.cannotCreatePixelBuffer
        }

        context.clear(CGRect(origin: .zero, size: size))
        context.saveGState()
        context.translateBy(x: size.width, y: 0)
        context.scaleBy(x: -1, y: 1)
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        context.restoreGState()
    }

    private static func outputURL(for segment: OverlayExportSegment, destinationURL: URL) -> URL {
        let baseName = URL(fileURLWithPath: segment.sourceFileName).deletingPathExtension().lastPathComponent
        return destinationURL.appendingPathComponent("\(baseName)_swiftui_overlay.mov")
    }

    private static func makePixelBuffer(from pool: CVPixelBufferPool) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        return pixelBuffer
    }

    private static func quantizedLayerDataTime(
        _ elapsedTime: TimeInterval,
        activityDuration: TimeInterval,
        layerDataFrameRate: Double
    ) -> TimeInterval {
        let fps = max(layerDataFrameRate, 1)
        let frame = floor(max(elapsedTime, 0) * fps)
        return min(frame / fps, activityDuration)
    }

    private static func flipPixelBufferRowsVertically(_ pixelBuffer: CVPixelBuffer) {
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return
        }

        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard height > 1, bytesPerRow > 0 else {
            return
        }

        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        var scratch = [UInt8](repeating: 0, count: bytesPerRow)
        for row in 0..<(height / 2) {
            let topOffset = row * bytesPerRow
            let bottomOffset = (height - row - 1) * bytesPerRow
            scratch.withUnsafeMutableBytes { scratchPointer in
                guard let scratchBase = scratchPointer.baseAddress else {
                    return
                }
                memcpy(scratchBase, buffer.advanced(by: topOffset), bytesPerRow)
                memcpy(buffer.advanced(by: topOffset), buffer.advanced(by: bottomOffset), bytesPerRow)
                memcpy(buffer.advanced(by: bottomOffset), scratchBase, bytesPerRow)
            }
        }
    }
}

private struct SwiftUIOverlayFrameView: View {
    let size: CGSize
    let overlays: [OverlayElement]
    let activity: ActivityTimeline
    let elapsedTime: TimeInterval

    var body: some View {
        ZStack {
            Color.clear
            ForEach(overlays) { element in
                let context = OverlayRenderContext(canvasSize: size, activity: activity, elapsedTime: elapsedTime)
                Group {
                    switch element.type {
                    case .distanceTimeline:
                        OverlaySharedDistanceTimelineView(
                            element: element,
                            layout: OverlayRenderModel.distanceTimelineLayout(for: element, in: context)
                            ,
                            isInteractive: false
                        )
                    case .routeMap:
                        OverlaySharedRouteMapView(
                            element: element,
                            layout: OverlayRenderModel.routeMapLayout(for: element, in: context)
                            ,
                            isInteractive: false
                        )
                    default:
                        OverlaySharedTextPresetView(
                            element: element,
                            layout: OverlayRenderModel.textLayout(for: element, in: context),
                            isInteractive: false
                        )
                    }
                }
                .position(x: size.width * element.position.x, y: size.height * element.position.y)
            }
        }
        .frame(width: size.width, height: size.height)
        .compositingGroup()
    }
}

private struct SwiftUINumericOverlayValueView: View {
    let element: OverlayElement
    let context: OverlayRenderContext

    var body: some View {
        let layout = OverlayRenderModel.textLayout(for: element, in: context)
        let components = layout.components
        let labelText = components.label.isEmpty ? components.shortLabel : components.label

        VStack(alignment: .leading, spacing: max(layout.labelSpacing, layout.fontSize * 0.08)) {
            if element.style.showLabel, !labelText.isEmpty {
                Text(labelText.uppercased())
                    .font(.custom(element.style.labelFontName, size: layout.labelFontSize).weight(element.style.labelFontWeight.swiftUIFontWeight))
                    .foregroundStyle(Color(numericOverlay: element.style.labelColor).opacity(element.style.labelOpacity))
            }
            HStack(alignment: .firstTextBaseline, spacing: max(layout.unitSpacing, layout.fontSize * 0.12)) {
                Text(components.value)
                    .font(.custom(element.style.fontName, size: layout.fontSize).weight(element.style.fontWeight.swiftUIFontWeight))
                    .foregroundStyle(Color(numericOverlay: element.style.valueColor))
                if element.style.showUnit, !components.unit.isEmpty {
                    Text(components.unit)
                        .font(.custom(element.style.unitFontName, size: layout.unitFontSize).weight(element.style.unitFontWeight.swiftUIFontWeight))
                        .foregroundStyle(Color(numericOverlay: element.style.unitColor).opacity(element.style.unitOpacity))
                }
            }
        }
        .padding(.horizontal, element.style.backgroundEnabled ? layout.horizontalPadding : 0)
        .padding(.vertical, element.style.backgroundEnabled ? layout.verticalPadding : 0)
        .background {
            if element.style.backgroundEnabled {
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(Color(numericOverlay: element.style.backgroundColor).opacity(element.style.backgroundOpacity))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius))
        .shadow(
            color: Color.black.opacity(element.style.shadowEnabled ? element.style.shadowOpacity : 0),
            radius: element.style.shadowEnabled ? layout.shadowRadius : 0,
            x: element.style.shadowEnabled ? element.style.shadowOffsetX : 0,
            y: element.style.shadowEnabled ? layout.shadowOffsetY : 0
        )
    }
}

private struct SwiftUIDistanceTimelineOverlayView: View {
    let element: OverlayElement
    let layout: OverlayDistanceTimelineRenderLayout

    var body: some View {
        let track = localRect(layout.trackRect)
        ZStack {
            if layout.style.backgroundEnabled {
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(Color(swiftUIExport: layout.style.backgroundColor).opacity(layout.style.backgroundOpacity))
                    .frame(width: layout.rect.width, height: layout.rect.height)
            }

            if layout.style.showValue || layout.style.showLabel {
                VStack(alignment: .leading, spacing: 2) {
                    if layout.style.showLabel {
                        Text(layout.label.uppercased())
                            .font(.custom(element.style.fontName, size: layout.labelFontSize).weight(.medium))
                            .foregroundStyle(Color(swiftUIExport: element.style.foregroundColor).opacity(0.64))
                    }
                    if layout.style.showValue {
                        Text(layout.valueText)
                            .font(.custom(element.style.fontName, size: layout.valueFontSize).weight(.bold))
                            .foregroundStyle(Color(swiftUIExport: element.style.foregroundColor))
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, max(4, layout.style.paddingY * styleScale))
                .padding(.leading, max(6, layout.style.paddingX * styleScale))
            }

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: track.height / 2)
                    .fill(Color(swiftUIExport: element.style.foregroundColor).opacity(layout.style.trackOpacity))
                if layout.style.preset == .route, !layout.routePoints.isEmpty {
                    swiftUIRoutePath(points: layout.routePoints.map(localTrackPoint))
                        .stroke(Color(swiftUIExport: element.style.foregroundColor).opacity(layout.style.trackOpacity), style: StrokeStyle(lineWidth: max(track.height, 2), lineCap: .round, lineJoin: .round))
                    swiftUIRoutePath(points: progressedRoutePoints.map(localTrackPoint))
                        .stroke(Color(swiftUIExport: layout.style.fillColor), style: StrokeStyle(lineWidth: max(track.height, 2), lineCap: .round, lineJoin: .round))
                } else {
                    RoundedRectangle(cornerRadius: track.height / 2)
                        .fill(Color(swiftUIExport: layout.style.fillColor))
                        .frame(width: max(track.width * layout.progress, track.height))
                }
            }
            .frame(width: track.width, height: track.height)
            .position(x: track.midX, y: track.midY)
        }
        .frame(width: layout.rect.width, height: layout.rect.height)
    }

    private var styleScale: Double {
        layout.rect.width / max(layout.style.width, 1)
    }

    private func localRect(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX - layout.rect.minX, y: rect.minY - layout.rect.minY, width: rect.width, height: rect.height)
    }

    private func localTrackPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - layout.trackRect.minX, y: point.y - layout.trackRect.minY)
    }

    private var progressedRoutePoints: [CGPoint] {
        guard layout.routePoints.count > 1 else {
            let track = layout.trackRect
            return [
                CGPoint(x: track.minX, y: track.midY),
                CGPoint(x: track.minX + track.width * layout.progress, y: track.midY)
            ]
        }
        let lastIndex = max(Int(round(Double(layout.routePoints.count - 1) * layout.progress)), 1)
        return Array(layout.routePoints.prefix(min(lastIndex + 1, layout.routePoints.count)))
    }
}

private struct SwiftUIRouteMapOverlayView: View {
    let element: OverlayElement
    let layout: OverlayRouteMapRenderLayout

    var body: some View {
        Group {
            if layout.shape == .circle {
                routeMapContent
                    .clipShape(Circle())
            } else {
                routeMapContent
                    .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius))
            }
        }
    }

    private var routeMapContent: some View {
        ZStack {
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .fill(mapBackground)

            if layout.projectedPoints.isEmpty {
                Text("NO GPS")
                    .font(.custom(element.style.fontName, size: max(layout.rect.width * 0.09, 10)).weight(.semibold))
                    .foregroundStyle(Color(swiftUIExport: element.style.foregroundColor).opacity(0.72))
            } else {
                swiftUIRoutePath(points: relativePoints)
                    .stroke(Color.black.opacity(0.55), style: StrokeStyle(lineWidth: layout.lineWidth + 3, lineCap: .round, lineJoin: .round))
                swiftUIRoutePath(points: relativePoints)
                    .stroke(routeStroke, style: StrokeStyle(lineWidth: layout.lineWidth, lineCap: .round, lineJoin: .round))
                if let first = relativePoints.first {
                    Circle().fill(Color.green).frame(width: 7, height: 7).position(first)
                }
                if let last = relativePoints.last {
                    Circle().fill(Color.red).frame(width: 7, height: 7).position(last)
                }
                if let current = relativeCurrentPoint {
                    Circle()
                        .fill(Color(swiftUIExport: element.style.routeMapRunnerDotColor))
                        .frame(width: max(layout.lineWidth * 2.6, 8), height: max(layout.lineWidth * 2.6, 8))
                        .position(current)
                }
            }
        }
        .frame(width: layout.rect.width, height: layout.rect.height)
    }

    private var relativePoints: [CGPoint] {
        layout.projectedPoints.map { CGPoint(x: $0.x - layout.rect.minX, y: $0.y - layout.rect.minY) }
    }

    private var relativeCurrentPoint: CGPoint? {
        layout.projectedCurrentPoint.map { CGPoint(x: $0.x - layout.rect.minX, y: $0.y - layout.rect.minY) }
    }

    private var mapBackground: Color {
        switch element.style.routeMapBackgroundStyle {
        case .light:
            return Color.white.opacity(max(element.style.backgroundOpacity, 0.48))
        case .terrain:
            return Color(red: 0.13, green: 0.17, blue: 0.13).opacity(max(element.style.backgroundOpacity, 0.66))
        case .satellite:
            return Color(red: 0.05, green: 0.07, blue: 0.06).opacity(max(element.style.backgroundOpacity, 0.74))
        case .dark:
            return Color(red: 0.08, green: 0.10, blue: 0.11).opacity(max(element.style.backgroundOpacity, 0.72))
        case .none:
            return Color.black.opacity(element.style.backgroundOpacity)
        }
    }

    private var routeStroke: AnyShapeStyle {
        if element.style.routeMapColorMode == .gradient || layout.preset == .gradient {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(swiftUIExport: element.style.routeMapGradientStart),
                        Color(swiftUIExport: element.style.routeMapGradientMiddle),
                        Color(swiftUIExport: element.style.routeMapGradientEnd)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        return AnyShapeStyle(Color(swiftUIExport: element.style.foregroundColor))
    }
}

private func swiftUIRoutePath(points: [CGPoint]) -> Path {
    Path { path in
        guard let first = points.first else { return }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
    }
}

private extension OverlayFontWeight {
    var swiftUIFontWeight: Font.Weight {
        switch self {
        case .regular:
            .regular
        case .medium:
            .medium
        case .semibold:
            .semibold
        case .bold:
            .bold
        }
    }
}

private extension Color {
    init(swiftUIExport color: OverlayColor) {
        self.init(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
    }
}
