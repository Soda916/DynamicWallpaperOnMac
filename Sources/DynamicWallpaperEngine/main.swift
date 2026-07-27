import AppKit
import SwiftUI
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
        menu.addItem(NSMenuItem(title: "Open Dashboard", action: #selector(openDashboard), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Mute Sound", action: #selector(toggleMute), keyEquivalent: "m"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit DynamicWallpaperEngine", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func statusItemClicked() {
        openDashboard()
    }

    @objc private func openDashboard() {
        if mainWindow == nil {
            let contentView = NSHostingView(rootView: MainDashboardView())
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 550),
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
        AppLogger.shared.info("Mute state toggled to: \(config.isMuted)")
    }

    @objc private func quitApp() {
        AppLogger.shared.info("Application quitting via Menu Bar...")
        NSApp.terminate(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Return false to keep app running in Menu Bar when GUI window is closed
        return false
    }
}

struct MainDashboardView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text("Dynamic Wallpaper Engine")
                .font(.title)
                .fontWeight(.bold)
            Text("macOS Native, Extreme Low Resource, Open Source Dynamic Wallpaper Runtime")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 600, minHeight: 400)
        .padding()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
