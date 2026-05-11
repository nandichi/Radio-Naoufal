import SwiftUI

/// Analoge tuner-band (88-108 MHz) met een naald op de huidige zenderpositie.
/// Stations worden lineair over de band verdeeld op basis van hun positie in de curated lijst.
struct TunerDialView: View {
    @Environment(PlayerViewModel.self) private var player
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                // Achtergrond met chrome bevel
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.16, green: 0.14, blue: 0.10),
                                Color(red: 0.07, green: 0.06, blue: 0.04)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(BoomboxTheme.chromeBevel, lineWidth: 1)
                    )

                // Schaal: hoofdstreepjes met getallen
                Canvas { context, size in
                    let labels: [Int] = [88, 92, 96, 100, 104, 108]
                    let bandStart: CGFloat = 12
                    let bandEnd: CGFloat = size.width - 12
                    let bandWidth = bandEnd - bandStart

                    for (i, label) in labels.enumerated() {
                        let progress = CGFloat(i) / CGFloat(labels.count - 1)
                        let x = bandStart + progress * bandWidth

                        // Hoofd-tick
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 10))
                        path.addLine(to: CGPoint(x: x, y: size.height - 18))
                        context.stroke(path, with: .color(BoomboxTheme.lcdAmber.opacity(0.85)), lineWidth: 1.3)

                        // Label
                        let text = Text("\(label)")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundColor(BoomboxTheme.lcdAmber)
                        let resolved = context.resolve(text)
                        context.draw(resolved, at: CGPoint(x: x, y: size.height - 6))
                    }

                    // Subticks
                    let subCount = 30
                    for i in 0...subCount {
                        let progress = CGFloat(i) / CGFloat(subCount)
                        let x = bandStart + progress * bandWidth
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 10))
                        let isMajor = i % 6 == 0
                        path.addLine(to: CGPoint(x: x, y: isMajor ? size.height - 18 : 18))
                        context.stroke(
                            path,
                            with: .color(BoomboxTheme.lcdAmber.opacity(isMajor ? 0.0 : 0.40)),
                            lineWidth: 0.7
                        )
                    }
                }

                // FM/AM label
                Text("FM")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(BoomboxTheme.lcdAmber.opacity(0.8))
                    .position(x: 14, y: 8)

                // Naald
                NeedleView()
                    .frame(width: 2, height: height - 14)
                    .position(
                        x: needleX(in: width),
                        y: height / 2
                    )
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: needleX(in: width))
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        let bandStart: CGFloat = 12
                        let bandEnd: CGFloat = width - 12
                        let bandWidth = bandEnd - bandStart
                        let x = min(bandEnd, max(bandStart, value.location.x))
                        let progress = (x - bandStart) / bandWidth
                        applyTuning(progress: progress)
                        dragOffset = 0
                    }
            )
        }
    }

    private func needleX(in width: CGFloat) -> CGFloat {
        let bandStart: CGFloat = 12
        let bandEnd: CGFloat = width - 12
        let bandWidth = bandEnd - bandStart

        guard let station = player.currentStation else {
            return bandStart
        }
        let stations = player.stations.curated
        guard let index = stations.firstIndex(of: station) else {
            return bandStart
        }
        let progress = CGFloat(index) / CGFloat(max(1, stations.count - 1))
        return bandStart + progress * bandWidth
    }

    private func applyTuning(progress: CGFloat) {
        let count = player.stations.curated.count
        guard count > 0 else { return }
        let clamped = min(1, max(0, progress))
        let index = Int(round(clamped * CGFloat(count - 1)))
        let station = player.stations.curated[index]
        if station.id != player.currentStation?.id {
            player.play(station: station)
        }
    }
}

private struct NeedleView: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        BoomboxTheme.presetRed.opacity(0.6),
                        BoomboxTheme.presetRed,
                        BoomboxTheme.presetRed.opacity(0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: BoomboxTheme.presetRed.opacity(0.7), radius: 2)
    }
}
