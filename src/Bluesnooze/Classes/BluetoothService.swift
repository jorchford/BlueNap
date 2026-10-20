//
//  BluetoothService.swift
//  Bluesnooze
//
//  Created on 2026-10-20.
//

import Foundation
import IOBluetooth
import os

@MainActor
final class BluetoothService {
    static let shared = BluetoothService()

    private init() {}

    /// Query current Bluetooth controller power state via IOBluetoothPreference
    func isPowerOn() -> Bool {
        IOBluetoothPreferenceGetControllerPowerState() != 0
    }

    /// Set Bluetooth controller power state immediately
    func setPower(on: Bool) {
        Log.bluetooth.notice("Setting Bluetooth controller power state: \(on, privacy: .public)")
        IOBluetoothPreferenceSetControllerPowerState(on ? 1 : 0)
    }

    /// Retrieve list of paired audio & peripheral devices, STRICTLY excluding input devices (mice, keyboards)
    func getPairedDevices() -> [BluetoothDeviceInfo] {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return []
        }

        return paired.compactMap { device -> BluetoothDeviceInfo? in
            guard let address = device.addressString, !address.isEmpty else { return nil }
            let name = device.nameOrAddress ?? "Unknown Device"
            let lowerName = name.lowercased()
            let major = Int(device.deviceClassMajor)

            // CRITICAL SAFETY RULE:
            // Input devices (mice, trackpads, keyboards) must NEVER be managed or disconnected by Bluesnooze!
            if isInputDevice(major: major, lowerName: lowerName) {
                return nil
            }

            let isConnected = device.isConnected()
            let isPaired = device.isPaired()
            let category = self.determineCategory(device: device, lowerName: lowerName)

            return BluetoothDeviceInfo(
                id: address,
                name: name,
                address: address,
                isConnected: isConnected,
                isPaired: isPaired,
                category: category,
                isInputDevice: false
            )
        }
    }

    /// Check connection status for a specific device address
    func isDeviceConnected(address: String) -> Bool {
        guard let device = IOBluetoothDevice(addressString: address) else { return false }
        return device.isConnected()
    }

    /// Disconnect a paired Bluetooth device safely with input device protection
    @discardableResult
    func disconnectDevice(address: String) -> Bool {
        guard let device = IOBluetoothDevice(addressString: address) else {
            Log.bluetooth.error("Invalid Bluetooth address for disconnect: \(address, privacy: .public)")
            return false
        }

        let name = device.nameOrAddress ?? "Unknown"
        let lowerName = name.lowercased()
        let major = Int(device.deviceClassMajor)

        // NEVER disconnect input devices (mice, keyboards, trackpads)
        if isInputDevice(major: major, lowerName: lowerName) {
            Log.bluetooth.warning("Safety guard: Refusing to disconnect input device: \(name) (\(address))")
            return false
        }

        Log.bluetooth.info("Disconnecting \(address, privacy: .public) (\(name, privacy: .public))")
        if device.isConnected() {
            let status = device.closeConnection()
            Log.bluetooth.info("closeConnection for \(address, privacy: .public) returned: \(status)")
            return status == kIOReturnSuccess
        }
        return true
    }

    /// Connect a paired Bluetooth device with optional retry logic
    @discardableResult
    func connectDevice(address: String, maxRetries: Int = 2) async -> Bool {
        guard let device = IOBluetoothDevice(addressString: address) else {
            Log.bluetooth.error("Invalid Bluetooth address for connect: \(address, privacy: .public)")
            return false
        }

        if device.isConnected() {
            return true
        }

        Log.bluetooth.info("Connecting \(address, privacy: .public) (\(device.nameOrAddress ?? "", privacy: .public))")

        for attempt in 1 ... maxRetries {
            let status = device.openConnection()
            if status == kIOReturnSuccess {
                Log.bluetooth.info("Successfully requested connection to \(address, privacy: .public)")
                // Allow brief delay for connection handshake
                try? await Task.sleep(nanoseconds: 300_000_000)
                if device.isConnected() {
                    return true
                }
            } else {
                Log.bluetooth.warning("openConnection attempt \(attempt) for \(address, privacy: .public) returned: \(status)")
                if attempt < maxRetries {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }

        return device.isConnected()
    }

    /// Check if any Bluetooth input device (mouse, trackpad, keyboard) is currently connected
    func hasConnectedInputDevice() -> Bool {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return false }
        for device in paired {
            let name = (device.nameOrAddress ?? "").lowercased()
            let major = Int(device.deviceClassMajor)
            if isInputDevice(major: major, lowerName: name), device.isConnected() {
                return true
            }
        }
        return false
    }

    // MARK: - Classification Helpers

    private func determineCategory(device: IOBluetoothDevice, lowerName: String) -> BluetoothDeviceCategory {
        let major = Int(device.deviceClassMajor)

        if isAudioDevice(major: major, lowerName: lowerName) {
            return .audio
        }
        if isInputDevice(major: major, lowerName: lowerName) {
            return .input
        }
        if isPhoneDevice(major: major, lowerName: lowerName) {
            return .phone
        }
        if isComputerDevice(major: major, lowerName: lowerName) {
            return .computer
        }
        return .other
    }

    private func isAudioDevice(major: Int, lowerName: String) -> Bool {
        major == kBluetoothDeviceClassMajorAudio ||
            lowerName.contains("airpod") ||
            lowerName.contains("headphone") ||
            lowerName.contains("earphone") ||
            lowerName.contains("buds") ||
            lowerName.contains("speaker") ||
            lowerName.contains("soundbar") ||
            lowerName.contains("bose") ||
            lowerName.contains("sony") ||
            lowerName.contains("wh-") ||
            lowerName.contains("wf-")
    }

    private func isInputDevice(major: Int, lowerName: String) -> Bool {
        major == kBluetoothDeviceClassMajorPeripheral ||
            lowerName.contains("mouse") ||
            lowerName.contains("trackball") ||
            lowerName.contains("trackpad") ||
            lowerName.contains("keyboard") ||
            lowerName.contains("pointer") ||
            lowerName.contains("magic mouse") ||
            lowerName.contains("magic keyboard") ||
            lowerName.contains("ergo") ||
            lowerName.contains("mx master") ||
            lowerName.contains("logitech mx")
    }

    private func isPhoneDevice(major: Int, lowerName: String) -> Bool {
        major == kBluetoothDeviceClassMajorPhone ||
            lowerName.contains("iphone") ||
            lowerName.contains("ipad") ||
            lowerName.contains("galaxy") ||
            lowerName.contains("pixel")
    }

    private func isComputerDevice(major: Int, lowerName: String) -> Bool {
        major == kBluetoothDeviceClassMajorComputer ||
            lowerName.contains("macbook") ||
            lowerName.contains("imac") ||
            lowerName.contains("mac mini") ||
            lowerName.contains("mac studio") ||
            lowerName.contains("mac pro")
    }
}
