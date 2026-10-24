//
//  WiFiProfile.swift
//  Bluesnooze
//
//  Created on 2026-10-23.
//

import Foundation

/// Represents a Wi-Fi SSID static IP configuration profile.
struct WiFiProfile: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var ssid: String
    var staticIP: String
    var subnetMask: String
    var router: String
    var dnsServers: [String]
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        ssid: String,
        staticIP: String,
        subnetMask: String = "255.255.255.0",
        router: String,
        dnsServers: [String] = [],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.ssid = ssid
        self.staticIP = staticIP
        self.subnetMask = subnetMask
        self.router = router
        self.dnsServers = dnsServers
        self.isEnabled = isEnabled
    }

    /// Validates whether a given string is a valid IPv4 address (0.0.0.0 - 255.255.255.255).
    static func isValidIPv4(_ ip: String) -> Bool {
        let trimmed = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        for part in parts {
            guard let val = Int(part), val >= 0, val <= 255, String(val) == part else {
                return false
            }
        }
        return true
    }

    /// Checks if the entire profile is valid and ready to be written to configuration.
    var isValid: Bool {
        !ssid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            Self.isValidIPv4(staticIP) &&
            Self.isValidIPv4(subnetMask) &&
            Self.isValidIPv4(router) &&
            dnsServers.allSatisfy { Self.isValidIPv4($0) }
    }

    /// Returns human-readable validation error messages if any.
    var validationErrors: [String] {
        var errors: [String] = []
        if ssid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(NSLocalizedString("SSID cannot be empty", comment: ""))
        }
        if !Self.isValidIPv4(staticIP) {
            errors.append(String(format: NSLocalizedString("Invalid static IPv4: %@", comment: ""), staticIP))
        }
        if !Self.isValidIPv4(subnetMask) {
            errors.append(String(format: NSLocalizedString("Invalid subnet mask: %@", comment: ""), subnetMask))
        }
        if !Self.isValidIPv4(router) {
            errors.append(String(format: NSLocalizedString("Invalid gateway/router: %@", comment: ""), router))
        }
        for dns in dnsServers where !Self.isValidIPv4(dns) {
            errors.append(String(format: NSLocalizedString("Invalid DNS address: %@", comment: ""), dns))
        }
        return errors
    }

    /// DNS list formatted as space-separated string for configuration file.
    var dnsString: String {
        get { dnsServers.joined(separator: " ") }
        set {
            dnsServers = newValue
                .split(whereSeparator: { $0.isWhitespace || $0 == "," })
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }
}
