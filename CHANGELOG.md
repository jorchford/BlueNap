# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2.1.1] - 2026-10-24

### Fixed
- **Memory Optimization (Physical Footprint reduced from ~61MB to ~12MB)**:
  - Completely eliminated all CLI subprocess spawning (`networksetup`, `ioreg`, `route`, `pgrep`, `launchctl print`) from `WiFiNetworkMonitor` and `WiFiDaemonManager`.
  - Converted network gateway, DNS, manual/DHCP configuration, and process status checks to 100% in-memory queries via `SCDynamicStoreCopyValue` and Darwin `proc_listallpids`/`proc_name`.
  - Automatically halt network monitoring and reclaim memory resources when the settings window closes.
- **Resolved Xcode Hang Risk & QoS Priority Inversion**:
  - Removed synchronous AppleScript executions during routine configuration changes; user configurations are saved instantly in Application Support (`~/Library/Application Support/BlueNap/bluenap-wifi.conf`).
  - Isolated privileged service installations to background utility queues with asynchronous continuations.

### Changed
- **Official App Branding & Multilingual App Name Support**:
  - Configured `LSHasLocalizedDisplayName` and `CFBundleLocalizations` in `Info.plist` to enable macOS LaunchServices and Finder to natively display **蓝憩** in Simplified Chinese, **藍憩** in Traditional Chinese, and **BlueNap** in English and Japanese.
  - Dynamically set `ProcessInfo.processInfo.processName` at application launch to reflect the localized app name in Activity Monitor, Force Quit, and system dialogs.
  - Set `PRODUCT_NAME` and `CFBundleDisplayName` to **BlueNap** (Chinese: **蓝憩**).
  - Added full multi-language localizations: Traditional Chinese (`zh-Hant`) and Japanese (`ja`), alongside Simplified Chinese (`zh-Hans`) and English (`en`).
  - Implemented runtime menu item localization so menu bars dynamically match the system language.

## [2.1.0] - 2026-10-24

### Added
- **AutoWiFi Intelligent Static IP Auto-Switching Subsystem**:
  - Automatically detects connected Wi-Fi SSID and applies tailored static IPv4 configurations (IP address, subnet mask, router, DNS servers).
  - Automatically restores DHCP when disconnecting from configured SSIDs or joining untracked networks.
  - Global master toggle for static IP auto-binding (`isAutoWiFiBindingEnabled`) and per-profile toggles (`isEnabled`).
  - Native LaunchDaemon (`bluenap-wifid`) written in Swift to replace the legacy 700-line shell script, maintaining 0.0% CPU and zero polling via `SCDynamicStoreCreate` kernel notifications.
  - Full daemon service lifecycle management inside the Settings UI: Install, Start, Stop, Restart, and Uninstall `/Library/LaunchDaemons/com.red.bluenap.autowifi.plist`.
  - Live network status card displaying current SSID, IPv4, Subnet, Router, DNS, and manual/DHCP status with "Apply Rule Now" button.
  - Profile edit sheet with "Use Current Wi-Fi" one-click autofill, live IPv4 format validation, and one-tap domestic & international DNS presets (AliDNS, DNSPod, 114DNS, Cloudflare, Google).
  - Compatible with `/usr/local/etc/bluenap-wifi.conf` and legacy `/usr/local/etc/wifi-static-ip-switcher.conf` INI formats.
- **Preferences & UI Upgrades**:
  - Expanded Preferences window frame to 580x540 for comfortable layout.
  - Added dedicated screenshot generation option (`--screenshot`) with Retina export.

## [2.0.1] - 2026-10-21

### Fixed
- Fixed Bluetooth device selection reactivity where `@ObservationIgnored` cache prevented SwiftUI view re-renders when toggling devices.
- Resolved mutual exclusivity deadlock between full Bluetooth toggle and per-device disconnect toggles.
- Fixed Swift 6 actor-isolation warning on `screenIsUnlocked` distributed notification closure via `MainActor.assumeIsolated`.
- Fixed memory ballooning when hiding the menu bar icon by aggressively unbinding `NSAlert` modal windows, status items, dynamic menus, and invoking `malloc_zone_pressure_relief`.
- Lazily released SwiftUI `NSHostingView` and `NSWindow` on settings window close to reclaim memory.

