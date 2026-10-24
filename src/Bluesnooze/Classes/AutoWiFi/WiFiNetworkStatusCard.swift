//
//  WiFiNetworkStatusCard.swift
//  Bluesnooze
//
//  Created on 2026-10-23.
//

import SwiftUI

struct WiFiNetworkStatusCard: View {
    let snapshot: NetworkSnapshot
    let onApplyOnce: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: snapshot.isConnected ? "wifi" : "wifi.slash")
                        .font(.title3)
                        .foregroundStyle(snapshot.isConnected ? Color.blue : Color.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot.connectedSSID ?? NSLocalizedString("Wi-Fi Disconnected", comment: ""))
                            .font(.headline)
                        Text(snapshot.modeDisplayText)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                snapshot.isManualConfiguration ? Color.purple.opacity(0.18) : Color.blue.opacity(0.18),
                                in: Capsule()
                            )
                            .foregroundStyle(snapshot.isManualConfiguration ? Color.purple : Color.blue)
                    }
                }

                Spacer()

                Button {
                    onApplyOnce()
                } label: {
                    Label(NSLocalizedString("Apply Rule Now", comment: ""), systemImage: "arrow.clockwise")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Divider()

            // Network Details Grid
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text(NSLocalizedString("Current IPv4", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(snapshot.currentIPv4 ?? "--")
                        .font(.caption.weight(.medium))
                        .monospaced()

                    Text(NSLocalizedString("Subnet Mask", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(snapshot.currentNetmask ?? "--")
                        .font(.caption.weight(.medium))
                        .monospaced()
                }

                GridRow {
                    Text(NSLocalizedString("Gateway Router", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(snapshot.currentRouter ?? "--")
                        .font(.caption.weight(.medium))
                        .monospaced()

                    Text(NSLocalizedString("DNS Servers", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(snapshot.currentDNS.isEmpty ? "--" : snapshot.currentDNS.joined(separator: ", "))
                        .font(.caption.weight(.medium))
                        .monospaced()
                        .lineLimit(1)
                }
            }

            if let matched = snapshot.matchedProfile {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text(String(format: NSLocalizedString("Rule Matched: %@ (%@)", comment: ""), matched.ssid, matched.staticIP))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
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
