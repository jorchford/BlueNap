//
//  GeneralPreferencesTab.swift
//  Bluesnooze
//
//  Created on 2026-10-20.
//

import ServiceManagement
import SwiftUI

struct GeneralPreferencesTab: View {
    @Bindable var preferences: Preferences
    @State private var showingHideIconAlert = false
    @State private var launchAtLogin: Bool = (SMAppService.mainApp.status == .enabled)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Status Bar & Animation
            liquidCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text(NSLocalizedString("Status Bar & Animation", comment: ""))
                        .font(.headline)

                    Toggle(
                        NSLocalizedString("Smooth transition animation on sleep/wake", comment: ""),
                        isOn: $preferences.showTransitionAnimation
                    )
                    .font(.body)

                    Text(
                        NSLocalizedString(
                            "Provides a subtle visual pulse and status feedback when network states change.",
                            comment: ""
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            // Menu Bar & Background Execution
            liquidCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text(NSLocalizedString("Menu Bar & Background Mode", comment: ""))
                        .font(.headline)

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("Show icon in menu bar", comment: ""))
                                .font(.body.weight(.medium))
                            Text(
                                NSLocalizedString(
                                    "When disabled, BlueNap runs silently in the background without taking up status bar space. " +
                                        "To reopen Settings, launch BlueNap from Applications or Spotlight.",
                                    comment: ""
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
                            Text(
                                NSLocalizedString(
                                    "Background mode active: BlueNap continues monitoring sleep & wake events silently.",
                                    comment: ""
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }

            // System & Lifecycle (Launch at Login & Quit)
            liquidCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text(NSLocalizedString("System & Lifecycle", comment: ""))
                        .font(.headline)

                    // Launch at Login Toggle
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("Launch at login", comment: ""))
                                .font(.body.weight(.medium))
                            Text(
                                NSLocalizedString(
                                    "Automatically start BlueNap in the background when your Mac turns on or logs in.",
                                    comment: ""
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { launchAtLogin },
                            set: { enabled in
                                do {
                                    if enabled {
                                        try SMAppService.mainApp.register()
                                    } else {
                                        try SMAppService.mainApp.unregister()
                                    }
                                    launchAtLogin = (SMAppService.mainApp.status == .enabled)
                                } catch {
                                    Log.app.error("Launch at login toggle error: \(error, privacy: .public)")
                                    launchAtLogin = (SMAppService.mainApp.status == .enabled)
                                }
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }

                    Divider()

                    // Quit Application Button
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("Quit BlueNap", comment: ""))
                                .font(.body.weight(.medium))
                            Text(
                                NSLocalizedString(
                                    "Completely stop BlueNap and terminate all background Bluetooth & Wi-Fi monitors.",
                                    comment: ""
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(role: .destructive) {
                            NSApplication.shared.terminate(nil)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "power")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(NSLocalizedString("Quit Application", comment: ""))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.regular)
                    }
                }
            }

            // Reset Preferences
            liquidCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("Reset Preferences", comment: ""))
                            .font(.headline)
                        Text(NSLocalizedString("Restore all BlueNap settings to factory defaults.", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    Button(NSLocalizedString("Reset to Defaults", comment: ""), role: .destructive) {
                        preferences.resetToDefaults()
                        AppDelegate.shared?.setMenuBarIconVisible(true)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .onAppear {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
        .alert(NSLocalizedString("Hide Menu Bar Icon?", comment: ""), isPresented: $showingHideIconAlert) {
            Button(NSLocalizedString("Hide Icon & Run in Background", comment: ""), role: .destructive) {
                AppDelegate.shared?.setMenuBarIconVisible(false)
            }
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(
                NSLocalizedString(
                    "BlueNap will continue protecting your Bluetooth audio and Wi-Fi in the background.\n\n" +
                        "To open Settings or restore the menu bar icon, launch BlueNap again from Applications or Spotlight.",
                    comment: ""
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
