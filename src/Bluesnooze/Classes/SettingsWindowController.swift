//
//  SettingsWindowController.swift
//  Bluesnooze
//
//  Created on 2026-10-20.
//

import Cocoa
import Darwin
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private init() {
        super.init(window: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showSettings() {
        if window == nil {
            let hostingView = NSHostingView(rootView: PreferencesView())
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 580, height: 480),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = NSLocalizedString("BlueNap Settings", comment: "")
            window.contentView = hostingView
            window.isReleasedWhenClosed = false
            window.titlebarAppearsTransparent = true
            window.delegate = self
            self.window = window
        }

        guard let window else { return }

        // Switch to regular activation policy so the settings window can become key and accept input
        NSApp.setActivationPolicy(.regular)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_: Notification) {
        // Return to accessory mode when preferences window is closed
        NSApp.setActivationPolicy(.accessory)
        window?.contentView = nil
        window = nil
        malloc_zone_pressure_relief(nil, 0)
        DispatchQueue.main.async {
            malloc_zone_pressure_relief(nil, 0)
        }
    }
}
