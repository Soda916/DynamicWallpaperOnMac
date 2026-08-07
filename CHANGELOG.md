[English](CHANGELOG.md) | [繁體中文](zh-TW/CHANGELOG.md)

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.4-alpha] - 2026-08-07

### Added & Refactored
- **Multi-Language Localization Engine (`LocalizationManager`)**:
  - Centralized localization manager supporting English (`en`), Traditional Chinese (`zh-Hant`), Simplified Chinese (`zh-Hans`), and Japanese (`ja`).
  - Added live language switcher in Control Panel with dynamic text rebinding.
  - Standardized Traditional Chinese term for Dashboard as **"控制台"**.
  - Implemented `NotificationCenter` event broadcasting (`.appLanguageDidChange`) for 100% synchronous language updates across Control Panel, status bar menu, and modal dialogs.
- **3-Tier Low Power Mode & Status Bar Warning (`BatteryManager` & `AutoPauseEngine`)**:
  - Implemented native macOS `IOKit.ps` API battery monitoring:
    - **Tier 1 ($\ge 20\%$)**: Normal operation with framerate / SDR peak brightness throttling on battery power.
    - **Tier 2 ($10\% \le \text{battery} < \text{threshold}$)**: Auto-pauses video decoding to save energy, displaying warning SVG icon (`laptopcomputer.trianglebadge.exclamationmark`) in status bar.
    - **Tier 3 ($< 10\%$)**: Complete 0% energy shutdown, pausing all timers and decoding.
  - Added customizable Smart Power Saving Threshold slider (15% - 50%) in Control Panel.
- **Native Localized Auto-Update Alerts (`UpdateChecker`)**:
  - Bypassed un-localized Sparkle default English dialogs and implemented native multi-language alert modals for update checks.
- **Audio Ducking Volume Control**:
  - Integrated 5% background audio ducking toggle in Control Panel and status bar menu.

## [0.1.3-alpha] - 2026-08-02

### Added & Refactored
- **Native Launch at Login (`LaunchAtLoginManager`)**:
  - Implemented 100% Apple native `SMAppService.mainApp` API (macOS 13.0+ ServiceManagement).
  - Added "Launch at Login" menu toggle in status bar menu with automatic preference persistence.
- **Apple Silicon (M1/M2/M3/M4) Code Signing Fix (`build_app.sh`)**:
  - Automatically executes deep ad-hoc code re-signing (`codesign --force --deep -s -`) after bundle assembly.
  - Resolves Gatekeeper "App is damaged and can't be opened" launch failure on ARM64 binaries caused by invalid Mach-O signature seals.
- **Option A Native SF Symbols for Status Bar (`main.swift`)**:
  - Implemented high-contrast, crystal-clear Apple native SF Symbols for status bar icon:
    - **Active & Playing**: `play.rectangle.fill`
    - **Active & Auto-Paused / Paused**: `pause.rectangle.fill`
    - **Disabled**: `play.laptopcomputer`
- **Instant Auto-Pause at Launch (`WallpaperController.swift`)**:
  - Evaluates window topology prior to playback start, ensuring video wallpaper immediately pauses if launched beneath a fullscreen/maximized window.
- **System Boot & Sleep/Wake Anti-Stutter (`WallpaperController.swift`)**:
  - Listens to `willSleepNotification` to gracefully pause playback before system sleep.
  - Delayed restoration (3.0s delay after `didWakeNotification`) to prevent system boot/wake resource contention.
- **macOS 14 Sonoma Menu Detachment Fix (`main.swift`)**:
  - Replaced deprecated `statusItem.popUpMenu` with anchored `menu.popUp(...)` to fix status menu detachment on macOS 14 Sonoma.
- **Updated Default Preferences (`AppConfig.swift`)**:
  - Set `autoPauseOnFullscreen` default to `false` and `isAudioDucked` default to `true` (5% volume).

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
