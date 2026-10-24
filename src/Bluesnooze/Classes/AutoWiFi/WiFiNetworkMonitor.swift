//
//  WiFiNetworkMonitor.swift
//  Bluesnooze
//
//  Created on 2026-10-23.
//

import Darwin
import Foundation
import IOKit
import Network
import SystemConfiguration

/// Pure event-driven network monitor. Consumes 0% CPU when idle.
final class WiFiNetworkMonitor: @unchecked Sendable {
    static let shared = WiFiNetworkMonitor()

    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.needai.bluenap.WiFiNetworkMonitor", qos: .utility)
    private var isRunning = false

    private init() {}

    /// Starts monitoring network changes. The callback is invoked on MainActor whenever network status changes.
    func startMonitoring(onChange: @escaping @MainActor @Sendable (NetworkSnapshot) -> Void) {
        guard !isRunning else { return }
        let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
        pathMonitor = monitor
        isRunning = true

        monitor.pathUpdateHandler = { [weak self] _ in
            guard let self else { return }
            let snapshot = captureCurrentSnapshot()
            Task { @MainActor in
                onChange(snapshot)
            }
        }
        monitor.start(queue: monitorQueue)
    }

    /// Stops monitoring to conserve battery and system resources.
    func stopMonitoring() {
        guard isRunning else { return }
        pathMonitor?.cancel()
        pathMonitor = nil
        isRunning = false
    }

    /// Captures a complete snapshot of current network state.
    func captureCurrentSnapshot(device: String = "en0", serviceName: String = "Wi-Fi") -> NetworkSnapshot {
        let ssid = Self.fetchCurrentSSID()
        let (ip, mask) = Self.fetchIPv4AndMask(for: device)
        let router = Self.fetchDefaultGateway()
        let dns = Self.fetchDNSServers()
        let isManual = Self.checkIfManualConfig(serviceName: serviceName)
        let lastSeen = (try? String(contentsOfFile: DaemonInfo.statePath, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return NetworkSnapshot(
            connectedSSID: ssid,
            currentIPv4: ip,
            currentNetmask: mask,
            currentRouter: router,
            currentDNS: dns,
            isManualConfiguration: isManual,
            lastSeenSSID: (lastSeen?.isEmpty == false) ? lastSeen : nil,
            matchedProfile: nil,
            timestamp: Date()
        )
    }

    /// Fetches the currently connected Wi-Fi SSID via native IOKit registry without location prompts.
    static func fetchCurrentSSID() -> String? {
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
                    let cfKey = "IO80211SSID" as CFString
                    if let prop = IORegistryEntryCreateCFProperty(entry, cfKey, kCFAllocatorDefault, 0)?.takeRetainedValue() {
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

        // Fast fallback via ioreg CLI
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        let cmd = "/usr/sbin/ioreg -r -k IO80211SSID 2>/dev/null | /usr/bin/awk -F '\"' '/\"IO80211SSID\" = \"/ {print $4; exit}'"
        process.arguments = ["-c", cmd]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
                return output
            }
        } catch {}

        return nil
    }

    /// Retrieves IPv4 address and subnet mask using `getifaddrs`.
    static func fetchIPv4AndMask(for interfaceName: String) -> (ip: String?, mask: String?) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return (nil, nil) }
        defer { freeifaddrs(ifaddr) }

        var current: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let ptr = current {
            let flags = Int32(ptr.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) == IFF_UP
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK
            let family = ptr.pointee.ifa_addr.pointee.sa_family

            if isUp, !isLoopback, family == UInt8(AF_INET) {
                let name = String(cString: ptr.pointee.ifa_name)
                if name == interfaceName {
                    var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    var maskBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))

                    _ = getnameinfo(ptr.pointee.ifa_addr, socklen_t(ptr.pointee.ifa_addr.pointee.sa_len),
                                    &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NUMERICHOST)
                    _ = getnameinfo(ptr.pointee.ifa_netmask, socklen_t(ptr.pointee.ifa_netmask.pointee.sa_len),
                                    &maskBuffer, socklen_t(maskBuffer.count), nil, 0, NI_NUMERICHOST)

                    let ipStr = hostBuffer.withUnsafeBufferPointer { ptr in
                        ptr.baseAddress.map { String(cString: $0) } ?? ""
                    }
                    let maskStr = maskBuffer.withUnsafeBufferPointer { ptr in
                        ptr.baseAddress.map { String(cString: $0) } ?? ""
                    }
                    return (ipStr.isEmpty ? nil : ipStr, maskStr.isEmpty ? nil : maskStr)
                }
            }
            current = ptr.pointee.ifa_next
        }
        return (nil, nil)
    }

    /// Fetches the default router gateway.
    static func fetchDefaultGateway() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "route -n get default 2>/dev/null | awk '/gateway:/{print $2}'"]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
                return output
            }
        } catch {}
        return nil
    }

    /// Retrieves current DNS servers via SCDynamicStore.
    static func fetchDNSServers() -> [String] {
        guard let store = SCDynamicStoreCreate(kCFAllocatorDefault, "WiFiNetworkMonitor" as CFString, nil, nil),
              let dict = SCDynamicStoreCopyValue(store, "State:/Network/Global/DNS" as CFString) as? [String: Any],
              let servers = dict["ServerAddresses"] as? [String]
        else {
            return []
        }
        return servers
    }

    /// Checks whether the network service is currently configured with Manual Static IP.
    static func checkIfManualConfig(serviceName: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = ["-getinfo", serviceName]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.contains("Manual Configuration")
        } catch {}
        return false
    }
}
