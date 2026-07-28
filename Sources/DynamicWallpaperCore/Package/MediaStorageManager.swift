import Foundation

/// Centralized media storage manager that handles copying, symlinking, hardlinking, moving, and organizing wallpaper media in ~/.dynamicwallpaper/media/
public final class MediaStorageManager {
    public static let shared = MediaStorageManager()

    private let fileManager = FileManager.default

    /// Standard hidden directory for centralized wallpaper media storage
    public var defaultMediaDirectory: URL {
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let hiddenDir = homeDir.appendingPathComponent(".dynamicwallpaper/media", isDirectory: true)
        try? fileManager.createDirectory(at: hiddenDir, withIntermediateDirectories: true)
        return hiddenDir
    }

    private init() {}

    /// Processes an imported media file according to the selected storage mode.
    /// Returns the target URL where the wallpaper should be loaded from.
    public func processImportedMedia(from sourceURL: URL, mode: MediaStorageMode) -> Result<URL, Error> {
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            return .failure(NSError(domain: "MediaStorageManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Source file missing at \(sourceURL.path)"]))
        }

        if mode == .direct {
            return .success(sourceURL)
        }

        let mediaDir = defaultMediaDirectory
        let fileName = sourceURL.lastPathComponent
        let destinationURL = mediaDir.appendingPathComponent(fileName)

        // If source is already in media directory, return as is
        if sourceURL.path == destinationURL.path {
            return .success(destinationURL)
        }

        do {
            // Remove existing destination if it's broken or needs replacement
            if fileManager.fileExists(atPath: destinationURL.path) {
                // If destination matches source file size and modification date, reuse
                if isSameFile(url1: sourceURL, url2: destinationURL) {
                    return .success(destinationURL)
                }
                try fileManager.removeItem(at: destinationURL)
            }

            switch mode {
            case .copy:
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                AppLogger.shared.info("[MEDIA-STORAGE] Copied media file to \(destinationURL.path)")
            case .symlink:
                try fileManager.createSymbolicLink(at: destinationURL, withDestinationURL: sourceURL)
                AppLogger.shared.info("[MEDIA-STORAGE] Created symbolic link at \(destinationURL.path) -> \(sourceURL.path)")
            case .hardlink:
                try fileManager.linkItem(at: sourceURL, to: destinationURL)
                AppLogger.shared.info("[MEDIA-STORAGE] Created hard link at \(destinationURL.path)")
            case .move:
                try fileManager.moveItem(at: sourceURL, to: destinationURL)
                AppLogger.shared.info("[MEDIA-STORAGE] Moved media file to \(destinationURL.path)")
            case .direct:
                return .success(sourceURL)
            }

            return .success(destinationURL)
        } catch {
            AppLogger.shared.error("[MEDIA-STORAGE] Failed to process media with mode '\(mode.rawValue)': \(error.localizedDescription)")
            return .failure(error)
        }
    }

    private func isSameFile(url1: URL, url2: URL) -> Bool {
        guard let attr1 = try? fileManager.attributesOfItem(atPath: url1.path),
              let attr2 = try? fileManager.attributesOfItem(atPath: url2.path) else {
            return false
        }
        let size1 = attr1[.size] as? Int64 ?? 0
        let size2 = attr2[.size] as? Int64 ?? 0
        return size1 == size2 && size1 > 0
    }
}
