import SwiftUI

struct SpeakerView: View {

    enum Side {
        case left
        case right
    }

    let side: Side
    let level: CGFloat
    let isPlaying: Bool

    var body: some View {
        ZStack {
            // Speaker housing
            Circle()
                .fill(BoomboxTheme.chassisDark)
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color.white.opacity(0.05),
                                    Color.black.opacity(0.30)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 3)

            // Outer chrome ring
            Circle()
                .stroke(BoomboxTheme.chromeBevel, lineWidth: 2)
                .padding(6)

            // Dot grille
            SpeakerGrille()
                .padding(16)

            // Pulserende glow op het centrum
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            BoomboxTheme.amber.opacity(0.50 * level + 0.10),
                            BoomboxTheme.amber.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 70
                    )
                )
                .padding(20)
                .opacity(isPlaying ? 1 : 0)
                .scaleEffect(1 + level * 0.05)
                .animation(.easeInOut(duration: 0.1), value: level)

            // VU meter overlay in het hart van de speaker
            VUMeterView(level: level)
                .frame(width: 86, height: 56)
                .offset(y: 30)
        }
    }
}

/// Subview: dot grid op de speaker.
private struct SpeakerGrille: View {
    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let spacing: CGFloat = 7
            let dotSize: CGFloat = 2.6

            var y: CGFloat = -radius
            while y < radius {
                var x: CGFloat = -radius
                while x < radius {
                    let dx = x
                    let dy = y
                    let distance = sqrt(dx * dx + dy * dy)
                    if distance < radius - 4 {
                        let rect = CGRect(
                            x: center.x + dx - dotSize / 2,
                            y: center.y + dy - dotSize / 2,
                            width: dotSize,
                            height: dotSize
                        )
                        let alpha = 1.0 - (distance / radius) * 0.5
                        let path = Path(ellipseIn: rect)
                        context.fill(
                            path,
                            with: .color(Color.black.opacity(0.7 * alpha))
                        )
                        // Highlight bovenkant
                        let highlightRect = CGRect(
                            x: rect.minX,
                            y: rect.minY,
                            width: dotSize,
                            height: dotSize / 2
                        )
                        context.fill(
                            Path(ellipseIn: highlightRect),
                            with: .color(Color.white.opacity(0.05 * alpha))
                        )
                    }
                    x += spacing
                }
                y += spacing
            }
        }
        .clipShape(Circle())
        .background(
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.16, green: 0.16, blue: 0.18),
                            Color(red: 0.06, green: 0.06, blue: 0.07)
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 110
                    )
                )
        )
    }
}
