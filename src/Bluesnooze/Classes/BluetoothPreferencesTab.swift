//
//  BluetoothPreferencesTab.swift
//  Bluesnooze
//
//  Created on 2026-10-20.
//

import SwiftUI

struct BluetoothPreferencesTab: View {
    @Bindable var preferences: Preferences
    @Bindable var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Hardware Status Card
            liquidCard {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.title2)
                        .foregroundStyle(appState.isBluetoothHardwareOn ? Color.blue : Color.gray)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bluetooth Hardware")
                            .font(.headline)
                        Text(appState.isBluetoothHardwareOn ? "Powered On" : "Powered Off")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        appState.refreshHardwareStates()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Refresh Bluetooth devices")
                }
            }

            // Sleep Actions
            liquidCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("When Mac Goes to Sleep")
                        .font(.headline)

                    Toggle("Turn off Bluetooth completely", isOn: $preferences.disableBluetoothOnSleep)
                        .onChange(of: preferences.disableBluetoothOnSleep) { _, newValue in
                            if newValue {
                                preferences.disconnectDevicesOnSleep = false
                            }
                        }

                    Toggle("Disconnect selected accessories only", isOn: $preferences.disconnectDevicesOnSleep)
                        .disabled(preferences.disableBluetoothOnSleep)
                        .onChange(of: preferences.disconnectDevicesOnSleep) { _, newValue in
                            if newValue {
                                preferences.disableBluetoothOnSleep = false
                            }
                        }

                    if preferences.disconnectDevicesOnSleep {
                        pairedDevicesListView
                    }
                }
            }

            // Wake Actions
            liquidCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("When Mac Wakes Up")
                        .font(.headline)

                    Picker("Action on unlock:", selection: $preferences.bluetoothWakeAction) {
                        ForEach(WakeAction.allCases, id: \.self) { action in
                            Text(action.displayName).tag(action)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }
            }
        }
    }

    private var pairedDevicesListView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select audio accessories to disconnect on sleep:")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            if appState.pairedDevices.isEmpty {
                Text("No paired Bluetooth audio accessories detected.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(appState.pairedDevices) { device in
                        deviceRow(for: device)
                    }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text("Mice, keyboards, and trackpads are automatically protected and will never be disconnected.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func deviceRow(for device: BluetoothDeviceInfo) -> some View {
        let isMarked = preferences.isDeviceMarkedForDisconnect(address: device.address)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: device.sfSymbolName)
                    .font(.system(size: 16))
                    .foregroundStyle(device.isConnected ? Color.blue : Color.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(device.name)
                            .font(.body.weight(.medium))
                        if device.isConnected {
                            Text("Connected")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.18), in: Capsule())
                                .foregroundStyle(Color.green)
                        }
                    }

                    Text(device.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { isMarked },
                    set: { newValue in
                        preferences.setDeviceMarkedForDisconnect(address: device.address, disconnect: newValue)
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
            }

            if isMarked, device.isInputDevice {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    Text("Disconnecting mouse or keyboard may prevent waking via Bluetooth.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 6)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func liquidCard(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}
