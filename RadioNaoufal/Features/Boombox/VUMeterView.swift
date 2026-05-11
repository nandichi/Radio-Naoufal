import SwiftUI

/// Analoge VU-meter met naald die spring-animeert op een 0...1 niveau.
struct VUMeterView: View {

    let level: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let centerX = width / 2
            let centerY = height
            let radius = min(width, height * 2) / 2 * 0.92
            // Naald hoek: -55° (links, 0) tot +55° (rechts, max)
            let angleRange: CGFloat = 110
            let startAngle: CGFloat = -55
            let normalized = min(1, max(0, level))
            let needleAngle = startAngle + angleRange * normalized

            ZStack {
                // Achtergrond
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(BoomboxTheme.lcdBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )

                // Schaal: tick-marks
                Canvas { context, size in
                    let stepCount = 11
                    for step in 0..<stepCount {
                        let progress = CGFloat(step) / CGFloat(stepCount - 1)
                        let angle = (startAngle + angleRange * progress) * .pi / 180
                        let tickOuter = CGPoint(
                            x: centerX + cos(angle - .pi/2) * radius,
                            y: centerY + sin(angle - .pi/2) * radius
                        )
                        let tickInner = CGPoint(
                            x: centerX + cos(angle - .pi/2) * (radius - 6),
                            y: centerY + sin(angle - .pi/2) * (radius - 6)
                        )
                        var path = Path()
                        path.move(to: tickOuter)
                        path.addLine(to: tickInner)
                        let color: Color = progress > 0.78 ? BoomboxTheme.presetRed : BoomboxTheme.lcdAmber
                        context.stroke(path, with: .color(color.opacity(0.85)), lineWidth: 1.2)
                    }
                }

                // Naald
                Path { path in
                    path.move(to: CGPoint(x: centerX, y: centerY))
                    let angleRad = needleAngle * .pi / 180 - .pi / 2
                    path.addLine(to: CGPoint(
                        x: centerX + cos(angleRad) * radius * 0.95,
                        y: centerY + sin(angleRad) * radius * 0.95
                    ))
                }
                .stroke(BoomboxTheme.lcdAmber, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .shadow(color: BoomboxTheme.amberGlow.opacity(0.6), radius: 2)
                .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.55, blendDuration: 0.1), value: needleAngle)

                // Centrum pin
                Circle()
                    .fill(BoomboxTheme.chrome)
                    .frame(width: 6, height: 6)
                    .overlay(Circle().stroke(Color.black, lineWidth: 0.5))
                    .position(x: centerX, y: centerY)

                // Label
                Text("VU")
                    .font(.system(size: 7, weight: .heavy, design: .monospaced))
                    .foregroundStyle(BoomboxTheme.lcdAmber.opacity(0.7))
                    .position(x: centerX, y: 8)
            }
        }
    }
}
