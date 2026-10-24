//
//  main.swift
//  BlueNap WiFi Daemon (bluenap-wifid)
//
//  Event-driven, 0.0% CPU Wi-Fi Static IP Auto-Switcher Daemon for macOS.
//  Replaces legacy shell script loops with native SCDynamicStore notifications.
//

import Darwin
import Foundation
import IOKit
import os
import SystemConfiguration

let log = Logger(subsystem: "com.needai.bluenap", category: "WiFiDaemon")

final class BlueNapWiFiDaemonCore: @unchecked Sendable {
    static let shared = BlueNapWiFiDaemonCore()

    let configPath = "/usr/local/etc/bluenap-wifi.conf"
    let legacyConfigPath = "/usr/local/etc/wifi-static-ip-switcher.conf"
    let statePath = "/usr/local/etc/bluenap-wifi.state"

    struct Profile {
        var ssid: String
        var staticIP: String
        var subnetMask: String
        var router: String
        var dnsServers: [String]
        var isEnabled: Bool
    }

    struct Config {
        var networkService: String = "Wi-Fi"
        var wifiDevice: String = "en0"
        var restoreDHCP: Bool = true
        var isBindingEnabled: Bool = true
        var profiles: [Profile] = []
    }

    private init() {}

    func loadConfig() -> Config {
        var content = ""
        for path in [configPath, legacyConfigPath] {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let str = String(data: data, encoding: .utf8),
               !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                content = str
                break
            }
        }

        var config = Config()
        guard !content.isEmpty else { return config }

        var currentSection: String?
        var currentIP = ""
        var currentMask = "255.255.255.0"
        var currentRouter = ""
        var currentDNS: [String] = []
        var currentEnabled = true

        func commit() {
            guard let ssid = currentSection, !ssid.isEmpty else { return }
            let p = Profile(
                ssid: ssid,
                staticIP: currentIP,
                subnetMask: currentMask.isEmpty ? "255.255.255.0" : currentMask,
                router: currentRouter,
                dnsServers: currentDNS,
                isEnabled: currentEnabled
            )
            config.profiles.append(p)
        }

        for rawLine in content.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix(";") {
                continue
            }

            if line.hasPrefix("["), line.hasSuffix("]") {
                commit()
                currentSection = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                currentIP = ""
                currentMask = "255.255.255.0"
                currentRouter = ""
                currentDNS = []
                currentEnabled = true
                continue
            }

            let parts = line.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            let (key, val) = (parts[0].uppercased(), parts[1])

            if currentSection == nil {
                switch key {
                case "NETWORK_SERVICE": config.networkService = val
                case "WIFI_DEVICE": config.wifiDevice = val
                case "RESTORE_DHCP": config.restoreDHCP = (val == "1" || val.lowercased() == "true")
                case "BINDING_ENABLED": config.isBindingEnabled = (val == "1" || val.lowercased() == "true")
                default: break
                }
            } else {
                switch key {
                case "STATIC_IP": currentIP = val
                case "SUBNET_MASK": currentMask = val
                case "ROUTER": currentRouter = val
                case "ENABLED": currentEnabled = (val == "1" || val.lowercased() == "true")
                case "DNS_SERVERS":
                    currentDNS = val.split(whereSeparator: { $0.isWhitespace || $0 == "," })
                        .map { String($0).trimmingCharacters(in: .whitespaces) }
                default: break
                }
            }
        }
        commit()
        return config
    }

    func fetchCurrentSSID() -> String? {
        let classesToTry = ["IOUserNetworkWLAN", "IO80211Interface", "AppleBCMWLANSkywalkInterface"]
        for className in classesToTry {
            var iterator: io_iterator_t = 0
            let matchingDict = IOServiceMatching(className)
            if IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) == KERN_SUCCESS {
                defer { IOObjectRelease(iterator) }
                var entry = IOIteratorNext(iterator)
                while entry != 0 {
                    defer {
                        IOObjectRelease(entry)
                        entry = IOIteratorNext(iterator)
                    }
                    if let prop = IORegistryEntryCreateCFProperty(entry, "IO80211SSID" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() {
                        if let str = prop as? String, !str.isEmpty {
                            return str
                        }
                        if let data = prop as? Data, let str = String(data: data, encoding: .utf8), !str.isEmpty {
                            return str
                        }
                    }
                }
            }
        }
        return nil
    }

    func isManualConfiguration(service: String) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        p.arguments = ["-getinfo", service]
        let pipe = Pipe()
        p.standardOutput = pipe
        try? p.run()
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8) ?? ""
        return out.contains("Manual Configuration")
    }

    func evaluateAndApply() {
        let config = loadConfig()
        guard let ssid = fetchCurrentSSID(), !ssid.isEmpty else {
            // Wi-Fi disconnected: preserve current configuration, do NOT switch to DHCP
            return
        }

        // Save last seen SSID
        try? FileManager.default.createDirectory(atPath: "/usr/local/etc", withIntermediateDirectories: true)
        try? ssid.write(toFile: statePath, atomically: true, encoding: .utf8)

        // Check master binding switch
        guard config.isBindingEnabled else {
            log.info("Auto-binding switch is OFF. Preserving network configuration for \(ssid, privacy: .public)")
            return
        }

        if let match = config.profiles.first(where: { $0.ssid == ssid }) {
            guard match.isEnabled else {
                log.info("Profile for \(ssid, privacy: .public) is paused.")
                return
            }

            log.notice("Applying static IP \(match.staticIP, privacy: .public) for SSID: \(ssid, privacy: .public)")
            let p1 = Process()
            p1.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
            p1.arguments = ["-setmanual", config.networkService, match.staticIP, match.subnetMask, match.router]
            try? p1.run()
            p1.waitUntilExit()

            let p2 = Process()
            p2.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
            if match.dnsServers.isEmpty {
                p2.arguments = ["-setdnsservers", config.networkService, "Empty"]
            } else {
                p2.arguments = ["-setdnsservers", config.networkService] + match.dnsServers
            }
            try? p2.run()
            p2.waitUntilExit()
            log.notice("Static IP applied successfully.")
        } else {
            // Unconfigured SSID
            if config.restoreDHCP, isManualConfiguration(service: config.networkService) {
                log.notice("Switching to unconfigured SSID: \(ssid, privacy: .public). Restoring DHCP.")
                let p1 = Process()
                p1.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
                p1.arguments = ["-setdhcp", config.networkService]
                try? p1.run()
                p1.waitUntilExit()

                let p2 = Process()
                p2.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
                p2.arguments = ["-setdnsservers", config.networkService, "Empty"]
                try? p2.run()
                p2.waitUntilExit()
                log.notice("DHCP restored successfully.")
            }
        }
    }
}

