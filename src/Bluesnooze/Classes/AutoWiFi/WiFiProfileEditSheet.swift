//
//  WiFiProfileEditSheet.swift
//  Bluesnooze
//
//  Created on 2026-10-23.
//

import SwiftUI

struct WiFiProfileEditSheet: View {
    @Binding var profile: WiFiProfile
    let isNew: Bool
    let currentSSID: String?
    let onSave: (WiFiProfile) -> Void
    let onCancel: () -> Void

    @State private var ssidText: String = ""
    @State private var ipText: String = ""
    @State private var maskText: String = "255.255.255.0"
    @State private var routerText: String = ""
    @State private var dnsText: String = ""

    private let dnsPresets: [(name: String, ips: [String])] = [
        ("AliDNS", ["223.5.5.5", "223.6.6.6"]),
        ("DNSPod", ["119.29.29.29", "182.254.116.116"]),
        ("114DNS", ["114.114.114.114", "114.114.115.115"]),
        ("Cloudflare", ["1.1.1.1", "1.0.0.1"]),
        ("Google", ["8.8.8.8", "8.8.4.4"])
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isNew ? NSLocalizedString("Add Wi-Fi Profile", comment: "") : NSLocalizedString("Edit Wi-Fi Profile", comment: ""))
                    .font(.headline)
                Spacer()
                Button(NSLocalizedString("Cancel", comment: ""), action: onCancel)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(.thinMaterial)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // SSID Input
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(NSLocalizedString("Wi-Fi SSID", comment: ""))
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            if let curr = currentSSID, WiFiNetworkMonitor.isValidSSID(curr) {
                                Button {
                                    ssidText = curr
                                    if routerText.isEmpty {
                                        routerText = WiFiNetworkMonitor.fetchDefaultGateway() ?? ""
                                    }
                                } label: {
                                    Label(NSLocalizedString("Use Current Wi-Fi", comment: ""), systemImage: "arrow.down.circle")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                            }

                            let preferred = WiFiNetworkMonitor.fetchPreferredNetworks()
                            if !preferred.isEmpty {
                                Menu {
                                    ForEach(preferred, id: \.self) { net in
                                        Button(net) {
                                            ssidText = net
                                        }
                                    }
                                } label: {
                                    Label(NSLocalizedString("Choose Preferred", comment: ""), systemImage: "list.bullet")
                                        .font(.caption)
                                }
                                .menuStyle(.borderlessButton)
                            }
                        }

                        TextField("e.g. Company_Office_5G", text: $ssidText)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Static IPv4 & Subnet Mask
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(NSLocalizedString("Static IPv4", comment: ""))
                                .font(.subheadline.weight(.medium))
                            TextField("192.168.1.100", text: $ipText)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(NSLocalizedString("Subnet Mask", comment: ""))
                                .font(.subheadline.weight(.medium))
                            TextField("255.255.255.0", text: $maskText)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    // Router Gateway
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("Router Gateway", comment: ""))
                            .font(.subheadline.weight(.medium))
                        TextField("192.168.1.1", text: $routerText)
                            .textFieldStyle(.roundedBorder)
                    }

                    // DNS Servers
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("DNS Servers (Space separated)", comment: ""))
                            .font(.subheadline.weight(.medium))
                        TextField("223.5.5.5 223.6.6.6", text: $dnsText)
                            .textFieldStyle(.roundedBorder)

                        // DNS Presets
                        HStack(spacing: 6) {
                            Text(NSLocalizedString("Presets:", comment: ""))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            ForEach(dnsPresets, id: \.name) { preset in
                                Button(preset.name) {
                                    dnsText = preset.ips.joined(separator: " ")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button(NSLocalizedString("Cancel", comment: ""), action: onCancel)
                    .buttonStyle(.bordered)
                Button(NSLocalizedString("Save Profile", comment: "")) {
                    let dnsList = dnsText
                        .split(whereSeparator: { $0.isWhitespace || $0 == "," })
                        .map { String($0) }
                    let updated = WiFiProfile(
                        id: profile.id,
                        ssid: ssidText.trimmingCharacters(in: .whitespacesAndNewlines),
                        staticIP: ipText.trimmingCharacters(in: .whitespacesAndNewlines),
                        subnetMask: maskText.trimmingCharacters(in: .whitespacesAndNewlines),
                        router: routerText.trimmingCharacters(in: .whitespacesAndNewlines),
                        dnsServers: dnsList,
                        isEnabled: profile.isEnabled
                    )
                    onSave(updated)
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    !WiFiNetworkMonitor.isValidSSID(ssidText) ||
                        !WiFiProfile.isValidIPv4(ipText) ||
                        !WiFiProfile.isValidIPv4(maskText) ||
                        !WiFiProfile.isValidIPv4(routerText)
                )
            }
            .padding(16)
            .background(.thinMaterial)
        }
        .frame(width: 480, height: 420)
        .onAppear {
            ssidText = profile.ssid
            ipText = profile.staticIP
            maskText = profile.subnetMask.isEmpty ? "255.255.255.0" : profile.subnetMask
            routerText = profile.router
            dnsText = profile.dnsServers.joined(separator: " ")
        }
    }
}
