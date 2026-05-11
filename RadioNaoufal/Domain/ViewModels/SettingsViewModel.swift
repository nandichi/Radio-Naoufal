import Foundation
import Observation

@MainActor
@Observable
public final class SettingsViewModel {

    public private(set) var sleepTimerActive: Bool = false
    public private(set) var sleepTimerRemaining: TimeInterval = 0
    public private(set) var sleepTimerDuration: TimeInterval = 0

    private var sleepTask: Task<Void, Never>?
    private weak var player: PlayerViewModel?

    public init() {}

    public func bind(player: PlayerViewModel) {
        self.player = player
    }

    // MARK: - Preferences

    /// Vaste lijst van sleep-timer preset duraties (in minuten).
    public var sleepMinutesPresets: [Int] { [15, 30, 45, 60, 90] }

    /// Aanbevolen default sleep-duur uit UserDefaults. Wordt b.v. door SleepTimerPopover gebruikt
    /// om de eerste keer een sensible default voor te selecteren.
    public var defaultSleepMinutes: Int {
        let stored = AppPreferences.int(AppPreferences.Keys.sleepTimerDefaultMinutes)
        return stored > 0 ? stored : AppPreferences.Defaults.sleepTimerDefaultMinutes
    }

    /// Fade-out duur (s) die het uiteindelijke einde van de sleep timer aankondigt.
    public var sleepFadeDuration: TimeInterval {
        let stored = AppPreferences.double(AppPreferences.Keys.sleepTimerFadeDuration)
        return stored > 0 ? stored : AppPreferences.Defaults.sleepTimerFadeDuration
    }

    /// Past de UserDefaults waarden toe op de player bij app-start.
    public func applyInitialPreferences(to player: PlayerViewModel) {
        let storedVolume = AppPreferences.double(AppPreferences.Keys.defaultVolume)
        let initial = storedVolume > 0 ? Float(storedVolume) : Float(AppPreferences.Defaults.defaultVolume)
        player.setVolume(initial)
    }

    /// Bij app-start: indien autoplay aan staat en er een laatst-gespeelde zender bekend is,
    /// laad die zender en speel hem af.
    public func autoplayLastStationIfNeeded(player: PlayerViewModel) {
        guard AppPreferences.bool(AppPreferences.Keys.autoplayLastStation) else { return }
        guard let id = AppPreferences.string(AppPreferences.Keys.lastStationID) else { return }
        guard let station = player.stations.station(byID: id) else { return }
        player.play(station: station)
    }

    // MARK: - Sleep timer

    public func startSleepTimer(minutes: Int) {
        cancelSleepTimer()
        let duration = TimeInterval(minutes * 60)
        sleepTimerDuration = duration
        sleepTimerRemaining = duration
        sleepTimerActive = true

        sleepTask = Task { [weak self] in
            guard let self else { return }
            let start = Date()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                let elapsed = Date().timeIntervalSince(start)
                let remaining = max(0, duration - elapsed)
                self.sleepTimerRemaining = remaining
                if remaining <= 0 {
                    await self.fireSleep()
                    break
                }
            }
        }
    }

    public func cancelSleepTimer() {
        sleepTask?.cancel()
        sleepTask = nil
        sleepTimerActive = false
        sleepTimerRemaining = 0
        sleepTimerDuration = 0
    }

    private func fireSleep() async {
        guard let player else { return }
        await player.audio.fadeOutAndStop(duration: sleepFadeDuration)
        sleepTimerActive = false
        sleepTimerRemaining = 0
        sleepTimerDuration = 0
        sleepTask = nil
    }

    public var formattedRemaining: String {
        let totalSeconds = Int(sleepTimerRemaining)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
