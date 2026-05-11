import AVFoundation
import Foundation
import Observation
import os

/// Core audio engine die radio streams afspeelt via `AVPlayer`.
/// Installeert een `AudioTap` voor VU/FFT en parsed `timedMetadata`.
@MainActor
@Observable
public final class AudioEngine: NSObject {

    public private(set) var status: PlaybackStatus = .idle
    public private(set) var volume: Float = 0.75 {
        didSet {
            player.volume = volume
        }
    }
    public private(set) var currentStation: Station?
    public private(set) var nowPlaying: NowPlaying?

    /// True wanneer een externe casting-route actief is (Chromecast).
    /// Wanneer true wordt lokale audio gepauzeerd en streamt de Chromecast zelf.
    public var isExternalCasting: Bool = false {
        didSet {
            if isExternalCasting {
                player.pause()
            } else if status.isPlaying {
                player.play()
            }
        }
    }

    public let visualizer: VisualizerEngine

    /// De onderliggende `AVPlayer`. Wordt extern gebruikt door `AVRoutePickerView` voor AirPlay.
    public let player: AVPlayer

    private let logger = Logger(subsystem: "nl.naoufal.radio-naoufal", category: "AudioEngine")
    private var currentItem: AVPlayerItem?
    private var audioTap: AudioTap?
    private var icyMetadataTask: Task<Void, Never>?
    private var statusObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?
    private var bufferEmptyObservation: NSKeyValueObservation?
    private var likelyToKeepUpObservation: NSKeyValueObservation?
    private var errorObservation: NSKeyValueObservation?

    public init(visualizer: VisualizerEngine = VisualizerEngine()) {
        self.visualizer = visualizer
        self.player = AVPlayer()
        super.init()
        player.automaticallyWaitsToMinimizeStalling = true
        player.volume = volume
    }

    // MARK: - Public API

    public func load(station: Station) async {
        cleanupCurrentPlayback()
        currentStation = station
        nowPlaying = NowPlaying(title: nil, artist: nil, stationName: station.name, artworkURL: station.logoURL)
        status = .loading
        visualizer.reset()

        // Set up the player item
        let asset = AVURLAsset(url: station.streamURL, options: [
            "AVURLAssetHTTPHeaderFieldsKey": [
                "User-Agent": "RadioNaoufal/1.0 (macOS)",
                "Icy-MetaData": "1"
            ]
        ])
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 4

        // Audio tap voor visualizer
        let visualizerRef = visualizer
        let tap = AudioTap { frame in
            Task { @MainActor in
                visualizerRef.ingest(frame: frame)
            }
        }
        await tap.install(on: item)
        self.audioTap = tap

        attachItemObservers(item: item)

        currentItem = item
        player.replaceCurrentItem(with: item)

        // Subscribe to timed metadata via item.add(metadata: output)
        let metadataOutput = AVPlayerItemMetadataOutput(identifiers: nil)
        metadataOutput.setDelegate(self, queue: .main)
        item.add(metadataOutput)

        // Start ICY metadata parser parallel voor Shoutcast streams
        startICYMetadataParser(for: station)

        if !isExternalCasting {
            player.play()
            status = .playing
        }
    }

    public func play() {
        guard currentStation != nil else { return }
        if isExternalCasting { return }
        player.play()
        status = .playing
    }

    public func pause() {
        player.pause()
        status = .paused
    }

    public func togglePlayPause() {
        switch status {
        case .playing:
            pause()
        case .paused, .stopped, .idle, .error:
            play()
        case .loading:
            // negeren tot loading klaar is
            break
        }
    }

    public func stop() {
        cleanupCurrentPlayback()
        player.replaceCurrentItem(with: nil)
        currentStation = nil
        nowPlaying = nil
        status = .stopped
        visualizer.reset()
    }

    public func setVolume(_ value: Float) {
        volume = min(1, max(0, value))
    }

    /// Fade-out audio over de gegeven duur en stop daarna.
    public func fadeOutAndStop(duration: TimeInterval) async {
        let steps = 30
        let stepDuration = duration / TimeInterval(steps)
        let startVolume = volume
        for step in 1...steps {
            let progress = Float(step) / Float(steps)
            setVolume(startVolume * (1 - progress))
            try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
        }
        stop()
        setVolume(startVolume)
    }

