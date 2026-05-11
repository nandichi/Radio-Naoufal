import SwiftUI

/// Centrale kleur- en stijl-definities voor de boombox.
/// Leest doorlopend uit `currentPalette` zodat een theme-switch via `ThemeProvider` direct
/// reflecteert in alle views (mits hun parent een `.id(currentPalette.id)` of equivalent gebruikt).
enum BoomboxTheme {

    /// De actief gebruikte theme. Wordt door `ThemeProvider` bij theme-wisseling geset.
    @MainActor static var currentPalette: BoomboxThemePalette = .blackChrome

    // MARK: - Colors

    @MainActor static var chassisDark: Color { currentPalette.chassisDark }
    @MainActor static var chassisMid: Color { currentPalette.chassisMid }
    @MainActor static var chassisLight: Color { currentPalette.chassisLight }
    @MainActor static var chassisHighlight: Color { currentPalette.chassisHighlight }

    @MainActor static var chrome: Color { currentPalette.chrome }
    @MainActor static var chromeBright: Color { currentPalette.chromeBright }
    @MainActor static var chromeDark: Color { currentPalette.chromeDark }

    @MainActor static var amber: Color { currentPalette.amber }
    @MainActor static var amberGlow: Color { currentPalette.amberGlow }
    @MainActor static var amberDim: Color { currentPalette.amberDim }

    @MainActor static var lcdBackground: Color { currentPalette.lcdBackground }
    @MainActor static var lcdAmber: Color { currentPalette.lcdAmber }
    @MainActor static var lcdGreen: Color { currentPalette.lcdGreen }

    @MainActor static var presetRed: Color { currentPalette.presetRed }
    @MainActor static var presetGreen: Color { currentPalette.presetGreen }

    // MARK: - Gradients

    @MainActor static var chassisGradient: LinearGradient { currentPalette.chassisGradient }
    @MainActor static var chromeBevel: LinearGradient { currentPalette.chromeBevel }
    @MainActor static var knobGradient: AngularGradient { currentPalette.knobGradient }

    // MARK: - Fonts

    static var lcdFont: Font {
        .system(size: 16, weight: .heavy, design: .monospaced)
    }

    static var lcdLargeFont: Font {
        .system(size: 24, weight: .heavy, design: .monospaced)
    }

    static var labelFont: Font {
        .system(size: 9, weight: .heavy, design: .monospaced)
    }

    // MARK: - Glass effect

    /// Past Liquid Glass effect toe op macOS 26+ (Tahoe), valt anders terug op
    /// een subtiele material achtergrond.
    @ViewBuilder
    static func glassChrome<Content: View>(_ content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .background(.ultraThinMaterial.opacity(0.4))
        } else {
            content
                .background(Color.white.opacity(0.04))
        }
    }
}

extension ShapeStyle where Self == Color {
    @MainActor static var amber: Color { BoomboxTheme.amber }
    @MainActor static var amberGlow: Color { BoomboxTheme.amberGlow }
    @MainActor static var lcdAmber: Color { BoomboxTheme.lcdAmber }
}
