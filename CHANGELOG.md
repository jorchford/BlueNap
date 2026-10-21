# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2.0.1] - 2026-10-21

### Fixed
- Fixed Bluetooth device selection reactivity where `@ObservationIgnored` cache prevented SwiftUI view re-renders when toggling devices.
- Resolved mutual exclusivity deadlock between full Bluetooth toggle and per-device disconnect toggles.
- Fixed Swift 6 actor-isolation warning on `screenIsUnlocked` distributed notification closure via `MainActor.assumeIsolated`.
- Fixed memory ballooning when hiding the menu bar icon by aggressively unbinding `NSAlert` modal windows, status items, dynamic menus, and invoking `malloc_zone_pressure_relief`.
- Lazily released SwiftUI `NSHostingView` and `NSWindow` on settings window close to reclaim memory.

### Added
- Linked developer official website (https://redsite.cn/apps/bluenap) and Tactile (妙触) app recommendations in About tab and README.

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
