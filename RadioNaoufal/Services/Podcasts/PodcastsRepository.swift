import Foundation
import Observation
import os

/// Beheert podcast-subscriptions en in-memory cache van episodes per podcast.
/// Persistente subscriptions zitten in DataStore; episodes worden bij subscribe/refresh
/// in geheugen gehouden zodat search en navigatie snappy zijn.
@MainActor
@Observable
public final class PodcastsRepository {

    public private(set) var episodesByPodcast: [String: [PodcastEpisode]] = [:]
    public private(set) var isRefreshing: Bool = false
    public private(set) var searchResults: [PodcastDiscoveryService.DiscoveredPodcast] = []
    public private(set) var isSearching: Bool = false

    private let logger = Logger(subsystem: "nl.naoufal.radio-naoufal", category: "PodcastsRepository")
    private let discovery: PodcastDiscoveryService
    private let parser: PodcastFeedParser
    private let dataStore: DataStore

    public init(
        dataStore: DataStore = .shared,
        discovery: PodcastDiscoveryService = PodcastDiscoveryService(),
        parser: PodcastFeedParser = PodcastFeedParser()
    ) {
        self.dataStore = dataStore
        self.discovery = discovery
        self.parser = parser
    }

    public var subscribedPodcasts: [Podcast] {
        dataStore.subscribedPodcasts
    }

    // MARK: - Discovery

    public func search(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        let results = await discovery.search(query: trimmed)
        searchResults = results
        isSearching = false
    }

    public func clearSearch() {
        searchResults = []
    }

    // MARK: - Subscriptions

    public func subscribe(_ discovered: PodcastDiscoveryService.DiscoveredPodcast) async {
        let podcast = Podcast(
            id: discovered.id,
            title: discovered.title,
            author: discovered.author,
            summary: nil,
            feedURL: discovered.feedURL,
            artworkURL: discovered.artworkURL,
            categories: discovered.genre.map { [$0] } ?? []
        )
        dataStore.subscribePodcast(podcast)
        await refreshEpisodes(for: podcast)
    }

    public func unsubscribe(podcastID: String) {
        dataStore.unsubscribePodcast(id: podcastID)
        episodesByPodcast.removeValue(forKey: podcastID)
    }

    public func isSubscribed(_ id: String) -> Bool {
        dataStore.isSubscribed(podcastID: id)
    }

    public func episodes(for podcastID: String) -> [PodcastEpisode] {
        episodesByPodcast[podcastID] ?? []
    }

    // MARK: - Refresh

    public func refreshAll() async {
        isRefreshing = true
        for podcast in subscribedPodcasts {
            await refreshEpisodes(for: podcast)
        }
        isRefreshing = false
    }

    public func refreshEpisodes(for podcast: Podcast) async {
        do {
            let result = try await parser.fetchAndParse(url: podcast.feedURL, podcastID: podcast.id)
            episodesByPodcast[podcast.id] = result.episodes.sorted(by: { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) })

            if result.podcast.summary != nil && (podcast.summary ?? "").isEmpty {
                var updated = podcast
                updated.summary = result.podcast.summary
                updated.author = updated.author ?? result.podcast.author
                updated.artworkURL = updated.artworkURL ?? result.podcast.artworkURL
                dataStore.subscribePodcast(updated)
            }
        } catch {
            logger.error("Refresh failed for podcast \(podcast.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
