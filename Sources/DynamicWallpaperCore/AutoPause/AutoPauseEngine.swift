import AppKit
import CoreGraphics

public extension Notification.Name {
    static let autoPausePauseStateDidChange = Notification.Name("autoPausePauseStateDidChange")
}

public final class AutoPauseEngine {
    public static let shared = AutoPauseEngine()

    private(set) public var isPaused: Bool = false
    public var isEnabled: Bool = false {
        didSet {
            evaluateAutoPauseConditions()
        }
    }

    private var workspaceObserver: NSObjectProtocol?
    private var activateObserver: NSObjectProtocol?
    private var timer: Timer?
    private var lastFrontmostBundleID: String?
    private var lastFrontmostWindowBounds: CGRect?

    private init() {
        setupObservers()
    }

    deinit {
        stopMonitoring()
    }

    public func startMonitoring() {
        timer?.invalidate()
        
        // Dump all screen info on startup
        AppLogger.shared.info("[AUTOPAUSE-DEBUG] ====== STARTUP SCREEN DUMP ======")
        for (i, screen) in NSScreen.screens.enumerated() {
            let f = screen.frame
            let v = screen.visibleFrame
            AppLogger.shared.info("[AUTOPAUSE-DEBUG] Screen[\(i)] '\(screen.localizedName)': frame=(\(f.origin.x), \(f.origin.y), \(f.size.width), \(f.size.height)) visibleFrame=(\(v.origin.x), \(v.origin.y), \(v.size.width), \(v.size.height))")
        }
        
        // Dump current frontmost app info
        if let front = NSWorkspace.shared.frontmostApplication {
            AppLogger.shared.info("[AUTOPAUSE-DEBUG] Current frontmost app: '\(front.localizedName ?? "unknown")' bundle='\(front.bundleIdentifier ?? "nil")' pid=\(front.processIdentifier)")
            dumpWindowBounds(for: front)
        } else {
            AppLogger.shared.info("[AUTOPAUSE-DEBUG] No frontmost application detected at startup")
        }
        AppLogger.shared.info("[AUTOPAUSE-DEBUG] AutoPause isEnabled=\(isEnabled)")
        AppLogger.shared.info("[AUTOPAUSE-DEBUG] ====== END STARTUP DUMP ======")
        
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
        ) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                AppLogger.shared.info("[AUTOPAUSE-DEBUG] [FOCUS CHANGED] New frontmost: '\(app.localizedName ?? "unknown")' bundle='\(app.bundleIdentifier ?? "nil")' pid=\(app.processIdentifier)")
                self?.dumpWindowBounds(for: app)
            }
            self?.evaluateAutoPauseConditions()
        }
    }

    private func dumpWindowBounds(for app: NSRunningApplication) {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            AppLogger.shared.info("[AUTOPAUSE-DEBUG]   -> CGWindowListCopyWindowInfo returned nil")
            return
        }
        
        var windowCount = 0
        for info in windowInfoList {
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid == app.processIdentifier else {
                continue
            }
            let layer = info[kCGWindowLayer as String] as? Int ?? -999
            let name = info[kCGWindowName as String] as? String ?? "<no name>"
            if let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
               let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) {
                AppLogger.shared.info("[AUTOPAUSE-DEBUG]   -> Window[\(windowCount)] layer=\(layer) name='\(name)' bounds=(\(bounds.origin.x), \(bounds.origin.y), \(bounds.size.width), \(bounds.size.height))")
            } else {
                AppLogger.shared.info("[AUTOPAUSE-DEBUG]   -> Window[\(windowCount)] layer=\(layer) name='\(name)' bounds=<unavailable>")
            }
            windowCount += 1
        }
        if windowCount == 0 {
            AppLogger.shared.info("[AUTOPAUSE-DEBUG]   -> No on-screen windows found for this app")
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
            let appName = frontmostApp.localizedName ?? "unknown"
            let bundleID = frontmostApp.bundleIdentifier ?? "nil"
            
            let result = isAppMaximizedOrFullscreen(app: frontmostApp)
            shouldPause = result
            
            // Detect window resize by comparing bounds
            let currentBounds = getFrontmostWindowBounds(app: frontmostApp)
            let currentBundleID = frontmostApp.bundleIdentifier
            
            if currentBundleID == lastFrontmostBundleID {
                if let old = lastFrontmostWindowBounds, let new = currentBounds, old != new {
                    AppLogger.shared.info("[AUTOPAUSE-DEBUG] [RESIZE DETECTED] App '\(appName)' window resized from (\(old.origin.x), \(old.origin.y), \(old.size.width), \(old.size.height)) to (\(new.origin.x), \(new.origin.y), \(new.size.width), \(new.size.height))")
                }
            } else {
                // App focus changed
                AppLogger.shared.debug("[AUTOPAUSE-DEBUG] Frontmost app changed to '\(appName)' bundle='\(bundleID)'")
            }
            
            lastFrontmostBundleID = currentBundleID
            lastFrontmostWindowBounds = currentBounds
            
            AppLogger.shared.debug("[AUTOPAUSE-DEBUG] [TICK] frontmost='\(appName)' bundle='\(bundleID)' isMaxOrFS=\(result) shouldPause=\(shouldPause) currentlyPaused=\(isPaused)")
        } else {
            AppLogger.shared.debug("[AUTOPAUSE-DEBUG] [TICK] No frontmost app")
        }

        if shouldPause != isPaused {
            isPaused = shouldPause
            AppLogger.shared.info("AutoPauseEngine: State changed. Paused = \(isPaused)")
            NotificationCenter.default.post(name: .autoPausePauseStateDidChange, object: isPaused)
        }
    }
    
    private func getFrontmostWindowBounds(app: NSRunningApplication) -> CGRect? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        for info in windowInfoList {
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid == app.processIdentifier else {
                continue
            }
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else {
                continue
            }
            if let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
               let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) {
                return bounds
            }
        }
        return nil
    }

    private func isAppMaximizedOrFullscreen(app: NSRunningApplication) -> Bool {
        if app.bundleIdentifier == "com.apple.finder" || app.processIdentifier == NSRunningApplication.current.processIdentifier {
            AppLogger.shared.debug("[AUTOPAUSE-DEBUG]   Skipping app (Finder or self)")
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
                
                let isFullscreen = bounds.width >= screenFrame.width - 10 && bounds.height >= screenFrame.height - 10
                let isMaximized = bounds.width >= visibleFrame.width - 20 && bounds.height >= visibleFrame.height - 20
                
                if isFullscreen || isMaximized {
                    AppLogger.shared.info("[AUTOPAUSE-DEBUG]   MATCH: '\(app.localizedName ?? "?")' window bounds=(\(bounds.width)x\(bounds.height)) vs screen=(\(screenFrame.width)x\(screenFrame.height)) visible=(\(visibleFrame.width)x\(visibleFrame.height)) fullscreen=\(isFullscreen) maximized=\(isMaximized)")
                    return true
                }
            }
        }
        return false
    }
}
