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
                contentRect: NSRect(x: 0, y: 0, width: 580, height: 540),
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

    func captureScreenshot(to path: String) {
        guard let window, let contentView = window.contentView else {
            print("Capture failed: window or contentView is nil")
            return
        }
        contentView.layoutSubtreeIfNeeded()
        guard let rep = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds) else {
            print("Capture failed: bitmapImageRepForCachingDisplay returned nil for bounds: \(contentView.bounds)")
            return
        }
        contentView.cacheDisplay(in: contentView.bounds, to: rep)
        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            print("Capture failed: png representation nil")
            return
        }
        do {
            try pngData.write(to: URL(fileURLWithPath: path), options: .atomic)
            print("Successfully wrote \(pngData.count) bytes to \(path)")
        } catch {
            print("Capture failed to write file: \(error)")
        }
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_: Notification) {
        // Stop network monitor immediately to stop all observers and free resources
        WiFiNetworkMonitor.shared.stopMonitoring()

        // Clear view hierarchy and break all SwiftUI graph references
        window?.contentView = nil
        window?.delegate = nil
        window = nil

        // Clear transient state caches
        AppState.shared.pairedDevices.removeAll(keepingCapacity: false)
        URLCache.shared.removeAllCachedResponses()

        // Return to accessory mode when preferences window is closed
        NSApp.setActivationPolicy(.accessory)

        // Aggressive memory pressure relief & purge
        trimMemory()
    }

    private func trimMemory() {
        CATransaction.flush()
        malloc_zone_pressure_relief(nil, 0)
        malloc_zone_pressure_relief(malloc_default_zone(), 0)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            autoreleasepool {
                CATransaction.flush()
                malloc_zone_pressure_relief(nil, 0)
                malloc_zone_pressure_relief(malloc_default_zone(), 0)
            }
        }
    }
}
