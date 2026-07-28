// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DynamicWallpaperEngine",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "DynamicWallpaperEngine",
            targets: ["DynamicWallpaperEngine"]
        ),
        .library(
            name: "DynamicWallpaperCore",
            targets: ["DynamicWallpaperCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .target(
            name: "DynamicWallpaperCore",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/DynamicWallpaperCore"
        ),
        .executableTarget(
            name: "DynamicWallpaperEngine",
            dependencies: ["DynamicWallpaperCore"],
            path: "Sources/DynamicWallpaperEngine"
        ),
        .executableTarget(
            name: "DynamicWallpaperTests",
            dependencies: ["DynamicWallpaperCore"],
            path: "Tests/DynamicWallpaperTests"
        )
    ]
)

