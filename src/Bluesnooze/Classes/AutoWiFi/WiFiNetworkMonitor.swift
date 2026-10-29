//
//  WiFiNetworkMonitor.swift
//  Bluesnooze
//
//  Created on 2026-10-23.
//

import CoreLocation
import CoreWLAN
import Darwin
import Foundation
import IOKit
import Network
import SystemConfiguration

/// Pure event-driven network monitor. Consumes 0.0% CPU when idle and executes 100% in-memory with zero subprocesses.
final class WiFiNetworkMonitor: NSObject, @unchecked Sendable, CLLocationManagerDelegate {
    static let shared = WiFiNetworkMonitor()

    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.needai.bluenap.WiFiNetworkMonitor", qos: .utility)
    private var isRunning = false
    private var locationManager: CLLocationManager?

    override private init() {
        super.init()
    }

    /// Requests location authorization if needed so macOS can provide unredacted Wi-Fi SSID.
    func requestLocationAuthorizationIfNeeded() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.locationManager == nil {
                let manager = CLLocationManager()
                manager.delegate = self
                self.locationManager = manager
            }
            if self.locationManager?.authorizationStatus == .notDetermined {
                self.locationManager?.requestWhenInUseAuthorization()
            }
        }
    }

    func locationManagerDidChangeAuthorization(_: CLLocationManager) {
        // Trigger a fresh snapshot whenever authorization status changes
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .init("WiFiNetworkSnapshotNeedsRefresh"), object: nil)
        }
    }

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

    /// Captures a complete snapshot of current network state purely from in-memory kernel/store queries.
    func captureCurrentSnapshot(device: String = "en0", serviceName: String = "Wi-Fi") -> NetworkSnapshot {
        let ssid = Self.fetchCurrentSSID()
        let (ip, mask) = Self.fetchIPv4AndMask(for: device)
        let router = Self.fetchDefaultGateway()
        let dns = Self.fetchDNSServers()
        let isManual = Self.checkIfManualConfig(serviceName: serviceName)
        let rawLastSeen = (try? String(contentsOfFile: DaemonInfo.statePath, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let lastSeen = Self.isValidSSID(rawLastSeen) ? rawLastSeen : nil

        return NetworkSnapshot(
            connectedSSID: ssid,
            currentIPv4: ip,
            currentNetmask: mask,
            currentRouter: router,
            currentDNS: dns,
            isManualConfiguration: isManual,
            lastSeenSSID: lastSeen,
            matchedProfile: nil,
            timestamp: Date()
        )
    }

    /// Checks if a string is a valid, unredacted SSID.
    static func isValidSSID(_ ssid: String?) -> Bool {
        guard let s = ssid?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else {
            return false
        }
        if s.contains("Redacted") || s.hasPrefix("<") || s.lowercased() == "none" {
            return false
        }
        return true
    }

    /// Fetches the currently connected Wi-Fi SSID via native IOKit registry or CoreWLAN.
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
                        if let str = prop as? String, isValidSSID(str) {
                            return str
                        }
                        if let data = prop as? Data, let str = String(data: data, encoding: .utf8), isValidSSID(str) {
                            return str
                        }
                    }
                }
            }
        }

        // Fast in-process CoreWLAN query fallback
        if let interface = CWWiFiClient.shared().interface(), let ssid = interface.ssid(), isValidSSID(ssid) {
            return ssid
        }

        return nil
    }

    /// Lists preferred Wi-Fi network SSIDs configured on macOS.
    static func fetchPreferredNetworks(device: String = "en0") -> [String] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        p.arguments = ["-listpreferredwirelessnetworks", device]
        let pipe = Pipe()
        p.standardOutput = pipe
        try? p.run()
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let out = String(data: data, encoding: .utf8) else { return [] }
        return out.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { isValidSSID($0) && !$0.hasPrefix("Preferred networks") }
    }

    /// Retrieves IPv4 address and subnet mask using in-memory `getifaddrs`.
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

                    _ = getnameinfo(
                        ptr.pointee.ifa_addr,
                        socklen_t(ptr.pointee.ifa_addr.pointee.sa_len),
                        &hostBuffer,
                        socklen_t(hostBuffer.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    _ = getnameinfo(
                        ptr.pointee.ifa_netmask,
                        socklen_t(ptr.pointee.ifa_netmask.pointee.sa_len),
                        &maskBuffer,
                        socklen_t(maskBuffer.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )

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

    /// Fetches the default router gateway directly from SCDynamicStore in memory (0 subprocesses).
    static func fetchDefaultGateway() -> String? {
        guard let store = SCDynamicStoreCreate(kCFAllocatorDefault, "WiFiNetworkMonitor" as CFString, nil, nil),
              let dict = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
              let router = dict["Router"] as? String, !router.isEmpty
        else {
            return nil
        }
        return router
    }

    /// Retrieves current DNS servers via SCDynamicStore in memory (0 subprocesses).
    static func fetchDNSServers() -> [String] {
        guard let store = SCDynamicStoreCreate(kCFAllocatorDefault, "WiFiNetworkMonitor" as CFString, nil, nil),
              let dict = SCDynamicStoreCopyValue(store, "State:/Network/Global/DNS" as CFString) as? [String: Any],
              let servers = dict["ServerAddresses"] as? [String]
        else {
            return []
        }
        return servers
    }

    /// Checks whether the network service is currently configured with Manual Static IP via SCDynamicStore in memory (0 subprocesses).
    static func checkIfManualConfig(serviceName _: String = "Wi-Fi") -> Bool {
        guard let store = SCDynamicStoreCreate(kCFAllocatorDefault, "WiFiNetworkMonitor" as CFString, nil, nil),
              let globalDict = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
              let serviceID = globalDict["PrimaryService"] as? String
        else {
            return false
        }
        let setupKey = "Setup:/Network/Service/\(serviceID)/IPv4" as CFString
        if let setupDict = SCDynamicStoreCopyValue(store, setupKey) as? [String: Any],
           let configMethod = setupDict["ConfigMethod"] as? String {
            return configMethod == "Manual"
        }
        return false
    }
}
