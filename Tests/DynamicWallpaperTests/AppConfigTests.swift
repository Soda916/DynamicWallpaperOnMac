import Foundation
import DynamicWallpaperCore

public struct AppConfigTests {
    public static func runAllTests() {
        testDefaultConfigInitialization()
        testConfigSerializationAndDeserialization()
        testLegacySchemaVersionMigration()
    }

    private static func testDefaultConfigInitialization() {
        let config = AppConfig()
        assert(config.schemaVersion == AppConfig.currentSchemaVersion, "schemaVersion must match currentSchemaVersion (\(AppConfig.currentSchemaVersion))")
        assert(config.hideDockIcon == true, "hideDockIcon must default to true")
        assert(config.launchAtLogin == false, "launchAtLogin must default to false")
        assert(config.loginDelaySeconds == 30, "loginDelaySeconds must default to 30")
        assert(config.defaultVolume == 1.0, "defaultVolume must default to 1.0")
        assert(config.isMuted == false, "isMuted must default to false")
        assert(config.autoPauseOnMissionControl == true, "autoPauseOnMissionControl must default to true")
        assert(config.wakeUpAction == .resume, "wakeUpAction must default to resume")
        assert(config.playlistPaths == [], "playlistPaths must default to empty array")
        assert(config.playbackMode == .single, "playbackMode must default to .single")
        print("✓ testDefaultConfigInitialization passed")
    }

    private static func testConfigSerializationAndDeserialization() {
        let tempDir = FileManager.default.temporaryDirectory
        let configURL = tempDir.appendingPathComponent("test_config_\(UUID().uuidString).json")

        var originalConfig = AppConfig()
        originalConfig.isMuted = true
        originalConfig.loginDelaySeconds = 15
        originalConfig.playlistPaths = ["/tmp/v1.mp4", "/tmp/v2.mp4"]
        originalConfig.playbackMode = .sequential

        do {
            try originalConfig.save(to: configURL)
            defer { try? FileManager.default.removeItem(at: configURL) }

            let loadResult = AppConfig.load(from: configURL)
            if case .success(let loadedConfig) = loadResult {
                assert(loadedConfig.isMuted == true, "isMuted should be true after deserialization")
                assert(loadedConfig.loginDelaySeconds == 15, "loginDelaySeconds should be 15")
                assert(loadedConfig.playlistPaths.count == 2, "playlistPaths count should be 2")
                assert(loadedConfig.playbackMode == .sequential, "playbackMode should be .sequential")
                print("✓ testConfigSerializationAndDeserialization passed")
            } else {
                fatalError("Expected .success load result")
            }
        } catch {
            fatalError("Failed to save config: \(error)")
        }
    }

    private static func testLegacySchemaVersionMigration() {
        let tempDir = FileManager.default.temporaryDirectory
        let configURL = tempDir.appendingPathComponent("legacy_config_\(UUID().uuidString).json")

        // JSON representing Schema v1 (without playlistPaths, playbackMode, playlistIndex)
        let v1JSON = """
        {
            "schemaVersion": 1,
            "hideDockIcon": true,
            "launchAtLogin": false,
            "loginDelaySeconds": 30,
            "defaultVolume": 0.8,
            "isMuted": false,
            "autoPauseOnMissionControl": true,
            "autoPauseOnLaunchpad": true,
            "autoPauseOnStageManager": true,
            "autoPauseOnFullscreen": true,
            "wakeUpAction": "resume",
            "isAudioDucked": false
        }
        """

        do {
            try v1JSON.data(using: .utf8)?.write(to: configURL)
            defer { try? FileManager.default.removeItem(at: configURL) }

            let loadResult = AppConfig.load(from: configURL)
            switch loadResult {
            case .migrated(let loadedConfig, let fromVersion):
                assert(fromVersion == 1, "Migrated fromVersion should be 1")
                assert(loadedConfig.schemaVersion == AppConfig.currentSchemaVersion, "Migrated config should be updated to currentSchemaVersion")
                assert(loadedConfig.defaultVolume == 0.8, "defaultVolume should be 0.8")
                assert(loadedConfig.playlistPaths == [], "Legacy config should default playlistPaths to empty")
                assert(loadedConfig.playbackMode == .single, "Legacy config should default playbackMode to .single")
                print("✓ testLegacySchemaVersionMigration passed (Migrated v\(fromVersion) -> v\(loadedConfig.schemaVersion))")
            case .success(let loadedConfig):
                assert(loadedConfig.defaultVolume == 0.8, "defaultVolume should be 0.8")
                print("✓ testLegacySchemaVersionMigration passed")
            default:
                fatalError("Expected .migrated or .success load result for legacy schema v1")
            }
        } catch {
            fatalError("Failed to test legacy config: \(error)")
        }
    }
}

