#!/bin/bash

# Exit on error
set -e

echo "Starting build process for Dynamic Wallpaper Engine..."

# Directories
PROJECT_DIR="/Users/dustlee/program/DynamicWallPaper"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/DynamicWallpaperEngine.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
VERSION="0.1.0-alpha"

# Ensure script is run from project root or directories are created correctly
mkdir -p "$PROJECT_DIR/scripts"

# Clean build directory
echo "Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$FRAMEWORKS_DIR"

# Compile Core
echo "Compiling DynamicWallpaperCore as dynamic library..."
CORE_SOURCES=$(find "$PROJECT_DIR/Sources/DynamicWallpaperCore" -name "*.swift")
swiftc -emit-library \
    -target arm64-apple-macosx14.0 \
    -module-name DynamicWallpaperCore \
    -emit-module -emit-module-path "$BUILD_DIR/DynamicWallpaperCore.swiftmodule" \
    $CORE_SOURCES \
    -o "$BUILD_DIR/libDynamicWallpaperCore.dylib"

# Set library id so it's recorded correctly during link
install_name_tool -id "@rpath/libDynamicWallpaperCore.dylib" "$BUILD_DIR/libDynamicWallpaperCore.dylib"

# Compile Engine
echo "Compiling DynamicWallpaperEngine..."
ENGINE_SOURCES=$(find "$PROJECT_DIR/Sources/DynamicWallpaperEngine" -name "*.swift")
swiftc \
    -target arm64-apple-macosx14.0 \
    -I "$BUILD_DIR" \
    -L "$BUILD_DIR" -lDynamicWallpaperCore \
    $ENGINE_SOURCES \
    -o "$BUILD_DIR/DynamicWallpaperEngine"

# Add rpath to executable so it can find the library
install_name_tool -add_rpath "@executable_path/../Frameworks" "$BUILD_DIR/DynamicWallpaperEngine"

# Assemble .app
echo "Assembling .app bundle..."
cp "$BUILD_DIR/DynamicWallpaperEngine" "$MACOS_DIR/"
cp "$BUILD_DIR/libDynamicWallpaperCore.dylib" "$FRAMEWORKS_DIR/"

# Generate Info.plist
echo "Generating Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DynamicWallpaperEngine</string>
    <key>CFBundleIdentifier</key>
    <string>com.antigravity.DynamicWallpaperEngine</string>
    <key>CFBundleName</key>
    <string>DynamicWallpaperEngine</string>
    <key>CFBundleDisplayName</key>
    <string>Dynamic Wallpaper Engine</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Zip release
echo "Creating release archive..."
cd "$BUILD_DIR"
ZIP_NAME="DynamicWallpaperEngine-v$VERSION-macOS-arm64.zip"
zip -r "$ZIP_NAME" "DynamicWallpaperEngine.app"

echo "Build successful! Archive created at: $BUILD_DIR/$ZIP_NAME"
