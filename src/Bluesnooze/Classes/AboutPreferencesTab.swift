//
//  AboutPreferencesTab.swift
//  Bluesnooze
//
//  Created on 2026-10-20.
//

import SwiftUI

struct AboutPreferencesTab: View {
    var body: some View {
        VStack(spacing: 18) {
            // Hero / Brand Card
            liquidCard {
                VStack(spacing: 12) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: 72, height: 72)
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)

                    Text(NSLocalizedString("BlueNap", comment: ""))
                        .font(.title2.weight(.bold))

                    Text(NSLocalizedString("Smart Bluetooth & Wi-Fi Power Manager for Mac", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Text(NSLocalizedString("Swift 6 Strict Concurrency", comment: ""))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.18), in: Capsule())
                            .foregroundStyle(Color.orange)

                        Text(NSLocalizedString("Liquid Glass", comment: ""))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.18), in: Capsule())
                            .foregroundStyle(Color.blue)

                        Text(NSLocalizedString("macOS 27 Tested", comment: ""))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.18), in: Capsule())
                            .foregroundStyle(Color.purple)
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            // Featured Recommendation Card: Tactile (秒触)
            liquidCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.purple)

                        Text(NSLocalizedString("Featured Recommendation", comment: ""))
                            .font(.headline)

                        Spacer()

                        Text("120Hz ProMotion")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(Color.purple.opacity(0.14), in: Capsule())
                            .foregroundStyle(Color.purple)
                    }

                    HStack(alignment: .center, spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [Color.accentColor, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 48, height: 48)
                                .shadow(color: Color.accentColor.opacity(0.35), radius: 6, x: 0, y: 3)

                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text("Tactile (妙触)")
                                    .font(.system(size: 14, weight: .bold))

                                Text("PRO")
                                    .font(.system(size: 9.5, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Color.green, in: Capsule())
                            }

                            Text(
                                NSLocalizedString(
                                    "120Hz ProMotion Multitouch & Gesture Powerhouse for macOS",
                                    comment: ""
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        }

                        Spacer()

                        Button {
                            if let url = URL(string: "https://app.needai.top/app/tactile") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "safari.fill")
                                    .font(.system(size: 11))
                                Text(NSLocalizedString("Visit Website", comment: ""))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 9, weight: .bold))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }

                    Text(
                        NSLocalizedString(
                            "Supercharge your Trackpad & Magic Mouse with 120Hz ProMotion gestures, stroke drawing recognition, and window management.",
                            comment: ""
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                }
            }

            // About This Application Card
            liquidCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(NSLocalizedString("About This Application", comment: ""))
                        .font(.headline)

                    Text(
                        NSLocalizedString(
                            "BlueNap prevents your sleeping Mac from intermittently connecting " +
                                "to paired Bluetooth accessories and disrupting your audio playback.",
                            comment: ""
                        )
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.purple)
                            .font(.caption)
                        Text(NSLocalizedString("Tested exclusively on macOS 27", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    HStack {
                        Text(NSLocalizedString("Official Website", comment: ""))
                            .font(.subheadline)
                        Spacer()
                        Button("www.needai.top/app/bluenap") {
                            if let url = URL(string: "https://www.needai.top/app/bluenap") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                    }

                    Divider()

                    HStack {
                        Text(NSLocalizedString("GitHub Repository", comment: ""))
                            .font(.subheadline)
                        Spacer()
                        Button("github.com/jorchford/BlueNap") {
                            if let url = URL(string: "https://github.com/jorchford/BlueNap") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                    }

                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tactile (妙触) Official")
                                .font(.subheadline)
                            Text("https://app.needai.top/app/tactile")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("app.needai.top/app/tactile") {
                            if let url = URL(string: "https://app.needai.top/app/tactile") {
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
