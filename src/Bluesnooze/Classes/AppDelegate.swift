//
//  AppDelegate.swift
//  Bluesnooze
//
//  Created by Oliver Peate on 07/04/2020.
//  Modernized for Swift 6 on 2026-10-20.
//

import Cocoa
import CoreWLAN
import Darwin
import IOBluetooth
import os

@main
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    // MARK: - IBOutlets

    @IBOutlet var statusMenu: NSMenu!
    @IBOutlet var bluetoothMenu: NSMenu!
    @IBOutlet var disableBluetoothOnPowerDownMenuItem: NSMenuItem!
    @IBOutlet var disconnectBluetoothDevicesOnPowerDownMenuItem: NSMenuItem!
    @IBOutlet var bluetoothActionOnScreenUnlockRestore: NSMenuItem!
    @IBOutlet var bluetoothActionOnScreenUnlockEnable: NSMenuItem!
    @IBOutlet var bluetoothActionOnScreenUnlockNothing: NSMenuItem!
    @IBOutlet var bluetoothDeviceListStart: NSMenuItem!
    @IBOutlet var bluetoothDeviceListEnd: NSMenuItem!
    @IBOutlet var disableWifiOnPowerDownMenuItem: NSMenuItem!
    @IBOutlet var wifiActionOnScreenUnlockRestore: NSMenuItem!
    @IBOutlet var wifiActionOnScreenUnlockEnable: NSMenuItem!
    @IBOutlet var wifiActionOnScreenUnlockNothing: NSMenuItem!
    @IBOutlet var hideIconMenuItem: NSMenuItem!

    // MARK: - Properties

    static var shared: AppDelegate? {
        NSApplication.shared.delegate as? AppDelegate
    }

    private var statusItem: NSStatusItem?
    private var autoHideTimer: Timer?
    private let preferences = Preferences.shared
    private let powerStateManager = PowerStateManager.shared
    private let bluetoothService = BluetoothService.shared
    private let appState = AppState.shared

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_: Notification) {
        Bundle.setupLocalizationSwizzling()

        // Prevent sudden termination to ensure status bar item is cleanly unmapped from MenuBarAgent
        ProcessInfo.processInfo.disableSuddenTermination()

        let localizedAppName = Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.localizedInfoDictionary?["CFBundleName"] as? String
            ?? NSLocalizedString("BlueNap", comment: "")
        ProcessInfo.processInfo.processName = localizedAppName

        if CommandLine.arguments.contains("--hidden") || CommandLine.arguments.contains("--background") {
            if !preferences.hideIcon {
                createStatusItem()
            }
        } else {
            // Default to opening/showing menu bar icon on startup / interactive launch
            if preferences.autoHideMenuBarDelayMinutes > 0 || !preferences.hideIcon {
                if statusItem == nil {
                    createStatusItem()
                }
                preferences.hideIcon = false
            } else if statusItem == nil {
                createStatusItem()
            }
        }
        localizeMenuTitles()
        setupNotificationHandlers()
        setupAccessibility()
        scheduleAutoHideTimerIfNeeded()

        if CommandLine.arguments.contains("--settings") {
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
            if statusItem == nil {
                createStatusItem()
            }
            updateStatusItemTooltip()
            hideIconMenuItem?.title = NSLocalizedString("Hide icon", comment: "")
            updateMenuStates()
            scheduleAutoHideTimerIfNeeded()
        } else {
            cancelAutoHideTimer()
            if let item = statusItem {
                item.menu = nil
                item.button?.image = nil
                item.button?.action = nil
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
            hideIconMenuItem?.title = NSLocalizedString("Show icon", comment: "")
            clearBluetoothDeviceList()
        }
        trimMemoryFootprint()
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

    private func updateStatusItemTooltip() {
        statusItem?.button?.toolTip = appState.status.menuTitle
    }

    // MARK: - Status Item & UI Setup

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let icon = NSImage(named: "bluesnooze") {
            icon.isTemplate = true
            item.button?.image = icon
        } else {
            item.button?.title = NSLocalizedString("BlueNap", comment: "")
        }

        item.button?.toolTip = appState.status.menuTitle
        statusMenu.delegate = self
        item.menu = statusMenu

        item.button?.setAccessibilityLabel(NSLocalizedString(
            "BlueNap",
            tableName: "Accessibility",
            comment: "Accessibility label for the menu bar icon"
        ))
        item.button?.setAccessibilityIdentifier("AppDelegate.statusItem")
        statusItem = item
    }

    func localizeMenuTitles() {
        guard let statusMenu else { return }

        for item in statusMenu.items {
            if item.submenu == bluetoothMenu {
                item.title = NSLocalizedString("Bluetooth", comment: "")
                bluetoothMenu?.title = NSLocalizedString("Bluetooth", comment: "")
            } else if item.submenu != nil {
                item.title = NSLocalizedString("Wi-Fi", comment: "")
                item.submenu?.title = NSLocalizedString("Wi-Fi", comment: "")
            } else if item.action == #selector(openPreferencesClicked(_:)) {
                item.title = NSLocalizedString("Preferences…", comment: "")
            } else if item == hideIconMenuItem {
                item.title = preferences.hideIcon ?
                    NSLocalizedString("Show icon", comment: "") :
                    NSLocalizedString("Hide icon", comment: "")
            } else if item.action == #selector(websiteClicked(_:)) {
                item.title = NSLocalizedString("Website", comment: "")
            } else if item.action == #selector(quitClicked(_:)) {
                item.title = NSLocalizedString("Quit", comment: "")
            } else if !item.isSeparatorItem && !item.title.isEmpty {
                localizeMenuItem(item)
            }
        }

        if let bluetoothMenu {
            for item in bluetoothMenu.items {
                if item.action == nil && !item.isSeparatorItem && !item.title.isEmpty {
                    if item.title.contains("sleeping") || item.title.contains("休眠") || item.title.contains("スリープ") {
                        item.title = NSLocalizedString("Action when sleeping", comment: "")
                    } else if item.title.contains("unlock") || item.title.contains("唤醒") || item.title.contains("ロック解除") {
                        item.title = NSLocalizedString("Action when unlocked", comment: "")
                    }
                }
            }
        }
        disableBluetoothOnPowerDownMenuItem?.title = NSLocalizedString("Turn off Bluetooth", comment: "")
        disconnectBluetoothDevicesOnPowerDownMenuItem?.title = NSLocalizedString("Disconnect selected devices", comment: "")
        bluetoothActionOnScreenUnlockRestore?.title = NSLocalizedString("Restore previous state", comment: "")
        bluetoothActionOnScreenUnlockEnable?.title = NSLocalizedString("Always enable", comment: "")
        bluetoothActionOnScreenUnlockNothing?.title = NSLocalizedString("Do nothing", comment: "")

        disableWifiOnPowerDownMenuItem?.title = NSLocalizedString("Turn off when sleeping", comment: "")
        wifiActionOnScreenUnlockRestore?.title = NSLocalizedString("Restore previous state", comment: "")
        wifiActionOnScreenUnlockEnable?.title = NSLocalizedString("Always enable", comment: "")
        wifiActionOnScreenUnlockNothing?.title = NSLocalizedString("Do nothing", comment: "")

        // Wi-Fi submenu header
        if let wifiItem = statusMenu.items.first(where: { $0.submenu != nil && $0.submenu != bluetoothMenu }) {
            for sub in wifiItem.submenu?.items ?? [] {
                if sub.action == nil && !sub.isSeparatorItem && !sub.title.isEmpty {
                    sub.title = NSLocalizedString("Action when unlocked:", comment: "")
                }
            }
        }
        updateStatusItemTooltip()
    }

    private func localizeMenuItem(_ item: NSMenuItem) {
        guard !item.isSeparatorItem else { return }
        let originalKey = (item.identifier?.rawValue).flatMap { $0.isEmpty ? nil : $0 } ?? item.title
        if item.identifier == nil {
            item.identifier = NSUserInterfaceItemIdentifier(originalKey)
        }
        let localized = NSLocalizedString(originalKey, comment: "")
        item.title = localized.isEmpty ? originalKey : localized
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_: NSMenu) {
        localizeMenuTitles()
        cancelAutoHideTimer()
        appState.refreshHardwareStates()
        updateMenuStates()
    }

    func menuDidClose(_: NSMenu) {
        scheduleAutoHideTimerIfNeeded()
    }

    @IBAction func handleMenuOpen(_: NSMenu) {
        localizeMenuTitles()
        appState.refreshHardwareStates()
        updateMenuStates()
    }

    private func updateMenuStates() {
        // Bluetooth settings
        disableBluetoothOnPowerDownMenuItem.state = boolToMenuState(preferences.disableBluetoothOnSleep)
        disconnectBluetoothDevicesOnPowerDownMenuItem.isEnabled = true
        disconnectBluetoothDevicesOnPowerDownMenuItem.state = boolToMenuState(preferences.disconnectDevicesOnSleep)

        // Populate dynamic device list
        populateBluetoothDeviceList()

        // Bluetooth wake actions
        let isBtActive = preferences.isBluetoothSleepActionActive
        let btAction = preferences.bluetoothWakeAction
        bluetoothActionOnScreenUnlockRestore.isEnabled = isBtActive
        let isRestoreActive = btAction == .restore ? (isBtActive ? true : nil) : false
        bluetoothActionOnScreenUnlockRestore.state = boolToMenuState(isRestoreActive)
        bluetoothActionOnScreenUnlockEnable.state = boolToMenuState(btAction == .enable)
        bluetoothActionOnScreenUnlockNothing.state = boolToMenuState(btAction == .nothing)

        // Wi-Fi settings
        let isWifiActive = preferences.disableWifiOnSleep
        let wifiAction = preferences.wifiWakeAction
        disableWifiOnPowerDownMenuItem.state = boolToMenuState(isWifiActive)
        wifiActionOnScreenUnlockRestore.isEnabled = isWifiActive
        let isWifiRestore = wifiAction == .restore ? (isWifiActive ? true : nil) : false
        wifiActionOnScreenUnlockRestore.state = boolToMenuState(isWifiRestore)
        wifiActionOnScreenUnlockEnable.state = boolToMenuState(wifiAction == .enable)
        wifiActionOnScreenUnlockNothing.state = boolToMenuState(wifiAction == .nothing)

        // Hide icon
        hideIconMenuItem.state = boolToMenuState(preferences.hideIcon)
        hideIconMenuItem.title = preferences.hideIcon ?
            NSLocalizedString("Show icon", comment: "") :
            NSLocalizedString("Hide icon", comment: "")
    }

    private func clearBluetoothDeviceList() {
        guard let startItem = bluetoothDeviceListStart,
              let endItem = bluetoothDeviceListEnd,
              let menu = bluetoothMenu else { return }

        let startIndex = menu.index(of: startItem) + 1
        let endIndex = menu.index(of: endItem)
        guard startIndex < endIndex else { return }

        for _ in startIndex ..< endIndex {
            menu.removeItem(at: startIndex)
        }
    }

    private func populateBluetoothDeviceList() {
        clearBluetoothDeviceList()

        guard let startItem = bluetoothDeviceListStart,
              let menu = bluetoothMenu else { return }
        let startIndex = menu.index(of: startItem) + 1

        let pairedDevices = appState.pairedDevices
        if pairedDevices.isEmpty {
            let noDevicesItem = NSMenuItem(
                title: NSLocalizedString("No audio devices", comment: ""),
                action: nil,
                keyEquivalent: ""
            )
            noDevicesItem.isEnabled = false
            noDevicesItem.indentationLevel = startItem.indentationLevel
            menu.insertItem(noDevicesItem, at: startIndex)
        } else {
            for device in pairedDevices.reversed() {
                let item = BluetoothDeviceMenuItem(
                    deviceInfo: device,
                    action: #selector(bluetoothDeviceClicked(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                let isMarked = preferences.isDeviceMarkedForDisconnect(address: device.address)
                item.state = boolToMenuState(isMarked)
                item.isEnabled = true
                item.indentationLevel = startItem.indentationLevel
                menu.insertItem(item, at: startIndex)
            }
        }
    }
}

