# System Architecture & Flowchart

## Overview

DynamicWallpaperEngine is structured as a modular, layered native macOS architecture.

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

## Playback Lifecycle & Auto-Pause Flowchart

```mermaid
graph TD
    A[App Startup / Menu Bar Launched] --> B[Load JSON AppConfig]
    B --> C[Initialize DisplayManager]
    C --> D[Create DesktopWindowController per NSScreen]
    D --> E[Initialize MediaPlaybackCore with AVPlayer]
    E --> F[Start AutoPauseEngine Monitoring 1Hz]
    F --> G{Fullscreen / Mission Control Active?}
    G -- Yes --> H[Pause AVPlayer & Suspend Rendering]
    G -- No --> I[Resume AVPlayer Streaming Playback]
    H --> J[Zero CPU/GPU Resource Footprint]
    I --> F
    J --> F
```
