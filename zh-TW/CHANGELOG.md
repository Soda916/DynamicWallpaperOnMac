[English](../CHANGELOG.md) | [繁體中文](CHANGELOG.md)

# 更新日誌

此專案的所有顯著變更都將記錄於此檔案中。

格式基於 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.0.0/)，
且本專案遵守 [語意化版本控制 (Semantic Versioning)](https://semver.org/spec/v2.0.0.html)。

## [0.1.2-alpha] - 2026-07-29

### 新增與重構 (Added & Refactored)
- **集中化隱藏媒體庫 (`MediaStorageManager`)**：
  - 自動將匯入之動態桌布整理收納於 `~/.dynamicwallpaper/media/` 隱藏目錄。
  - 支援 5 種媒體處理模式：軟連結 (`symlink`)、硬連結 (`hardlink`)、直接複製 (`copy`)、移動檔案 (`move`) 與 原檔路徑 (`direct`)。
- **原生 FFmpeg 管理器 (`FFmpegManager`)**：
  - 動態偵測系統環境 PATH 及 Homebrew (`/opt/homebrew/bin/ffmpeg`) 安裝之 FFmpeg 執行檔。
  - 嚴格遵守輕量原生原則，不安裝/打包特定 FFmpeg 二進位檔至應用程式目錄。
  - 遇到 AV1/VP9 轉碼需求時提供非侵入式 Homebrew (`brew install ffmpeg`) 安裝提醒。
- **JavaScript 插件引擎與 WebKit 桌面圖層 (`PluginManager`)**：
  - 於桌面視窗整合透明 WebKit (`WKWebView`) 圖層，支援動態元件繪製於動態桌布之上。
  - 預設內建微光玻璃擬物數位時鐘 (`Digital Clock`) 桌面插件 (`~/.dynamicwallpaper/plugins/digital_clock`)。
- **GitHub Release 自動檢查與更新提醒 (`UpdateChecker`)**：
  - 實作語意化版本比對演算法 (`isVersionNewer`)，相容 `0.1.2-alpha` 等預發布標籤。
  - 支援非同步新版發布通知與原生 `NSAlert` 對話框，一鍵開啟 GitHub 發布頁面下載。

### 效能優化與錯誤修復 (Performance & Bug Fixes)
- **極致低資源 AppLogger 日誌引擎優化 (`AppLogger`)**：
  - 解決 CPU 101% 高負載與 1.6GB 磁碟寫入膨脹問題：移除逐條產生的 `ISO8601DateFormatter` 與同步檔案控制代碼。
  - 引入背景佇列 (`ioQueue`) 非同步寫入、150 條記憶體日誌上限與 1MB 檔案容量旋轉上限 (`maxLogFileSize`)。
- **AppConfig Schema v3 升級與容錯降級 (`AppConfig`)**：
  - 配置檔案升級至 `Schema v3`，增強屬性預設值降級與舊版無縫升級遷移 (`.migrated`)。

## [0.1.1-alpha] - 2026-07-28

### 新增 (Added)
- **多影片播放清單系統 (`Playlist`)**：
  - 支援一次選取/匯入多個影片，Dashboard 新增 `NSTableView` 清單列表、雙擊指定切換、單條目移除與一鍵清空功能。
  - 三種播放模式：單條目循環 (`Single Track Loop`)、清單順序播放 (`Sequential Playlist`) 與隨機播放 (`Random Shuffle`)。
  - 新增「上一首 `⏮ Prev`」、「下一首 `Next ⏭`」按鈕與模式切換下拉選單。
- **Dashboard 拖曳自動匯入 (`Drag & Drop Import`)**：
  - 支援直接將一個或多個影片檔案 (.mp4, .mov, .webm, .gif) 拖拽進 Dashboard 視窗，自動按拖放順序追加至播放清單。
- **背景影片播放進度條 (`Progress Scrubber & Timer`)**：
  - 加回影片進度控制條 (`NSSlider`) 與時間標籤 (`MM:SS / MM:SS`)，支援拖動進度條即時快進/快退桌面背景播放點。
- **自動化 Universal 2 DMG 打包腳本 (`build_app.sh`)**：
  - 新增自動化 Universal Binary (arm64 + x86_64) 二進位編譯與 DMG 安裝鏡像生成指令。

### 變更與重構 (Changed & Refactored)
- **智慧全螢幕 Auto-Pause 引擎重構 (`AutoPauseEngine`)**：
  - 改為全顯示器 (`NSScreen.screens`) 所有可見視窗 (`CGWindowListCopyWindowInfo`) 動態掃描，解決非聚焦全螢幕、多螢幕情境下的零 CPU/GPU 資源浪費問題。
- **CoreAudio 智慧音訊偵測與系統音效過濾 (`AudioDuckingDetector`)**：
  - 監控 CoreAudio 裝置音訊 Output 通道，自動過濾 `systemsoundserverd`（通知音/打字聲）、`coreaudiod` 等背景系統服務。
  - 於選單列與 Dashboard UI 即時透明化顯示發聲 App 名稱（例如：`Active: Spotify`）。
- **平滑音量漸變 Fade Engine (`MediaPlaybackCore`)**：
  - 實裝 30Hz Ease-Out 音量漸變插值引擎，切換 Ducking 音量時會在 ~0.8 秒內優雅地「漸小」與「漸大」。

### 修復與持久化 (Fixed & Persistence)
- **設定檔升級為 Schema v2 (`AppConfig`)**：
  - 自動記錄與恢復 `playlistPaths`、`playbackMode` 與 `playlistIndex`，具備 JSON 向後相容解碼能力。
- **單一實例防重開保護 (Single Instance Enforcement)**：
  - 啟動時自動檢測 PID，防止重複開啟多個 Engine 實例。

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
