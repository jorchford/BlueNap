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

    private var hostingController: NSHostingController<AnyView>?

    var isWindowVisible: Bool {
        window?.isVisible == true
    }

    private init() {
        super.init(window: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showSettings() {
        if window == nil {
            let controller = NSHostingController(rootView: AnyView(PreferencesView()))
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 550),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = NSLocalizedString("BlueNap Settings", comment: "")
            window.contentViewController = controller
            window.isReleasedWhenClosed = false
            window.titlebarAppearsTransparent = true
            window.delegate = self
            self.hostingController = controller
            self.window = window
        }

        guard let window else { return }

        // Cancel any pending auto-hide countdown while settings window is open
        AppDelegate.shared?.cancelAutoHideTimer()

        // Switch to regular activation policy so the settings window can become key and accept input
        NSApp.setActivationPolicy(.regular)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func updateWindowTitle() {
        window?.title = NSLocalizedString("BlueNap Settings", comment: "")
    }

    func closeSettings() {
        guard let win = window else { return }
        windowWillClose(Notification(name: NSWindow.willCloseNotification, object: win))
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
        // Stop all background timers & monitors immediately
        WiFiNetworkMonitor.shared.stopMonitoring()

        // CRITICAL: Replace SwiftUI graph with EmptyView to force complete teardown of ViewGraph,
        // state observation subscriptions, display lists, and cached layouts
        hostingController?.rootView = AnyView(EmptyView())
        hostingController?.view.removeFromSuperview()
        hostingController = nil

        if let win = window {
            win.contentViewController = nil
            win.contentView = nil
            win.delegate = nil
            win.orderOut(nil)
            win.close()
        }
        window = nil

        // Clear transient state caches
        AppState.shared.pairedDevices.removeAll(keepingCapacity: false)
        URLCache.shared.removeAllCachedResponses()

        // Return to accessory mode when preferences window is closed
        NSApp.setActivationPolicy(.accessory)

        // Resume auto-hide timer if configured
        AppDelegate.shared?.scheduleAutoHideTimerIfNeeded()

        // Perform aggressive multi-pass memory reclamation
        performDeepMemoryPurge()
    }

    func performDeepMemoryPurge() {
        // 1. Flush CoreAnimation transaction to commit view removals
        CATransaction.flush()

        // 2. Clear AppKit / Cocoa internal caches
        URLCache.shared.removeAllCachedResponses()
        NSAnimationContext.beginGrouping()
        CATransaction.flush()
        NSAnimationContext.endGrouping()

        // 3. Purge all Darwin malloc zones
        purgeAllMallocZones()

        // 4. Multi-stage deferred purge to catch async release loops
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            autoreleasepool {
                CATransaction.flush()
                self?.purgeAllMallocZones()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            autoreleasepool {
                CATransaction.flush()
                self?.purgeAllMallocZones()
            }
        }
    }

    private func purgeAllMallocZones() {
        var count: UInt32 = 0
        var zoneList: UnsafeMutablePointer<vm_address_t>?
        if malloc_get_all_zones(mach_task_self_, nil, &zoneList, &count) == KERN_SUCCESS, let list = zoneList {
            for i in 0 ..< Int(count) {
                if let zone = UnsafeMutablePointer<malloc_zone_t>(bitPattern: list[i]) {
                    malloc_zone_pressure_relief(zone, 0)
                }
            }
        }
        malloc_zone_pressure_relief(nil, 0)
    }
}
