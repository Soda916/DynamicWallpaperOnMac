import Foundation

/// Manages system FFmpeg discovery, video codec transcoding, and Homebrew installation guidance.
public final class FFmpegManager {
    public static let shared = FFmpegManager()

    private let fileManager = FileManager.default

    public var isFFmpegAvailable: Bool {
        return findFFmpegURL() != nil
    }

    private init() {}

    /// Returns URL to system FFmpeg binary if present.
    public func findFFmpegURL() -> URL? {
        let candidatePaths = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]

        for path in candidatePaths {
            if fileManager.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        // Try `which ffmpeg` in PATH environment
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ffmpeg"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty, fileManager.fileExists(atPath: path) {
                    return URL(fileURLWithPath: path)
                }
            }
        } catch {}

        return nil
    }

    /// Provides Homebrew install command for user execution when FFmpeg is not installed.
    public var homebrewInstallInstruction: String {
        return "brew install ffmpeg"
    }

    /// Triggers background Homebrew installation of ffmpeg if requested by user.
    public func installFFmpegViaHomebrew(completion: @escaping (Bool, String) -> Void) {
        let brewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        guard let brewPath = brewPaths.first(where: { fileManager.fileExists(atPath: $0) }) else {
            completion(false, "Homebrew binary ('brew') not found on system. Please install Homebrew or install ffmpeg manually.")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = ["install", "ffmpeg"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        AppLogger.shared.info("[FFMPEG-INSTALL] Triggering Homebrew ffmpeg installation: \(brewPath) install ffmpeg")

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                AppLogger.shared.info("[FFMPEG-INSTALL] FFmpeg installation completed successfully!")
                completion(true, "FFmpeg installed successfully.")
            } else {
                AppLogger.shared.error("[FFMPEG-INSTALL] Homebrew install failed: \(output)")
                completion(false, "FFmpeg installation failed: \(output)")
            }
        } catch {
            completion(false, "Failed to launch Homebrew process: \(error.localizedDescription)")
        }
    }
}
