//
//  WiFiPreferencesTab.swift
//  Bluesnooze
//
//  Created on 2026-10-20.
//  Enhanced with AutoWiFi on 2026-10-23.
//

import SwiftUI

struct WiFiPreferencesTab: View {
    @Bindable var preferences: Preferences
    @Bindable var appState: AppState

    @State private var globalConfig: GlobalConfig = .init()
    @State private var profiles: [WiFiProfile] = []
    @State private var networkSnapshot: NetworkSnapshot = .init()
    @State private var daemonInfo: DaemonInfo = .init()

    @State private var isSheetPresented: Bool = false
    @State private var isNewProfile: Bool = false
    @State private var editingProfile: WiFiProfile = .init(ssid: "", staticIP: "", router: "")
    @State private var statusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Master Auto-Binding Toggle Card
            autoBindingMasterCard

            if preferences.isAutoWiFiBindingEnabled {
                // Live Network Status Card
                WiFiNetworkStatusCard(snapshot: networkSnapshot) {
                    applyOnce()
                }

                // Configured Wi-Fi Profiles Section
                profilesSection

                // Background Daemon Service Card
                WiFiDaemonControlCard(
                    daemonInfo: daemonInfo,
                    globalConfig: $globalConfig,
                    onInstall: { installDaemon() },
                    onStart: { startDaemon() },
                    onStop: { stopDaemon() },
                    onRestart: { restartDaemon() },
                    onUninstall: { uninstallDaemon() }
                )
            }

