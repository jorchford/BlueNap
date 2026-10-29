//
//  Log.swift
//  Bluesnooze
//
//  Created on 2026-10-18.
//

import Foundation
import os

enum Log: Sendable {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.needai.bluesnooze"

    static let bluetooth = Logger(subsystem: subsystem, category: "bluetooth")
    static let wifi = Logger(subsystem: subsystem, category: "wifi")
    static let power = Logger(subsystem: subsystem, category: "power")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let state = Logger(subsystem: subsystem, category: "state")
    static let app = Logger(subsystem: subsystem, category: "app")
}
