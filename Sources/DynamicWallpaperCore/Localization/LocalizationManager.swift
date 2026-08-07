import Foundation

public enum AppLanguage: String, CaseIterable, Sendable, Codable {
    case system = "system"
    case english = "en"
    case traditionalChinese = "zh-Hant"
    case simplifiedChinese = "zh-Hans"
    case japanese = "ja"

    public var displayName: String {
        switch self {
        case .system: return "System Default"
        case .english: return "English"
        case .traditionalChinese: return "繁體中文"
        case .simplifiedChinese: return "简体中文"
        case .japanese: return "日本語"
        }
    }
}

/// Central Localization Manager providing multi-language support (English, Traditional Chinese, Simplified Chinese, Japanese) with real-time UI switching.
public final class LocalizationManager: @unchecked Sendable {
    public static let shared = LocalizationManager()

    public private(set) var currentLanguage: AppLanguage = .system
    public var onLanguageChanged: (() -> Void)?

    private init() {}

    public func setLanguage(_ language: AppLanguage) {
        self.currentLanguage = language
        onLanguageChanged?()
    }

    public func localized(_ key: String, _ args: CVarArg...) -> String {
        let langCode = currentLangCode()
        let template: String
        if let dict = strings[langCode], let val = dict[key] {
            template = val
        } else if let fallbackDict = strings["en"], let fallbackVal = fallbackDict[key] {
            template = fallbackVal
        } else {
            template = key
        }

        if args.isEmpty {
            return template
        }
        return String(format: template, arguments: args)
    }

    private func currentLangCode() -> String {
        if currentLanguage != .system {
            return currentLanguage.rawValue
        }
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.starts(with: "zh-Hant") || preferred.starts(with: "zh-TW") || preferred.starts(with: "zh-HK") {
            return "zh-Hant"
        }
        if preferred.starts(with: "zh-Hans") || preferred.starts(with: "zh-CN") {
            return "zh-Hans"
        }
        if preferred.starts(with: "ja") {
            return "ja"
        }
        return "en"
    }

    private let strings: [String: [String: String]] = [
        "en": [
            "dashboard_title": "Dynamic Wallpaper Engine - Dashboard",
            "import_button": "Import / Select Wallpaper Video...",
            "prev_button": "⏮ Prev",
            "pause_button": "Pause",
            "play_button": "Play",
            "next_button": "Next ⏭",
            "mute_button": "Mute",
            "unmute_button": "Unmute",
            "playback_mode": "Playback Mode:",
            "auto_pause_fullscreen": "Enable Auto-Pause on Fullscreen / Maximize",
            "audio_ducking": "Audio Ducking (5% Volume)",
            "smart_power_saving": "Smart Power Saving (Pause on Low Battery & Reduce FPS / SDR Brightness)",
            "emergency_power_saving": "Emergency Power Saving (Complete 0% Energy Shutdown under 10% Battery)",
            "smart_power_saving_threshold": "Smart Power Saving Threshold: %d%%",
            "app_language": "App Language:",
            "remove_selected": "Remove Selected",
            "clear_playlist": "Clear Playlist",
            "console_logs": "Real-Time Console Chatter & Logs:",
            "status_ready": "Status: Ready",
            "status_playing": "Status: Playing %@"
        ],
        "zh-Hant": [
            "dashboard_title": "動態桌布引擎 - 控制儀表板",
            "import_button": "匯入 / 選擇動態桌布影片...",
            "prev_button": "⏮ 上一張",
            "pause_button": "暫停",
            "play_button": "播放",
            "next_button": "下一張 ⏭",
            "mute_button": "靜音",
            "unmute_button": "取消靜音",
            "playback_mode": "播放模式：",
            "auto_pause_fullscreen": "啟用全螢幕 / 最大化視窗自動暫停",
            "audio_ducking": "啟用背景音量鴨音 (減至 5%)",
            "smart_power_saving": "智慧省電模式 (低電量自動暫停 + 降低幀率 / SDR 亮度)",
            "emergency_power_saving": "緊急省電模式 (低於 10% 電量完全停止 0% 耗電運算)",
            "smart_power_saving_threshold": "智慧省電暫停門檻：%d%%",
            "app_language": "顯示語言：",
            "remove_selected": "移除選取項目",
            "clear_playlist": "清空播放清單",
            "console_logs": "實時系統 Chatter 與日誌監控：",
            "status_ready": "狀態：就緒",
            "status_playing": "狀態：正在播放 %@"
        ],
        "zh-Hans": [
            "dashboard_title": "动态壁纸引擎 - 控制仪表板",
            "import_button": "导入 / 选择动态壁纸视频...",
            "prev_button": "⏮ 上一张",
            "pause_button": "暂停",
            "play_button": "播放",
            "next_button": "下一张 ⏭",
            "mute_button": "静音",
            "unmute_button": "取消静音",
            "playback_mode": "播放模式：",
            "auto_pause_fullscreen": "启用全屏 / 最大化窗口自动暂停",
            "audio_ducking": "启用背景音量闪避 (降至 5%)",
            "smart_power_saving": "智能省电模式 (低电量自动暂停 + 降低帧率 / SDR 亮度)",
            "emergency_power_saving": "紧急省电模式 (低于 10% 电量完全停止 0% 耗电计算)",
            "smart_power_saving_threshold": "智能省电暂停门槛：%d%%",
            "app_language": "显示语言：",
            "remove_selected": "移除选中项目",
            "clear_playlist": "清空播放列表",
            "console_logs": "实时系统 Chatter 与日志监控：",
            "status_ready": "状态：就绪",
            "status_playing": "状态：正在播放 %@"
        ],
        "ja": [
            "dashboard_title": "ダイナミック壁紙エンジン - ダッシュボード",
            "import_button": "壁紙動画をインポート / 選択...",
            "prev_button": "⏮ 前へ",
            "pause_button": "一時停止",
            "play_button": "再生",
            "next_button": "次へ ⏭",
            "mute_button": "消音",
            "unmute_button": "消音解除",
            "playback_mode": "再生モード：",
            "auto_pause_fullscreen": "全画面 / 最大化時に自動一時停止を有効化",
            "audio_ducking": "オーディオダッキングを有効化 (5% 音量)",
            "smart_power_saving": "スマート省電力モード (低バッテリー時に一時停止 + フレームレート/SDR輝度低下)",
            "emergency_power_saving": "緊急省電力モード (10%未満で完全0%消費電力停止)",
            "smart_power_saving_threshold": "スマート省電力一時停止閾値：%d%%",
            "app_language": "表示言語：",
            "remove_selected": "選択項目を削除",
            "clear_playlist": "プレイリストをクリア",
            "console_logs": "リアルタイムログ＆チャッター：",
            "status_ready": "ステータス：準備完了",
            "status_playing": "ステータス：再生中 %@"
        ]
    ]
}
