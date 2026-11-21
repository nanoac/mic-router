import CoreAudio
import Foundation

public struct AudioInputDevice: Equatable, Hashable {
    public let id: AudioDeviceID
    public let uid: String
    public let name: String
    public let transportType: UInt32

    public var isVirtual: Bool {
        if transportType == kAudioDeviceTransportTypeVirtual ||
           transportType == kAudioDeviceTransportTypeAggregate {
            return true
        }
        let lower = (name + " " + uid).lowercased()
        let virtualKeywords = [
            "miremotev", "blackhole", "orayvirtual", "loopback",
            "vb-cable", "soundflower", "background music", "ark"
        ]
        return virtualKeywords.contains { lower.contains($0) }
    }
}

public final class AudioDeviceManager {
    private static let systemObject = AudioObjectID(kAudioObjectSystemObject)

    /// Returns all currently available CoreAudio input devices.
    public static func allInputDevices() -> [AudioInputDevice] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObject, &addr, 0, nil, &size) == noErr, size > 0 else {
            return []
        }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(systemObject, &addr, 0, nil, &size, &ids) == noErr else {
            return []
        }

        return ids.compactMap { id -> AudioInputDevice? in
            guard hasInputStreams(id) else { return nil }
            let uid = getStringProperty(id, kAudioDevicePropertyDeviceUID)
            let name = getStringProperty(id, kAudioObjectPropertyName)
            guard !uid.isEmpty else { return nil }
            let transport = getUInt32Property(id, kAudioDevicePropertyTransportType)
            return AudioInputDevice(id: id, uid: uid, name: name, transportType: transport)
        }
    }

    public static func defaultInputDevice() -> AudioInputDevice? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var devID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(systemObject, &addr, 0, nil, &size, &devID) == noErr,
              devID != AudioDeviceID(kAudioObjectUnknown) else {
            return nil
        }
        let uid = getStringProperty(devID, kAudioDevicePropertyDeviceUID)
        let name = getStringProperty(devID, kAudioObjectPropertyName)
        let transport = getUInt32Property(devID, kAudioDevicePropertyTransportType)
        return AudioInputDevice(id: devID, uid: uid, name: name, transportType: transport)
    }

    @discardableResult
    public static func setDefaultInputDevice(_ deviceID: AudioDeviceID) -> Bool {
        var dev = deviceID
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(
            systemObject, &addr, 0, nil,
            UInt32(MemoryLayout<AudioDeviceID>.size), &dev
        )
        return status == noErr
    }

    public static func findInputDevice(matching query: String) -> AudioInputDevice? {
        let inputs = allInputDevices()
        if let exact = inputs.first(where: { $0.uid == query || $0.name == query }) {
            return exact
        }
        return inputs.first(where: { $0.name.localizedCaseInsensitiveContains(query) })
    }

    /// Reads SayAll's `selectedAudioDeviceUID` preference if present.
    public static func detectSayAllVirtualMicUID() -> String? {
        let plistPath = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/Preferences/com.hd838a.RemoteMic.plist")
        guard let data = FileManager.default.contents(atPath: plistPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let uid = plist["selectedAudioDeviceUID"] as? String,
              !uid.isEmpty else {
            return nil
        }
        return uid
    }

    /// Resolves the target remote virtual mic:
    /// 1. Explicit override UID/name if provided
    /// 2. SayAll's `selectedAudioDeviceUID`
    /// 3. Built-in fallback search (`MiRemoteV2ch_UID`, `MiRemoteV`, `BlackHole`)
    public static func resolveRemoteMic(overrideQuery: String? = nil) -> AudioInputDevice? {
        if let q = overrideQuery, !q.isEmpty, let dev = findInputDevice(matching: q) {
            return dev
        }
        if let sayAllUID = detectSayAllVirtualMicUID(), let dev = findInputDevice(matching: sayAllUID) {
            return dev
        }
        for candidate in ["MiRemoteV2ch_UID", "MiRemoteV", "BlackHole"] {
            if let dev = findInputDevice(matching: candidate) {
                return dev
            }
        }
        return nil
    }

    /// Picks the best available physical (non-virtual) microphone as a fallback.
    public static func bestPhysicalFallback(excludingUID: String) -> AudioInputDevice? {
        let candidates = allInputDevices().filter { $0.uid != excludingUID && !$0.isVirtual }
        if candidates.isEmpty {
            return allInputDevices().first { $0.uid != excludingUID }
        }
        // Prefer USB / Bluetooth / Built-in in a sensible order
        let priority: [UInt32] = [
            kAudioDeviceTransportTypeUSB,
            kAudioDeviceTransportTypeBuiltIn,
            kAudioDeviceTransportTypeBluetooth,
            kAudioDeviceTransportTypeBluetoothLE
        ]
        for transport in priority {
            if let match = candidates.first(where: { $0.transportType == transport }) {
                return match
            }
        }
        return candidates.first
    }

    // MARK: - Private CoreAudio Property Helpers

    private static func hasInputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(deviceID, &addr, 0, nil, &size) == noErr && size > 0
    }

    private static func getStringProperty(_ deviceID: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String {
        var addr = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &value) == noErr,
              let cfStr = value?.takeUnretainedValue() else {
            return ""
        }
        return cfStr as String
    }

    private static func getUInt32Property(_ deviceID: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> UInt32 {
        var addr = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &value) == noErr else {
            return 0
        }
        return value
    }
}
