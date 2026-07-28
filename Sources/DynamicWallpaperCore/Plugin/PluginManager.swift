import Foundation
import WebKit

/// Central manager for loading, registering, and controlling JavaScript plugins (widgets/clocks/overlays).
public final class PluginManager: @unchecked Sendable {
    public static let shared = PluginManager()

    private let fileManager = FileManager.default

    public var pluginsDirectory: URL {
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let dir = homeDir.appendingPathComponent(".dynamicwallpaper/plugins", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public private(set) var installedPlugins: [PluginMetadata] = []
    public var activePluginIDs: Set<String> = ["digital_clock"]

    private init() {
        createDefaultBuiltinPluginsIfNeeded()
        reloadInstalledPlugins()
    }

    /// Scans ~/.dynamicwallpaper/plugins for plugin manifests (plugin.json or metadata.json)
    public func reloadInstalledPlugins() {
        installedPlugins.removeAll()
        guard let subdirs = try? fileManager.contentsOfDirectory(at: pluginsDirectory, includingPropertiesForKeys: nil) else { return }

        for dir in subdirs {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue {
                let manifestURL = dir.appendingPathComponent("plugin.json")
                if fileManager.fileExists(atPath: manifestURL.path),
                   let data = try? Data(contentsOf: manifestURL),
                   let meta = try? JSONDecoder().decode(PluginMetadata.self, from: data) {
                    installedPlugins.append(meta)
                }
            }
        }
        AppLogger.shared.info("[PLUGIN-MANAGER] Loaded \(installedPlugins.count) installed plugin(s).")
    }

    /// Returns HTML content for a specific plugin ID to load into desktop web overlay
    public func getPluginHTML(for pluginID: String) -> String? {
        let pluginDir = pluginsDirectory.appendingPathComponent(pluginID)
        let indexHTML = pluginDir.appendingPathComponent("index.html")
        if fileManager.fileExists(atPath: indexHTML.path),
           let htmlContent = try? String(contentsOf: indexHTML, encoding: .utf8) {
            return htmlContent
        }
        return nil
    }

    /// Creates standard built-in plugins (Digital Clock & System Status) on first run
    public func createDefaultBuiltinPluginsIfNeeded() {
        let clockDir = pluginsDirectory.appendingPathComponent("digital_clock")
        let clockManifest = clockDir.appendingPathComponent("plugin.json")
        let clockHTML = clockDir.appendingPathComponent("index.html")

        if !fileManager.fileExists(atPath: clockManifest.path) {
            try? fileManager.createDirectory(at: clockDir, withIntermediateDirectories: true)

            let meta = PluginMetadata(
                id: "digital_clock",
                name: "Digital Clock",
                version: "1.0.0",
                author: "DynamicWallpaperEngine",
                mainJS: "index.html",
                type: .clock,
                defaultPositionX: 60,
                defaultPositionY: 60
            )

            if let data = try? JSONEncoder().encode(meta) {
                try? data.write(to: clockManifest)
            }

            let htmlString = """
            <!DOCTYPE html>
            <html>
            <head>
              <meta charset="utf-8">
              <style>
                body {
                  margin: 0;
                  padding: 20px;
                  overflow: hidden;
                  background: transparent;
                  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                  user-select: none;
                }
                .clock-card {
                  display: inline-block;
                  padding: 16px 28px;
                  background: rgba(20, 20, 25, 0.45);
                  backdrop-filter: blur(16px);
                  -webkit-backdrop-filter: blur(16px);
                  border: 1px solid rgba(255, 255, 255, 0.15);
                  border-radius: 18px;
                  color: #ffffff;
                  box-shadow: 0 8px 32px rgba(0,0,0,0.3);
                }
                .time {
                  font-size: 48px;
                  font-weight: 700;
                  letter-spacing: 2px;
                  text-shadow: 0 2px 10px rgba(0,0,0,0.5);
                }
                .date {
                  font-size: 16px;
                  font-weight: 500;
                  opacity: 0.85;
                  margin-top: 4px;
                  text-transform: uppercase;
                  letter-spacing: 1px;
                }
              </style>
            </head>
            <body>
              <div class="clock-card">
                <div class="time" id="time">00:00:00</div>
                <div class="date" id="date">YYYY-MM-DD</div>
              </div>
              <script>
                function updateClock() {
                  const now = new Date();
                  const hours = String(now.getHours()).padStart(2, '0');
                  const mins = String(now.getMinutes()).padStart(2, '0');
                  const secs = String(now.getSeconds()).padStart(2, '0');
                  document.getElementById('time').textContent = `${hours}:${mins}:${secs}`;
                  
                  const options = { weekday: 'short', month: 'short', day: 'numeric' };
                  document.getElementById('date').textContent = now.toLocaleDateString(undefined, options);
                }
                setInterval(updateClock, 1000);
                updateClock();
              </script>
            </body>
            </html>
            """
            try? htmlString.write(to: clockHTML, atomically: true, encoding: .utf8)
            AppLogger.shared.info("[PLUGIN-MANAGER] Created built-in Digital Clock plugin.")
        }
    }
}
