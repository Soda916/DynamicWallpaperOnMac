import AppKit
import AVFoundation

public extension NSScreen {
    /// Unique and persistent CGDirectDisplayID for this display (compatible with Sidecar and hotplugged monitors).
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (deviceDescription[key] as? NSNumber)?.uint32Value ?? 0
    }
}

/// Manages multi-monitor topologies and screen parameter changes (plug/unplug, Sidecar, resolution changes).
public final class DisplayManager {
    public static let shared = DisplayManager()

    private(set) public var controllers: [CGDirectDisplayID: DesktopWindowController] = [:]
    private var screenNotificationObserver: NSObjectProtocol?
    private weak var activePlayer: AVPlayer?

    private init() {
        setupScreenNotifications()
    }

    deinit {
        if let observer = screenNotificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Updates desktop window controllers for all connected screens using the shared AVPlayer.
    public func updateScreens(with player: AVPlayer) {
        self.activePlayer = player
        let currentScreens = NSScreen.screens
        let currentDisplayIDs = Set(currentScreens.map { $0.displayID })
        let existingDisplayIDs = Set(controllers.keys)

        // 1. Remove controllers for disconnected screens
        for removedID in existingDisplayIDs.subtracting(currentDisplayIDs) {
            controllers[removedID]?.close()
            controllers.removeValue(forKey: removedID)
            AppLogger.shared.info("[DISPLAY] Screen (ID: \(removedID)) disconnected, closed desktop window")
        }

        // 2. Update existing controllers or create new ones for all connected screens
        for screen in currentScreens {
            let id = screen.displayID
            if let existingController = controllers[id] {
                // Screen already has a controller: update its frame, bounds, and player layer
                existingController.updateScreenAndFrame(screen: screen)
                existingController.setPlayer(player)
                AppLogger.shared.info("[DISPLAY] Updated existing window for '\(screen.localizedName)' (ID: \(id)) to frame: \(screen.frame)")
            } else {
                // New screen detected (e.g. Sidecar or newly plugged HDMI/DisplayPort monitor)
                let controller = DesktopWindowController(screen: screen)
                controllers[id] = controller
                controller.setPlayer(player)
                controller.showWindow(nil)
                controller.window?.orderFrontRegardless()
                AppLogger.shared.info("[DISPLAY] Attached new desktop window for '\(screen.localizedName)' (ID: \(id)), frame: \(screen.frame)")
            }
        }
    }

    private func setupScreenNotifications() {
        screenNotificationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            AppLogger.shared.info("[DISPLAY] Screen parameters changed (Sidecar/plug/unplug/resolution). Refreshing displays...")
            
            if let player = self.activePlayer {
                self.updateScreens(with: player)
            }

            // Sidecar and wireless displays often need 0.5s for Quartz WindowServer framebuffer stabilization
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, let player = self.activePlayer else { return }
                AppLogger.shared.info("[DISPLAY] Secondary display stabilization check after Sidecar/resolution change...")
                self.updateScreens(with: player)
            }
        }
    }
}
