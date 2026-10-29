//
//  WiFiAutoBindingService.swift
//  Bluesnooze
//
//  Created on 2026-10-23.
//

import Foundation
import os

/// Native service engine for automatic Wi-Fi static IP binding and switching.
actor WiFiAutoBindingService {
    static let shared = WiFiAutoBindingService()

    private let log = Logger(subsystem: "com.needai.bluenap", category: "WiFiAutoBinding")

    init() {}

    /// Evaluates current Wi-Fi connection and applies rules if binding is enabled.
    @discardableResult
    func evaluateAndApply(
        global: GlobalConfig,
        profiles: [WiFiProfile]
    ) async -> (applied: Bool, message: String) {
        var detectedSSID = WiFiNetworkMonitor.fetchCurrentSSID()
        let currentRouter = WiFiNetworkMonitor.fetchDefaultGateway()

        // Fallback: match profile by router gateway IP if SSID was redacted by macOS
        if (detectedSSID == nil || !WiFiNetworkMonitor.isValidSSID(detectedSSID)),
           let router = currentRouter,
           let match = profiles.first(where: { $0.router == router }) {
            detectedSSID = match.ssid
        }

        guard let activeSSID = detectedSSID, WiFiNetworkMonitor.isValidSSID(activeSSID) else {
            return (false, NSLocalizedString("Wi-Fi disconnected; maintaining current network settings", comment: ""))
        }

        // Save last seen SSID state
        let stateURL = WiFiConfigManager.standardStateURL
        try? FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? activeSSID.write(to: stateURL, atomically: true, encoding: .utf8)

        // Check master binding switch
        guard global.isBindingEnabled else {
            log.info("Auto-binding is disabled by user. Skipping rule evaluation for SSID: \(activeSSID, privacy: .public)")
            return (false, String(format: NSLocalizedString("Auto-binding disabled; maintaining settings for %@", comment: ""), activeSSID))
        }

        // Look for matching profile
        if let match = profiles.first(where: { $0.ssid == activeSSID }) {
            guard match.isEnabled else {
                log.info("Profile for \(activeSSID, privacy: .public) is paused. Skipping.")
                return (false, String(format: NSLocalizedString("Binding paused for %@", comment: ""), activeSSID))
            }

            return applyStaticConfiguration(profile: match, serviceName: global.networkService)
        } else {
            // Unconfigured network
            if global.restoreDHCP {
                return restoreDHCP(serviceName: global.networkService, ssid: activeSSID)
            } else {
                return (false, String(format: NSLocalizedString("Unconfigured SSID: %@ (DHCP restore disabled)", comment: ""), activeSSID))
            }
        }
    }

    private func applyStaticConfiguration(
        profile: WiFiProfile,
        serviceName: String
    ) -> (applied: Bool, message: String) {
        log.notice("Applying static IP \(profile.staticIP, privacy: .public) for SSID: \(profile.ssid, privacy: .public)")

        // 1. Set static IPv4
        let setManual = Process()
        setManual.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        setManual.arguments = ["-setmanual", serviceName, profile.staticIP, profile.subnetMask, profile.router]
        do {
            try setManual.run()
            setManual.waitUntilExit()
            if setManual.terminationStatus != 0 {
                return (false, NSLocalizedString("Failed to set static IP", comment: ""))
            }
        } catch {
            return (false, error.localizedDescription)
        }

        // 2. Set DNS servers
        let setDNS = Process()
        setDNS.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        if profile.dnsServers.isEmpty {
            setDNS.arguments = ["-setdnsservers", serviceName, "Empty"]
        } else {
            setDNS.arguments = ["-setdnsservers", serviceName] + profile.dnsServers
        }
        try? setDNS.run()
        setDNS.waitUntilExit()

        let msg = String(format: NSLocalizedString("Static IP %@ successfully applied for %@", comment: ""), profile.staticIP, profile.ssid)
        return (true, msg)
    }

    private func restoreDHCP(
        serviceName: String,
        ssid: String
    ) -> (applied: Bool, message: String) {
        guard WiFiNetworkMonitor.checkIfManualConfig(serviceName: serviceName) else {
            return (false, NSLocalizedString("Already in DHCP mode", comment: ""))
        }

        log.notice("Switching to unconfigured SSID: \(ssid, privacy: .public). Restoring DHCP.")
        let setDHCP = Process()
        setDHCP.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        setDHCP.arguments = ["-setdhcp", serviceName]
        try? setDHCP.run()
        setDHCP.waitUntilExit()

        let clearDNS = Process()
        clearDNS.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        clearDNS.arguments = ["-setdnsservers", serviceName, "Empty"]
        try? clearDNS.run()
        clearDNS.waitUntilExit()

        return (true, String(format: NSLocalizedString("Restored DHCP for unconfigured Wi-Fi: %@", comment: ""), ssid))
    }
}
