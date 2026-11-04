#if canImport(CSkiaBridge)
import AppKit
import Combine
import CSkiaBridge
import Metal
import QuartzCore
import SwiftUI

// Phase A of the Skia renderer migration (see
// docs/superpowers/plans/2026-11-02-skia-renderer-migration.md).
//
// Product preview host: a persistent Metal context presents overlays through
// the same Skia renderer used by export, without CPU readback. SwiftUI owns
// selection/drag affordances above this transparent canvas.
//
// Presentation contract:
//
// 1. `SkiaEasyRunRenderer` owns one bridge GPU context built on the view's
//    `MTLDevice` and `MTLCommandQueue`; the context survives resizes.
// 2. Each frame wraps the `CAMetalDrawable` texture as the Skia render target,
//    records the overlay draws, and submits them with `flush(sync: false)`.
// 3. A presentation command buffer is created on the *same* queue after the
//    Skia submission and calls `present(drawable)`. Metal executes command
//    buffers on one queue in submission order, so the drawable is presented
//    only after the Skia work that filled it.
// 4. The layer is transparent and the Skia surface clears to transparent, so a
//    source video layer sits beneath the overlay canvas.

/// One presented preview frame, reported by `SkiaPreviewMetalView`.
struct SkiaPreviewFrameStats: Equatable, Sendable {
    /// Monotonic index starting at 1 for the first presented frame.
    var frameIndex: Int
    /// Pixel size of the drawable that was rendered.
    var drawableSize: CGSize
    /// Time from acquiring the drawable through submitting the present command
    /// buffer. Excludes the `nextDrawable()` wait so it measures host work.
    var cpuMilliseconds: Double
    /// Time since the previous frame started. Zero for the first frame.
    var intervalMilliseconds: Double
}

/// SwiftUI wrapper for the product Skia preview host.
///
/// `canvasSize` is the project pixel resolution (for example 1920x1080 or
/// 3840x2160). The layer draws at exactly that resolution and Core Animation
/// scales it into the view's bounds, so resizing the pane never reallocates the
/// Skia context.
struct SkiaPreviewCanvasView: NSViewRepresentable {
    var layout: OverlayLayout
    var activity: ActivityTimeline
    var elapsedTime: TimeInterval
    var canvasSize: CGSize
    var isPaused: Bool = false
    var onFrame: ((SkiaPreviewFrameStats) -> Void)? = nil

    func makeNSView(context: Context) -> SkiaPreviewMetalView {
        let view = SkiaPreviewMetalView(frame: .zero)
        view.onFrame = onFrame
        view.configure(
            layout: layout,
            activity: activity,
            elapsedTime: elapsedTime,
            canvasSize: canvasSize,
            isPaused: isPaused
        )
        return view
    }

    func updateNSView(_ nsView: SkiaPreviewMetalView, context: Context) {
        nsView.onFrame = onFrame
        nsView.configure(
            layout: layout,
            activity: activity,
            elapsedTime: elapsedTime,
            canvasSize: canvasSize,
            isPaused: isPaused
        )
    }
}

/// `CAMetalLayer`-backed preview host with a persistent Metal context.
///
/// A display link drives frames while the view is in a window and not paused.
/// While paused, `configure` renders one frame so the canvas reflects the
/// current playhead instead of going blank.
@MainActor
final class SkiaPreviewMetalView: NSView {
    let metalLayer = CAMetalLayer()

    private let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private var renderer: SkiaEasyRunRenderer?
    private var rendererSize: CGSize = .zero

    private var overlayLayout: OverlayLayout = .empty
    private var activity: ActivityTimeline?
    private var elapsedTime: TimeInterval = 0
    private var canvasSize = CGSize(width: 1920, height: 1080)
    private var isPaused = true
    private var needsRender = true

    /// Route map snapshots are fetched asynchronously and only ever consumed by
    /// `preloadAssets` outside the frame loop. Replaceable in tests.
    var mapSnapshotProvider: any MapSnapshotProvider & Sendable = MapKitMapSnapshotProvider()
    private var mapSnapshots: [MapSnapshotRequest: NSImage] = [:]
    private var pendingSnapshotRequests: Set<MapSnapshotRequest> = []
    private var failedSnapshotRequests: Set<MapSnapshotRequest> = []

    /// Inputs of the last successful `preloadAssets` call. Draw never rasterizes
    /// AppKit assets; `configure` refreshes them before the next frame.
    private var preloadedLayout: OverlayLayout?
    private var preloadedActivity: ActivityTimeline?
    private var preloadedCanvasSize: CGSize = .zero

