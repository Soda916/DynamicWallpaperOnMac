import Foundation
import DynamicWallpaperCore

public struct WallpaperControllerTests {
    public static func runAllTests() {
        testWallpaperControllerInitialization()
    }

    private static func testWallpaperControllerInitialization() {
        let controller = WallpaperController.shared
        assert(controller.activeWallpaperURL == nil, "Initial active wallpaper URL should be nil")
        assert(controller.playbackCore.isPlaying == false, "Initial playback state should be false")
        print("✓ testWallpaperControllerInitialization passed")
    }
}
