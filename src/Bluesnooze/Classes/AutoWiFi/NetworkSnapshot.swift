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
    var isInterfaceActive: Bool
    var locationAuthorizationStatus: Int
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
        isInterfaceActive: Bool = false,
        locationAuthorizationStatus: Int = 0,
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
        self.isInterfaceActive = isInterfaceActive
        self.locationAuthorizationStatus = locationAuthorizationStatus
        self.lastSeenSSID = lastSeenSSID
        self.matchedProfile = matchedProfile
        self.timestamp = timestamp
    }

    var isConnected: Bool {
        if let ssid = connectedSSID, !ssid.isEmpty {
            return true
        }
        if let ip = currentIPv4, !ip.isEmpty, ip != "0.0.0.0" {
            return true
        }
        if let router = currentRouter, !router.isEmpty {
            return true
        }
        return isInterfaceActive
    }

    var isLocationAuthorized: Bool {
        locationAuthorizationStatus == 3 || locationAuthorizationStatus == 4
    }

    var isLocationDenied: Bool {
        locationAuthorizationStatus == 1 || locationAuthorizationStatus == 2
    }

    var modeDisplayText: String {
        isManualConfiguration ? NSLocalizedString("Static IP", comment: "") : NSLocalizedString("DHCP", comment: "")
    }
}
