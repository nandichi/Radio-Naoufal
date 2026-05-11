import SwiftUI

/// Tab in `BrowseDrawer` voor podcast-discovery, subscriptions en episode-selectie.
struct PodcastsTab: View {
    @Environment(PlayerViewModel.self) private var player

    @State private var searchQuery: String = ""
    @State private var debounceTask: Task<Void, Never>?
    @State private var selectedPodcast: Podcast?

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            Divider().background(Color.white.opacity(0.05))

            if selectedPodcast != nil {
                detailView
            } else if !searchQuery.isEmpty {
                searchResultsView
            } else {
                subscriptionsView
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            if selectedPodcast != nil {
                Button {
                    selectedPodcast = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 10, weight: .bold))
                        Text(String(localized: "Terug")).font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(BoomboxTheme.amber)
                }
                .buttonStyle(.plain)
            }

            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.5))
                .font(.system(size: 11))

            TextField(String(localized: "Zoek podcasts..."), text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .onChange(of: searchQuery) { _, newValue in
                    debounceSearch(query: newValue)
                }

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    player.podcasts.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.4))
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }

            if player.podcasts.isSearching {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.2))
    }

    private var subscriptionsView: some View {
        Group {
            if player.podcasts.subscribedPodcasts.isEmpty {
                emptySubscriptionsState
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], spacing: 8) {
                        ForEach(player.podcasts.subscribedPodcasts) { podcast in
                            SubscribedPodcastCard(
                                podcast: podcast,
                                onSelect: { selectedPodcast = podcast },
                                onUnsubscribe: { player.podcasts.unsubscribe(podcastID: podcast.id) }
                            )
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                }
            }
        }
    }

    private var emptySubscriptionsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.25))
            Text(String(localized: "Nog geen podcast-abonnementen"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
            Text(String(localized: "Zoek hierboven een podcast om je aan te abonneren."))
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(player.podcasts.searchResults) { result in
                    DiscoveredPodcastRow(
                        result: result,
                        isSubscribed: player.podcasts.isSubscribed(result.id),
                        onSubscribe: {
                            Task { await player.podcasts.subscribe(result) }
                        },
                        onUnsubscribe: { player.podcasts.unsubscribe(podcastID: result.id) }
                    )
                }
                if player.podcasts.searchResults.isEmpty && !player.podcasts.isSearching {
                    Text(String(localized: "Geen podcasts gevonden voor deze zoekterm."))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 40)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if let podcast = selectedPodcast {
            PodcastDetailView(podcast: podcast)
        }
    }

    private func debounceSearch(query: String) {
        debounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            player.podcasts.clearSearch()
            return
        }
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            await player.podcasts.search(query: trimmed)
        }
    }
}

// MARK: - Sub views

private struct SubscribedPodcastCard: View {
    let podcast: Podcast
    let onSelect: () -> Void
    let onUnsubscribe: () -> Void

    @State private var hovered: Bool = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                AsyncImage(url: podcast.artworkURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    InitialsBadge(name: podcast.title)
                }
                .frame(width: 44, height: 44)
                .background(BoomboxTheme.chassisLight)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(podcast.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let author = podcast.author {
                        Text(author)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                if hovered {
                    Menu {
                        Button(role: .destructive) {
                            onUnsubscribe()
                        } label: {
                            Label(String(localized: "Uitschrijven"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 22, height: 22)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(hovered ? 0.07 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

private struct DiscoveredPodcastRow: View {
    let result: PodcastDiscoveryService.DiscoveredPodcast
    let isSubscribed: Bool
    let onSubscribe: () -> Void
    let onUnsubscribe: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            AsyncImage(url: result.artworkURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                InitialsBadge(name: result.title)
            }
            .frame(width: 44, height: 44)
            .background(BoomboxTheme.chassisLight)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let author = result.author {
                    Text(author)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                if let genre = result.genre {
                    Text(genre)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer(minLength: 4)

            Button {
                if isSubscribed { onUnsubscribe() } else { onSubscribe() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isSubscribed ? "checkmark" : "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text(isSubscribed ? String(localized: "Geabonneerd") : String(localized: "Abonneren"))
                        .font(.system(size: 10, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .foregroundStyle(isSubscribed ? .white : .black)
                .background(
                    Capsule().fill(isSubscribed ? Color.white.opacity(0.12) : BoomboxTheme.amber)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
        )
    }
}
