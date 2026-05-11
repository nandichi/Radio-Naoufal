import SwiftUI

struct FavoritesTab: View {
    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if player.dataStore.favorites.isEmpty {
                    EmptyStateView(
                        icon: "star.slash",
                        title: String(localized: "Geen favorieten ingesteld"),
                        message: String(localized: "Houd een preset-knop op de boombox lang ingedrukt om er een zender aan toe te wijzen.")
                    )
                } else {
                    ForEach(player.dataStore.favorites) { slot in
                        if let station = player.stations.station(byID: slot.stationID) {
                            HStack {
                                Text("[\(slot.slotIndex)]")
                                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(BoomboxTheme.amber)
                                    .frame(width: 28)
                                StationCard(
                                    station: station,
                                    isPlaying: station.id == player.currentStation?.id,
                                    action: { player.play(station: station) }
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white.opacity(0.3))
            Text(title)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))
            Text(message)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
        }
        .padding(30)
        .frame(maxWidth: .infinity)
    }
}
