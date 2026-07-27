import AppKit
import CoreGraphics

/// Monitors system states (Mission Control, Stage Manager, Launchpad, Fullscreen Apps) to trigger auto-pausing.
public final class AutoPauseEngine {
    public static let shared = AutoPauseEngine()

    public var onPauseStateChanged: ((Bool) -> Void)?
    private(set) public var isPaused: Bool = false
    public var isEnabled: Bool = false // Default to false so wallpapers play continuously unless user enables AutoPause

    private var workspaceObserver: NSObjectProtocol?
    private var timer: Timer?

    private init() {
        setupObservers()
    }

    deinit {
        stopMonitoring()
    }

    public func startMonitoring() {
        timer?.invalidate()
        // Poll system states at a low frequency (1Hz) to maintain near zero CPU footprint
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.evaluateAutoPauseConditions()
        }
    }

    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func setupObservers() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObserver = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.evaluateAutoPauseConditions()
        }
    }

    /// Evaluates active window configurations to determine if live wallpaper rendering should pause.
    public func evaluateAutoPauseConditions() {
        guard isEnabled else {
            if isPaused {
                isPaused = false
                AppLogger.shared.info("AutoPauseEngine: AutoPause disabled, resuming playback")
                onPauseStateChanged?(false)
            }
            return
        }

        var shouldPause = false

        // Check if frontmost app is in native macOS Fullscreen mode
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            if isAppNativeFullscreen(app: frontmostApp) {
                shouldPause = true
            }
        }

        // State transition evaluation
        if shouldPause != isPaused {
            isPaused = shouldPause
            AppLogger.shared.info("AutoPauseEngine: State changed. Paused = \(isPaused)")
            onPauseStateChanged?(isPaused)
        }
    }

    private func isAppNativeFullscreen(app: NSRunningApplication) -> Bool {
        // Exclude Finder and our own application PID
        if app.bundleIdentifier == "com.apple.finder" || app.processIdentifier == NSRunningApplication.current.processIdentifier {
            return false
        }

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        guard let mainScreen = NSScreen.main else { return false }
        let mainScreenBounds = mainScreen.frame

        for info in windowInfoList {
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid == app.processIdentifier else {
                continue
            }
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else {
                continue
            }
            if let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
               let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) {
                // If window bounds match or exceed main screen bounds
                if bounds.width >= mainScreenBounds.width && bounds.height >= mainScreenBounds.height {
                    return true
                }
            }
        }
        return false
    }
}
