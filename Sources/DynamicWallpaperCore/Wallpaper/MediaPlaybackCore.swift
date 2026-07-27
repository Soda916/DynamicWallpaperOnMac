import Foundation
import AVFoundation

/// Core media player encapsulating AVPlayer streaming playback with automatic looping, volume control, and resource cleanup.
public final class MediaPlaybackCore: @unchecked Sendable {
    public private(set) var player: AVPlayer
    private var playerItemObserver: NSKeyValueObservation?
    private var loopObserver: NSObjectProtocol?

    public private(set) var currentURL: URL?
    public var isPlaying: Bool {
        return player.timeControlStatus == .playing || player.rate > 0
    }

    public init() {
        self.player = AVPlayer()
        self.player.actionAtItemEnd = .none
    }

    deinit {
        stop()
    }

    /// Load and stream video from a file URL without reading entire video into RAM.
    public func loadVideo(url: URL) {
        stop()

        self.currentURL = url
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: false])
        let item = AVPlayerItem(asset: asset)

        player.replaceCurrentItem(with: item)
        setupLooping(for: item)
        AppLogger.shared.info("MediaPlaybackCore: Loaded video asset from \(url.path)")
    }

    public func play() {
        player.rate = 1.0
        player.play()
        AppLogger.shared.debug("MediaPlaybackCore: Playback rate set to 1.0 for \(currentURL?.lastPathComponent ?? "unknown")")
    }

    public func pause() {
        player.pause()
        player.rate = 0.0
        AppLogger.shared.debug("MediaPlaybackCore: Playback paused")
    }

    public func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)

        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
        playerItemObserver?.invalidate()
        playerItemObserver = nil

        AppLogger.shared.debug("MediaPlaybackCore: Stopped and resources released")
    }

    public func setVolume(_ volume: Float) {
        player.volume = max(0.0, min(1.0, volume))
    }

    public func setMuted(_ isMuted: Bool) {
        player.isMuted = isMuted
    }

    private func setupLooping(for item: AVPlayerItem) {
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.player.seek(to: .zero) { _ in
                self?.player.play()
                self?.player.rate = 1.0
            }
        }
    }
}
