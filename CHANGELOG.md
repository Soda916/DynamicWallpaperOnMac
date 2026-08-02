[English](CHANGELOG.md) | [繁體中文](zh-TW/CHANGELOG.md)

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.2-alpha] - 2026-07-29

> 💡 **Known Issue Workaround (已知問題與臨時對策)**:
> 若在下載與開啟 Apple Silicon ARM 版 (`arm64`) 時遇到「檔案已毀損，無法開啟」或 Gatekeeper 攔截問題，請先下載 **Universal (通用)** 版本作為臨時備案。
> *(If you encounter a "file is damaged and can't be opened" error when launching the downloaded ARM64 version, please download the **Universal** version as a temporary fallback.)*

### Added & Refactored
- **Centralized Hidden Media Library (`MediaStorageManager`)**:
  - Automatically centralizes imported wallpaper files inside `~/.dynamicwallpaper/media/` hidden directory.
  - Supports 5 storage modes: Symbolic Link (`symlink`), Hard Link (`hardlink`), Direct Copy (`copy`), File Move (`move`), and Original Path (`direct`).
- **Native FFmpeg Manager (`FFmpegManager`)**:
  - Dynamically detects system `ffmpeg` binary from PATH and Homebrew (`/opt/homebrew/bin/ffmpeg`).
  - No bundled FFmpeg binary inside app bundle to maintain lightweight native footprint.
  - Non-intrusive Homebrew installation prompt for users when AV1/VP9 codecs require transcoding.
- **JavaScript Desktop Plugin & WebKit Overlay Engine (`PluginManager`)**:
  - Embedded WebKit (`WKWebView`) transparent desktop overlay layer on top of video wallpapers.
  - Built-in sleek glassmorphism **Digital Clock** widget (`~/.dynamicwallpaper/plugins/digital_clock`).
- **GitHub Release Auto-Updater & Notification (`UpdateChecker`)**:
  - Automated version comparison algorithm (`isVersionNewer`) supporting semantic pre-release tags (`0.1.2-alpha`).
  - Asynchronous update notification and native `NSAlert` modal dialog with release notes and GitHub download links.

### Performance & Bug Fixes
- **Ultra-Low Memory & CPU Logging Optimization (`AppLogger`)**:
  - Resolved 101% CPU usage spike and 1.6GB disk write bloat by eliminating per-log `ISO8601DateFormatter` re-allocations and synchronous file handles.
  - Asynchronous background I/O queue (`ioQueue`), 150-entry memory log limit, and 1MB log file rotation cap (`maxLogFileSize`).
- **AppConfig Schema v3 Migration & Fallback (`AppConfig`)**:
  - Upgraded configuration schema to `v3` with graceful property fallbacks and automatic legacy schema migration (`.migrated`).

## [0.1.1-alpha] - 2026-07-28

### Added
- **Multiple Video Playlist System (`Playlist`)**:
  - Support selecting/importing multiple wallpaper videos (.mp4, .mov, .webm, .gif).
  - Three playback modes: Single Track Loop (`single`), Sequential Playlist (`sequential`), and Random Shuffle (`random`).
  - Added Dashboard `NSTableView` playlist manager with double-click track selection, single item removal, and one-click clear.
  - Added `⏮ Prev` / `Next ⏭` buttons and playback mode selector (`NSPopUpButton`).
- **Dashboard Drag & Drop Import**:
  - Drag & drop one or multiple video files directly onto the Dashboard window to append them to the playlist in exact drag order.
- **Interactive Playback Progress Scrubber (`NSSlider`)**:
  - Interactive progress slider and time label (`MM:SS / MM:SS`) for seeking/scrubbing background wallpaper playback in real-time.
- **Automated Universal 2 DMG Packaging (`build_app.sh`)**:
  - Automated Universal Binary (`arm64` + `x86_64`) compilation and DMG installer generation.

### Changed & Refactored
- **Multi-Monitor Smart Auto-Pause Engine (`AutoPauseEngine`)**:
  - Refactored to scan all visible on-screen windows (`CGWindowListCopyWindowInfo`) across all connected displays (`NSScreen.screens`).
  - Pauses playback automatically when any display is covered by a fullscreen or maximized window while ignoring Finder desktop layer and self application windows.
- **System Audio Output Detection & Daemon Filtering (`AudioDuckingDetector`)**:
  - CoreAudio system audio detection dynamically monitors active audio streams across all output devices.
  - Filtered out macOS system sound daemons (`systemsoundserverd`, `coreaudiod`, `ControlCenter`, etc.) to prevent false-positive ducking.
  - Transparent active app name logging and UI status display (e.g. `Active: Spotify`).
- **Smooth Volume Fade Ramp Engine (`MediaPlaybackCore`)**:
  - 30Hz ease-out volume interpolation engine for smooth 0.8s fade-in and fade-out volume transitions during Audio Ducking.

### Fixed & Persistence
- **AppConfig Schema v2 Persistence**:
  - Preserves `playlistPaths`, `playbackMode`, and `playlistIndex` with backward-compatible JSON decoding.
- **Single Instance Enforcement**:
  - Prevents launching multiple duplicate engine processes.

## [0.1.0-alpha] - 2026-07-27

### Added
- Native macOS AppKit `NSStatusItem` Menu Bar application with hidden Dock icon support.
- Core Desktop Window Engine using AppKit `.desktopWindow` level for multi-space wallpaper rendering.
- `MediaPlaybackCore` streaming media player with native `AVPlayer` / `AVURLAsset` hardware decoding pipeline.
- `Multi-Monitor` topology manager (`DisplayManager`) with display hotplug detection.
- `AutoPauseEngine` detecting Fullscreen apps, Mission Control, Launchpad, and Stage Manager for zero CPU/GPU background idle consumption.
- Open `.wallpaper` package format importer with automatic hardware HEVC GIF-to-video conversion (`WallpaperPackageImporter`).
- JavaScript plugin runtime (`JSPluginRuntime`) and Clock Widget SDK (`PluginMetadata`).
- Backward-compatible JSON configuration manager (`AppConfig`) with schema migration handling.
- Unified `AppLogger` (`os.Logger` + log files) and GitHub Release `UpdateChecker`.
- Complete developer documentation (`docs/ARCHITECTURE.md` & `docs/PLUGIN_GUIDE.md`).
- Universal Binary compilation (`arm64` & `x86_64`) and automated test suite.
