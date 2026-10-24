//
//  WiFiDaemonManager.swift
//  Bluesnooze
//
//  Created on 2026-10-23.
//

import Cocoa
import Darwin
import Foundation

/// Manages the background LaunchDaemon switcher service lifecycle.
actor WiFiDaemonManager {
    static let shared = WiFiDaemonManager()

    init() {}

    /// Checks the current status of the LaunchDaemon using in-memory Darwin libproc (0 subprocesses).
    func checkStatus() -> DaemonInfo.Status {
        let plistExists = FileManager.default.fileExists(atPath: DaemonInfo.plistPath) ||
            FileManager.default.fileExists(atPath: DaemonInfo.legacyPlistPath)
        guard plistExists else {
            return .notInstalled
        }

        // Query active processes purely in memory via libproc
        var pids = [pid_t](repeating: 0, count: 2048)
        let bytesUsed = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.stride * pids.count))
        let count = Int(bytesUsed) / MemoryLayout<pid_t>.stride

        for index in 0 ..< count {
            let pid = pids[index]
            guard pid > 0 else { continue }
            var buffer = [CChar](repeating: 0, count: 4096)
            let nameLen = Int(proc_name(pid, &buffer, UInt32(buffer.count)))
            if nameLen > 0 {
                let name = buffer.withUnsafeBufferPointer { ptr in
                    ptr.baseAddress.map { String(cString: $0) } ?? ""
                }
                if name.contains("bluenap-wifid") || name.contains("wifi-static-ip-switcher") {
                    return .running(pid: Int(pid))
                }
            }
        }

        return .stopped
    }

    /// Installs the native LaunchDaemon and registers it with launchd using administrator privileges.
    func installService(daemonBinaryURL: URL, configText: String) async throws {
        let tempConfigURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bluenap_install_\(UUID().uuidString).conf")
        try configText.write(to: tempConfigURL, atomically: true, encoding: .utf8)

        let plistContent = generatePlistContent()
        let tempPlistURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("com.needai.bluenap.wifid.plist")
        try plistContent.write(to: tempPlistURL, atomically: true, encoding: .utf8)

        let cmd = "mkdir -p /usr/local/libexec/bluenap /usr/local/etc /Library/LaunchDaemons && " +
            "cp '\(daemonBinaryURL.path)' '\(DaemonInfo.daemonExecutablePath)' && " +
            "chmod 755 '\(DaemonInfo.daemonExecutablePath)' && " +
            "cp '\(tempConfigURL.path)' '\(DaemonInfo.configPath)' && " +
            "chmod 666 '\(DaemonInfo.configPath)' && " +
            "cp '\(tempPlistURL.path)' '\(DaemonInfo.plistPath)' && " +
            "chown root:wheel '\(DaemonInfo.plistPath)' && " +
            "chmod 644 '\(DaemonInfo.plistPath)' && " +
            "rm -f '\(tempConfigURL.path)' '\(tempPlistURL.path)' && " +
            "/bin/launchctl bootout system '\(DaemonInfo.plistPath)' 2>/dev/null || true && " +
            "/bin/launchctl bootstrap system '\(DaemonInfo.plistPath)'"
        let script = "do shell script \"\(cmd)\" with administrator privileges"

        try await executePrivilegedScript(script)
    }

    /// Starts or bootstraps the LaunchDaemon.
    func start() async throws {
        let cmd = "/bin/launchctl bootstrap system '\(DaemonInfo.plistPath)' || " +
            "/bin/launchctl kickstart -k system/\(DaemonInfo.daemonLabel)"
        let script = "do shell script \"\(cmd)\" with administrator privileges"
        try await executePrivilegedScript(script)
    }

    /// Stops or bootouts the LaunchDaemon.
    func stop() async throws {
        let cmd = "/bin/launchctl bootout system '\(DaemonInfo.plistPath)' 2>/dev/null || " +
            "/bin/launchctl bootout system '\(DaemonInfo.legacyPlistPath)' 2>/dev/null || true"
        let script = "do shell script \"\(cmd)\" with administrator privileges"
        try await executePrivilegedScript(script)
    }

    /// Restarts the LaunchDaemon service.
    func restart() async throws {
        let kickstartLegacy = "/bin/launchctl kickstart -k system/\(DaemonInfo.legacyDaemonLabel) 2>/dev/null || "
        let fallbackReload = "(/bin/launchctl bootout system '\(DaemonInfo.plistPath)' 2>/dev/null; " +
            "/bin/launchctl bootstrap system '\(DaemonInfo.plistPath)')"
        let cmd = "/bin/launchctl kickstart -k system/\(DaemonInfo.daemonLabel) 2>/dev/null || " +
            kickstartLegacy + fallbackReload
        let script = "do shell script \"\(cmd)\" with administrator privileges"
        try await executePrivilegedScript(script)
    }

    /// Uninstalls the service and removes daemon files.
    func uninstall(purgeConfig: Bool = false) async throws {
        var cmd = "/bin/launchctl bootout system '\(DaemonInfo.plistPath)' 2>/dev/null || true && " +
            "/bin/launchctl bootout system '\(DaemonInfo.legacyPlistPath)' 2>/dev/null || true && " +
            "rm -f '\(DaemonInfo.plistPath)' '\(DaemonInfo.legacyPlistPath)' '\(DaemonInfo.daemonExecutablePath)'"
        if purgeConfig {
            cmd += " '\(DaemonInfo.configPath)' '\(DaemonInfo.legacyConfigPath)' '\(DaemonInfo.statePath)' '\(DaemonInfo.legacyStatePath)'"
        }
        let script = "do shell script \"\(cmd)\" with administrator privileges"
        try await executePrivilegedScript(script)
    }

    private func executePrivilegedScript(_ scriptSource: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .utility).async {
                var errorInfo: NSDictionary?
                if let appleScript = NSAppleScript(source: scriptSource) {
                    _ = appleScript.executeAndReturnError(&errorInfo)
                    if let error = errorInfo {
                        let msg = error[NSAppleScript.errorMessage] as? String ?? NSLocalizedString("Authorization failed", comment: "")
                        continuation.resume(
                            throwing: NSError(
                                domain: "BlueNap.WiFiDaemonManager",
                                code: 2,
                                userInfo: [NSLocalizedDescriptionKey: msg]
                            )
                        )
                        return
                    }
                }
                continuation.resume(returning: ())
            }
        }
    }

    private func generatePlistContent() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(DaemonInfo.daemonLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(DaemonInfo.daemonExecutablePath)</string>
                <string>service</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>ProcessType</key>
            <string>Background</string>
            <key>ThrottleInterval</key>
            <integer>5</integer>
        </dict>
        </plist>
        """
    }
}
