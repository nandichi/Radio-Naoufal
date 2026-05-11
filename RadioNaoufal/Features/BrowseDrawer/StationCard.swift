import SwiftUI

struct StationCard: View {
    let station: Station
    let isPlaying: Bool
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AsyncImage(url: station.logoURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    InitialsBadge(name: station.name)
                }
                .frame(width: 44, height: 44)
                .background(BoomboxTheme.chassisLight)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(station.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(station.genre.localizedLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                        if let bitrate = station.bitrate {
                            Text(verbatim: "•")
                                .foregroundStyle(.white.opacity(0.3))
                            Text("\(bitrate) kbps")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }

                Spacer(minLength: 8)

                if isPlaying {
                    NowPlayingIndicator()
                        .frame(width: 18, height: 14)
                } else if hovered {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(BoomboxTheme.amber)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(BoomboxTheme.amber.opacity(0.15)))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPlaying ? BoomboxTheme.amber.opacity(0.12) : Color.white.opacity(hovered ? 0.07 : 0.0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isPlaying ? BoomboxTheme.amber.opacity(0.5) : Color.white.opacity(0.05), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

struct InitialsBadge: View {
    let name: String

    var body: some View {
        ZStack {
            BoomboxTheme.amber.opacity(0.2)
            Text(initials)
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(BoomboxTheme.amber)
        }
    }

    private var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            let first = words[0].first.map(String.init) ?? "?"
            let second = words[1].first.map(String.init) ?? ""
            return (first + second).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

struct NowPlayingIndicator: View {
    @State private var levels: [CGFloat] = [0.3, 0.7, 0.5, 0.8]

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(BoomboxTheme.amber)
                    .frame(width: 2.5, height: 14 * levels[i])
                    .animation(
                        .easeInOut(duration: Double.random(in: 0.4...0.8))
                            .repeatForever()
                            .delay(Double(i) * 0.1),
                        value: levels
                    )
            }
        }
        .onAppear {
            levels = [0.9, 0.4, 0.7, 0.5]
        }
    }
}
