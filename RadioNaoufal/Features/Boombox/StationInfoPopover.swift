import SwiftUI
import AppKit

/// Popover die station-metadata toont: codec, bitrate, dial-freq, stream-URL en homepage.
/// Wordt getoond door een tap-gesture op `CassetteDeckView`.
struct StationInfoPopover: View {
    let station: Station
    let nowPlaying: NowPlaying?
    let onDismiss: () -> Void

    @State private var copied: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                AsyncImage(url: station.logoURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    InitialsBadge(name: station.name)
                }
                .frame(width: 56, height: 56)
                .background(BoomboxTheme.chassisLight)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(station.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        Text(station.genre.localizedLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        if let dial = station.dial {
                            Text(verbatim: "\(String(format: "%.1f", dial)) MHz")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help(String(localized: "Sluit"))
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                infoRow(label: String(localized: "Codec"), value: station.codec.rawValue.uppercased())
                if let bitrate = station.bitrate {
                    infoRow(label: String(localized: "Bitrate"), value: "\(bitrate) kbps")
                }
                infoRow(label: String(localized: "Bron"), value: sourceLabel)
                if let np = nowPlaying, np.hasTrackInfo {
                    infoRow(label: String(localized: "Nu speelt"), value: np.displayLine)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Stream-URL"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text(station.streamURL.absoluteString)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    Spacer()
                    Button {
                        copyStreamURL()
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundStyle(copied ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "Kopieer URL"))
                }
            }

            if let homepage = station.homepageURL {
                Button {
                    NSWorkspace.shared.open(homepage)
                } label: {
                    HStack {
                        Image(systemName: "globe")
                        Text(String(localized: "Open homepage"))
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 11))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private var sourceLabel: String {
        switch station.source {
        case .curated: return String(localized: "Curated")
        case .radioBrowser: return String(localized: "Radio-Browser")
        case .userAdded: return String(localized: "Eigen zender")
        }
    }

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
    }

    private func copyStreamURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(station.streamURL.absoluteString, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { copied = false }
        }
    }
}
