import Cocoa
import Foundation
import ServiceManagement

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
        static let appLanguage = "appLanguage"
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

    var appLanguage: AppLanguage {
        get {
            guard let raw = defaults.string(forKey: Key.appLanguage),
                  let lang = AppLanguage(rawValue: raw) else {
                return .system
            }
            return lang
        }
        set { defaults.set(newValue.rawValue, forKey: Key.appLanguage) }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = AppSettings()
    private let engine = MicRouterEngine(hidConfig: .xiaomiRC003)

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var permissionPollTimer: Timer?
    private var permissionWindow: PermissionWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        L10n.current = settings.appLanguage

        let args = CommandLine.arguments
        if args.contains("--hide-menu-bar") {
            settings.hideMenuBarIcon = true
        } else if args.contains("--show-menu-bar") {
            settings.hideMenuBarIcon = false
        }

        setupStatusItem()
        setupEngine()
        setupSleepObserver()

        FileLogger.shared.log(
            "MicRouter.app started (lang=\(settings.appLanguage.rawValue), hideMenuBarIcon=\(settings.hideMenuBarIcon))"
        )
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.showPermissionGuide()
            }
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
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            if RemoteHIDMonitor.hasInputMonitoringPermission {
                if self.engine.start(recoverStuckVirtualMic: false) {
                    FileLogger.shared.log("Input Monitoring granted -> HID monitor started")
                    self.permissionWindow?.markGrantedAndCloseSoon()
                    timer.invalidate()
                    self.permissionPollTimer = nil
                }
            }
        }
    }

    private func showPermissionGuide() {
        if permissionWindow == nil {
            let vc = PermissionWindowController()
            vc.onOpenSettings = { [weak self] in
                self?.openInputMonitoringSettings()
            }
            vc.onRelaunch = { [weak self] in
                self?.relaunchApp()
            }
            permissionWindow = vc
        }
        permissionWindow?.show()
    }

    private func relaunchApp() {
        let appPath = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", appPath]
        try? task.run()
        NSApp.terminate(nil)
    }

    // MARK: - Icon Rendering

    private func updateStatusIcon(_ state: MicRouterState) {
        guard let button = statusItem?.button else { return }

        let symbolName: String
        let tooltip: String
        if !state.hasPermission {
            symbolName = "exclamationmark.triangle"
            tooltip = L10n.t(.tooltipNeedPermission)
        } else if !state.isEnabled {
            symbolName = "mic.slash.circle"
            tooltip = L10n.t(.tooltipPaused)
        } else if state.isVoiceActive {
            symbolName = "mic.circle.fill"
            tooltip = L10n.t(.tooltipVoiceActive)
        } else {
            symbolName = "mic.circle"
            tooltip = L10n.t(.tooltipActive)
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
        let currentDefault = AudioDeviceManager.defaultInputDevice()?.name ?? L10n.t(.none)
        let resolvedRemote = AudioDeviceManager.resolveRemoteMic(overrideQuery: settings.remoteMicOverride)

        // 1. Permission warning if needed
        if !state.hasPermission {
            let warnItem = NSMenuItem(
                title: L10n.t(.warnNeedPermission),
                action: #selector(openPermissionGuideClicked),
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
            remoteText = L10n.fmt(.remoteConnectedFmt, name)
        } else {
            remoteText = L10n.t(.remoteDisconnected)
        }
        let remoteItem = NSMenuItem(title: remoteText, action: nil, keyEquivalent: "")
        remoteItem.isEnabled = false
        menu.addItem(remoteItem)

        let defaultItem = NSMenuItem(
            title: L10n.fmt(.defaultMicFmt, currentDefault),
            action: nil,
            keyEquivalent: ""
        )
        defaultItem.isEnabled = false
        menu.addItem(defaultItem)

        menu.addItem(.separator())

        // 3. Enable / Disable toggle
        let toggleItem = NSMenuItem(
            title: L10n.t(.enableAutoSwitch),
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.state = settings.isEnabled ? .on : .off
        menu.addItem(toggleItem)

        // 4. Target Virtual Mic submenu
        let targetMenu = NSMenu()
        let autoName = AudioDeviceManager.resolveRemoteMic(overrideQuery: nil)?.name ?? L10n.t(.remoteMicNotFound)
        let autoItem = NSMenuItem(
            title: L10n.fmt(.remoteMicAutoFmt, autoName),
            action: #selector(selectRemoteMic(_:)),
            keyEquivalent: ""
        )
        autoItem.target = self
        autoItem.representedObject = ""
        autoItem.state = (settings.remoteMicOverride == nil) ? .on : .off
        targetMenu.addItem(autoItem)
        targetMenu.addItem(.separator())

        for dev in AudioDeviceManager.allInputDevices() {
            let tag = dev.isVirtual ? L10n.t(.virtualTag) : ""
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
            title: L10n.fmt(.remoteMicMenuFmt, resolvedRemote?.name ?? L10n.t(.remoteMicNotFound)),
            action: nil,
            keyEquivalent: ""
        )
        targetParent.submenu = targetMenu
        menu.addItem(targetParent)

        // 5. Restore Delay submenu
        let delayMenu = NSMenu()
        let delays: [TimeInterval] = [0.2, 0.3, 0.5, 0.8, 1.0]
        for d in delays {
            let suffix = (d == 0.5) ? L10n.t(.recommendedSuffix) : ""
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
            title: L10n.fmt(.restoreDelayMenuFmt, settings.restoreDelay),
            action: nil,
            keyEquivalent: ""
        )
        delayParent.submenu = delayMenu
        menu.addItem(delayParent)

        // 6. Language submenu
        let langMenu = NSMenu()
        for lang in AppLanguage.allCases {
            let item = NSMenuItem(
                title: lang.nativeLabel,
                action: #selector(selectLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = lang.rawValue
            item.state = (settings.appLanguage == lang) ? .on : .off
            langMenu.addItem(item)
            if lang == .system {
                langMenu.addItem(.separator())
            }
        }
        let langParent = NSMenuItem(
            title: L10n.t(.languageMenu),
            action: nil,
            keyEquivalent: ""
        )
        langParent.submenu = langMenu
        menu.addItem(langParent)

        menu.addItem(.separator())

        // 7. Launch at Login (macOS 13+ SMAppService)
        if #available(macOS 13.0, *) {
            let loginItem = NSMenuItem(
                title: L10n.t(.launchAtLogin),
                action: #selector(toggleLaunchAtLogin),
                keyEquivalent: ""
            )
            loginItem.target = self
            loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
            menu.addItem(loginItem)
        }

        // 8. Hide Menu Bar Icon
        let hideItem = NSMenuItem(
            title: L10n.t(.hideMenuBarIcon),
            action: #selector(hideMenuBarIcon),
            keyEquivalent: ""
        )
        hideItem.target = self
        menu.addItem(hideItem)

        // 9. Open Log
        let logItem = NSMenuItem(
            title: L10n.t(.viewLog),
            action: #selector(openLogFile),
            keyEquivalent: ""
        )
        logItem.target = self
        menu.addItem(logItem)

        menu.addItem(.separator())

        // 10. Quit
        let quitItem = NSMenuItem(
            title: L10n.t(.quitApp),
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

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let lang = AppLanguage(rawValue: raw) else { return }
        settings.appLanguage = lang
        L10n.current = lang
        updateStatusIcon(engine.currentState())
        permissionWindow?.refreshTexts()
        FileLogger.shared.log("Language -> \(lang.rawValue)")
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
            alert.messageText = L10n.t(.loginErrorTitle)
            alert.informativeText = error.localizedDescription + "\n\n" + L10n.t(.loginErrorHint)
            alert.runModal()
        }
    }

    @objc private func hideMenuBarIcon() {
        if !settings.didShowHideAlert {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = L10n.t(.hideAlertTitle)
            alert.informativeText = L10n.t(.hideAlertBody)
            alert.addButton(withTitle: L10n.t(.hideAlertConfirm))
            alert.addButton(withTitle: L10n.t(.cancel))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            settings.didShowHideAlert = true
        }

        settings.hideMenuBarIcon = true
        statusItem.isVisible = false
        FileLogger.shared.log("Menu bar icon hidden (running in background)")
    }

    @objc private func openPermissionGuideClicked() {
        showPermissionGuide()
    }

    @objc private func openInputMonitoringSettings() {
        // Clear any stale ad-hoc TCC entry from an older version before re-registering.
        if !RemoteHIDMonitor.hasInputMonitoringPermission,
           let bundleID = Bundle.main.bundleIdentifier {
            let reset = Process()
            reset.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            reset.arguments = ["reset", "ListenEvent", bundleID]
            try? reset.run()
            reset.waitUntilExit()
            FileLogger.shared.log("Reset stale ListenEvent TCC entry for \(bundleID)")
        }

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
