import Foundation

public struct NowPlaying: Equatable, Sendable {
    public var title: String?
    public var artist: String?
    public var stationName: String
    public var artworkURL: URL?
    public var updatedAt: Date

    public init(
        title: String? = nil,
        artist: String? = nil,
        stationName: String,
        artworkURL: URL? = nil,
        updatedAt: Date = .now
    ) {
        self.title = title
        self.artist = artist
        self.stationName = stationName
        self.artworkURL = artworkURL
        self.updatedAt = updatedAt
    }

    public var displayLine: String {
        var components: [String] = []
        if let artist, !artist.isEmpty { components.append(artist) }
        if let title, !title.isEmpty { components.append(title) }
        if components.isEmpty { return stationName }
        return components.joined(separator: " - ")
    }

    public var hasTrackInfo: Bool {
        (title?.isEmpty == false) || (artist?.isEmpty == false)
    }
}
