import SwiftUI

/// Centrale kleur- en stijl-definities voor de boombox.
enum BoomboxTheme {

    // MARK: - Colors

    static let chassisDark = Color(red: 0.09, green: 0.10, blue: 0.11)
    static let chassisMid = Color(red: 0.14, green: 0.15, blue: 0.17)
    static let chassisLight = Color(red: 0.22, green: 0.23, blue: 0.26)
    static let chassisHighlight = Color(red: 0.35, green: 0.36, blue: 0.40)

    static let chrome = Color(red: 0.78, green: 0.79, blue: 0.82)
    static let chromeBright = Color(red: 0.93, green: 0.94, blue: 0.96)
    static let chromeDark = Color(red: 0.40, green: 0.42, blue: 0.45)

    static let amber = Color(red: 1.00, green: 0.71, blue: 0.12)
    static let amberGlow = Color(red: 1.00, green: 0.55, blue: 0.06)
    static let amberDim = Color(red: 0.55, green: 0.38, blue: 0.08)

    static let lcdBackground = Color(red: 0.04, green: 0.03, blue: 0.02)
    static let lcdAmber = Color(red: 1.00, green: 0.65, blue: 0.10)
    static let lcdGreen = Color(red: 0.35, green: 1.00, blue: 0.50)

    static let presetRed = Color(red: 0.92, green: 0.22, blue: 0.20)
    static let presetGreen = Color(red: 0.20, green: 0.78, blue: 0.45)

    // MARK: - Gradients

    static var chassisGradient: LinearGradient {
        LinearGradient(
            colors: [chassisLight, chassisMid, chassisDark],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var chromeBevel: LinearGradient {
        LinearGradient(
            colors: [chromeBright, chrome, chromeDark, chrome],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var knobGradient: AngularGradient {
        AngularGradient(
            colors: [chromeBright, chrome, chromeDark, chrome, chromeBright],
            center: .center,
            startAngle: .degrees(-30),
            endAngle: .degrees(330)
        )
    }

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
    static var amber: Color { BoomboxTheme.amber }
    static var amberGlow: Color { BoomboxTheme.amberGlow }
    static var lcdAmber: Color { BoomboxTheme.lcdAmber }
}
