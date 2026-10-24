//
//  DaemonInfo.swift
//  Bluesnooze
//
//  Created on 2026-10-23.
//

import Foundation

/// State of the background LaunchDaemon switcher service.
struct DaemonInfo: Sendable, Hashable {
    enum Status: Sendable, Hashable {
        case running(pid: Int?)
        case stopped
        case notInstalled
        case unknown(String)

        var displayText: String {
            switch self {
            case let .running(pid):
                if let pid {
                    return String(format: NSLocalizedString("Running (PID: %d)", comment: ""), pid)
                }
                return NSLocalizedString("Running", comment: "")
            case .stopped:
                return NSLocalizedString("Stopped", comment: "")
            case .notInstalled:
                return NSLocalizedString("Not Installed", comment: "")
            case let .unknown(msg):
                return String(format: NSLocalizedString("Unknown: %@", comment: ""), msg)
            }
        }

        var isHealthy: Bool {
            if case .running = self {
                return true
            }
            return false
        }
    }

    static let daemonLabel = "com.needai.bluenap.wifid"
    static let legacyDaemonLabel = "com.local.wifi-static-ip-switcher"
    static let plistPath = "/Library/LaunchDaemons/com.needai.bluenap.wifid.plist"
    static let legacyPlistPath = "/Library/LaunchDaemons/com.local.wifi-static-ip-switcher.plist"
    static let daemonExecutablePath = "/usr/local/libexec/bluenap/bluenap-wifid"
    static let configPath = "/usr/local/etc/bluenap-wifi.conf"
    static let legacyConfigPath = "/usr/local/etc/wifi-static-ip-switcher.conf"
    static let statePath = "/usr/local/etc/bluenap-wifi.state"
    static let legacyStatePath = "/usr/local/etc/wifi-static-ip-switcher.state"

    var status: Status
    var lastCheckDate: Date

    init(status: Status = .unknown("Initializing"), lastCheckDate: Date = Date()) {
        self.status = status
        self.lastCheckDate = lastCheckDate
    }
}
