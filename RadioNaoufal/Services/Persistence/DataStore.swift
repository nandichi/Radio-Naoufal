import Foundation
import Observation
import os

/// Eenvoudige persistente store voor favorieten en recent geluisterde zenders.
/// Slaat data op als JSON in Application Support map - geen SwiftData/CoreData nodig.
@MainActor
@Observable
public final class DataStore {

    public struct FavoriteSlot: Identifiable, Codable, Hashable, Sendable {
        public let slotIndex: Int
        public let stationID: String
        public let stationName: String
        public let addedAt: Date

        public var id: Int { slotIndex }

        public init(slotIndex: Int, stationID: String, stationName: String, addedAt: Date = .now) {
            self.slotIndex = slotIndex
            self.stationID = stationID
            self.stationName = stationName
            self.addedAt = addedAt
        }
    }

    public struct RecentPlay: Identifiable, Codable, Hashable, Sendable {
        public let id: UUID
        public let stationID: String
        public let stationName: String
        public let playedAt: Date

        public init(stationID: String, stationName: String, playedAt: Date = .now) {
            self.id = UUID()
            self.stationID = stationID
            self.stationName = stationName
            self.playedAt = playedAt
        }
    }

    public struct UserCustomStation: Identifiable, Codable, Hashable, Sendable {
        public let id: String
        public let name: String
        public let streamURL: URL
        public let logoURL: URL?
        public let addedAt: Date

        public init(name: String, streamURL: URL, logoURL: URL? = nil) {
            self.id = "user-\(UUID().uuidString)"
            self.name = name
            self.streamURL = streamURL
            self.logoURL = logoURL
            self.addedAt = .now
        }
    }

    public private(set) var favorites: [FavoriteSlot] = []
    public private(set) var recents: [RecentPlay] = []
    public private(set) var customStations: [UserCustomStation] = []

    private let logger = Logger(subsystem: "nl.naoufal.radio-naoufal", category: "DataStore")
    private let baseDirectory: URL
    private let favoritesFile: URL
    private let recentsFile: URL
    private let customStationsFile: URL

    private static let maxRecents = 20

    public static let shared = DataStore()

    public init(baseDirectory: URL? = nil) {
        let base: URL
        if let baseDirectory {
            base = baseDirectory
        } else {
            let appSupport = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first ?? FileManager.default.temporaryDirectory
            base = appSupport.appendingPathComponent("RadioNaoufal", isDirectory: true)
        }
        self.baseDirectory = base
        self.favoritesFile = base.appendingPathComponent("favorites.json")
        self.recentsFile = base.appendingPathComponent("recents.json")
        self.customStationsFile = base.appendingPathComponent("custom-stations.json")
        ensureDirectoryExists()
        loadAll()
    }

    // MARK: - Favorites

    public func favorite(at slot: Int) -> FavoriteSlot? {
        favorites.first(where: { $0.slotIndex == slot })
    }

    public func setFavorite(_ favorite: FavoriteSlot) {
        favorites.removeAll(where: { $0.slotIndex == favorite.slotIndex })
        favorites.append(favorite)
        favorites.sort(by: { $0.slotIndex < $1.slotIndex })
        save(favorites, to: favoritesFile)
    }

    public func clearFavorite(slot: Int) {
        favorites.removeAll(where: { $0.slotIndex == slot })
        save(favorites, to: favoritesFile)
    }

    // MARK: - Recents

    public func appendRecent(_ play: RecentPlay) {
        // Verwijder eerdere entries van zelfde station om duplicaten te voorkomen
        recents.removeAll(where: { $0.stationID == play.stationID })
        recents.insert(play, at: 0)
        if recents.count > Self.maxRecents {
            recents = Array(recents.prefix(Self.maxRecents))
        }
        save(recents, to: recentsFile)
    }

    public func clearRecents() {
        recents = []
        save(recents, to: recentsFile)
    }

    // MARK: - Custom Stations

    public func addCustomStation(_ station: UserCustomStation) {
        customStations.append(station)
        save(customStations, to: customStationsFile)
    }

    public func removeCustomStation(id: String) {
        customStations.removeAll(where: { $0.id == id })
        save(customStations, to: customStationsFile)
    }

    // MARK: - IO

    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    private func loadAll() {
        favorites = (try? load([FavoriteSlot].self, from: favoritesFile)) ?? []
        recents = (try? load([RecentPlay].self, from: recentsFile)) ?? []
        customStations = (try? load([UserCustomStation].self, from: customStationsFile)) ?? []
    }

    private func load<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error("Persistence write failed for \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
