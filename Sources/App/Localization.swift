import Foundation

enum AppLanguage: String, CaseIterable {
    case system
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case en
    case ja

    var nativeLabel: String {
        switch self {
        case .system: return L10n.t(.langFollowSystem)
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        case .en:     return "English"
        case .ja:     return "日本語"
        }
    }

    /// Resolves `.system` to a concrete language based on `Locale.preferredLanguages`.
    var resolved: AppLanguage {
        guard self == .system else { return self }
        for lang in Locale.preferredLanguages {
            let lower = lang.lowercased()
            if lower.hasPrefix("zh-hant") || lower.hasPrefix("zh-tw") ||
               lower.hasPrefix("zh-hk") || lower.hasPrefix("zh-mo") {
                return .zhHant
            }
            if lower.hasPrefix("zh") {
                return .zhHans
            }
            if lower.hasPrefix("ja") {
                return .ja
            }
            if lower.hasPrefix("en") {
                return .en
            }
        }
        return .en
    }
}

enum L10nKey {
    case tooltipNeedPermission
    case tooltipPaused
    case tooltipVoiceActive
    case tooltipActive

    case warnNeedPermission
    case remoteConnectedFmt
    case remoteDisconnected
    case defaultMicFmt
    case none

    case enableAutoSwitch
    case remoteMicMenuFmt
    case remoteMicNotFound
    case remoteMicAutoFmt
    case virtualTag

    case restoreDelayMenuFmt
    case recommendedSuffix

    case languageMenu
    case langFollowSystem

    case launchAtLogin
    case loginErrorTitle
    case loginErrorHint

    case hideMenuBarIcon
    case hideAlertTitle
    case hideAlertBody
    case hideAlertConfirm
    case cancel

    case viewLog
    case quitApp
}

final class L10n {
    static var current: AppLanguage = .system

    static func t(_ key: L10nKey) -> String {
        let lang = current.resolved
        return table[lang]?[key] ?? table[.en]![key]!
    }

    static func fmt(_ key: L10nKey, _ args: CVarArg...) -> String {
        String(format: t(key), arguments: args)
    }

