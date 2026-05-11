import SwiftUI
import AVFoundation

struct ContentView: View {
    @Environment(PlayerViewModel.self) private var player
    @Environment(SettingsViewModel.self) private var settings
    @Environment(ThemeProvider.self) private var theme

    @State private var drawerExpanded: Bool = false
    @State private var showSearch: Bool = false

    var body: some View {
        ZStack {
            // Backplate gradient achtergrond (passend bij theme)
            LinearGradient(
                colors: backgroundColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderBar(showSearch: $showSearch, drawerExpanded: $drawerExpanded)

                BoomboxView()
                    .padding(.horizontal, 28)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                    .frame(maxWidth: 980)
                    .frame(maxWidth: .infinity)

                BrowseDrawerView(isExpanded: $drawerExpanded)
            }
        }
        .id(theme.current.id)
        .preferredColorScheme(theme.current.preferredColorScheme)
        .sheet(isPresented: $showSearch) {
            SearchSheetView()
                .environment(player)
        }
    }

    private var backgroundColors: [Color] {
        switch theme.current.id {
        case "snow":
            return [
                Color(red: 0.94, green: 0.93, blue: 0.90),
                Color(red: 0.84, green: 0.83, blue: 0.79)
            ]
        case "woodBrown":
            return [
                Color(red: 0.10, green: 0.07, blue: 0.04),
                Color(red: 0.18, green: 0.12, blue: 0.06)
            ]
        default:
            return [
                Color(red: 0.04, green: 0.05, blue: 0.07),
                Color(red: 0.10, green: 0.10, blue: 0.13)
            ]
        }
    }
}

private struct HeaderBar: View {
    @Environment(PlayerViewModel.self) private var player
    @Environment(SettingsViewModel.self) private var settings
    @Binding var showSearch: Bool
    @Binding var drawerExpanded: Bool

    var body: some View {
        HStack(spacing: 14) {
            Spacer().frame(width: 70)
            HStack(spacing: 10) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.amber)
                Text("RADIO NAOUFAL")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .tracking(2.5)
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer()

            HStack(spacing: 8) {
                if settings.sleepTimerActive {
                    SleepTimerIndicator()
                }

                Button {
                    showSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(IconButtonStyle())
                .help(String(localized: "Zoeken"))
                .keyboardShortcut("f", modifiers: .command)

                AirPlayPickerView(player: player.audio.player, tint: .white)
                    .frame(width: 30, height: 30)

                ChromecastButton()

                Button {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        drawerExpanded.toggle()
                    }
                } label: {
                    Image(systemName: drawerExpanded ? "chevron.down" : "chevron.up")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(IconButtonStyle())
                .help(String(localized: "Browse zenders"))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(height: 52)
    }
}

private struct SleepTimerIndicator: View {
    @Environment(SettingsViewModel.self) private var settings

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.amber)
            Text(settings.formattedRemaining)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.amber)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(Color.black.opacity(0.4))
        )
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 30, height: 30)
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.6 : 0.85))
            .background(
                Circle()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.05 : 0.10))
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

