//
//  WiFiDaemonManager.swift
//  Bluesnooze
//
//  Created on 2026-10-23.
//

import Cocoa
import Foundation

/// Manages the background LaunchDaemon switcher service lifecycle.
actor WiFiDaemonManager {
    static let shared = WiFiDaemonManager()

    init() {}

    /// Checks the current status of the LaunchDaemon.
    func checkStatus() -> DaemonInfo.Status {
        let plistExists = FileManager.default.fileExists(atPath: DaemonInfo.plistPath) ||
            FileManager.default.fileExists(atPath: DaemonInfo.legacyPlistPath)
        guard plistExists else {
            return .notInstalled
        }

        // Check if process is actively running via pgrep
        let pgrepProcess = Process()
        pgrepProcess.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        pgrepProcess.arguments = ["-f", "bluenap-wifid|wifi-static-ip-switcher.sh"]
        let pgrepPipe = Pipe()
        pgrepProcess.standardOutput = pgrepPipe
        do {
            try pgrepProcess.run()
            pgrepProcess.waitUntilExit()
            if pgrepProcess.terminationStatus == 0 {
                let data = pgrepPipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   let firstLine = output.components(separatedBy: .newlines).first,
                   let pid = Int(firstLine) {
                    return .running(pid: pid)
                }
                return .running(pid: nil)
            }
        } catch {}

        // Check launchctl print
        for label in [DaemonInfo.daemonLabel, DaemonInfo.legacyDaemonLabel] {
            let launchctlProcess = Process()
            launchctlProcess.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            launchctlProcess.arguments = ["print", "system/\(label)"]
            let lPipe = Pipe()
            launchctlProcess.standardOutput = lPipe
            launchctlProcess.standardError = Pipe()
            do {
                try launchctlProcess.run()
                launchctlProcess.waitUntilExit()
                if launchctlProcess.terminationStatus == 0 {
                    let data = lPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    if output.contains("state = running") {
                        return .running(pid: nil)
                    }
                }
            } catch {}
        }

        return .stopped
    }

    /// Installs the native LaunchDaemon and registers it with launchd using administrator privileges.
    func installService(daemonBinaryURL: URL, configText: String) throws {
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

        try executePrivilegedScript(script)
    }

    /// Starts or bootstraps the LaunchDaemon.
    func start() throws {
        let cmd = "/bin/launchctl bootstrap system '\(DaemonInfo.plistPath)' || " +
            "/bin/launchctl kickstart -k system/\(DaemonInfo.daemonLabel)"
        let script = "do shell script \"\(cmd)\" with administrator privileges"
        try executePrivilegedScript(script)
    }

    /// Stops the LaunchDaemon.
    func stop() throws {
        let cmd = "/bin/launchctl bootout system '\(DaemonInfo.plistPath)' 2>/dev/null || true"
        let script = "do shell script \"\(cmd)\" with administrator privileges"
        try executePrivilegedScript(script)
    }

    /// Restarts the LaunchDaemon.
    func restart() throws {
        let restartCmd = "/bin/launchctl kickstart -k system/\(DaemonInfo.daemonLabel) 2>/dev/null || " +
            "(/bin/launchctl bootout system '\(DaemonInfo.plistPath)' 2>/dev/null; " +
            "/bin/launchctl bootstrap system '\(DaemonInfo.plistPath)')"
        let script = "do shell script \"\(restartCmd)\" with administrator privileges"
        try executePrivilegedScript(script)
    }

    /// Uninstalls the service and removes daemon files.
    func uninstall(purgeConfig: Bool = false) throws {
        var cmd = "/bin/launchctl bootout system '\(DaemonInfo.plistPath)' 2>/dev/null || true && " +
            "/bin/launchctl bootout system '\(DaemonInfo.legacyPlistPath)' 2>/dev/null || true && " +
            "rm -f '\(DaemonInfo.plistPath)' '\(DaemonInfo.legacyPlistPath)' '\(DaemonInfo.daemonExecutablePath)'"
        if purgeConfig {
            cmd += " '\(DaemonInfo.configPath)' '\(DaemonInfo.legacyConfigPath)' '\(DaemonInfo.statePath)' '\(DaemonInfo.legacyStatePath)'"
        }
        let script = "do shell script \"\(cmd)\" with administrator privileges"
        try executePrivilegedScript(script)
    }

    private func executePrivilegedScript(_ scriptSource: String) throws {
        var errorInfo: NSDictionary?
        if let appleScript = NSAppleScript(source: scriptSource) {
            _ = appleScript.executeAndReturnError(&errorInfo)
            if let error = errorInfo {
                let msg = error[NSAppleScript.errorMessage] as? String ?? NSLocalizedString("Authorization failed", comment: "")
                throw NSError(domain: "BlueNap.WiFiDaemonManager", code: 2, userInfo: [NSLocalizedDescriptionKey: msg])
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
