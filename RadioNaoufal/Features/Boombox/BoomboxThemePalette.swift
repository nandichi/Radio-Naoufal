import SwiftUI

/// Concreet kleurenpalet voor een boombox-thema.
/// Drie instances: `.blackChrome` (default), `.woodBrown`, `.snow`. Wordt in Fase 2 actief gebruikt
/// door alle boombox-views via `@Environment(ThemeProvider.self)`.
public struct BoomboxThemePalette: Equatable, Sendable {
    public let id: String
    public let displayName: String

    public let chassisDark: Color
    public let chassisMid: Color
    public let chassisLight: Color
    public let chassisHighlight: Color

    public let chrome: Color
    public let chromeBright: Color
    public let chromeDark: Color

    public let amber: Color
    public let amberGlow: Color
    public let amberDim: Color

    public let lcdBackground: Color
    public let lcdAmber: Color
    public let lcdGreen: Color

    public let presetRed: Color
    public let presetGreen: Color

    public let preferredColorScheme: ColorScheme

    public var chassisGradient: LinearGradient {
        LinearGradient(colors: [chassisLight, chassisMid, chassisDark], startPoint: .top, endPoint: .bottom)
    }

    public var chromeBevel: LinearGradient {
        LinearGradient(colors: [chromeBright, chrome, chromeDark, chrome], startPoint: .top, endPoint: .bottom)
    }

    public var knobGradient: AngularGradient {
        AngularGradient(colors: [chromeBright, chrome, chromeDark, chrome, chromeBright], center: .center, startAngle: .degrees(-30), endAngle: .degrees(330))
    }
}

public extension BoomboxThemePalette {

    static let blackChrome = BoomboxThemePalette(
        id: "blackChrome",
        displayName: "Zwart-chrome",
        chassisDark: Color(red: 0.09, green: 0.10, blue: 0.11),
        chassisMid: Color(red: 0.14, green: 0.15, blue: 0.17),
        chassisLight: Color(red: 0.22, green: 0.23, blue: 0.26),
        chassisHighlight: Color(red: 0.35, green: 0.36, blue: 0.40),
        chrome: Color(red: 0.78, green: 0.79, blue: 0.82),
        chromeBright: Color(red: 0.93, green: 0.94, blue: 0.96),
        chromeDark: Color(red: 0.40, green: 0.42, blue: 0.45),
        amber: Color(red: 1.00, green: 0.71, blue: 0.12),
        amberGlow: Color(red: 1.00, green: 0.55, blue: 0.06),
        amberDim: Color(red: 0.55, green: 0.38, blue: 0.08),
        lcdBackground: Color(red: 0.04, green: 0.03, blue: 0.02),
        lcdAmber: Color(red: 1.00, green: 0.65, blue: 0.10),
        lcdGreen: Color(red: 0.35, green: 1.00, blue: 0.50),
        presetRed: Color(red: 0.92, green: 0.22, blue: 0.20),
        presetGreen: Color(red: 0.20, green: 0.78, blue: 0.45),
        preferredColorScheme: .dark
    )

    static let woodBrown = BoomboxThemePalette(
        id: "woodBrown",
        displayName: "Walnoot-bruin",
        chassisDark: Color(red: 0.22, green: 0.14, blue: 0.08),
        chassisMid: Color(red: 0.34, green: 0.22, blue: 0.13),
        chassisLight: Color(red: 0.48, green: 0.31, blue: 0.18),
        chassisHighlight: Color(red: 0.62, green: 0.42, blue: 0.25),
        chrome: Color(red: 0.78, green: 0.62, blue: 0.36),
        chromeBright: Color(red: 0.94, green: 0.80, blue: 0.50),
        chromeDark: Color(red: 0.46, green: 0.32, blue: 0.16),
        amber: Color(red: 1.00, green: 0.65, blue: 0.10),
        amberGlow: Color(red: 1.00, green: 0.45, blue: 0.04),
        amberDim: Color(red: 0.55, green: 0.32, blue: 0.06),
        lcdBackground: Color(red: 0.06, green: 0.04, blue: 0.02),
        lcdAmber: Color(red: 1.00, green: 0.58, blue: 0.08),
        lcdGreen: Color(red: 0.40, green: 0.90, blue: 0.40),
        presetRed: Color(red: 0.85, green: 0.20, blue: 0.18),
        presetGreen: Color(red: 0.28, green: 0.68, blue: 0.40),
        preferredColorScheme: .dark
    )

    static let snow = BoomboxThemePalette(
        id: "snow",
        displayName: "Sneeuw-ivoor",
        chassisDark: Color(red: 0.78, green: 0.76, blue: 0.71),
        chassisMid: Color(red: 0.86, green: 0.84, blue: 0.79),
        chassisLight: Color(red: 0.92, green: 0.90, blue: 0.86),
        chassisHighlight: Color(red: 0.97, green: 0.96, blue: 0.93),
        chrome: Color(red: 0.74, green: 0.74, blue: 0.78),
        chromeBright: Color(red: 0.90, green: 0.90, blue: 0.94),
        chromeDark: Color(red: 0.52, green: 0.52, blue: 0.56),
        amber: Color(red: 0.16, green: 0.30, blue: 0.62),
        amberGlow: Color(red: 0.20, green: 0.40, blue: 0.78),
        amberDim: Color(red: 0.30, green: 0.40, blue: 0.55),
        lcdBackground: Color(red: 0.18, green: 0.22, blue: 0.30),
        lcdAmber: Color(red: 0.30, green: 0.55, blue: 0.95),
        lcdGreen: Color(red: 0.16, green: 0.60, blue: 0.42),
        presetRed: Color(red: 0.82, green: 0.22, blue: 0.22),
        presetGreen: Color(red: 0.20, green: 0.62, blue: 0.36),
        preferredColorScheme: .light
    )

    static let all: [BoomboxThemePalette] = [.blackChrome, .woodBrown, .snow]
}
