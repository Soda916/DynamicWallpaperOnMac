[English](CONTRIBUTING.md) | [繁體中文](zh-TW/CONTRIBUTING.md)

# Contributing Guidelines

Thank you for your interest in contributing to **DynamicWallpaperEngine**! This project aims to be a high-performance, low-resource open-source dynamic wallpaper player and plugin platform for macOS.

---

## 🎯 Core Principles

All contributions must strictly follow our core priorities:
1. **Performance**: Performance comes first. Code changes that increase CPU/GPU/RAM consumption unnecessarily will be rejected.
2. **Stability**: Defensive error handling and backward compatibility are required.
3. **macOS Native Experience**: Adhere strictly to Apple HIG. No heavyweight web wrappers or cross-platform UI frameworks.
4. **Maintainability**: Clear modular code, sufficient comments, and comprehensive tests.

---

## 📝 Commit Convention

We enforce the **Conventional Commits** specification for all git commit messages:

- `feat:` A new feature
- `fix:` A bug fix
- `docs:` Documentation only changes
- `perf:` A code change that improves performance
- `refactor:` A code change that neither fixes a bug nor adds a feature
- `test:` Adding missing tests or correcting existing tests
- `ci:` Changes to CI configuration files and scripts

### Example
```bash
git commit -m "feat(engine): implement AVPlayer hardware decoding pipeline"
git commit -m "fix(autopause): resolve Mission Control space detection edge case"
```

---

## 🛠️ Development Workflow

1. Fork the repository and create your feature branch from `main`.
2. Make sure your code builds cleanly as a **Universal Binary** (`arm64` and `x86_64`).
3. Add unit tests for new functionality.
4. Update relevant documentation (`README.md`, `CHANGELOG.md`, API specs).
5. Open a Pull Request adhering to the PR template.

---

## 🧪 Testing Guidelines

Before submitting a Pull Request, run all tests locally:
```bash
swift test
```
Ensure all automated tests pass and memory footprint targets (< 40 MB idle) are verified.
