import Foundation
import Observation
import os

@MainActor
@Observable
public final class PlayerViewModel {

    public let audio: AudioEngine
    public let stations: StationsRepository
    public let cast: CastManager
    public let nowPlayingCenter: NowPlayingCenter
    public let dataStore: DataStore
    public let podcasts: PodcastsRepository

    public private(set) var output: OutputTarget = .local
    public private(set) var error: String?

    private let logger = Logger(subsystem: "nl.naoufal.radio-naoufal", category: "PlayerViewModel")

    public init(
        audio: AudioEngine = AudioEngine(),
        stations: StationsRepository = StationsRepository(),
        cast: CastManager = CastManager(),
        nowPlayingCenter: NowPlayingCenter = NowPlayingCenter(),
        dataStore: DataStore = DataStore.shared,
        podcasts: PodcastsRepository = PodcastsRepository()
    ) {
        self.audio = audio
        self.stations = stations
        self.cast = cast
        self.nowPlayingCenter = nowPlayingCenter
        self.dataStore = dataStore
        self.podcasts = podcasts

        setupRemoteCommands()
    }

    public var currentStation: Station? { audio.currentStation }
    public var nowPlaying: NowPlaying? { audio.nowPlaying }
    public var status: PlaybackStatus { audio.status }

    // MARK: - Public commands

    public func play(station: Station) {
        Task {
            await audio.load(station: station)
            nowPlayingCenter.update(state: audio.status, nowPlaying: audio.nowPlaying)
            recordRecent(station: station)
            AppPreferences.setLastStationID(station.id)
            if case .playing = cast.state {
                await cast.play(station: station)
            }
        }
    }

    public func toggle() {
        if case .playing(let name) = cast.state {
            Task { await cast.pause() }
            _ = name
            return
        }
        if case .connected(_) = cast.state, let station = currentStation {
            Task {
                await cast.play(station: station)
            }
            return
        }
        audio.togglePlayPause()
        nowPlayingCenter.update(state: audio.status, nowPlaying: audio.nowPlaying)
    }

    public func stop() {
        audio.stop()
        nowPlayingCenter.clear()
    }

    public func next() {
        let next = stations.nextStation(after: currentStation?.id)
        if let next { play(station: next) }
    }

    public func previous() {
        let prev = stations.previousStation(before: currentStation?.id)
        if let prev { play(station: prev) }
    }

    public func setVolume(_ value: Float) {
        audio.setVolume(value)
        Task { await cast.setVolume(value) }
        if UserDefaults.standard.bool(forKey: AppPreferences.Keys.rememberVolume) {
            UserDefaults.standard.set(Double(audio.volume), forKey: AppPreferences.Keys.defaultVolume)
        }
    }

    public func connectToChromecast(_ device: CastDevice) {
        cast.connect(to: device)
        audio.isExternalCasting = true
        output = .chromecast(deviceName: device.name)
    }

    public func disconnectChromecast() {
        cast.disconnect()
        audio.isExternalCasting = false
        output = .local
        if status.isPlaying == false, let station = currentStation {
            audio.play()
            _ = station
        }
    }

    public func handleScrubFromNowPlaying() {
        // No-op for live streams
    }

    // MARK: - Podcasts

    public func play(episode: PodcastEpisode, podcast: Podcast) {
        Task {
            await audio.loadEpisode(episode, podcast: podcast)
            nowPlayingCenter.update(state: audio.status, nowPlaying: audio.nowPlaying)
        }
    }

    public func seekEpisode(to seconds: TimeInterval) {
        audio.seekEpisode(to: seconds)
    }

    public var isPlayingEpisode: Bool {
        audio.currentEpisode != nil
    }

    // MARK: - Persistence (favorites + recent)

    public func favoriteSlot(at index: Int) -> Station? {
        guard let slot = dataStore.favorite(at: index) else { return nil }
        return stations.station(byID: slot.stationID)
    }

    public func assignFavorite(station: Station, to slotIndex: Int) {
        let favorite = DataStore.FavoriteSlot(
            slotIndex: slotIndex,
            stationID: station.id,
            stationName: station.name
        )
        dataStore.setFavorite(favorite)
    }

    public func clearFavorite(at slotIndex: Int) {
        dataStore.clearFavorite(slot: slotIndex)
    }

    public func recordRecent(station: Station) {
        let recent = DataStore.RecentPlay(stationID: station.id, stationName: station.name)
        dataStore.appendRecent(recent)
    }

    // MARK: - Remote commands

    private func setupRemoteCommands() {
        nowPlayingCenter.onPlay = { [weak self] in self?.audio.play() }
        nowPlayingCenter.onPause = { [weak self] in self?.audio.pause() }
        nowPlayingCenter.onToggle = { [weak self] in self?.toggle() }
        nowPlayingCenter.onNext = { [weak self] in self?.next() }
        nowPlayingCenter.onPrevious = { [weak self] in self?.previous() }
        nowPlayingCenter.onStop = { [weak self] in self?.stop() }
    }
}
