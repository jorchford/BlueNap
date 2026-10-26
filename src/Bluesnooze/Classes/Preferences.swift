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

enum AutoHideDelayOption: Int, CaseIterable, Identifiable, Sendable {
    case never = 0
    case oneMinute = 1
    case twoMinutes = 2
    case threeMinutes = 3
    case fiveMinutes = 5
    case tenMinutes = 10
    case fifteenMinutes = 15

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .never:
            NSLocalizedString("Never", comment: "")
        case .oneMinute:
            NSLocalizedString("1 Minute", comment: "")
        case .twoMinutes:
            NSLocalizedString("2 Minutes", comment: "")
        case .threeMinutes:
            NSLocalizedString("3 Minutes", comment: "")
        case .fiveMinutes:
            NSLocalizedString("5 Minutes", comment: "")
        case .tenMinutes:
            NSLocalizedString("10 Minutes", comment: "")
        case .fifteenMinutes:
            NSLocalizedString("15 Minutes", comment: "")
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
        static let isAutoWiFiBindingEnabled = "isAutoWiFiBindingEnabled"
        static let autoHideMenuBarDelayMinutes = "autoHideMenuBarDelayMinutes"
    }

    private let defaults: UserDefaults

    /// In-memory cached properties for zero-IPC and O(1) reads
    var appLanguage: AppLanguage {
        get { AppLanguage.current }
        set {
            AppLanguage.current = newValue
            AppDelegate.shared?.localizeMenuTitles()
        }
    }

    var autoHideMenuBarDelayMinutes: Int {
        didSet { defaults.set(autoHideMenuBarDelayMinutes, forKey: Keys.autoHideMenuBarDelayMinutes) }
    }
    var isAutoWiFiBindingEnabled: Bool {
        didSet { defaults.set(isAutoWiFiBindingEnabled, forKey: Keys.isAutoWiFiBindingEnabled) }
    }

    var disableBluetoothOnSleep: Bool {
        didSet { defaults.set(disableBluetoothOnSleep, forKey: Keys.disableBluetoothOnPowerDown) }
    }

    var disconnectDevicesOnSleep: Bool {
        didSet { defaults.set(disconnectDevicesOnSleep, forKey: Keys.disconnectBluetoothDevicesOnPowerDown) }
    }

    var bluetoothDevicesToDisconnect: [String] {
        didSet { defaults.set(bluetoothDevicesToDisconnect, forKey: Keys.bluetoothDevicesToDisconnectOnPowerDown) }
    }

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

        defaults.register(defaults: [
            Keys.hideIcon: false,
            Keys.showTransitionAnimation: true,
            Keys.isAutoWiFiBindingEnabled: true,
            Keys.disableBluetoothOnPowerDown: true,
            Keys.autoHideMenuBarDelayMinutes: 0
        ])

        if defaults.object(forKey: Keys.disableBluetoothOnPowerDown) == nil {
            disableBluetoothOnSleep = true
        } else {
            disableBluetoothOnSleep = defaults.bool(forKey: Keys.disableBluetoothOnPowerDown)
        }

        disconnectDevicesOnSleep = defaults.bool(forKey: Keys.disconnectBluetoothDevicesOnPowerDown)
        bluetoothDevicesToDisconnect = defaults.stringArray(forKey: Keys.bluetoothDevicesToDisconnectOnPowerDown) ?? []

        let btRaw = defaults.string(forKey: Keys.bluetoothActionOnScreenUnlock)
        bluetoothWakeAction = btRaw.flatMap(WakeAction.init) ?? .restore

        disableWifiOnSleep = defaults.bool(forKey: Keys.disableWifiOnPowerDown)

        let wifiRaw = defaults.string(forKey: Keys.wifiActionOnScreenUnlock)
        wifiWakeAction = wifiRaw.flatMap(WakeAction.init) ?? .nothing

        hideIcon = defaults.bool(forKey: Keys.hideIcon)
        autoHideMenuBarDelayMinutes = defaults.integer(forKey: Keys.autoHideMenuBarDelayMinutes)

        if defaults.object(forKey: Keys.isAutoWiFiBindingEnabled) == nil {
            isAutoWiFiBindingEnabled = true
        } else {
            isAutoWiFiBindingEnabled = defaults.bool(forKey: Keys.isAutoWiFiBindingEnabled)
        }

        if defaults.object(forKey: Keys.showTransitionAnimation) == nil {
            showTransitionAnimation = true
        } else {
            showTransitionAnimation = defaults.bool(forKey: Keys.showTransitionAnimation)
        }
    }

    func isDeviceMarkedForDisconnect(address: String) -> Bool {
        bluetoothDevicesToDisconnect.contains(address)
    }

    func setDeviceMarkedForDisconnect(address: String, disconnect: Bool) {
        var devices = bluetoothDevicesToDisconnect
        if disconnect {
            if !devices.contains(address) {
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
            Keys.showTransitionAnimation,
            Keys.isAutoWiFiBindingEnabled,
            Keys.autoHideMenuBarDelayMinutes
        ]
        for key in keys {
            defaults.removeObject(forKey: key)
        }

        disableBluetoothOnSleep = true
        disconnectDevicesOnSleep = false
        bluetoothDevicesToDisconnect = []
        bluetoothWakeAction = .restore
        disableWifiOnSleep = false
        wifiWakeAction = .nothing
        hideIcon = false
        showTransitionAnimation = true
        isAutoWiFiBindingEnabled = true
        autoHideMenuBarDelayMinutes = 0
        appLanguage = .system
    }
}
