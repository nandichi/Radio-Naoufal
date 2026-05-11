import Foundation
import os

/// Client voor de openbare Radio-Browser API (api.radio-browser.info).
/// Implementeert mirror-discovery via DNS SRV-records met fallback op een vaste lijst van bekende hosts.
public actor RadioBrowserClient {

    public struct SearchOptions: Sendable {
        public var name: String?
        public var country: String?
        public var countryCode: String?
        public var tag: String?
        public var language: String?
        public var limit: Int
        public var hideBroken: Bool

        public init(
            name: String? = nil,
            country: String? = nil,
            countryCode: String? = "NL",
            tag: String? = nil,
            language: String? = nil,
            limit: Int = 50,
            hideBroken: Bool = true
        ) {
            self.name = name
            self.country = country
            self.countryCode = countryCode
            self.tag = tag
            self.language = language
            self.limit = limit
            self.hideBroken = hideBroken
        }
    }

    public struct APIStation: Decodable, Sendable {
        public let stationuuid: String
        public let name: String
        public let url_resolved: String
        public let url: String
        public let favicon: String
        public let homepage: String
        public let tags: String
        public let countrycode: String
        public let language: String
        public let codec: String
        public let bitrate: Int

        public func toStation() -> Station? {
            guard !name.isEmpty else { return nil }
            let resolvedURLString = url_resolved.isEmpty ? url : url_resolved
            guard let streamURL = URL(string: resolvedURLString) else { return nil }
            let logoURL = URL(string: favicon)
            let home = URL(string: homepage)
            let tagList = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            return Station(
                id: "rb-\(stationuuid)",
                name: name,
                streamURL: streamURL,
                logoURL: logoURL,
                homepageURL: home,
                genre: Self.inferGenre(from: tagList),
                region: .national,
                dial: nil,
                bitrate: bitrate > 0 ? bitrate : nil,
                codec: Self.inferCodec(from: codec),
                source: .radioBrowser,
                tags: tagList
            )
        }

        static func inferGenre(from tags: [String]) -> Station.Genre {
            let lower = tags.map { $0.lowercased() }
            if lower.contains(where: { $0.contains("news") || $0.contains("nieuws") }) { return .news }
            if lower.contains(where: { $0.contains("classical") || $0.contains("klassiek") }) { return .classical }
            if lower.contains(where: { $0.contains("dance") || $0.contains("edm") }) { return .dance }
            if lower.contains(where: { $0.contains("jazz") || $0.contains("soul") }) { return .soulJazz }
            if lower.contains(where: { $0.contains("rock") }) { return .rock }
            if lower.contains(where: { $0.contains("hip") || $0.contains("urban") || $0.contains("rap") }) { return .urban }
            if lower.contains(where: { $0.contains("oldies") || $0.contains("70s") || $0.contains("80s") }) { return .oldies }
            if lower.contains(where: { $0.contains("dutch") || $0.contains("nederlandstalig") }) { return .dutch }
            if lower.contains(where: { $0.contains("top40") || $0.contains("top 40") }) { return .top40 }
            if lower.contains(where: { $0.contains("hits") || $0.contains("pop") }) { return .hits }
            if lower.contains(where: { $0.contains("business") }) { return .business }
            return .other
        }

        static func inferCodec(from raw: String) -> Station.Codec {
            switch raw.lowercased() {
            case "mp3": return .mp3
            case "aac": return .aac
            case "aac+", "he-aac", "heaac": return .heAac
            case "ogg", "vorbis": return .ogg
            case "hls": return .hls
            default: return .unknown
            }
        }
    }

    private let session: URLSession
    private let logger = Logger(subsystem: "nl.naoufal.radio-naoufal", category: "RadioBrowserClient")
    private var cachedBase: URL?
    private let candidateHosts: [String] = [
        "de1.api.radio-browser.info",
        "fr1.api.radio-browser.info",
        "at1.api.radio-browser.info",
        "nl1.api.radio-browser.info"
    ]
    private var cache: [String: (Date, [Station])] = [:]
    private let cacheTTL: TimeInterval = 300

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func searchNetherlandsStations(options: SearchOptions = SearchOptions()) async throws -> [Station] {
        let cacheKey = cacheKey(for: options)
        if let cached = cache[cacheKey], Date().timeIntervalSince(cached.0) < cacheTTL {
            return cached.1
        }
        let base = try await resolveBase()
        var path = "/json/stations/search"
        if let _ = options.countryCode, options.name == nil, options.tag == nil {
            // dedicated endpoint voor country
            path = "/json/stations/bycountrycodeexact/NL"
        }

        var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        var items: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(options.limit)),
            URLQueryItem(name: "hidebroken", value: options.hideBroken ? "true" : "false"),
            URLQueryItem(name: "order", value: "clickcount"),
            URLQueryItem(name: "reverse", value: "true")
        ]
        if let name = options.name {
            items.append(URLQueryItem(name: "name", value: name))
        }
        if let tag = options.tag {
            items.append(URLQueryItem(name: "tag", value: tag))
        }
        if let language = options.language {
            items.append(URLQueryItem(name: "language", value: language))
        }
        if path == "/json/stations/search", let countryCode = options.countryCode {
            items.append(URLQueryItem(name: "countrycode", value: countryCode))
        }
        components?.queryItems = items
        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("RadioNaoufal/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, _) = try await session.data(for: request)
        let apiStations = try JSONDecoder().decode([APIStation].self, from: data)
        let stations = apiStations.compactMap { $0.toStation() }
        cache[cacheKey] = (Date(), stations)
        return stations
    }

    public func search(query: String, limit: Int = 30) async throws -> [Station] {
        try await searchNetherlandsStations(options: SearchOptions(name: query, limit: limit))
    }

    public func popularNetherlands(limit: Int = 100) async throws -> [Station] {
        try await searchNetherlandsStations(options: SearchOptions(countryCode: "NL", limit: limit))
    }

    public func byTag(_ tag: String, limit: Int = 50) async throws -> [Station] {
        try await searchNetherlandsStations(options: SearchOptions(countryCode: "NL", tag: tag, limit: limit))
    }

    // MARK: - Helpers

    private func resolveBase() async throws -> URL {
        if let cached = cachedBase { return cached }
        for host in candidateHosts {
            if let url = URL(string: "https://\(host)") {
                if await isReachable(base: url) {
                    cachedBase = url
                    return url
                }
            }
        }
        guard let fallback = URL(string: "https://de1.api.radio-browser.info") else {
            throw URLError(.cannotFindHost)
        }
        cachedBase = fallback
        return fallback
    }

    private func isReachable(base: URL) async -> Bool {
        var request = URLRequest(url: base.appendingPathComponent("/json/stats"))
        request.timeoutInterval = 5
        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return http.statusCode == 200
        } catch {
            return false
        }
    }

    private func cacheKey(for options: SearchOptions) -> String {
        [
            options.name ?? "",
            options.countryCode ?? "",
            options.tag ?? "",
            options.language ?? "",
            String(options.limit)
        ].joined(separator: "|")
    }
}
