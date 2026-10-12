import AVFoundation
import SwiftUI

struct VideoPreviewPlayerView: NSViewRepresentable {
    var previewMedia: PreviewMedia?
    var isPlaying: Bool
    var playbackRate: Double = 1
    var seekToken: UInt64 = 0
    var fitMode: PreviewFitMode = .fit
    var onPlaybackActivityTime: (TimeInterval) -> Void

    func makeNSView(context: Context) -> VideoPreviewNSView {
        VideoPreviewNSView()
    }

    func updateNSView(_ nsView: VideoPreviewNSView, context: Context) {
        nsView.update(
            previewMedia: previewMedia,
            isPlaying: isPlaying,
            playbackRate: playbackRate,
            seekToken: seekToken,
            fitMode: fitMode,
            onPlaybackActivityTime: onPlaybackActivityTime
        )
    }
}

@MainActor
final class VideoPreviewNSView: NSView {
    private let player = AVPlayer()
    private let playerLayer = AVPlayerLayer()
    private var currentURL: URL?
    private var currentClipID: TimelineClip.ID?
    private var lastPausedSeekTarget: TimeInterval = -1
    private var currentClipStartTime: TimeInterval = 0
    private var currentSeekToken: UInt64 = 0
    private var seekGeneration: UInt64 = 0
    private var isSeeking = false
    private var timeObserver: Any?
    private var onPlaybackActivityTime: ((TimeInterval) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.clear.cgColor
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect
        layer?.addSublayer(playerLayer)
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, !self.isSeeking, self.player.timeControlStatus == .playing else {
                    return
                }
                let observedTime = time.seconds
                let currentTime = self.player.currentTime().seconds
                guard observedTime.isFinite, currentTime.isFinite,
                      abs(currentTime - observedTime) <= 0.5 else { return }
                self.onPlaybackActivityTime?(self.currentClipStartTime + observedTime)
            }
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            removeTimeObserver()
        }
    }

    func update(
        previewMedia: PreviewMedia?,
        isPlaying: Bool,
        playbackRate: Double,
        seekToken: UInt64,
        fitMode: PreviewFitMode,
        onPlaybackActivityTime: @escaping (TimeInterval) -> Void
    ) {
        self.onPlaybackActivityTime = onPlaybackActivityTime
        let timelineSeekRequested = seekToken != currentSeekToken
        currentSeekToken = seekToken
        let desiredGravity: AVLayerVideoGravity = fitMode == .fill ? .resizeAspectFill : .resizeAspect
        if playerLayer.videoGravity != desiredGravity {
            playerLayer.videoGravity = desiredGravity
        }

        guard let previewMedia else {
            currentURL = nil
            currentClipID = nil
            currentClipStartTime = 0
            lastPausedSeekTarget = -1
            seekGeneration &+= 1
            isSeeking = false
            player.pause()
            player.replaceCurrentItem(with: nil)
            return
        }

        let targetTime = max(previewMedia.sourceTime, 0)
        let clipChanged = currentURL != previewMedia.url || currentClipID != previewMedia.clipID
        currentClipStartTime = previewMedia.clipStartTime

        if currentURL != previewMedia.url || currentClipID != previewMedia.clipID {
            currentURL = previewMedia.url
            currentClipID = previewMedia.clipID
            lastPausedSeekTarget = -1
            player.replaceCurrentItem(with: AVPlayerItem(url: previewMedia.url))
            seek(to: targetTime)
        }

        if isPlaying {
            let drift = abs(player.currentTime().seconds - targetTime)
            if timelineSeekRequested && !clipChanged {
                seek(to: targetTime)
            } else if previewMedia.syncsToSourceTime && !clipChanged && !isSeeking && drift > 0.35 {
                seek(to: targetTime)
            }
            let rate = Float(max(playbackRate, 1))
            player.rate = rate
        } else {
            if clipChanged || abs(targetTime - lastPausedSeekTarget) > 0.02 {
                seek(to: targetTime)
                lastPausedSeekTarget = targetTime
            }
            player.pause()
        }
    }

    private func seek(to seconds: TimeInterval) {
        seekGeneration &+= 1
        let generation = seekGeneration
        isSeeking = true
        player.seek(
            to: CMTime(seconds: seconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.seekGeneration == generation else { return }
                self.isSeeking = false
            }
        }
    }

    private func removeTimeObserver() {
        guard let timeObserver else {
            return
        }
        player.removeTimeObserver(timeObserver)
        self.timeObserver = nil
    }
}
