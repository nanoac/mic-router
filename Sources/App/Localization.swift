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
    case permSubtitle
    case permStep1Title
    case permStep1Desc
    case permStep2Title
    case permStep2Desc
    case permStep3Title
    case permStep3Desc
    case permDragBadge
    case permOpenSettings
    case permRelaunch
    case permWaitingStatus
    case permGrantedStatus
    case permWhyToggleClosed
    case permWhyToggleOpen
    case permWhyBody
    case permViewSourceLink
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

            .permWindowTitle:       "MicRouter 权限引导",
            .permHeading:           "开启「输入监控」即可使用",
            .permSubtitle:          "仅用于识别小米遥控器语音键，不监听键盘、不录音、不联网",
            .permStep1Title:        "打开系统设置",
            .permStep1Desc:         "点击下方蓝色按钮，自动添加 MicRouter",
            .permStep2Title:        "开启 MicRouter 开关",
            .permStep2Desc:         "若列表未出现，把左侧图标拖进去即可",
            .permStep3Title:        "放心点「退出并重新打开」",
            .permStep3Desc:         "系统弹窗确认后会自动重启并生效",
            .permDragBadge:         "可拖拽",
            .permOpenSettings:      "打开「输入监控」设置",
            .permRelaunch:          "手动重启",
            .permWaitingStatus:     "等待授权中…",
            .permGrantedStatus:     "✅ 授权成功！正在连接…",
            .permWhyToggleClosed:   "为什么需要「输入监控」权限？▸",
            .permWhyToggleOpen:     "为什么需要「输入监控」权限？▾",
            .permWhyBody:           "• 系统机制：小米遥控器在 macOS 中被识别为蓝牙 HID 外设，系统强制要求「输入监控」才能读取语音键按下事件。\n• 硬件隔离：底层严格按 VID/PID (0x2717:0x32B8) 过滤，只监听遥控器这一个设备，完全不接触电脑键盘。\n• 开源可验：纯原生 Swift、零第三方依赖、不录音不联网，代码完全公开可审计。",
            .permViewSourceLink:    "在 GitHub 查看 HID 监听源码 →",
            .permPrivacyFootnote:   "",
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

            .permWindowTitle:       "MicRouter 權限引導",
            .permHeading:           "開啟「輸入監控」即可使用",
            .permSubtitle:          "僅用於識別小米遙控器語音鍵，不監聽鍵盤、不錄音、不連網",
            .permStep1Title:        "開啟系統設定",
            .permStep1Desc:         "點擊下方藍色按鈕，自動加入 MicRouter",
            .permStep2Title:        "開啟 MicRouter 開關",
            .permStep2Desc:         "若列表未出現，把左側圖示拖進去即可",
            .permStep3Title:        "放心點「結束並重新開啟」",
            .permStep3Desc:         "系統彈窗確認後會自動重啟並生效",
            .permDragBadge:         "可拖曳",
            .permOpenSettings:      "開啟「輸入監控」設定",
            .permRelaunch:          "手動重啟",
            .permWaitingStatus:     "等待授權中…",
            .permGrantedStatus:     "✅ 授權成功！正在連線…",
            .permWhyToggleClosed:   "為什麼需要「輸入監控」權限？▸",
            .permWhyToggleOpen:     "為什麼需要「輸入監控」權限？▾",
            .permWhyBody:           "• 系統機制：小米遙控器在 macOS 中被識別為藍牙 HID 裝置，系統強制要求「輸入監控」才能讀取語音鍵按下事件。\n• 硬體隔離：底層嚴格依 VID/PID (0x2717:0x32B8) 過濾，只監聽遙控器這一個裝置，完全不接觸電腦鍵盤。\n• 開源可驗：純原生 Swift、零第三方相依、不錄音不連網，程式碼完全公開可審計。",
            .permViewSourceLink:    "在 GitHub 檢視 HID 監聽原始碼 →",
            .permPrivacyFootnote:   "",
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

            .permWindowTitle:       "MicRouter Setup",
            .permHeading:           "Enable Input Monitoring",
            .permSubtitle:          "Only listens to the Xiaomi remote voice key. No keylogging or network.",
            .permStep1Title:        "Open System Settings",
            .permStep1Desc:         "Click the button below to auto-add MicRouter",
            .permStep2Title:        "Turn ON MicRouter",
            .permStep2Desc:         "Not listed? Drag the icon on the left into the list",
            .permStep3Title:        "Click \"Quit & Reopen\"",
            .permStep3Desc:         "Safe to confirm — the app restarts automatically",
            .permDragBadge:         "Drag me",
            .permOpenSettings:      "Open Input Monitoring",
            .permRelaunch:          "Relaunch",
            .permWaitingStatus:     "Waiting for permission…",
            .permGrantedStatus:     "✅ Granted! Connecting…",
            .permWhyToggleClosed:   "Why is Input Monitoring needed? ▸",
            .permWhyToggleOpen:     "Why is Input Monitoring needed? ▾",
            .permWhyBody:           "• macOS requirement: The Xiaomi remote registers as a Bluetooth HID device, so macOS requires Input Monitoring to read its voice button.\n• Hardware-isolated: Filtered strictly by VID/PID (0x2717:0x32B8) — it only opens the remote and never touches your keyboard.\n• Open source: Pure Swift, zero dependencies, no recording or network access.",
            .permViewSourceLink:    "Inspect RemoteHIDMonitor.swift on GitHub →",
            .permPrivacyFootnote:   "",
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

            .permWindowTitle:       "MicRouter セットアップ",
            .permHeading:           "「入力監視」をオンにする",
            .permSubtitle:          "リモコンの音声ボタンのみ監視。キー記録・録音・通信なし",
            .permStep1Title:        "システム設定を開く",
            .permStep1Desc:         "下のボタンで MicRouter を一覧に自動追加",
            .permStep2Title:        "MicRouter をオンにする",
            .permStep2Desc:         "一覧にない場合は左のアイコンをドラッグ",
            .permStep3Title:        "「終了して再度開く」を押す",
            .permStep3Desc:         "自動で再起動し、すぐ使えるようになります",
            .permDragBadge:         "ドラッグ可",
            .permOpenSettings:      "「入力監視」設定を開く",
            .permRelaunch:          "再起動",
            .permWaitingStatus:     "許可を待機中…",
            .permGrantedStatus:     "✅ 許可されました！接続中…",
            .permWhyToggleClosed:   "なぜ「入力監視」が必要ですか？ ▸",
            .permWhyToggleOpen:     "なぜ「入力監視」が必要ですか？ ▾",
            .permWhyBody:           "• macOS の仕様：Xiaomi リモコンは Bluetooth HID 機器として認識されるため、音声ボタンの検知に「入力監視」権限が必要です。\n• ハードウェア分離：VID/PID (0x2717:0x32B8) でリモコン単体のみを監視し、キーボード入力には一切触れません。\n• オープンソース：純粋な Swift 製・外部依存ゼロ・録音や通信も一切行いません。",
            .permViewSourceLink:    "GitHub で HID 監視コードを確認 →",
            .permPrivacyFootnote:   "",
        ],
    ]
}
