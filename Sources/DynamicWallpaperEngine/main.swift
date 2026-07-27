import AppKit
import SwiftUI
import AVFoundation
import DynamicWallpaperCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?
    private var config: AppConfig = AppConfig()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLogger.shared.info("DynamicWallpaperEngine starting up...")

        // Configure Dock icon visibility according to user preference (Default: hidden Menu Bar App)
        if config.hideDockIcon {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }

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
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Video Wallpaper or GIF"
        openPanel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie, .gif]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false

        openPanel.begin { result in
            if result == .OK, let selectedURL = openPanel.url {
                WallpaperController.shared.importAndApplyWallpaper(from: selectedURL)
            }
        }
    }

    @objc private func togglePlayPause() {
        WallpaperController.shared.togglePlayPause()
    }

    @objc private func openDashboard() {
        if mainWindow == nil {
            let contentView = NSHostingView(rootView: MainDashboardView())
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 850, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Dynamic Wallpaper Engine"
            window.center()
            window.contentView = contentView
            window.isReleasedWhenClosed = false
            mainWindow = window
        }

        mainWindow?.makeKeyAndOrderFront(nil)
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

struct MainDashboardView: View {
    @State private var currentWallpaperURL: URL? = WallpaperController.shared.activeWallpaperURL
    @State private var isPlaying: Bool = WallpaperController.shared.playbackCore.isPlaying
    @State private var isMuted: Bool = false
    @State private var volume: Float = 1.0
    @State private var isAutoPaused: Bool = WallpaperController.shared.autoPauseEngine.isPaused
    @State private var statusMessage: String = "Ready"

    var body: some View {
        VStack(spacing: 20) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dynamic Wallpaper Engine")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("macOS Native, Extreme Low Resource, Open Source Dynamic Wallpaper Runtime")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Auto Pause Status Badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(isAutoPaused ? Color.orange : Color.green)
                        .frame(width: 10, height: 10)
                    Text(isAutoPaused ? "Auto-Paused (Fullscreen)" : "Active Playback")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(12)
            }

            Divider()

            // Main Content Area
            HStack(spacing: 20) {
                // Left Side: Selected Wallpaper Preview Box
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.8))
                            .frame(height: 240)

                        if let url = currentWallpaperURL {
                            VStack(spacing: 8) {
                                Image(systemName: "film.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)
                                Text(url.lastPathComponent)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(url.path)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 44))
                                    .foregroundColor(.gray)
                                Text("No Wallpaper Selected")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                Text("Click below to import MP4, MOV, WEBM or GIF")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Import Button
                    Button(action: importWallpaper) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Import / Select Wallpaper Video...")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                // Right Side: Control & Options Panel
                VStack(alignment: .leading, spacing: 16) {
                    Text("Playback Controls")
                        .font(.headline)

                    // Play / Pause Toggle
                    HStack {
                        Button(action: togglePlayPause) {
                            HStack {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                Text(isPlaying ? "Pause" : "Play")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: toggleMute) {
                            HStack {
                                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                Text(isMuted ? "Unmute" : "Mute")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }

                    // Volume Slider
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Volume: \(Int(volume * 100))%")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Slider(value: $volume, in: 0.0...1.0) { _ in
                            WallpaperController.shared.setVolume(volume)
                        }
                    }

                    Divider()

                    // Status Bar Footer
                    Text("Status: \(statusMessage)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
        }
        .frame(minWidth: 800, minHeight: 500)
        .padding(24)
        .onAppear {
            setupObservers()
        }
    }

    private func importWallpaper() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Video Wallpaper or GIF"
        openPanel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie, .gif]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false

        openPanel.begin { result in
            if result == .OK, let selectedURL = openPanel.url {
                statusMessage = "Processing \(selectedURL.lastPathComponent)..."
                WallpaperController.shared.importAndApplyWallpaper(from: selectedURL) { res in
                    switch res {
                    case .success(let appliedURL):
                        currentWallpaperURL = appliedURL
                        isPlaying = true
                        statusMessage = "Applied \(appliedURL.lastPathComponent)"
                    case .failure(let err):
                        statusMessage = "Error: \(err.localizedDescription)"
                    }
                }
            }
        }
    }

    private func togglePlayPause() {
        WallpaperController.shared.togglePlayPause()
        isPlaying = WallpaperController.shared.playbackCore.isPlaying
    }

    private func toggleMute() {
        isMuted.toggle()
        WallpaperController.shared.setMuted(isMuted)
    }

    private func setupObservers() {
        WallpaperController.shared.onWallpaperChanged = { url in
            currentWallpaperURL = url
            isPlaying = true
        }
        WallpaperController.shared.autoPauseEngine.onPauseStateChanged = { paused in
            isAutoPaused = paused
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
