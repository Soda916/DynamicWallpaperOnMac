import AppKit
import AVFoundation

/// Central manager orchestrating media playback, display window layers, package imports, and auto-pause triggers.
public final class WallpaperController: @unchecked Sendable {
    public static let shared = WallpaperController()

    public let playbackCore = MediaPlaybackCore()
    public let displayManager = DisplayManager.shared
    public let autoPauseEngine = AutoPauseEngine.shared

    public private(set) var activeWallpaperURL: URL?
    public var onWallpaperChanged: ((URL?) -> Void)?

    private init() {
        setupAutoPauseIntegration()
    }

    private func setupAutoPauseIntegration() {
        autoPauseEngine.onPauseStateChanged = { [weak self] isPaused in
            guard let self = self else { return }
            if isPaused {
                AppLogger.shared.info("WallpaperController: Auto-pausing desktop playback")
                self.playbackCore.pause()
            } else if self.activeWallpaperURL != nil {
                AppLogger.shared.info("WallpaperController: Resuming desktop playback")
                self.playbackCore.play()
            }
        }
        autoPauseEngine.startMonitoring()
    }

    /// Selects and applies a wallpaper video or GIF to all connected desktop windows.
    public func importAndApplyWallpaper(from url: URL, completion: ((Result<URL, Error>) -> Void)? = nil) {
        AppLogger.shared.info("WallpaperController: Importing wallpaper from \(url.path)")

        let fileExtension = url.pathExtension.lowercased()
        if fileExtension == "gif" {
            // Handle GIF conversion to HEVC cache
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let cacheDir = appSupport.appendingPathComponent("DynamicWallpaperEngine/Cache", isDirectory: true)
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            let cacheVideoURL = cacheDir.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent)_cache.mp4")

            WallpaperPackageImporter.shared.convertGIFToHEVCVideo(gifURL: url, outputVideoURL: cacheVideoURL) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let convertedVideoURL):
                        self?.applyVideo(url: convertedVideoURL)
                        completion?(.success(convertedVideoURL))
                    case .failure(let error):
                        AppLogger.shared.error("WallpaperController: Failed to convert GIF: \(error.localizedDescription)")
                        completion?(.failure(error))
                    }
                }
            }
        } else {
            // Native video formats (MP4, MOV, WEBM)
            applyVideo(url: url)
            completion?(.success(url))
        }
    }

    private func applyVideo(url: URL) {
        self.activeWallpaperURL = url
        playbackCore.loadVideo(url: url)
        displayManager.updateScreens(with: playbackCore.player)
        playbackCore.play()
        onWallpaperChanged?(url)
        AppLogger.shared.info("WallpaperController: Successfully applied wallpaper to all screens")
    }

    public func setVolume(_ volume: Float) {
        playbackCore.setVolume(volume)
    }

    public func setMuted(_ isMuted: Bool) {
        playbackCore.setMuted(isMuted)
    }

    public func togglePlayPause() {
        if playbackCore.isPlaying {
            playbackCore.pause()
        } else {
            playbackCore.play()
        }
    }
}
