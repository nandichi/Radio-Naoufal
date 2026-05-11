import SwiftUI

struct SearchTab: View {
    @Environment(PlayerViewModel.self) private var player
    @State private var query: String = ""
    @State private var results: [Station] = []
    @State private var isSearching: Bool = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(String(localized: "Zoek Nederlandse zenders..."), text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onChange(of: query) { _, newValue in
                        scheduleSearch(query: newValue)
                    }
                if isSearching {
                    ProgressView().scaleEffect(0.6)
                }
                if !query.isEmpty {
                    Button {
                        query = ""
                        results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 22)
            .padding(.top, 12)

            if query.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: String(localized: "Zoek alle Nederlandse zenders"),
                    message: String(localized: "Typ een zenderlokaal naam of trefwoord. We zoeken zowel in curated stations als in Radio-Browser.")
                )
            } else if results.isEmpty && !isSearching {
                EmptyStateView(
                    icon: "questionmark.app.dashed",
                    title: String(localized: "Geen resultaten"),
                    message: String(localized: "Probeer een andere zoekterm.")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(results) { station in
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
    }

    private func scheduleSearch(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            let hits = await player.stations.search(query: trimmed)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.results = hits
                self.isSearching = false
            }
        }
    }
}

struct SearchSheetView: View {
    @Environment(PlayerViewModel.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "Zoek zenders"))
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(String(localized: "Sluit")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            Divider()
            SearchTab()
                .environment(player)
        }
        .padding(20)
        .frame(width: 600, height: 580)
    }
}