            // Wi-Fi Sleep & Wake Power Management
            sleepWakePowerSection
        }
        .sheet(isPresented: $isSheetPresented) {
            WiFiProfileEditSheet(
                profile: $editingProfile,
                isNew: isNewProfile,
                currentSSID: networkSnapshot.connectedSSID,
                onSave: { saved in
                    saveProfile(saved)
                    isSheetPresented = false
                },
                onCancel: {
                    isSheetPresented = false
                }
            )
        }
        .onAppear {
            WiFiNetworkMonitor.shared.requestLocationAuthorizationIfNeeded()
            loadAutoWiFiData()
            startMonitoring()
        }
        .onDisappear {
            stopMonitoring()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("WiFiNetworkSnapshotNeedsRefresh"))) { _ in
            refreshSnapshot()
        }
        .onChange(of: preferences.isAutoWiFiBindingEnabled) { _, newValue in
            globalConfig.isBindingEnabled = newValue
            persistConfig()
        }
        .onChange(of: globalConfig.restoreDHCP) { _, _ in
            persistConfig()
        }
    }

    // MARK: - Sections

    private var autoBindingMasterCard: some View {
        liquidCard {
            HStack {
                Image(systemName: "network")
                    .font(.title2)
                    .foregroundStyle(preferences.isAutoWiFiBindingEnabled ? Color.blue : Color.secondary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("Auto-Bind Wi-Fi Static IP", comment: ""))
                        .font(.headline)
                    Text(NSLocalizedString("Automatically switches to static IP for designated Wi-Fi networks.", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $preferences.isAutoWiFiBindingEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
    }

    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("Configured Wi-Fi Networks", comment: ""))
                    .font(.headline)
                Spacer()
                Button {
                    editingProfile = WiFiProfile(
                        ssid: networkSnapshot.connectedSSID ?? "",
                        staticIP: networkSnapshot.currentIPv4 ?? "",
                        subnetMask: networkSnapshot.currentNetmask ?? "255.255.255.0",
                        router: networkSnapshot.currentRouter ?? "",
                        dnsServers: networkSnapshot.currentDNS
                    )
                    isNewProfile = true
                    isSheetPresented = true
                } label: {
                    Label(NSLocalizedString("Add Wi-Fi Profile", comment: ""), systemImage: "plus")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if profiles.isEmpty {
                liquidCard {
                    HStack(spacing: 12) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("No Wi-Fi Profiles Added", comment: ""))
                                .font(.subheadline.weight(.medium))
                            Text(
                                NSLocalizedString(
                                    "Click 'Add Wi-Fi Profile' above to configure static IP for your office or home network.",
                                    comment: ""
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            } else {
                ForEach(profiles) { profile in
                    WiFiProfileCardView(
                        profile: profile,
                        isCurrentSSID: profile.ssid == networkSnapshot.connectedSSID,
                        onToggleBinding: { isEnabled in
                            if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
                                profiles[idx].isEnabled = isEnabled
                                persistConfig()
                            }
                        },
                        onEdit: {
                            editingProfile = profile
                            isNewProfile = false
                            isSheetPresented = true
                        },
                        onDelete: {
                            profiles.removeAll { $0.id == profile.id }
                            persistConfig()
                        }
                    )
                }
            }
        }
    }

    private var sleepWakePowerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(NSLocalizedString("Sleep & Wake Power Lifecycle", comment: ""))
                .font(.headline)

            liquidCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text(NSLocalizedString("When Mac Goes to Sleep", comment: ""))
                        .font(.subheadline.weight(.medium))

                    Toggle(NSLocalizedString("Turn off Wi-Fi when sleeping", comment: ""), isOn: $preferences.disableWifiOnSleep)

                    Text(NSLocalizedString("Helps preserve battery life and prevent unexpected background network wakeups.", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    Text(NSLocalizedString("When Mac Wakes Up", comment: ""))
                        .font(.subheadline.weight(.medium))

                    Picker(NSLocalizedString("Action on unlock:", comment: ""), selection: $preferences.wifiWakeAction) {
                        ForEach(WakeAction.allCases, id: \.self) { action in
                            Text(action.displayName).tag(action)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }
            }
        }
    }

    // MARK: - Actions & Persistence

    private func loadAutoWiFiData() {
        Task {
            if CommandLine.arguments.contains("--demo") {
                globalConfig = GlobalConfig(networkService: "Wi-Fi", wifiDevice: "en0", restoreDHCP: true, isBindingEnabled: true)
                let demoProfile1 = WiFiProfile(ssid: "Home_Office_5G", staticIP: "192.168.1.151", subnetMask: "255.255.255.0", router: "192.168.1.1", dnsServers: ["1.1.1.1", "8.8.8.8"], isEnabled: true)
                let demoProfile2 = WiFiProfile(ssid: "Company_HighSpeed_Wi-Fi", staticIP: "10.0.0.188", subnetMask: "255.255.255.0", router: "10.0.0.1", dnsServers: ["223.5.5.5", "114.114.114.114"], isEnabled: true)
                profiles = [demoProfile1, demoProfile2]
                networkSnapshot = NetworkSnapshot(
                    connectedSSID: "Home_Office_5G",
                    currentIPv4: "192.168.1.151",
                    currentNetmask: "255.255.255.0",
                    currentRouter: "192.168.1.1",
                    currentDNS: ["1.1.1.1", "8.8.8.8"],
                    isManualConfiguration: true,
                    lastSeenSSID: "Home_Office_5G",
                    matchedProfile: demoProfile1,
                    timestamp: Date()
                )
                daemonInfo = DaemonInfo(status: .running(pid: 1234))
                return
            }

            let (loadedGlobal, loadedProfiles) = await WiFiConfigManager.shared.loadConfig()
            globalConfig = loadedGlobal
            // Filter out any legacy corrupted redacted SSIDs
            profiles = loadedProfiles.filter { WiFiNetworkMonitor.isValidSSID($0.ssid) }

            let daemonStatus = await WiFiDaemonManager.shared.checkStatus()
            daemonInfo = DaemonInfo(status: daemonStatus)

            refreshSnapshot()
        }
    }

    private func startMonitoring() {
        guard !CommandLine.arguments.contains("--demo") else { return }
        WiFiNetworkMonitor.shared.startMonitoring { snapshot in
            var updated = snapshot
            if let ssid = updated.connectedSSID,
               let match = profiles.first(where: { $0.ssid == ssid }) {
                updated.matchedProfile = match
            } else if updated.connectedSSID == nil, let router = updated.currentRouter,
                      let match = profiles.first(where: { $0.router == router }) {
                updated.matchedProfile = match
                updated.connectedSSID = match.ssid
            }
            networkSnapshot = updated
            Task {
                let status = await WiFiDaemonManager.shared.checkStatus()
                daemonInfo = DaemonInfo(status: status)
            }
        }
    }

    private func stopMonitoring() {
        WiFiNetworkMonitor.shared.stopMonitoring()
    }

    private func refreshSnapshot() {
        guard !CommandLine.arguments.contains("--demo") else { return }
        var snap = WiFiNetworkMonitor.shared.captureCurrentSnapshot(
            device: globalConfig.wifiDevice,
            serviceName: globalConfig.networkService
        )
        if let ssid = snap.connectedSSID,
           let match = profiles.first(where: { $0.ssid == ssid }) {
            snap.matchedProfile = match
        } else if snap.connectedSSID == nil, let router = snap.currentRouter,
                  let match = profiles.first(where: { $0.router == router }) {
            // Intelligent fallback: Resolve Wi-Fi SSID by matching default router gateway IP
            snap.matchedProfile = match
            snap.connectedSSID = match.ssid
        }
        networkSnapshot = snap
    }

    private func persistConfig() {
        Task {
            try? await WiFiConfigManager.shared.saveConfig(global: globalConfig, profiles: profiles)
        }
    }

    private func saveProfile(_ saved: WiFiProfile) {
        if let idx = profiles.firstIndex(where: { $0.id == saved.id }) {
            profiles[idx] = saved
        } else {
            profiles.append(saved)
        }
        persistConfig()
        refreshSnapshot()
    }

    private func applyOnce() {
        Task {
            let (_, msg) = await WiFiAutoBindingService.shared.evaluateAndApply(global: globalConfig, profiles: profiles)
            statusMessage = msg
            refreshSnapshot()
        }
    }

    private func installDaemon() {
        Task {
            let configText = await WiFiConfigManager.shared.serializeINI(global: globalConfig, profiles: profiles)
            // Use bundled universal binary
            let bundledURL = Bundle.main.url(forResource: "bluenap-wifid", withExtension: nil) ??
                URL(fileURLWithPath: DaemonInfo.daemonExecutablePath)
            do {
                try await WiFiDaemonManager.shared.installService(daemonBinaryURL: bundledURL, configText: configText)
                let status = await WiFiDaemonManager.shared.checkStatus()
                daemonInfo = DaemonInfo(status: status)
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    private func startDaemon() {
        Task {
            try? await WiFiDaemonManager.shared.start()
            let status = await WiFiDaemonManager.shared.checkStatus()
            daemonInfo = DaemonInfo(status: status)
        }
    }

    private func stopDaemon() {
        Task {
            try? await WiFiDaemonManager.shared.stop()
            let status = await WiFiDaemonManager.shared.checkStatus()
            daemonInfo = DaemonInfo(status: status)
        }
    }

    private func restartDaemon() {
        Task {
            try? await WiFiDaemonManager.shared.restart()
            let status = await WiFiDaemonManager.shared.checkStatus()
            daemonInfo = DaemonInfo(status: status)
        }
    }

    private func uninstallDaemon() {
        Task {
            try? await WiFiDaemonManager.shared.uninstall(purgeConfig: false)
            let status = await WiFiDaemonManager.shared.checkStatus()
            daemonInfo = DaemonInfo(status: status)
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
