[English](README.md) | [繁體中文](zh-TW/README.md)

# DynamicWallpaperEngine (macOS Native Dynamic Wallpaper Player & Plugin Platform)

[![macOS Sonoma+](https://img.shields.io/badge/macOS-14.0%2B%20Sonoma-blue.svg?style=flat&logo=apple)](https://www.apple.com/macos/)
[![Universal Binary](https://img.shields.io/badge/Architecture-Universal%20(Apple%20Silicon%20%2B%20Intel)-brightgreen.svg)](https://developer.apple.com/documentation/apple-silicon/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![CI Build](https://github.com/your-org/DynamicWallpaperEngine/actions/workflows/ci.yml/badge.svg)](https://github.com/your-org/DynamicWallpaperEngine/actions)

**DynamicWallpaperEngine** is a high-performance, low-resource, extensible, open-source macOS native live wallpaper runtime and plugin platform. Built strictly with Swift, AppKit, SwiftUI, and Apple Native VideoToolbox hardware decoding, it offers an exceptionally smooth desktop live wallpaper experience without sacrificing battery life or system performance.

---

## 🌟 Design Philosophy & Priorities

This project adheres to a strict hierarchy of design decisions:

1. **Priority 1: Performance** (Zero unnecessary CPU/GPU/RAM usage)
2. **Priority 2: Stability** (Graceful fallback, non-crashing configuration handler)
3. **Priority 3: macOS Native Experience** (Adheres strictly to Apple HIG, Menu Bar App, AppKit desktop windows)
4. **Priority 4: Maintainability** (Clean modular architecture, documented code)
5. **Priority 5: Feature Richness**

> ⚠️ **No Heavyweight Frameworks**: We strictly avoid Electron, Chromium, React Native, Flutter, and Qt to deliver a pure native macOS footprint (< 40 MB RAM idle).

---

## ✨ Features

- 🖥️ **Native Desktop Windowing**: Layered below desktop icons with full mouse event pass-through and multi-space support.
- ⚡ **Hardware Accelerated Decoding**: VideoToolbox and AVFoundation stream playback with minimal memory overhead.
- ⏸️ **Intelligent Auto-Pause**: Automatically freezes playback and releases rendering resources during Mission Control, Launchpad, Stage Manager, Fullscreen Apps, or user-specified processes.
- 🧩 **Extensible JavaScript Plugins**: Embedded QuickJS runtime enables desktop clocks, widgets, and dynamic interactive overlays without Node.js dependencies.
- 📦 **Open `.wallpaper` Format**: Self-contained wallpaper packages containing media, metadata, licenses, and previews.
- 🖼️ **Multi-Monitor Support**: Configure unique wallpapers per monitor or synchronize across display arrays.
- 🎵 **Synced Audio Control**: Integrated volume and mute controls directly accessible from the Menu Bar.

---

## 📐 System Architecture

```
 +-------------------------------------------------------------------------+
 |                            User Interface                               |
 |   - SwiftUI GUI Manager (Library, Settings, Plugin Store, Log Viewer)   |
 |   - Menu Bar Control (NSStatusItem / AppKit Menu)                       |
 +-------------------------------------------------------------------------+
                                    |
                                    v
 +-------------------------------------------------------------------------+
 |                           App Controller Core                           |
 |   - StateManager (App lifecycle, Config JSON schema & migration)        |
 |   - AutoPauseEngine (Mission Control, Stage Manager, Fullscreen detector) |
 |   - DisplayManager (Multi-monitor workspace topology & hotplug)         |
 +-------------------------------------------------------------------------+
         |                                           |
         v                                           v
 +----------------------------------+   +----------------------------------+
 |       Wallpaper Engine           |   |       Plugin System              |
 | - DesktopWindow (AppKit Level)   |   | - QuickJS C-Bridge               |
 | - MediaPlaybackCore              |   | - JS Runtime Context             |
 |   (AVPlayer / VideoToolbox /    |   | - Canvas / Overlay Renderer      |
 |    FFmpeg fallback)              |   | - Event Bus & Native APIs        |
 +----------------------------------+   +----------------------------------+
```

---

## 🛠️ Building & Installation

### Requirements
- macOS 14.0 (Sonoma) or later
- Xcode 15.0+ or Swift 5.10 Toolchain
- Apple Silicon (M1/M2/M3/M4) or Intel x86_64 Mac

### Building the Application Bundle
```bash
git clone https://github.com/your-org/DynamicWallpaperEngine.git
cd DynamicWallpaperEngine

# Build macOS .app bundle and release zip
chmod +x scripts/build_app.sh
./scripts/build_app.sh
```

---

## 📄 License & Community

Distributed under the **Apache License 2.0**. See [`LICENSE`](LICENSE) for details.

- 🤝 **Contributing**: Read [`CONTRIBUTING.md`](CONTRIBUTING.md) to get started.
- 📜 **Code of Conduct**: See [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).
- 🛡️ **Security Policy**: See [`SECURITY.md`](SECURITY.md).
- 📝 **Changelog**: Detailed release history in [`CHANGELOG.md`](CHANGELOG.md).