// MARK: - Action Handlers

extension AppDelegate {
    // MARK: - Bluetooth Actions

    @IBAction func disableBluetoothOnPowerDownClicked(_: NSMenuItem) {
        preferences.disableBluetoothOnSleep.toggle()
        if preferences.disableBluetoothOnSleep {
            preferences.disconnectDevicesOnSleep = false
        }
        if preferences.bluetoothWakeAction == .restore {
            preferences.bluetoothWakeAction = .nothing
        }
        updateMenuStates()
    }

    @IBAction func disconnectBluetoothDevicesOnPowerDownClicked(_: NSMenuItem) {
        preferences.disconnectDevicesOnSleep.toggle()
        if preferences.disconnectDevicesOnSleep {
            preferences.disableBluetoothOnSleep = false
        }
        if preferences.bluetoothWakeAction == .restore {
            preferences.bluetoothWakeAction = .nothing
        }
        updateMenuStates()
    }

    @IBAction func bluetoothActionOnScreenUnlockRestoreClicked(_: NSMenuItem) {
        preferences.bluetoothWakeAction = .restore
        updateMenuStates()
    }

    @IBAction func bluetoothActionOnScreenUnlockEnableClicked(_: NSMenuItem) {
        preferences.bluetoothWakeAction = .enable
        updateMenuStates()
    }

