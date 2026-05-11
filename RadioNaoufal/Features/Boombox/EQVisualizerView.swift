import SwiftUI

/// Frequentie-bar visualizer (16 amber bars) gevoed door `VisualizerEngine`.
struct EQVisualizerView: View {
    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        GeometryReader { geometry in
            let bars = player.audio.visualizer.bars
            let barCount = max(1, bars.count)
            let totalWidth = geometry.size.width
            let height = geometry.size.height
            let gap: CGFloat = 2
            let barWidth = max(2, (totalWidth - CGFloat(barCount + 1) * gap) / CGFloat(barCount))

            HStack(alignment: .bottom, spacing: gap) {
                ForEach(0..<barCount, id: \.self) { index in
                    EQBar(
                        level: CGFloat(bars[index]),
                        height: height,
                        index: index,
                        total: barCount
                    )
                    .frame(width: barWidth)
                }
            }
            .frame(width: totalWidth, height: height)
            .padding(.horizontal, gap)
        }
    }
}

private struct EQBar: View {
    let level: CGFloat
    let height: CGFloat
    let index: Int
    let total: Int

    var body: some View {
        let segmentCount = 12
        let activeSegments = Int((level * CGFloat(segmentCount)).rounded())

        VStack(spacing: 1.5) {
            ForEach((0..<segmentCount).reversed(), id: \.self) { segment in
                Rectangle()
                    .fill(color(for: segment, active: segment < activeSegments))
                    .frame(height: max(2, (height - CGFloat(segmentCount) * 1.5) / CGFloat(segmentCount)))
                    .shadow(
                        color: segment < activeSegments ? glowColor(for: segment).opacity(0.7) : .clear,
                        radius: segment < activeSegments ? 1.4 : 0
                    )
            }
        }
        .animation(.easeOut(duration: 0.07), value: level)
    }

    private func color(for segment: Int, active: Bool) -> Color {
        guard active else {
            return BoomboxTheme.amber.opacity(0.07)
        }
        return glowColor(for: segment)
    }

    private func glowColor(for segment: Int) -> Color {
        if segment >= 10 {
            return BoomboxTheme.presetRed
        } else if segment >= 7 {
            return BoomboxTheme.amberGlow
        } else {
            return BoomboxTheme.amber
        }
    }
}
