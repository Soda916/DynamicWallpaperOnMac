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

    public static let currentAppVersion = "0.1.2-alpha"

    private init() {}

    /// Checks latest release version from GitHub API asynchronously.
    public func checkForUpdates(repositoryOwner: String = "dustlee", repositoryName: String = "DynamicWallPaper", completion: ((Result<ReleaseInfo, Error>) -> Void)? = nil) {
        let urlString = "https://api.github.com/repos/\(repositoryOwner)/\(repositoryName)/releases/latest"
        guard let url = URL(string: urlString) else {
            completion?(.failure(NSError(domain: "UpdateChecker", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid GitHub repository URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion?(.failure(error))
                return
            }
            guard let data = data else {
                completion?(.failure(NSError(domain: "UpdateChecker", code: 500, userInfo: [NSLocalizedDescriptionKey: "No data returned from update API"])))
                return
            }

            do {
                let release = try JSONDecoder().decode(ReleaseInfo.self, from: data)
                if let self = self, self.isVersionNewer(latest: release.tagName, current: UpdateChecker.currentAppVersion) {
                    AppLogger.shared.info("[UPDATE-CHECKER] New release available: \(release.tagName)")
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .appUpdateAvailable, object: release)
                    }
                }
                completion?(.success(release))
            } catch {
                completion?(.failure(error))
            }
        }.resume()
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

