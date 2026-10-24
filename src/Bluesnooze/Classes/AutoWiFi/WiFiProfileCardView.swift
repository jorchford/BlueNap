//
//  WiFiProfileCardView.swift
//  Bluesnooze
//
//  Created on 2026-10-23.
//

import SwiftUI

struct WiFiProfileCardView: View {
    let profile: WiFiProfile
    let isCurrentSSID: Bool
    let onToggleBinding: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "wifi")
                    .font(.system(size: 16))
                    .foregroundStyle(isCurrentSSID ? Color.blue : Color.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(profile.ssid)
                            .font(.body.weight(.semibold))

                        if isCurrentSSID {
                            Text(NSLocalizedString("Connected", comment: ""))
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.18), in: Capsule())
                                .foregroundStyle(Color.green)
                        }

                        if !profile.isEnabled {
                            Text(NSLocalizedString("Binding Paused", comment: ""))
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.18), in: Capsule())
                                .foregroundStyle(Color.orange)
                        }
                    }

                    Text("IP: \(profile.staticIP)  •  Gateway: \(profile.router)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospaced()
                }

                Spacer()

                // Toggle whether binding is active for this profile
                Toggle("", isOn: Binding(
                    get: { profile.isEnabled },
                    set: { onToggleBinding($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)

                Menu {
                    Button(action: onEdit) {
                        Label(NSLocalizedString("Edit Configuration", comment: ""), systemImage: "pencil")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label(NSLocalizedString("Delete Profile", comment: ""), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
            }

            if !profile.dnsServers.isEmpty {
                HStack(spacing: 4) {
                    Text(NSLocalizedString("DNS:", comment: ""))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(profile.dnsServers.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospaced()
                }
                .padding(.leading, 34)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isCurrentSSID ? Color.blue.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
