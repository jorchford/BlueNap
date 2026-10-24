//
//  WiFiDaemonControlCard.swift
//  Bluesnooze
//
//  Created on 2026-10-23.
//

import SwiftUI

struct WiFiDaemonControlCard: View {
    let daemonInfo: DaemonInfo
    @Binding var globalConfig: GlobalConfig
    let onInstall: () -> Void
    let onStart: () -> Void
    let onStop: () -> Void
    let onRestart: () -> Void
    let onUninstall: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header with status indicator
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(NSLocalizedString("Background Daemon Service", comment: ""))
                        .font(.headline)
                    Text(NSLocalizedString("0% CPU kernel event-driven LaunchDaemon for automatic switching.", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Status pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(daemonInfo.status.displayText)
                        .font(.caption2.weight(.medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
            }

            Divider()

            // Service Management Action Buttons
            HStack(spacing: 10) {
                switch daemonInfo.status {
                case .notInstalled:
                    Button(action: onInstall) {
                        Label(NSLocalizedString("Install Daemon Service", comment: ""), systemImage: "arrow.down.doc")
                    }
                    .buttonStyle(.borderedProminent)

                case .running:
                    Button(action: onStop) {
                        Label(NSLocalizedString("Stop Service", comment: ""), systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)

                    Button(action: onRestart) {
                        Label(NSLocalizedString("Restart", comment: ""), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button(role: .destructive, action: onUninstall) {
                        Label(NSLocalizedString("Uninstall", comment: ""), systemImage: "trash")
                    }
                    .buttonStyle(.bordered)

                case .stopped, .unknown:
                    Button(action: onStart) {
                        Label(NSLocalizedString("Start Service", comment: ""), systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: onRestart) {
                        Label(NSLocalizedString("Restart", comment: ""), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button(role: .destructive, action: onUninstall) {
                        Label(NSLocalizedString("Uninstall", comment: ""), systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Global Fallback Option
            Toggle(
                NSLocalizedString("Restore DHCP when connecting to unconfigured Wi-Fi", comment: ""),
                isOn: $globalConfig.restoreDHCP
            )
            .font(.subheadline)
            .padding(.top, 4)
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

    private var statusColor: Color {
        switch daemonInfo.status {
        case .running: .green
        case .stopped: .orange
        case .notInstalled: .gray
        case .unknown: .yellow
        }
    }
}
