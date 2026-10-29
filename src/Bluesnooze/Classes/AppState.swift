//
//  AppState.swift
//  Bluesnooze
//
//  Created on 2026-10-20.
//

import Foundation
import Observation

enum BluesnoozeStatus: Equatable, Sendable {
    case active
    case snoozing(devicesCount: Int)
    case transitioning(message: String)

    var displayText: String {
        switch self {
        case .active:
            NSLocalizedString("Active", comment: "")
        case let .snoozing(count):
            if count > 0 {
                String(format: NSLocalizedString("Snoozing (%d devices)", comment: ""), count)
            } else {
                NSLocalizedString("Snoozing Bluetooth", comment: "")
            }
        case let .transitioning(message):
            message
        }
    }

    var menuTitle: String {
        switch self {
        case .active:
            NSLocalizedString("BlueNap: Active", comment: "")
        case .snoozing:
            NSLocalizedString("BlueNap: Snoozing (Mac asleep)", comment: "")
        case let .transitioning(message):
            String(format: NSLocalizedString("BlueNap: %@", comment: ""), message)
        }
    }
}

@Observable
@MainActor
final class AppState {
    static let shared = AppState()

    var status: BluesnoozeStatus = .active
    var isBluetoothHardwareOn: Bool = true
    var isWifiHardwareOn: Bool = true
    var pairedDevices: [BluetoothDeviceInfo] = []
    var isRefreshing: Bool = false

    private init() {}

    /// Synchronously query hardware states without blocking the UI
    func refreshHardwareStates() {
        isRefreshing = true
        defer { isRefreshing = false }

        if CommandLine.arguments.contains("--demo") {
            isBluetoothHardwareOn = true
            isWifiHardwareOn = true
            pairedDevices = [
                BluetoothDeviceInfo(id: "A8-66-7F-3B-21-9C", name: "AirPods Pro (2nd Gen)", address: "A8-66-7F-3B-21-9C", isConnected: true, isPaired: true, category: .audio, isInputDevice: false),
                BluetoothDeviceInfo(id: "70-26-05-8A-1F-E4", name: "Wireless Headset", address: "70-26-05-8A-1F-E4", isConnected: false, isPaired: true, category: .audio, isInputDevice: false),
                BluetoothDeviceInfo(id: "F0-18-98-52-A1-03", name: "Magic Keyboard", address: "F0-18-98-52-A1-03", isConnected: true, isPaired: true, category: .input, isInputDevice: true)
            ]
            return
        }

        isBluetoothHardwareOn = BluetoothService.shared.isPowerOn()
        isWifiHardwareOn = WiFiService.shared.isPowerOn() ?? false
        pairedDevices = BluetoothService.shared.getPairedDevices()
    }
}
