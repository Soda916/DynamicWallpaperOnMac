import AppKit
import AVFoundation

public extension Notification.Name {
    static let wallpaperMuteStateDidChange = Notification.Name("wallpaperMuteStateDidChange")
    static let wallpaperPlayPauseStateDidChange = Notification.Name("wallpaperPlayPauseStateDidChange")
    static let wallpaperAutoPauseConfigDidChange = Notification.Name("wallpaperAutoPauseConfigDidChange")
    static let wallpaperVolumeDidChange = Notification.Name("wallpaperVolumeDidChange")
    static let wallpaperAudioDuckingDidChange = Notification.Name("wallpaperAudioDuckingDidChange")
}

public final class WallpaperController: @unchecked Sendable {
    public static let shared = WallpaperController()

    public let playbackCore = MediaPlaybackCore()
    public let displayManager = DisplayManager.shared
    public let autoPauseEngine = AutoPauseEngine.shared

    public private(set) var activeWallpaperURL: URL?
    public var onWallpaperChanged: ((URL?) -> Void)?

    private var autoPauseObserver: NSObjectProtocol?

    private init() {
        setupAutoPauseIntegration()
    }

    private func setupAutoPauseIntegration() {
        autoPauseObserver = NotificationCenter.default.addObserver(
            forName: .autoPausePauseStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let self = self else { return }
            guard let isPaused = notif.object as? Bool else { return }
            if isPaused {
                AppLogger.shared.info("WallpaperController: Auto-pausing desktop playback")
                self.playbackCore.pause()
                NotificationCenter.default.post(name: .wallpaperPlayPauseStateDidChange, object: false)
            } else if self.activeWallpaperURL != nil {
                AppLogger.shared.info("WallpaperController: Resuming desktop playback")
                self.playbackCore.play()
                NotificationCenter.default.post(name: .wallpaperPlayPauseStateDidChange, object: true)
            }
        }
        autoPauseEngine.startMonitoring()
    }

    public func importAndApplyWallpaper(from url: URL, completion: ((Result<URL, Error>) -> Void)? = nil) {
        AppLogger.shared.info("[CHATTER] WallpaperController: Received user request to import wallpaper: \(url.path)")

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            let err = NSError(domain: "WallpaperController", code: 404, userInfo: [NSLocalizedDescriptionKey: "File does not exist at path: \(url.path)"])
            AppLogger.shared.error("[CHATTER] Target wallpaper file is missing at \(url.path)")
            completion?(.failure(err))
            return
        }

        if let attrs = try? fileManager.attributesOfItem(atPath: url.path), let fileSize = attrs[.size] as? Int64 {
            AppLogger.shared.info("[CHATTER] Verified file size: \(fileSize) bytes for \(url.lastPathComponent)")
        }

        let fileExtension = url.pathExtension.lowercased()
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let cacheDir = appSupport.appendingPathComponent("DynamicWallpaperEngine/Cache", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        if fileExtension == "gif" {
            AppLogger.shared.info("[CHATTER] Input is a GIF image. Starting hardware GIF -> HEVC converter...")
            let cacheVideoURL = cacheDir.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent)_gif_cache.mp4")

            WallpaperPackageImporter.shared.convertGIFToHEVCVideo(gifURL: url, outputVideoURL: cacheVideoURL) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let convertedVideoURL):
                        self?.applyVideo(url: convertedVideoURL)
                        completion?(.success(convertedVideoURL))
                    case .failure(let error):
                        AppLogger.shared.error("[CHATTER] Failed to convert GIF: \(error.localizedDescription)")
                        completion?(.failure(error))
                    }
                }
            }
        } else {
            AppLogger.shared.info("[CHATTER] Inspecting video codec subtype via AVFoundation for \(url.lastPathComponent)...")
            WallpaperPackageImporter.shared.inspectVideoCodec(url: url) { [weak self] isSupported, codecSubType in
                DispatchQueue.main.async {
                    if isSupported {
                        AppLogger.shared.info("[CHATTER] Codec '\(codecSubType)' is supported natively by VideoToolbox. Applying video directly!")
                        self?.applyVideo(url: url)
                        completion?(.success(url))
                    } else {
                        AppLogger.shared.info("[CHATTER] Codec '\(codecSubType)' (e.g. AV1/VP9) is NOT supported natively by AVPlayer. Auto-transcoding to HEVC cache...")
                        let cacheVideoURL = cacheDir.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent)_hevc_cache.mp4")
                        
                        WallpaperPackageImporter.shared.transcodeVideoToHEVC(inputURL: url, outputVideoURL: cacheVideoURL) { transcodeResult in
                            DispatchQueue.main.async {
                                switch transcodeResult {
                                case .success(let convertedVideoURL):
                                    AppLogger.shared.info("[CHATTER] Transcoding successful! Applying converted HEVC wallpaper...")
                                    self?.applyVideo(url: convertedVideoURL)
                                    completion?(.success(convertedVideoURL))
                                case .failure(let error):
                                    AppLogger.shared.error("[CHATTER] Transcoding failed: \(error.localizedDescription)")
                                    completion?(.failure(error))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func applyVideo(url: URL) {
        self.activeWallpaperURL = url
        playbackCore.loadVideo(url: url)
        displayManager.updateScreens(with: playbackCore.player)
        playbackCore.play()
        onWallpaperChanged?(url)
        NotificationCenter.default.post(name: .wallpaperPlayPauseStateDidChange, object: true)
        AppLogger.shared.info("[CHATTER] Successfully attached player to desktop layer. Active URL: \(url.path)")
    }

    public func setVolume(_ volume: Float) {
        playbackCore.setVolume(volume)
        NotificationCenter.default.post(name: .wallpaperVolumeDidChange, object: volume)
        AppLogger.shared.debug("[CHATTER] Volume changed to \(volume)")
    }

    public func setAudioDucked(_ isDucked: Bool) {
        playbackCore.setDucked(isDucked)
        NotificationCenter.default.post(name: .wallpaperAudioDuckingDidChange, object: isDucked)
        AppLogger.shared.info("[CHATTER] Audio ducking state changed to \(isDucked)")
    }

    public func setMuted(_ isMuted: Bool) {
        playbackCore.setMuted(isMuted)
        NotificationCenter.default.post(name: .wallpaperMuteStateDidChange, object: isMuted)
        AppLogger.shared.debug("[CHATTER] Mute changed to \(isMuted)")
    }

    public func setAutoPauseEnabled(_ isEnabled: Bool) {
        autoPauseEngine.isEnabled = isEnabled
        NotificationCenter.default.post(name: .wallpaperAutoPauseConfigDidChange, object: isEnabled)
        AppLogger.shared.info("[CHATTER] AutoPause configuration changed to \(isEnabled)")
    }

    public func togglePlayPause() {
        if playbackCore.isPlaying {
            playbackCore.pause()
            NotificationCenter.default.post(name: .wallpaperPlayPauseStateDidChange, object: false)
            AppLogger.shared.info("[CHATTER] User toggled playback to PAUSE")
        } else {
            playbackCore.play()
            NotificationCenter.default.post(name: .wallpaperPlayPauseStateDidChange, object: true)
            AppLogger.shared.info("[CHATTER] User toggled playback to PLAY")
        }
    }
}
