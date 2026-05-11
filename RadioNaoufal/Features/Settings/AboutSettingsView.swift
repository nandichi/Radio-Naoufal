import SwiftUI
import AppKit

/// Derde tab: app-info, versie, links en credits.
struct AboutSettingsView: View {

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private let repoURL = URL(string: "https://github.com/nandichi/Radio-Naoufal")!
    private let releasesURL = URL(string: "https://github.com/nandichi/Radio-Naoufal/releases")!
    private let issuesURL = URL(string: "https://github.com/nandichi/Radio-Naoufal/issues/new")!
    private let radioBrowserURL = URL(string: "https://www.radio-browser.info")!

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    if let icon = NSApp.applicationIconImage {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 96, height: 96)
                    } else {
                        Image(systemName: "radio.fill")
                            .font(.system(size: 64, weight: .light))
                            .foregroundStyle(.orange)
                            .frame(width: 96, height: 96)
                    }

                    Text(String(localized: "Radio Naoufal"))
                        .font(.system(size: 22, weight: .bold))

                    Text(verbatim: "v\(appVersion) (build \(buildNumber))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                Text(String(localized: "Een 1980s boombox op je Mac. Native Nederlandse radio met live VU-meters, EQ, AirPlay en Chromecast."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Divider().padding(.horizontal, 40)

                VStack(spacing: 8) {
                    LinkButton(title: String(localized: "Open GitHub-repo"), systemImage: "chevron.left.slash.chevron.right", url: repoURL)
                    LinkButton(title: String(localized: "Bekijk alle releases"), systemImage: "arrow.down.circle", url: releasesURL)
                    LinkButton(title: String(localized: "Meld een probleem"), systemImage: "exclamationmark.bubble", url: issuesURL)
                }
                .padding(.horizontal, 40)

                Divider().padding(.horizontal, 40)

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Met dank aan"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            Button {
                                NSWorkspace.shared.open(radioBrowserURL)
                            } label: {
                                Text(verbatim: "Radio-Browser.info")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.link)
                            Text(String(localized: "Community database met duizenden internet-radio zenders."))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "tv.and.hifispeaker.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: "ChromecastKit")
                                .font(.system(size: 11))
                            Text(String(localized: "Discovery en casting via Bonjour, door dioKaratzas."))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "applelogo")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                        Text(String(localized: "Apple voor AVFoundation, MediaPlayer, Accelerate en SwiftUI."))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 40)

                Spacer(minLength: 8)

                VStack(spacing: 2) {
                    Text(verbatim: "MIT License")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(String(localized: "Copyright 2026 Naoufal Andichi"))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct LinkButton: View {
    let title: String
    let systemImage: String
    let url: URL

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 12))
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
