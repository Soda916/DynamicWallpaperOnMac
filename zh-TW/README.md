[English](../README.md) | [繁體中文](README.md)

# DynamicWallpaperEngine (macOS 原生動態桌布播放器與外掛平台)

[![macOS Sonoma+](https://img.shields.io/badge/macOS-14.0%2B%20Sonoma-blue.svg?style=flat&logo=apple)](https://www.apple.com/macos/)
[![Universal Binary](https://img.shields.io/badge/Architecture-Universal%20(Apple%20Silicon%20%2B%20Intel)-brightgreen.svg)](https://developer.apple.com/documentation/apple-silicon/)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](../LICENSE)
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

### 建置應用程式 (Application Bundle)
```bash
git clone https://github.com/your-org/DynamicWallpaperEngine.git
cd DynamicWallpaperEngine

# 建置 macOS .app bundle、發佈 zip 與 dmg 映像檔
chmod +x scripts/build_app.sh
./scripts/build_app.sh
# 產生的 .dmg 與 .zip 檔案將位於 build/ 目錄中。
```

### 系統架構版本與即時下載表格 (v0.1.4-alpha)

| 系統架構 | 晶片支援 | 設備相容性 | 官方下載連結 (Direct Download) |
| :--- | :--- | :--- | :--- |
| **Universal 通用版 (推薦)** | Apple Silicon + Intel | 所有 Mac 設備 | [DMG 檔](https://github.com/Soda916/DynamicWallpaperOnMac/releases/download/v0.1.4-alpha/DynamicWallpaperEngine-v0.1.4-alpha-macOS-Universal.dmg) \| [ZIP 檔](https://github.com/Soda916/DynamicWallpaperOnMac/releases/download/v0.1.4-alpha/DynamicWallpaperEngine-v0.1.4-alpha-macOS-Universal.zip) |
| **Apple Silicon 專用版** | `arm64` | M1 / M2 / M3 / M4 Mac | [DMG 檔](https://github.com/Soda916/DynamicWallpaperOnMac/releases/download/v0.1.4-alpha/DynamicWallpaperEngine-v0.1.4-alpha-macOS-arm64.dmg) \| [ZIP 檔](https://github.com/Soda916/DynamicWallpaperOnMac/releases/download/v0.1.4-alpha/DynamicWallpaperEngine-v0.1.4-alpha-macOS-arm64.zip) |
| **Intel 專用版** | `x86_64` | Intel Mac | [DMG 檔](https://github.com/Soda916/DynamicWallpaperOnMac/releases/download/v0.1.4-alpha/DynamicWallpaperEngine-v0.1.4-alpha-macOS-x86_64.dmg) \| [ZIP 檔](https://github.com/Soda916/DynamicWallpaperOnMac/releases/download/v0.1.4-alpha/DynamicWallpaperEngine-v0.1.4-alpha-macOS-x86_64.zip) |

### ⚠️ 常見問題：遇到「檔案已毀損」或未署名開發者警告時
透過瀏覽器下載非 App Store 應用程式時，macOS Gatekeeper 可能會顯示「"DynamicWallpaperEngine" 已經毀損，無法開啟。你應該將它丟到垃圾桶。」提示。

請依循以下步驟解除隔離屬性（Quarantine）：
1. 開啟 macOS 的 **終端機** (`Terminal.app`)。
2. 執行以下命令清除應用程式的 Gatekeeper 隔離屬性：
```bash
# 清除已解開/已安裝 App 的隔離屬性 (建議)
xattr -cr /Applications/DynamicWallpaperEngine.app

# 或明確指定移除 com.apple.quarantine 屬性
sudo xattr -rd com.apple.quarantine /Applications/DynamicWallpaperEngine.app
```
3. 若下載 Apple Silicon **ARM64** 版仍遇到狀況，請優先下載 **Universal (通用)** 版本作為臨時備案。

---

## 📄 授權條款與商業授權

本專案採用 **GNU General Public License v3 (GPL v3)** 與 **商業授權 (Commercial License)** 雙重授權模式：

- **開源免費使用**：在遵守 [`GPL v3`](../LICENSE) 條款的前提下，個人、學生與社群皆可免費使用、修改與散佈。
- **商業授權申請**：若公司企業需要在不遵守 GPL v3 源碼公開條款的情況下整合或進行商業專有產品發佈，必須申請商業授權：
  - **商業授權聯繫 Email**：`soda916ongithub+DynamicWallpaperBusiness@gmail.com`

詳細條款請參閱 [`LICENSE`](../LICENSE)。

- 🤝 **參與貢獻**：請閱讀 [`CONTRIBUTING.md`](CONTRIBUTING.md) 以開始貢獻。
- 📜 **行為準則**：請見 [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md)。
- 🛡️ **安全性政策**：請見 [`SECURITY.md`](SECURITY.md)。
- 📝 **更新日誌**：詳細的發佈歷史在 [`CHANGELOG.md`](CHANGELOG.md)。
