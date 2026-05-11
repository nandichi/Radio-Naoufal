import SwiftUI

/// Root view voor de native macOS Settings/Preferences window.
/// Drie tabs: Algemeen, Stations, Over. Gebruikt `TabView` met `Tab(...)` items.
struct SettingsWindow: View {
    @Environment(PlayerViewModel.self) private var player
    @Environment(SettingsViewModel.self) private var settings

    enum Section: String, Hashable, CaseIterable {
        case general, stations, about
    }

    @State private var selection: Section = .general

    var body: some View {
        TabView(selection: $selection) {
            Tab(String(localized: "Algemeen"), systemImage: "gear", value: Section.general) {
                GeneralSettingsView()
                    .environment(player)
                    .environment(settings)
            }
            Tab(String(localized: "Stations"), systemImage: "antenna.radiowaves.left.and.right", value: Section.stations) {
                StationsSettingsView()
                    .environment(player)
            }
            Tab(String(localized: "Over"), systemImage: "info.circle", value: Section.about) {
                AboutSettingsView()
            }
        }
        .scenePadding()
        .frame(width: 540, height: 480)
    }
}
