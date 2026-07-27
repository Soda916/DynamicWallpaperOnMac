import AppKit
import AVFoundation
import DynamicWallpaperCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var dashboardController: DashboardWindowController?
    private var config: AppConfig = AppConfig()
    private var autoPauseMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLogger.shared.info("DynamicWallpaperEngine starting up...")

        // Configure Dock icon visibility according to user preference (Default: hidden Menu Bar App)
        if config.hideDockIcon {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }

        // Apply initial config to AutoPauseEngine
        AutoPauseEngine.shared.isEnabled = config.autoPauseOnFullscreen

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
        AppLogger.shared.info("AutoPause toggled via menu item: \(isEnabled)")
    }

    @objc private func openDashboard() {
        if dashboardController == nil {
            dashboardController = DashboardWindowController()
        }
        dashboardController?.showWindow(nil)
        dashboardController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleMute() {
        config.isMuted.toggle()
        WallpaperController.shared.setMuted(config.isMuted)
        AppLogger.shared.info("Mute state toggled to: \(config.isMuted)")
    }

    @objc private func quitApp() {
        AppLogger.shared.info("Application quitting via Menu Bar...")
        NSApp.terminate(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running in Menu Bar when GUI window is closed
        return false
    }
}

/// AppKit Dashboard Window Controller providing zero-macro, native high-performance controls.
final class DashboardWindowController: NSWindowController {
    private let titleLabel = NSTextField(labelWithString: "Dynamic Wallpaper Engine")
    private let subtitleLabel = NSTextField(labelWithString: "macOS Native, Extreme Low Resource, Open Source Dynamic Wallpaper Runtime")
    private let statusBadge = NSTextField(labelWithString: "Active Playback")

    private let previewBox = NSBox()
    private let fileNameLabel = NSTextField(labelWithString: "No Wallpaper Selected")
    private let filePathLabel = NSTextField(labelWithString: "Click below to import MP4, MOV, WEBM or GIF")

    private let importButton = NSButton(title: "Import / Select Wallpaper Video...", target: nil, action: nil)
    private let playPauseButton = NSButton(title: "Pause", target: nil, action: nil)
    private let muteButton = NSButton(title: "Mute", target: nil, action: nil)
    private let autoPauseCheckbox = NSButton(checkboxWithTitle: "Enable Auto-Pause on Fullscreen", target: nil, action: nil)

    private let volumeSlider = NSSlider(value: 1.0, minValue: 0.0, maxValue: 1.0, target: nil, action: nil)
    private let volumeLabel = NSTextField(labelWithString: "Volume: 100%")
    private let footerStatusLabel = NSTextField(labelWithString: "Status: Ready")

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Dynamic Wallpaper Engine Dashboard"
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)

        setupUI()
        setupActions()
        observeControllerState()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

        // Preview Box Layout
        previewBox.boxType = .custom
        previewBox.fillColor = NSColor.black
        previewBox.borderColor = NSColor.separatorColor
        previewBox.cornerRadius = 10

        fileNameLabel.font = NSFont.boldSystemFont(ofSize: 15)
        fileNameLabel.textColor = .white
        fileNameLabel.alignment = .center

        filePathLabel.font = NSFont.systemFont(ofSize: 11)
        filePathLabel.textColor = .lightGray
        filePathLabel.alignment = .center

        let previewStack = NSStackView(views: [fileNameLabel, filePathLabel])
        previewStack.orientation = .vertical
        previewStack.alignment = .centerX
        previewStack.spacing = 6
        previewStack.translatesAutoresizingMaskIntoConstraints = false

        previewBox.addSubview(previewStack)
        NSLayoutConstraint.activate([
            previewStack.centerXAnchor.constraint(equalTo: previewBox.centerXAnchor),
            previewStack.centerYAnchor.constraint(equalTo: previewBox.centerYAnchor),
            previewStack.leadingAnchor.constraint(greaterThanOrEqualTo: previewBox.leadingAnchor, constant: 16),
            previewStack.trailingAnchor.constraint(lessThanOrEqualTo: previewBox.trailingAnchor, constant: -16)
        ])

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

        // Right Controls Stack
        let rightStack = NSStackView(views: [
            NSTextField(labelWithString: "Playback Controls"),
            mediaControlStack,
            autoPauseCheckbox,
            volumeLabel,
            volumeSlider,
            footerStatusLabel
        ])
        rightStack.orientation = .vertical
        rightStack.alignment = .leading
        rightStack.spacing = 14

        // Main Split Content
        let leftStack = NSStackView(views: [previewBox, importButton])
        leftStack.orientation = .vertical
        leftStack.spacing = 12

        let mainContentStack = NSStackView(views: [leftStack, rightStack])
        mainContentStack.orientation = .horizontal
        mainContentStack.spacing = 24
        mainContentStack.distribution = .fillEqually

        let rootStack = NSStackView(views: [headerStack, NSBox(), mainContentStack])
        rootStack.orientation = .vertical
        rootStack.spacing = 16
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            rootStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            previewBox.heightAnchor.constraint(equalToConstant: 220)
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
        WallpaperController.shared.onWallpaperChanged = { [weak self] url in
            DispatchQueue.main.async {
                self?.fileNameLabel.stringValue = url?.lastPathComponent ?? "No Wallpaper Selected"
                self?.filePathLabel.stringValue = url?.path ?? ""
                self?.playPauseButton.title = "Pause"
                self?.footerStatusLabel.stringValue = "Status: Active Playback"
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
                self?.footerStatusLabel.stringValue = "Status: Processing \(selectedURL.lastPathComponent)..."
                WallpaperController.shared.importAndApplyWallpaper(from: selectedURL) { res in
                    DispatchQueue.main.async {
                        switch res {
                        case .success(let appliedURL):
                            self?.fileNameLabel.stringValue = appliedURL.lastPathComponent
                            self?.filePathLabel.stringValue = appliedURL.path
                            self?.playPauseButton.title = "Pause"
                            self?.footerStatusLabel.stringValue = "Status: Applied \(appliedURL.lastPathComponent)"
                        case .failure(let err):
                            self?.footerStatusLabel.stringValue = "Error: \(err.localizedDescription)"
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
        AppLogger.shared.info("AutoPause toggled via checkbox: \(isEnabled)")
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
