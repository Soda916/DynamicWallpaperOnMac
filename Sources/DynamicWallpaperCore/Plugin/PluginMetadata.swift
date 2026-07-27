import Foundation

/// Defines the public metadata specification for JavaScript plugins (widgets, clocks, overlays).
public struct PluginMetadata: Codable, Equatable {
    public var id: String
    public var name: String
    public var version: String
    public var author: String
    public var mainJS: String
    public var type: PluginType
    public var defaultPositionX: Double
    public var defaultPositionY: Double

    public enum PluginType: String, Codable {
        case clock
        case widget
        case overlay
        case animation
    }

    public init(
        id: String,
        name: String,
        version: String = "1.0.0",
        author: String = "Unknown",
        mainJS: String = "main.js",
        type: PluginType = .clock,
        defaultPositionX: Double = 100.0,
        defaultPositionY: Double = 100.0
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.author = author
        self.mainJS = mainJS
        self.type = type
        self.defaultPositionX = defaultPositionX
        self.defaultPositionY = defaultPositionY
    }
}
