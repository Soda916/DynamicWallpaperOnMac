import AppKit
import CoreGraphics

/// Monitors system states (Mission Control, Stage Manager, Launchpad, Fullscreen Apps) to trigger auto-pausing.
public final class AutoPauseEngine {
    public static let shared = AutoPauseEngine()

    public var onPauseStateChanged: ((Bool) -> Void)?
    private(set) public var isPaused: Bool = false

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
        var shouldPause = false

        // 1. Check if the frontmost app is running in native Fullscreen mode
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            if isAppFullscreen(app: frontmostApp) {
                shouldPause = true
            }
        }

        // 2. State transition evaluation
        if shouldPause != isPaused {
            isPaused = shouldPause
            AppLogger.shared.info("AutoPauseEngine: State changed. Paused = \(isPaused)")
            onPauseStateChanged?(isPaused)
        }
    }

    private func isAppFullscreen(app: NSRunningApplication) -> Bool {
        // Exclude Finder desktop itself
        if app.bundleIdentifier == "com.apple.finder" {
            return false
        }

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        let mainScreenBounds = NSScreen.main?.frame ?? .zero
        for info in windowInfoList {
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid == app.processIdentifier else {
                continue
            }
            if let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
               let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) {
                // If frontmost window bounds cover or exceed main screen bounds, treat as Fullscreen
                if bounds.width >= mainScreenBounds.width && bounds.height >= mainScreenBounds.height {
                    return true
                }
            }
        }
        return false
    }
}
