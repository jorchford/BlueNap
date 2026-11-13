//
//  AppDelegate+MenuBuilder.swift
//  BlueNap
//
//  Created on 2026-11-12.
//

import Cocoa

extension AppDelegate {
    func buildStatusMenuIfNeeded() {
        guard statusMenu == nil else { return }

        let menu = NSMenu()
        menu.delegate = self

        let btMenu = buildBluetoothSubmenu()
        bluetoothMenu = btMenu
        let btTopItem = NSMenuItem(title: NSLocalizedString("Bluetooth", comment: ""), action: nil, keyEquivalent: "")
        btTopItem.submenu = btMenu
        menu.addItem(btTopItem)

        let wifiMenu = buildWiFiSubmenu()
        let wifiTopItem = NSMenuItem(title: NSLocalizedString("Wi-Fi", comment: ""), action: nil, keyEquivalent: "")
        wifiTopItem.submenu = wifiMenu
        menu.addItem(wifiTopItem)

        appendGeneralMenuItems(to: menu)

        statusMenu = menu
        setupLanguageMenuIfNeeded()
        ensureMenuItemOrder()
        setupAccessibility()
    }

    private func buildBluetoothSubmenu() -> NSMenu {
        let btMenu = NSMenu(title: NSLocalizedString("Bluetooth", comment: ""))
        btMenu.autoenablesItems = false
        setupBluetoothSleepItems(in: btMenu)
        btMenu.addItem(.separator())
        setupBluetoothWakeItems(in: btMenu)
        return btMenu
    }

    private func setupBluetoothSleepItems(in btMenu: NSMenu) {
        let btSleepHeader = NSMenuItem(
            title: NSLocalizedString("Action when sleeping", comment: ""),
            action: nil,
            keyEquivalent: ""
        )
        btSleepHeader.isEnabled = false
        btMenu.addItem(btSleepHeader)

        disableBluetoothOnPowerDownMenuItem = makeIndentedItem(
            title: NSLocalizedString("Turn off Bluetooth", comment: ""),
            action: #selector(disableBluetoothOnPowerDownClicked(_:)),
            in: btMenu
        )
        disconnectBluetoothDevicesOnPowerDownMenuItem = makeIndentedItem(
            title: NSLocalizedString("Disconnect selected devices", comment: ""),
            action: #selector(disconnectBluetoothDevicesOnPowerDownClicked(_:)),
            in: btMenu
        )

        let listStart = NSMenuItem(title: "Device list start", action: nil, keyEquivalent: "")
        listStart.isHidden = true
        listStart.indentationLevel = 2
        btMenu.addItem(listStart)
        bluetoothDeviceListStart = listStart

        let listEnd = NSMenuItem(title: "Device list end", action: nil, keyEquivalent: "")
        listEnd.isHidden = true
        listEnd.indentationLevel = 2
        btMenu.addItem(listEnd)
        bluetoothDeviceListEnd = listEnd
    }

    private func setupBluetoothWakeItems(in btMenu: NSMenu) {
        let btUnlockHeader = NSMenuItem(
            title: NSLocalizedString("Action when unlocked", comment: ""),
            action: nil,
            keyEquivalent: ""
        )
        btUnlockHeader.isEnabled = false
        btMenu.addItem(btUnlockHeader)

        bluetoothActionOnScreenUnlockRestore = makeIndentedItem(
            title: NSLocalizedString("Restore previous state", comment: ""),
            action: #selector(bluetoothActionOnScreenUnlockRestoreClicked(_:)),
            in: btMenu
        )
        bluetoothActionOnScreenUnlockEnable = makeIndentedItem(
            title: NSLocalizedString("Always enable", comment: ""),
            action: #selector(bluetoothActionOnScreenUnlockEnableClicked(_:)),
            in: btMenu
        )
        bluetoothActionOnScreenUnlockNothing = makeIndentedItem(
            title: NSLocalizedString("Do nothing", comment: ""),
            action: #selector(bluetoothActionOnScreenUnlockNothingClicked(_:)),
            in: btMenu
        )
    }

