# BlueNap (蓝憩)

<p align="center">
  <img src="images/icon.png" width="108" height="108" alt="BlueNap 蓝憩 App Icon" /><br />
  <b>Sleeping Mac, Silent Bluetooth & Intelligent Auto-WiFi.</b><br />
  <i>意境优雅的 Mac 蓝牙与 Wi-Fi 深度休眠管理 · 原生 AutoWiFi 静态 IP 智能自动绑定 · 让设备管理恬静自如</i>
</p>

<p align="center">
  <a href="https://app.needai.top/app/bluenap"><img src="https://img.shields.io/badge/Website-app.needai.top-blueviolet?style=flat-square" alt="Official Website" /></a>
  <a href="https://app.needai.top/app/tactile"><img src="https://img.shields.io/badge/More%20Apps-Tactile%20(妙触)-ff69b4?style=flat-square" alt="Tactile (妙触)" /></a>
  <img src="https://img.shields.io/badge/macOS-14.0%2B-blue.svg?style=flat-square" alt="macOS 14.0+" />
  <img src="https://img.shields.io/badge/Swift-6.0-orange.svg?style=flat-square" alt="Swift 6.0" />
  <img src="https://img.shields.io/badge/Concurrency-Complete%20Strict-brightgreen.svg?style=flat-square" alt="Strict Concurrency Complete" />
  <img src="https://img.shields.io/badge/Dependencies-0%20(Pure%20Native)-purple.svg?style=flat-square" alt="Zero Dependencies" />
  <img src="https://img.shields.io/badge/Notarized-Apple%20Verified-success.svg?style=flat-square" alt="Apple Notarized" />
  <a href="https://github.com/jorchford/BlueNap"><img src="https://img.shields.io/badge/GitHub-jorchford%2FBlueNap-181717.svg?style=flat-square&logo=github" alt="GitHub Repository" /></a>
  <a href="https://gitee.com/jorchford/BlueNap"><img src="https://img.shields.io/badge/Gitee-jorchford%2FBlueNap-C71D23.svg?style=flat-square&logo=gitee" alt="Gitee Mirror" /></a>
</p>

<p align="center">
  <b>⚡ Fast Downloads / 高速下载通道:</b><br />
  <a href="https://app.needai.top/downloads/BlueNap.app.zip">🌐 官网直链 (app.needai.top)</a> &nbsp;|&nbsp;
  <a href="https://gitee.com/jorchford/BlueNap/raw/main/downloads/BlueNap.app.zip">⚡ Gitee 国内极速直链</a> &nbsp;|&nbsp;
  <a href="https://github.com/jorchford/BlueNap/releases">📦 GitHub Releases</a>
</p>

---

## 📸 Screenshots & Interface Showcase / 界面截图展示

<div align="center">

### 1. 通用设置与后台运行 (General Preferences & Silent Background Mode)
*登录时自动启动、完全退出应用、以及菜单栏定时自动隐藏（进入静默后台）选项*

<img src="images/bluenap_general_settings.png" width="620" alt="BlueNap General Settings" />

<br /><br />

### 2. AutoWiFi 静态 IP 智能绑定与系统守护服务 (AutoWiFi Subsystem)
*自动感知已连接 SSID，毫秒级切换静态 IPv4 与 DNS，纯原生 Swift LaunchDaemon 守护*

<img src="images/bluenap_autowifi_preferences.png" width="620" alt="BlueNap AutoWiFi Settings" />

<br /><br />

### 3. 蓝牙休眠管理与外设防抢连 (Bluetooth Sleep Management)
*Mac 合盖或休眠时，自动断开指定的 AirPods 或无线音频外设，防止声音截断与电池偷跑*

<img src="images/blue.png" width="620" alt="BlueNap Bluetooth Settings" />

<br /><br />

### 4. Wi-Fi 节能控制与睡眠电源管理 (Wi-Fi Power Management)
*休眠时关闭 Wi-Fi 电源阻断维护唤醒与无效能耗，开盖解锁瞬间秒速恢复连网*

<img src="images/wifi.png" width="620" alt="BlueNap Wi-Fi Settings" />

</div>

---

