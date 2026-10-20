//
//  BluetoothDeviceInfo.swift
//  Bluesnooze
//
//  Created on 2026-10-20.
//

import Foundation

enum BluetoothDeviceCategory: String, Sendable, CaseIterable {
    case audio
    case input
    case phone
    case computer
    case other

    var sfSymbolName: String {
        switch self {
        case .audio:
            "headphones"
        case .input:
            "computermouse"
        case .phone:
            "iphone"
        case .computer:
            "laptopcomputer"
        case .other:
            "wave.3.right.circle"
        }
    }

    var displayName: String {
        switch self {
        case .audio:
            NSLocalizedString("Audio / Headset", comment: "")
        case .input:
            NSLocalizedString("Input Device", comment: "")
        case .phone:
            NSLocalizedString("Phone / Tablet", comment: "")
        case .computer:
            NSLocalizedString("Computer", comment: "")
        case .other:
            NSLocalizedString("Bluetooth Accessory", comment: "")
        }
    }
}

struct BluetoothDeviceInfo: Identifiable, Sendable, Hashable, Equatable {
    let id: String // MAC Address (e.g. "38-fb-a0-1a-d8-fe")
    let name: String
    let address: String
    let isConnected: Bool
    let isPaired: Bool
    let category: BluetoothDeviceCategory
    let isInputDevice: Bool
    let sfSymbolName: String

    init(
        id: String,
        name: String,
        address: String,
        isConnected: Bool,
        isPaired: Bool,
        category: BluetoothDeviceCategory,
        isInputDevice: Bool
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.isConnected = isConnected
        self.isPaired = isPaired
        self.category = category
        self.isInputDevice = isInputDevice

        let lowerName = name.lowercased()
        if lowerName.contains("mouse") {
            sfSymbolName = "computermouse"
        } else if lowerName.contains("keyboard") {
            sfSymbolName = "keyboard"
        } else if lowerName.contains("trackpad") {
            sfSymbolName = "trackpad"
        } else if lowerName.contains("airpod") || lowerName.contains("earbud") || lowerName.contains("buds") {
            sfSymbolName = "airpodspro"
        } else if lowerName.contains("speaker") || lowerName.contains("sound") {
            sfSymbolName = "speaker.wave.2"
        } else {
            sfSymbolName = category.sfSymbolName
        }
    }
}
