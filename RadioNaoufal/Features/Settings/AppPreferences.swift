import Foundation
import SwiftUI

/// Centrale lijst van UserDefaults-keys en hun defaults.
/// SwiftUI views gebruiken `@AppStorage(AppPreferences.Keys.X)` met de constante `AppPreferences.Defaults.X`.
/// Non-view code leest via `AppPreferences.read*()` helpers.
public enum AppPreferences {

    public enum Keys {
        public static let autoplayLastStation = "autoplayLastStation"
        public static let lastStationID = "lastStationID"
        public static let defaultVolume = "defaultVolume"
        public static let rememberVolume = "rememberVolume"
        public static let fadeInDuration = "fadeInDuration"
        public static let fadeOutDuration = "fadeOutDuration"
        public static let sleepTimerDefaultMinutes = "sleepTimerDefaultMinutes"
        public static let sleepTimerFadeDuration = "sleepTimerFadeDuration"
        public static let showMenuBarPlayer = "showMenuBarPlayer"
        public static let defaultDrawerTab = "defaultDrawerTab"
        public static let showTrackInMenuBar = "showTrackInMenuBar"
        public static let eqPreset = "eqPreset"
        public static let themeName = "themeName"
        public static let artworkFetching = "artworkFetching"
    }

    public enum Defaults {
        public static let autoplayLastStation: Bool = false
        public static let defaultVolume: Double = 0.75
        public static let rememberVolume: Bool = true
        public static let fadeInDuration: Double = 1.0
        public static let fadeOutDuration: Double = 0.5
        public static let sleepTimerDefaultMinutes: Int = 30
        public static let sleepTimerFadeDuration: Double = 5.0
        public static let showMenuBarPlayer: Bool = true
        public static let defaultDrawerTab: String = "favorites"
        public static let showTrackInMenuBar: Bool = false
        public static let eqPreset: String = "flat"
        public static let themeName: String = "blackChrome"
        public static let artworkFetching: Bool = true
    }

    /// Registreert alle defaults bij UserDefaults zodat eerste-keer-opstart de juiste waarden gebruikt.
    public static func registerDefaults() {
        let store = UserDefaults.standard
        let defaults: [String: Any] = [
            Keys.autoplayLastStation: Defaults.autoplayLastStation,
            Keys.defaultVolume: Defaults.defaultVolume,
            Keys.rememberVolume: Defaults.rememberVolume,
            Keys.fadeInDuration: Defaults.fadeInDuration,
            Keys.fadeOutDuration: Defaults.fadeOutDuration,
            Keys.sleepTimerDefaultMinutes: Defaults.sleepTimerDefaultMinutes,
            Keys.sleepTimerFadeDuration: Defaults.sleepTimerFadeDuration,
            Keys.showMenuBarPlayer: Defaults.showMenuBarPlayer,
            Keys.defaultDrawerTab: Defaults.defaultDrawerTab,
            Keys.showTrackInMenuBar: Defaults.showTrackInMenuBar,
            Keys.eqPreset: Defaults.eqPreset,
            Keys.themeName: Defaults.themeName,
            Keys.artworkFetching: Defaults.artworkFetching
        ]
        store.register(defaults: defaults)
    }

    // MARK: - Read helpers (non-view context)

    public static func bool(_ key: String) -> Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    public static func double(_ key: String) -> Double {
        UserDefaults.standard.double(forKey: key)
    }

    public static func int(_ key: String) -> Int {
        UserDefaults.standard.integer(forKey: key)
    }

    public static func string(_ key: String) -> String? {
        UserDefaults.standard.string(forKey: key)
    }

    public static func setLastStationID(_ id: String?) {
        if let id {
            UserDefaults.standard.set(id, forKey: Keys.lastStationID)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.lastStationID)
        }
    }
}
