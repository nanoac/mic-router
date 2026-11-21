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

    // Permission Onboarding Window
    case permWindowTitle
    case permHeading
    case permExplanation
    case permDragTitle
    case permDragHint
    case permOpenSettings
    case permRevealFinder
    case permRelaunch
    case permWaitingStatus
    case permGrantedStatus
    case permPrivacyFootnote
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

            .warnNeedPermission:    "⚠️ 需要「输入监控」权限（打开引导窗口）",
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

            .permWindowTitle:       "MicRouter 权限设置",
            .permHeading:           "需要「输入监控」权限",
            .permExplanation:       "小米蓝牙语音遥控器在 macOS 中被识别为蓝牙 HID 外设。MicRouter 需要此权限，才能在按下语音键的瞬间自动切换麦克风。",
            .permDragTitle:         "拖入系统设置列表",
            .permDragHint:          "1. 点击下方「打开系统设置」，勾选 MicRouter（若升级后未生效，请先关再开）。\n2. 如果列表里没有，直接把左侧图标拖进「输入监控」列表即可。",
            .permOpenSettings:      "打开「输入监控」设置",
            .permRevealFinder:      "在 Finder 中显示",
            .permRelaunch:          "重启生效",
            .permWaitingStatus:     "等待授权中… 勾选后将自动检测",
            .permGrantedStatus:     "✅ 授权成功！正在连接遥控器…",
            .permPrivacyFootnote:   "隐私承诺：仅监听小米遥控器语音键，不监听键盘、不录音、不联网。",
        ],
        .zhHant: [
            .tooltipNeedPermission: "MicRouter：需要「輸入監控」權限",
            .tooltipPaused:         "MicRouter：已暫停",
            .tooltipVoiceActive:    "MicRouter：正在使用遙控器麥克風",
            .tooltipActive:         "MicRouter：執行中",

            .warnNeedPermission:    "⚠️ 需要「輸入監控」權限（開啟引導視窗）",
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

            .permWindowTitle:       "MicRouter 權限設定",
            .permHeading:           "需要「輸入監控」權限",
            .permExplanation:       "小米藍牙語音遙控器在 macOS 中被識別為藍牙 HID 裝置。MicRouter 需要此權限，才能在按下語音鍵的瞬間自動切換麥克風。",
            .permDragTitle:         "拖入系統設定列表",
            .permDragHint:          "1. 點擊下方「開啟系統設定」，勾選 MicRouter（若升級後未生效，請先關再開）。\n2. 如果列表裡沒有，直接把左側圖示拖進「輸入監控」列表即可。",
            .permOpenSettings:      "開啟「輸入監控」設定",
            .permRevealFinder:      "在 Finder 中顯示",
            .permRelaunch:          "重新啟動生效",
            .permWaitingStatus:     "等待授權中… 勾選後將自動偵測",
            .permGrantedStatus:     "✅ 授權成功！正在連線遙控器…",
            .permPrivacyFootnote:   "隱私承諾：僅監聽小米遙控器語音鍵，不監聽鍵盤、不錄音、不連網。",
        ],
        .en: [
            .tooltipNeedPermission: "MicRouter: Input Monitoring permission required",
            .tooltipPaused:         "MicRouter: Paused",
            .tooltipVoiceActive:    "MicRouter: Remote mic active",
            .tooltipActive:         "MicRouter: Active",

            .warnNeedPermission:    "⚠️ Input Monitoring Required (Open Guide)",
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

            .permWindowTitle:       "MicRouter Permission Setup",
            .permHeading:           "Input Monitoring Permission Required",
            .permExplanation:       "macOS treats the Xiaomi Bluetooth Remote as a HID device. MicRouter needs Input Monitoring so it can switch microphones the instant you press the remote's voice key.",
            .permDragTitle:         "Drag into System Settings",
            .permDragHint:          "1. Click \"Open Input Monitoring\" and enable MicRouter (toggle off & on after an update).\n2. If it's not listed, drag the app icon on the left directly into the Input Monitoring list.",
            .permOpenSettings:      "Open Input Monitoring",
            .permRevealFinder:      "Reveal in Finder",
            .permRelaunch:          "Relaunch",
            .permWaitingStatus:     "Waiting for permission… auto-detecting",
            .permGrantedStatus:     "✅ Permission granted! Connecting remote…",
            .permPrivacyFootnote:   "Privacy: Only listens to the Xiaomi remote voice button. Never logs keys, records audio, or accesses the network.",
        ],
        .ja: [
            .tooltipNeedPermission: "MicRouter：入力監視の権限が必要です",
            .tooltipPaused:         "MicRouter：一時停止中",
            .tooltipVoiceActive:    "MicRouter：リモコンマイク使用中",
            .tooltipActive:         "MicRouter：動作中",

            .warnNeedPermission:    "⚠️「入力監視」の権限が必要です（ガイドを開く）",
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

            .permWindowTitle:       "MicRouter 権限の設定",
            .permHeading:           "「入力監視」の権限が必要です",
            .permExplanation:       "Xiaomi Bluetooth リモコンは macOS 上で HID デバイスとして認識されます。音声ボタンを押した瞬間にマイクを切り替えるため、入力監視の権限が必要です。",
            .permDragTitle:         "システム設定へドラッグ",
            .permDragHint:          "1. 下の「入力監視を開く」から MicRouter をオンにしてください（更新後は一度オフ→オン）。\n2. 一覧にない場合は、左のアイコンをそのまま入力監視リストへドラッグできます。",
            .permOpenSettings:      "「入力監視」設定を開く",
            .permRevealFinder:      "Finder で表示",
            .permRelaunch:          "再起動して反映",
            .permWaitingStatus:     "権限の許可を待機中… 自動検出します",
            .permGrantedStatus:     "✅ 権限が確認されました！接続しています…",
            .permPrivacyFootnote:   "プライバシー：リモコンの音声ボタンのみ監視。キーボード入力・録音・通信は一切行いません。",
        ],
    ]
}
