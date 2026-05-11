import SwiftUI

struct SleepTimerPopover: View {
    @Environment(SettingsViewModel.self) private var settings
    @State private var customMinutes: Int = 45

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(BoomboxTheme.amber)
                Text(String(localized: "Slaaptimer"))
                    .font(.headline)
                Spacer()
                if settings.sleepTimerActive {
                    Text(settings.formattedRemaining)
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(BoomboxTheme.amber)
                }
            }

            if settings.sleepTimerActive {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(BoomboxTheme.amber)
            }

            Divider()

            Text(String(localized: "Stop afspelen na"))
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                ForEach(settings.sleepMinutesPresets, id: \.self) { minutes in
                    Button {
                        settings.startSleepTimer(minutes: minutes)
                    } label: {
                        Text("\(minutes) min")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.secondary.opacity(0.18))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Stepper(value: $customMinutes, in: 1...240, step: 5) {
                    Text(String(localized: "Eigen tijd: \(customMinutes) min"))
                        .font(.callout)
                }
                .frame(maxWidth: .infinity)
                Button(String(localized: "Start")) {
                    settings.startSleepTimer(minutes: customMinutes)
                }
                .buttonStyle(.borderedProminent)
                .tint(BoomboxTheme.amber)
            }

            if settings.sleepTimerActive {
                Button(String(localized: "Annuleer timer"), role: .destructive) {
                    settings.cancelSleepTimer()
                }
            }
        }
        .padding(18)
        .frame(width: 280)
    }

    private var progress: Double {
        guard settings.sleepTimerDuration > 0 else { return 0 }
        return 1.0 - settings.sleepTimerRemaining / settings.sleepTimerDuration
    }
}
