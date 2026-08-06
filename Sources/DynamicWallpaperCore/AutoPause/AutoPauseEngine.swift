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

    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var timer: Timer?
    private var ownPID: pid_t = NSRunningApplication.current.processIdentifier

    private(set) public var isScreenSleeping: Bool = false
    private(set) public var isScreenLocked: Bool = false
    private(set) public var isSystemSleeping: Bool = false
    private(set) public var isLowPowerModeEnabled: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled

    private init() {
        setupObservers()
    }

    deinit {
        stopMonitoring()
    }

    public func startMonitoring() {
        timer?.invalidate()
        
        AppLogger.shared.info("[AUTOPAUSE] Started monitoring displays, system sleep, screen lock, and power state.")
        dumpScreenTopology()
        
        // Immediate check and 0.5s delayed check to capture existing windows at launch
        evaluateAutoPauseConditions()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.evaluateAutoPauseConditions()
        }
        
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
        let defaultCenter = NotificationCenter.default
        let distCenter = DistributedNotificationCenter.default()
        
        let obs1 = center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.evaluateAutoPauseConditions()
        }
        let obs2 = center.addObserver(forName: NSWorkspace.didHideApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.evaluateAutoPauseConditions()
        }
        let obs3 = center.addObserver(forName: NSWorkspace.didUnhideApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.evaluateAutoPauseConditions()
        }
        let obs4 = center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.evaluateAutoPauseConditions()
        }
        let obs5 = defaultCenter.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.dumpScreenTopology()
            self?.evaluateAutoPauseConditions()
        }
        
        // Screen Sleep & System Sleep Observers for Autonomous Power Conservation
        let obsSleep = center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            AppLogger.shared.info("[POWER-SAVER] Screens did sleep -> Pausing wallpaper execution.")
            self?.isScreenSleeping = true
            self?.evaluateAutoPauseConditions()
        }
        let obsWake = center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            AppLogger.shared.info("[POWER-SAVER] Screens did wake -> Re-evaluating wallpaper state.")
            self?.isScreenSleeping = false
            self?.evaluateAutoPauseConditions()
        }
        let obsSysSleep = center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            AppLogger.shared.info("[POWER-SAVER] System will sleep -> Freezing playback pipeline.")
            self?.isSystemSleeping = true
            self?.evaluateAutoPauseConditions()
        }
        let obsSysWake = center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            AppLogger.shared.info("[POWER-SAVER] System did wake -> Resuming wallpaper pipeline.")
            self?.isSystemSleeping = false
            self?.evaluateAutoPauseConditions()
        }
        
        // Low Power Mode Observer
        let obsPower = defaultCenter.addObserver(forName: NSNotification.Name.NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            AppLogger.shared.info("[POWER-SAVER] Low Power Mode state changed: \(lowPower)")
            self?.isLowPowerModeEnabled = lowPower
            self?.evaluateAutoPauseConditions()
        }

        // Screen Lock / Unlock Distributed Observers
        let obsLock = distCenter.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            AppLogger.shared.info("[POWER-SAVER] Screen locked -> Entering 0% CPU freeze state.")
            self?.isScreenLocked = true
            self?.evaluateAutoPauseConditions()
        }
        let obsUnlock = distCenter.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            AppLogger.shared.info("[POWER-SAVER] Screen unlocked -> Restoring playback.")
            self?.isScreenLocked = false
            self?.evaluateAutoPauseConditions()
        }

        workspaceObservers = [obs1, obs2, obs3, obs4, obs5, obsSleep, obsWake, obsSysSleep, obsSysWake, obsPower]
        distributedObservers = [obsLock, obsUnlock]
    }

    public func dumpScreenTopology() {
        AppLogger.shared.info("[AUTOPAUSE-DEBUG] ====== SCREEN TOPOLOGY DUMP ======")
        for (i, screen) in NSScreen.screens.enumerated() {
            let f = screen.frame
            let v = screen.visibleFrame
            AppLogger.shared.info("[AUTOPAUSE-DEBUG] Screen[\(i)] '\(screen.localizedName)': frame=\(f) visibleFrame=\(v)")
        }
        AppLogger.shared.info("[AUTOPAUSE-DEBUG] ====== END SCREEN DUMP ======")
    }

    public func evaluateAutoPauseConditions() {
        // Hard Rule: If Screen is Sleeping, Locked, or System is Sleeping -> Always Force Pause (0% CPU/GPU Energy Mode)
        if isScreenSleeping || isScreenLocked || isSystemSleeping {
            if !isPaused {
                isPaused = true
                AppLogger.shared.info("[POWER-SAVER] System off-screen event active (sleep/lock/screensOff) -> Forcing Zero Energy Freeze state.")
                NotificationCenter.default.post(name: .autoPausePauseStateDidChange, object: true)
            }
            return
        }

        guard isEnabled else {
            if isPaused {
                isPaused = false
                AppLogger.shared.info("[AUTOPAUSE] AutoPause disabled, resuming playback")
                NotificationCenter.default.post(name: .autoPausePauseStateDidChange, object: false)
            }
            return
        }

        let shouldPause = checkForFullscreenOrMaximizedWindows()

        if shouldPause != isPaused {
            isPaused = shouldPause
            AppLogger.shared.info("[AUTOPAUSE] State changed -> isPaused = \(isPaused)")
            NotificationCenter.default.post(name: .autoPausePauseStateDidChange, object: isPaused)
        }
    }

    /// Scans all visible on-screen windows across all active displays to detect if any display is covered by a fullscreen or maximized window.
    private func checkForFullscreenOrMaximizedWindows() -> Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return false }

        let primaryScreenHeight = screens.first?.frame.height ?? 0

        for info in windowInfoList {
            // Filter out self process
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID else {
                continue
            }

            let ownerName = info[kCGWindowOwnerName as String] as? String ?? ""
            
            // Skip Finder Desktop background layer
            if ownerName == "Finder" {
                if let windowName = info[kCGWindowName as String] as? String, windowName == "Desktop" {
                    continue
                }
            }

            // Inspect normal window layer (layer == 0)
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else {
                continue
            }

            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let quartzBounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
                continue
            }

            let cocoaBounds = CGRect(
                x: quartzBounds.origin.x,
                y: primaryScreenHeight - (quartzBounds.origin.y + quartzBounds.size.height),
                width: quartzBounds.size.width,
                height: quartzBounds.size.height
            )

            for screen in screens {
                let screenFrame = screen.frame
                let visibleFrame = screen.visibleFrame

                // Check intersection or containment with screen
                let windowCenter = CGPoint(x: cocoaBounds.midX, y: cocoaBounds.midY)
                if screenFrame.contains(windowCenter) || screenFrame.intersects(cocoaBounds) {
                    let isFullscreen = cocoaBounds.width >= screenFrame.width - 15 && cocoaBounds.height >= screenFrame.height - 15
                    let isMaximized = cocoaBounds.width >= visibleFrame.width - 25 && cocoaBounds.height >= visibleFrame.height - 25

                    if isFullscreen || isMaximized {
                        AppLogger.shared.debug("[AUTOPAUSE] Match found: '\(ownerName)' (PID: \(pid)) on screen '\(screen.localizedName)' bounds=(\(cocoaBounds.width)x\(cocoaBounds.height)) screen=(\(screenFrame.width)x\(screenFrame.height)) FS=\(isFullscreen) Max=\(isMaximized)")
                        return true
                    }
                }
            }
        }

        return false
    }
}

