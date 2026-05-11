import Foundation
import Observation
import SwiftUI

/// Levert het actieve boombox-thema via SwiftUI environment.
/// Wordt in Fase 2 uitgebreid met drie themes (BlackChrome, WoodBrown, Snow).
/// Tot die tijd functioneert dit als doorvoer naar `BoomboxTheme.blackChrome`.
@MainActor
@Observable
public final class ThemeProvider {

    public private(set) var current: BoomboxThemePalette = .blackChrome

    public init() {}

    public func applyStoredTheme() {
        let name = AppPreferences.string(AppPreferences.Keys.themeName) ?? AppPreferences.Defaults.themeName
        setTheme(named: name, animated: false)
    }

    public func setTheme(named name: String, animated: Bool = true) {
        let new: BoomboxThemePalette
        switch name {
        case "woodBrown": new = .woodBrown
        case "snow": new = .snow
        default: new = .blackChrome
        }
        BoomboxTheme.currentPalette = new
        if animated {
            withAnimation(.easeInOut(duration: 0.35)) {
                current = new
            }
        } else {
            current = new
        }
    }

    /// Convenience-toegang vanuit views die geen Environment-access hebben (b.v. AppKit-bridges).
    public static let shared = ThemeProvider()
}
