import Foundation
import ServiceManagement

public final class LaunchAtLoginManager {
    public static let shared = LaunchAtLoginManager()

    private init() {}

    public var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return false
        }
    }

    public func setEnabled(_ enabled: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
                AppLogger.shared.info("[LAUNCH_AT_LOGIN] Successfully set launch at login to \(enabled)")
                return true
            } catch {
                AppLogger.shared.error("[LAUNCH_AT_LOGIN] Failed to toggle launch at login: \(error.localizedDescription)")
                return false
            }
        } else {
            AppLogger.shared.info("[LAUNCH_AT_LOGIN] SMAppService requires macOS 13.0+")
            return false
        }
    }

    public func syncWithConfig(_ configEnabled: Bool) {
        if isEnabled != configEnabled {
            _ = setEnabled(configEnabled)
        }
    }
}
