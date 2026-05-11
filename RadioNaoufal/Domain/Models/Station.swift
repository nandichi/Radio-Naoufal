import Foundation

public struct Station: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let name: String
    public let streamURL: URL
    public let logoURL: URL?
    public let homepageURL: URL?
    public let genre: Genre
    public let region: Region
    public let dial: Double?
    public let bitrate: Int?
    public let codec: Codec
    public let source: Source
    public let tags: [String]

    public enum Genre: String, Codable, CaseIterable, Sendable, Identifiable {
        case news
        case popClassics
        case alternative
        case classical
        case dutch
        case oldies
        case hits
        case top40
        case dance
        case rock
        case soulJazz
        case urban
        case business
        case regional
        case other

        public var id: String { rawValue }

        public var localizedLabel: String {
            switch self {
            case .news: return String(localized: "Nieuws")
            case .popClassics: return String(localized: "Pop Classics")
            case .alternative: return String(localized: "Alternatief")
            case .classical: return String(localized: "Klassiek")
            case .dutch: return String(localized: "Nederlandstalig")
            case .oldies: return String(localized: "Oldies")
            case .hits: return String(localized: "Hits")
            case .top40: return String(localized: "Top 40")
            case .dance: return String(localized: "Dance")
            case .rock: return String(localized: "Rock")
            case .soulJazz: return String(localized: "Soul & Jazz")
            case .urban: return String(localized: "Urban")
            case .business: return String(localized: "Zakelijk")
            case .regional: return String(localized: "Regionaal")
            case .other: return String(localized: "Overig")
            }
        }
    }

    public enum Region: String, Codable, CaseIterable, Sendable {
        case national
        case noordHolland
        case zuidHolland
        case utrecht
        case noordBrabant
        case gelderland
        case overijssel
        case drenthe
        case groningen
        case friesland
        case limburg
        case zeeland
        case flevoland
        case international
    }

    public enum Codec: String, Codable, Sendable {
        case mp3
        case aac
        case heAac
        case hls
        case ogg
        case unknown
    }

    public enum Source: String, Codable, Sendable {
        case curated
        case radioBrowser
        case userAdded
    }

    public init(
        id: String,
        name: String,
        streamURL: URL,
        logoURL: URL? = nil,
        homepageURL: URL? = nil,
        genre: Genre,
        region: Region = .national,
        dial: Double? = nil,
        bitrate: Int? = nil,
        codec: Codec = .mp3,
        source: Source = .curated,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.streamURL = streamURL
        self.logoURL = logoURL
        self.homepageURL = homepageURL
        self.genre = genre
        self.region = region
        self.dial = dial
        self.bitrate = bitrate
        self.codec = codec
        self.source = source
        self.tags = tags
    }
}

public extension Station {
    static let preview = Station(
        id: "preview-station",
        name: "NPO Radio 2",
        streamURL: URL(string: "https://icecast.omroep.nl/radio2-bb-mp3")!,
        logoURL: nil,
        genre: .popClassics,
        region: .national,
        dial: 92.6,
        bitrate: 128,
        codec: .mp3
    )
}
