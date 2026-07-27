# JavaScript Plugin & Clock SDK Guide

DynamicWallpaperEngine supports extensible desktop clock widgets, dynamic overlays, and interactive animations powered by JavaScript.

---

## 📁 Plugin Package Layout

Every plugin is structured as a directory containing:

```
my-clock-plugin/
├── plugin.json
├── main.js
└── assets/
    └── font.ttf
```

---

## 📄 `plugin.json` Specification

```json
{
  "id": "com.example.clock.minimal",
  "name": "Minimal Digital Clock",
  "version": "1.0.0",
  "author": "Your Name",
  "mainJS": "main.js",
  "type": "clock",
  "defaultPositionX": 120.0,
  "defaultPositionY": 80.0
}
```

---

## 💻 `main.js` Example

```javascript
// Sandboxed JavaScript Clock Plugin
function renderClock() {
    const now = new Date();
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    const seconds = String(now.getSeconds()).padStart(2, '0');

    return `${hours}:${minutes}:${seconds}`;
}

// Global hook called by Swift JSPluginRuntime
onTick(function() {
    drawText(renderClock(), { font: "Inter", size: 48, color: "#FFFFFF" });
});
```
