import Foundation
import AppKit
import UniformTypeIdentifiers

/// Exporteert/importeert favorieten en eigen zenders als versie-gestempelde JSON.
public enum FavoritesExporter {

    public enum MergeStrategy {
        case merge
        case replace
    }

    public struct ExportPayload: Codable, Sendable {
        public let version: Int
        public let exportedAt: Date
        public let favorites: [DataStore.FavoriteSlot]
        public let customStations: [DataStore.UserCustomStation]
    }

    public enum ExporterError: LocalizedError {
        case incompatibleVersion(found: Int, supported: Int)
        case decodeFailed(String)

        public var errorDescription: String? {
            switch self {
            case .incompatibleVersion(let found, let supported):
                return String(localized: "Bestand heeft versie \(found), deze app ondersteunt versie \(supported).")
            case .decodeFailed(let message):
                return String(localized: "Kon JSON niet lezen: \(message)")
            }
        }
    }

    public static let supportedVersion: Int = 1

    // MARK: - Payload

    @MainActor
    public static func payload(from dataStore: DataStore) -> ExportPayload {
        ExportPayload(
            version: supportedVersion,
            exportedAt: .now,
            favorites: dataStore.favorites,
            customStations: dataStore.customStations
        )
    }

    public static func write(_ payload: ExportPayload, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        try data.write(to: url, options: .atomic)
    }

    public static func read(from url: URL) throws -> ExportPayload {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let payload = try decoder.decode(ExportPayload.self, from: data)
            guard payload.version == supportedVersion else {
                throw ExporterError.incompatibleVersion(found: payload.version, supported: supportedVersion)
            }
            return payload
        } catch let error as ExporterError {
            throw error
        } catch {
            throw ExporterError.decodeFailed(error.localizedDescription)
        }
    }

    // MARK: - Apply

    @MainActor
    public static func apply(_ payload: ExportPayload, to dataStore: DataStore, strategy: MergeStrategy) {
        switch strategy {
        case .replace:
            dataStore.replaceAllFavorites(payload.favorites)
            dataStore.replaceAllCustomStations(payload.customStations)
        case .merge:
            for fav in payload.favorites {
                dataStore.setFavorite(fav)
            }
            let existingIDs = Set(dataStore.customStations.map(\.id))
            for station in payload.customStations where !existingIDs.contains(station.id) {
                dataStore.addCustomStation(station)
            }
        }
    }

    // MARK: - Panels

    @MainActor
    public static func runSavePanel(suggestedFilename: String) async -> URL? {
        let panel = NSSavePanel()
        panel.title = String(localized: "Exporteer favorieten")
        panel.nameFieldStringValue = suggestedFilename
        panel.allowedContentTypes = [UTType.json]
        panel.canCreateDirectories = true
        let response = panel.runModal()
        return response == .OK ? panel.url : nil
    }

    @MainActor
    public static func runOpenPanel() async -> URL? {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Kies een favorieten-bestand")
        panel.allowedContentTypes = [UTType.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        let response = panel.runModal()
        return response == .OK ? panel.url : nil
    }
}
