import Foundation
import MediaPlayer
import AppKit

/// Integratie met `MPNowPlayingInfoCenter` voor de macOS Now Playing widget
/// en `MPRemoteCommandCenter` voor media-keys.
@MainActor
public final class NowPlayingCenter {

    public typealias Action = @MainActor () -> Void

    private let infoCenter = MPNowPlayingInfoCenter.default()
    private let commandCenter = MPRemoteCommandCenter.shared()
    private var artworkTask: Task<Void, Never>?

    public var onPlay: Action?
    public var onPause: Action?
    public var onToggle: Action?
    public var onNext: Action?
    public var onPrevious: Action?
    public var onStop: Action?

    public init() {
        registerCommands()
    }

    deinit {
        artworkTask?.cancel()
    }

    public func update(state: PlaybackStatus, nowPlaying: NowPlaying?) {
        var info: [String: Any] = [:]
        if let nowPlaying {
            info[MPMediaItemPropertyTitle] = nowPlaying.title ?? nowPlaying.stationName
            info[MPMediaItemPropertyArtist] = nowPlaying.artist ?? nowPlaying.stationName
            info[MPMediaItemPropertyAlbumTitle] = nowPlaying.stationName
            info[MPNowPlayingInfoPropertyIsLiveStream] = true
            if state.isPlaying {
                info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
            } else {
                info[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
            }
        }
        infoCenter.nowPlayingInfo = info

        switch state {
        case .playing:
            infoCenter.playbackState = .playing
        case .paused:
            infoCenter.playbackState = .paused
        case .stopped, .idle:
            infoCenter.playbackState = .stopped
        case .loading:
            infoCenter.playbackState = .playing
        case .error:
            infoCenter.playbackState = .interrupted
        }

        if let artworkURL = nowPlaying?.artworkURL {
            loadArtwork(from: artworkURL)
        }
    }

    public func clear() {
        artworkTask?.cancel()
        artworkTask = nil
        infoCenter.nowPlayingInfo = nil
        infoCenter.playbackState = .stopped
    }

    private func registerCommands() {
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onPlay?() }
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onPause?() }
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onToggle?() }
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onNext?() }
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onPrevious?() }
            return .success
        }
        commandCenter.stopCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onStop?() }
            return .success
        }

        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.stopCommand.isEnabled = true
        commandCenter.changePlaybackRateCommand.isEnabled = false
        commandCenter.seekForwardCommand.isEnabled = false
        commandCenter.seekBackwardCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
    }

    private func loadArtwork(from url: URL) {
        artworkTask?.cancel()
        artworkTask = Task { [weak self] in
            guard let self else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled, let image = NSImage(data: data), image.size.width > 0 else {
                    return
                }
                // Belangrijk: MPMediaItemArtwork roept de requestHandler later aan op zijn
                // eigen accessQueue. Daarom maken we hem aan vanuit een nonisolated factory,
                // anders erft de closure @MainActor isolation en crasht de runtime.
                let artwork = NowPlayingCenter.makeArtwork(from: image)
                await MainActor.run {
                    var info = self.infoCenter.nowPlayingInfo ?? [:]
                    info[MPMediaItemPropertyArtwork] = artwork
                    self.infoCenter.nowPlayingInfo = info
                }
            } catch {
                // silent
            }
        }
    }

    /// Nonisolated factory: zorgt dat de requestHandler geen actor isolation erft.
    /// MPNowPlayingInfoCenter roept hem aan op een private dispatch queue; als de closure
    /// @MainActor isolated zou zijn, crasht Swift 6 met SIGTRAP via swift_task_checkIsolatedSwift.
    nonisolated private static func makeArtwork(from image: NSImage) -> MPMediaItemArtwork {
        let sendableImage = SendableImage(image)
        return MPMediaItemArtwork(boundsSize: image.size) { _ in sendableImage.image }
    }
}

/// Wrapper om een NSImage door een nonisolated/Sendable closure te kunnen lekken.
/// NSImage is in praktijk thread-safe voor read-only access nadat hij volledig is geladen.
private struct SendableImage: @unchecked Sendable {
    let image: NSImage
    init(_ image: NSImage) { self.image = image }
}
