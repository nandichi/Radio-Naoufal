import Foundation
import os

/// Zoekt podcasts via de iTunes Search API. Geen authenticatie nodig.
public actor PodcastDiscoveryService {

    public struct DiscoveredPodcast: Identifiable, Sendable, Hashable {
        public let id: String
        public let title: String
        public let author: String?
        public let feedURL: URL
        public let artworkURL: URL?
        public let genre: String?
        public let trackCount: Int?

        public init(id: String, title: String, author: String?, feedURL: URL, artworkURL: URL?, genre: String?, trackCount: Int?) {
            self.id = id
            self.title = title
            self.author = author
            self.feedURL = feedURL
            self.artworkURL = artworkURL
            self.genre = genre
            self.trackCount = trackCount
        }
    }

    private let logger = Logger(subsystem: "nl.naoufal.radio-naoufal", category: "PodcastDiscovery")
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func search(query: String, limit: Int = 25) async -> [DiscoveredPodcast] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: trimmed),
            URLQueryItem(name: "media", value: "podcast"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        guard let url = components?.url else { return [] }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("RadioNaoufal/1.0 (macOS)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
            let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
            return decoded.results.compactMap { result in
                guard let feedURLString = result.feedUrl, let feedURL = URL(string: feedURLString) else { return nil }
                guard let collectionId = result.collectionId else { return nil }
                let artworkRaw = result.artworkUrl600 ?? result.artworkUrl100
                let artworkURL = artworkRaw.flatMap { URL(string: $0) }
                return DiscoveredPodcast(
                    id: "itunes-\(collectionId)",
                    title: result.collectionName ?? "Onbekende podcast",
                    author: result.artistName,
                    feedURL: feedURL,
                    artworkURL: artworkURL,
                    genre: result.primaryGenreName,
                    trackCount: result.trackCount
                )
            }
        } catch {
            logger.error("Podcast search failed for query '\(trimmed, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    // MARK: - Response models

    private struct SearchResponse: Decodable {
        let resultCount: Int
        let results: [Result]
    }

    private struct Result: Decodable {
        let collectionId: Int?
        let collectionName: String?
        let artistName: String?
        let feedUrl: String?
        let artworkUrl100: String?
        let artworkUrl600: String?
        let primaryGenreName: String?
        let trackCount: Int?
    }
}
