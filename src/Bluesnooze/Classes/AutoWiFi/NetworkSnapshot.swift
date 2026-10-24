//
//  NetworkSnapshot.swift
//  Bluesnooze
//
//  Created on 2026-10-23.
//

import Foundation

/// Real-time snapshot of the current Wi-Fi network interface state.
struct NetworkSnapshot: Sendable, Hashable {
    var connectedSSID: String?
    var currentIPv4: String?
    var currentNetmask: String?
    var currentRouter: String?
    var currentDNS: [String]
    var isManualConfiguration: Bool
    var lastSeenSSID: String?
    var matchedProfile: WiFiProfile?
    var timestamp: Date

    init(
        connectedSSID: String? = nil,
        currentIPv4: String? = nil,
        currentNetmask: String? = nil,
        currentRouter: String? = nil,
        currentDNS: [String] = [],
        isManualConfiguration: Bool = false,
        lastSeenSSID: String? = nil,
        matchedProfile: WiFiProfile? = nil,
        timestamp: Date = Date()
    ) {
        self.connectedSSID = connectedSSID
        self.currentIPv4 = currentIPv4
        self.currentNetmask = currentNetmask
        self.currentRouter = currentRouter
        self.currentDNS = currentDNS
        self.isManualConfiguration = isManualConfiguration
        self.lastSeenSSID = lastSeenSSID
        self.matchedProfile = matchedProfile
        self.timestamp = timestamp
    }

    var isConnected: Bool {
        connectedSSID != nil && !connectedSSID!.isEmpty
    }

    var modeDisplayText: String {
        isManualConfiguration ? NSLocalizedString("Static IP", comment: "") : NSLocalizedString("DHCP", comment: "")
    }
}
