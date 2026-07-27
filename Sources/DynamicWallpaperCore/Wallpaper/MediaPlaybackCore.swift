import Foundation
import AVFoundation

/// Core media player encapsulating AVPlayer streaming playback with automatic looping, volume control, audio ducking, and resource cleanup.
public final class MediaPlaybackCore: @unchecked Sendable {
    public private(set) var player: AVPlayer
    private var playerItemObserver: NSKeyValueObservation?
    private var loopObserver: NSObjectProtocol?

    public private(set) var currentURL: URL?
    public private(set) var userVolume: Float = 1.0
    public private(set) var isDucked: Bool = false

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
        applyActualVolume()
        AppLogger.shared.info("MediaPlaybackCore: Loaded video asset from \(url.path)")
    }

    public func play() {
        player.play()
        AppLogger.shared.debug("MediaPlaybackCore: Playback rate set to 1.0 for \(currentURL?.lastPathComponent ?? "unknown")")
    }

    public func pause() {
        player.pause()
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
        self.userVolume = max(0.0, min(1.0, volume))
        applyActualVolume()
        AppLogger.shared.debug("MediaPlaybackCore: User volume set to \(self.userVolume)")
    }

    public func setDucked(_ ducked: Bool) {
        self.isDucked = ducked
        applyActualVolume()
        AppLogger.shared.info("MediaPlaybackCore: Audio ducking set to \(ducked) (Volume = \(player.volume))")
    }

    public func setMuted(_ isMuted: Bool) {
        player.isMuted = isMuted
    }

    private func applyActualVolume() {
        // Duck volume down to 5% (0.05) when other audio apps are active
        let actualVolume = isDucked ? (userVolume * 0.05) : userVolume
        player.volume = actualVolume
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
