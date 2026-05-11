import SwiftUI

/// Chroom-stijl knop die 30s achterwaarts in de live stream springt.
/// Zichtbaar gedimd wanneer er onvoldoende ringbuffer beschikbaar is.
struct RewindButton: View {
    @Environment(PlayerViewModel.self) private var player

    @State private var hovered: Bool = false
    @State private var pressed: Bool = false
    @State private var isWorking: Bool = false

    private var isEnabled: Bool {
        player.audio.canRewind && !isWorking
    }

    private var isTimeShifted: Bool {
        player.audio.isTimeShifted
    }

    var body: some View {
        Button {
            if isTimeShifted {
                Task { await player.audio.returnToLive() }
            } else {
                Task {
                    isWorking = true
                    await player.audio.rewindToBuffer(seconds: 30)
                    isWorking = false
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(BoomboxTheme.knobGradient)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.5), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)

                if isTimeShifted {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(BoomboxTheme.presetRed)
                } else if isWorking {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "gobackward.30")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(BoomboxTheme.chassisDark)
                }
            }
            .scaleEffect(pressed ? 0.94 : (hovered ? 1.03 : 1.0))
            .opacity(isEnabled || isTimeShifted ? 1.0 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled && !isTimeShifted)
        .onHover { hovered = $0 }
        .help(isTimeShifted ? String(localized: "Terug naar live") : String(localized: "Spring 30 seconden terug"))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}
