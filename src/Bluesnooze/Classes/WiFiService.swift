//
//  WiFiService.swift
//  Bluesnooze
//
//  Created on 2026-10-20.
//

import CoreWLAN
import Foundation
import os

@MainActor
final class WiFiService {
    static let shared = WiFiService()

    private init() {}

    private var defaultInterface: CWInterface? {
        CWWiFiClient.shared().interface()
    }

    /// Query current Wi-Fi power state safely. Returns nil if no Wi-Fi interface is present.
    func isPowerOn() -> Bool? {
        guard let interface = defaultInterface else {
            Log.wifi.debug("No Wi-Fi interface available on this hardware")
            return nil
        }
        return interface.powerOn()
    }

    /// Set Wi-Fi interface power safely. Returns true if successful.
    @discardableResult
    func setPower(on: Bool) -> Bool {
        guard let interface = defaultInterface else {
            Log.wifi.error("Cannot set Wi-Fi power: No default interface available")
            return false
        }

        Log.wifi.notice("Setting Wi-Fi power on \(interface.interfaceName ?? "en", privacy: .public) to \(on, privacy: .public)")
        do {
            try interface.setPower(on)
            return true
        } catch {
            Log.wifi.error("Failed to set Wi-Fi power state: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
