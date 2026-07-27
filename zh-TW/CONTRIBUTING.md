[English](../CONTRIBUTING.md) | [繁體中文](CONTRIBUTING.md)

# 貢獻指南

感謝您有興趣為 **DynamicWallpaperEngine** 做出貢獻！本專案旨在為 macOS 提供一個高效能、低資源消耗且開源的動態桌布播放器與外掛平台。

---

## 🎯 核心原則

所有貢獻必須嚴格遵守我們的核心優先順序：
1. **效能**：效能至上。任何不必要地增加 CPU/GPU/RAM 消耗的程式碼變更都將被拒絕。
2. **穩定性**：必須具備防禦性錯誤處理與向後相容性。
3. **macOS 原生體驗**：嚴格遵守 Apple HIG。不使用重量級網頁包裝器 (web wrappers) 或跨平台 UI 框架。
4. **可維護性**：乾淨的模組化程式碼、充足的註解以及完善的測試。

---

## 📝 提交規範 (Commit Convention)

我們強制要求所有 Git 提交訊息必須遵循 **Conventional Commits** 規範：

- `feat:` 新功能
- `fix:` 錯誤修復
- `docs:` 僅文件變更
- `perf:` 改善效能的程式碼變更
- `refactor:` 既不修復錯誤也不新增功能的程式碼重構
- `test:` 新增缺失的測試或修正現有的測試
- `ci:` CI 設定檔與腳本的變更

### 範例
```bash
git commit -m "feat(engine): implement AVPlayer hardware decoding pipeline"
git commit -m "fix(autopause): resolve Mission Control space detection edge case"
```

---

## 🛠️ 開發工作流程

1. 復刻 (Fork) 本儲存庫，並從 `main` 建立您的功能分支。
2. 確保您的程式碼能夠順利建置為 **通用二進位檔 (Universal Binary)**（`arm64` 與 `x86_64`）。
3. 為新功能新增單元測試。
4. 更新相關文件（`README.md`、`CHANGELOG.md`、API 規格）。
5. 提交符合 PR 範本的 Pull Request。

---

## 🧪 測試指南

在提交 Pull Request 之前，請在本地執行所有測試：
```bash
swift test
```
請確保所有自動化測試皆通過，並驗證符合記憶體佔用目標（閒置時 < 40 MB）。
