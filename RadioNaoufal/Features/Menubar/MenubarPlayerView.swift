import SwiftUI
import AppKit

struct MenubarLabelView: View {
    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: player.status.isPlaying ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 13, weight: .semibold))
            if let station = player.currentStation {
                Text(station.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
        }
    }
}

struct MenubarPlayerView: View {
    @Environment(PlayerViewModel.self) private var player
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                AsyncImage(url: player.currentStation?.logoURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    if let name = player.currentStation?.name {
                        InitialsBadge(name: name)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 52, height: 52)
                .background(BoomboxTheme.chassisLight)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentStation?.name ?? String(localized: "Geen zender"))
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if let np = player.nowPlaying, np.hasTrackInfo {
                        Text(np.displayLine)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(statusText)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)

            Divider()

            // Transport controls
            HStack(spacing: 18) {
                Button {
                    player.previous()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14, weight: .semibold))
                }
                Button {
                    player.toggle()
                } label: {
                    Image(systemName: player.status.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(BoomboxTheme.amber)
                }
                Button {
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            Divider()

            // Volume slider
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { Double(player.audio.volume) },
                        set: { player.setVolume(Float($0)) }
                    ),
                    in: 0...1
                )
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()

            // Open main window
            Button {
                openMainWindow()
            } label: {
                HStack {
                    Image(systemName: "macwindow")
                    Text(String(localized: "Open Radio Naoufal"))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .onHover { _ in }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text(String(localized: "Stop Radio Naoufal"))
                    Spacer()
                    Text("Cmd+Q").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
    }

    private var statusText: String {
        switch player.status {
        case .idle: return String(localized: "Stand-by")
        case .loading: return String(localized: "Bezig met laden")
        case .playing: return String(localized: "Speelt af")
        case .paused: return String(localized: "Gepauzeerd")
        case .stopped: return String(localized: "Gestopt")
        case .error(let msg): return msg
        }
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title == "Radio Naoufal" }) {
            window.makeKeyAndOrderFront(nil)
        } else if let window = NSApp.windows.first(where: { !$0.title.isEmpty && !$0.title.contains("Radio Naoufal") == false }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
