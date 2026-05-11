import SwiftUI

/// Scrub-bar + skip-knoppen voor de actieve podcast-episode.
/// Wordt getoond in de BrowseDrawer header wanneer er een episode wordt afgespeeld.
struct PodcastPlayerControls: View {
    @Environment(PlayerViewModel.self) private var player

    @State private var isScrubbing: Bool = false
    @State private var scrubValue: Double = 0

    var body: some View {
        if let episode = player.audio.currentEpisode, let podcast = player.audio.currentPodcast {
            HStack(spacing: 12) {
                AsyncImage(url: episode.artworkURL ?? podcast.artworkURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    InitialsBadge(name: podcast.title)
                }
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 5))

                VStack(alignment: .leading, spacing: 2) {
                    Text(episode.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(durationString(currentTime))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                        scrubSlider
                        Text(durationString(totalTime))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    Button {
                        player.seekEpisode(to: max(0, currentTime - 15))
                    } label: {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.85))

                    Button {
                        player.toggle()
                    } label: {
                        Image(systemName: player.status.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(BoomboxTheme.amber))
                            .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)

                    Button {
                        player.seekEpisode(to: currentTime + 30)
                    } label: {
                        Image(systemName: "goforward.30")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.35))
        }
    }

    private var currentTime: TimeInterval {
        isScrubbing ? scrubValue : player.audio.currentEpisodeTime
    }

    private var totalTime: TimeInterval {
        let dur = player.audio.currentEpisodeDuration
        return dur > 0 ? dur : (player.audio.currentEpisode?.duration ?? 0)
    }

    private var scrubSlider: some View {
        Slider(
            value: Binding(
                get: { isScrubbing ? scrubValue : player.audio.currentEpisodeTime },
                set: { scrubValue = $0 }
            ),
            in: 0...max(1, totalTime),
            onEditingChanged: { editing in
                if editing {
                    isScrubbing = true
                    scrubValue = player.audio.currentEpisodeTime
                } else {
                    player.seekEpisode(to: scrubValue)
                    isScrubbing = false
                }
            }
        )
        .controlSize(.small)
        .tint(BoomboxTheme.amber)
        .frame(maxWidth: .infinity)
    }

    private func durationString(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
