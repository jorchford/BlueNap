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

        let isConnected = deviceInfo.isConnected
        let statusImage = NSImage(size: NSSize(width: 10, height: 10), flipped: false) { rect in
            let circleRect = rect.insetBy(dx: 1.5, dy: 1.5)
            let path = NSBezierPath(ovalIn: circleRect)
            if isConnected {
                NSColor.systemGreen.setFill()
                path.fill()
            } else {
                NSColor.secondaryLabelColor.withAlphaComponent(0.55).setStroke()
                path.lineWidth = 1.2
                path.stroke()
            }
            return true
        }
        statusImage.accessibilityDescription = deviceInfo.category.displayName
        image = statusImage

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
