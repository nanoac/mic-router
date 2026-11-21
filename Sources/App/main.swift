import Cocoa
import Foundation
import ServiceManagement

// MARK: - Localization Helper

let isChinese: Bool = {
    Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") ?? false
}()

func L(_ zh: String, _ en: String) -> String {
    isChinese ? zh : en
}

// MARK: - File Logger

final class FileLogger {
    static let shared = FileLogger()
    let logURL: URL
    private let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    private init() {
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        self.logURL = logsDir.appendingPathComponent("MicRouter.log")
    }

    func log(_ message: String) {
        let line = "[\(dateFmt.string(from: Date()))] \(message)\n"
        print(line, terminator: "")
        guard let data = line.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: logURL.path) {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: logURL.path),
               let size = attrs[.size] as? UInt64, size > 512 * 1024 {
                try? data.write(to: logURL, options: .atomic)
                return
            }
            if let fh = try? FileHandle(forWritingTo: logURL) {
                defer { try? fh.close() }
                _ = try? fh.seekToEnd()
                try? fh.write(contentsOf: data)
            }
        } else {
            try? data.write(to: logURL, options: .atomic)
        }
    }
}

// MARK: - Preferences

final class AppSettings {
    private let defaults = UserDefaults.standard

    private enum Key {
        static let enabled = "isEnabled"
        static let remoteMicOverride = "remoteMicOverride"
        static let restoreDelay = "restoreDelay"
        static let hideMenuBarIcon = "hideMenuBarIcon"
        static let didShowHideAlert = "didShowHideAlert"
    }

    var isEnabled: Bool {
        get { defaults.object(forKey: Key.enabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    var remoteMicOverride: String? {
        get { defaults.string(forKey: Key.remoteMicOverride) }
        set {
            if let v = newValue, !v.isEmpty {
                defaults.set(v, forKey: Key.remoteMicOverride)
            } else {
                defaults.removeObject(forKey: Key.remoteMicOverride)
            }
        }
    }

    var restoreDelay: TimeInterval {
        get {
            let v = defaults.double(forKey: Key.restoreDelay)
            return v > 0 ? v : 0.5
        }
        set { defaults.set(newValue, forKey: Key.restoreDelay) }
    }

    var hideMenuBarIcon: Bool {
        get { defaults.bool(forKey: Key.hideMenuBarIcon) }
        set { defaults.set(newValue, forKey: Key.hideMenuBarIcon) }
    }

    var didShowHideAlert: Bool {
        get { defaults.bool(forKey: Key.didShowHideAlert) }
        set { defaults.set(newValue, forKey: Key.didShowHideAlert) }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = AppSettings()
    private let engine = MicRouterEngine(hidConfig: .xiaomiRC003)

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var permissionPollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Handle CLI flags on the app binary if any
        let args = CommandLine.arguments
        if args.contains("--hide-menu-bar") {
            settings.hideMenuBarIcon = true
        } else if args.contains("--show-menu-bar") {
            settings.hideMenuBarIcon = false
        }

        setupStatusItem()
        setupEngine()
        setupSleepObserver()

        FileLogger.shared.log("MicRouter.app started (hideMenuBarIcon=\(settings.hideMenuBarIcon))")
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionPollTimer?.invalidate()
        engine.stop()
        FileLogger.shared.log("MicRouter.app terminated")
    }

    /// Re-opening MicRouter from Spotlight / Finder / Applications restores the hidden menu bar icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if settings.hideMenuBarIcon || !statusItem.isVisible {
            settings.hideMenuBarIcon = false
            statusItem.isVisible = true
            FileLogger.shared.log("Menu bar icon restored via app reopen")
        }
        statusItem.button?.performClick(nil)
        return true
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu.delegate = self
        statusItem.menu = menu
        statusItem.isVisible = !settings.hideMenuBarIcon
        updateStatusIcon(engine.currentState())
    }

    private func setupEngine() {
        engine.isEnabled = settings.isEnabled
        engine.remoteMicOverride = settings.remoteMicOverride
        engine.restoreDelay = settings.restoreDelay

        engine.onLog = { msg in
            FileLogger.shared.log(msg)
        }
        engine.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.updateStatusIcon(state)
            }
        }

        if !RemoteHIDMonitor.hasInputMonitoringPermission {
            _ = RemoteHIDMonitor.requestInputMonitoringPermission()
        }

