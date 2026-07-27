import AppKit
import AVFoundation

/// Manages multi-monitor topologies and screen parameter changes (plug/unplug).
public final class DisplayManager {
    public static let shared = DisplayManager()

    private(set) var controllers: [NSScreen: DesktopWindowController] = [:]
    private var screenNotificationObserver: NSObjectProtocol?

    private init() {
        setupScreenNotifications()
    }

    deinit {
        if let observer = screenNotificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public func updateScreens(with player: AVPlayer) {
        // Remove existing controllers for disconnected screens
        let currentScreens = Set(NSScreen.screens)
        let existingScreens = Set(controllers.keys)

        for removedScreen in existingScreens.subtracting(currentScreens) {
            controllers[removedScreen]?.close()
            controllers.removeValue(forKey: removedScreen)
            AppLogger.shared.info("DisplayManager: Screen disconnected, closed desktop window")
        }

        // Attach controllers to connected screens
        for screen in currentScreens {
            if controllers[screen] == nil {
                let controller = DesktopWindowController(screen: screen)
                controller.setPlayer(player)
                controller.showWindow(nil)
                controllers[screen] = controller
                AppLogger.shared.info("DisplayManager: Attached desktop window to screen: \(screen.localizedName)")
            }
        }
    }

    private func setupScreenNotifications() {
        screenNotificationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            AppLogger.shared.info("DisplayManager: Screen configuration changed")
        }
    }
}