### Added
- Linked developer official website (https://app.needai.top/app/bluenap) and Tactile (妙触) app recommendations in About tab and README.

## [2.0.0] - 2026-10-20

### Added
- Complete rewrite with Swift 6 and strict concurrency checking (`SWIFT_STRICT_CONCURRENCY = complete`).
- Dedicated native SwiftUI Liquid Glass Preferences window with tabs: Bluetooth, Wi-Fi, General, and About.
- Full Chinese (Simplified, `zh-Hans`) localization support across menus, status bar tooltips, alerts, accessibility, and preferences.
- Smart paired Bluetooth device identification with SF Symbols (headphones, watch, mouse, keyboard, controller, audio).
- Headless / background-only daemon mode with failsafe relaunch detection to re-open settings.
- Missing `NSBluetoothAlwaysUsageDescription` and `NSBluetoothPeripheralUsageDescription` in Info.plist for macOS Sonoma/Sequoia TCC compliance.
- True lazy-loading of window controllers and hosting views to reduce idle memory usage to the bare minimum.
- VoiceOver accessibility labels and hints for menu bar and settings items.

### Fixed
- Fixed Swift 6 actor-isolation compiler warnings on `NSAnimationContext.runAnimationGroup` completion handlers and `@objc @MainActor` notification selectors.
- Fixed WindowServer/HIToolbox menu tracking deadlock caused by asynchronous tasks inside `menuWillOpen`.
- Filtered HID input devices (mice, keyboards, trackpads) to eliminate IOBluetooth BLE packet drop issues.

### Changed
- Converted hardware controllers into actor-isolated services (`BluetoothService`, `WiFiService`).
- State management modernized to `@Observable` and `@MainActor` (`AppState`, `Preferences`).
- Upgraded minimum macOS deployment target to macOS 14.0 (Sonoma).

### Removed
- Third-party `LaunchAtLogin` SPM dependency and legacy framework bindings.
- Legacy `BluetoothManager.swift` and `WiFiManager.swift`.

## [March 2023]

### Added
- Option to disconnect Bluetooth devices on sleep.

### Fixed
- Bluetooth devices could remain disconnected after a quick sleep/wake cycle.
- Bluetooth no longer fails to reconnect after unlocking the screen when the wake action is set to enable.

## [December 2022]

### Added
- Wi-Fi support: optionally disable Wi-Fi on sleep and re-enable on wake.
- Website menu item with the version number shown as a tooltip.

### Changed
- State is now restored when the screen is unlocked instead of on power up.

## [October 2022]

### Added
- Alert with instructions for showing the menu bar icon again after hiding it.
- Tooltip on the menu bar icon.

## [September 2022]

### Added
- Status bar icon is re-added when the app is launched a second time.
- Settings sync when the menu is opened, so manual edits via the `defaults` utility are picked up.

### Changed
- Lowered the minimum macOS version to 10.12.

## [August 2022]

### Added
- Wake behavior options: remember previous state, always enable, or never enable Bluetooth.
- Cmd+Q keyboard shortcut for the Quit menu item.

## [March 2022]

### Added
- Bluetooth state is remembered before sleep and restored on wake.

## [February 2021]

### Added
- Headless mode that hides the menu bar icon.
- Bluetooth is turned on when the app launches, and turned off during shutdown.

## [December 2020]

### Changed
- Updated the Homebrew cask install command for Homebrew 2.7.

## [July 2020]

### Added
- Homebrew installation instructions in the README.

## [June 2020]

### Added
- Installation instructions in the README.

## [April 2020]

### Added
- Initial release.
- Disable Bluetooth on sleep and re-enable on wake.
