import SwiftUI

/// De buitenkant van de boombox: chassis met handle en speaker-grille randen.
struct BoomboxChassisView: View {
    var body: some View {
        GeometryReader { geometry in
            let cornerRadius: CGFloat = 28

            ZStack {
                // Hoofdchassis
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(BoomboxTheme.chassisGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.16),
                                        Color.white.opacity(0.02),
                                        Color.black.opacity(0.30)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.black.opacity(0.55), radius: 28, x: 0, y: 16)
                    .shadow(color: Color.black.opacity(0.30), radius: 6, x: 0, y: 3)

                // Subtiele textuur via noise overlay
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.05),
                                Color.white.opacity(0.00),
                                Color.black.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.overlay)

                // Carry handle bovenaan
                HandleView()
                    .frame(width: geometry.size.width * 0.35, height: 12)
                    .offset(y: -geometry.size.height / 2 + 2)

                // Onder-strip met chrome
                RoundedRectangle(cornerRadius: 4)
                    .fill(BoomboxTheme.chromeBevel)
                    .frame(height: 3)
                    .opacity(0.7)
                    .offset(y: geometry.size.height / 2 - 14)
                    .padding(.horizontal, 40)
            }
        }
    }
}

private struct HandleView: View {
    var body: some View {
        ZStack {
            Capsule()
                .stroke(BoomboxTheme.chromeBevel, lineWidth: 3)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.4))
                )
            Capsule()
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        }
        .frame(height: 12)
    }
}
