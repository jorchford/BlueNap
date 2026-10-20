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

        isBluetoothHardwareOn = BluetoothService.shared.isPowerOn()
        isWifiHardwareOn = WiFiService.shared.isPowerOn() ?? false
        pairedDevices = BluetoothService.shared.getPairedDevices()
    }
}
