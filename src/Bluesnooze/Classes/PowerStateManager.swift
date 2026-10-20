//
//  PowerStateManager.swift
//  Bluesnooze
//
//  Created on 2026-10-18.
//

import Foundation
import os

@MainActor
final class PowerStateManager {
    static let shared = PowerStateManager()

    // MARK: - Internal State

    private(set) var isSystemSleeping: Bool = false
    private(set) var prevBluetoothState: Bool = true
    private(set) var prevWifiState: Bool = false
    private(set) var prevConnectedDevices: [String: Bool] = [:]

    private var lastWakeTimestamp: Date = .distantPast
    private let wakeDebounceInterval: TimeInterval = 1.0

    private let preferences: Preferences
    private let bluetoothService: BluetoothService
    private let wifiService: WiFiService
    private let appState: AppState

    init(
        preferences: Preferences = .shared,
        bluetoothService: BluetoothService = .shared,
        wifiService: WiFiService = .shared,
        appState: AppState = .shared
    ) {
        self.preferences = preferences
        self.bluetoothService = bluetoothService
        self.wifiService = wifiService
        self.appState = appState
    }

    // MARK: - Power Down (Sleep / Power Off)

    /// Synchronously handles the sleep transition before the kernel suspends
    func handlePowerDown() {
        Log.power.notice("Power down / sleep sequence initiated")

        // 1. Capture current hardware states before modifying
        let currentBtOn = bluetoothService.isPowerOn()
        let currentWifiOn = wifiService.isPowerOn() ?? false
        prevBluetoothState = currentBtOn
        prevWifiState = currentWifiOn

        var connectedStates: [String: Bool] = [:]
        if preferences.disconnectDevicesOnSleep {
            let targets = preferences.bluetoothDevicesToDisconnect
            for addr in targets {
                let isConn = bluetoothService.isDeviceConnected(address: addr)
                connectedStates[addr] = isConn
            }
        }
        prevConnectedDevices = connectedStates

        Log.power.info("Saved hardware states - Bluetooth: \(currentBtOn), Wi-Fi: \(currentWifiOn)")

        // 2. Execute configured sleep actions
        var disconnectedCount = 0
        if preferences.disableBluetoothOnSleep {
            // Safety guard: If an active Bluetooth mouse/keyboard is connected, warn in logs
            if bluetoothService.hasConnectedInputDevice() {
                Log.power.warning("Notice: Bluetooth input device connected while disabling Bluetooth on sleep")
            }
            appState.status = .transitioning(message: "Turning off Bluetooth...")
            bluetoothService.setPower(on: false)
            appState.status = .snoozing(devicesCount: 0)
        } else if preferences.disconnectDevicesOnSleep {
            let targets = preferences.bluetoothDevicesToDisconnect
            appState.status = .transitioning(message: "Disconnecting accessories...")
            for addr in targets {
                let wasConnected = connectedStates[addr] ?? false
                if wasConnected {
                    bluetoothService.disconnectDevice(address: addr)
                    disconnectedCount += 1
                }
            }
            appState.status = .snoozing(devicesCount: disconnectedCount)
        }

        if preferences.disableWifiOnSleep {
            wifiService.setPower(on: false)
        }

        // 3. Mark system as sleeping
        isSystemSleeping = true
        appState.isBluetoothHardwareOn = !preferences.disableBluetoothOnSleep && currentBtOn
        appState.isWifiHardwareOn = !preferences.disableWifiOnSleep && currentWifiOn
    }

    // MARK: - User Wake / Screen Unlock

    func handleUserWake(source: String) {
        let now = Date()
        guard now.timeIntervalSince(lastWakeTimestamp) > wakeDebounceInterval else {
            Log.power.debug("Debouncing wake trigger from \(source, privacy: .public)")
            return
        }

        // Only restore states if the system was actively in sleep mode.
        guard isSystemSleeping else {
            Log.power.debug("Wake event from \(source, privacy: .public) received, but not sleeping. Ignoring.")
            return
        }

        Log.power.notice("User wake validated via \(source, privacy: .public). Restoring network states.")
        lastWakeTimestamp = now
        isSystemSleeping = false

        appState.status = .transitioning(message: "Restoring connections...")

        // 1. Immediately restore hardware power states (allows Bluetooth mice/keyboards to reconnect instantly)
        restoreBluetoothPowerState()
        restoreWifiPowerState()

        // 2. Reconnect accessories asynchronously if selective disconnect was used
        Task { @MainActor in
            await reconnectAccessoriesIfNeeded()
            appState.status = .active
            appState.refreshHardwareStates()
        }
    }

    private func restoreBluetoothPowerState() {
        let btAction = preferences.bluetoothWakeAction
        switch btAction {
        case .enable:
            bluetoothService.setPower(on: true)
        case .restore:
            if prevBluetoothState {
                bluetoothService.setPower(on: true)
            }
        case .nothing:
            break
        }
    }

    private func restoreWifiPowerState() {
        let wifiAction = preferences.wifiWakeAction
        switch wifiAction {
        case .enable:
            wifiService.setPower(on: true)
        case .restore:
            if prevWifiState {
                wifiService.setPower(on: true)
            }
        case .nothing:
            break
        }
    }

    private func reconnectAccessoriesIfNeeded() async {
        guard preferences.disconnectDevicesOnSleep else { return }

        // Allow controller a brief moment to stabilize
        try? await Task.sleep(nanoseconds: 400_000_000)

        for address in preferences.bluetoothDevicesToDisconnect {
            let wasConnected = prevConnectedDevices[address] ?? false
            if preferences.bluetoothWakeAction == .enable || wasConnected {
                await bluetoothService.connectDevice(address: address, maxRetries: 2)
            }
        }
    }

    // MARK: - Testing Hooks

    #if DEBUG
        func resetForTesting(sleeping: Bool, prevBT: Bool, prevWifi: Bool) {
            isSystemSleeping = sleeping
            prevBluetoothState = prevBT
            prevWifiState = prevWifi
            lastWakeTimestamp = Date.distantPast
        }
    #endif
}