    private static let table: [AppLanguage: [L10nKey: String]] = [
        .zhHans: [
            .tooltipNeedPermission: "MicRouter：需要「输入监控」权限",
            .tooltipPaused:         "MicRouter：已暂停",
            .tooltipVoiceActive:    "MicRouter：正在使用遥控器麦克风",
            .tooltipActive:         "MicRouter：运行中",

            .warnNeedPermission:    "⚠️ 需要「输入监控」权限（点击前往设置）",
            .remoteConnectedFmt:    "遥控器：已连接（%@）",
            .remoteDisconnected:    "遥控器：未连接（等待小米遥控器）",
            .defaultMicFmt:         "当前默认麦：%@",
            .none:                  "无",

            .enableAutoSwitch:      "启用自动切换",
            .remoteMicMenuFmt:      "遥控器虚拟麦：%@",
            .remoteMicNotFound:     "未找到",
            .remoteMicAutoFmt:      "自动检测（跟随 SayAll：%@）",
            .virtualTag:            " [虚拟]",

            .restoreDelayMenuFmt:   "松开恢复延迟：%.1fs",
            .recommendedSuffix:     "（推荐）",

            .languageMenu:          "语言 / Language",
            .langFollowSystem:      "跟随系统",

            .launchAtLogin:         "开机自动启动",
            .loginErrorTitle:       "无法修改开机自启设置",
            .loginErrorHint:        "请确保 MicRouter.app 已放入 /Applications 目录。",

            .hideMenuBarIcon:       "隐藏菜单栏图标…",
            .hideAlertTitle:        "隐藏菜单栏图标？",
            .hideAlertBody:         "隐藏后 MicRouter 会继续在后台静默运行。\n\n需要重新显示菜单栏图标时，只需在 Spotlight / Raycast 或「应用程序」中再次打开 MicRouter 即可。",
            .hideAlertConfirm:      "隐藏图标",
            .cancel:                "取消",

            .viewLog:               "查看运行日志",
            .quitApp:               "退出 MicRouter",
        ],
        .zhHant: [
            .tooltipNeedPermission: "MicRouter：需要「輸入監控」權限",
            .tooltipPaused:         "MicRouter：已暫停",
            .tooltipVoiceActive:    "MicRouter：正在使用遙控器麥克風",
            .tooltipActive:         "MicRouter：執行中",

            .warnNeedPermission:    "⚠️ 需要「輸入監控」權限（點擊前往設定）",
            .remoteConnectedFmt:    "遙控器：已連線（%@）",
            .remoteDisconnected:    "遙控器：未連線（等待小米遙控器）",
            .defaultMicFmt:         "目前預設麥克風：%@",
            .none:                  "無",

            .enableAutoSwitch:      "啟用自動切換",
            .remoteMicMenuFmt:      "遙控器虛擬麥克風：%@",
            .remoteMicNotFound:     "未找到",
            .remoteMicAutoFmt:      "自動偵測（跟隨 SayAll：%@）",
            .virtualTag:            " [虛擬]",

            .restoreDelayMenuFmt:   "放開恢復延遲：%.1fs",
            .recommendedSuffix:     "（推薦）",

            .languageMenu:          "語言 / Language",
            .langFollowSystem:      "跟隨系統",

            .launchAtLogin:         "開機自動啟動",
            .loginErrorTitle:       "無法修改開機自啟設定",
            .loginErrorHint:        "請確保 MicRouter.app 已放入 /Applications 目錄。",

            .hideMenuBarIcon:       "隱藏選單列圖示…",
            .hideAlertTitle:        "隱藏選單列圖示？",
            .hideAlertBody:         "隱藏後 MicRouter 會繼續在背景靜默執行。\n\n需要重新顯示選單列圖示時，只需在 Spotlight / Raycast 或「應用程式」中再次開啟 MicRouter 即可。",
            .hideAlertConfirm:      "隱藏圖示",
            .cancel:                "取消",

            .viewLog:               "檢視執行日誌",
            .quitApp:               "結束 MicRouter",
        ],
        .en: [
            .tooltipNeedPermission: "MicRouter: Input Monitoring permission required",
            .tooltipPaused:         "MicRouter: Paused",
            .tooltipVoiceActive:    "MicRouter: Remote mic active",
            .tooltipActive:         "MicRouter: Active",

            .warnNeedPermission:    "⚠️ Input Monitoring Required (Open Settings)",
            .remoteConnectedFmt:    "Remote: Connected (%@)",
            .remoteDisconnected:    "Remote: Disconnected (Waiting for RC003)",
            .defaultMicFmt:         "Default Mic: %@",
            .none:                  "None",

            .enableAutoSwitch:      "Enable Auto Switching",
            .remoteMicMenuFmt:      "Remote Virtual Mic: %@",
            .remoteMicNotFound:     "Not Found",
            .remoteMicAutoFmt:      "Auto (Follow SayAll: %@)",
            .virtualTag:            " [Virtual]",

            .restoreDelayMenuFmt:   "Restore Delay: %.1fs",
            .recommendedSuffix:     " (Recommended)",

            .languageMenu:          "Language",
            .langFollowSystem:      "Follow System",

            .launchAtLogin:         "Launch at Login",
            .loginErrorTitle:       "Failed to update Launch at Login",
            .loginErrorHint:        "Make sure MicRouter.app is located in /Applications.",

            .hideMenuBarIcon:       "Hide Menu Bar Icon…",
            .hideAlertTitle:        "Hide Menu Bar Icon?",
            .hideAlertBody:         "MicRouter will continue running silently in the background.\n\nTo show the menu bar icon again, simply reopen MicRouter from Spotlight or Applications.",
            .hideAlertConfirm:      "Hide Icon",
            .cancel:                "Cancel",

            .viewLog:               "View Log",
            .quitApp:               "Quit MicRouter",
        ],
        .ja: [
            .tooltipNeedPermission: "MicRouter：入力監視の権限が必要です",
            .tooltipPaused:         "MicRouter：一時停止中",
            .tooltipVoiceActive:    "MicRouter：リモコンマイク使用中",
            .tooltipActive:         "MicRouter：動作中",

            .warnNeedPermission:    "⚠️「入力監視」の権限が必要です（設定を開く）",
            .remoteConnectedFmt:    "リモコン：接続済み（%@）",
            .remoteDisconnected:    "リモコン：未接続（RC003 待機中）",
            .defaultMicFmt:         "デフォルトマイク：%@",
            .none:                  "なし",

            .enableAutoSwitch:      "自動切替を有効にする",
            .remoteMicMenuFmt:      "リモコン仮想マイク：%@",
            .remoteMicNotFound:     "未検出",
            .remoteMicAutoFmt:      "自動検出（SayAll に連動：%@）",
            .virtualTag:            " [仮想]",

            .restoreDelayMenuFmt:   "復帰ディレイ：%.1fs",
            .recommendedSuffix:     "（推奨）",

            .languageMenu:          "言語 / Language",
            .langFollowSystem:      "システムに従う",

            .launchAtLogin:         "ログイン時に自動起動",
            .loginErrorTitle:       "自動起動の設定を変更できません",
            .loginErrorHint:        "MicRouter.app が /Applications フォルダにあることを確認してください。",

            .hideMenuBarIcon:       "メニューバーアイコンを隠す…",
            .hideAlertTitle:        "メニューバーアイコンを隠しますか？",
            .hideAlertBody:         "非表示にしても MicRouter はバックグラウンドで動作し続けます。\n\n再表示したい場合は、Spotlight または「アプリケーション」から MicRouter をもう一度開いてください。",
            .hideAlertConfirm:      "アイコンを隠す",
            .cancel:                "キャンセル",

            .viewLog:               "ログを表示",
            .quitApp:               "MicRouter を終了",
        ],
    ]
}
