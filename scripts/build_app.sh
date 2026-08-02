#!/bin/bash

# Exit on error
set -e

echo "Starting release build process for Dynamic Wallpaper Engine v0.1.2-alpha..."

# Directories
PROJECT_DIR="/Users/dustlee/program/DynamicWallPaper"
BUILD_DIR="$PROJECT_DIR/build"
VERSION="0.1.2-alpha"

# Clean build directory
echo "Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

CORE_SOURCES=$(find "$PROJECT_DIR/Sources/DynamicWallpaperCore" -name "*.swift")
ENGINE_SOURCES=$(find "$PROJECT_DIR/Sources/DynamicWallpaperEngine" -name "*.swift")

SPARKLE_FRAMEWORK=$(find "$PROJECT_DIR/.build" -name "Sparkle.framework" -type d 2>/dev/null | head -n 1)

# Helper function to compile for an architecture
compile_arch() {
    local arch=$1
    echo "Compiling for $arch..."
    
    local ARCH_DIR="$BUILD_DIR/$arch"
    mkdir -p "$ARCH_DIR"
    
    local EXTRA_FLAGS=""
    if [ -n "$SPARKLE_FRAMEWORK" ]; then
        local SPARKLE_DIR=$(dirname "$SPARKLE_FRAMEWORK")
        EXTRA_FLAGS="-F $SPARKLE_DIR -framework Sparkle"
    fi

    # Compile Core
    swiftc -emit-library \
        -target ${arch}-apple-macosx14.0 \
        -module-name DynamicWallpaperCore \
        -emit-module -emit-module-path "$ARCH_DIR/DynamicWallpaperCore.swiftmodule" \
        $EXTRA_FLAGS \
        $CORE_SOURCES \
        -o "$ARCH_DIR/libDynamicWallpaperCore.dylib"

    install_name_tool -id "@rpath/libDynamicWallpaperCore.dylib" "$ARCH_DIR/libDynamicWallpaperCore.dylib" 2>/dev/null || true

    # Compile Engine
    swiftc \
        -target ${arch}-apple-macosx14.0 \
        -I "$ARCH_DIR" \
        -L "$ARCH_DIR" -lDynamicWallpaperCore \
        $EXTRA_FLAGS \
        $ENGINE_SOURCES \
        -o "$ARCH_DIR/DynamicWallpaperEngine"
}

compile_arch "arm64"
compile_arch "x86_64"

# Combine using lipo
echo "Creating Universal 2 binaries..."
UNIVERSAL_DIR="$BUILD_DIR/universal"
mkdir -p "$UNIVERSAL_DIR"

lipo -create "$BUILD_DIR/arm64/libDynamicWallpaperCore.dylib" "$BUILD_DIR/x86_64/libDynamicWallpaperCore.dylib" -output "$UNIVERSAL_DIR/libDynamicWallpaperCore.dylib"
lipo -create "$BUILD_DIR/arm64/DynamicWallpaperEngine" "$BUILD_DIR/x86_64/DynamicWallpaperEngine" -output "$UNIVERSAL_DIR/DynamicWallpaperEngine"

# Helper function to package
package_variant() {
    local variant_name=$1
    local bin_dir=$2
    
    echo "Packaging variant: $variant_name"
    
    local STAGING_DIR="$BUILD_DIR/staging_$variant_name"
    local APP_DIR="$STAGING_DIR/DynamicWallpaperEngine.app"
    local CONTENTS_DIR="$APP_DIR/Contents"
    local MACOS_DIR="$CONTENTS_DIR/MacOS"
    local RESOURCES_DIR="$CONTENTS_DIR/Resources"
    local FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"

    mkdir -p "$MACOS_DIR"
    mkdir -p "$RESOURCES_DIR"
    mkdir -p "$FRAMEWORKS_DIR"

    cp "$bin_dir/DynamicWallpaperEngine" "$MACOS_DIR/DynamicWallpaperEngine"
    cp "$bin_dir/libDynamicWallpaperCore.dylib" "$FRAMEWORKS_DIR/libDynamicWallpaperCore.dylib"
    
    if [ -n "$SPARKLE_FRAMEWORK" ] && [ -d "$SPARKLE_FRAMEWORK" ]; then
        cp -R "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/Sparkle.framework"
    fi

    if [ -f "$PROJECT_DIR/AppIcon.icns" ]; then
        cp "$PROJECT_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
    fi
    
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/DynamicWallpaperEngine" 2>/dev/null || true

    # Generate Info.plist
    cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleExecutable</key>
    <string>DynamicWallpaperEngine</string>
    <key>CFBundleIdentifier</key>
    <string>tw.soda916.DynamicWallpaperEngine</string>
    <key>CFBundleName</key>
    <string>DynamicWallpaperEngine</string>
    <key>CFBundleDisplayName</key>
    <string>Dynamic Wallpaper Engine</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>1.2.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/Soda916/DynamicWallpaperOnMac/main/appcast.xml</string>
</dict>
</plist>
EOF

    # Code sign (Ad-hoc re-sign entire app bundle and frameworks)
    echo "Signing app bundle with ad-hoc signature..."
    codesign --force --deep -s - "$APP_DIR"

    # Zip
    cd "$STAGING_DIR"
    local ZIP_NAME="DynamicWallpaperEngine-v${VERSION}-macOS-${variant_name}.zip"
    zip -r "$BUILD_DIR/$ZIP_NAME" "DynamicWallpaperEngine.app" > /dev/null

    # DMG
    local DMG_STAGING="$STAGING_DIR/dmg_staging"
    mkdir -p "$DMG_STAGING"
    cp -R "$APP_DIR" "$DMG_STAGING/"
    ln -s /Applications "$DMG_STAGING/Applications"
    local DMG_NAME="DynamicWallpaperEngine-v${VERSION}-macOS-${variant_name}.dmg"
    rm -f "$BUILD_DIR/$DMG_NAME"
    hdiutil create -volname "Dynamic Wallpaper Engine" -srcfolder "$DMG_STAGING" -ov -format UDZO "$BUILD_DIR/$DMG_NAME" > /dev/null
    
    echo "Generated $ZIP_NAME and $DMG_NAME"
}

package_variant "arm64" "$BUILD_DIR/arm64"
package_variant "x86_64" "$BUILD_DIR/x86_64"
package_variant "Universal" "$BUILD_DIR/universal"

echo "Build successful!"