    private var frameLink: CADisplayLink?
    private var frameIndex = 0
    private var lastFrameStart: CFTimeInterval?

    /// Number of frames that reached `present(drawable)`. Exposed for tests and
    /// for the demo HUD.
    private(set) var presentedFrameCount = 0

    var onFrame: ((SkiaPreviewFrameStats) -> Void)?

    override init(frame frameRect: NSRect) {
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device?.makeCommandQueue()
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        configureMetalLayer()
    }

    required init?(coder: NSCoder) {
        nil
    }

    // MARK: - Configuration

    func configure(
        layout: OverlayLayout,
        activity: ActivityTimeline,
        elapsedTime: TimeInterval,
        canvasSize: CGSize,
        isPaused: Bool
    ) {
        self.overlayLayout = layout
        self.activity = activity
        self.elapsedTime = elapsedTime
        self.canvasSize = canvasSize
        self.isPaused = isPaused

        if metalLayer.drawableSize != canvasSize {
            metalLayer.drawableSize = canvasSize
        }
        frameLink?.isPaused = isPaused

        // Rasterize route masks / weather icons and register any snapshots we
        // already have before the next frame. Missing snapshots are fetched
        // asynchronously and trigger one redraw when they arrive.
        refreshPreloadedAssetsIfNeeded()
        requestMissingMapSnapshotsIfNeeded()

        needsRender = true
        renderIfPaused()
    }

    // MARK: - View lifecycle

