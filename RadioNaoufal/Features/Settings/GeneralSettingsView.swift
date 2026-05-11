import SwiftUI

/// Eerste tab van het Settings-window: opstart-, audio-, geluid- en weergave-instellingen.
struct GeneralSettingsView: View {
    @Environment(PlayerViewModel.self) private var player
    @Environment(SettingsViewModel.self) private var settings
    @Environment(ThemeProvider.self) private var theme

    @AppStorage(AppPreferences.Keys.autoplayLastStation) private var autoplayLastStation: Bool = AppPreferences.Defaults.autoplayLastStation
    @AppStorage(AppPreferences.Keys.defaultVolume) private var defaultVolume: Double = AppPreferences.Defaults.defaultVolume
    @AppStorage(AppPreferences.Keys.rememberVolume) private var rememberVolume: Bool = AppPreferences.Defaults.rememberVolume
    @AppStorage(AppPreferences.Keys.fadeInDuration) private var fadeInDuration: Double = AppPreferences.Defaults.fadeInDuration
    @AppStorage(AppPreferences.Keys.fadeOutDuration) private var fadeOutDuration: Double = AppPreferences.Defaults.fadeOutDuration
    @AppStorage(AppPreferences.Keys.sleepTimerDefaultMinutes) private var sleepTimerDefaultMinutes: Int = AppPreferences.Defaults.sleepTimerDefaultMinutes
    @AppStorage(AppPreferences.Keys.sleepTimerFadeDuration) private var sleepTimerFadeDuration: Double = AppPreferences.Defaults.sleepTimerFadeDuration
    @AppStorage(AppPreferences.Keys.showMenuBarPlayer) private var showMenuBarPlayer: Bool = AppPreferences.Defaults.showMenuBarPlayer
    @AppStorage(AppPreferences.Keys.defaultDrawerTab) private var defaultDrawerTab: String = AppPreferences.Defaults.defaultDrawerTab
    @AppStorage(AppPreferences.Keys.showTrackInMenuBar) private var showTrackInMenuBar: Bool = AppPreferences.Defaults.showTrackInMenuBar
    @AppStorage(AppPreferences.Keys.eqPreset) private var eqPreset: String = AppPreferences.Defaults.eqPreset
    @AppStorage(AppPreferences.Keys.themeName) private var themeName: String = AppPreferences.Defaults.themeName
    @AppStorage(AppPreferences.Keys.artworkFetching) private var artworkFetching: Bool = AppPreferences.Defaults.artworkFetching

    var body: some View {
        Form {
            Section(String(localized: "Opstarten")) {
                Toggle(String(localized: "Speel laatst gespeelde zender bij opstart"), isOn: $autoplayLastStation)
                LabeledContent(String(localized: "Standaard volume")) {
                    HStack {
                        Slider(value: $defaultVolume, in: 0...1)
                            .frame(width: 200)
                        Text(verbatim: String(format: "%.0f%%", defaultVolume * 100))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                Toggle(String(localized: "Onthoud volume tussen sessies"), isOn: $rememberVolume)
                Toggle(String(localized: "Toon menubar mini-player"), isOn: $showMenuBarPlayer)
            }

            Section(String(localized: "Audio")) {
                LabeledContent(String(localized: "Fade-in bij afspelen")) {
                    HStack {
                        Slider(value: $fadeInDuration, in: 0...5, step: 0.1)
                            .frame(width: 200)
                        Text(verbatim: String(format: "%.1fs", fadeInDuration))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                LabeledContent(String(localized: "Fade-out bij pauze/stop")) {
                    HStack {
                        Slider(value: $fadeOutDuration, in: 0...5, step: 0.1)
                            .frame(width: 200)
                        Text(verbatim: String(format: "%.1fs", fadeOutDuration))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                Picker(String(localized: "Standaard sleep-timer duur"), selection: $sleepTimerDefaultMinutes) {
                    ForEach([15, 30, 45, 60, 90], id: \.self) { minutes in
                        Text(verbatim: "\(minutes) min").tag(minutes)
                    }
                }
                LabeledContent(String(localized: "Fade bij sleep-timer")) {
                    HStack {
                        Slider(value: $sleepTimerFadeDuration, in: 1...10, step: 0.5)
                            .frame(width: 200)
                        Text(verbatim: String(format: "%.1fs", sleepTimerFadeDuration))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }

            Section(String(localized: "Geluid")) {
                Picker(String(localized: "Equalizer-preset"), selection: $eqPreset) {
                    Text(String(localized: "Vlak (Flat)")).tag("flat")
                    Text(String(localized: "Rock")).tag("rock")
                    Text(String(localized: "Klassiek")).tag("classical")
                    Text(String(localized: "Stem-boost")).tag("vocal")
                }
                .pickerStyle(.menu)
            }

            Section(String(localized: "Weergave")) {
                Picker(String(localized: "Thema"), selection: $themeName) {
                    Text(String(localized: "Zwart-chrome")).tag("blackChrome")
                    Text(String(localized: "Walnoot-bruin")).tag("woodBrown")
                    Text(String(localized: "Sneeuw-ivoor")).tag("snow")
                }
                .pickerStyle(.menu)

                Picker(String(localized: "Standaard drawer-tab"), selection: $defaultDrawerTab) {
                    Text(String(localized: "Favorieten")).tag("favorites")
                    Text(String(localized: "Categorieen")).tag("categories")
                    Text(String(localized: "Zoeken")).tag("search")
                    Text(String(localized: "Recent")).tag("recent")
                    Text(String(localized: "Podcasts")).tag("podcasts")
                }
                .pickerStyle(.menu)

                Toggle(String(localized: "Toon track-titel in menubar"), isOn: $showTrackInMenuBar)
                Toggle(String(localized: "Haal track-artwork op (iTunes Search)"), isOn: $artworkFetching)
            }
        }
        .formStyle(.grouped)
        .onChange(of: themeName) { _, newValue in
            theme.setTheme(named: newValue)
        }
        .onChange(of: eqPreset) { _, newValue in
            player.audio.setEQPreset(newValue)
        }
    }
}
