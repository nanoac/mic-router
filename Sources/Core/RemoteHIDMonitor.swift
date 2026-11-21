import Foundation
import IOKit.hid

public struct RemoteHIDConfig {
    public var vendorID: Int
    public var productID: Int
    public var usagePage: UInt32
    public var usage: UInt32

    public static let xiaomiRC003 = RemoteHIDConfig(
        vendorID: 0x2717,
        productID: 0x32B8,
        usagePage: 0x0007,
        usage: 0x003E // F5 (mapped to Fn/Globe by SayAll)
    )

    public init(vendorID: Int, productID: Int, usagePage: UInt32, usage: UInt32) {
        self.vendorID = vendorID
        self.productID = productID
        self.usagePage = usagePage
        self.usage = usage
    }
}

public final class RemoteHIDMonitor {
    public let config: RemoteHIDConfig
    public var onConnectionChanged: ((Bool, String?) -> Void)?
    public var onVoiceKeyChanged: ((Bool) -> Void)?
    public var onLog: ((String) -> Void)?

    private var manager: IOHIDManager?
    private var connectedDevices = Set<UnsafeMutableRawPointer>()
    private var lastDeviceName: String?

    public var isConnected: Bool { !connectedDevices.isEmpty }
    public var connectedDeviceName: String? { isConnected ? lastDeviceName : nil }
    public private(set) var isRunning = false

    public static var hasInputMonitoringPermission: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    @discardableResult
    public static func requestInputMonitoringPermission() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    public init(config: RemoteHIDConfig = .xiaomiRC003) {
        self.config = config
    }

    deinit {
        stop()
    }

    @discardableResult
    public func start() -> Bool {
        if isRunning { return true }

        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: config.vendorID,
            kIOHIDProductIDKey as String: config.productID
        ]
        IOHIDManagerSetDeviceMatching(mgr, matching as CFDictionary)

        let ctx = Unmanaged.passUnretained(self).toOpaque()

        IOHIDManagerRegisterDeviceMatchingCallback(mgr, { ctx, _, _, device in
            guard let ctx else { return }
            let monitor = Unmanaged<RemoteHIDMonitor>.fromOpaque(ctx).takeUnretainedValue()
            monitor.handleDeviceMatched(device)
        }, ctx)

        IOHIDManagerRegisterDeviceRemovalCallback(mgr, { ctx, _, _, device in
            guard let ctx else { return }
            let monitor = Unmanaged<RemoteHIDMonitor>.fromOpaque(ctx).takeUnretainedValue()
            monitor.handleDeviceRemoved(device)
        }, ctx)

        IOHIDManagerRegisterInputValueCallback(mgr, { ctx, _, _, value in
            guard let ctx else { return }
            let monitor = Unmanaged<RemoteHIDMonitor>.fromOpaque(ctx).takeUnretainedValue()
            monitor.handleInputValue(value)
        }, ctx)

        IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        let result = IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        if result != kIOReturnSuccess {
            IOHIDManagerUnscheduleFromRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            onLog?("IOHIDManagerOpen failed (code=\(result)). Input Monitoring permission may be missing.")
            return false
        }

        self.manager = mgr
        self.isRunning = true
        return true
    }

    public func stop() {
        guard let mgr = manager else { return }
        IOHIDManagerClose(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerUnscheduleFromRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        manager = nil
        isRunning = false
        connectedDevices.removeAll()
        onConnectionChanged?(false, nil)
    }

    // MARK: - HID Callbacks

    private func handleDeviceMatched(_ device: IOHIDDevice) {
        let ptr = Unmanaged.passUnretained(device).toOpaque()
        let wasConnected = !connectedDevices.isEmpty
        connectedDevices.insert(ptr)
        let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Remote"
        lastDeviceName = name
        if !wasConnected {
            onLog?("Remote connected: \(name)")
            onConnectionChanged?(true, name)
        }
    }

    private func handleDeviceRemoved(_ device: IOHIDDevice) {
        let ptr = Unmanaged.passUnretained(device).toOpaque()
        connectedDevices.remove(ptr)
        if connectedDevices.isEmpty {
            let name = lastDeviceName ?? "Remote"
            onLog?("Remote disconnected: \(name)")
            onConnectionChanged?(false, nil)
        }
    }

    private func handleInputValue(_ value: IOHIDValue) {
        let elem = IOHIDValueGetElement(value)
        let page = IOHIDElementGetUsagePage(elem)
        let usage = IOHIDElementGetUsage(elem)
        guard page == config.usagePage && usage == config.usage else { return }

        let pressed = IOHIDValueGetIntegerValue(value) != 0
        onVoiceKeyChanged?(pressed)
    }
}
