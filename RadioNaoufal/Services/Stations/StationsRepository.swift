import Foundation
import Observation
import os

/// Beheert de lijst van gestelde Nederlandse radiozenders en biedt zoeken via Radio-Browser.
@MainActor
@Observable
public final class StationsRepository {

    public private(set) var curated: [Station] = []
    public private(set) var radioBrowser: [Station] = []
    public private(set) var isLoading: Bool = false
    public private(set) var lastError: String?

    private let logger = Logger(subsystem: "nl.naoufal.radio-naoufal", category: "StationsRepository")
    private let bundles: [Bundle]
    private let browserClient: RadioBrowserClient

    public init(bundles: [Bundle] = StationsRepository.defaultBundles(), browserClient: RadioBrowserClient = RadioBrowserClient()) {
        self.bundles = bundles
        self.browserClient = browserClient
        loadCurated()
    }

    public convenience init(bundle: Bundle, browserClient: RadioBrowserClient = RadioBrowserClient()) {
        self.init(bundles: [bundle], browserClient: browserClient)
    }

    /// Geeft alle plausibele bundles waaruit `curated-stations.json` geladen kan worden.
    /// Volgorde: SwiftPM module bundle (indien beschikbaar) > Bundle.main.
    public static func defaultBundles() -> [Bundle] {
        var result: [Bundle] = []
        #if SWIFT_PACKAGE
        result.append(Bundle.module)
        #endif
        result.append(.main)
        return result
    }

    public var allStations: [Station] {
        curated + radioBrowser
    }

    public var stationsByGenre: [Station.Genre: [Station]] {
        Dictionary(grouping: allStations, by: \.genre)
    }

    public func station(byID id: String) -> Station? {
        allStations.first(where: { $0.id == id })
    }

    public func nextStation(after id: String?) -> Station? {
        guard let id, let index = curated.firstIndex(where: { $0.id == id }) else {
            return curated.first
        }
        let next = (index + 1) % max(1, curated.count)
        return curated[next]
    }

    public func previousStation(before id: String?) -> Station? {
        guard let id, let index = curated.firstIndex(where: { $0.id == id }) else {
            return curated.last
        }
        let previous = (index - 1 + curated.count) % max(1, curated.count)
        return curated[previous]
    }

    public func loadRadioBrowserStations() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let stations = try await browserClient.popularNetherlands(limit: 300)
            self.radioBrowser = Self.dedupedAgainstCurated(stations, curated: curated)
            self.lastError = nil
        } catch {
            self.lastError = error.localizedDescription
            logger.error("Failed to load Radio-Browser stations: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func search(query: String) async -> [Station] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }
        let lower = trimmed.lowercased()
        let localResults = curated.filter {
            $0.name.lowercased().contains(lower)
            || $0.tags.contains(where: { $0.lowercased().contains(lower) })
        }
        do {
            let remote = try await browserClient.search(query: trimmed, limit: 50)
            let deduped = Self.dedupedAgainstCurated(remote, curated: localResults)
            return localResults + deduped
        } catch {
            logger.error("Search failed: \(error.localizedDescription, privacy: .public)")
            return localResults
        }
    }

    // MARK: - Dedupe

    /// Normaliseert een stationnaam tot lowercase, alfanumeriek-only.
    /// Voorbeelden:
    ///   "NPO Radio 1" → "nporadio1"
    ///   "Q-music"    → "qmusic"
    ///   "538 Radio"  → "538radio"
    static func normalize(_ name: String) -> String {
        var result = name.lowercased().folding(options: .diacriticInsensitive, locale: .current)
        result = result.filter { $0.isLetter || $0.isNumber }
        return result
    }

    /// Dedupe Radio-Browser stations tegen curated + onderling:
    ///  - filtert stations die al in `curated` zitten (op genormaliseerde naam)
    ///  - dedupliceert onderling op naam, kiest de variant met hoogste bitrate
    ///  - filtert stations zonder werkbare URL of met lege naam
    static func dedupedAgainstCurated(_ stations: [Station], curated: [Station]) -> [Station] {
        let curatedKeys: Set<String> = Set(curated.map { normalize($0.name) })

        // Bucket op genormaliseerde naam, behoud per bucket de versie met hoogste bitrate.
        var bestByKey: [String: Station] = [:]
        for station in stations {
            let key = normalize(station.name)
            if key.isEmpty { continue }
            if curatedKeys.contains(key) { continue }
            // Skip stations met onbruikbare stream URLs.
            guard station.streamURL.scheme?.lowercased().hasPrefix("http") == true else { continue }

            if let existing = bestByKey[key] {
                let existingBitrate = existing.bitrate ?? 0
                let newBitrate = station.bitrate ?? 0
                if newBitrate > existingBitrate {
                    bestByKey[key] = station
                }
            } else {
                bestByKey[key] = station
            }
        }
        // Sorteer alfabetisch op naam voor consistente UI volgorde.
        return bestByKey.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Curated JSON

    private struct CuratedBundle: Decodable {
        let version: Int
        let updatedAt: String
        let stations: [CuratedStation]
    }

    private struct CuratedStation: Decodable {
        let id: String
        let name: String
        let streamURL: String
        let logoURL: String?
        let homepageURL: String?
        let genre: String
        let region: String
        let dial: Double?
        let bitrate: Int?
        let codec: String
        let source: String
        let tags: [String]
    }

    private func loadCurated() {
        var foundURL: URL?
        for bundle in bundles {
            if let url = bundle.url(forResource: "curated-stations", withExtension: "json") {
                foundURL = url
                break
            }
        }
        guard let url = foundURL else {
            logger.error("curated-stations.json niet gevonden in een van de bundles")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(CuratedBundle.self, from: data)
            let stations: [Station] = payload.stations.compactMap { item in
                guard let stream = URL(string: item.streamURL) else { return nil }
                return Station(
                    id: item.id,
                    name: item.name,
                    streamURL: stream,
                    logoURL: item.logoURL.flatMap(URL.init(string:)),
                    homepageURL: item.homepageURL.flatMap(URL.init(string:)),
                    genre: Station.Genre(rawValue: item.genre) ?? .other,
                    region: Station.Region(rawValue: item.region) ?? .national,
                    dial: item.dial,
                    bitrate: item.bitrate,
                    codec: Station.Codec(rawValue: item.codec) ?? .mp3,
                    source: Station.Source(rawValue: item.source) ?? .curated,
                    tags: item.tags
                )
            }
            self.curated = stations
        } catch {
            logger.error("Kon curated-stations.json niet decoderen: \(error.localizedDescription, privacy: .public)")
        }
    }
}
