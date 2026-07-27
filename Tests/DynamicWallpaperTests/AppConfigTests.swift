import Foundation
import DynamicWallpaperCore

public struct AppConfigTests {
    public static func runAllTests() {
        testDefaultConfigInitialization()
        testConfigSerializationAndDeserialization()
    }

    private static func testDefaultConfigInitialization() {
        let config = AppConfig()
        assert(config.schemaVersion == 1, "schemaVersion must be 1")
        assert(config.hideDockIcon == true, "hideDockIcon must default to true")
        assert(config.launchAtLogin == false, "launchAtLogin must default to false")
        assert(config.loginDelaySeconds == 30, "loginDelaySeconds must default to 30")
        assert(config.defaultVolume == 1.0, "defaultVolume must default to 1.0")
        assert(config.isMuted == false, "isMuted must default to false")
        assert(config.autoPauseOnMissionControl == true, "autoPauseOnMissionControl must default to true")
        assert(config.wakeUpAction == .resume, "wakeUpAction must default to resume")
        print("✓ testDefaultConfigInitialization passed")
    }

    private static func testConfigSerializationAndDeserialization() {
        let tempDir = FileManager.default.temporaryDirectory
        let configURL = tempDir.appendingPathComponent("test_config_\(UUID().uuidString).json")

        var originalConfig = AppConfig()
        originalConfig.isMuted = true
        originalConfig.loginDelaySeconds = 15

        do {
            try originalConfig.save(to: configURL)
            defer { try? FileManager.default.removeItem(at: configURL) }

            let loadResult = AppConfig.load(from: configURL)
            if case .success(let loadedConfig) = loadResult {
                assert(loadedConfig.isMuted == true, "isMuted should be true after deserialization")
                assert(loadedConfig.loginDelaySeconds == 15, "loginDelaySeconds should be 15")
                print("✓ testConfigSerializationAndDeserialization passed")
            } else {
                fatalError("Expected .success load result")
            }
        } catch {
            fatalError("Failed to save config: \(error)")
        }
    }
}
