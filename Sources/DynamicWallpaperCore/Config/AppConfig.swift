import Foundation

/// Application configuration structure supporting backward compatibility and JSON schema migration.
public struct AppConfig: Codable, Equatable {
    public static let currentSchemaVersion = 1

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
        autoPauseOnFullscreen: Bool = true,
        wakeUpAction: WakeUpAction = .resume
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
    }

    /// Result enum when loading configuration files to handle schema version mismatches without crashing.
    public enum LoadResult {
        case success(AppConfig)
        case newerVersionDetected(schemaVersion: Int, rawData: Data)
        case corruptedFile(Error)
    }

    public static func load(from url: URL) -> LoadResult {
        guard let data = try? Data(contentsOf: url) else {
            return .success(AppConfig())
        }

        let decoder = JSONDecoder()
        do {
            let config = try decoder.decode(AppConfig.self, from: data)
            if config.schemaVersion > currentSchemaVersion {
                return .newerVersionDetected(schemaVersion: config.schemaVersion, rawData: data)
            }
            return .success(config)
        } catch {
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
