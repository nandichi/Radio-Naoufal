import SwiftUI

/// Een chrome draaiknop met drag-to-rotate.
/// `value` wordt gemapped op de hoek tussen `startAngle` en `endAngle`.
struct ChromeKnobView: View {

    @Binding var value: Double
    let range: ClosedRange<Double>
    let label: String
    let showTicks: Bool
    let accent: Color

    var startAngle: Angle = .degrees(-130)
    var endAngle: Angle = .degrees(130)

    @State private var dragStartAngle: Angle?
    @State private var dragStartValue: Double = 0
    @State private var localValue: Double = 0

    private var clampedValue: Double {
        min(range.upperBound, max(range.lowerBound, value))
    }

    private var progress: Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        return (clampedValue - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    private var pointerAngle: Angle {
        let total = endAngle.degrees - startAngle.degrees
        return .degrees(startAngle.degrees + total * progress)
    }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                ZStack {
                    // Tick marks ring
                    if showTicks {
                        TickRing(size: size, accent: accent)
                    }

                    // Outer chrome ring
                    Circle()
                        .fill(BoomboxTheme.knobGradient)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.7), Color.black.opacity(0.5)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 4)

                    // Inner cap
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.20, green: 0.20, blue: 0.22),
                                    Color(red: 0.06, green: 0.06, blue: 0.07)
                                ],
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: size * 0.7
                            )
                        )
                        .padding(8)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                .padding(8)
                        )

                    // Indicator-streep
                    Rectangle()
                        .fill(accent)
                        .frame(width: 3, height: size * 0.28)
                        .offset(y: -size * 0.18)
                        .shadow(color: accent.opacity(0.6), radius: 2)
                        .rotationEffect(pointerAngle)
                        .animation(.spring(response: 0.18, dampingFraction: 0.7), value: pointerAngle)
                }
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let center = CGPoint(x: size / 2, y: size / 2)
                            let location = gesture.location
                            let dx = location.x - center.x
                            let dy = location.y - center.y
                            let angleRad = atan2(dy, dx) + .pi / 2
                            var degrees = angleRad * 180 / .pi
                            if degrees > 180 { degrees -= 360 }
                            if degrees < -180 { degrees += 360 }
                            let clampedDeg = min(endAngle.degrees, max(startAngle.degrees, degrees))
                            let progress = (clampedDeg - startAngle.degrees) / (endAngle.degrees - startAngle.degrees)
                            let newValue = range.lowerBound + progress * (range.upperBound - range.lowerBound)
                            value = newValue
                        }
                )
            }
            .aspectRatio(1, contentMode: .fit)

            Text(label)
                .font(BoomboxTheme.labelFont)
                .tracking(1.2)
                .foregroundStyle(BoomboxTheme.chromeBright.opacity(0.7))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(String(format: "%.0f%%", progress * 100))
        .accessibilityAdjustableAction { direction in
            let step = 0.05
            switch direction {
            case .increment:
                value = min(range.upperBound, value + step)
            case .decrement:
                value = max(range.lowerBound, value - step)
            @unknown default:
                break
            }
        }
    }
}

private struct TickRing: View {
    let size: CGFloat
    let accent: Color

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let outer = canvasSize.width / 2 - 1
            let inner = outer - 5
            let tickCount = 24
            let angleRange: Double = 260
            let startDeg: Double = -130
            for i in 0...tickCount {
                let progress = Double(i) / Double(tickCount)
                let degrees = startDeg + angleRange * progress - 90
                let rad = degrees * .pi / 180
                let p1 = CGPoint(x: center.x + cos(rad) * outer, y: center.y + sin(rad) * outer)
                let p2 = CGPoint(x: center.x + cos(rad) * inner, y: center.y + sin(rad) * inner)
                var path = Path()
                path.move(to: p1)
                path.addLine(to: p2)
                context.stroke(path, with: .color(accent.opacity(0.4)), lineWidth: 1)
            }
        }
    }
}
