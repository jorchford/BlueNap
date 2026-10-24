//
//  AboutPreferencesTab.swift
//  Bluesnooze
//
//  Created on 2026-10-20.
//

import SwiftUI

struct AboutPreferencesTab: View {
    var body: some View {
        VStack(spacing: 20) {
            liquidCard {
                VStack(spacing: 12) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: 72, height: 72)
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)

                    Text(NSLocalizedString("BlueNap", comment: ""))
                        .font(.title2.weight(.bold))

                    Text("Smart Bluetooth & Wi-Fi Power Manager for Mac")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Text("Swift 6 Strict Concurrency")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.18), in: Capsule())
                            .foregroundStyle(Color.orange)

                        Text("Liquid Glass")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.18), in: Capsule())
                            .foregroundStyle(Color.blue)
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }

            liquidCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("About This Application")
                        .font(.headline)

                    Text(
                        LocalizedStringKey(
                            "BlueNap prevents your sleeping Mac from intermittently connecting " +
                                "to paired Bluetooth accessories and disrupting your audio playback."
                        )
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)

                    Divider()

                    HStack {
                        Text("Official Website")
                            .font(.subheadline)
                        Spacer()
                        Button("app.needai.top") {
                            if let url = URL(string: "https://app.needai.top/app/bluenap") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                    }

                    Divider()

                    HStack {
                        Text("GitHub Repository")
                            .font(.subheadline)
                        Spacer()
                        Button("jorchford/BlueNap") {
                            if let url = URL(string: "https://github.com/jorchford/BlueNap") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                    }

                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("More Apps: Tactile (妙触)")
                                .font(.subheadline)
                            Text("120Hz ProMotion Multitouch Gestures")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("View on GitHub") {
                            if let url = URL(string: "https://github.com/jorchford/tactile") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                    }
                }
            }
        }
    }

    private func liquidCard(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}
