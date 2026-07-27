[English](../README.md) | [繁體中文](README.md)

# DynamicWallpaperEngine (macOS 原生動態桌布播放器與外掛平台)

[![macOS Sonoma+](https://img.shields.io/badge/macOS-14.0%2B%20Sonoma-blue.svg?style=flat&logo=apple)](https://www.apple.com/macos/)
[![Universal Binary](https://img.shields.io/badge/Architecture-Universal%20(Apple%20Silicon%20%2B%20Intel)-brightgreen.svg)](https://developer.apple.com/documentation/apple-silicon/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![CI Build](https://github.com/your-org/DynamicWallpaperEngine/actions/workflows/ci.yml/badge.svg)](https://github.com/your-org/DynamicWallpaperEngine/actions)

**DynamicWallpaperEngine** 是一個高效能、低資源消耗、可擴展且開源的 macOS 原生動態桌布執行階段與外掛平台。本專案嚴格使用 Swift、AppKit、SwiftUI 以及 Apple 原生的 VideoToolbox 硬體解碼進行開發，能在不犧牲電池續航力或系統效能的情況下，提供極致流暢的桌面動態桌布體驗。

---

## 🌟 設計理念與優先順序

本專案嚴格遵守以下設計決策層級：

1. **優先順序 1：效能**（零不必要的 CPU/GPU/RAM 消耗）
2. **優先順序 2：穩定性**（優雅降級，不崩潰的設定處理機制）
3. **優先順序 3：macOS 原生體驗**（嚴格遵守 Apple HIG、選單列應用程式、AppKit 桌面視窗）
4. **優先順序 4：可維護性**（乾淨的模組化架構，程式碼附有文件）
5. **優先順序 5：功能豐富度**

> ⚠️ **無重量級框架**：我們嚴格避免使用 Electron、Chromium、React Native、Flutter 和 Qt，以提供純粹的原生 macOS 佔用（閒置時 RAM < 40 MB）。

---

## ✨ 功能特色

- 🖥️ **原生桌面視窗**：位於桌面圖示底層，完全支援滑鼠事件穿透與多桌面（多空間）支援。
- ⚡ **硬體加速解碼**：VideoToolbox 與 AVFoundation 串流播放，記憶體開銷降至最低。
- ⏸️ **智慧自動暫停**：在進入指揮中心 (Mission Control)、啟動台 (Launchpad)、幕前調度 (Stage Manager)、全螢幕應用程式或使用者指定處理程序時，自動凍結播放並釋放渲染資源。
- 🧩 **可擴展的 JavaScript 外掛**：內建 QuickJS 執行階段，無須 Node.js 依賴即可啟用桌面時鐘、小工具與動態互動式疊加層。
- 📦 **開放 `.wallpaper` 格式**：獨立的桌布套件，內含媒體、中繼資料、授權與預覽圖。
- 🖼️ **多螢幕支援**：可為每部顯示器設定獨特的桌布，或在顯示器陣列間同步。
- 🎵 **同步音訊控制**：可直接從選單列存取整合的音量與靜音控制。

---

## 📐 系統架構

```
 +-------------------------------------------------------------------------+
 |                              使用者介面                                 |
 |   - SwiftUI GUI 管理器 (資料庫、設定、外掛商店、日誌檢視器)             |
 |   - 選單列控制 (NSStatusItem / AppKit 選單)                             |
 +-------------------------------------------------------------------------+
                                    |
                                    v
 +-------------------------------------------------------------------------+
 |                             應用程式核心                                |
 |   - 狀態管理器 StateManager (App 生命週期, 設定 JSON 綱要與遷移)        |
 |   - 自動暫停引擎 AutoPauseEngine (指揮中心, 幕前調度, 全螢幕偵測)       |
 |   - 顯示器管理器 DisplayManager (多螢幕工作空間拓撲與熱插拔)            |
 +-------------------------------------------------------------------------+
         |                                           |
         v                                           v
 +----------------------------------+   +----------------------------------+
 |           桌布引擎               |   |           外掛系統               |
 | - DesktopWindow (AppKit 層級)    |   | - QuickJS C-Bridge               |
 | - MediaPlaybackCore              |   | - JS Runtime Context             |
 |   (AVPlayer / VideoToolbox /    |   | - Canvas / 疊加層渲染器          |
 |    FFmpeg 備用方案)              |   | - 事件匯流排 & 原生 API          |
 +----------------------------------+   +----------------------------------+
```

---

## 🛠️ 建置與安裝

### 系統需求
- macOS 14.0 (Sonoma) 或更新版本
- Xcode 15.0+ 或 Swift 5.10 工具鏈
- Apple Silicon (M1/M2/M3/M4) 或 Intel x86_64 Mac

### 建置通用二進位檔 (Universal Binary)
```bash
git clone https://github.com/your-org/DynamicWallpaperEngine.git
cd DynamicWallpaperEngine

# 建置通用二進位檔發佈版本
swift build -c release --arch arm64 --arch x86_64
```

---

## 📄 授權與社群

基於 **Apache License 2.0** 散佈。詳情請見 [`LICENSE`](LICENSE)。

- 🤝 **參與貢獻**：請閱讀 [`CONTRIBUTING.md`](CONTRIBUTING.md) 以開始貢獻。
- 📜 **行為準則**：請見 [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md)。
- 🛡️ **安全性政策**：請見 [`SECURITY.md`](SECURITY.md)。
- 📝 **更新日誌**：詳細的發佈歷史在 [`CHANGELOG.md`](CHANGELOG.md)。
