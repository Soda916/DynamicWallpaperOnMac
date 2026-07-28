# Release Notes - v0.1.0-alpha (2026-07-28)

我們非常高興地宣布 **DynamicWallPaper** 第一個測試版本 `v0.1.0-alpha` 正式發布！本專案是一個專為 macOS 設計的原生動態桌布引擎，旨在提供極致的硬體解碼效能、低能耗設計以及豐富的客製化外掛支援。

---

## 🚀 核心功能與改進 (Core Features & Enhancements)

### 1. 選單列與桌面視窗引擎 (Menu Bar & Desktop Window Engine)
* **選單列原生運行**：採用 macOS AppKit 原生 `NSStatusItem` 選單列模式，支援隱藏 Dock 圖示以保持桌面簡潔。
* **視窗底層桌布渲染**：使用 AppKit 底層 `.desktopWindow` 層級進行桌布渲染，支援多桌面 (Multi-space) 平滑展示，並修復了視窗 z-index 圖層順序。
* **桌面控制台 (Dashboard)**：內建互動式控制面板，支援動態桌布切換與即時監控。

### 2. 智慧自動暫停功能 (Auto-Pause Engine)
* **零背景能耗設計**：智慧型 `AutoPauseEngine` 可即時偵測使用者是否開啟全螢幕應用程式、啟動台 (Launchpad)、指揮中心 (Mission Control) 或使用幕前調度 (Stage Manager)。
* **自動凍結**：偵測到上述場景或視窗被覆蓋時，桌布引擎會立刻暫停播放，實現零 CPU/GPU 背景閒置消耗。
* **快速鍵支援**：新增 `Option + 綠色視窗按鈕` 快速觸發自動暫停切換，並在選單列中加入勾選狀態同步。

### 3. 硬體加速媒體播放管線 (Media Playback & Audio Pipeline)
* **原生硬體解碼**：使用 macOS 原生 `AVPlayer` 與 `AVURLAsset` 建立高效能串流媒體播放管線。
* **自動轉碼支援**：具備 AV1 與 VP9 影片自動轉碼功能，轉碼時自動標記 FFmpeg `hvc1` 標籤以發揮晶片硬解能力。
* **智慧音訊管理**：支援 5% 智慧音訊避讓 (Audio Ducking)、雙向靜音與音量狀態同步。

### 4. 開放套件匯入與 JS 外掛執行環境 (Extensibility)
* **開放 `.wallpaper` 套件**：實作 `WallpaperPackageImporter`，支援匯入開放格式的桌布包，並對 GIF 圖檔進行自動硬體加速 HEVC 影片轉換。
* **JavaScript Widget 支援**：內建 `JSPluginRuntime` 執行環境與時鐘 Widget SDK (`PluginMetadata`)，支援在桌面上疊加動態時鐘與小工具。

### 5. 構建打包與自動化 (Build & Distribution)
* **Universal 2 雙架構支援**：新增自動化編譯指令碼，支援同時為 Apple Silicon (`arm64`) 與 Intel (`x86_64`) 架構編譯，並利用 `lipo` 自動打包為通用二進位檔 (Universal Binary)。
* **DMG 安裝器生成**：支援利用 macOS `hdiutil` 工具一鍵自動生成 DMG 安裝檔與外觀配置。
* **原生圖示生成**：自動從 `play.laptopcomputer.svg` 向量檔渲染出適應光/暗模式的 AppIcon.icns 與選單列模板圖標。

---

## 🛠️ 技術優化與問題修復

* **移除 SwiftUI 宏依賴**：為解決 SwiftUIMacros 編譯衝突，全面將 Dashboard 重構為純 AppKit `DashboardWindowController`，大幅提升編譯穩定度與 GUI 效能。
* **多顯示器熱插拔**：實作 `DisplayManager` 顯示器拓撲管理器，支援多螢幕熱插拔自動偵測與桌布自動附加。
* **綱要自動遷移**：採用具備向後相容性的 `AppConfig` 設定檔管理器，支援舊版設定綱要的自動平滑遷移。
* **統一日誌系統**：引進 `AppLogger`，整合原生 `os.Logger` 與本機日誌檔案輸出，方便調試。

---

## 📦 構建與安裝步驟

1. **安裝 Swift 依賴項與環境**（確保 Swift 5.9+ 與 macOS 14+ SDK）。
2. **執行編譯指令碼**：
   ```bash
   ./scripts/build_app.sh
   ```
3. **執行測試套件**：
   ```bash
   ./RunTests
   ```
