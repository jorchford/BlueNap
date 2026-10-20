//
//  AppDelegate+Accessibility.swift
//  Bluesnooze
//
//  Created on 2026-10-20.
//

import Cocoa

extension AppDelegate {
    func setupAccessibility() {
        guard let statusMenu else { return }

        let bluetoothMenuItem = statusMenu.items.first { $0.submenu == bluetoothMenu }
        let wifiMenuItem = statusMenu.items.first { $0.hasSubmenu && $0.submenu != bluetoothMenu }
        let wifiMenu = wifiMenuItem?.submenu
        let websiteMenuItem = statusMenu.items.first { $0.action == #selector(websiteClicked(_:)) }
        let quitMenuItem = statusMenu.items.first { $0.action == #selector(quitClicked(_:)) }
        let btSleepHeader = bluetoothMenu?.items.first
        let btUnlockHeader = bluetoothMenu?.items.first { !$0.isEnabled && $0 != btSleepHeader && !$0.isSeparatorItem }
        let wifiUnlockHeader = wifiMenu?.items.first { !$0.isEnabled && !$0.isSeparatorItem }

        bluetoothMenuItem?.setAccessibilityIdentifier("AppDelegate.bluetoothMenuItem")
        btSleepHeader?.setAccessibilityIdentifier("AppDelegate.bluetoothSleepActionHeaderMenuItem")
        disableBluetoothOnPowerDownMenuItem?.setAccessibilityIdentifier(
            "AppDelegate.disableBluetoothOnPowerDownMenuItem"
        )
        disconnectBluetoothDevicesOnPowerDownMenuItem?.setAccessibilityIdentifier(
            "AppDelegate.disconnectBluetoothDevicesOnPowerDownMenuItem"
        )
        btUnlockHeader?.setAccessibilityIdentifier("AppDelegate.bluetoothUnlockActionHeaderMenuItem")
        bluetoothActionOnScreenUnlockRestore?.setAccessibilityIdentifier(
            "AppDelegate.bluetoothActionOnScreenUnlockRestore"
        )
        bluetoothActionOnScreenUnlockEnable?.setAccessibilityIdentifier(
            "AppDelegate.bluetoothActionOnScreenUnlockEnable"
        )
        bluetoothActionOnScreenUnlockNothing?.setAccessibilityIdentifier(
            "AppDelegate.bluetoothActionOnScreenUnlockNothing"
        )

        wifiMenuItem?.setAccessibilityIdentifier("AppDelegate.wifiMenuItem")
        disableWifiOnPowerDownMenuItem?.setAccessibilityIdentifier("AppDelegate.disableWifiOnPowerDownMenuItem")
        wifiUnlockHeader?.setAccessibilityIdentifier("AppDelegate.wifiUnlockActionHeaderMenuItem")
        wifiActionOnScreenUnlockRestore?.setAccessibilityIdentifier("AppDelegate.wifiActionOnScreenUnlockRestore")
        wifiActionOnScreenUnlockEnable?.setAccessibilityIdentifier("AppDelegate.wifiActionOnScreenUnlockEnable")
        wifiActionOnScreenUnlockNothing?.setAccessibilityIdentifier("AppDelegate.wifiActionOnScreenUnlockNothing")

        hideIconMenuItem?.setAccessibilityHelp(NSLocalizedString(
            "Hides the menu bar icon. Launch the app again to show it.",
            tableName: "Accessibility",
            comment: "Accessibility hint for the Hide icon menu item"
        ))
        hideIconMenuItem?.setAccessibilityIdentifier("AppDelegate.hideIconMenuItem")

        websiteMenuItem?.setAccessibilityIdentifier("AppDelegate.websiteMenuItem")
        quitMenuItem?.setAccessibilityIdentifier("AppDelegate.quitMenuItem")
    }
}
