import Foundation
import Sparkle

/// Standard Sparkle Auto-Update Controller for macOS AppKit applications.
/// Configured to fetch raw appcast.xml from GitHub repository:
/// https://raw.githubusercontent.com/Soda916/DynamicWallpaperOnMac/main/appcast.xml
public final class SparkleUpdaterManager: NSObject, SPUUpdaterDelegate, @unchecked Sendable {
    public static let shared = SparkleUpdaterManager()

    public static let appcastURLString = "https://raw.githubusercontent.com/Soda916/DynamicWallpaperOnMac/main/appcast.xml"

    public private(set) var updaterController: SPUStandardUpdaterController?

    private override init() {
        super.init()
    }

    /// Initializes Sparkle Updater Controller with custom Appcast feed URL delegate.
    public func start(startingUpdater: Bool = true) {
        guard updaterController == nil else { return }
        
        let controller = SPUStandardUpdaterController(
            startingUpdater: startingUpdater,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        self.updaterController = controller
        AppLogger.shared.info("[SPARKLE-UPDATER] Initialized Sparkle Auto-Update Manager with feed: \(SparkleUpdaterManager.appcastURLString)")
    }

    /// Triggers user-initiated update check modal dialog
    public func checkForUpdates() {
        if updaterController == nil {
            start(startingUpdater: true)
        }
        updaterController?.checkForUpdates(nil)
    }

    // MARK: - SPUUpdaterDelegate

    public func feedURLString(for updater: SPUUpdater) -> String? {
        return SparkleUpdaterManager.appcastURLString
    }

    public func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        AppLogger.shared.info("[SPARKLE-UPDATER] Successfully loaded appcast XML feed.")
    }

    public func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        AppLogger.shared.info("[SPARKLE-UPDATER] Found valid update: \(item.displayVersionString) [Download URL: \(item.fileURL?.absoluteString ?? "N/A")]")
    }

    public func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        AppLogger.shared.info("[SPARKLE-UPDATER] No new updates found. Current version is up-to-date.")
    }
}
