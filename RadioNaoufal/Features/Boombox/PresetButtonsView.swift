import SwiftUI

/// Rij van 9 preset-knoppen voor favoriete zenders.
struct PresetButtonsView: View {
    @Environment(PlayerViewModel.self) private var player

    @State private var assignSheetSlot: Int?

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...9, id: \.self) { slot in
                PresetButton(
                    slot: slot,
                    station: station(at: slot),
                    isActive: isCurrent(slot: slot),
                    onTap: { handleTap(slot: slot) },
                    onLongPress: { assignSheetSlot = slot }
                )
            }

            PlayPauseButton()
                .padding(.leading, 6)

            SleepTimerButton()
        }
        .sheet(item: Binding(
            get: { assignSheetSlot.map(SlotIdentifier.init) },
            set: { assignSheetSlot = $0?.value }
        )) { slotID in
            PresetAssignSheet(slot: slotID.value)
                .environment(player)
        }
    }

    private func station(at slot: Int) -> Station? {
        guard let favorite = player.dataStore.favorite(at: slot) else { return nil }
        return player.stations.station(byID: favorite.stationID)
    }

    private func isCurrent(slot: Int) -> Bool {
        guard let station = station(at: slot) else { return false }
        return station.id == player.currentStation?.id
    }

    private func handleTap(slot: Int) {
        if let station = station(at: slot) {
            player.play(station: station)
        } else {
            assignSheetSlot = slot
        }
    }
}

private struct SlotIdentifier: Identifiable {
    let value: Int
    var id: Int { value }
}

private struct PresetButton: View {
    let slot: Int
    let station: Station?
    let isActive: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            onTap()
        }) {
            ZStack {
                // Body
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                isActive ? BoomboxTheme.amber : Color(red: 0.18, green: 0.18, blue: 0.20),
                                isActive ? BoomboxTheme.amberGlow : Color(red: 0.10, green: 0.10, blue: 0.11)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: isActive ? BoomboxTheme.amberGlow.opacity(0.6) : .black.opacity(0.4), radius: isActive ? 4 : 2, y: 1)

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.30),
                                Color.black.opacity(0.45)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )

                VStack(spacing: 1) {
                    Text("\(slot)")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(isActive ? .black : Color.white.opacity(0.85))
                    if let station {
                        Text(station.name)
                            .font(.system(size: 7, weight: .semibold, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .foregroundStyle(isActive ? Color.black.opacity(0.75) : Color.white.opacity(0.5))
                            .frame(maxWidth: 38)
                    } else {
                        Text("—")
                            .font(.system(size: 7, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.30))
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(width: 46, height: 46)
            .scaleEffect(isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0.5) {
            onLongPress()
        }
        .help(station?.name ?? String(localized: "Slot \(slot) - lang indrukken om in te stellen"))
        .accessibilityLabel(station.map { "Preset \(slot): \($0.name)" } ?? "Preset \(slot) leeg")
        .accessibilityHint(String(localized: "Tik om af te spelen, of houd lang ingedrukt om in te stellen"))
    }
}

private struct PlayPauseButton: View {
    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        Button(action: { player.toggle() }) {
            ZStack {
                Circle()
                    .fill(BoomboxTheme.knobGradient)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.black.opacity(0.6), lineWidth: 1)
                    )
                Circle()
                    .fill(BoomboxTheme.chassisLight)
                    .padding(6)
                Image(systemName: player.status.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(BoomboxTheme.chromeBright)
                    .offset(x: player.status.isPlaying ? 0 : 1)
            }
            .frame(width: 50, height: 50)
            .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
        }
        .buttonStyle(.plain)
        .help(String(localized: "Afspelen/Pauzeren"))
    }
}

private struct SleepTimerButton: View {
    @Environment(SettingsViewModel.self) private var settings
    @State private var showPopover = false

    var body: some View {
        Button(action: { showPopover.toggle() }) {
            ZStack {
                Circle()
                    .fill(BoomboxTheme.chassisLight)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                Image(systemName: settings.sleepTimerActive ? "moon.zzz.fill" : "moon.zzz")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(settings.sleepTimerActive ? BoomboxTheme.amber : Color.white.opacity(0.65))
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .help(String(localized: "Slaaptimer"))
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            SleepTimerPopover()
                .environment(settings)
        }
    }
}

/// Sheet om een station aan een preset-slot te koppelen.
struct PresetAssignSheet: View {
    @Environment(PlayerViewModel.self) private var player
    @Environment(\.dismiss) private var dismiss

    let slot: Int

    @State private var searchText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "Preset \(slot) instellen"))
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(String(localized: "Sluit")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(String(localized: "Zoek zender"), text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(filteredStations) { station in
                        Button {
                            assign(station: station)
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(BoomboxTheme.amber.opacity(0.18))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Text(initials(for: station.name))
                                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                            .foregroundStyle(BoomboxTheme.amber)
                                    )
                                VStack(alignment: .leading) {
                                    Text(station.name)
                                        .font(.body)
                                    Text(station.genre.localizedLabel)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if player.favoriteSlot(at: slot) != nil {
                Divider()
                Button(String(localized: "Verwijder huidige preset"), role: .destructive) {
                    player.clearFavorite(at: slot)
                    dismiss()
                }
            }
        }
        .padding(20)
        .frame(width: 440, height: 520)
    }

    private var filteredStations: [Station] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let all = player.stations.curated
        guard !trimmed.isEmpty else { return all }
        return all.filter { $0.name.lowercased().contains(trimmed) || $0.tags.contains(where: { $0.lowercased().contains(trimmed) }) }
    }

    private func assign(station: Station) {
        player.assignFavorite(station: station, to: slot)
        dismiss()
    }

    private func initials(for name: String) -> String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            let first = words[0].first.map(String.init) ?? "?"
            let second = words[1].first.map(String.init) ?? ""
            return (first + second).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
