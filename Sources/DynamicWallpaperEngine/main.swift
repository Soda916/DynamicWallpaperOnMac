import AppKit
import AVFoundation
import DynamicWallpaperCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var dashboardController: DashboardWindowController?
    private var config: AppConfig = AppConfig()
    private var autoPauseMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLogger.shared.info("[CHATTER] Application launch initiated. Loading system settings...")

        // Configure Dock icon visibility according to user preference (Default: hidden Menu Bar App)
        if config.hideDockIcon {
            NSApp.setActivationPolicy(.accessory)
            AppLogger.shared.info("[CHATTER] Dock Icon hidden as per user configuration (Menu Bar App mode)")
        } else {
            NSApp.setActivationPolicy(.regular)
            AppLogger.shared.info("[CHATTER] Dock Icon enabled as per user configuration")
        }

        // Apply initial config to AutoPauseEngine
        AutoPauseEngine.shared.isEnabled = config.autoPauseOnFullscreen
        AppLogger.shared.info("[CHATTER] AutoPauseEngine initial state: \(config.autoPauseOnFullscreen)")

        setupStatusMenu()
    }

    private func setupStatusMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "desktopcomputer", accessibilityDescription: "Dynamic Wallpaper Engine")
            button.action = #selector(statusItemClicked)
            button.target = self
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Import Wallpaper...", action: #selector(chooseWallpaper), keyEquivalent: "i"))
        menu.addItem(NSMenuItem(title: "Toggle Play / Pause", action: #selector(togglePlayPause), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "Mute Sound", action: #selector(toggleMute), keyEquivalent: "m"))
        
        let autoPauseItem = NSMenuItem(title: "Auto-Pause on Fullscreen", action: #selector(toggleAutoPause), keyEquivalent: "a")
        autoPauseItem.state = config.autoPauseOnFullscreen ? .on : .off
        autoPauseMenuItem = autoPauseItem
        menu.addItem(autoPauseItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Open Dashboard", action: #selector(openDashboard), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit DynamicWallpaperEngine", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
        AppLogger.shared.info("[CHATTER] System Status Menu initialized successfully")
    }

    @objc private func statusItemClicked() {
        openDashboard()
    }

    @objc private func chooseWallpaper() {
        dashboardController?.importWallpaper()
    }

    @objc private func togglePlayPause() {
        WallpaperController.shared.togglePlayPause()
    }

    @objc private func toggleAutoPause() {
        config.autoPauseOnFullscreen.toggle()
        let isEnabled = config.autoPauseOnFullscreen
        AutoPauseEngine.shared.isEnabled = isEnabled
        autoPauseMenuItem?.state = isEnabled ? .on : .off
        dashboardController?.updateAutoPauseUI(isEnabled: isEnabled)
        AppLogger.shared.info("[CHATTER] AutoPause toggled via Menu Bar item to: \(isEnabled)")
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

    @objc private func toggleMute() {
        config.isMuted.toggle()
        WallpaperController.shared.setMuted(config.isMuted)
        AppLogger.shared.info("[CHATTER] Mute state toggled to: \(config.isMuted)")
    }

    @objc private func quitApp() {
        AppLogger.shared.info("[CHATTER] Quitting application via Menu Bar...")
        NSApp.terminate(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
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
        playerLayer.videoGravity = .resizeAspectFill
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

/// AppKit Dashboard Window Controller providing raw live video stream preview and real-time console chatter logging.
final class DashboardWindowController: NSWindowController {
    private let titleLabel = NSTextField(labelWithString: "Dynamic Wallpaper Engine")
    private let subtitleLabel = NSTextField(labelWithString: "macOS Native Live Stream Monitor & Real-Time Console Logs")
    private let statusBadge = NSTextField(labelWithString: "Active Playback")

    private let rawPlayerView = RawPlayerView()
    private let fileNameLabel = NSTextField(labelWithString: "No Wallpaper Selected")
    private let filePathLabel = NSTextField(labelWithString: "Click below to import MP4, MOV, WEBM or GIF")

    private let importButton = NSButton(title: "Import / Select Wallpaper Video...", target: nil, action: nil)
    private let playPauseButton = NSButton(title: "Pause", target: nil, action: nil)
    private let muteButton = NSButton(title: "Mute", target: nil, action: nil)
    private let autoPauseCheckbox = NSButton(checkboxWithTitle: "Enable Auto-Pause on Fullscreen", target: nil, action: nil)

    private let volumeSlider = NSSlider(value: 1.0, minValue: 0.0, maxValue: 1.0, target: nil, action: nil)
    private let volumeLabel = NSTextField(labelWithString: "Volume: 100%")
    private let footerStatusLabel = NSTextField(labelWithString: "Status: Ready")

    private let consoleTextView = NSTextView()
    private let consoleScrollView = NSScrollView()
    private var chatterTimer: Timer?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 620),
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

        titleLabel.font = NSFont.boldSystemFont(ofSize: 20)
        subtitleLabel.font = NSFont.systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor

        statusBadge.font = NSFont.boldSystemFont(ofSize: 11)
        statusBadge.textColor = .systemGreen

        // Header Stack
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
        previewInfoStack.spacing = 6

        importButton.bezelStyle = .rounded
        importButton.controlSize = .large

        playPauseButton.bezelStyle = .rounded
        muteButton.bezelStyle = .rounded
        autoPauseCheckbox.state = AutoPauseEngine.shared.isEnabled ? .on : .off

        let mediaControlStack = NSStackView(views: [playPauseButton, muteButton])
        mediaControlStack.orientation = .horizontal
        mediaControlStack.spacing = 12

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

        // Populate initial logs
        for log in AppLogger.shared.recentLogs {
            appendConsoleLog(log)
        }

        // Right Controls Stack
        let rightStack = NSStackView(views: [
            NSTextField(labelWithString: "Playback Controls"),
            mediaControlStack,
            autoPauseCheckbox,
            volumeLabel,
            volumeSlider,
            footerStatusLabel,
            consoleStack
        ])
        rightStack.orientation = .vertical
        rightStack.alignment = .leading
        rightStack.spacing = 10

        // Main Split Content
        let leftStack = NSStackView(views: [previewInfoStack, importButton])
        leftStack.orientation = .vertical
        leftStack.spacing = 12

        let mainContentStack = NSStackView(views: [leftStack, rightStack])
        mainContentStack.orientation = .horizontal
        mainContentStack.spacing = 20
        mainContentStack.distribution = .fillEqually

        let rootStack = NSStackView(views: [headerStack, NSBox(), mainContentStack])
        rootStack.orientation = .vertical
        rootStack.spacing = 14
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            rootStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            rawPlayerView.heightAnchor.constraint(equalToConstant: 220),
            consoleScrollView.heightAnchor.constraint(equalToConstant: 160),
            consoleScrollView.widthAnchor.constraint(equalTo: rightStack.widthAnchor)
        ])
    }

    private func setupActions() {
        importButton.target = self
        importButton.action = #selector(importWallpaper)

        playPauseButton.target = self
        playPauseButton.action = #selector(togglePlayPause)

        muteButton.target = self
        muteButton.action = #selector(toggleMute)

        autoPauseCheckbox.target = self
        autoPauseCheckbox.action = #selector(autoPauseToggled)

        volumeSlider.target = self
        volumeSlider.action = #selector(volumeSliderChanged)
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
                self?.footerStatusLabel.stringValue = "Status: Active Playback"
                self?.rawPlayerView.setPlayer(WallpaperController.shared.playbackCore.player)
            }
        }

        WallpaperController.shared.autoPauseEngine.onPauseStateChanged = { [weak self] isPaused in
            DispatchQueue.main.async {
                if isPaused {
                    self?.statusBadge.stringValue = "Auto-Paused (Fullscreen)"
                    self?.statusBadge.textColor = .systemOrange
                } else {
                    self?.statusBadge.stringValue = "Active Playback"
                    self?.statusBadge.textColor = .systemGreen
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

    private func startChatterTimer() {
        chatterTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            let player = WallpaperController.shared.playbackCore.player
            let rate = player.rate
            let time = player.currentTime().seconds
            let status = player.status.rawValue
            let itemStatus = player.currentItem?.status.rawValue ?? -1
            let itemError = player.currentItem?.error?.localizedDescription ?? "None"

            AppLogger.shared.debug("[CHATTER] Player Monitor Tick: rate=\(rate), time=\(String(format: "%.2f", time))s, status=\(status), itemStatus=\(itemStatus), itemError=\(itemError)")
        }
    }

    public func updateAutoPauseUI(isEnabled: Bool) {
        autoPauseCheckbox.state = isEnabled ? .on : .off
    }

    @objc public func importWallpaper() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Video Wallpaper or GIF"
        openPanel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie, .gif]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false

        openPanel.begin { [weak self] result in
            if result == .OK, let selectedURL = openPanel.url {
                AppLogger.shared.info("[CHATTER] User selected file from NSOpenPanel: \(selectedURL.path)")
                self?.footerStatusLabel.stringValue = "Status: Processing \(selectedURL.lastPathComponent)..."
                
                WallpaperController.shared.importAndApplyWallpaper(from: selectedURL) { res in
                    DispatchQueue.main.async {
                        switch res {
                        case .success(let appliedURL):
                            self?.fileNameLabel.stringValue = appliedURL.lastPathComponent
                            self?.filePathLabel.stringValue = appliedURL.path
                            self?.playPauseButton.title = "Pause"
                            self?.footerStatusLabel.stringValue = "Status: Applied \(appliedURL.lastPathComponent)"
                            self?.rawPlayerView.setPlayer(WallpaperController.shared.playbackCore.player)
                            AppLogger.shared.info("[CHATTER] Live Dashboard RawPlayerView updated with player for \(appliedURL.lastPathComponent)")
                        case .failure(let err):
                            self?.footerStatusLabel.stringValue = "Error: \(err.localizedDescription)"
                            AppLogger.shared.error("[CHATTER] Error importing wallpaper: \(err.localizedDescription)")
                        }
                    }
                }
            }
        }
    }

    @objc private func togglePlayPause() {
        WallpaperController.shared.togglePlayPause()
        let isPlaying = WallpaperController.shared.playbackCore.isPlaying
        playPauseButton.title = isPlaying ? "Pause" : "Play"
    }

    @objc private func toggleMute() {
        let isMuted = !WallpaperController.shared.playbackCore.player.isMuted
        WallpaperController.shared.setMuted(isMuted)
        muteButton.title = isMuted ? "Unmute" : "Mute"
    }

    @objc private func autoPauseToggled() {
        let isEnabled = (autoPauseCheckbox.state == .on)
        AutoPauseEngine.shared.isEnabled = isEnabled
        AppLogger.shared.info("[CHATTER] AutoPause toggled via Dashboard checkbox: \(isEnabled)")
    }

    @objc private func volumeSliderChanged() {
        let vol = volumeSlider.floatValue
        WallpaperController.shared.setVolume(vol)
        volumeLabel.stringValue = "Volume: \(Int(vol * 100))%"
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
