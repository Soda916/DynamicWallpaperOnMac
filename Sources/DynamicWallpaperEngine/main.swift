import AppKit
import AVKit
import AVFoundation
import DynamicWallpaperCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var dashboardController: DashboardWindowController?
    private var config: AppConfig = AppConfig()
    private var statusMenu: NSMenu?

    private var togglePlayPauseMenuItem: NSMenuItem?
    private var toggleMuteMenuItem: NSMenuItem?
    private var autoPauseMenuItem: NSMenuItem?
    private var audioDuckingMenuItem: NSMenuItem?

    private let configURL: URL = {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("DynamicWallpaperEngine", isDirectory: true)
        try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("config.json")
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLogger.shared.info("[CHATTER] Application launch initiated. Loading system settings...")

        // Load configuration from disk
        switch AppConfig.load(from: configURL) {
        case .success(let loadedConfig):
            self.config = loadedConfig
            AppLogger.shared.info("[CHATTER] Configuration loaded successfully.")
        case .migrated(let loadedConfig, let fromVersion):
            self.config = loadedConfig
            AppLogger.shared.info("[CHATTER] Configuration migrated successfully from Schema v\(fromVersion) -> v\(AppConfig.currentSchemaVersion).")
        case .newerVersionDetected(let version, _):
            AppLogger.shared.info("[CHATTER] Newer configuration version detected (\(version)). Using defaults.")
        case .corruptedFile(let error):
            AppLogger.shared.info("[CHATTER] Configuration file corrupted: \(error.localizedDescription). Using defaults.")
        }

        // Configure Dock icon visibility
        if config.hideDockIcon {
            NSApp.setActivationPolicy(.accessory)
            AppLogger.shared.info("[CHATTER] Dock Icon hidden as per user configuration (Menu Bar App mode)")
        } else {
            NSApp.setActivationPolicy(.regular)
            AppLogger.shared.info("[CHATTER] Dock Icon enabled as per user configuration")
        }

        // Apply initial config to WallpaperController
        WallpaperController.shared.setAutoPauseEnabled(config.autoPauseOnFullscreen)
        WallpaperController.shared.setVolume(config.defaultVolume)
        WallpaperController.shared.setMuted(config.isMuted)
        WallpaperController.shared.setAudioDucked(config.isAudioDucked)
        WallpaperController.shared.setPlaybackMode(config.playbackMode)
        
        let restoredPlaylist = config.playlistPaths.map { URL(fileURLWithPath: $0) }
        if !restoredPlaylist.isEmpty {
            WallpaperController.shared.setPlaylist(restoredPlaylist, currentIndex: config.playlistIndex)
        }

        AppLogger.shared.info("[CHATTER] Initial states applied: autoPause=\(config.autoPauseOnFullscreen), volume=\(config.defaultVolume), isMuted=\(config.isMuted), mode=\(config.playbackMode.rawValue)")

        setupStatusMenu()
        setupGlobalStateObservers()

        // Load and apply last wallpaper or active playlist track
        if let lastPath = config.lastWallpaperPath {
            AppLogger.shared.info("[CHATTER] Restoring last wallpaper path: \(lastPath)")
            let url = URL(fileURLWithPath: lastPath)
            DispatchQueue.main.async {
                WallpaperController.shared.importAndApplyWallpaper(from: url) { result in
                    switch result {
                    case .success(let appliedURL):
                        AppLogger.shared.info("[CHATTER] Restored last wallpaper successfully: \(appliedURL.path)")
                    case .failure(let error):
                        AppLogger.shared.error("[CHATTER] Failed to restore last wallpaper: \(error.localizedDescription)")
                    }
                }
            }
        } else if !restoredPlaylist.isEmpty {
            DispatchQueue.main.async { [weak self] in
                if let idx = self?.config.playlistIndex {
                    WallpaperController.shared.playIndex(idx)
                }
            }
        }

        // Trigger asynchronous update check
        if config.autoCheckUpdates {
            UpdateChecker.shared.checkForUpdates()
        }

        NotificationCenter.default.addObserver(forName: .appUpdateAvailable, object: nil, queue: .main) { notif in
            if let release = notif.object as? UpdateChecker.ReleaseInfo {
                UpdateChecker.shared.presentUpdateAlert(for: release)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveConfig()
    }

    private func saveConfig() {
        config.autoPauseOnFullscreen = WallpaperController.shared.autoPauseEngine.isEnabled
        config.isMuted = WallpaperController.shared.playbackCore.player.isMuted
        config.defaultVolume = WallpaperController.shared.playbackCore.userVolume
        config.isAudioDucked = WallpaperController.shared.playbackCore.isDucked
        config.lastWallpaperPath = WallpaperController.shared.activeWallpaperURL?.path
        config.playlistPaths = WallpaperController.shared.playlist.map { $0.path }
        config.playbackMode = WallpaperController.shared.playbackMode
        config.playlistIndex = WallpaperController.shared.currentIndex
        
        do {
            try config.save(to: configURL)
            AppLogger.shared.info("[CHATTER] Configuration saved successfully to \(configURL.path)")
        } catch {
            AppLogger.shared.error("[CHATTER] Failed to save configuration: \(error.localizedDescription)")
        }
    }

    private func loadSVGIcon(named name: String) -> NSImage? {
        let fm = FileManager.default
        var svgURL: URL?

        if let url = Bundle.main.url(forResource: name, withExtension: "svg") {
            svgURL = url
        } else if let resourcePath = Bundle.main.resourcePath {
            let path = URL(fileURLWithPath: resourcePath).appendingPathComponent("\(name).svg")
            if fm.fileExists(atPath: path.path) { svgURL = path }
        }

        if svgURL == nil {
            let path = URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent("\(name).svg")
            if fm.fileExists(atPath: path.path) { svgURL = path }
        }

        guard let targetURL = svgURL,
              let data = try? Data(contentsOf: targetURL),
              let img = NSImage(data: data) else {
            return nil
        }

        img.size = NSSize(width: 22, height: 16)
        img.isTemplate = true
        return img
    }

    private func updateStatusItemIcon() {
        let isAutoPauseEnabled = config.autoPauseOnFullscreen
        let isAutoPaused = WallpaperController.shared.autoPauseEngine.isPaused
        let isPlaying = WallpaperController.shared.playbackCore.isPlaying && !isAutoPaused

        var iconImage: NSImage?

        if isAutoPauseEnabled {
            if isAutoPaused || !isPlaying {
                // Rule 2: Autoplay (Auto-Pause) 啟用，但畫面因自動暫停停止播放的情況下 -> 使用 autoplay-paused.svg
                iconImage = loadSVGIcon(named: "autoplay-paused")
            } else {
                // Rule 1: Autoplay (Auto-Pause) 啟用，且畫面播放中的情況下 -> 使用 autoplay-playing.svg
                iconImage = loadSVGIcon(named: "autoplay-playing")
            }
        }

        // Rule 3: Autoplay (Auto-Pause) 要是沒啟用 -> 直接使用原本的 icon (play.laptopcomputer / laptopcomputer)
        if iconImage == nil {
            let symbol = isPlaying ? "play.laptopcomputer" : "laptopcomputer"
            iconImage = NSImage(systemSymbolName: symbol, accessibilityDescription: "Dynamic Wallpaper Engine")
            iconImage?.isTemplate = true
        }

        statusItem?.button?.image = iconImage
    }

    private func updateAutoPauseMenuItemState() {
        let isEnabled = config.autoPauseOnFullscreen
        let isPaused = WallpaperController.shared.autoPauseEngine.isPaused
        
        autoPauseMenuItem?.state = isEnabled ? .on : .off
        if isEnabled {
            if isPaused {
                autoPauseMenuItem?.title = "Auto-Pause on Fullscreen (Auto-Paused)"
            } else {
                autoPauseMenuItem?.title = "Auto-Pause on Fullscreen (Active)"
            }
        } else {
            autoPauseMenuItem?.title = "Auto-Pause on Fullscreen"
        }
    }

    private func setupStatusMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.action = #selector(statusItemClicked)
            button.target = self
        }
        updateStatusItemIcon()

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Import Wallpaper...", action: #selector(chooseWallpaper), keyEquivalent: "i"))
        
        let playPauseItem = NSMenuItem(title: "Pause Playback", action: #selector(togglePlayPause), keyEquivalent: "p")
        togglePlayPauseMenuItem = playPauseItem
        menu.addItem(playPauseItem)

        let muteItem = NSMenuItem(title: "Mute Sound", action: #selector(toggleMute), keyEquivalent: "m")
        toggleMuteMenuItem = muteItem
        menu.addItem(muteItem)

        let duckingItem = NSMenuItem(title: "Audio Ducking (5% Volume)", action: #selector(toggleAudioDucking), keyEquivalent: "d")
        duckingItem.state = config.isAudioDucked ? .on : .off
        audioDuckingMenuItem = duckingItem
        menu.addItem(duckingItem)
        
        let autoPauseItem = NSMenuItem(title: "Auto-Pause on Fullscreen", action: #selector(toggleAutoPause), keyEquivalent: "a")
        autoPauseMenuItem = autoPauseItem
        menu.addItem(autoPauseItem)
        updateAutoPauseMenuItemState()

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Open Dashboard", action: #selector(openDashboard), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdatesClicked), keyEquivalent: "u"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit DynamicWallpaperEngine", action: #selector(quitApp), keyEquivalent: "q"))

        statusMenu = menu
        AppLogger.shared.info("[CHATTER] System Status Menu initialized successfully")
    }

    private func setupGlobalStateObservers() {
        let center = NotificationCenter.default
        center.addObserver(forName: .wallpaperMuteStateDidChange, object: nil, queue: .main) { [weak self] notif in
            if let isMuted = notif.object as? Bool {
                self?.config.isMuted = isMuted
                self?.toggleMuteMenuItem?.title = isMuted ? "Unmute Sound" : "Mute Sound"
                self?.saveConfig()
            }
        }

        center.addObserver(forName: .wallpaperPlayPauseStateDidChange, object: nil, queue: .main) { [weak self] notif in
            if let isPlaying = notif.object as? Bool {
                self?.togglePlayPauseMenuItem?.title = isPlaying ? "Pause Playback" : "Resume Playback"
                self?.updateStatusItemIcon()
                self?.updateAutoPauseMenuItemState()
            }
        }

        center.addObserver(forName: .autoPausePauseStateDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.updateStatusItemIcon()
            self?.updateAutoPauseMenuItemState()
        }

        center.addObserver(forName: .wallpaperAutoPauseConfigDidChange, object: nil, queue: .main) { [weak self] notif in
            if let isEnabled = notif.object as? Bool {
                self?.config.autoPauseOnFullscreen = isEnabled
                self?.updateStatusItemIcon()
                self?.updateAutoPauseMenuItemState()
                self?.saveConfig()
            }
        }

        center.addObserver(forName: .wallpaperAudioDuckingDidChange, object: nil, queue: .main) { [weak self] notif in
            if let isDucked = notif.object as? Bool {
                self?.config.isAudioDucked = isDucked
                self?.audioDuckingMenuItem?.state = isDucked ? .on : .off
                self?.saveConfig()
            }
        }

        center.addObserver(forName: .wallpaperVolumeDidChange, object: nil, queue: .main) { [weak self] notif in
            if let vol = notif.object as? Float {
                self?.config.defaultVolume = vol
                self?.saveConfig()
            }
        }

        center.addObserver(forName: .wallpaperPlaylistDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.saveConfig()
        }

        center.addObserver(forName: .wallpaperPlaybackModeDidChange, object: nil, queue: .main) { [weak self] notif in
            if let mode = notif.object as? PlaybackMode {
                self?.config.playbackMode = mode
                self?.saveConfig()
            }
        }
    }

    @objc private func statusItemClicked() {
        let isRightClick = NSApp.currentEvent?.type == .rightMouseUp ||
                           NSApp.currentEvent?.type == .rightMouseDown ||
                           NSApp.currentEvent?.modifierFlags.contains(.control) == true
        if isRightClick {
            openDashboard()
        } else {
            if let button = statusItem?.button, let menu = statusMenu {
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.frame.height + 4), in: button)
            }
        }
    }

    @objc private func chooseWallpaper() {
        if dashboardController == nil {
            dashboardController = DashboardWindowController()
        }
        dashboardController?.importWallpaper()
    }

    @objc private func togglePlayPause() {
        WallpaperController.shared.togglePlayPause()
    }

    @objc private func toggleMute() {
        let newState = !config.isMuted
        WallpaperController.shared.setMuted(newState)
    }

    @objc private func toggleAudioDucking() {
        let isCurrentlyDucked = WallpaperController.shared.playbackCore.isDucked
        WallpaperController.shared.setAudioDucked(!isCurrentlyDucked)
    }

    @objc private func toggleAutoPause() {
        let newState = !config.autoPauseOnFullscreen
        WallpaperController.shared.setAutoPauseEnabled(newState)
    }

    @objc private func openDashboard() {
        if dashboardController == nil {
            dashboardController = DashboardWindowController()
        }
        dashboardController?.showWindow(nil)
        dashboardController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        AppLogger.shared.info("[CHATTER] Opened Dashboard Window Controller")
    }

    @objc private func checkForUpdatesClicked() {
        SparkleUpdaterManager.shared.checkForUpdates()
    }

    @objc private func quitApp() {
        AppLogger.shared.info("[CHATTER] Quitting application via Menu Bar...")
        NSApp.terminate(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

/// Drag and Drop receiver view for Dashboard
final class DashboardDropView: NSView {
    var onFilesDropped: (([URL]) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        if pasteboard.canReadObject(forClasses: [NSURL.self], options: nil) {
            return .copy
        }
        return []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            let supported = urls.filter { ["mp4", "mov", "m4v", "webm", "gif", "wallpaper"].contains($0.pathExtension.lowercased()) }
            if !supported.isEmpty {
                onFilesDropped?(supported)
                return true
            }
        }
        return false
    }
}

/// Custom NSView rendering raw AVPlayerLayer directly without QuickTime player UI controls.
final class RawPlayerView: NSView {
    private let playerLayer = AVPlayerLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(playerLayer)
        playerLayer.videoGravity = .resizeAspect
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }

    public func setPlayer(_ player: AVPlayer) {
        playerLayer.player = player
        playerLayer.frame = bounds
    }
}

/// AppKit Dashboard Window Controller providing raw live video stream preview, playlist management, and real-time console chatter logging.
final class DashboardWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let titleLabel = NSTextField(labelWithString: "Dynamic Wallpaper Engine")
    private let subtitleLabel = NSTextField(labelWithString: "macOS Native Live Stream Monitor & Playlist Manager")
    private let statusBadge = NSTextField(labelWithString: "Active Playback")

    private let dropView = DashboardDropView()
    private let rawPlayerView = RawPlayerView()
    private let fileNameLabel = NSTextField(labelWithString: "No Wallpaper Selected")
    private let filePathLabel = NSTextField(labelWithString: "Drag & Drop video files here or click Import below")

    private let importButton = NSButton(title: "Import / Select Wallpaper Video...", target: nil, action: nil)
    private let prevButton = NSButton(title: "⏮ Prev", target: nil, action: nil)
    private let playPauseButton = NSButton(title: "Pause", target: nil, action: nil)
    private let nextButton = NSButton(title: "Next ⏭", target: nil, action: nil)
    private let muteButton = NSButton(title: "Mute", target: nil, action: nil)

    private let modePopUp = NSPopUpButton()
    private let playbackProgressSlider = NSSlider(value: 0.0, minValue: 0.0, maxValue: 1.0, target: nil, action: nil)
    private let timeLabel = NSTextField(labelWithString: "00:00 / 00:00")
    private var isUserScrubbing = false

    private let autoPauseCheckbox = NSButton(checkboxWithTitle: "Enable Auto-Pause on Fullscreen / Maximize", target: nil, action: nil)
    private let audioDuckingCheckbox = NSButton(checkboxWithTitle: "Audio Ducking (5% Volume)", target: nil, action: nil)

    private let volumeSlider = NSSlider(value: 1.0, minValue: 0.0, maxValue: 1.0, target: nil, action: nil)
    private let volumeLabel = NSTextField(labelWithString: "Volume: 100%")
    private let footerStatusLabel = NSTextField(labelWithString: "Status: Ready")

    private let playlistTableView = NSTableView()
    private let playlistScrollView = NSScrollView()
    private let removePlaylistItemButton = NSButton(title: "Remove Selected", target: nil, action: nil)
    private let clearPlaylistButton = NSButton(title: "Clear Playlist", target: nil, action: nil)

    private let consoleTextView = NSTextView()
    private let consoleScrollView = NSScrollView()
    private var chatterTimer: Timer?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Dynamic Wallpaper Engine Live Monitor"
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)

        setupUI()
        setupActions()
        observeControllerState()
        startChatterTimer()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        chatterTimer?.invalidate()
    }

    private func setupUI() {
        guard let window = window, let contentView = window.contentView else { return }

        dropView.translatesAutoresizingMaskIntoConstraints = false
        dropView.onFilesDropped = { [weak self] urls in
            AppLogger.shared.info("[DRAG-DROP] User dropped \(urls.count) files into Dashboard")
            WallpaperController.shared.addToPlaylist(urls)
            if WallpaperController.shared.activeWallpaperURL == nil, let first = urls.first {
                WallpaperController.shared.importAndApplyWallpaper(from: first)
            }
            self?.playlistTableView.reloadData()
        }
        contentView.addSubview(dropView)
        NSLayoutConstraint.activate([
            dropView.topAnchor.constraint(equalTo: contentView.topAnchor),
            dropView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            dropView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            dropView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])

        titleLabel.font = NSFont.boldSystemFont(ofSize: 20)
        subtitleLabel.font = NSFont.systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor

        statusBadge.font = NSFont.boldSystemFont(ofSize: 11)
        statusBadge.textColor = .systemGreen

        let headerTextStack = NSStackView(views: [titleLabel, subtitleLabel])
        headerTextStack.orientation = .vertical
        headerTextStack.alignment = .leading
        headerTextStack.spacing = 4

        let headerStack = NSStackView(views: [headerTextStack, statusBadge])
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.distribution = .equalSpacing

        // Raw Live Preview Player Setup
        rawPlayerView.setPlayer(WallpaperController.shared.playbackCore.player)

        fileNameLabel.font = NSFont.boldSystemFont(ofSize: 13)
        fileNameLabel.textColor = .labelColor
        fileNameLabel.alignment = .center

        filePathLabel.font = NSFont.systemFont(ofSize: 10)
        filePathLabel.textColor = .secondaryLabelColor
        filePathLabel.alignment = .center

        let previewInfoStack = NSStackView(views: [rawPlayerView, fileNameLabel, filePathLabel])
        previewInfoStack.orientation = .vertical
        previewInfoStack.alignment = .centerX
        previewInfoStack.spacing = 8

        importButton.bezelStyle = .rounded
        importButton.controlSize = .large

        // Playlist Table View Setup
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("PlaylistColumn"))
        col.title = "Playlist Items (Drag & Drop files to append)"
        col.width = 360
        playlistTableView.addTableColumn(col)
        playlistTableView.dataSource = self
        playlistTableView.delegate = self
        playlistTableView.doubleAction = #selector(playlistDoubleClicked)
        playlistTableView.target = self

        playlistScrollView.documentView = playlistTableView
        playlistScrollView.hasVerticalScroller = true
        playlistScrollView.borderType = .bezelBorder

        removePlaylistItemButton.bezelStyle = .rounded
        removePlaylistItemButton.controlSize = .small
        clearPlaylistButton.bezelStyle = .rounded
        clearPlaylistButton.controlSize = .small

        let playlistBtnStack = NSStackView(views: [removePlaylistItemButton, clearPlaylistButton])
        playlistBtnStack.orientation = .horizontal
        playlistBtnStack.spacing = 8

        let playlistSectionStack = NSStackView(views: [playlistScrollView, playlistBtnStack])
        playlistSectionStack.orientation = .vertical
        playlistSectionStack.alignment = .leading
        playlistSectionStack.spacing = 4

        prevButton.bezelStyle = .rounded
        playPauseButton.bezelStyle = .rounded
        nextButton.bezelStyle = .rounded
        muteButton.bezelStyle = .rounded
        
        modePopUp.addItems(withTitles: ["Single Track Loop", "Sequential Playlist", "Random Shuffle"])
        switch WallpaperController.shared.playbackMode {
        case .single: modePopUp.selectItem(at: 0)
        case .sequential: modePopUp.selectItem(at: 1)
        case .random: modePopUp.selectItem(at: 2)
        }

        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        timeLabel.textColor = .secondaryLabelColor

        let progressLabel = NSTextField(labelWithString: "Playback Progress:")
        progressLabel.font = NSFont.systemFont(ofSize: 11)

        let progressHeaderStack = NSStackView(views: [progressLabel, timeLabel])
        progressHeaderStack.orientation = .horizontal
        progressHeaderStack.distribution = .equalSpacing

        let progressStack = NSStackView(views: [progressHeaderStack, playbackProgressSlider])
        progressStack.orientation = .vertical
        progressStack.alignment = .leading
        progressStack.spacing = 4

        autoPauseCheckbox.state = AutoPauseEngine.shared.isEnabled ? .on : .off
        audioDuckingCheckbox.state = WallpaperController.shared.playbackCore.isDucked ? .on : .off

        let mediaControlStack = NSStackView(views: [prevButton, playPauseButton, nextButton, muteButton])
        mediaControlStack.orientation = .horizontal
        mediaControlStack.spacing = 8

        let modeStack = NSStackView(views: [NSTextField(labelWithString: "Playback Mode:"), modePopUp])
        modeStack.orientation = .horizontal
        modeStack.spacing = 8

        let checkboxesStack = NSStackView(views: [autoPauseCheckbox, audioDuckingCheckbox])
        checkboxesStack.orientation = .vertical
        checkboxesStack.alignment = .leading
        checkboxesStack.spacing = 6

        volumeLabel.font = NSFont.systemFont(ofSize: 12)
        volumeLabel.textColor = .secondaryLabelColor

        footerStatusLabel.font = NSFont.systemFont(ofSize: 11)
        footerStatusLabel.textColor = .tertiaryLabelColor

        // Console Log View Setup
        consoleTextView.isEditable = false
        consoleTextView.font = NSFont.userFixedPitchFont(ofSize: 10)
        consoleTextView.backgroundColor = NSColor.black
        consoleTextView.textColor = NSColor.systemGreen
        consoleTextView.autoresizingMask = [.width, .height]

        consoleScrollView.documentView = consoleTextView
        consoleScrollView.hasVerticalScroller = true
        consoleScrollView.borderType = .bezelBorder
        consoleScrollView.wantsLayer = true
        consoleScrollView.layer?.cornerRadius = 6

        let consoleTitleLabel = NSTextField(labelWithString: "Real-Time Console Chatter & Logs:")
        consoleTitleLabel.font = NSFont.boldSystemFont(ofSize: 11)

        let consoleStack = NSStackView(views: [consoleTitleLabel, consoleScrollView])
        consoleStack.orientation = .vertical
        consoleStack.alignment = .leading
        consoleStack.spacing = 4

        for log in AppLogger.shared.recentLogs {
            appendConsoleLog(log)
        }

        let controlsHeading = NSTextField(labelWithString: "Playback & Playlist Controls")
        controlsHeading.font = NSFont.boldSystemFont(ofSize: 12)

        // Right Controls Stack
        let rightStack = NSStackView(views: [
            controlsHeading,
            modeStack,
            progressStack,
            mediaControlStack,
            checkboxesStack,
            volumeLabel,
            volumeSlider,
            footerStatusLabel,
            consoleStack
        ])
        rightStack.orientation = .vertical
        rightStack.alignment = .leading
        rightStack.spacing = 8

        // Left Content Stack (Preview + Playlist)
        let leftStack = NSStackView(views: [previewInfoStack, importButton, playlistSectionStack])
        leftStack.orientation = .vertical
        leftStack.spacing = 10
        leftStack.alignment = .centerX

        let mainContentStack = NSStackView(views: [leftStack, rightStack])
        mainContentStack.orientation = .horizontal
        mainContentStack.spacing = 20
        mainContentStack.distribution = .fill

        let separator = NSBox()
        separator.boxType = .separator
        let rootStack = NSStackView(views: [headerStack, separator, mainContentStack])
        rootStack.orientation = .vertical
        rootStack.spacing = 12
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            rootStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),

            rawPlayerView.widthAnchor.constraint(equalToConstant: 380),
            rawPlayerView.heightAnchor.constraint(equalToConstant: 213.75),

            playlistScrollView.widthAnchor.constraint(equalToConstant: 380),
            playlistScrollView.heightAnchor.constraint(equalToConstant: 160),

            progressHeaderStack.widthAnchor.constraint(equalTo: rightStack.widthAnchor),
            playbackProgressSlider.widthAnchor.constraint(equalTo: rightStack.widthAnchor),

            consoleScrollView.heightAnchor.constraint(equalToConstant: 130),
            consoleScrollView.widthAnchor.constraint(equalTo: rightStack.widthAnchor)
        ])
    }

    private func setupActions() {
        importButton.target = self
        importButton.action = #selector(importWallpaper)

        prevButton.target = self
        prevButton.action = #selector(prevTrack)

        playPauseButton.target = self
        playPauseButton.action = #selector(togglePlayPause)

        nextButton.target = self
        nextButton.action = #selector(nextTrack)

        muteButton.target = self
        muteButton.action = #selector(toggleMute)

        modePopUp.target = self
        modePopUp.action = #selector(modePopUpChanged)

        playbackProgressSlider.target = self
        playbackProgressSlider.action = #selector(progressSliderScrubbed)

        autoPauseCheckbox.target = self
        autoPauseCheckbox.action = #selector(autoPauseToggled)

        audioDuckingCheckbox.target = self
        audioDuckingCheckbox.action = #selector(audioDuckingToggled)

        volumeSlider.target = self
        volumeSlider.action = #selector(volumeSliderChanged)

        removePlaylistItemButton.target = self
        removePlaylistItemButton.action = #selector(removeSelectedPlaylistItem)

        clearPlaylistButton.target = self
        clearPlaylistButton.action = #selector(clearPlaylistClicked)
    }

    private func observeControllerState() {
        AppLogger.shared.onLogAdded = { [weak self] line in
            self?.appendConsoleLog(line)
        }

        WallpaperController.shared.onWallpaperChanged = { [weak self] url in
            DispatchQueue.main.async {
                self?.fileNameLabel.stringValue = url?.lastPathComponent ?? "No Wallpaper Selected"
                self?.filePathLabel.stringValue = url?.path ?? ""
                self?.playPauseButton.title = "Pause"
                self?.footerStatusLabel.stringValue = "Status: Playing \(url?.lastPathComponent ?? "")"
                self?.rawPlayerView.setPlayer(WallpaperController.shared.playbackCore.player)
                self?.playlistTableView.reloadData()
            }
        }

        let center = NotificationCenter.default

        center.addObserver(forName: .wallpaperPlaylistDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.playlistTableView.reloadData()
        }

        center.addObserver(forName: .wallpaperPlaybackModeDidChange, object: nil, queue: .main) { [weak self] notif in
            if let mode = notif.object as? PlaybackMode {
                switch mode {
                case .single: self?.modePopUp.selectItem(at: 0)
                case .sequential: self?.modePopUp.selectItem(at: 1)
                case .random: self?.modePopUp.selectItem(at: 2)
                }
            }
        }

        center.addObserver(forName: .autoPausePauseStateDidChange, object: nil, queue: .main) { [weak self] notif in
            if let isPaused = notif.object as? Bool {
                if isPaused {
                    self?.statusBadge.stringValue = "Auto-Paused (Fullscreen/Maximized)"
                    self?.statusBadge.textColor = .systemOrange
                } else {
                    self?.statusBadge.stringValue = "Active Playback"
                    self?.statusBadge.textColor = .systemGreen
                }
            }
        }

        center.addObserver(forName: .wallpaperMuteStateDidChange, object: nil, queue: .main) { [weak self] notif in
            if let isMuted = notif.object as? Bool {
                self?.muteButton.title = isMuted ? "Unmute" : "Mute"
                self?.volumeSlider.isEnabled = !isMuted
            }
        }

        center.addObserver(forName: .wallpaperPlayPauseStateDidChange, object: nil, queue: .main) { [weak self] notif in
            if let isPlaying = notif.object as? Bool {
                self?.playPauseButton.title = isPlaying ? "Pause" : "Play"
                if isPlaying {
                    if WallpaperController.shared.autoPauseEngine.isPaused && WallpaperController.shared.autoPauseEngine.isEnabled {
                        self?.statusBadge.stringValue = "Auto-Paused (Fullscreen/Maximized)"
                        self?.statusBadge.textColor = .systemOrange
                    } else {
                        self?.statusBadge.stringValue = "Active Playback"
                        self?.statusBadge.textColor = .systemGreen
                    }
                } else {
                    if WallpaperController.shared.isManuallyPaused {
                        self?.statusBadge.stringValue = "Paused by User"
                        self?.statusBadge.textColor = .systemRed
                    } else {
                        self?.statusBadge.stringValue = "Auto-Paused (Fullscreen/Maximized)"
                        self?.statusBadge.textColor = .systemOrange
                    }
                }
            }
        }

        center.addObserver(forName: .wallpaperVolumeDidChange, object: nil, queue: .main) { [weak self] notif in
            if let vol = notif.object as? Float {
                self?.volumeSlider.floatValue = vol
                self?.volumeLabel.stringValue = "Volume: \(Int(vol * 100))%"
            }
        }

        center.addObserver(forName: .wallpaperAutoPauseConfigDidChange, object: nil, queue: .main) { [weak self] notif in
            if let isEnabled = notif.object as? Bool {
                self?.autoPauseCheckbox.state = isEnabled ? .on : .off
            }
        }

        center.addObserver(forName: .wallpaperAudioDuckingDidChange, object: nil, queue: .main) { [weak self] notif in
            if let isDucked = notif.object as? Bool {
                self?.audioDuckingCheckbox.state = isDucked ? .on : .off
            }
        }

        center.addObserver(forName: NSNotification.Name("wallpaperAudioDuckingActiveAppsDidChange"), object: nil, queue: .main) { [weak self] notif in
            if let apps = notif.object as? [String] {
                if !apps.isEmpty {
                    let names = apps.joined(separator: ", ")
                    self?.audioDuckingCheckbox.title = "Audio Ducking (5% Volume) - Active: \(names)"
                    self?.footerStatusLabel.stringValue = "Status: Audio Ducked (5%) by '\(names)'"
                } else {
                    self?.audioDuckingCheckbox.title = "Audio Ducking (5% Volume)"
                }
            }
        }
    }

    private func appendConsoleLog(_ text: String) {
        let textWithNewline = text + "\n"
        if let textStorage = consoleTextView.textStorage {
            let attrString = NSAttributedString(string: textWithNewline, attributes: [
                .font: NSFont.userFixedPitchFont(ofSize: 10) ?? NSFont.systemFont(ofSize: 10),
                .foregroundColor: NSColor.systemGreen
            ])
            textStorage.append(attrString)
            consoleTextView.scrollToEndOfDocument(nil)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "00:00" }
        let totalSeconds = Int(seconds)
        let hrs = totalSeconds / 3600
        let mins = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hrs > 0 {
            return String(format: "%02d:%02d:%02d", hrs, mins, secs)
        } else {
            return String(format: "%02d:%02d", mins, secs)
        }
    }

    private func startChatterTimer() {
        chatterTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let core = WallpaperController.shared.playbackCore
            let current = core.currentTimeSeconds
            let total = core.durationSeconds

            if !self.isUserScrubbing {
                if total > 0 {
                    self.playbackProgressSlider.doubleValue = current / total
                    self.timeLabel.stringValue = "\(self.formatTime(current)) / \(self.formatTime(total))"
                } else {
                    self.playbackProgressSlider.doubleValue = 0
                    self.timeLabel.stringValue = "00:00 / 00:00"
                }
            }

            let player = core.player
            let rate = player.rate
            let status = player.status.rawValue
            let itemStatus = player.currentItem?.status.rawValue ?? -1
            let itemError = player.currentItem?.error?.localizedDescription ?? "None"

            AppLogger.shared.debug("[CHATTER] Player Monitor Tick: rate=\(rate), time=\(String(format: "%.2f", current))s/\(String(format: "%.2f", total))s, status=\(status), itemStatus=\(itemStatus), itemError=\(itemError)")
        }
    }

    @objc private func progressSliderScrubbed(_ sender: NSSlider) {
        let event = NSApp.currentEvent
        if event?.type == .leftMouseUp {
            isUserScrubbing = false
            WallpaperController.shared.playbackCore.seek(toProgress: sender.doubleValue)
        } else {
            isUserScrubbing = true
            let total = WallpaperController.shared.playbackCore.durationSeconds
            let current = sender.doubleValue * total
            timeLabel.stringValue = "\(formatTime(current)) / \(formatTime(total))"
        }
    }

    // NSTableView DataSource & Delegate
    func numberOfRows(in tableView: NSTableView) -> Int {
        return WallpaperController.shared.playlist.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let playlist = WallpaperController.shared.playlist
        guard playlist.indices.contains(row) else { return nil }

        let item = playlist[row]
        let isCurrent = (row == WallpaperController.shared.currentIndex)

        let identifier = NSUserInterfaceItemIdentifier("PlaylistCell")
        var textField = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField
        if textField == nil {
            textField = NSTextField(labelWithString: "")
            textField?.identifier = identifier
            textField?.font = NSFont.systemFont(ofSize: 11)
        }

        let prefix = isCurrent ? "▶ " : "   "
        textField?.stringValue = "\(prefix)\(row + 1). \(item.lastPathComponent)"
        textField?.textColor = isCurrent ? NSColor.systemGreen : NSColor.labelColor
        if isCurrent {
            textField?.font = NSFont.boldSystemFont(ofSize: 11)
        } else {
            textField?.font = NSFont.systemFont(ofSize: 11)
        }
        return textField
    }

    @objc private func playlistDoubleClicked() {
        let clickedRow = playlistTableView.clickedRow
        if clickedRow >= 0 {
            WallpaperController.shared.playIndex(clickedRow)
        }
    }

    @objc private func removeSelectedPlaylistItem() {
        let selectedRow = playlistTableView.selectedRow
        if selectedRow >= 0 {
            WallpaperController.shared.removeFromPlaylist(at: selectedRow)
        }
    }

    @objc private func clearPlaylistClicked() {
        WallpaperController.shared.clearPlaylist()
    }

    @objc public func importWallpaper() {
        NSApp.activate(ignoringOtherApps: true)
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Video Wallpaper(s) or GIF"
        openPanel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie, .gif]
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false

        openPanel.begin { [weak self] result in
            if result == .OK {
                let selectedURLs = openPanel.urls
                AppLogger.shared.info("[CHATTER] User selected \(selectedURLs.count) file(s) from NSOpenPanel")
                
                WallpaperController.shared.addToPlaylist(selectedURLs)
                if let first = selectedURLs.first {
                    WallpaperController.shared.importAndApplyWallpaper(from: first)
                }
                self?.playlistTableView.reloadData()
            }
        }
    }

    @objc private func prevTrack() {
        WallpaperController.shared.playPrevious()
    }

    @objc private func nextTrack() {
        WallpaperController.shared.playNext()
    }

    @objc private func modePopUpChanged() {
        let selectedIndex = modePopUp.indexOfSelectedItem
        switch selectedIndex {
        case 0: WallpaperController.shared.setPlaybackMode(.single)
        case 1: WallpaperController.shared.setPlaybackMode(.sequential)
        case 2: WallpaperController.shared.setPlaybackMode(.random)
        default: break
        }
    }

    @objc private func togglePlayPause() {
        WallpaperController.shared.togglePlayPause()
    }

    @objc private func toggleMute() {
        let isMuted = !WallpaperController.shared.playbackCore.player.isMuted
        WallpaperController.shared.setMuted(isMuted)
    }

    @objc private func autoPauseToggled() {
        let isEnabled = (autoPauseCheckbox.state == .on)
        WallpaperController.shared.setAutoPauseEnabled(isEnabled)
    }

    @objc private func audioDuckingToggled() {
        let isDucked = (audioDuckingCheckbox.state == .on)
        WallpaperController.shared.setAudioDucked(isDucked)
    }

    @objc private func volumeSliderChanged() {
        let vol = volumeSlider.floatValue
        WallpaperController.shared.setVolume(vol)
    }
}

if let bundleID = Bundle.main.bundleIdentifier {
    let currentApp = NSRunningApplication.current
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    let otherInstances = runningApps.filter { $0.processIdentifier != currentApp.processIdentifier }
    if !otherInstances.isEmpty {
        print("Another instance of DynamicWallpaperEngine (\(bundleID)) is already running. Exiting.")
        exit(0)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

