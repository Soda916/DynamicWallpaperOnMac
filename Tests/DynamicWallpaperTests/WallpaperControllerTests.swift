import Foundation
import DynamicWallpaperCore

public struct WallpaperControllerTests {
    public static func runAllTests() {
        testWallpaperControllerInitialization()
        testPlaylistAndPlaybackMode()
    }

    private static func testWallpaperControllerInitialization() {
        let controller = WallpaperController.shared
        assert(controller.activeWallpaperURL == nil, "Initial active wallpaper URL should be nil")
        assert(controller.playbackCore.isPlaying == false, "Initial playback state should be false")
        print("✓ testWallpaperControllerInitialization passed")
    }

    private static func testPlaylistAndPlaybackMode() {
        let controller = WallpaperController.shared
        controller.clearPlaylist()
        assert(controller.playlist.isEmpty, "Playlist should be empty after clear")
        
        let url1 = URL(fileURLWithPath: "/tmp/test1.mp4")
        let url2 = URL(fileURLWithPath: "/tmp/test2.mp4")
        controller.addToPlaylist([url1, url2])
        assert(controller.playlist.count == 2, "Playlist should have 2 items")
        assert(controller.playlist[0] == url1, "First item should match url1")

        controller.setPlaybackMode(.sequential)
        assert(controller.playbackMode == .sequential, "Playback mode should be sequential")

        controller.removeFromPlaylist(at: 0)
        assert(controller.playlist.count == 1, "Playlist should have 1 item after removal")
        assert(controller.playlist[0] == url2, "Remaining item should be url2")

        controller.clearPlaylist()
        print("✓ testPlaylistAndPlaybackMode passed")
    }
}

