//
//  WiFiPreferencesTab.swift
//  Bluesnooze
//
//  Created on 2026-10-20.
//

import SwiftUI

struct WiFiPreferencesTab: View {
    @Bindable var preferences: Preferences
    @Bindable var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Hardware Status Card
            liquidCard {
                HStack {
                    Image(systemName: "wifi")
                        .font(.title2)
                        .foregroundStyle(appState.isWifiHardwareOn ? Color.blue : Color.gray)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Wi-Fi Interface")
                            .font(.headline)
                        Text(appState.isWifiHardwareOn ? "Powered On" : "Powered Off")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }

            // Wi-Fi Sleep Actions
            liquidCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("When Mac Goes to Sleep")
                        .font(.headline)

                    Toggle("Turn off Wi-Fi when sleeping", isOn: $preferences.disableWifiOnSleep)

                    Text("Helps preserve battery life and prevent unexpected background network wakeups.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Wi-Fi Wake Actions
            liquidCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("When Mac Wakes Up")
                        .font(.headline)

                    Picker("Action on unlock:", selection: $preferences.wifiWakeAction) {
                        ForEach(WakeAction.allCases, id: \.self) { action in
                            Text(action.displayName).tag(action)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }
            }
        }
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
