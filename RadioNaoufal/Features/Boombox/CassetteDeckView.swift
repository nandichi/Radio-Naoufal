import SwiftUI

/// Centrale cassette deck met Now Playing display en EQ visualizer.
struct CassetteDeckView: View {
    @Environment(PlayerViewModel.self) private var player

    @State private var scrollOffset: CGFloat = 0
    @State private var lastTitle: String = ""
    @State private var showStationInfo: Bool = false

    var body: some View {
        ZStack {
            // Frame
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.06, blue: 0.07),
                            Color(red: 0.10, green: 0.11, blue: 0.13)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(BoomboxTheme.chromeBevel, lineWidth: 1.5)
                )

            VStack(spacing: 8) {
                // Top: cassette tape "window"
                CassetteWindow(isPlaying: player.status.isPlaying)
                    .frame(height: 56)

                // LCD scrolling now-playing + station
                LCDDisplay()
                    .frame(height: 38)

                // EQ visualizer
                EQVisualizerView()
                    .frame(height: 36)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard player.currentStation != nil else { return }
            showStationInfo.toggle()
        }
        .help(String(localized: "Klik voor station-info"))
        .popover(isPresented: $showStationInfo, arrowEdge: .top) {
            if let station = player.currentStation {
                StationInfoPopover(
                    station: station,
                    nowPlaying: player.nowPlaying,
                    onDismiss: { showStationInfo = false }
                )
            } else {
                EmptyView()
            }
        }
    }
}

/// Cassette-tape window: twee draaiende cogs en magnetische tape.
private struct CassetteWindow: View {
    let isPlaying: Bool
    @State private var rotation: Double = 0

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let cogSize: CGFloat = height * 0.7
            let spacing = geometry.size.width - cogSize * 2 - 30

            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.black.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )

                HStack(spacing: spacing) {
                    CassetteCog(size: cogSize)
                        .rotationEffect(.degrees(rotation))
                    CassetteCog(size: cogSize)
                        .rotationEffect(.degrees(rotation))
                }
                .padding(.horizontal, 15)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rotation = isPlaying ? 360 : 0
            }
        }
        .onChange(of: isPlaying) { _, newValue in
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rotation = newValue ? rotation + 360 : rotation
            }
        }
    }
}

private struct CassetteCog: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(BoomboxTheme.chassisDark)
                .overlay(
                    Circle()
                        .strokeBorder(BoomboxTheme.chrome.opacity(0.6), lineWidth: 1)
                )
            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let outerRadius = canvasSize.width / 2 - 2
                let innerRadius = canvasSize.width / 2 - 8
                let teeth = 8
                for i in 0..<teeth {
                    let angle = Double(i) / Double(teeth) * 2 * .pi
                    var path = Path()
                    path.move(to: CGPoint(
                        x: center.x + cos(angle) * innerRadius,
                        y: center.y + sin(angle) * innerRadius
                    ))
                    path.addLine(to: CGPoint(
                        x: center.x + cos(angle) * outerRadius,
                        y: center.y + sin(angle) * outerRadius
                    ))
                    context.stroke(path, with: .color(BoomboxTheme.chrome.opacity(0.8)), lineWidth: 2)
                }
            }
            Circle()
                .fill(BoomboxTheme.chassisLight)
                .frame(width: size * 0.18, height: size * 0.18)
        }
        .frame(width: size, height: size)
    }
}

/// LCD-display met scrollende titel en frequentie + station-naam.
private struct LCDDisplay: View {
    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(BoomboxTheme.lcdBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color.black, lineWidth: 1)
                )
                .overlay(
                    // Subtle scan-lines
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.18),
                            Color.black.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blendMode(.multiply)
                    .allowsHitTesting(false)
                )

            HStack(spacing: 12) {
                // Linkerkant: status + frequency
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(player.status.isPlaying ? BoomboxTheme.presetGreen : Color.gray.opacity(0.4))
                            .frame(width: 6, height: 6)
                            .shadow(color: player.status.isPlaying ? BoomboxTheme.presetGreen : .clear, radius: 3)
                        Text(statusText)
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundStyle(BoomboxTheme.lcdAmber)
                    }
                    Text(frequencyText)
                        .font(.system(size: 16, weight: .heavy, design: .monospaced))
                        .foregroundStyle(BoomboxTheme.lcdAmber)
                        .shadow(color: BoomboxTheme.amberGlow.opacity(0.6), radius: 2)
                }
                .frame(width: 110, alignment: .leading)

                // Verticale separator
                Rectangle()
                    .fill(BoomboxTheme.lcdAmber.opacity(0.25))
                    .frame(width: 1)

                // Rechterkant: scrolling now playing
                MarqueeText(
                    text: displayText,
                    font: .system(size: 13, weight: .heavy, design: .monospaced),
                    color: BoomboxTheme.lcdAmber
                )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }

    private var statusText: String {
        switch player.status {
        case .playing: return "ON AIR"
        case .paused: return "PAUSED"
        case .loading: return "TUNING.."
        case .stopped, .idle: return "STDBY"
        case .error: return "ERROR"
        }
    }

    private var frequencyText: String {
        if let dial = player.currentStation?.dial {
            return String(format: "%.1f", dial) + (dial > 200 ? " kHz" : " MHz")
        }
        return "----.- MHz"
    }

    private var displayText: String {
        if case .error(let msg) = player.status {
            return msg
        }
        if let np = player.nowPlaying {
            return np.displayLine.uppercased()
        }
        return player.currentStation?.name.uppercased() ?? String(localized: "GEEN ZENDER GESELECTEERD")
    }
}

/// Tekst die horizontaal scrolt als ze te breed is voor het frame.
private struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Text(text)
                    .font(font)
                    .foregroundStyle(color)
                    .shadow(color: BoomboxTheme.amberGlow.opacity(0.4), radius: 2)
                    .lineLimit(1)
                    .fixedSize()
                    .background(
                        GeometryReader { textProxy in
                            Color.clear
                                .onAppear {
                                    textWidth = textProxy.size.width
                                    containerWidth = proxy.size.width
                                    startAnimationIfNeeded()
                                }
                                .onChange(of: textProxy.size.width) { _, newValue in
                                    textWidth = newValue
                                    startAnimationIfNeeded()
                                }
                        }
                    )
                    .offset(x: offset)
                    .clipped()
                    .onChange(of: text) { _, _ in
                        offset = 0
                        startAnimationIfNeeded()
                    }
            }
            .clipped()
        }
    }

    private func startAnimationIfNeeded() {
        guard textWidth > containerWidth else {
            offset = 0
            return
        }
        let distance = textWidth - containerWidth + 24
        offset = 0
        withAnimation(.linear(duration: Double(distance) / 25).repeatForever(autoreverses: true).delay(0.6)) {
            offset = -distance
        }
    }
}
