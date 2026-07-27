[English](../CHANGELOG.md) | [繁體中文](CHANGELOG.md)

# 更新日誌

此專案的所有顯著變更都將記錄於此檔案中。

格式基於 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.0.0/)，
且本專案遵守 [語意化版本控制 (Semantic Versioning)](https://semver.org/spec/v2.0.0.html)。

## [0.1.0-alpha] - 2026-07-27

### 新增
- 支援隱藏 Dock 圖示的 macOS AppKit 原生 `NSStatusItem` 選單列應用程式。
- 核心桌面視窗引擎，使用 AppKit `.desktopWindow` 層級以進行多桌面 (multi-space) 桌布渲染。
- `MediaPlaybackCore` 串流媒體播放器，具備原生 `AVPlayer` / `AVURLAsset` 硬體解碼管線。
- `Multi-Monitor` 拓撲管理器 (`DisplayManager`)，支援顯示器熱插拔偵測。
- `AutoPauseEngine` 可偵測全螢幕應用程式、指揮中心 (Mission Control)、啟動台 (Launchpad) 與幕前調度 (Stage Manager)，在背景閒置時實現零 CPU/GPU 消耗。
- 開放的 `.wallpaper` 套件格式匯入器，具備自動硬體 HEVC GIF 轉影片功能 (`WallpaperPackageImporter`)。
- JavaScript 外掛執行階段 (`JSPluginRuntime`) 與時鐘小工具 SDK (`PluginMetadata`)。
- 具備向後相容性的 JSON 設定管理器 (`AppConfig`)，並支援綱要遷移處理。
- 統一的 `AppLogger` (`os.Logger` + 日誌檔案) 與 GitHub Release 更新檢查器 (`UpdateChecker`)。
- 完整的開發者文件 (`docs/ARCHITECTURE.md` & `docs/PLUGIN_GUIDE.md`)。
- 通用二進位檔 (Universal Binary) 編譯支援 (`arm64` & `x86_64`) 與自動化測試套件。
