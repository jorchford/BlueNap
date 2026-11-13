//
//  AppDelegate+Actions.swift
//  BlueNap
//
//  Created on 2026-11-13.
//

import Cocoa
import os

extension AppDelegate {
    // MARK: - Menu State Updating

    func updateMenuStates() {
        guard statusMenu != nil else { return }

        disableBluetoothOnPowerDownMenuItem.state = boolToMenuState(preferences.disableBluetoothOnSleep)
        disconnectBluetoothDevicesOnPowerDownMenuItem.isEnabled = true
        disconnectBluetoothDevicesOnPowerDownMenuItem.state = boolToMenuState(preferences.disconnectDevicesOnSleep)

        populateBluetoothDeviceList()

        let isBtActive = preferences.isBluetoothSleepActionActive
        let btAction = preferences.bluetoothWakeAction
        bluetoothActionOnScreenUnlockRestore.isEnabled = isBtActive
        let isRestoreActive = btAction == .restore ? (isBtActive ? true : nil) : false
        bluetoothActionOnScreenUnlockRestore.state = boolToMenuState(isRestoreActive)
        bluetoothActionOnScreenUnlockEnable.state = boolToMenuState(btAction == .enable)
        bluetoothActionOnScreenUnlockNothing.state = boolToMenuState(btAction == .nothing)

        let isWifiActive = preferences.disableWifiOnSleep
        let wifiAction = preferences.wifiWakeAction
        disableWifiOnPowerDownMenuItem.state = boolToMenuState(isWifiActive)
        wifiActionOnScreenUnlockRestore.isEnabled = isWifiActive
        let isWifiRestore = wifiAction == .restore ? (isWifiActive ? true : nil) : false
        wifiActionOnScreenUnlockRestore.state = boolToMenuState(isWifiRestore)
        wifiActionOnScreenUnlockEnable.state = boolToMenuState(wifiAction == .enable)
        wifiActionOnScreenUnlockNothing.state = boolToMenuState(wifiAction == .nothing)

        updateLanguageMenuStates()

        hideIconMenuItem.state = boolToMenuState(preferences.hideIcon)
        hideIconMenuItem.title = preferences.hideIcon
            ? NSLocalizedString("Show icon", comment: "")
            : NSLocalizedString("Exit to Background", comment: "")
        hideIconMenuItem.toolTip = NSLocalizedString("Exit to Background Description", comment: "")
    }

    func clearBluetoothDeviceList() {
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

    func boolToMenuState(_ value: Bool?) -> NSControl.StateValue {
        switch value {
        case true: .on
        case false: .off
        case nil: .mixed
        }
    }

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
            enterBackgroundMode()
        }
    }

    func enterBackgroundMode() {
        SettingsWindowController.shared.closeSettings()
        setMenuBarIconVisible(false)
    }

    @IBAction func websiteClicked(_: NSMenuItem) {
        if let url = URL(string: "https://www.needai.top/app/bluenap") {
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

        guard preferences.autoHideMenuBarDelayMinutes > 0 || testDelaySeconds != nil, statusItem != nil else { return }

        if SettingsWindowController.shared.isWindowVisible {
            return
        }

        let delaySeconds = testDelaySeconds ?? TimeInterval(preferences.autoHideMenuBarDelayMinutes * 60)
        Log.app.info("Scheduling menu bar icon auto-hide in \(delaySeconds, privacy: .public)s")

        autoHideTimer = Timer.scheduledTimer(withTimeInterval: delaySeconds, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if SettingsWindowController.shared.isWindowVisible {
                    scheduleAutoHideTimerIfNeeded()
                    return
                }
                Log.app.info("Auto-hiding menu bar icon after configured delay. Entering background mode.")
                setMenuBarIconVisible(false)
            }
        }
    }

    func cancelAutoHideTimer() {
        if autoHideTimer != nil {
            autoHideTimer?.invalidate()
            autoHideTimer = nil
        }
    }

    // MARK: - Memory Helpers

    func trimMemoryFootprint() {
        SettingsWindowController.shared.performDeepMemoryPurge()
    }
}
