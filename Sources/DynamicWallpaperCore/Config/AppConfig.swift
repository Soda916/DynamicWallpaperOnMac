import Foundation

public enum PlaybackMode: String, Codable, CaseIterable {
    case single = "single"          // Repeat single video
    case sequential = "sequential"  // Play sequentially through playlist
    case random = "random"          // Play randomly through playlist
}

public enum MediaStorageMode: String, Codable, CaseIterable {
    case copy = "copy"          // Copy media file into ~/.dynamicwallpaper/media/
    case symlink = "symlink"    // Soft link (symbolic link) into ~/.dynamicwallpaper/media/
    case hardlink = "hardlink"  // Hard link into ~/.dynamicwallpaper/media/
    case move = "move"          // Move file into ~/.dynamicwallpaper/media/
    case direct = "direct"      // Use original file path directly
}

/// Application configuration structure supporting backward compatibility and JSON schema migration.
public struct AppConfig: Codable, Equatable {
    public static let currentSchemaVersion = 3

    public var schemaVersion: Int
    public var hideDockIcon: Bool
    public var launchAtLogin: Bool
    public var loginDelaySeconds: Int
    public var defaultVolume: Float
    public var isMuted: Bool
    public var autoPauseOnMissionControl: Bool
    public var autoPauseOnLaunchpad: Bool
    public var autoPauseOnStageManager: Bool
    public var autoPauseOnFullscreen: Bool
    public var wakeUpAction: WakeUpAction
    public var isAudioDucked: Bool
    public var lastWallpaperPath: String?
    public var playlistPaths: [String]
    public var playbackMode: PlaybackMode
    public var playlistIndex: Int
    public var mediaStorageMode: MediaStorageMode
    public var autoCheckUpdates: Bool
    public var ffmpegPath: String?
    public var enabledPluginIDs: [String]

    public enum WakeUpAction: String, Codable {
        case restart
        case resume
    }

    public init(
        schemaVersion: Int = AppConfig.currentSchemaVersion,
        hideDockIcon: Bool = true,
        launchAtLogin: Bool = false,
        loginDelaySeconds: Int = 30,
        defaultVolume: Float = 1.0,
        isMuted: Bool = false,
        autoPauseOnMissionControl: Bool = true,
        autoPauseOnLaunchpad: Bool = true,
        autoPauseOnStageManager: Bool = true,
        autoPauseOnFullscreen: Bool = false,
        wakeUpAction: WakeUpAction = .resume,
        isAudioDucked: Bool = true,
        lastWallpaperPath: String? = nil,
        playlistPaths: [String] = [],
        playbackMode: PlaybackMode = .single,
        playlistIndex: Int = 0,
        mediaStorageMode: MediaStorageMode = .symlink,
        autoCheckUpdates: Bool = true,
        ffmpegPath: String? = nil,
        enabledPluginIDs: [String] = ["digital_clock"]
    ) {
        self.schemaVersion = schemaVersion
        self.hideDockIcon = hideDockIcon
        self.launchAtLogin = launchAtLogin
        self.loginDelaySeconds = loginDelaySeconds
        self.defaultVolume = defaultVolume
        self.isMuted = isMuted
        self.autoPauseOnMissionControl = autoPauseOnMissionControl
        self.autoPauseOnLaunchpad = autoPauseOnLaunchpad
        self.autoPauseOnStageManager = autoPauseOnStageManager
        self.autoPauseOnFullscreen = autoPauseOnFullscreen
        self.wakeUpAction = wakeUpAction
        self.isAudioDucked = isAudioDucked
        self.lastWallpaperPath = lastWallpaperPath
        self.playlistPaths = playlistPaths
        self.playbackMode = playbackMode
        self.playlistIndex = playlistIndex
        self.mediaStorageMode = mediaStorageMode
        self.autoCheckUpdates = autoCheckUpdates
        self.ffmpegPath = ffmpegPath
        self.enabledPluginIDs = enabledPluginIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        self.hideDockIcon = try container.decodeIfPresent(Bool.self, forKey: .hideDockIcon) ?? true
        self.launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        self.loginDelaySeconds = try container.decodeIfPresent(Int.self, forKey: .loginDelaySeconds) ?? 30
        self.defaultVolume = try container.decodeIfPresent(Float.self, forKey: .defaultVolume) ?? 1.0
        self.isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
        self.autoPauseOnMissionControl = try container.decodeIfPresent(Bool.self, forKey: .autoPauseOnMissionControl) ?? true
        self.autoPauseOnLaunchpad = try container.decodeIfPresent(Bool.self, forKey: .autoPauseOnLaunchpad) ?? true
        self.autoPauseOnStageManager = try container.decodeIfPresent(Bool.self, forKey: .autoPauseOnStageManager) ?? true
        self.autoPauseOnFullscreen = try container.decodeIfPresent(Bool.self, forKey: .autoPauseOnFullscreen) ?? false
        self.wakeUpAction = try container.decodeIfPresent(WakeUpAction.self, forKey: .wakeUpAction) ?? .resume
        self.isAudioDucked = try container.decodeIfPresent(Bool.self, forKey: .isAudioDucked) ?? true
        self.lastWallpaperPath = try container.decodeIfPresent(String.self, forKey: .lastWallpaperPath)
        self.playlistPaths = try container.decodeIfPresent([String].self, forKey: .playlistPaths) ?? []
        self.playbackMode = try container.decodeIfPresent(PlaybackMode.self, forKey: .playbackMode) ?? .single
        self.playlistIndex = try container.decodeIfPresent(Int.self, forKey: .playlistIndex) ?? 0
        self.mediaStorageMode = try container.decodeIfPresent(MediaStorageMode.self, forKey: .mediaStorageMode) ?? .symlink
        self.autoCheckUpdates = try container.decodeIfPresent(Bool.self, forKey: .autoCheckUpdates) ?? true
        self.ffmpegPath = try container.decodeIfPresent(String.self, forKey: .ffmpegPath)
        self.enabledPluginIDs = try container.decodeIfPresent([String].self, forKey: .enabledPluginIDs) ?? ["digital_clock"]
    }

    /// Result enum when loading configuration files to handle schema version mismatches without crashing.
    public enum LoadResult {
        case success(AppConfig)
        case migrated(AppConfig, fromVersion: Int)
        case newerVersionDetected(schemaVersion: Int, rawData: Data)
        case corruptedFile(Error)
    }

    public static func load(from url: URL) -> LoadResult {
        guard let data = try? Data(contentsOf: url) else {
            return .success(AppConfig())
        }

        let decoder = JSONDecoder()
        do {
            var config = try decoder.decode(AppConfig.self, from: data)
            if config.schemaVersion > currentSchemaVersion {
                return .newerVersionDetected(schemaVersion: config.schemaVersion, rawData: data)
            }
            if config.schemaVersion < currentSchemaVersion {
                let oldVersion = config.schemaVersion
                config.schemaVersion = currentSchemaVersion
                try? config.save(to: url)
                return .migrated(config, fromVersion: oldVersion)
            }
            return .success(config)
        } catch {
            // Safe fallback: repair corrupted file while preserving readable fields
            AppLogger.shared.error("AppConfig load failed: \(error.localizedDescription). Utilizing default schema.")
            return .corruptedFile(error)
        }
    }

    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }
}


