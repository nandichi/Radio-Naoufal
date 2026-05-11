import SwiftUI

struct RecentTab: View {
    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if player.dataStore.recents.isEmpty {
                    EmptyStateView(
                        icon: "clock.arrow.circlepath",
                        title: String(localized: "Nog niets geluisterd"),
                        message: String(localized: "Hier zie je een lijst van zenders waarnaar je recent hebt geluisterd.")
                    )
                } else {
                    ForEach(player.dataStore.recents) { recent in
                        if let station = player.stations.station(byID: recent.stationID) {
                            HStack(spacing: 10) {
                                StationCard(
                                    station: station,
                                    isPlaying: station.id == player.currentStation?.id,
                                    action: { player.play(station: station) }
                                )
                                Text(formattedDate(recent.playedAt))
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .frame(width: 60, alignment: .trailing)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
