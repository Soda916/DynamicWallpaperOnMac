import Foundation
import DynamicWallpaperCore

public struct AutoPauseEngineTests {
    public static func runAllTests() {
        testAutoPauseEngineInitialization()
    }

    private static func testAutoPauseEngineInitialization() {
        let engine = AutoPauseEngine.shared
        assert(engine.isPaused == false, "AutoPauseEngine should start unpaused")
        print("✓ testAutoPauseEngineInitialization passed")
    }
}
