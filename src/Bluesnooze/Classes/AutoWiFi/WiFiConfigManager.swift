//
//  WiFiConfigManager.swift
//  Bluesnooze
//
//  Created on 2026-10-23.
//

import Foundation

/// Manages reading, writing, and parsing of the Wi-Fi static IP configuration INI file.
actor WiFiConfigManager {
    static let shared = WiFiConfigManager()

    static let standardConfigURL = URL(fileURLWithPath: DaemonInfo.configPath)
    static let legacyConfigURL = URL(fileURLWithPath: DaemonInfo.legacyConfigPath)
    static let standardStateURL = URL(fileURLWithPath: DaemonInfo.statePath)
    static let legacyStateURL = URL(fileURLWithPath: DaemonInfo.legacyStatePath)

    private var appSupportURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = appSupport.appendingPathComponent("BlueNap", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("bluenap-wifi.conf")
    }

    init() {}

    /// Reads configuration from active configuration file or local fallback cache.
    func loadConfig() -> (global: GlobalConfig, profiles: [WiFiProfile]) {
        var content = ""
        let urlsToTry = [Self.standardConfigURL, Self.legacyConfigURL, appSupportURL]
        for url in urlsToTry {
            if FileManager.default.fileExists(atPath: url.path),
               let fileData = try? Data(contentsOf: url),
               let str = String(data: fileData, encoding: .utf8),
               !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                content = str
                break
            }
        }

        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let defaultGlobal = GlobalConfig(networkService: "Wi-Fi", wifiDevice: "en0", restoreDHCP: true, isBindingEnabled: true)
            return (defaultGlobal, [])
        }

        return parseINI(content)
    }

    /// Reads the last seen SSID from state file.
    func readLastSeenSSID() -> String? {
        let urlsToTry = [Self.standardStateURL, Self.legacyStateURL]
        for url in urlsToTry {
            if let data = try? Data(contentsOf: url),
               let str = String(data: data, encoding: .utf8) {
                let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    /// Saves configuration to file, syncing both system path and local backup.
    func saveConfig(global: GlobalConfig, profiles: [WiFiProfile]) throws {
        let text = serializeINI(global: global, profiles: profiles)

        // Always save local backup in Application Support
        try text.write(to: appSupportURL, atomically: true, encoding: .utf8)

        // Attempt writing directly to /usr/local/etc/bluenap-wifi.conf
        let stdPath = Self.standardConfigURL.path
        let etcDir = Self.standardConfigURL.deletingLastPathComponent().path

        var writeSucceeded = false
        let isDirectlyWritable = FileManager.default.isWritableFile(atPath: stdPath) ||
            (!FileManager.default.fileExists(atPath: stdPath) && FileManager.default.isWritableFile(atPath: etcDir))

        if isDirectlyWritable {
            do {
                try text.write(to: Self.standardConfigURL, atomically: true, encoding: .utf8)
                writeSucceeded = true
            } catch {
                writeSucceeded = false
            }
        }

        if !writeSucceeded {
            try writePrivilegedConfig(text: text)
        }
    }

    private func writePrivilegedConfig(text: String) throws {
        let tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bluenap_wifi_\(UUID().uuidString).conf")
        try text.write(to: tempFileURL, atomically: true, encoding: .utf8)

        let cmd = "mkdir -p /usr/local/etc && " +
            "cp '\(tempFileURL.path)' '\(DaemonInfo.configPath)' && " +
            "chmod 666 '\(DaemonInfo.configPath)' && " +
            "cp '\(tempFileURL.path)' '\(DaemonInfo.legacyConfigPath)' 2>/dev/null || true && " +
            "rm -f '\(tempFileURL.path)'"
        let script = "do shell script \"\(cmd)\" with administrator privileges"

        var errorInfo: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            _ = appleScript.executeAndReturnError(&errorInfo)
            if let error = errorInfo {
                let msg = error[NSAppleScript.errorMessage] as? String ?? NSLocalizedString("Authorization failed", comment: "")
                throw NSError(
                    domain: "BlueNap.WiFiConfigManager",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: msg]
                )
            }
        }
    }

    private struct ProfileDraft {
        var ip: String = ""
        var mask: String = "255.255.255.0"
        var router: String = ""
        var dns: [String] = []
        var isEnabled: Bool = true
    }

    /// Parses INI format string.
    func parseINI(_ content: String) -> (global: GlobalConfig, profiles: [WiFiProfile]) {
        var global = GlobalConfig()
        var profiles: [WiFiProfile] = []

        var currentSection: String?
        var draft = ProfileDraft()

        func commitCurrentSection() {
            guard let ssid = currentSection, !ssid.isEmpty else { return }
            let profile = WiFiProfile(
                ssid: ssid,
                staticIP: draft.ip,
                subnetMask: draft.mask.isEmpty ? "255.255.255.0" : draft.mask,
                router: draft.router,
                dnsServers: draft.dns,
                isEnabled: draft.isEnabled
            )
            profiles.append(profile)
        }

        for rawLine in content.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix(";") {
                continue
            }

            if line.hasPrefix("["), line.hasSuffix("]") {
                commitCurrentSection()
                currentSection = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                draft = ProfileDraft()
                continue
            }

            let parts = line.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            let (key, val) = (parts[0].uppercased(), parts[1])

            if currentSection == nil {
                applyGlobalKey(key, value: val, into: &global)
            } else {
                applyProfileKey(key, value: val, draft: &draft)
            }
        }
        commitCurrentSection()

        return (global, profiles)
    }

    private func applyGlobalKey(_ key: String, value: String, into global: inout GlobalConfig) {
        switch key {
        case "NETWORK_SERVICE": global.networkService = value
        case "WIFI_DEVICE": global.wifiDevice = value
        case "RESTORE_DHCP": global.restoreDHCP = (value == "1" || value.lowercased() == "true")
        case "BINDING_ENABLED": global.isBindingEnabled = (value == "1" || value.lowercased() == "true")
        default: break
        }
    }

    private func applyProfileKey(_ key: String, value: String, draft: inout ProfileDraft) {
        switch key {
        case "STATIC_IP": draft.ip = value
        case "SUBNET_MASK": draft.mask = value
        case "ROUTER": draft.router = value
        case "ENABLED": draft.isEnabled = (value == "1" || value.lowercased() == "true")
        case "DNS_SERVERS":
            draft.dns = value.split(whereSeparator: { $0.isWhitespace || $0 == "," })
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        default: break
        }
    }

    /// Serializes global settings and profiles into standard INI format.
    func serializeINI(global: GlobalConfig, profiles: [WiFiProfile]) -> String {
        var output = """
        # ==============================================================================
        # BlueNap AutoWiFi 静态网络配置
        # 纯事件驱动 0% CPU 守护服务配置文件
        # ==============================================================================

        NETWORK_SERVICE=\(global.networkService)
        WIFI_DEVICE=\(global.wifiDevice)
        RESTORE_DHCP=\(global.restoreDHCP ? "1" : "0")
        BINDING_ENABLED=\(global.isBindingEnabled ? "1" : "0")

        """

        for profile in profiles {
            output += "\n# Wi-Fi SSID: \(profile.ssid)\n"
            output += "[\(profile.ssid)]\n"
            output += "STATIC_IP=\(profile.staticIP)\n"
            output += "SUBNET_MASK=\(profile.subnetMask)\n"
            output += "ROUTER=\(profile.router)\n"
            output += "ENABLED=\(profile.isEnabled ? "1" : "0")\n"
            if !profile.dnsServers.isEmpty {
                output += "DNS_SERVERS=\(profile.dnsServers.joined(separator: " "))\n"
            } else {
                output += "DNS_SERVERS=\n"
            }
        }

        return output
    }
}
