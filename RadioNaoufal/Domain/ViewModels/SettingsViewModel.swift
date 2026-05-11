import Foundation
import Observation

@MainActor
@Observable
public final class SettingsViewModel {

    public var sleepMinutesPresets: [Int] { [15, 30, 45, 60, 90] }

    public private(set) var sleepTimerActive: Bool = false
    public private(set) var sleepTimerRemaining: TimeInterval = 0
    public private(set) var sleepTimerDuration: TimeInterval = 0

    private var sleepTask: Task<Void, Never>?
    private weak var player: PlayerViewModel?

    public init() {}

    public func bind(player: PlayerViewModel) {
        self.player = player
    }

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
        await player.audio.fadeOutAndStop(duration: 5)
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
