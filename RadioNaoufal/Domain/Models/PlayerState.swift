import Foundation

public enum PlaybackStatus: Equatable, Sendable {
    case idle
    case loading
    case playing
    case paused
    case stopped
    case error(String)

    public var isPlaying: Bool {
        if case .playing = self { return true }
        return false
    }

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

public enum OutputTarget: Equatable, Sendable {
    case local
    case airplay(deviceName: String)
    case chromecast(deviceName: String)

    public var displayName: String {
        switch self {
        case .local: return String(localized: "Deze Mac")
        case .airplay(let name): return name
        case .chromecast(let name): return name
        }
    }

    public var isRemote: Bool {
        switch self {
        case .local: return false
        case .airplay, .chromecast: return true
        }
    }

    public var isChromecasting: Bool {
        if case .chromecast = self { return true }
        return false
    }
}
