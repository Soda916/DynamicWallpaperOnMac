import AppKit
import CoreGraphics

public extension Notification.Name {
    static let autoPausePauseStateDidChange = Notification.Name("autoPausePauseStateDidChange")
}

/// Monitors system states (Mission Control, Stage Manager, Launchpad, Fullscreen Apps, Option+Green Button Zoom) to trigger auto-pausing.
public final class AutoPauseEngine {
    public static let shared = AutoPauseEngine()

    private(set) public var isPaused: Bool = false
    public var isEnabled: Bool = false {
        didSet {
            evaluateAutoPauseConditions()
        }
    }

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

    public func evaluateAutoPauseConditions() {
        guard isEnabled else {
            if isPaused {
                isPaused = false
                AppLogger.shared.info("AutoPauseEngine: AutoPause disabled, resuming playback")
                NotificationCenter.default.post(name: .autoPausePauseStateDidChange, object: false)
            }
            return
        }

        var shouldPause = false

        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            if isAppMaximizedOrFullscreen(app: frontmostApp) {
                shouldPause = true
            }
        }

        if shouldPause != isPaused {
            isPaused = shouldPause
            AppLogger.shared.info("AutoPauseEngine: State changed. Paused = \(isPaused)")
            NotificationCenter.default.post(name: .autoPausePauseStateDidChange, object: isPaused)
        }
    }

    private func isAppMaximizedOrFullscreen(app: NSRunningApplication) -> Bool {
        if app.bundleIdentifier == "com.apple.finder" || app.processIdentifier == NSRunningApplication.current.processIdentifier {
            return false
        }

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        guard let mainScreen = NSScreen.main else { return false }
        let screenFrame = mainScreen.frame
        let visibleFrame = mainScreen.visibleFrame

        for info in windowInfoList {
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid == app.processIdentifier else {
                continue
            }
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else {
                continue
            }
            if let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
               let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) {
                if bounds.width >= screenFrame.width - 10 && bounds.height >= screenFrame.height - 10 {
                    return true
                }
                if bounds.width >= visibleFrame.width - 20 && bounds.height >= visibleFrame.height - 20 {
                    return true
                }
            }
        }
        return false
    }
}
