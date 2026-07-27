import Foundation

/// Defines the public metadata schema for open `.wallpaper` packages.
public struct WallpaperMetadata: Codable, Equatable {
    public var title: String
    public var author: String
    public var version: String
    public var description: String
    public var mediaFileName: String
    public var thumbnailFileName: String
    public var license: String
    public var minimumAppVersion: String

    public init(
        title: String,
        author: String,
        version: String = "1.0.0",
        description: String = "",
        mediaFileName: String,
        thumbnailFileName: String = "thumbnail.jpg",
        license: String = "Apache-2.0",
        minimumAppVersion: String = "1.0.0"
    ) {
        self.title = title
        self.author = author
        self.version = version
        self.description = description
        self.mediaFileName = mediaFileName
        self.thumbnailFileName = thumbnailFileName
        self.license = license
        self.minimumAppVersion = minimumAppVersion
    }
}
