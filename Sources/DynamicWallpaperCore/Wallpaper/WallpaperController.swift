import AppKit
import AVFoundation

public extension Notification.Name {
    static let wallpaperMuteStateDidChange = Notification.Name("wallpaperMuteStateDidChange")
    static let wallpaperPlayPauseStateDidChange = Notification.Name("wallpaperPlayPauseStateDidChange")
    static let wallpaperAutoPauseConfigDidChange = Notification.Name("wallpaperAutoPauseConfigDidChange")
    static let wallpaperVolumeDidChange = Notification.Name("wallpaperVolumeDidChange")
    static let wallpaperAudioDuckingDidChange = Notification.Name("wallpaperAudioDuckingDidChange")
    static let wallpaperPlaylistDidChange = Notification.Name("wallpaperPlaylistDidChange")
    static let wallpaperPlaybackModeDidChange = Notification.Name("wallpaperPlaybackModeDidChange")
}

public final class WallpaperController: @unchecked Sendable {
    public static let shared = WallpaperController()

    public let playbackCore = MediaPlaybackCore()
    public let displayManager = DisplayManager.shared
    public let autoPauseEngine = AutoPauseEngine.shared

    public private(set) var activeWallpaperURL: URL?
    public var onWallpaperChanged: ((URL?) -> Void)?
    public private(set) var isManuallyPaused = false

    public private(set) var playlist: [URL] = []
    public private(set) var currentIndex: Int = 0
    public private(set) var playbackMode: PlaybackMode = .single

    private var autoPauseObserver: NSObjectProtocol?

    private init() {
        setupAutoPauseIntegration()
        setupPlaybackEndHook()
        setupSleepWakeObservers()
    }