    // MARK: - Cleanup

    private func cleanupCurrentPlayback() {
        statusObservation?.invalidate()
        rateObservation?.invalidate()
        bufferEmptyObservation?.invalidate()
        likelyToKeepUpObservation?.invalidate()
        errorObservation?.invalidate()
        statusObservation = nil
        rateObservation = nil
        bufferEmptyObservation = nil
        likelyToKeepUpObservation = nil
        errorObservation = nil

        if let item = currentItem {
            audioTap?.detach(from: item)
        }
        audioTap = nil
        icyMetadataTask?.cancel()
        icyMetadataTask = nil
        currentItem = nil
    }

    private func attachItemObservers(item: AVPlayerItem) {
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch item.status {
                case .failed:
                    let message = item.error?.localizedDescription ?? String(localized: "Onbekende fout")
                    self.status = .error(message)
                    self.logger.error("Player item failed: \(message, privacy: .public)")
                case .readyToPlay:
                    if !self.isExternalCasting {
                        self.status = .playing
                    }
                default:
                    break
                }
            }
        }

        bufferEmptyObservation = item.observe(\.isPlaybackBufferEmpty, options: [.new]) { [weak self] _, change in
            Task { @MainActor [weak self] in
                if change.newValue == true {
                    self?.status = .loading
                }
            }
        }

        likelyToKeepUpObservation = item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] _, change in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if change.newValue == true, !self.isExternalCasting {
                    self.status = .playing
                }
            }
        }
    }

    // MARK: - ICY metadata

    private func startICYMetadataParser(for station: Station) {
        icyMetadataTask?.cancel()
        let url = station.streamURL
        let stationName = station.name
        let logoURL = station.logoURL
        let weakEngine = WeakEngineRef(self)
        icyMetadataTask = Task.detached {
            await ICYMetadataParser.streamMetadata(from: url) { @Sendable metadata in
                Task { @MainActor in
                    guard let engine = weakEngine.value else { return }
                    guard let metadata else { return }
                    let parsed = ICYMetadataParser.parseStreamTitle(metadata.streamTitle)
                    engine.nowPlaying = NowPlaying(
                        title: parsed.title,
                        artist: parsed.artist,
                        stationName: stationName,
                        artworkURL: logoURL
                    )
                }
            }
        }
    }
}

/// Sendable holder voor een weak reference naar `AudioEngine` zodat we hem veilig
/// kunnen capturen in detached async closures.
private final class WeakEngineRef: @unchecked Sendable {
    weak var value: AudioEngine?
    init(_ value: AudioEngine) { self.value = value }
}

// MARK: - AVPlayerItemMetadataOutputPushDelegate

extension AudioEngine: AVPlayerItemMetadataOutputPushDelegate {
    public nonisolated func metadataOutput(
        _ output: AVPlayerItemMetadataOutput,
        didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
        from track: AVPlayerItemTrack?
    ) {
        let weakEngine = WeakEngineRef(self)
        // We bewust gebruiken de deprecated `stringValue` voor synchrone toegang vanuit
        // de nonisolated callback. AVPlayerItemMetadataOutputPushDelegate kan geen
        // async/await voor strict-concurrency-safe metadata loading uitvoeren.
        var collected: [String] = []
        for group in groups {
            for metadata in group.items {
                if let stringValue = Self.legacyStringValue(of: metadata) {
                    collected.append(stringValue)
                }
            }
        }
        guard !collected.isEmpty else { return }
        Task { @MainActor in
            guard let engine = weakEngine.value, let station = engine.currentStation else { return }
            for stringValue in collected {
                let parsed = ICYMetadataParser.parseStreamTitle(stringValue)
                if parsed.title != nil || parsed.artist != nil {
                    engine.nowPlaying = NowPlaying(
                        title: parsed.title,
                        artist: parsed.artist,
                        stationName: station.name,
                        artworkURL: station.logoURL
                    )
                }
            }
        }
    }

    nonisolated private static func legacyStringValue(of item: AVMetadataItem) -> String? {
        let bridged = item as NSObject
        return bridged.value(forKey: "stringValue") as? String
    }
}
