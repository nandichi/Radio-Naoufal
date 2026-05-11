import SwiftUI

/// Toont een geabonneerde podcast met zijn lijst van episodes.
/// Bij selectie wordt de episode geladen in de player; resume-positie wordt automatisch toegepast.
struct PodcastDetailView: View {
    @Environment(PlayerViewModel.self) private var player

    let podcast: Podcast

    @State private var isLoading: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider().background(Color.white.opacity(0.05))

            episodeList
        }
        .task(id: podcast.id) {
            await loadIfNeeded()
        }
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            AsyncImage(url: podcast.artworkURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                InitialsBadge(name: podcast.title)
            }
            .frame(width: 64, height: 64)
            .background(BoomboxTheme.chassisLight)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(podcast.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let author = podcast.author {
                    Text(author)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                if let summary = podcast.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(2)
                }
            }

            Spacer()

            Button {
                Task {
                    isLoading = true
                    await player.podcasts.refreshEpisodes(for: podcast)
                    isLoading = false
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(8)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help(String(localized: "Ververs episodes"))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
    }

    private var episodeList: some View {
        Group {
            if isLoading && player.podcasts.episodes(for: podcast.id).isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if player.podcasts.episodes(for: podcast.id).isEmpty {
                Text(String(localized: "Geen episodes gevonden in deze feed."))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(player.podcasts.episodes(for: podcast.id)) { episode in
                            EpisodeRow(
                                episode: episode,
                                progress: player.dataStore.progress(for: episode.id),
                                isCurrent: player.audio.currentEpisode?.id == episode.id,
                                onPlay: { player.play(episode: episode, podcast: podcast) }
                            )
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func loadIfNeeded() async {
        if player.podcasts.episodes(for: podcast.id).isEmpty {
            isLoading = true
            await player.podcasts.refreshEpisodes(for: podcast)
            isLoading = false
        }
    }
}

struct EpisodeRow: View {
    let episode: PodcastEpisode
    let progress: DataStore.EpisodeProgress?
    let isCurrent: Bool
    let onPlay: () -> Void

    @State private var hovered: Bool = false

    private var progressFraction: Double? {
        guard let progress, let duration = episode.duration, duration > 0 else { return nil }
        return min(1, max(0, progress.positionSeconds / duration))
    }

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isCurrent ? BoomboxTheme.amber : Color.white.opacity(0.08))
                        .frame(width: 30, height: 30)
                    Image(systemName: isCurrent ? "waveform" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isCurrent ? .black : BoomboxTheme.amber)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(episode.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if let published = episode.publishedAt {
                            Text(relativeDate(published))
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        if let duration = episode.duration {
                            Text(verbatim: "•")
                                .foregroundStyle(.white.opacity(0.3))
                            Text(durationString(duration))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        if let fraction = progressFraction, fraction > 0.02, fraction < 0.98 {
                            Text(verbatim: "•")
                                .foregroundStyle(.white.opacity(0.3))
                            Text(verbatim: "\(Int(fraction * 100))% \(String(localized: "beluisterd"))")
                                .font(.system(size: 10))
                                .foregroundStyle(BoomboxTheme.amber.opacity(0.8))
                        }
                    }
                }

                Spacer(minLength: 4)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isCurrent ? BoomboxTheme.amber.opacity(0.1) : Color.white.opacity(hovered ? 0.05 : 0))
            )
            .overlay(alignment: .bottom) {
                if let fraction = progressFraction {
                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(BoomboxTheme.amber)
                            .frame(width: proxy.size.width * fraction, height: 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 2)
                    .padding(.horizontal, 4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    private func durationString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return String(format: "%d:%02d:00", hours, minutes)
        }
        return String(format: "%d min", minutes)
    }
}
