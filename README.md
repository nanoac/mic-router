# MicRouter

> 让小米蓝牙语音遥控器 2 Pro（配合 [SayAll](https://github.com/HD838A/remote-mic-app)）与电脑键盘 `Fn` 语音输入自动分流麦克风的轻量级 macOS 工具。  
> Lightweight macOS utility that automatically routes the system default microphone between Xiaomi Bluetooth Remote 2 Pro (via SayAll) and your regular microphone.

## 解决什么问题？

使用 SayAll + 微信输入法 / 豆包输入法 / 系统听写等“按住 Fn 语音输入”的工具时，通常会遇到两难：

- 如果输入法麦克风设为**固定虚拟麦（如 `MiRemoteV 2ch`）**：遥控器能用，但按键盘 `Fn` 说话时外接/内置麦克风没反应。
- 如果输入法麦克风设为**自动检测（跟随系统默认输入）**：键盘 `Fn` 能用，但按遥控器语音键时输入法只听系统默认麦，听不到遥控器声音。

**MicRouter 的做法**：在 macOS 硬件 HID 层直接监听遥控器语音键（与键盘 `Fn` 完全隔离）：
- **按住遥控器语音键**：瞬间将系统默认输入切到遥控器虚拟麦（自动读取 SayAll 配置，如 `MiRemoteV 2ch` / `BlackHole 2ch`），同时记住切换前的默认麦克风。
- **松开遥控器语音键**：延迟 `0.5s`（可调，确保尾音不截断）后自动切回原来的麦克风（无论你是 USB 麦克风、Mac 内置麦还是 AirPods）。
- **按住键盘 `Fn`**：完全不干预，直接使用你当前的系统默认麦克风。

## 特性

- **双形态，共享同一套核心引擎（零第三方依赖、纯原生 Swift）**：
  - **菜单栏 App（`MicRouter.app`）**：适合日常使用。支持状态显示、暂停/恢复、目标虚拟麦切换、延迟调节、开机自启（`SMAppService`），以及**隐藏菜单栏图标**（寸土寸金的菜单栏也能干干净净；需要再次显示时，重新打开 `MicRouter` 即可）。
  - **极客 CLI 模式（`mic-router`）**：无界面、可自定义 VID/PID/Usage、延迟、超时保护，支持通过 `LaunchAgent` 后台常驻运行。
- **多语言支持**：内置 **简体中文 / 繁體中文 / English / 日本語**，默认自动跟随系统语言，也支持在菜单栏内随时切换、即时生效。
- **安全防卡死**：
  - 启动时若发现上次异常退出导致系统卡在虚拟麦，自动恢复到可用物理麦克风。
  - 蓝牙断连、系统休眠、单次按住超时（默认 120s）均自动恢复原麦克风。
- **开箱即用的权限引导**：未授权时自动弹出原生引导窗口，支持一键跳转系统设置、**直接把窗口里的 App 图标拖进「输入监控」列表**，授权后自动检测并关闭窗口。
- **低权限要求**：仅需 macOS「输入监控（Input Monitoring）」权限，无需辅助功能权限，不监听键盘、不录音、不联网。

## 快速开始

需要 macOS 13+ 与 Xcode Command Line Tools（`xcode-select --install`）。

### 1. 菜单栏 App 模式（推荐）

#### 方式 A：通过 Homebrew 一键安装（推荐）

```bash
brew install --cask nanoac/tap/mic-router
open /Applications/MicRouter.app
```

> 提示：当前免费开源版使用本地 ad-hoc 签名（未公证），如首次打开被 Gatekeeper 拦截，可在「系统设置 → 隐私与安全性」点击“仍要打开”，或在安装时加上 `--no-quarantine`。

#### 方式 B：从源码构建安装

```bash
make install-app
open /Applications/MicRouter.app
```

首次启动时会自动弹出三步权限引导窗口，点击 **「打开『输入监控』设置」** 开启 `MicRouter` 开关并按提示「退出并重新打开」即可生效。

- **隐藏菜单栏图标**：点击菜单栏图标 →「隐藏菜单栏图标…」。隐藏后程序继续在后台静默运行。
- **重新显示图标**：在 Spotlight / Raycast 或 `/Applications` 中再次打开 `MicRouter` 即可恢复图标并弹出菜单。

### 为什么需要「输入监控（Input Monitoring）」权限？

这是 macOS 系统的隐私机制要求，很多用户看到“输入监控”会担心键盘隐私，这里透明说明边界：

1. **为什么必须申请**：小米蓝牙语音遥控器 2 Pro 在 macOS 中被系统识别为 **蓝牙 HID 键盘类外设**（语音键发送 HID `F5` / `usage 0x3E`）。macOS 强制要求后台进程持有「输入监控」权限才能通过 `IOHIDManager` 读取该按键事件，从而在微信输入法开麦前（毫秒级）切好系统默认麦克风。
2. **绝不监听你的电脑键盘**：在 [`Sources/Core/RemoteHIDMonitor.swift`](Sources/Core/RemoteHIDMonitor.swift) 中，设备匹配严格限定为 `VendorID = 0x2717`、`ProductID = 0x32B8`（仅小米遥控器），只处理语音键的按下/松开状态，完全不打开也不读取电脑键盘。
3. **100% 开源可审计**：纯原生 Swift 编写，零第三方依赖、不录音、不联网、不收集任何数据。

### 2. 极客 CLI 模式

```bash
make cli

# 查看所有音频输入设备与自动检测到的 SayAll 虚拟麦
./build/mic-router --list-devices

# 前台运行（默认自动适配 SayAll 虚拟麦与 0.5s 恢复延迟）
./build/mic-router

# 自定义参数运行
./build/mic-router --remote-uid MiRemoteV2ch_UID --delay 0.4 --max-hold 90

# 一键安装为后台 LaunchAgent（开机自启）
make install-cli

# 卸载 LaunchAgent
make uninstall-cli
```

查看全部命令行选项：

```bash
./build/mic-router --help
```

## 项目结构

```text
Sources/
├── Core/
│   ├── AudioDeviceManager.swift   # CoreAudio 设备枚举、SayAll 配置读取、物理麦智能回退
│   ├── RemoteHIDMonitor.swift     # IOHIDManager 硬件按键监听与热插拔
│   └── MicRouterEngine.swift      # 切换状态机与防卡死保护
├── App/
│   ├── Localization.swift         # 多语言支持（简体中文 / 繁體中文 / English / 日本語）
│   └── main.swift                 # 轻量原生菜单栏 App（支持隐藏图标与 SMAppService 自启）
└── CLI/
    └── main.swift                 # 极客命令行版本
scripts/
├── build-app.sh                   # 构建并签名 MicRouter.app
└── install-launchagent.sh         # 安装/卸载 CLI LaunchAgent
```

## License

[MIT](LICENSE)
