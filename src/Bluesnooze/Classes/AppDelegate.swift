//
//  AppDelegate.swift
//  BlueNap
//
//  Created by jorchford on 2026-10-20.
//

import Cocoa
import CoreWLAN
import Darwin
import IOBluetooth
import os

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    // MARK: - Lazy Menu Items

    var statusMenu: NSMenu!
    var bluetoothMenu: NSMenu!
    var disableBluetoothOnPowerDownMenuItem: NSMenuItem!
    var disconnectBluetoothDevicesOnPowerDownMenuItem: NSMenuItem!
    var bluetoothActionOnScreenUnlockRestore: NSMenuItem!
    var bluetoothActionOnScreenUnlockEnable: NSMenuItem!
    var bluetoothActionOnScreenUnlockNothing: NSMenuItem!
    var bluetoothDeviceListStart: NSMenuItem!
    var bluetoothDeviceListEnd: NSMenuItem!
    var disableWifiOnPowerDownMenuItem: NSMenuItem!
    var wifiActionOnScreenUnlockRestore: NSMenuItem!
    var wifiActionOnScreenUnlockEnable: NSMenuItem!
    var wifiActionOnScreenUnlockNothing: NSMenuItem!
    var hideIconMenuItem: NSMenuItem!

    // MARK: - Properties

    static var shared: AppDelegate? {
        NSApplication.shared.delegate as? AppDelegate
    }

    var openSettingsOnLaunch = false
    var statusItem: NSStatusItem?
    var autoHideTimer: Timer?
    var languageMenuItem: NSMenuItem?
    var languageMenu: NSMenu?
    let preferences = Preferences.shared
    let powerStateManager = PowerStateManager.shared
    let appState = AppState.shared

    var activePreferences: Preferences {
        preferences
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_: Notification) {
        Bundle.setupLocalizationSwizzling()
        ProcessInfo.processInfo.disableSuddenTermination()

        let localizedAppName = Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.localizedInfoDictionary?["CFBundleName"] as? String
            ?? NSLocalizedString("BlueNap", comment: "")
        ProcessInfo.processInfo.processName = localizedAppName

        configureInitialStatusItemState()
        setupNotificationHandlers()
        scheduleAutoHideTimerIfNeeded()
        handleCommandLineLaunchOptions()

        if !SettingsWindowController.shared.isWindowVisible {
            SettingsWindowController.purgeAllProcessMallocZones()
        }
    }

    private func configureInitialStatusItemState() {
        if CommandLine.arguments.contains("--lang-en") {
            preferences.appLanguage = .en
        } else if CommandLine.arguments.contains("--lang-zh") {
            preferences.appLanguage = .zhHans
        }

        if CommandLine.arguments.contains("--hidden") || CommandLine.arguments.contains("--background") {
            if !preferences.hideIcon {
                createStatusItem()
            } else {
                setpriority(PRIO_PROCESS, 0, PRIO_DARWIN_BG)
            }
        } else if statusItem == nil {
            createStatusItem()
            preferences.hideIcon = false
        }
    }

    private func handleCommandLineLaunchOptions() {
        if CommandLine.arguments.contains("--dump-menu") {
            createStatusItem()
            buildStatusMenuIfNeeded()
            setupLanguageMenuIfNeeded()
            ensureMenuItemOrder()
            localizeMenuTitles()
            for (idx, item) in statusMenu.items.enumerated() {
                let title = item.isSeparatorItem ? "--- Separator ---" : item.title
                print("[\(idx)] \(title)")
            }
            exit(0)
        }

        if openSettingsOnLaunch || CommandLine.arguments.contains("--settings") {
            SettingsWindowController.shared.showSettings()
        }

        if let idx = CommandLine.arguments.firstIndex(of: "--close-after"), idx + 1 < CommandLine.arguments.count,
           let delay = Double(CommandLine.arguments[idx + 1]) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                SettingsWindowController.shared.window?.performClose(nil)
            }
        }

        if CommandLine.arguments.contains("--screenshot") {
            SettingsWindowController.shared.showSettings()
            let outputPath = CommandLine.arguments.first(where: { $0.hasSuffix(".png") })
                ?? "/Volumes/data/xcode/Bluesnooze/images/bluenap_autowifi_preferences.png"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                SettingsWindowController.shared.captureScreenshot(to: outputPath)
                print("Screenshot captured to \(outputPath)")
                NSApplication.shared.terminate(nil)
            }
        }
    }

    func applicationWillTerminate(_: Notification) {
        cancelAutoHideTimer()
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        if preferences.hideIcon {
            setMenuBarIconVisible(true)
        }
        SettingsWindowController.shared.showSettings()
        return true
    }

    func setMenuBarIconVisible(_ visible: Bool) {
        preferences.hideIcon = !visible
        if visible {
            setpriority(PRIO_PROCESS, 0, 0)
            if statusItem == nil {
                createStatusItem()
            }
            updateStatusItemTooltip()
            hideIconMenuItem?.title = NSLocalizedString("Exit to Background", comment: "")
            updateMenuStates()
            scheduleAutoHideTimerIfNeeded()
            trimMemoryFootprint()
        } else {
            cancelAutoHideTimer()
            SettingsWindowController.shared.closeSettings()
            teardownStatusMenu()
            if let item = statusItem {
                item.menu = nil
                item.button?.image = nil
                item.button?.action = nil
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
            appState.pairedDevices.removeAll(keepingCapacity: false)
            setpriority(PRIO_PROCESS, 0, PRIO_DARWIN_BG)
            trimMemoryFootprint()
        }
    }

    // MARK: - Notification Setup

    private func setupNotificationHandlers() {
        let center = NSWorkspace.shared.notificationCenter

        center.addObserver(
            self,
            selector: #selector(onPowerDown(note:)),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(onPowerDown(note:)),
            name: NSWorkspace.willPowerOffNotification,
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            forName: .init("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleWakeSequence(source: "screenIsUnlocked")
            }
        }

        center.addObserver(
            self,
            selector: #selector(onScreensDidWake(note:)),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }

    @objc @MainActor func onPowerDown(note _: NSNotification) {
        animateStatusTransition(toSnooze: true)
        powerStateManager.handlePowerDown()
    }

    @objc @MainActor func onScreensDidWake(note _: NSNotification) {
        handleWakeSequence(source: "screensDidWake")
    }

    private func handleWakeSequence(source: String) {
        animateStatusTransition(toSnooze: false)
        powerStateManager.handleUserWake(source: source)
    }

    // MARK: - Status Bar Transitions & Animation

    private func animateStatusTransition(toSnooze: Bool) {
        guard preferences.showTransitionAnimation, let button = statusItem?.button else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            button.animator().alphaValue = 0.3
        } completionHandler: {
            MainActor.assumeIsolated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.4
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    button.animator().alphaValue = toSnooze ? 0.65 : 1.0
                }
            }
        }

        updateStatusItemTooltip()
    }

    func updateStatusItemTooltip() {
        statusItem?.button?.toolTip = appState.status.menuTitle
    }

    // MARK: - Status Item & UI Setup

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let icon = StatusBarIconRenderer.makeStatusBarIcon() {
            item.button?.image = icon
        } else {
            item.button?.title = NSLocalizedString("BlueNap", comment: "")
        }

        item.button?.toolTip = appState.status.menuTitle
        item.menu = nil
        item.button?.target = self
        item.button?.action = #selector(statusBarButtonClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        item.button?.setAccessibilityLabel(NSLocalizedString(
            "BlueNap",
            tableName: "Accessibility",
            comment: "Accessibility label for the menu bar icon"
        ))
        item.button?.setAccessibilityIdentifier("AppDelegate.statusItem")
        statusItem = item
    }

    @objc func languageMenuItemClicked(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let lang = AppLanguage(rawValue: rawValue) else { return }
        preferences.appLanguage = lang
    }

    // MARK: - Status Bar Button Actions

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true

        if isRightClick {
            buildStatusMenuIfNeeded()
            setupLanguageMenuIfNeeded()
            ensureMenuItemOrder()
            localizeMenuTitles()
            updateLanguageMenuStates()
            statusItem?.menu = statusMenu
            statusItem?.button?.performClick(nil)
        } else {
            openPreferencesClicked(sender)
        }
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_: NSMenu) {
        buildStatusMenuIfNeeded()
        setupLanguageMenuIfNeeded()
        ensureMenuItemOrder()
        localizeMenuTitles()
        updateLanguageMenuStates()
        cancelAutoHideTimer()
        appState.refreshHardwareStates()
        updateMenuStates()
    }

    func menuDidClose(_: NSMenu) {
        statusItem?.menu = nil
        teardownStatusMenu()
        appState.pairedDevices.removeAll(keepingCapacity: false)
        scheduleAutoHideTimerIfNeeded()
        trimMemoryFootprint()
    }

    @IBAction func handleMenuOpen(_: NSMenu) {
        buildStatusMenuIfNeeded()
        setupLanguageMenuIfNeeded()
        ensureMenuItemOrder()
        localizeMenuTitles()
        updateLanguageMenuStates()
        appState.refreshHardwareStates()
        updateMenuStates()
    }
}
