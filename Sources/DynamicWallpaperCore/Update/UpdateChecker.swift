import Foundation
import AppKit

public extension Notification.Name {
    static let appUpdateAvailable = Notification.Name("appUpdateAvailable")
}

/// Checks GitHub Releases API for non-intrusive update notifications and handles version comparison and update alerts.
public final class UpdateChecker {
    public static let shared = UpdateChecker()

    public struct ReleaseInfo: Codable {
        public let tagName: String
        public let htmlUrl: String
        public let body: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlUrl = "html_url"
            case body
        }
    }

    public static var currentAppVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.4-alpha"
    }

    private init() {}

    /// Starts Sparkle auto-update engine and triggers update check via raw GitHub appcast feed.
    public func checkForUpdates(repositoryOwner: String = "Soda916", repositoryName: String = "DynamicWallpaperOnMac", completion: ((Result<ReleaseInfo, Error>) -> Void)? = nil) {
        SparkleUpdaterManager.shared.start(startingUpdater: true)
        SparkleUpdaterManager.shared.checkForUpdates()
    }

    /// Compares two version strings (e.g. "v0.1.3" vs "0.1.2-alpha")
    public func isVersionNewer(latest: String, current: String) -> Bool {
        let cleanLatest = latest.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let cleanCurrent = current.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        return cleanLatest.compare(cleanCurrent, options: .numeric) == .orderedDescending
    }

    /// Presents a non-intrusive macOS NSAlert modal prompting the user to view or download the update.
    public func presentUpdateAlert(for release: ReleaseInfo) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "✨ 新版本可供更新 (\(release.tagName))"
            alert.informativeText = "DynamicWallpaperEngine 有新版本公開！\n\n更新說明：\n\(release.body.prefix(300))"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "前往 GitHub 下載")
            alert.addButton(withTitle: "稍後提醒")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(string: release.htmlUrl) {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}