    private func setupSleepWakeObservers() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            AppLogger.shared.info("[SYSTEM-SLEEP] Mac going to sleep. Pausing desktop playback...")
            self?.playbackCore.pause()
            NotificationCenter.default.post(name: .wallpaperPlayPauseStateDidChange, object: false)
        }

        center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            AppLogger.shared.info("[SYSTEM-WAKE] Mac woke from sleep. Waiting 3.0s for graphics/display stabilization...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                guard let self = self else { return }
                AppLogger.shared.info("[SYSTEM-WAKE] Re-evaluating screen topology & auto-pause state after wake delay...")
                self.displayManager.updateScreens(with: self.playbackCore.player)
                self.autoPauseEngine.evaluateAutoPauseConditions()
                if !self.isManuallyPaused && (!self.autoPauseEngine.isEnabled || !self.autoPauseEngine.isPaused) {
                    if self.activeWallpaperURL != nil {
                        self.playbackCore.play()
                        NotificationCenter.default.post(name: .wallpaperPlayPauseStateDidChange, object: true)
                    }
                }
            }
        }
    }

    private func setupAutoPauseIntegration() {
        autoPauseObserver = NotificationCenter.default.addObserver(
            forName: .autoPausePauseStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let self = self else { return }
            guard let isPaused = notif.object as? Bool else { return }
            
            // If the user has manually paused, do NOT let auto-pause auto-resume it!
            if self.isManuallyPaused {
                AppLogger.shared.info("WallpaperController: User has manually paused, ignoring Auto-Pause state change notification (isPaused=\(isPaused))")
                return
            }
            
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

        NotificationCenter.default.addObserver(
            forName: .lowPowerTierDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let self = self else { return }
            guard let tier = notif.object as? LowPowerTier else { return }
            AppLogger.shared.info("[WALLPAPER-CONTROLLER] Applying Low Power Tier settings: \(tier)")
            
            switch tier {
            case .tier1_reducedQuality, .tier2_stopDecoding, .tier3_zeroEnergy:
                self.displayManager.windowControllers.values.forEach { $0.setHDREnabled(false) }
            case .none:
                self.displayManager.windowControllers.values.forEach { $0.setHDREnabled(true) }
            }
        }

        autoPauseEngine.startMonitoring()
    }

    private func setupPlaybackEndHook() {
        playbackCore.onItemDidEnd = { [weak self] in
            guard let self = self else { return }
            AppLogger.shared.info("[PLAYLIST] Current item ended under playbackMode '\(self.playbackMode.rawValue)'")
            switch self.playbackMode {
            case .single:
                self.playbackCore.player.seek(to: .zero) { _ in
                    self.playbackCore.play()
                }
            case .sequential:
                self.playNext()
            case .random:
                self.playRandom()
            }
        }
    }

    public func setPlaybackMode(_ mode: PlaybackMode) {
        self.playbackMode = mode
        AppLogger.shared.info("[PLAYLIST] Playback mode changed to \(mode.rawValue)")
        NotificationCenter.default.post(name: .wallpaperPlaybackModeDidChange, object: mode)
    }

    public func setPlaylist(_ urls: [URL], currentIndex: Int = 0) {
        self.playlist = urls
        if !urls.isEmpty {
            self.currentIndex = max(0, min(currentIndex, urls.count - 1))
        } else {
            self.currentIndex = 0
        }
        NotificationCenter.default.post(name: .wallpaperPlaylistDidChange, object: self.playlist)
        AppLogger.shared.info("[PLAYLIST] Playlist set with \(urls.count) item(s)")
    }

    public func addToPlaylist(_ urls: [URL]) {
        for url in urls {
            let resolvedPath = url.resolvingSymlinksInPath().standardized.path
            if !playlist.contains(where: { $0.resolvingSymlinksInPath().standardized.path == resolvedPath }) {
                playlist.append(url)
            }
        }
        AppLogger.shared.info("[PLAYLIST] Added \(urls.count) items to playlist (Total: \(playlist.count))")
        NotificationCenter.default.post(name: .wallpaperPlaylistDidChange, object: self.playlist)
    }

    public func removeFromPlaylist(at index: Int) {
        guard playlist.indices.contains(index) else { return }
        let removedURL = playlist.remove(at: index)
        AppLogger.shared.info("[PLAYLIST] Removed item at index \(index): \(removedURL.lastPathComponent)")
        if currentIndex >= playlist.count {
            currentIndex = max(0, playlist.count - 1)
        }
        NotificationCenter.default.post(name: .wallpaperPlaylistDidChange, object: self.playlist)
    }

    public func clearPlaylist() {
        playlist.removeAll()
        currentIndex = 0
        NotificationCenter.default.post(name: .wallpaperPlaylistDidChange, object: self.playlist)
        AppLogger.shared.info("[PLAYLIST] Playlist cleared")
    }

    public func playNext() {
        guard !playlist.isEmpty else { return }
        currentIndex = (currentIndex + 1) % playlist.count
        let targetURL = playlist[currentIndex]
        AppLogger.shared.info("[PLAYLIST] Advancing to next track [\(currentIndex + 1)/\(playlist.count)]: \(targetURL.lastPathComponent)")
        importAndApplyWallpaper(from: targetURL)
    }

    public func playPrevious() {
        guard !playlist.isEmpty else { return }
        currentIndex = (currentIndex - 1 + playlist.count) % playlist.count
        let targetURL = playlist[currentIndex]
        AppLogger.shared.info("[PLAYLIST] Moving to previous track [\(currentIndex + 1)/\(playlist.count)]: \(targetURL.lastPathComponent)")
        importAndApplyWallpaper(from: targetURL)
    }

    public func playRandom() {
        guard !playlist.isEmpty else { return }
        if playlist.count == 1 {
            currentIndex = 0
        } else {
            var randomIndex = Int.random(in: 0..<playlist.count)
            if randomIndex == currentIndex {
                randomIndex = (randomIndex + 1) % playlist.count
            }
            currentIndex = randomIndex
        }
        let targetURL = playlist[currentIndex]
        AppLogger.shared.info("[PLAYLIST] Randomly selected track [\(currentIndex + 1)/\(playlist.count)]: \(targetURL.lastPathComponent)")
        importAndApplyWallpaper(from: targetURL)
    }

    public func playIndex(_ index: Int) {
        guard playlist.indices.contains(index) else { return }
        currentIndex = index
        let targetURL = playlist[index]
        AppLogger.shared.info("[PLAYLIST] Playing specific track index [\(index + 1)/\(playlist.count)]: \(targetURL.lastPathComponent)")
        importAndApplyWallpaper(from: targetURL)
    }

    public func importAndApplyWallpaper(from url: URL, storageMode: MediaStorageMode = .symlink, completion: ((Result<URL, Error>) -> Void)? = nil) {
        AppLogger.shared.info("[CHATTER] WallpaperController: Received user request to import wallpaper: \(url.path) [StorageMode: \(storageMode.rawValue)]")

        // Centralize media storage under ~/.dynamicwallpaper/media/
        let effectiveURL: URL
        switch MediaStorageManager.shared.processImportedMedia(from: url, mode: storageMode) {
        case .success(let targetURL):
            effectiveURL = targetURL
        case .failure(let error):
            AppLogger.shared.error("[CHATTER] Media centralization failed: \(error.localizedDescription), using original path.")
            effectiveURL = url
        }

        let effectiveResolvedPath = effectiveURL.resolvingSymlinksInPath().standardized.path
        let sourceResolvedPath = url.resolvingSymlinksInPath().standardized.path

        // Check if item already exists in playlist by resolved path or filename
        if let existingIdx = playlist.firstIndex(where: {
            let itemResolvedPath = $0.resolvingSymlinksInPath().standardized.path
            return itemResolvedPath == effectiveResolvedPath || itemResolvedPath == sourceResolvedPath || $0.lastPathComponent == effectiveURL.lastPathComponent
        }) {
            // Update playlist entry to use normalized effectiveURL and jump to existing index
            playlist[existingIdx] = effectiveURL
            currentIndex = existingIdx
            NotificationCenter.default.post(name: .wallpaperPlaylistDidChange, object: self.playlist)
        } else {
            playlist.append(effectiveURL)
            currentIndex = playlist.count - 1
            NotificationCenter.default.post(name: .wallpaperPlaylistDidChange, object: self.playlist)
        }

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: effectiveURL.path) else {
            let err = NSError(domain: "WallpaperController", code: 404, userInfo: [NSLocalizedDescriptionKey: "File does not exist at path: \(effectiveURL.path)"])
            AppLogger.shared.error("[CHATTER] Target wallpaper file is missing at \(effectiveURL.path)")
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
        self.isManuallyPaused = false
        playbackCore.loadVideo(url: url)
        displayManager.updateScreens(with: playbackCore.player)

        // Evaluate AutoPause BEFORE starting playback to prevent playing under existing fullscreen/maximized windows
        autoPauseEngine.evaluateAutoPauseConditions()
        if autoPauseEngine.isEnabled && autoPauseEngine.isPaused {
            AppLogger.shared.info("[CHATTER] AutoPause is active at video load time. Pausing playback immediately.")
            playbackCore.pause()
            onWallpaperChanged?(url)
            NotificationCenter.default.post(name: .wallpaperPlayPauseStateDidChange, object: false)
        } else {
            playbackCore.play()
            onWallpaperChanged?(url)
            NotificationCenter.default.post(name: .wallpaperPlayPauseStateDidChange, object: true)
        }
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
            isManuallyPaused = true
            NotificationCenter.default.post(name: .wallpaperPlayPauseStateDidChange, object: false)
            AppLogger.shared.info("[CHATTER] User toggled playback to PAUSE")
        } else {
            isManuallyPaused = false
            playbackCore.play()
            NotificationCenter.default.post(name: .wallpaperPlayPauseStateDidChange, object: true)
            AppLogger.shared.info("[CHATTER] User toggled playback to PLAY")
        }
    }
}

