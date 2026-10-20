//
//  Preferences.swift
//  Bluesnooze
//
//  Created on 2026-10-18.
//

import Foundation
import Observation

enum WakeAction: String, CaseIterable, Sendable {
    case restore
    case enable
    case nothing

    var displayName: String {
        switch self {
        case .restore:
            NSLocalizedString("Restore previous state", comment: "")
        case .enable:
            NSLocalizedString("Always enable", comment: "")
        case .nothing:
            NSLocalizedString("Do nothing", comment: "")
        }
    }
}

@Observable
@MainActor
final class Preferences {
    static let shared = Preferences()

    private enum Keys {
        static let disableBluetoothOnPowerDown = "disableBluetoothOnPowerDown"
        static let disconnectBluetoothDevicesOnPowerDown = "disconnectBluetoothDevicesOnPowerDown"
        static let bluetoothDevicesToDisconnectOnPowerDown = "bluetoothDevicesToDisconnectOnPowerDown"
        static let bluetoothActionOnScreenUnlock = "bluetoothActionOnScreenUnlock"
        static let disableWifiOnPowerDown = "disableWifiOnPowerDown"
        static let wifiActionOnScreenUnlock = "wifiActionOnScreenUnlock"
        static let hideIcon = "hideIcon"
        static let showTransitionAnimation = "showTransitionAnimation"
    }

    private let defaults: UserDefaults

    /// In-memory cached properties for zero-IPC and O(1) reads
    var disableBluetoothOnSleep: Bool {
        didSet { defaults.set(disableBluetoothOnSleep, forKey: Keys.disableBluetoothOnPowerDown) }
    }

    var disconnectDevicesOnSleep: Bool {
        didSet { defaults.set(disconnectDevicesOnSleep, forKey: Keys.disconnectBluetoothDevicesOnPowerDown) }
    }

    var bluetoothDevicesToDisconnect: [String] {
        didSet {
            disconnectSet = Set(bluetoothDevicesToDisconnect)
            defaults.set(bluetoothDevicesToDisconnect, forKey: Keys.bluetoothDevicesToDisconnectOnPowerDown)
        }
    }

    @ObservationIgnored
    private var disconnectSet: Set<String>

    var bluetoothWakeAction: WakeAction {
        didSet { defaults.set(bluetoothWakeAction.rawValue, forKey: Keys.bluetoothActionOnScreenUnlock) }
    }

    var disableWifiOnSleep: Bool {
        didSet { defaults.set(disableWifiOnSleep, forKey: Keys.disableWifiOnPowerDown) }
    }

    var wifiWakeAction: WakeAction {
        didSet { defaults.set(wifiWakeAction.rawValue, forKey: Keys.wifiActionOnScreenUnlock) }
    }

    var hideIcon: Bool {
        didSet { defaults.set(hideIcon, forKey: Keys.hideIcon) }
    }

    var showMenuBarIcon: Bool {
        get { !hideIcon }
        set { hideIcon = !newValue }
    }

    var showTransitionAnimation: Bool {
        didSet { defaults.set(showTransitionAnimation, forKey: Keys.showTransitionAnimation) }
    }

    var isBluetoothSleepActionActive: Bool {
        disableBluetoothOnSleep || disconnectDevicesOnSleep
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if defaults.object(forKey: Keys.disableBluetoothOnPowerDown) == nil {
            disableBluetoothOnSleep = true
        } else {
            disableBluetoothOnSleep = defaults.bool(forKey: Keys.disableBluetoothOnPowerDown)
        }

        disconnectDevicesOnSleep = defaults.bool(forKey: Keys.disconnectBluetoothDevicesOnPowerDown)

        let initialDevices = defaults.stringArray(forKey: Keys.bluetoothDevicesToDisconnectOnPowerDown) ?? []
        bluetoothDevicesToDisconnect = initialDevices
        disconnectSet = Set(initialDevices)

        let btRaw = defaults.string(forKey: Keys.bluetoothActionOnScreenUnlock)
        bluetoothWakeAction = btRaw.flatMap(WakeAction.init) ?? .restore

        disableWifiOnSleep = defaults.bool(forKey: Keys.disableWifiOnPowerDown)

        let wifiRaw = defaults.string(forKey: Keys.wifiActionOnScreenUnlock)
        wifiWakeAction = wifiRaw.flatMap(WakeAction.init) ?? .nothing

        hideIcon = defaults.bool(forKey: Keys.hideIcon)

        if defaults.object(forKey: Keys.showTransitionAnimation) == nil {
            showTransitionAnimation = true
        } else {
            showTransitionAnimation = defaults.bool(forKey: Keys.showTransitionAnimation)
        }
    }

    func isDeviceMarkedForDisconnect(address: String) -> Bool {
        disconnectSet.contains(address)
    }

    func setDeviceMarkedForDisconnect(address: String, disconnect: Bool) {
        var devices = bluetoothDevicesToDisconnect
        if disconnect {
            if !disconnectSet.contains(address) {
                devices.append(address)
            }
        } else {
            devices.removeAll { $0 == address }
        }
        bluetoothDevicesToDisconnect = devices
    }

    func resetToDefaults() {
        let keys = [
            Keys.disableBluetoothOnPowerDown,
            Keys.disconnectBluetoothDevicesOnPowerDown,
            Keys.bluetoothDevicesToDisconnectOnPowerDown,
            Keys.bluetoothActionOnScreenUnlock,
            Keys.disableWifiOnPowerDown,
            Keys.wifiActionOnScreenUnlock,
            Keys.hideIcon,
            Keys.showTransitionAnimation
        ]
        for key in keys {
            defaults.removeObject(forKey: key)
        }

        disableBluetoothOnSleep = true
        disconnectDevicesOnSleep = false
        bluetoothDevicesToDisconnect = []
        disconnectSet = []
        bluetoothWakeAction = .restore
        disableWifiOnSleep = false
        wifiWakeAction = .nothing
        hideIcon = false
        showTransitionAnimation = true
    }
}
