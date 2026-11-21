import Foundation

public struct MicRouterState: Equatable {
    public var isEnabled: Bool
    public var hasPermission: Bool
    public var isRemoteConnected: Bool
    public var remoteDeviceName: String?
    public var isVoiceActive: Bool
    public var activeRemoteMicName: String?
    public var savedInputName: String?
}

public final class MicRouterEngine {
    public let hidMonitor: RemoteHIDMonitor

    public var isEnabled: Bool = true {
        didSet {
            if !isEnabled {
                restoreDefaultInput(reason: "Disabled")
            }
            emitState()
        }
    }

    /// `nil` means auto-detect from SayAll preferences or known virtual mics.
    public var remoteMicOverride: String? {
        didSet { emitState() }
    }

    /// Delay after releasing the remote voice button before restoring the previous mic.
    public var restoreDelay: TimeInterval = 0.5

    /// Safety timeout in case a Bluetooth key-up packet is ever lost.
    public var maxHoldDuration: TimeInterval = 120.0

    public var onLog: ((String) -> Void)?
    public var onStateChanged: ((MicRouterState) -> Void)?

    private var isVoiceActive = false
    private var savedInputUID: String?
    private var savedInputName: String?
    private var pendingRestore: DispatchWorkItem?
    private var safetyTimer: DispatchWorkItem?

    public init(hidConfig: RemoteHIDConfig = .xiaomiRC003) {
        self.hidMonitor = RemoteHIDMonitor(config: hidConfig)
        setupCallbacks()
    }

    private func setupCallbacks() {
        hidMonitor.onLog = { [weak self] msg in
            self?.log(msg)
        }
        hidMonitor.onConnectionChanged = { [weak self] connected, _ in
            guard let self else { return }
            if !connected {
                self.restoreDefaultInput(reason: "Remote disconnected")
            }
            self.emitState()
        }
        hidMonitor.onVoiceKeyChanged = { [weak self] pressed in
            guard let self else { return }
            if pressed {
                self.onVoiceButtonDown()
            } else {
                self.onVoiceButtonUp()
            }
        }
    }

    public func currentState() -> MicRouterState {
        let resolvedRemote = AudioDeviceManager.resolveRemoteMic(overrideQuery: remoteMicOverride)
        return MicRouterState(
            isEnabled: isEnabled,
            hasPermission: RemoteHIDMonitor.hasInputMonitoringPermission,
            isRemoteConnected: hidMonitor.isConnected,
            remoteDeviceName: hidMonitor.connectedDeviceName,
            isVoiceActive: isVoiceActive,
            activeRemoteMicName: resolvedRemote?.name,
            savedInputName: savedInputName
        )
    }

    /// Starts HID monitoring. Returns true if HID manager opened successfully.
    @discardableResult
    public func start(recoverStuckVirtualMic: Bool = true) -> Bool {
        if recoverStuckVirtualMic {
            self.recoverIfStuckOnRemoteMic()
        }
        let ok = hidMonitor.start()
        emitState()
        return ok
    }

    public func stop() {
        restoreDefaultInput(reason: "Stopped")
        hidMonitor.stop()
        emitState()
    }

    /// If the system default input was left on the virtual remote mic (e.g. after a crash),
    /// restore it to the best available physical microphone.
    public func recoverIfStuckOnRemoteMic() {
        guard let remoteMic = AudioDeviceManager.resolveRemoteMic(overrideQuery: remoteMicOverride),
              let current = AudioDeviceManager.defaultInputDevice(),
              current.uid == remoteMic.uid else {
            return
        }
        if let physical = AudioDeviceManager.bestPhysicalFallback(excludingUID: remoteMic.uid) {
            if AudioDeviceManager.setDefaultInputDevice(physical.id) {
                log("Startup recovery -> switched default input from '\(current.name)' to '\(physical.name)'")
            }
        }
    }

    public func onVoiceButtonDown() {
        guard isEnabled else { return }

        pendingRestore?.cancel()
        pendingRestore = nil

        if isVoiceActive { return }

        guard let remoteMic = AudioDeviceManager.resolveRemoteMic(overrideQuery: remoteMicOverride) else {
            log("ERROR: no target virtual mic found (install MiRemoteV 2ch or set --remote-uid)")
            return
        }

        let current = AudioDeviceManager.defaultInputDevice()
        if let cur = current, cur.uid != remoteMic.uid {
            savedInputUID = cur.uid
            savedInputName = cur.name
        }

        if current?.id != remoteMic.id {
            if AudioDeviceManager.setDefaultInputDevice(remoteMic.id) {
                log("Voice DOWN -> '\(remoteMic.name)' (saved: '\(current?.name ?? "none")')")
            } else {
                log("ERROR: failed to set default input to '\(remoteMic.name)'")
                return
            }
        } else {
            log("Voice DOWN -> already on '\(remoteMic.name)'")
        }

        isVoiceActive = true
        scheduleSafetyTimeout()
        emitState()
    }

    public func onVoiceButtonUp() {
        guard isVoiceActive else { return }

        pendingRestore?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.restoreDefaultInput(reason: "Voice UP")
        }
        pendingRestore = work
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay, execute: work)
    }

    public func restoreDefaultInput(reason: String) {
        pendingRestore?.cancel()
        pendingRestore = nil
        safetyTimer?.cancel()
        safetyTimer = nil

        guard isVoiceActive else { return }
        isVoiceActive = false

        let remoteUID = AudioDeviceManager.resolveRemoteMic(overrideQuery: remoteMicOverride)?.uid ?? ""
        let target: AudioInputDevice?
        if let savedUID = savedInputUID, let found = AudioDeviceManager.findInputDevice(matching: savedUID) {
            target = found
        } else {
            target = AudioDeviceManager.bestPhysicalFallback(excludingUID: remoteUID)
        }

        guard let restoreDev = target else {
            log("\(reason) -> WARNING: no physical microphone available to restore")
            emitState()
            return
        }

        if AudioDeviceManager.defaultInputDevice()?.id != restoreDev.id {
            if AudioDeviceManager.setDefaultInputDevice(restoreDev.id) {
                log("\(reason) -> restored '\(restoreDev.name)'")
            } else {
                log("\(reason) -> ERROR: failed to restore '\(restoreDev.name)'")
            }
        }
        emitState()
    }

    private func scheduleSafetyTimeout() {
        safetyTimer?.cancel()
        guard maxHoldDuration > 0 else { return }
        let timer = DispatchWorkItem { [weak self] in
            self?.restoreDefaultInput(reason: "Safety timeout (\(Int(self?.maxHoldDuration ?? 0))s)")
        }
        safetyTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + maxHoldDuration, execute: timer)
    }

    private func emitState() {
        onStateChanged?(currentState())
    }

    private func log(_ msg: String) {
        onLog?(msg)
    }
}
