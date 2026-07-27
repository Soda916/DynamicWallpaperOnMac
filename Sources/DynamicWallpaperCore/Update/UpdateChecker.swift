import Foundation

/// Checks GitHub Releases API for non-intrusive update notifications.
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

    private init() {}

    /// Checks latest release version from GitHub API asynchronously.
    public func checkForUpdates(repositoryOwner: String, repositoryName: String, completion: @escaping (Result<ReleaseInfo, Error>) -> Void) {
        let urlString = "https://api.github.com/repos/\(repositoryOwner)/\(repositoryName)/releases/latest"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "UpdateChecker", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid GitHub repository URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "UpdateChecker", code: 500, userInfo: [NSLocalizedDescriptionKey: "No data returned from update API"])))
                return
            }

            do {
                let release = try JSONDecoder().decode(ReleaseInfo.self, from: data)
                completion(.success(release))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
