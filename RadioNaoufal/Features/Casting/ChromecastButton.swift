import SwiftUI

struct ChromecastButton: View {
    @Environment(PlayerViewModel.self) private var player
    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover.toggle()
            if showPopover {
                player.cast.startDiscovery()
            } else {
                player.cast.stopDiscovery()
            }
        } label: {
            Image(systemName: isCasting ? "tv.fill" : "tv")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isCasting ? BoomboxTheme.amber : Color.white.opacity(0.85))
        }
        .buttonStyle(IconButtonStyle())
        .help(String(localized: "Chromecast"))
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            ChromecastDevicePicker()
                .environment(player)
                .onDisappear {
                    player.cast.stopDiscovery()
                }
        }
    }

    private var isCasting: Bool {
        switch player.cast.state {
        case .connected, .playing: return true
        default: return false
        }
    }
}

struct ChromecastDevicePicker: View {
    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "tv")
                    .foregroundStyle(BoomboxTheme.amber)
                Text(String(localized: "Chromecast"))
                    .font(.headline)
                Spacer()
                if case .discovering = player.cast.state {
                    ProgressView().scaleEffect(0.6)
                }
            }

            Divider()

            if player.cast.devices.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text(String(localized: "Geen apparaten gevonden"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "Zorg dat je Chromecast op hetzelfde Wi-Fi netwerk staat."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            } else {
                ForEach(player.cast.devices) { device in
                    Button {
                        select(device: device)
                    } label: {
                        HStack {
                            Image(systemName: "tv")
                            VStack(alignment: .leading) {
                                Text(device.name)
                                    .font(.system(size: 13, weight: .medium))
                                if let model = device.modelName {
                                    Text(model)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if isActive(device: device) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(BoomboxTheme.amber)
                            }
                        }
                        .padding(8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if case .playing = player.cast.state {
                Divider()
                Button(String(localized: "Stop casten"), role: .destructive) {
                    player.disconnectChromecast()
                }
            } else if case .connected = player.cast.state {
                Divider()
                Button(String(localized: "Verbinding verbreken"), role: .destructive) {
                    player.disconnectChromecast()
                }
            }

            if case .error(let message) = player.cast.state {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    private func select(device: CastDevice) {
        if isActive(device: device) {
            player.disconnectChromecast()
        } else {
            player.connectToChromecast(device)
            if let station = player.currentStation {
                Task {
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    await player.cast.play(station: station)
                }
            }
        }
    }

    private func isActive(device: CastDevice) -> Bool {
        player.cast.activeDevice?.id == device.id
    }
}
