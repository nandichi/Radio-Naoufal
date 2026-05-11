import Foundation
import os

/// Haalt track-artwork op via iTunes Search API en cached resultaten in een NSCache.
/// Wordt aangeroepen door `AudioEngine` zodra ICY-metadata een artist+title oplevert.
/// Vereist geen authenticatie en stuurt alleen de track-naam naar Apple.
public actor ArtworkFetcher {

    public static let shared = ArtworkFetcher()

    private let logger = Logger(subsystem: "nl.naoufal.radio-naoufal", category: "ArtworkFetcher")
    private var cache: [String: CacheEntry] = [:]
    private let cacheTTL: TimeInterval = 3600

    private struct CacheEntry {
        let url: URL?
        let storedAt: Date
    }

    public init() {}

    /// Vraagt een artwork-URL op voor de gegeven artist + title combinatie.
    /// Returns `nil` als er geen match is, een netwerkfout optreedt, of artwork-fetching is uitgezet via preferences.
    public func artworkURL(artist: String?, title: String?) async -> URL? {
        guard UserDefaults.standard.bool(forKey: AppPreferences.Keys.artworkFetching) else { return nil }
        let key = makeKey(artist: artist, title: title)
        guard !key.isEmpty else { return nil }

        if let cached = cache[key], Date().timeIntervalSince(cached.storedAt) < cacheTTL {
            return cached.url
        }

        let url = await query(key: key)
        cache[key] = CacheEntry(url: url, storedAt: .now)
        return url
    }

    private func makeKey(artist: String?, title: String?) -> String {
        let a = (artist ?? "").trimmingCharacters(in: .whitespaces)
        let t = (title ?? "").trimmingCharacters(in: .whitespaces)
        if a.isEmpty && t.isEmpty { return "" }
        return [a, t].joined(separator: "|").lowercased()
    }

    private struct ITunesResponse: Decodable {
        let resultCount: Int
        let results: [ITunesResult]
    }

    private struct ITunesResult: Decodable {
        let artworkUrl100: String?
        let artworkUrl60: String?
    }

    private func query(key: String) async -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/search")
        let term = key.replacingOccurrences(of: "|", with: " ")
        components?.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url, timeoutInterval: 6)
        request.setValue("RadioNaoufal/1.0 (macOS)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let decoded = try JSONDecoder().decode(ITunesResponse.self, from: data)
            guard let first = decoded.results.first else { return nil }
            // Upgrade naar 600x600 voor scherpere weergave in cassette deck/MenuBar
            let raw = first.artworkUrl100 ?? first.artworkUrl60
            guard let raw else { return nil }
            let upgraded = raw.replacingOccurrences(of: "100x100bb", with: "600x600bb")
            return URL(string: upgraded)
        } catch {
            logger.debug("Artwork lookup failed for \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
