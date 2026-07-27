import Foundation
import DynamicWallpaperCore

public struct WallpaperPackageTests {
    public static func runAllTests() {
        testWallpaperMetadataSerialization()
    }

    private static func testWallpaperMetadataSerialization() {
        let metadata = WallpaperMetadata(
            title: "Cyberpunk City",
            author: "Antigravity Team",
            mediaFileName: "city.mp4"
        )
        
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(metadata) else {
            fatalError("Failed to encode WallpaperMetadata")
        }

        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(WallpaperMetadata.self, from: data) else {
            fatalError("Failed to decode WallpaperMetadata")
        }

        assert(decoded.title == "Cyberpunk City", "Title should match")
        assert(decoded.author == "Antigravity Team", "Author should match")
        assert(decoded.mediaFileName == "city.mp4", "mediaFileName should match")
        assert(decoded.license == "Apache-2.0", "Default license should be Apache-2.0")
        print("✓ testWallpaperMetadataSerialization passed")
    }
}
