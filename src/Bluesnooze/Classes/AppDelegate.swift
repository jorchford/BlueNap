//
//  AppDelegate.swift
//  Bluesnooze
//
//  Created by Oliver Peate on 07/04/2020.
//  Modernized for Swift 6 on 2026-10-20.
//

import Cocoa
import CoreWLAN
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
    private let preferences = Preferences.shared
    private let powerStateManager = PowerStateManager.shared
    private let bluetoothService = BluetoothService.shared
    private let appState = AppState.shared

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_: Notification) {
        // Prevent sudden termination to ensure status bar item is cleanly unmapped from MenuBarAgent
        ProcessInfo.processInfo.disableSuddenTermination()

        if !preferences.hideIcon {
            createStatusItem()
        }
        setupNotificationHandlers()
        setupAccessibility()
    }

    func applicationWillTerminate(_: Notification) {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
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
        } else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
            hideIconMenuItem?.title = NSLocalizedString("Show icon", comment: "")
        }
        updateMenuStates()
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
            self?.handleWakeSequence(source: "screenIsUnlocked")
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
            item.button?.title = "BlueNap"
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

    // MARK: - NSMenuDelegate

    func menuWillOpen(_: NSMenu) {
        appState.refreshHardwareStates()
        updateMenuStates()
    }

    @IBAction func handleMenuOpen(_: NSMenu) {
        appState.refreshHardwareStates()
        updateMenuStates()
    }

    private func updateMenuStates() {
        // Bluetooth settings
        disableBluetoothOnPowerDownMenuItem.state = boolToMenuState(preferences.disableBluetoothOnSleep)
        disconnectBluetoothDevicesOnPowerDownMenuItem.isEnabled = !preferences.disableBluetoothOnSleep
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

    private func populateBluetoothDeviceList() {
        guard let startItem = bluetoothDeviceListStart,
              let endItem = bluetoothDeviceListEnd,
              let menu = bluetoothMenu else { return }

        let startIndex = menu.index(of: startItem) + 1
        let endIndex = menu.index(of: endItem)
        guard startIndex <= endIndex else { return }

        for _ in startIndex ..< endIndex {
            menu.removeItem(at: startIndex)
        }

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
                item.isEnabled = preferences.disconnectDevicesOnSleep
                item.indentationLevel = startItem.indentationLevel
                menu.insertItem(item, at: startIndex)
            }
        }
    }

    // MARK: - Action Handlers: Bluetooth

    @IBAction func disableBluetoothOnPowerDownClicked(_: NSMenuItem) {
        preferences.disableBluetoothOnSleep.toggle()
        if preferences.bluetoothWakeAction == .restore {
            preferences.bluetoothWakeAction = .nothing
        }
        if preferences.disableBluetoothOnSleep {
            preferences.disconnectDevicesOnSleep = false
        }
        updateMenuStates()
    }

    @IBAction func disconnectBluetoothDevicesOnPowerDownClicked(_: NSMenuItem) {
        preferences.disconnectDevicesOnSleep.toggle()
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
        preferences.setDeviceMarkedForDisconnect(address: addr, disconnect: !isCurrentlyMarked)
        updateMenuStates()
    }

    // MARK: - Action Handlers: Wi-Fi

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

    // MARK: - Action Handlers: General & Preferences

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
            if alert.runModal() == .alertSecondButtonReturn {
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

    // MARK: - Helpers

    private func boolToMenuState(_ value: Bool?) -> NSControl.StateValue {
        switch value {
        case true: .on
        case false: .off
        case nil: .mixed
        }
    }
}
