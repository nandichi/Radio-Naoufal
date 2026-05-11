import Foundation

public struct Podcast: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var author: String?
    public var summary: String?
    public var feedURL: URL
    public var artworkURL: URL?
    public var categories: [String]
    public var subscribedAt: Date

    public init(
        id: String,
        title: String,
        author: String? = nil,
        summary: String? = nil,
        feedURL: URL,
        artworkURL: URL? = nil,
        categories: [String] = [],
        subscribedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.summary = summary
        self.feedURL = feedURL
        self.artworkURL = artworkURL
        self.categories = categories
        self.subscribedAt = subscribedAt
    }
}

public struct PodcastEpisode: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let podcastID: String
    public var title: String
    public var summary: String?
    public var audioURL: URL
    public var duration: TimeInterval?
    public var publishedAt: Date?
    public var artworkURL: URL?

    public init(
        id: String,
        podcastID: String,
        title: String,
        summary: String? = nil,
        audioURL: URL,
        duration: TimeInterval? = nil,
        publishedAt: Date? = nil,
        artworkURL: URL? = nil
    ) {
        self.id = id
        self.podcastID = podcastID
        self.title = title
        self.summary = summary
        self.audioURL = audioURL
        self.duration = duration
        self.publishedAt = publishedAt
        self.artworkURL = artworkURL
    }
}

public struct Chapter: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var startTime: TimeInterval
    public var artworkURL: URL?

    public init(id: UUID = UUID(), title: String, startTime: TimeInterval, artworkURL: URL? = nil) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.artworkURL = artworkURL
    }
}
