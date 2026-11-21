import Foundation

let kVersion = "1.2.4"

setvbuf(stdout, nil, _IOLBF, 0)
setvbuf(stderr, nil, _IOLBF, 0)

let dateFmt: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    return f
}()

func parseInt(_ s: String) -> Int? {
    if s.hasPrefix("0x") || s.hasPrefix("0X") {
        return Int(s.dropFirst(2), radix: 16)
    }
    return Int(s)
}

func printUsage() {
    print("""
    mic-router \(kVersion) — Automatic macOS microphone router for Xiaomi Remote 2 Pro (SayAll)

    USAGE:
      mic-router [OPTIONS]

    OPTIONS:
      --list-devices           List all CoreAudio input devices and exit
      --set-input <NAME|UID>   Set the system default input device and exit
      --remote-uid <UID|NAME>  Target virtual mic (default: auto-detect from SayAll)
      --delay <SECONDS>        Delay before restoring previous mic after release (default: 0.5)
      --max-hold <SECONDS>     Safety timeout to force-restore mic (default: 120, 0 to disable)
      --vendor-id <HEX|DEC>    Remote HID Vendor ID (default: 0x2717)
      --product-id <HEX|DEC>   Remote HID Product ID (default: 0x32B8)
      --usage-page <HEX|DEC>   Voice key HID Usage Page (default: 0x07)
      --usage <HEX|DEC>        Voice key HID Usage (default: 0x3E)
      --no-startup-recover     Do not auto-recover if default input starts on virtual mic
      -q, --quiet              Suppress non-error log output
      -v, --version            Show version
      -h, --help               Show this help
    """)
}

var remoteOverride: String?
var restoreDelay: TimeInterval = 0.5
var maxHold: TimeInterval = 120.0
var hidConfig = RemoteHIDConfig.xiaomiRC003
var startupRecover = true
var quiet = false
var listDevices = false
var setInputQuery: String?

var it = CommandLine.arguments.dropFirst().makeIterator()
while let arg = it.next() {
    switch arg {
    case "--list-devices":
        listDevices = true
    case "--set-input":
        setInputQuery = it.next()
    case "--remote-uid":
        remoteOverride = it.next()
    case "--delay":
        if let v = it.next(), let d = Double(v), d >= 0 { restoreDelay = d }
    case "--max-hold":
        if let v = it.next(), let d = Double(v), d >= 0 { maxHold = d }
    case "--vendor-id":
        if let v = it.next(), let n = parseInt(v) { hidConfig.vendorID = n }
    case "--product-id":
        if let v = it.next(), let n = parseInt(v) { hidConfig.productID = n }
    case "--usage-page":
        if let v = it.next(), let n = parseInt(v) { hidConfig.usagePage = UInt32(n) }
    case "--usage":
        if let v = it.next(), let n = parseInt(v) { hidConfig.usage = UInt32(n) }
    case "--no-startup-recover":
        startupRecover = false
    case "-q", "--quiet":
        quiet = true
    case "-v", "--version":
        print("mic-router \(kVersion)")
        exit(0)
    case "-h", "--help":
        printUsage()
        exit(0)
    default:
        FileHandle.standardError.write("Unknown option: \(arg)\n".data(using: .utf8)!)
        exit(2)
    }
}

if listDevices {
    let cur = AudioDeviceManager.defaultInputDevice()
    let sayAll = AudioDeviceManager.detectSayAllVirtualMicUID()
    for dev in AudioDeviceManager.allInputDevices() {
        let star = (dev.id == cur?.id) ? "*" : " "
        let kind = dev.isVirtual ? "virtual " : "physical"
        let tag = (dev.uid == sayAll) ? " [SayAll]" : ""
        print("\(star) [\(kind)] \(dev.name)\t(\(dev.uid))\(tag)")
    }
    exit(0)
}

if let query = setInputQuery {
    guard let dev = AudioDeviceManager.findInputDevice(matching: query) else {
        FileHandle.standardError.write("Input device not found: \(query)\n".data(using: .utf8)!)
        exit(1)
    }
    let ok = AudioDeviceManager.setDefaultInputDevice(dev.id)
    if ok {
        print("Default input -> \(dev.name) (\(dev.uid))")
        exit(0)
    } else {
        FileHandle.standardError.write("Failed to set default input: \(dev.name)\n".data(using: .utf8)!)
        exit(1)
    }
}

func log(_ msg: String) {
    if quiet && !msg.contains("ERROR") { return }
    print("[\(dateFmt.string(from: Date()))] \(msg)")
}

if !RemoteHIDMonitor.hasInputMonitoringPermission {
    log("Requesting Input Monitoring permission...")
    _ = RemoteHIDMonitor.requestInputMonitoringPermission()
}

let engine = MicRouterEngine(hidConfig: hidConfig)
engine.remoteMicOverride = remoteOverride
engine.restoreDelay = restoreDelay
engine.maxHoldDuration = maxHold
engine.onLog = { log($0) }

// Restore mic cleanly on SIGINT / SIGTERM
signal(SIGINT, SIG_IGN)
signal(SIGTERM, SIG_IGN)
let sigInt = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
let sigTerm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
let onExit = {
    engine.stop()
    log("mic-router exited")
    exit(0)
}
sigInt.setEventHandler(handler: onExit)
sigTerm.setEventHandler(handler: onExit)
sigInt.resume()
sigTerm.resume()

guard engine.start(recoverStuckVirtualMic: startupRecover) else {
    FileHandle.standardError.write(
        "ERROR: Failed to open HID monitor. Grant Input Monitoring permission in System Settings -> Privacy & Security -> Input Monitoring.\n"
            .data(using: .utf8)!
    )
    exit(1)
}

let curName = AudioDeviceManager.defaultInputDevice()?.name ?? "none"
let targetName = AudioDeviceManager.resolveRemoteMic(overrideQuery: remoteOverride)?.name ?? "auto (not found yet)"
log("mic-router \(kVersion) started | default: '\(curName)' | remote mic: '\(targetName)' | delay: \(restoreDelay)s")

CFRunLoopRun()
