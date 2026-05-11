import Foundation
import os

/// Parser voor SHOUTcast/Icecast ICY metadata (titel/artiest van het huidige nummer).
/// Opent een parallelle URLSession-verbinding naast `AVPlayer` om de inline metadata te lezen.
public enum ICYMetadataParser {

    public struct StreamMetadata: Sendable {
        public let streamTitle: String
        public let raw: [String: String]
    }

    public struct ParsedTrack: Sendable {
        public let title: String?
        public let artist: String?
    }

    private static let logger = Logger(subsystem: "nl.naoufal.radio-naoufal", category: "ICYMetadataParser")

    public static func parseStreamTitle(_ raw: String) -> ParsedTrack {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ParsedTrack(title: nil, artist: nil)
        }
        let separators: [String] = [" - ", " — ", " – "]
        for sep in separators {
            if let range = trimmed.range(of: sep) {
                let artist = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let title = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                return ParsedTrack(
                    title: title.isEmpty ? nil : title,
                    artist: artist.isEmpty ? nil : artist
                )
            }
        }
        return ParsedTrack(title: trimmed, artist: nil)
    }

    /// Streamt metadata-updates van een SHOUTcast/Icecast URL.
    /// De callback wordt aangeroepen telkens nieuwe metadata is geparsed (of `nil` bij stop/fout).
    public static func streamMetadata(
        from url: URL,
        onUpdate: @Sendable @escaping (StreamMetadata?) -> Void
    ) async {
        var request = URLRequest(url: url)
        request.setValue("RadioNaoufal/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("1", forHTTPHeaderField: "Icy-MetaData")
        request.timeoutInterval = 30

        do {
            let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                onUpdate(nil)
                return
            }
            guard let metaIntString = httpResponse.value(forHTTPHeaderField: "icy-metaint")
                ?? httpResponse.value(forHTTPHeaderField: "Icy-MetaInt"),
                  let metaInt = Int(metaIntString),
                  metaInt > 0 else {
                logger.debug("No icy-metaint header found for \(url.absoluteString, privacy: .public)")
                onUpdate(nil)
                return
            }

            var audioCounter = 0
            var iterator = asyncBytes.makeAsyncIterator()
            while !Task.isCancelled {
                if audioCounter < metaInt {
                    guard try await iterator.next() != nil else { break }
                    audioCounter += 1
                    continue
                }

                // Read 1 byte length
                guard let lengthByte = try await iterator.next() else { break }
                let metaLength = Int(lengthByte) * 16
                audioCounter = 0
                if metaLength == 0 { continue }

                var metaBytes: [UInt8] = []
                metaBytes.reserveCapacity(metaLength)
                for _ in 0..<metaLength {
                    if let byte = try await iterator.next() {
                        metaBytes.append(byte)
                    } else {
                        break
                    }
                }

                if let metaString = String(bytes: metaBytes, encoding: .utf8)
                    ?? String(bytes: metaBytes, encoding: .isoLatin1) {
                    let metadata = parseMetadataLine(metaString)
                    if !metadata.streamTitle.isEmpty {
                        onUpdate(metadata)
                    }
                }
            }
            onUpdate(nil)
        } catch {
            logger.debug("ICY metadata stream error: \(error.localizedDescription, privacy: .public)")
            onUpdate(nil)
        }
    }

    private static func parseMetadataLine(_ line: String) -> StreamMetadata {
        // Format: `StreamTitle='Artist - Title';StreamUrl='http://...';`
        var dict: [String: String] = [:]
        let pairs = line.split(separator: ";")
        for pair in pairs {
            let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard kv.count == 2 else { continue }
            var value = kv[1]
            if value.hasPrefix("'") { value.removeFirst() }
            if value.hasSuffix("'") { value.removeLast() }
            if value.hasSuffix("\0") { value = value.replacingOccurrences(of: "\0", with: "") }
            dict[kv[0].trimmingCharacters(in: .whitespaces)] = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let streamTitle = dict["StreamTitle"] ?? ""
        return StreamMetadata(streamTitle: streamTitle, raw: dict)
    }
}
