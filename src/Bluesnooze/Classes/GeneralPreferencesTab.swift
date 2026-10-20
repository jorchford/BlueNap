//
//  GeneralPreferencesTab.swift
//  Bluesnooze
//
//  Created on 2026-10-20.
//

import SwiftUI

struct GeneralPreferencesTab: View {
    @Bindable var preferences: Preferences
    @State private var showingHideIconAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Status Bar & Animation
            liquidCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Status Bar & Animation")
                        .font(.headline)

                    Toggle("Smooth transition animation on sleep/wake", isOn: $preferences.showTransitionAnimation)
                        .font(.body)

                    Text("Provides a subtle visual pulse and status feedback when network states change.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Menu Bar & Background Execution
            liquidCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Menu Bar & Background Mode")
                        .font(.headline)

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Show icon in menu bar")
                                .font(.body.weight(.medium))
                            Text(
                                LocalizedStringKey(
                                    "When disabled, BlueNap runs silently in the background without taking up status bar space. " +
                                        "To reopen Settings, launch BlueNap from Applications or Spotlight."
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { !preferences.hideIcon },
                            set: { isVisible in
                                if !isVisible {
                                    showingHideIconAlert = true
                                } else {
                                    AppDelegate.shared?.setMenuBarIconVisible(true)
                                }
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }

                    if preferences.hideIcon {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Background mode active: BlueNap continues monitoring sleep & wake events silently.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }

            // Reset Preferences
            liquidCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reset Preferences")
                            .font(.headline)
                        Text("Restore all BlueNap settings to factory defaults.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    Button("Reset to Defaults", role: .destructive) {
                        preferences.resetToDefaults()
                        AppDelegate.shared?.setMenuBarIconVisible(true)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .alert("Hide Menu Bar Icon?", isPresented: $showingHideIconAlert) {
            Button("Hide Icon & Run in Background", role: .destructive) {
                AppDelegate.shared?.setMenuBarIconVisible(false)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                LocalizedStringKey(
                    "BlueNap will continue protecting your Bluetooth audio and Wi-Fi in the background.\n\n" +
                        "To open Settings or restore the menu bar icon, launch BlueNap again from Applications or Spotlight."
                )
            )
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
