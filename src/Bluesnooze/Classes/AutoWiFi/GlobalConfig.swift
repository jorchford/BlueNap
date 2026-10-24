//
//  GlobalConfig.swift
//  Bluesnooze
//
//  Created on 2026-10-23.
//

import Foundation

/// Global Wi-Fi switcher and auto-binding configuration settings.
struct GlobalConfig: Codable, Hashable, Sendable {
    /// macOS network service name (default: "Wi-Fi").
    var networkService: String
    /// Wi-Fi interface BSD name (default: "en0").
    var wifiDevice: String
    /// Whether to restore DHCP when connecting to an unconfigured Wi-Fi (1 = yes, 0 = no).
    var restoreDHCP: Bool
    /// Master toggle: whether static IP auto-binding and switching is enabled.
    var isBindingEnabled: Bool

    init(
        networkService: String = "Wi-Fi",
        wifiDevice: String = "en0",
        restoreDHCP: Bool = true,
        isBindingEnabled: Bool = true
    ) {
        self.networkService = networkService
        self.wifiDevice = wifiDevice
        self.restoreDHCP = restoreDHCP
        self.isBindingEnabled = isBindingEnabled
    }
}