    @IBAction func bluetoothActionOnScreenUnlockNothingClicked(_: NSMenuItem) {
        preferences.bluetoothWakeAction = .nothing
        updateMenuStates()
    }

    @IBAction func bluetoothDeviceClicked(_ sender: BluetoothDeviceMenuItem) {
        let addr = sender.deviceAddressString
        let isCurrentlyMarked = preferences.isDeviceMarkedForDisconnect(address: addr)
        let nextState = !isCurrentlyMarked
        preferences.setDeviceMarkedForDisconnect(address: addr, disconnect: nextState)
        if nextState, !preferences.disconnectDevicesOnSleep {
            preferences.disconnectDevicesOnSleep = true
            preferences.disableBluetoothOnSleep = false
        }
        updateMenuStates()
    }

    // MARK: - Wi-Fi Actions

    @IBAction func disableWifiOnPowerDownClicked(_: NSMenuItem) {
        preferences.disableWifiOnSleep.toggle()
        if preferences.wifiWakeAction == .restore {
            preferences.wifiWakeAction = .nothing
        }
        updateMenuStates()
    }

    @IBAction func wifiActionOnScreenUnlockRestoreClicked(_: NSMenuItem) {
        preferences.wifiWakeAction = .restore
        updateMenuStates()
    }

    @IBAction func wifiActionOnScreenUnlockEnableClicked(_: NSMenuItem) {
        preferences.wifiWakeAction = .enable
        updateMenuStates()
    }

