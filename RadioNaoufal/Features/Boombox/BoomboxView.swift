import SwiftUI

struct BoomboxView: View {
    @Environment(PlayerViewModel.self) private var player
    @Environment(SettingsViewModel.self) private var settings

    var body: some View {
        ZStack {
            BoomboxChassisView()

            VStack(spacing: 18) {
                HStack(alignment: .center, spacing: 22) {
                    SpeakerView(
                        side: .left,
                        level: CGFloat(player.audio.visualizer.leftLevel),
                        isPlaying: player.status.isPlaying
                    )
                    .frame(width: 180, height: 180)

                    CassetteDeckView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)

                    SpeakerView(
                        side: .right,
                        level: CGFloat(player.audio.visualizer.rightLevel),
                        isPlaying: player.status.isPlaying
                    )
                    .frame(width: 180, height: 180)
                }

                HStack(alignment: .center, spacing: 20) {
                    ChromeKnobView(
                        value: Binding(
                            get: { Double(player.audio.volume) },
                            set: { player.setVolume(Float($0)) }
                        ),
                        range: 0...1,
                        label: String(localized: "VOLUME"),
                        showTicks: true,
                        accent: BoomboxTheme.amber
                    )
                    .frame(width: 86, height: 86)

                    Spacer().frame(width: 6)

                    PresetButtonsView()
                        .frame(maxWidth: .infinity)

                    Spacer().frame(width: 6)

                    ChromeKnobView(
                        value: Binding(
                            get: { tuneValue },
                            set: { newValue in updateTune(newValue) }
                        ),
                        range: 0...1,
                        label: String(localized: "TUNING"),
                        showTicks: false,
                        accent: BoomboxTheme.amberGlow
                    )
                    .frame(width: 86, height: 86)
                }
                .padding(.horizontal, 18)

                TunerDialView()
                    .frame(height: 70)
                    .padding(.horizontal, 22)
            }
            .padding(.vertical, 26)
            .padding(.horizontal, 26)
        }
        .aspectRatio(1.55, contentMode: .fit)
        .frame(maxHeight: 560)
    }

    // MARK: - Tuner mapping

    private var tuneValue: Double {
        guard let station = player.currentStation else { return 0 }
        let index = player.stations.curated.firstIndex(of: station) ?? 0
        return Double(index) / Double(max(1, player.stations.curated.count - 1))
    }

    private func updateTune(_ value: Double) {
        let count = player.stations.curated.count
        guard count > 0 else { return }
        let clamped = min(1, max(0, value))
        let index = Int(round(clamped * Double(count - 1)))
        let station = player.stations.curated[index]
        if station.id != player.currentStation?.id {
            player.play(station: station)
        }
    }
}
