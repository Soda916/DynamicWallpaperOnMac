[English](CHANGELOG.md) | [繁體中文](zh-TW/CHANGELOG.md)

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