    private func buildWiFiSubmenu() -> NSMenu {
        let wifiMenu = NSMenu(title: NSLocalizedString("Wi-Fi", comment: ""))
        wifiMenu.autoenablesItems = false

        disableWifiOnPowerDownMenuItem = makeIndentedItem(
            title: NSLocalizedString("Turn off when sleeping", comment: ""),
            action: #selector(disableWifiOnPowerDownClicked(_:)),
            level: 0,
            in: wifiMenu
        )
        wifiMenu.addItem(.separator())

        let wifiUnlockHeader = NSMenuItem(
            title: NSLocalizedString("Action when unlocked:", comment: ""),
            action: nil,
            keyEquivalent: ""
        )
        wifiUnlockHeader.isEnabled = false
        wifiMenu.addItem(wifiUnlockHeader)

        wifiActionOnScreenUnlockRestore = makeIndentedItem(
            title: NSLocalizedString("Restore previous state", comment: ""),
            action: #selector(wifiActionOnScreenUnlockRestoreClicked(_:)),
            level: 0,
            in: wifiMenu
        )
        wifiActionOnScreenUnlockEnable = makeIndentedItem(
            title: NSLocalizedString("Always enable", comment: ""),
            action: #selector(wifiActionOnScreenUnlockEnableClicked(_:)),
            level: 0,
            in: wifiMenu
        )
        wifiActionOnScreenUnlockNothing = makeIndentedItem(
            title: NSLocalizedString("Do nothing", comment: ""),
            action: #selector(wifiActionOnScreenUnlockNothingClicked(_:)),
            level: 0,
            in: wifiMenu
        )
        return wifiMenu
    }

