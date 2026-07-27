import Foundation
import os

/// Thread-safe logger for DynamicWallpaperEngine with verbose console logging and live UI stream callbacks.
public final class AppLogger: @unchecked Sendable {
    public static let shared = AppLogger()

    private let logger = Logger(subsystem: "com.antigravity.DynamicWallpaperEngine", category: "Core")
    private let fileManager = FileManager.default
    private let logDirectory: URL
    private let debugLogURL: URL
    private let errorLogURL: URL
    private let lock = NSLock()

    public private(set) var recentLogs: [String] = []
    public var onLogAdded: ((String) -> Void)?

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        logDirectory = appSupport.appendingPathComponent("DynamicWallpaperEngine/Logs", isDirectory: true)
        debugLogURL = logDirectory.appendingPathComponent("debug.log")
        errorLogURL = logDirectory.appendingPathComponent("error.log")

        try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
    }

    public func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
        logFormatted(prefix: "[DEBUG]", message: message)
    }

    public func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        logFormatted(prefix: "[INFO]", message: message)
    }

    public func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        logFormatted(prefix: "[ERROR]", message: message)
        appendToFile(url: errorLogURL, prefix: "[ERROR]", message: message)
    }

    public func verbose(_ message: String) {
        logger.debug("[VERBOSE] \(message, privacy: .public)")
        logFormatted(prefix: "[VERBOSE]", message: message)
    }

    private func logFormatted(prefix: String, message: String) {
        lock.lock()
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(timestamp) \(prefix) \(message)"
        
        // Print to stdout for immediate terminal feedback
        print(line)
        
        recentLogs.append(line)
        if recentLogs.count > 300 {
            recentLogs.removeFirst()
        }
        lock.unlock()

        appendToFile(url: debugLogURL, prefix: prefix, message: message)
        
        DispatchQueue.main.async { [weak self] in
            self?.onLogAdded?(line)
        }
    }

    private func appendToFile(url: URL, prefix: String, message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logLine = "\(timestamp) \(prefix) \(message)\n"
        guard let data = logLine.data(using: .utf8) else { return }

        if fileManager.fileExists(atPath: url.path) {
            if let fileHandle = try? FileHandle(forWritingTo: url) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                try? fileHandle.close()
            }
        } else {
            try? data.write(to: url)
        }
    }
}
