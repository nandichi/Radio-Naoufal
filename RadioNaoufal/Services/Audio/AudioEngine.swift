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
    public private(set) var currentEpisode: PodcastEpisode?
    public private(set) var currentPodcast: Podcast?
    public private(set) var currentEpisodeTime: TimeInterval = 0
    public private(set) var currentEpisodeDuration: TimeInterval = 0
    public private(set) var nowPlaying: NowPlaying?

    /// True wanneer we momenteel een time-shifted (rewinded) tmp-file afspelen i.p.v. de live stream.
    public private(set) var isTimeShifted: Bool = false

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
    private var lastArtworkKey: String = ""
    private var timeObserverToken: Any?
    private var lastProgressSaveTime: TimeInterval = 0

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
        currentEpisode = nil
        currentPodcast = nil
        currentEpisodeTime = 0
        currentEpisodeDuration = 0
        nowPlaying = NowPlaying(title: nil, artist: nil, stationName: station.name, artworkURL: station.logoURL)
        status = .loading
        visualizer.reset()
        lastArtworkKey = ""

        // Set up the player item
        let asset = AVURLAsset(url: station.streamURL, options: [
            "AVURLAssetHTTPHeaderFieldsKey": [
                "User-Agent": "RadioNaoufal/1.0 (macOS)",
                "Icy-MetaData": "1"
            ]
        ])
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 4

        // Audio tap voor visualizer + EQ-processing + time-shift capture
        let visualizerRef = visualizer
        let tap = AudioTap { frame in
            Task { @MainActor in
                visualizerRef.ingest(frame: frame)
            }
        }
        let storedPreset = UserDefaults.standard.string(forKey: AppPreferences.Keys.eqPreset) ?? AppPreferences.Defaults.eqPreset
        tap.eqProcessor.setPresetByName(storedPreset)
        // Capture laatste 35s naar ringbuffer voor rewind-functionaliteit (alleen voor live streams)
        tap.timeShiftBuffer = TimeShiftBuffer()
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

    /// Laadt een podcast-episode. Resume-positie wordt automatisch uit DataStore gehaald.
    public func loadEpisode(_ episode: PodcastEpisode, podcast: Podcast, dataStore: DataStore = .shared) async {
        cleanupCurrentPlayback()
        currentStation = nil
        currentEpisode = episode
        currentPodcast = podcast
        currentEpisodeTime = 0
        currentEpisodeDuration = episode.duration ?? 0
        nowPlaying = NowPlaying(
            title: episode.title,
            artist: podcast.author ?? podcast.title,
            stationName: podcast.title,
            artworkURL: episode.artworkURL ?? podcast.artworkURL
        )
        status = .loading
        visualizer.reset()
        lastArtworkKey = ""

        let asset = AVURLAsset(url: episode.audioURL, options: [
            "AVURLAssetHTTPHeaderFieldsKey": [
                "User-Agent": "RadioNaoufal/1.0 (macOS)"
            ]
        ])
        let item = AVPlayerItem(asset: asset)

        let visualizerRef = visualizer
        let tap = AudioTap { frame in
            Task { @MainActor in
                visualizerRef.ingest(frame: frame)
            }
        }
        let storedPreset = UserDefaults.standard.string(forKey: AppPreferences.Keys.eqPreset) ?? AppPreferences.Defaults.eqPreset
        tap.eqProcessor.setPresetByName(storedPreset)
        await tap.install(on: item)
        self.audioTap = tap

        attachItemObservers(item: item)

        currentItem = item
        player.replaceCurrentItem(with: item)

        // Resume positie
        if let progress = dataStore.progress(for: episode.id), progress.positionSeconds > 5 {
            let seekTime = CMTime(seconds: progress.positionSeconds, preferredTimescale: 600)
            await item.seek(to: seekTime)
            currentEpisodeTime = progress.positionSeconds
        }

        installTimeObserver(dataStore: dataStore)

        if !isExternalCasting {
            player.play()
            status = .playing
        }
    }

    public func play() {
        guard currentStation != nil || currentEpisode != nil else { return }
        if isExternalCasting { return }
        player.play()
        status = .playing
    }

    /// Spring naar een tijdpositie binnen de huidige episode (geen effect op live streams).
    public func seekEpisode(to seconds: TimeInterval) {
        guard currentEpisode != nil, let item = currentItem else { return }
        let target = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
        Task {
            await item.seek(to: target)
            currentEpisodeTime = seconds
        }
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
        currentEpisode = nil
        currentPodcast = nil
        currentEpisodeTime = 0
        currentEpisodeDuration = 0
        nowPlaying = nil
        status = .stopped
        visualizer.reset()
    }

    public func setVolume(_ value: Float) {
        volume = min(1, max(0, value))
    }

    /// Switch de actieve EQ-preset op de huidige AudioTap. Veilig om live aan te roepen.
    public func setEQPreset(_ name: String) {
        audioTap?.eqProcessor.setPresetByName(name)
    }

    /// True als er voldoende historische audio in de ringbuffer staat voor rewind.
    public var canRewind: Bool {
        guard currentStation != nil, !isTimeShifted else { return false }
        return audioTap?.timeShiftBuffer?.hasSufficientHistory(seconds: 5) ?? false
    }

    /// Spring `seconds` terug in de live stream door de tmp time-shift file af te spelen.
    /// Wanneer de file is afgespeeld keert het systeem automatisch terug naar de live stream.
    public func rewindToBuffer(seconds: TimeInterval = 30) async {
        guard let station = currentStation,
              let buffer = audioTap?.timeShiftBuffer,
              !isTimeShifted else { return }

        guard let snapshot = buffer.snapshot(seconds: seconds), snapshot.left.count > 0 else { return }

        let url = RewindFileWriter.makeURL()
        do {
            try await RewindFileWriter.write(left: snapshot.left, right: snapshot.right, sampleRate: 44_100, to: url)
        } catch {
            logger.error("Rewind file write failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        // Cleanup huidige live stream (zonder station-state te verliezen)
        cleanupCurrentPlayback()

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)

        let visualizerRef = visualizer
        let tap = AudioTap { frame in
            Task { @MainActor in
                visualizerRef.ingest(frame: frame)
            }
        }
        let storedPreset = UserDefaults.standard.string(forKey: AppPreferences.Keys.eqPreset) ?? AppPreferences.Defaults.eqPreset
        tap.eqProcessor.setPresetByName(storedPreset)
        await tap.install(on: item)
        self.audioTap = tap
        self.currentItem = item

        attachItemObservers(item: item)

        // Notificatie bij file-end -> automatisch terugvallen op live stream
        let weakSelf = WeakEngineRef(self)
        let stationRef = station
        let urlRef = url
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            Task { @MainActor in
                guard let engine = weakSelf.value else { return }
                engine.isTimeShifted = false
                await engine.load(station: stationRef)
                try? FileManager.default.removeItem(at: urlRef)
            }
        }

        isTimeShifted = true
        player.replaceCurrentItem(with: item)
        player.play()
        status = .playing
    }

    /// Spring terug naar de live stream. Verwerpt de huidige time-shift file.
    public func returnToLive() async {
        guard isTimeShifted, let station = currentStation else { return }
        isTimeShifted = false
        await load(station: station)
    }

    // MARK: - Episode time observer

    private func installTimeObserver(dataStore: DataStore) {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        let weakSelf = WeakEngineRef(self)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            Task { @MainActor in
                guard let engine = weakSelf.value else { return }
                let seconds = time.seconds
                guard seconds.isFinite else { return }
                engine.currentEpisodeTime = seconds

                // Update duration vanuit item (eerste keer beschikbaar zodra metadata geladen)
                if let item = engine.currentItem, engine.currentEpisodeDuration == 0 {
                    let dur = item.duration.seconds
                    if dur.isFinite && dur > 0 {
                        engine.currentEpisodeDuration = dur
                    }
                }

                // Save progress elke ~5 seconden, throttled
                if seconds - engine.lastProgressSaveTime > 5, let episode = engine.currentEpisode {
                    engine.lastProgressSaveTime = seconds
                    dataStore.setProgress(.init(episodeID: episode.id, positionSeconds: seconds))
                }
            }
        }
    }

    private func removeTimeObserver() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
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
        // Save final progress voor de episode die we verlaten
        if let episode = currentEpisode, currentEpisodeTime > 5 {
            DataStore.shared.setProgress(.init(episodeID: episode.id, positionSeconds: currentEpisodeTime))
        }
        removeTimeObserver()
        lastProgressSaveTime = 0

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
                    engine.scheduleArtworkLookup(artist: parsed.artist, title: parsed.title, stationName: stationName, fallback: logoURL)
                }
            }
        }
    }

    /// Vraagt een betere artwork-URL op via iTunes Search en update `nowPlaying.artworkURL`
    /// bij een hit. Gebruikt een `lastArtworkKey` om duplicate lookups te vermijden.
    fileprivate func scheduleArtworkLookup(artist: String?, title: String?, stationName: String, fallback: URL?) {
        let key = "\(artist ?? "")|\(title ?? "")".lowercased()
        guard !key.isEmpty, key != lastArtworkKey else { return }
        lastArtworkKey = key

        let weakEngine = WeakEngineRef(self)
        Task.detached { [artist, title, stationName, fallback] in
            let resolved = await ArtworkFetcher.shared.artworkURL(artist: artist, title: title)
            await MainActor.run {
                guard let engine = weakEngine.value else { return }
                guard let current = engine.nowPlaying else { return }
                // Alleen updaten als track-info nog match (race-vermijding)
                guard current.artist == artist && current.title == title else { return }
                engine.nowPlaying = NowPlaying(
                    title: title,
                    artist: artist,
                    stationName: stationName,
                    artworkURL: resolved ?? fallback
                )
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
                    engine.scheduleArtworkLookup(artist: parsed.artist, title: parsed.title, stationName: station.name, fallback: station.logoURL)
                }
            }
        }
    }

    nonisolated private static func legacyStringValue(of item: AVMetadataItem) -> String? {
        let bridged = item as NSObject
        return bridged.value(forKey: "stringValue") as? String
    }
}