    private func appendGeneralMenuItems(to menu: NSMenu) {
        let prefsItem = NSMenuItem(
            title: NSLocalizedString("Preferences…", comment: ""),
            action: #selector(openPreferencesClicked(_:)),
            keyEquivalent: ","
        )
        prefsItem.target = self
        menu.addItem(prefsItem)

        let webItem = NSMenuItem(
            title: NSLocalizedString("Website", comment: ""),
            action: #selector(websiteClicked(_:)),
            keyEquivalent: ""
        )
        webItem.target = self
        menu.addItem(webItem)

        menu.addItem(.separator())

        let hideItem = NSMenuItem(
            title: NSLocalizedString("Exit to Background", comment: ""),
            action: #selector(hideIconClicked(_:)),
            keyEquivalent: ""
        )
        hideItem.target = self
        menu.addItem(hideItem)
        hideIconMenuItem = hideItem

        let quitItem = NSMenuItem(
            title: NSLocalizedString("Quit", comment: ""),
            action: #selector(quitClicked(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func makeIndentedItem(
        title: String,
        action: Selector,
        level: Int = 1,
        in menu: NSMenu
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.indentationLevel = level
        menu.addItem(item)
        return item
    }

    func teardownStatusMenu() {
        clearBluetoothDeviceList()
        statusMenu?.removeAllItems()
        bluetoothMenu?.removeAllItems()
        languageMenu?.removeAllItems()
        statusMenu = nil
        bluetoothMenu = nil
        languageMenu = nil
        languageMenuItem = nil
        disableBluetoothOnPowerDownMenuItem = nil
        disconnectBluetoothDevicesOnPowerDownMenuItem = nil
        bluetoothActionOnScreenUnlockRestore = nil
        bluetoothActionOnScreenUnlockEnable = nil
        bluetoothActionOnScreenUnlockNothing = nil
        bluetoothDeviceListStart = nil
        bluetoothDeviceListEnd = nil
        disableWifiOnPowerDownMenuItem = nil
        wifiActionOnScreenUnlockRestore = nil
        wifiActionOnScreenUnlockEnable = nil
        wifiActionOnScreenUnlockNothing = nil
        hideIconMenuItem = nil
    }

    func setupLanguageMenuIfNeeded() {
        guard let statusMenu else { return }

        if let existing = languageMenuItem, statusMenu.items.contains(existing) {
            updateLanguageMenuStates()
            return
        }

        let langMenu = NSMenu(title: NSLocalizedString("Language", comment: ""))
        for lang in AppLanguage.allCases {
            let item = NSMenuItem(
                title: lang.displayName,
                action: #selector(languageMenuItemClicked(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = lang.rawValue
            langMenu.addItem(item)
        }

        let mainItem = NSMenuItem(
            title: NSLocalizedString("Language", comment: ""),
            action: nil,
            keyEquivalent: ""
        )
        mainItem.submenu = langMenu

        if let prefIndex = statusMenu.items.firstIndex(where: { $0.action == #selector(openPreferencesClicked(_:)) }) {
            statusMenu.insertItem(mainItem, at: prefIndex + 1)
        } else {
            statusMenu.addItem(mainItem)
        }

        languageMenu = langMenu
        languageMenuItem = mainItem
        ensureMenuItemOrder()
        updateLanguageMenuStates()
    }

    func ensureMenuItemOrder() {
        guard let statusMenu, let hideItem = hideIconMenuItem else { return }

        if let currentIdx = statusMenu.items.firstIndex(of: hideItem) {
            statusMenu.removeItem(at: currentIdx)
        }

        guard let quitIndex = statusMenu.items.firstIndex(where: { $0.action == #selector(quitClicked(_:)) }) else {
            return
        }

        let itemAbove = quitIndex > 0 ? statusMenu.items[quitIndex - 1] : nil
        if itemAbove?.isSeparatorItem != true {
            statusMenu.insertItem(NSMenuItem.separator(), at: quitIndex)
        }

        if let targetQuitIndex = statusMenu.items.firstIndex(where: { $0.action == #selector(quitClicked(_:)) }) {
            statusMenu.insertItem(hideItem, at: targetQuitIndex)
        }
    }

    func updateLanguageMenuStates() {
        guard let languageMenu else { return }
        let currentLang = activePreferences.appLanguage
        for item in languageMenu.items {
            if let rawValue = item.representedObject as? String,
               let lang = AppLanguage(rawValue: rawValue) {
                item.state = (lang == currentLang) ? .on : .off
            }
        }
    }

    func localizeMenuTitles() {
        guard let statusMenu else { return }

        setupLanguageMenuIfNeeded()
        ensureMenuItemOrder()
        updateLanguageMenuStates()
        localizeTopLevelMenuItems(in: statusMenu)
        localizeSubmenuHeaders(in: statusMenu)
        localizeActionMenuItems()
        updateStatusItemTooltip()
    }

    private func localizeTopLevelMenuItems(in statusMenu: NSMenu) {
        for item in statusMenu.items {
            if item.submenu == bluetoothMenu {
                item.title = NSLocalizedString("Bluetooth", comment: "")
                bluetoothMenu?.title = NSLocalizedString("Bluetooth", comment: "")
            } else if item == languageMenuItem || item.submenu == languageMenu {
                item.title = NSLocalizedString("Language", comment: "")
                languageMenu?.title = NSLocalizedString("Language", comment: "")
            } else if item.submenu != nil {
                item.title = NSLocalizedString("Wi-Fi", comment: "")
                item.submenu?.title = NSLocalizedString("Wi-Fi", comment: "")
            } else if item.action == #selector(openPreferencesClicked(_:)) {
                item.title = NSLocalizedString("Preferences…", comment: "")
            } else if item == hideIconMenuItem {
                item.title = activePreferences.hideIcon
                    ? NSLocalizedString("Show icon", comment: "")
                    : NSLocalizedString("Exit to Background", comment: "")
                item.toolTip = NSLocalizedString("Exit to Background Description", comment: "")
            } else if item.action == #selector(websiteClicked(_:)) {
                item.title = NSLocalizedString("Website", comment: "")
                let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.4"
                item.toolTip = "BlueNap v\(version)"
            } else if item.action == #selector(quitClicked(_:)) {
                item.title = NSLocalizedString("Quit", comment: "")
            } else if !item.isSeparatorItem, !item.title.isEmpty {
                localizeMenuItem(item)
            }
        }
    }

    private func localizeSubmenuHeaders(in statusMenu: NSMenu) {
        if let items = bluetoothMenu?.items {
            items.first?.title = NSLocalizedString("Action when sleeping", comment: "")
            if let unlockHeader = items.first(where: { !$0.isEnabled && $0 != items.first && !$0.isSeparatorItem }) {
                unlockHeader.title = NSLocalizedString("Action when unlocked", comment: "")
            }
        }

        let wifiTop = statusMenu.items.first {
            $0.submenu != nil && $0.submenu != bluetoothMenu && $0.submenu != languageMenu
        }
        if let subItems = wifiTop?.submenu?.items {
            for sub in subItems where sub.action == nil && !sub.isSeparatorItem && !sub.title.isEmpty {
                sub.title = NSLocalizedString("Action when unlocked:", comment: "")
            }
        }
    }

    private func localizeActionMenuItems() {
        disableBluetoothOnPowerDownMenuItem?.title = NSLocalizedString("Turn off Bluetooth", comment: "")
        disconnectBluetoothDevicesOnPowerDownMenuItem?.title = NSLocalizedString(
            "Disconnect selected devices",
            comment: ""
        )
        bluetoothActionOnScreenUnlockRestore?.title = NSLocalizedString("Restore previous state", comment: "")
        bluetoothActionOnScreenUnlockEnable?.title = NSLocalizedString("Always enable", comment: "")
        bluetoothActionOnScreenUnlockNothing?.title = NSLocalizedString("Do nothing", comment: "")

        disableWifiOnPowerDownMenuItem?.title = NSLocalizedString("Turn off when sleeping", comment: "")
        wifiActionOnScreenUnlockRestore?.title = NSLocalizedString("Restore previous state", comment: "")
        wifiActionOnScreenUnlockEnable?.title = NSLocalizedString("Always enable", comment: "")
        wifiActionOnScreenUnlockNothing?.title = NSLocalizedString("Do nothing", comment: "")
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
}
