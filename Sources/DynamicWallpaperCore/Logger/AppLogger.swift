import Foundation
import os

/// High-performance, low-overhead, thread-safe logger for DynamicWallpaperEngine.
/// Utilizes asynchronous background writing, static date formatting, and file size rotation.
public final class AppLogger: @unchecked Sendable {
    public static let shared = AppLogger()

    private let logger = Logger(subsystem: "tw.soda916.DynamicWallpaperEngine", category: "Core")
    private let fileManager = FileManager.default
    private let logDirectory: URL
    private let debugLogURL: URL
    private let errorLogURL: URL
    private let lock = NSLock()
    private let ioQueue = DispatchQueue(label: "tw.soda916.DynamicWallpaperEngine.logger", qos: .utility)

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()

    public private(set) var recentLogs: [String] = []
    public var onLogAdded: ((String) -> Void)?
    public var enableVerboseFileLogging: Bool = false
    private let maxLogFileSize: Int64 = 1_048_576 // 1MB log cap

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        logDirectory = appSupport.appendingPathComponent("DynamicWallpaperEngine/Logs", isDirectory: true)
        debugLogURL = logDirectory.appendingPathComponent("debug.log")
        errorLogURL = logDirectory.appendingPathComponent("error.log")

        try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
    }

    public func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
        logFormatted(prefix: "[DEBUG]", message: message, writeToFile: enableVerboseFileLogging)
    }

    public func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        logFormatted(prefix: "[INFO]", message: message, writeToFile: true)
    }

    public func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        logFormatted(prefix: "[ERROR]", message: message, writeToFile: true)
        appendToFileAsync(url: errorLogURL, prefix: "[ERROR]", message: message)
    }

    public func verbose(_ message: String) {
        logger.debug("[VERBOSE] \(message, privacy: .public)")
        logFormatted(prefix: "[VERBOSE]", message: message, writeToFile: enableVerboseFileLogging)
    }

    private func logFormatted(prefix: String, message: String, writeToFile: Bool) {
        lock.lock()
        let timestamp = AppLogger.dateFormatter.string(from: Date())
        let line = "\(timestamp) \(prefix) \(message)"
        
        // Output to console stdout for debugging
        print(line)
        
        recentLogs.append(line)
        if recentLogs.count > 150 {
            recentLogs.removeFirst()
        }
        lock.unlock()

        if writeToFile {
            appendToFileAsync(url: debugLogURL, prefix: prefix, message: message)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.onLogAdded?(line)
        }
    }

    private func appendToFileAsync(url: URL, prefix: String, message: String) {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            let timestamp = AppLogger.dateFormatter.string(from: Date())
            let logLine = "\(timestamp) \(prefix) \(message)\n"
            guard let data = logLine.data(using: .utf8) else { return }

            self.rotateLogFileIfNeeded(url: url)

            if self.fileManager.fileExists(atPath: url.path) {
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

    private func rotateLogFileIfNeeded(url: URL) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
           let fileSize = attrs[.size] as? Int64,
           fileSize > maxLogFileSize {
            // Truncate log file to prevent infinite growth
            let truncatedMessage = "[LOG ROTATED - File exceeded 1MB limit]\n"
            try? truncatedMessage.data(using: .utf8)?.write(to: url, options: .atomic)
        }
    }
}