    override func layout() {
        super.layout()
        metalLayer.frame = bounds
        metalLayer.contentsScale = window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
        if metalLayer.drawableSize != canvasSize {
            metalLayer.drawableSize = canvasSize
        }
        renderIfPaused()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            stopDisplayLink()
        }
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        metalLayer.contentsScale = window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
        layout()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            startDisplayLink()
        } else {
            stopDisplayLink()
        }
    }

    // MARK: - Frame rendering

    /// Renders and presents one frame. Returns `nil` when Metal is unavailable,
    /// no drawable can be acquired, or no activity has been configured yet.
    @discardableResult
    func renderFrame() -> SkiaPreviewFrameStats? {
        guard let activity else { return nil }
        guard let drawable = metalLayer.nextDrawable() else { return nil }
        let texture = drawable.texture
        let pixelSize = CGSize(width: texture.width, height: texture.height)
        // `configure`/`layout` keep the layer at project resolution and preload
        // assets for it. Skip a stale drawable rather than rebuilding the
        // renderer (and rasterizing assets) inside the frame callback.
        guard pixelSize == canvasSize else { return nil }
        guard let renderer = renderer(for: pixelSize),
              renderer.wrap(texture: texture) else {
            return nil
        }

        let frameStart = CACurrentMediaTime()
        renderer.draw(layout: overlayLayout, activity: activity, elapsedTime: elapsedTime)
        guard renderer.flush(sync: false) else { return nil }

        guard let commandBuffer = commandQueue?.makeCommandBuffer() else { return nil }
        commandBuffer.present(drawable)
        commandBuffer.commit()

        let frameEnd = CACurrentMediaTime()
        let interval = lastFrameStart.map { (frameStart - $0) * 1000 } ?? 0
        lastFrameStart = frameStart
        frameIndex += 1
        presentedFrameCount += 1

        let stats = SkiaPreviewFrameStats(
            frameIndex: frameIndex,
            drawableSize: pixelSize,
            cpuMilliseconds: (frameEnd - frameStart) * 1000,
            intervalMilliseconds: interval
        )
        onFrame?(stats)
        return stats
    }

    /// Blocks until the Skia context has submitted all pending GPU work. Used by
    /// pacing tests so the measured total includes GPU time.
    func waitForGPU() {
        renderer?.flush(sync: true)
    }

    /// Test hook: renders the current frame into an arbitrary texture so tests
    /// can read pixels back. Uses the same renderer, layout, activity, and
    /// elapsed time as the drawable path.
    @discardableResult
    func renderIntoTexture(_ texture: MTLTexture) -> Bool {
        guard let activity else { return false }
        // Keep asset rasterization on the caller's (non-frame) path.
        refreshPreloadedAssetsIfNeeded()
        let size = CGSize(width: texture.width, height: texture.height)
        guard let renderer = renderer(for: size),
              renderer.wrap(texture: texture) else {
            return false
        }
        renderer.draw(layout: overlayLayout, activity: activity, elapsedTime: elapsedTime)
        return renderer.flush(sync: true)
    }

    // MARK: - Assets

    /// Preloads route masks, weather icons, and any available map snapshots.
    /// Runs from `configure` and snapshot completion, never from the display
    /// link callback.
    private func refreshPreloadedAssetsIfNeeded(force: Bool = false) {
        guard let activity else { return }
        if !force,
           preloadedCanvasSize == canvasSize,
           preloadedLayout == overlayLayout,
           preloadedActivity == activity {
            return
        }
        guard let renderer = renderer(for: canvasSize) else { return }
        renderer.preloadAssets(
            layout: overlayLayout,
            activity: activity,
            mapSnapshots: mapSnapshots
        )
        preloadedLayout = overlayLayout
        preloadedActivity = activity
        preloadedCanvasSize = canvasSize
    }

    /// Requests map snapshots for visible route maps that do not have one yet.
    /// Requests are deduplicated while in flight and not retried after failure
    /// until the route geometry or style changes the request key.
    private func requestMissingMapSnapshotsIfNeeded() {
        guard let activity else { return }
        let renderContext = OverlayRenderContext(
            canvasSize: canvasSize,
            activity: activity,
            elapsedTime: 0
        )
        for element in overlayLayout.elements where element.isVisible && element.type == .routeMap {
            let layout = OverlayRenderModel.routeMapLayout(for: element, in: renderContext)
            guard let request = RouteMapSnapshotRequestBuilder.request(
                for: element,
                layout: layout
            ) else { continue }
            guard mapSnapshots[request] == nil,
                  !pendingSnapshotRequests.contains(request),
                  !failedSnapshotRequests.contains(request) else { continue }

            pendingSnapshotRequests.insert(request)
            let provider = mapSnapshotProvider
            Task { @MainActor [weak self] in
                let image = await MapSnapshotCache.shared.image(
                    for: request,
                    provider: provider
                )
                self?.finishMapSnapshotRequest(request, image: image)
            }
        }
    }

    private func finishMapSnapshotRequest(
        _ request: MapSnapshotRequest,
        image: NSImage?
    ) {
        pendingSnapshotRequests.remove(request)
        guard let image else {
            failedSnapshotRequests.insert(request)
            return
        }
        mapSnapshots[request] = image
        refreshPreloadedAssetsIfNeeded(force: true)
        needsRender = true
        if isPaused {
            renderIfPaused()
        } else if frameLink == nil {
            // No display link (for example an off-window test host): still
            // present one frame so the new snapshot is visible.
            if renderFrame() != nil {
                needsRender = false
            }
        }
    }

    // MARK: - Display link

    private func startDisplayLink() {
        guard frameLink == nil else {
            frameLink?.isPaused = isPaused
            return
        }
        let link = displayLink(target: self, selector: #selector(displayLinkFired(_:)))
        link.add(to: .main, forMode: .common)
        link.isPaused = isPaused
        frameLink = link
    }

    private func stopDisplayLink() {
        frameLink?.invalidate()
        frameLink = nil
    }

    @objc private func displayLinkFired(_ link: CADisplayLink) {
        guard !isPaused else { return }
        needsRender = false
        renderFrame()
    }

    // MARK: - Helpers

    private func configureMetalLayer() {
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        // Skia only writes to the drawable, but keep it sampleable for future
        // effects and for parity with the export path.
        metalLayer.framebufferOnly = false
        metalLayer.isOpaque = false
        metalLayer.backgroundColor = nil
        metalLayer.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        metalLayer.drawableSize = canvasSize
        layer?.addSublayer(metalLayer)
    }

    /// Rebuilds the renderer only when the drawable pixel size changes. The
    /// device and command queue stay alive for the lifetime of the view.
    private func renderer(for size: CGSize) -> SkiaEasyRunRenderer? {
        if let renderer, rendererSize == size {
            return renderer
        }
        guard let device, let commandQueue else { return nil }
        // Pixel-size changes are rare (only a project-resolution switch). Drain
        // the old context before releasing it so no drawable is destroyed while
        // its GPU work is still in flight.
        renderer?.flush(sync: true)
        guard let newRenderer = SkiaEasyRunRenderer(
            size: size,
            device: device,
            commandQueue: commandQueue,
            offscreen: false
        ) else {
            return nil
        }
        renderer = newRenderer
        rendererSize = size
        return newRenderer
    }

    /// Renders a single frame when paused and data changed. The display link is
    /// paused in that state, so this is the only path that updates the canvas.
    private func renderIfPaused() {
        guard needsRender, isPaused else { return }
        // Keep the pending flag when the drawable is temporarily unavailable so
        // the next layout/configure pass retries instead of stranding a stale
        // frame on screen.
        if renderFrame() != nil {
            needsRender = false
        }
    }
}

