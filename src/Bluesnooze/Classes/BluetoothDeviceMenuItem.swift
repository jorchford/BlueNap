//
//  BluetoothDeviceMenuItem.swift
//  Bluesnooze
//
//  Created on 2026-10-18.
//

import Cocoa

@MainActor
final class BluetoothDeviceMenuItem: NSMenuItem {
    let deviceAddressString: String

    init(deviceInfo: BluetoothDeviceInfo, action selector: Selector?, keyEquivalent charCode: String = "") {
        deviceAddressString = deviceInfo.address

        let connectionSuffix = deviceInfo.isConnected ? NSLocalizedString(" (Connected)", comment: "") : ""
        super.init(title: "\(deviceInfo.name)\(connectionSuffix)", action: selector, keyEquivalent: charCode)

        if let symbolImage = NSImage(
            systemSymbolName: deviceInfo.sfSymbolName,
            accessibilityDescription: deviceInfo.category.displayName
        ) {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            image = symbolImage.withSymbolConfiguration(config)
        }

        let addressLabel = NSLocalizedString("Address", comment: "")
        let categoryLabel = NSLocalizedString("Category", comment: "")
        toolTip = "\(deviceInfo.name)\n\(addressLabel): \(deviceInfo.address)\n\(categoryLabel): \(deviceInfo.category.displayName)"

        setAccessibilityHelp(NSLocalizedString(
            "Disconnects this device when the Mac goes to sleep.",
            tableName: "Accessibility",
            comment: "Accessibility hint for a paired Bluetooth device menu item"
        ))
        setAccessibilityIdentifier("BluetoothDeviceMenuItem.deviceMenuItem")
    }

    required init(coder: NSCoder) {
        deviceAddressString = coder.decodeObject(forKey: "deviceAddressString") as? String ?? ""
        super.init(coder: coder)
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(deviceAddressString, forKey: "deviceAddressString")
    }
}