    @IBAction func wifiActionOnScreenUnlockNothingClicked(_: NSMenuItem) {
        preferences.wifiWakeAction = .nothing
        updateMenuStates()
    }

    // MARK: - General Actions

    @IBAction func openPreferencesClicked(_: Any) {
        SettingsWindowController.shared.showSettings()
    }

    @IBAction func hideIconClicked(_: NSMenuItem) {
        if preferences.hideIcon {
            setMenuBarIconVisible(true)
        } else {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Hide from Menu Bar?", comment: "")
            alert.informativeText = NSLocalizedString(
                "BlueNap will continue running silently in the background.\n\n" +
                    "To open Settings or restore the menu bar icon, launch BlueNap again from Applications or Spotlight.",
                comment: ""
            )
            alert.alertStyle = .informational
            alert.addButton(withTitle: NSLocalizedString("Hide Icon", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))

            let response = alert.runModal()
            alert.window.orderOut(nil)
            alert.window.contentView = nil

            if response == .alertSecondButtonReturn {
                trimMemoryFootprint()
                return
            }
            setMenuBarIconVisible(false)
        }
    }

    @IBAction func websiteClicked(_: NSMenuItem) {
        if let url = URL(string: "https://github.com/jorchford/BlueNap") {
            NSWorkspace.shared.open(url)
        }
    }

    @IBAction func quitClicked(_: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }

    // MARK: - Auto-Hide Menu Bar Timer

    func scheduleAutoHideTimerIfNeeded() {
        cancelAutoHideTimer()

        let testDelaySeconds: TimeInterval? = {
            if let idx = CommandLine.arguments.firstIndex(of: "--autohide-delay-seconds"),
               idx + 1 < CommandLine.arguments.count,
               let sec = Double(CommandLine.arguments[idx + 1]) {
                return sec
            }
            return nil
        }()

        guard (preferences.autoHideMenuBarDelayMinutes > 0 || testDelaySeconds != nil), statusItem != nil else { return }

        if SettingsWindowController.shared.isWindowVisible {
            return
        }

        let delaySeconds = testDelaySeconds ?? TimeInterval(preferences.autoHideMenuBarDelayMinutes * 60)
        Log.app.info("Scheduling menu bar icon auto-hide in \(delaySeconds, privacy: .public)s")

        autoHideTimer = Timer.scheduledTimer(withTimeInterval: delaySeconds, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if SettingsWindowController.shared.isWindowVisible {
                    self.scheduleAutoHideTimerIfNeeded()
                    return
                }
                Log.app.info("Auto-hiding menu bar icon after configured delay. Entering background mode.")
                self.setMenuBarIconVisible(false)
            }
        }
    }

    func cancelAutoHideTimer() {
        if autoHideTimer != nil {
            autoHideTimer?.invalidate()
            autoHideTimer = nil
        }
    }

    // MARK: - Helpers

    func trimMemoryFootprint() {
        malloc_zone_pressure_relief(nil, 0)
        DispatchQueue.main.async {
            malloc_zone_pressure_relief(nil, 0)
        }
    }

    private func boolToMenuState(_ value: Bool?) -> NSControl.StateValue {
        switch value {
        case true: .on
        case false: .off
        case nil: .mixed
        }
    }
}
