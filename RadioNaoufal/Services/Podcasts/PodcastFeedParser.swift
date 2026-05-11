import Foundation
import os

/// Lichtgewicht RSS/iTunes-podcast XML parser op basis van Foundation `XMLParser`.
/// Ondersteunt: RSS 2.0 channel + items, iTunes namespace voor duration/image/author.
public final class PodcastFeedParser: NSObject, @unchecked Sendable {

    public struct FeedResult: Sendable {
        public let podcast: Podcast
        public let episodes: [PodcastEpisode]
    }

    public enum ParserError: Error {
        case invalidData
        case parseFailed
    }

    private let logger = Logger(subsystem: "nl.naoufal.radio-naoufal", category: "PodcastFeedParser")

    public override init() {
        super.init()
    }

    public func parse(data: Data, feedURL: URL, podcastID: String) async throws -> FeedResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<FeedResult, Error>) in
            let helper = ParserHelper(feedURL: feedURL, podcastID: podcastID)
            let parser = XMLParser(data: data)
            parser.delegate = helper
            parser.shouldProcessNamespaces = false

            if parser.parse() {
                let podcast = Podcast(
                    id: podcastID,
                    title: helper.channelTitle ?? "Onbekende podcast",
                    author: helper.channelAuthor,
                    summary: helper.channelDescription,
                    feedURL: feedURL,
                    artworkURL: helper.channelArtwork,
                    categories: helper.channelCategories
                )
                continuation.resume(returning: FeedResult(podcast: podcast, episodes: helper.episodes))
            } else {
                continuation.resume(throwing: ParserError.parseFailed)
            }
        }
    }

    public func fetchAndParse(url: URL, podcastID: String) async throws -> FeedResult {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("RadioNaoufal/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/rss+xml, application/xml;q=0.9, */*;q=0.5", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ParserError.invalidData
        }
        return try await parse(data: data, feedURL: url, podcastID: podcastID)
    }
}

// MARK: - XMLParser delegate helper

private final class ParserHelper: NSObject, XMLParserDelegate {
    let feedURL: URL
    let podcastID: String

    var channelTitle: String?
    var channelDescription: String?
    var channelArtwork: URL?
    var channelAuthor: String?
    var channelCategories: [String] = []

    var episodes: [PodcastEpisode] = []

    private var inItem: Bool = false
    private var currentElement: String = ""
    private var currentCharacters: String = ""

    private var itemTitle: String?
    private var itemDescription: String?
    private var itemAudioURL: URL?
    private var itemDuration: TimeInterval?
    private var itemPublished: Date?
    private var itemArtwork: URL?
    private var itemGUID: String?

    private static let rfc822Formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return f
    }()

    init(feedURL: URL, podcastID: String) {
        self.feedURL = feedURL
        self.podcastID = podcastID
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentCharacters = ""

        switch elementName {
        case "item":
            inItem = true
            itemTitle = nil
            itemDescription = nil
            itemAudioURL = nil
            itemDuration = nil
            itemPublished = nil
            itemArtwork = nil
            itemGUID = nil
        case "enclosure":
            if inItem, let urlStr = attributeDict["url"], let url = URL(string: urlStr) {
                itemAudioURL = url
            }
        case "itunes:image":
            if let href = attributeDict["href"], let url = URL(string: href) {
                if inItem {
                    itemArtwork = url
                } else {
                    channelArtwork = url
                }
            }
        case "itunes:category":
            if !inItem, let text = attributeDict["text"] {
                channelCategories.append(text)
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentCharacters += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let str = String(data: CDATABlock, encoding: .utf8) {
            currentCharacters += str
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = currentCharacters.trimmingCharacters(in: .whitespacesAndNewlines)

        if inItem {
            switch elementName {
            case "title":
                itemTitle = trimmed
            case "description", "itunes:summary":
                if itemDescription == nil || (itemDescription?.isEmpty ?? true) {
                    itemDescription = trimmed
                }
            case "pubDate":
                itemPublished = ParserHelper.rfc822Formatter.date(from: trimmed)
            case "itunes:duration":
                itemDuration = ParserHelper.parseDuration(trimmed)
            case "guid":
                itemGUID = trimmed
            case "item":
                if let audio = itemAudioURL, let title = itemTitle {
                    let id = itemGUID ?? audio.absoluteString
                    let episode = PodcastEpisode(
                        id: id,
                        podcastID: podcastID,
                        title: title,
                        summary: itemDescription,
                        audioURL: audio,
                        duration: itemDuration,
                        publishedAt: itemPublished,
                        artworkURL: itemArtwork
                    )
                    episodes.append(episode)
                }
                inItem = false
            default:
                break
            }
        } else {
            switch elementName {
            case "title":
                if channelTitle == nil { channelTitle = trimmed }
            case "description", "itunes:summary":
                if channelDescription == nil || (channelDescription?.isEmpty ?? true) {
                    channelDescription = trimmed
                }
            case "itunes:author":
                channelAuthor = trimmed
            default:
                break
            }
        }

        currentCharacters = ""
        currentElement = ""
    }

    /// Parseert ISO/HH:MM:SS/seconden formats voor `itunes:duration`.
    static func parseDuration(_ value: String) -> TimeInterval? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains(":") {
            let components = trimmed.split(separator: ":").map { Double($0) ?? 0 }
            switch components.count {
            case 3: return components[0] * 3600 + components[1] * 60 + components[2]
            case 2: return components[0] * 60 + components[1]
            default: return nil
            }
        }
        return Double(trimmed)
    }
}
