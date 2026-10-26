//
//  PreferencesView.swift
//  Bluesnooze
//
//  Created on 2026-10-20.
//

import SwiftUI

struct PreferencesView: View {
    @Bindable var preferences: Preferences = .shared
    @Bindable var appState: AppState = .shared

    @State private var selectedTab: SettingsTab = CommandLine.arguments.contains("--tab-wifi") ? .wifi : (CommandLine.arguments.contains("--tab-about") ? .about : (CommandLine.arguments.contains("--tab-general") ? .general : .bluetooth))

    enum SettingsTab: String, CaseIterable, Identifiable {
        case bluetooth = "Bluetooth"
        case wifi = "Wi-Fi"
        case general = "General"
        case about = "About"

        var id: String {
            rawValue
        }

        var localizedKey: LocalizedStringKey {
            LocalizedStringKey(rawValue)
        }

        var iconName: String {
            switch self {
            case .bluetooth: "antenna.radiowaves.left.and.right"
            case .wifi: "wifi"
            case .general: "gearshape"
            case .about: "info.circle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Tabs
            HStack(spacing: 8) {
                ForEach(SettingsTab.allCases) { tab in
                    tabButton(for: tab)
                }
                Spacer()

                // Live status capsule
                HStack(spacing: 6) {
                    Circle()
                        .fill(appState.status == .active ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(appState.status.displayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.regularMaterial, in: Capsule())

                // Quick Quit button
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.red)
                        .padding(6)
                        .background(Color.red.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("Quit BlueNap", comment: ""))
            }
            .padding(16)
            .background(.thinMaterial)

            Divider()

            // Content Area
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                    switch selectedTab {
                    case .bluetooth:
                        BluetoothPreferencesTab(preferences: preferences, appState: appState)
                    case .wifi:
                        WiFiPreferencesTab(preferences: preferences, appState: appState)
                    case .general:
                        GeneralPreferencesTab(preferences: preferences)
                    case .about:
                        AboutPreferencesTab()
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 580, height: 540)
        .background(.regularMaterial)
        .id(preferences.appLanguage.rawValue)
        .environment(\.locale, preferences.appLanguage.locale ?? Locale.autoupdatingCurrent)
        .onAppear {
            appState.refreshHardwareStates()
        }
    }

    private func tabButton(for tab: SettingsTab) -> some View {
        Button {
            withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 13, weight: .medium))
                Text(tab.localizedKey)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                selectedTab == tab
                    ? AnyShapeStyle(.tint.opacity(0.18))
                    : AnyShapeStyle(.clear),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(selectedTab == tab ? Color.accentColor.opacity(0.3) : .clear, lineWidth: 1)
            )
            .foregroundStyle(selectedTab == tab ? Color.primary : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PreferencesView()
}
