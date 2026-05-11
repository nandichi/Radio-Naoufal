import SwiftUI

struct CategoriesTab: View {
    @Environment(PlayerViewModel.self) private var player
    @State private var selectedGenre: Station.Genre?

    private var genresWithStations: [Station.Genre] {
        let used = Set(player.stations.allStations.map(\.genre))
        return Station.Genre.allCases.filter { used.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Genre chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ChipButton(
                        label: String(localized: "Alle"),
                        isSelected: selectedGenre == nil,
                        action: { selectedGenre = nil }
                    )
                    ForEach(genresWithStations) { genre in
                        ChipButton(
                            label: genre.localizedLabel,
                            isSelected: selectedGenre == genre,
                            action: { selectedGenre = genre }
                        )
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
            }
            .background(Color.black.opacity(0.2))

            Divider().background(Color.white.opacity(0.05))

            // Stations grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], spacing: 8) {
                    ForEach(filteredStations) { station in
                        StationCard(
                            station: station,
                            isPlaying: station.id == player.currentStation?.id,
                            action: { player.play(station: station) }
                        )
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
            }
        }
    }

    private var filteredStations: [Station] {
        if let genre = selectedGenre {
            return player.stations.allStations.filter { $0.genre == genre }
        }
        return player.stations.allStations
    }
}

struct ChipButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? .black : .white.opacity(0.8))
                .background(
                    Capsule()
                        .fill(isSelected ? BoomboxTheme.amber : Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? BoomboxTheme.amber : Color.white.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