/// Global Callback for SCDynamicStore
func dynamicStoreCallback(
    _: SCDynamicStore,
    _: CFArray,
    _: UnsafeMutableRawPointer?
) {
    // Debounce 1.0 second to allow Wi-Fi association and hardware handshake to settle
    DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
        BlueNapWiFiDaemonCore.shared.evaluateAndApply()
    }
}

let args = CommandLine.arguments
let mode = args.count > 1 ? args[1] : "service"

switch mode {
case "once":
    BlueNapWiFiDaemonCore.shared.evaluateAndApply()
    print("BlueNap WiFi rule evaluated and applied once.")
    exit(0)

case "status":
    let core = BlueNapWiFiDaemonCore.shared
    let config = core.loadConfig()
    let ssid = core.fetchCurrentSSID() ?? "None"
    let manual = core.isManualConfiguration(service: config.networkService)
    print("Service: \(config.networkService), Interface: \(config.wifiDevice)")
    print("Binding Enabled: \(config.isBindingEnabled), Restore DHCP: \(config.restoreDHCP)")
    print("Active SSID: \(ssid), Mode: \(manual ? "Static IP" : "DHCP")")
    print("Configured SSIDs: \(config.profiles.map(\.ssid).joined(separator: ", "))")
    exit(0)

default: // "service"
    signal(SIGTERM) { _ in
        log.notice("BlueNap WiFi Daemon received SIGTERM, exiting.")
        exit(0)
    }
    signal(SIGINT) { _ in
        log.notice("BlueNap WiFi Daemon received SIGINT, exiting.")
        exit(0)
    }

    log.notice("BlueNap WiFi Daemon started (Event-driven SCDynamicStore 0% CPU mode).")
    BlueNapWiFiDaemonCore.shared.evaluateAndApply()

    var context = SCDynamicStoreContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
    guard let store = SCDynamicStoreCreate(kCFAllocatorDefault, "com.needai.bluenap.wifid" as CFString, dynamicStoreCallback, &context) else {
        log.error("Failed to create SCDynamicStore. Exiting.")
        exit(1)
    }

    let patterns = [
        "State:/Network/Interface/.*/.*" as CFString,
        "State:/Network/Global/IPv4" as CFString
    ] as CFArray

    SCDynamicStoreSetNotificationKeys(store, nil, patterns)
    guard let runLoopSource = SCDynamicStoreCreateRunLoopSource(kCFAllocatorDefault, store, 0) else {
        log.error("Failed to create RunLoopSource for SCDynamicStore.")
        exit(1)
    }

    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
    CFRunLoopRun()
}