#if DEBUG
// MARK: - Isolated demo path

/// Debug-only demo that hosts the Easy Run template in the Skia preview canvas.
/// Not referenced by the shipping editor; open it from the Xcode preview canvas
/// or a temporary debug entry point.
struct SkiaPreviewDemoView: View {
    @State private var resolution: SkiaPreviewResolution = .hd1080
    @State private var isPlaying = true
    @State private var elapsed: TimeInterval = 0
    @State private var lastTick = Date()

    private let layout = SkiaPreviewDemoData.easyRunLayout
    private let activity = SkiaPreviewDemoData.activity
    private let timer = Timer.publish(
        every: 1.0 / 30.0,
        on: .main,
        in: .common
    ).autoconnect()

    var body: some View {
        VStack(spacing: 12) {
            SkiaPreviewCanvasView(
                layout: layout,
                activity: activity,
                elapsedTime: elapsed,
                canvasSize: resolution.size,
                isPaused: !isPlaying
            )
            .aspectRatio(resolution.size.width / resolution.size.height, contentMode: .fit)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 16) {
                Picker("Resolution", selection: $resolution) {
                    ForEach(SkiaPreviewResolution.allCases) { resolution in
                        Text(resolution.rawValue).tag(resolution)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Button(isPlaying ? "Pause" : "Play") {
                    isPlaying.toggle()
                    lastTick = Date()
                }

                Text(String(format: "%.1f s", elapsed))
                    .monospacedDigit()

                Spacer()
            }
        }
        .padding()
        .frame(minWidth: 640, minHeight: 420)
        .onReceive(timer) { now in
            guard isPlaying else {
                lastTick = now
                return
            }
            elapsed += now.timeIntervalSince(lastTick)
            lastTick = now
            if elapsed >= activity.duration {
                elapsed = 0
            }
        }
    }
}

enum SkiaPreviewResolution: String, CaseIterable, Identifiable {
    case hd1080 = "1080p"
    case uhd4K = "4K"

    var id: String { rawValue }

    var size: CGSize {
        switch self {
        case .hd1080: CGSize(width: 1920, height: 1080)
        case .uhd4K: CGSize(width: 3840, height: 2160)
        }
    }
}

private enum SkiaPreviewDemoData {
    static let easyRunLayout: OverlayLayout = {
        guard let url = Bundle.runningOverlayResources.url(
            forResource: "EasyRun",
            withExtension: "rotemplate",
            subdirectory: "Templates"
        ) ?? Bundle.runningOverlayResources.url(
            forResource: "EasyRun",
            withExtension: "rotemplate"
        ),
              let data = try? Data(contentsOf: url),
              let template = try? JSONDecoder().decode(OverlayTemplate.self, from: data)
        else {
            return .empty
        }

        var layout = template.layout
        layout.elements = layout.elements.filter(SkiaEasyRunRenderer.supports)
        // MapKit snapshots require the network; the Skia spike draws the local
        // grid when the map background is off.
        for index in layout.elements.indices where layout.elements[index].type == .routeMap {
            layout.elements[index].style.routeMapBackgroundStyle = .none
        }
        return layout
    }()

    static let activity: ActivityTimeline = {
        let start = Date(timeIntervalSince1970: 1_735_689_600)
        let duration: TimeInterval = 1800
        let records = stride(from: 0.0, through: duration, by: 1).map { t in
            ActivityRecord(
                elapsedTime: t,
                timestamp: start.addingTimeInterval(t),
                distanceMeters: t * 3.1,
                heartRate: 135 + Int(12 * sin(t / 240)),
                paceSecondsPerKilometer: 320 - 20 * sin(t / 300),
                elevationMeters: 30 + 18 * sin(t / 420),
                cadence: 174 + Int(6 * sin(t / 180)),
                powerWatts: 240 + Int(25 * sin(t / 200)),
                calories: t / 3.6,
                latitude: 40.75 + 0.006 * sin(t / 500),
                longitude: -73.99 + 0.008 * cos(t / 500)
            )
        }
        return ActivityTimeline(
            startDate: start,
            duration: duration,
            distanceMeters: 5580,
            records: records,
            laps: []
        )
    }()
}

#Preview("Skia Preview Demo") {
    SkiaPreviewDemoView()
}
#endif
#endif