        let started = engine.start(recoverStuckVirtualMic: true)
        if !started {
            startPermissionPolling()
        }
    }

    private func setupSleepObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.engine.restoreDefaultInput(reason: "System sleep")
        }
    }

    private func startPermissionPolling() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            if RemoteHIDMonitor.hasInputMonitoringPermission {
                if self.engine.start(recoverStuckVirtualMic: false) {
                    FileLogger.shared.log("Input Monitoring granted -> HID monitor started")
                    timer.invalidate()
                    self.permissionPollTimer = nil
                }
            }
        }
    }

    // MARK: - Icon Rendering

    private func updateStatusIcon(_ state: MicRouterState) {
        guard let button = statusItem?.button else { return }

        let symbolName: String
        let tooltip: String
        if !state.hasPermission {
            symbolName = "exclamationmark.triangle"
            tooltip = L("MicRouter：需要「输入监控」权限", "MicRouter: Input Monitoring permission required")
        } else if !state.isEnabled {
            symbolName = "mic.slash.circle"
            tooltip = L("MicRouter：已暂停", "MicRouter: Paused")
        } else if state.isVoiceActive {
            symbolName = "mic.circle.fill"
            tooltip = L("MicRouter：正在使用遥控器麦克风", "MicRouter: Remote mic active")
        } else {
            symbolName = "mic.circle"
            tooltip = L("MicRouter：运行中", "MicRouter: Active")
        }

        if let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: "MicRouter") {
            img.isTemplate = true
            button.image = img
        } else {
            button.title = state.isVoiceActive ? "●" : "🎙"
        }
        button.toolTip = tooltip
    }

    // MARK: - Dynamic Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let state = engine.currentState()
        let currentDefault = AudioDeviceManager.defaultInputDevice()?.name ?? L("无", "None")
        let resolvedRemote = AudioDeviceManager.resolveRemoteMic(overrideQuery: settings.remoteMicOverride)

        // 1. Permission warning if needed
        if !state.hasPermission {
            let warnItem = NSMenuItem(
                title: L("⚠️ 需要「输入监控」权限（点击前往设置）", "⚠️ Input Monitoring Required (Open Settings)"),
                action: #selector(openInputMonitoringSettings),
                keyEquivalent: ""
            )
            warnItem.target = self
            menu.addItem(warnItem)
            menu.addItem(.separator())
        }

        // 2. Status summary (non-clickable info items)
        let remoteText: String
        if state.isRemoteConnected {
            let name = state.remoteDeviceName ?? "RC003"
            remoteText = L("遥控器：已连接（\(name)）", "Remote: Connected (\(name))")
        } else {
            remoteText = L("遥控器：未连接（等待小米遥控器）", "Remote: Disconnected")
        }
        let remoteItem = NSMenuItem(title: remoteText, action: nil, keyEquivalent: "")
        remoteItem.isEnabled = false
        menu.addItem(remoteItem)

        let defaultItem = NSMenuItem(
            title: L("当前默认麦：\(currentDefault)", "Default Mic: \(currentDefault)"),
            action: nil,
            keyEquivalent: ""
        )
        defaultItem.isEnabled = false
        menu.addItem(defaultItem)

        menu.addItem(.separator())

        // 3. Enable / Disable toggle
        let toggleItem = NSMenuItem(
            title: L("启用自动切换", "Enable Auto Switching"),
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.state = settings.isEnabled ? .on : .off
        menu.addItem(toggleItem)

        // 4. Target Virtual Mic submenu
        let targetMenu = NSMenu()
        let autoName = AudioDeviceManager.resolveRemoteMic(overrideQuery: nil)?.name ?? L("未检测到", "Not Found")
        let autoItem = NSMenuItem(
            title: L("自动检测（跟随 SayAll：\(autoName)）", "Auto (Follow SayAll: \(autoName))"),
            action: #selector(selectRemoteMic(_:)),
            keyEquivalent: ""
        )
        autoItem.target = self
        autoItem.representedObject = ""
        autoItem.state = (settings.remoteMicOverride == nil) ? .on : .off
        targetMenu.addItem(autoItem)
        targetMenu.addItem(.separator())

        for dev in AudioDeviceManager.allInputDevices() {
            let tag = dev.isVirtual ? L(" [虚拟]", " [Virtual]") : ""
            let item = NSMenuItem(
                title: "\(dev.name)\(tag)",
                action: #selector(selectRemoteMic(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = dev.uid
            item.state = (settings.remoteMicOverride == dev.uid) ? .on : .off
            targetMenu.addItem(item)
        }

        let targetParent = NSMenuItem(
            title: L("遥控器虚拟麦：\(resolvedRemote?.name ?? "未找到")", "Remote Mic: \(resolvedRemote?.name ?? "None")"),
            action: nil,
            keyEquivalent: ""
        )
        targetParent.submenu = targetMenu
        menu.addItem(targetParent)

        // 5. Restore Delay submenu
        let delayMenu = NSMenu()
        let delays: [TimeInterval] = [0.2, 0.3, 0.5, 0.8, 1.0]
        for d in delays {
            let suffix = (d == 0.5) ? L("（推荐）", " (Recommended)") : ""
            let item = NSMenuItem(
                title: String(format: "%.1fs%@", d, suffix),
                action: #selector(selectRestoreDelay(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = d
            item.state = abs(settings.restoreDelay - d) < 0.01 ? .on : .off
            delayMenu.addItem(item)
        }
        let delayParent = NSMenuItem(
            title: String(format: L("松开恢复延迟：%.1fs", "Restore Delay: %.1fs"), settings.restoreDelay),
            action: nil,
            keyEquivalent: ""
        )
        delayParent.submenu = delayMenu
        menu.addItem(delayParent)

        menu.addItem(.separator())

        // 6. Launch at Login (macOS 13+ SMAppService)
        if #available(macOS 13.0, *) {
            let loginItem = NSMenuItem(
                title: L("开机自动启动", "Launch at Login"),
                action: #selector(toggleLaunchAtLogin),
                keyEquivalent: ""
            )
            loginItem.target = self
            loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
            menu.addItem(loginItem)
        }

        // 7. Hide Menu Bar Icon
        let hideItem = NSMenuItem(
            title: L("隐藏菜单栏图标…", "Hide Menu Bar Icon…"),
            action: #selector(hideMenuBarIcon),
            keyEquivalent: ""
        )
        hideItem.target = self
        menu.addItem(hideItem)

        // 8. Open Log
        let logItem = NSMenuItem(
            title: L("查看运行日志", "View Log"),
            action: #selector(openLogFile),
            keyEquivalent: ""
        )
        logItem.target = self
        menu.addItem(logItem)

        menu.addItem(.separator())

        // 9. Quit
        let quitItem = NSMenuItem(
            title: L("退出 MicRouter", "Quit MicRouter"),
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
        engine.isEnabled = settings.isEnabled
        FileLogger.shared.log("Auto switching \(settings.isEnabled ? "enabled" : "paused")")
    }

    @objc private func selectRemoteMic(_ sender: NSMenuItem) {
        let uid = sender.representedObject as? String ?? ""
        settings.remoteMicOverride = uid.isEmpty ? nil : uid
        engine.remoteMicOverride = settings.remoteMicOverride
        FileLogger.shared.log("Remote mic selection -> \(uid.isEmpty ? "auto" : uid)")
    }

    @objc private func selectRestoreDelay(_ sender: NSMenuItem) {
        guard let d = sender.representedObject as? TimeInterval else { return }
        settings.restoreDelay = d
        engine.restoreDelay = d
        FileLogger.shared.log("Restore delay -> \(d)s")
    }

    @available(macOS 13.0, *)
    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
                FileLogger.shared.log("Launch at login disabled")
            } else {
                try service.register()
                FileLogger.shared.log("Launch at login enabled")
            }
        } catch {
            FileLogger.shared.log("ERROR: Launch at login failed: \(error.localizedDescription)")
            let alert = NSAlert()
            alert.messageText = L("无法修改开机自启设置", "Failed to update Launch at Login")
            alert.informativeText = error.localizedDescription + "\n\n" +
                L("请确保 MicRouter.app 已放入 /Applications 目录。", "Make sure MicRouter.app is located in /Applications.")
            alert.runModal()
        }
    }

    @objc private func hideMenuBarIcon() {
        if !settings.didShowHideAlert {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = L("隐藏菜单栏图标？", "Hide Menu Bar Icon?")
            alert.informativeText = L(
                "隐藏后 MicRouter 会继续在后台静默运行。\n\n需要重新显示菜单栏图标时，只需在 Spotlight / Raycast 或「应用程序」中再次打开 MicRouter 即可。",
                "MicRouter will continue running silently in the background.\n\nTo show the menu bar icon again, simply reopen MicRouter from Spotlight or Applications."
            )
            alert.addButton(withTitle: L("隐藏图标", "Hide Icon"))
            alert.addButton(withTitle: L("取消", "Cancel"))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            settings.didShowHideAlert = true
        }

        settings.hideMenuBarIcon = true
        statusItem.isVisible = false
        FileLogger.shared.log("Menu bar icon hidden (running in background)")
    }

    @objc private func openInputMonitoringSettings() {
        _ = RemoteHIDMonitor.requestInputMonitoringPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
        startPermissionPolling()
    }

    @objc private func openLogFile() {
        let url = FileLogger.shared.logURL
        if !FileManager.default.fileExists(atPath: url.path) {
            FileLogger.shared.log("Log file created")
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - Main Entry

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
