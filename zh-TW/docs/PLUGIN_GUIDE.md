[English](../../docs/PLUGIN_GUIDE.md) | [繁體中文](PLUGIN_GUIDE.md)

# JavaScript 外掛與時鐘 SDK 指南

DynamicWallpaperEngine 支援可擴充的桌面時鐘小工具、動態疊加層，以及由 JavaScript 驅動的互動式動畫。

---

## 📁 外掛套件目錄結構

每個外掛都組織成一個目錄，包含：

```
my-clock-plugin/
├── plugin.json
├── main.js
└── assets/
    └── font.ttf
```

---

## 📄 `plugin.json` 規格

```json
{
  "id": "com.example.clock.minimal",
  "name": "極簡數位時鐘",
  "version": "1.0.0",
  "author": "你的名字",
  "mainJS": "main.js",
  "type": "clock",
  "defaultPositionX": 120.0,
  "defaultPositionY": 80.0
}
```

---

## 💻 `main.js` 範例

```javascript
// 沙箱化 JavaScript 時鐘外掛
function renderClock() {
    const now = new Date();
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    const seconds = String(now.getSeconds()).padStart(2, '0');

    return `${hours}:${minutes}:${seconds}`;
}

// 全域掛鉤，由 Swift JSPluginRuntime 呼叫
onTick(function() {
    drawText(renderClock(), { font: "Inter", size: 48, color: "#FFFFFF" });
});
```
