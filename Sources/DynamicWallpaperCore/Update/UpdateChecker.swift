import Foundation
import AppKit

public extension Notification.Name {
    static let appUpdateAvailable = Notification.Name("appUpdateAvailable")
}

/// Checks GitHub Releases API for non-intrusive update notifications and handles version comparison and update alerts.
public final class UpdateChecker: @unchecked Sendable {
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
        performLocalizedUpdateCheck(explicitUserInitiated: false, completion: completion)
    }

    /// Performs an asynchronous update check against GitHub API with full multi-language alert modals.
    public func performLocalizedUpdateCheck(explicitUserInitiated: Bool = true, completion: ((Result<ReleaseInfo, Error>) -> Void)? = nil) {
        // Also trigger Sparkle updater controller for native appcast support
        SparkleUpdaterManager.shared.start(startingUpdater: true)
        SparkleUpdaterManager.shared.checkForUpdates()

        guard let url = URL(string: "https://api.github.com/repos/\(repositoryOwner)/\(repositoryName)/releases/latest") else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 8.0

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                AppLogger.shared.error("[UPDATE-CHECKER] Failed to fetch GitHub release info: \(error.localizedDescription)")
                if explicitUserInitiated {
                    self.presentErrorAlert(error: error)
                }
                completion?(.failure(error))
                return
            }

            guard let data = data, let release = try? JSONDecoder().decode(ReleaseInfo.self, from: data) else {
                let err = NSError(domain: "UpdateChecker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid release data payload"])
                if explicitUserInitiated {
                    self.presentErrorAlert(error: err)
                }
                completion?(.failure(err))
                return
            }

            let isNewer = self.isVersionNewer(latest: release.tagName, current: UpdateChecker.currentAppVersion)
            if isNewer {
                AppLogger.shared.info("[UPDATE-CHECKER] New release found: \(release.tagName) (Current: \(UpdateChecker.currentAppVersion))")
                self.presentUpdateAlert(for: release)
                completion?(.success(release))
            } else {
                AppLogger.shared.info("[UPDATE-CHECKER] App is up to date: \(UpdateChecker.currentAppVersion)")
                if explicitUserInitiated {
                    self.presentNoUpdateAlert()
                }
                completion?(.success(release))
            }
        }.resume()
    }

    private var repositoryOwner: String { "Soda916" }
    private var repositoryName: String { "DynamicWallpaperOnMac" }

    /// Compares two version strings (e.g. "v0.1.4-alpha" vs "v0.1.3")
    public func isVersionNewer(latest: String, current: String) -> Bool {
        let cleanLatest = latest.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let cleanCurrent = current.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        return cleanLatest.compare(cleanCurrent, options: .numeric) == .orderedDescending
    }

    /// Presents a non-intrusive macOS NSAlert modal in user's active language when an update is available.
    public func presentUpdateAlert(for release: ReleaseInfo) {
        DispatchQueue.main.async {
            let loc = LocalizationManager.shared
            let alert = NSAlert()
            alert.messageText = loc.localized("update_alert_title", release.tagName)
            let releaseNotes = release.body.isEmpty ? "v\(release.tagName)" : String(release.body.prefix(400))
            alert.informativeText = loc.localized("update_alert_info", releaseNotes)
            alert.alertStyle = .informational
            alert.addButton(withTitle: loc.localized("update_alert_download"))
            alert.addButton(withTitle: loc.localized("update_alert_later"))

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(string: release.htmlUrl) {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    /// Presents a localized NSAlert modal indicating the application is currently running the latest version.
    public func presentNoUpdateAlert() {
        DispatchQueue.main.async {
            let loc = LocalizationManager.shared
            let alert = NSAlert()
            alert.messageText = loc.localized("update_alert_no_update_title")
            alert.informativeText = loc.localized("update_alert_no_update_info", UpdateChecker.currentAppVersion)
            alert.alertStyle = .informational
            alert.addButton(withTitle: loc.localized("update_alert_ok"))
            alert.runModal()
        }
    }

    /// Presents a localized NSAlert modal indicating update check failure.
    public func presentErrorAlert(error: Error) {
        DispatchQueue.main.async {
            let loc = LocalizationManager.shared
            let alert = NSAlert()
            alert.messageText = loc.localized("update_alert_error_title")
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: loc.localized("update_alert_ok"))
            alert.runModal()
        }
    }
}