[English](#english) | [中文说明](#中文说明)

---

<a name="english"></a>
## English

### Overview

**BlueNap (蓝憩) elegantly prevents your sleeping Mac from hijacking paired Bluetooth accessories.**

When you share Bluetooth headphones, earbuds (such as AirPods), or speakers between your Mac and iPhone/iPad, a sleeping Mac can intermittently connect in the background during maintenance wakeups or power assertions, abruptly interrupting your audio or draining accessory battery.

**BlueNap** provides an intuitive, serene solution:
- When your Mac **goes to sleep**, BlueNap automatically disconnects selected audio accessories or gracefully switches off Bluetooth entirely.
- When your Mac **wakes up and is unlocked**, BlueNap restores your previous state seamlessly.
- Optionally applies the same power lifecycle management for **Wi-Fi**.
- **AutoWiFi Intelligent Static IP Auto-Switching**: Detects your connected Wi-Fi SSID and automatically applies customized static IP, subnet, router, and DNS settings. When leaving, it restores DHCP automatically. Powered by a native Swift LaunchDaemon with 0.0% CPU and zero polling.

---

### What's New in Version 2.2.0

1. **Auto-Close Menu Bar Icon & Silent Background Mode**
   - Configurable timeout (Never, 1, 2, 3, 5, 10, or 15 minutes) to automatically hide the menu bar icon and run silently in the background.
   - On system startup or launch at login, BlueNap starts quietly without popping up the Settings window, showing only the status bar item before automatically entering background mode.
   - Intelligent interaction protection: countdown automatically pauses while menu or settings window is open. Relaunching from Applications or Spotlight restores both the menu bar icon and settings window instantly.

2. **System & Lifecycle Integration**
   - Added native macOS "Launch at login" toggle powered by `SMAppService.mainApp`.
   - Added dedicated "Quit Application" button in General preferences and header bar.

3. **Privacy & Security Commitment**
   - 100% offline, zero-telemetry architecture: does not collect, track, or upload any user personal or device data.

4. **Ecosystem & Memory Optimization**
   - Added featured recommendation for [Tactile (秒触)](https://app.needai.top/app/tactile) - 120Hz ProMotion Multitouch & Gesture engine.
   - Aggressive memory purging and zero-IPC caching reducing runtime footprint to bare minimum.

---

### What's New in Version 2.1.0

1. **AutoWiFi Static IP Auto-Binding Subsystem**
   - Seamlessly switches between DHCP and custom static IP profiles matching office/lab/home SSIDs.
   - Master switch to enable/disable auto-binding anytime, with individual per-profile toggles.
   - Pure Swift native background daemon (`bluenap-wifid`) replacing legacy shell scripts, consuming 0.0% CPU via kernel `SCDynamicStore` event-driven notifications.
   - Full daemon lifecycle management directly within the UI: install, start, stop, restart, and uninstall.
   - Live network card, IPv4 validation, and one-tap DNS presets (AliDNS, DNSPod, 114DNS, Cloudflare, Google).

2. **Swift 6 Complete Concurrency Architecture**
   - Fully compiled under `SWIFT_STRICT_CONCURRENCY = complete` with zero concurrency warnings or race conditions.
   - Actor-isolated hardware managers: [`BluetoothService`](src/Bluesnooze/Classes/BluetoothService.swift) and [`WiFiService`](src/Bluesnooze/Classes/WiFiService.swift) ensure all hardware control and I/O tasks execute off the main thread.
   - Unified reactive UI state model driven by `@Observable` and `@MainActor` ([`AppState`](src/Bluesnooze/Classes/AppState.swift) and [`Preferences`](src/Bluesnooze/Classes/Preferences.swift)).

2. **Liquid Glass SwiftUI Preferences Panel**
   - Replaced clunky nested menus with a native, responsive SwiftUI Settings window ([`PreferencesView`](src/Bluesnooze/Classes/PreferencesView.swift)).
   - Dedicated tabs for **Bluetooth**, **Wi-Fi**, **General**, and **About**.
   - Live paired Bluetooth accessories list with intelligent SF Symbol classification.
   - Automatic protection for HID input devices (mice, keyboards, trackpads) to eliminate accidental disconnection.

3. **Background-Only Daemon Mode (Hide Menu Bar Icon)**
   - Option to completely hide the status bar icon while keeping the background sleep/wake listener active.
   - **Failsafe Re-summon**: Simply relaunching BlueNap via Spotlight, Finder, or Terminal automatically restores the Settings window.

4. **Comprehensive Localization (English & 简体中文)**
   - Complete Chinese translation across menu bars, settings panels, alerts, and VoiceOver accessibility labels.

5. **Apple Notarized & Direct Distribution**
   - Officially notarized by Apple (`source=Notarized Developer ID`), guaranteed Gatekeeper trust with zero quarantine blocks.

---

### 🌟 More macOS Apps from Developer

* **[Tactile (妙触)](https://app.needai.top/app/tactile)** — Next-Generation 120Hz ProMotion Multitouch Gesture Powerhouse & Stroke Drawing Engine for macOS. Buttery-smooth, native-grade trackpad & Magic Mouse gesture enhancements.
* **[Official Website (BlueNap)](https://app.needai.top/app/bluenap)** — Discover more commercial-grade native macOS & iOS utilities crafted for speed and elegance.

---

### System Requirements & Development Environment

* **Operating System**: macOS 14.0 (Sonoma) or later.
* **⚠️ Testing Notice**: **This application has currently only been tested and validated on macOS 27.**
* **Architecture**: Universal (Apple Silicon M1/M2/M3/M4 & Intel x86_64).
* **Development Environment**: macOS 27 (Darwin 26.x), Xcode 16.0+, Swift 6.0 (`SWIFT_STRICT_CONCURRENCY = complete`).

---

### 🔒 Privacy Policy

**BlueNap operates 100% locally and offline on your device.** It makes zero outbound network connections, includes no tracking or analytics SDKs, and never collects, stores, or uploads any user private data.

---

<a name="中文说明"></a>
## 中文说明

### 项目简介

**蓝憩 (BlueNap)** 是一款专为 Mac 用户精心打造的「意境优雅风」蓝牙与 Wi-Fi 深度休眠管理工具。

当您在 iPhone/iPad 与 Mac 之间共用蓝牙耳机（如 AirPods）或无线音箱时，休眠中的 Mac 经常会因系统后台维护（Power Nap、网络唤醒）意外“抢连”蓝牙耳机，打断您的手机听歌通话，或在背包中悄悄耗尽耳机电量。

**蓝憩** 赋予您的 Mac 恬静的睡眠体验：
- **Mac 入睡**：合盖或进入睡眠时，蓝憩立即断开指定的蓝牙音频设备或完全关闭蓝牙电源；
- **Mac 醒来**：屏幕唤醒并解锁后，瞬间自动还原休眠前的外设与网络状态；
- **AutoWiFi 静态 IP 智能绑定**：全自动感知当前连接的 Wi-Fi SSID，毫秒级切换为对应网络预设的静态 IPv4、子网掩码、网关与 DNS，离开或断开自动恢复 DHCP。内置纯原生 Swift LaunchDaemon 守护进程，内核级事件驱动，零轮询、0.0% CPU 占用；
- **输入外设安全守卫**：全自动识别蓝牙鼠标、触控板与键盘，坚决不误断输入设备，确保蓝牙唤醒顺畅无阻。

---

### 核心特性 (v2.2.0)

1. **菜单栏定时自动隐藏与开机静默后台运行**
   - 灵活设置自动关闭菜单栏时长（从不、1/2/3/5/10/15 分钟），达到时限后自动从状态栏隐去，转入极低功耗静默后台。
   - 开机或登录启动时，默认仅在菜单栏常驻、绝不主动弹出任何设置界面打扰用户。
   - 智能防误触：在用户展开菜单或浏览设置时自动暂停计时；随时从「应用程序」或「聚焦搜索」再次点击 BlueNap 即可立刻唤回界面与图标。
2. **系统生命周期原生集成**
   - 采用 Apple 现代 `SMAppService.mainApp` 官方 API，在通用设置一键开启/关闭「登录时自动启动」。
   - 新增明确的「完全退出应用」按钮，停止一切后台监听。
3. **隐私安全声明与零遥测**
   - 坚持 100% 本地纯离线运行，绝不收集、追踪或上传任何设备与个人隐私数据。
4. **精选生态推荐与内存深度优化**
   - 推荐新一代 macOS 120Hz 智能多指触控神器 [Tactile (秒触)](https://app.needai.top/app/tactile)。
   - 设置窗口关闭主动释放 SwiftUI 视图层图元与 `URLCache` 缓存，触发系统级内存压力释放。

---

### 核心特性 (v2.1.0)

1. **AutoWiFi 智能网络绑定引擎**
   - 告别繁琐的终端命令与 Shell 脚本，由纯 Swift 原生守护进程驱动。
   - 提供全局主开关与单网络独立开关，自由掌控是否绑定静态 IP。
   - 偏好设置面板内原生一键安装、启动、停止、重启与彻底卸载后台 LaunchDaemon 守护进程。
   - 实时网络状态看板（显示当前连接 SSID、IP、掩码、网关与 DNS），自带“立即应用规则”与“使用当前网络配置”。
   - 预设常用高速 DNS（阿里、腾讯 DNSPod、114DNS、Cloudflare、Google）。
2. **Swift 6 全并发安全架构**
   - 彻底开启 `SWIFT_STRICT_CONCURRENCY = complete`，严格消除数据竞争。
2. **Liquid Glass 流光玻璃偏好设置**
   - 专为 macOS Sonoma/Sequoia 设计的高级磨砂拟物面板，支持独立勾选任意已配对设备，实时响应。
3. **后台极简静默模式**
   - 支持彻底隐藏状态栏图标，后台持续监听休眠事件；只需从聚焦搜索（Spotlight）再次启动蓝憩，即可随时唤回设置。
4. **全语言原生适配**
   - 包含完整的简体中文（`zh-Hans`）与英文（`en`）支持，状态提示、动效反馈与 VoiceOver 盲人读屏完全本土化。
5. **苹果官方公证 (Notarized)**
   - 已通过 Apple 官方安全扫描公证，搭载 Developer ID 权威签名，下载即开，无拦截弹窗。

---

### 🌟 更多开发者独立作品

* **[Tactile (妙触)](https://app.needai.top/app/tactile)**：macOS 120Hz 全能多点触控与笔画手势神器。独创单指驻留滑动、流光轨迹绘字识别、妙控鼠标全表面增强，榨干触控板潜能。
* **[官方应用主页 (BlueNap)](https://app.needai.top/app/bluenap)**：汇聚个人独立开发的高品质 Apple 生态原生应用，欢迎体验。

---

### 系统要求与开发环境说明

* **系统支持**：macOS 14.0 (Sonoma) 或更高版本。
* **⚠️ 测试环境特别说明**：**本应用目前仅在 macOS 27 环境下完成全面测试与验证。**
* **硬件架构**：Universal 通用二进制（原生支持 Apple Silicon M1/M2/M3/M4 与 Intel x86_64 架构）。
* **开发环境说明**：macOS 27 (Darwin 26.x)、Xcode 16.0+、Swift 6.0 纯原生（开启严格并发检查 `SWIFT_STRICT_CONCURRENCY = complete`）。

---

### 🔒 隐私与数据安全

**蓝憩 (BlueNap) 100% 在本地设备离线运行。** 绝无任何外部网络请求与上传行为，不含任何统计或遥测 SDK，承诺绝不收集、记录或上传任何用户的个人隐私数据。

---

### 源码编译指南

```bash
# 克隆仓库
git clone https://github.com/jorchford/BlueNap.git
cd BlueNap

# 执行 Release 编译
xcodebuild -project src/Bluesnooze.xcodeproj \
           -scheme Bluesnooze \
           -configuration Release \
           build
```

---

### 开发者信息
* **支持我喝杯咖啡**：[https://afdian.com/item/383f394ccd6011f1a9ec5254001e7c00](https://afdian.com/item/383f394ccd6011f1a9ec5254001e7c00)
* **官方展示页面**：[https://app.needai.top/app/bluenap](https://app.needai.top/app/bluenap)
* **GitHub 仓库**：[https://github.com/jorchford/BlueNap](https://github.com/jorchford/BlueNap)
* **更多 macOS 神器**：[https://github.com/jorchford/tactile](https://github.com/jorchford/tactile)
* **作者**：[ Jorchford](https://github.com/jorchford)
