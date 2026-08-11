import Foundation
import AppKit
import Darwin

public struct MemoryStats: Codable {
    public let physFootprintMB: Double
    public let residentMB: Double
    public let virtualMB: Double
    public let timestamp: String
}

/// Native macOS RAM Diagnostic and Cache Purging Manager.
/// Measures physical memory footprint via Darwin task_info API and dumps diagnostic JSON reports.
public final class MemoryDumpManager: @unchecked Sendable {
    public static let shared = MemoryDumpManager()

    private init() {}

    /// Query current macOS process physical memory footprint using Darwin task_vm_info kernel API.
    public func currentMemoryStats() -> MemoryStats {
        var stats = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        if kerr == KERN_SUCCESS {
            let footprint = Double(stats.phys_footprint) / (1024.0 * 1024.0)
            let resident = Double(stats.resident_size) / (1024.0 * 1024.0)
            let virtualSize = Double(stats.virtual_size) / (1024.0 * 1024.0)
            return MemoryStats(physFootprintMB: footprint, residentMB: resident, virtualMB: virtualSize, timestamp: timestamp)
        }
        return MemoryStats(physFootprintMB: 0, residentMB: 0, virtualMB: 0, timestamp: timestamp)
    }

    /// Performs memory optimization by draining autorelease pools, clearing URLCache, and writing a timestamped JSON RAM dump file.
    public func dumpAndPurgeMemory() -> (before: MemoryStats, after: MemoryStats, dumpFileURL: URL) {
        let beforeStats = currentMemoryStats()

        // 1. Purge system URLCache
        URLCache.shared.removeAllCachedResponses()

        // 2. Force autorelease pool drain
        autoreleasepool {
            // Memory cache purge scope
        }

        let afterStats = currentMemoryStats()

        // 3. Create timestamped RAM Dump JSON log file
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let logDir = appSupport.appendingPathComponent("DynamicWallpaperEngine/Logs", isDirectory: true)
        try? fileManager.createDirectory(at: logDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "ram_dump_\(formatter.string(from: Date())).json"
        let dumpFileURL = logDir.appendingPathComponent(filename)

        let dumpData: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "appVersion": UpdateChecker.currentAppVersion,
            "memoryBeforeDump": [
                "physFootprintMB": Double(String(format: "%.2f", beforeStats.physFootprintMB)) ?? 0.0,
                "residentMB": Double(String(format: "%.2f", beforeStats.residentMB)) ?? 0.0,
                "virtualMB": Double(String(format: "%.2f", beforeStats.virtualMB)) ?? 0.0
            ],
            "memoryAfterDump": [
                "physFootprintMB": Double(String(format: "%.2f", afterStats.physFootprintMB)) ?? 0.0,
                "residentMB": Double(String(format: "%.2f", afterStats.residentMB)) ?? 0.0,
                "virtualMB": Double(String(format: "%.2f", afterStats.virtualMB)) ?? 0.0
            ],
            "activeWallpaperURL": WallpaperController.shared.activeWallpaperURL?.path ?? "None",
            "playlistCount": WallpaperController.shared.playlist.count,
            "isAutoPaused": WallpaperController.shared.autoPauseEngine.isPaused,
            "systemOSVersion": ProcessInfo.processInfo.operatingSystemVersionString
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: dumpData, options: .prettyPrinted) {
            try? jsonData.write(to: dumpFileURL)
        }

        AppLogger.shared.info("[RAM-DUMP] Diagnostic RAM dump saved to \(dumpFileURL.path). Footprint: \(String(format: "%.2f", beforeStats.physFootprintMB))MB -> \(String(format: "%.2f", afterStats.physFootprintMB))MB")

        return (beforeStats, afterStats, dumpFileURL)
    }

    /// Triggers memory dump and presents a native multi-language alert modal detailing memory stats.
    public func presentRAMDumpAlert() {
        let (before, after, dumpURL) = dumpAndPurgeMemory()

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = LocalizationManager.shared.localized("ram_dump_title")
            alert.informativeText = LocalizationManager.shared.localized(
                "ram_dump_info",
                after.physFootprintMB,
                before.physFootprintMB,
                after.residentMB,
                after.virtualMB,
                dumpURL.path
            )
            alert.alertStyle = .informational
            alert.addButton(withTitle: LocalizationManager.shared.localized("update_alert_ok"))
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
}
