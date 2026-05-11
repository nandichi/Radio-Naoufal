import SwiftUI
import AppKit

@main
struct RadioNaoufalApp: App {

    @State private var player = PlayerViewModel()
    @State private var settings = SettingsViewModel()

    init() {
        settings.bind(player: player)
    }

    var body: some Scene {
        WindowGroup("Radio Naoufal") {
            RootContainerView()
                .environment(player)
                .environment(settings)
                .frame(minWidth: 980, minHeight: 640)
                .preferredColorScheme(.dark)
                .background(WindowAccessor())
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu(String(localized: "Afspelen")) {
                Button(String(localized: "Afspelen/Pauzeren")) {
                    player.toggle()
                }
                .keyboardShortcut(.space, modifiers: [])

                Button(String(localized: "Volgende zender")) {
                    player.next()
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)

                Button(String(localized: "Vorige zender")) {
                    player.previous()
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)

                Divider()

                ForEach(1...9, id: \.self) { slot in
                    Button(String(localized: "Preset \(slot)")) {
                        if let station = player.favoriteSlot(at: slot) {
                            player.play(station: station)
                        }
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(slot)")), modifiers: .command)
                }
            }
        }

        MenuBarExtra {
            MenubarPlayerView()
                .environment(player)
                .environment(settings)
                .frame(width: 320)
        } label: {
            MenubarLabelView()
                .environment(player)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Bridge tot het NSWindow object voor titlebar transparantie.
struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.titlebarAppearsTransparent = true
                window.styleMask.insert(.fullSizeContentView)
                window.isMovableByWindowBackground = true
                window.backgroundColor = NSColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1.0)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Root view die de stations data laadt bij appearance.
struct RootContainerView: View {
    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        ContentView()
            .onAppear {
                Task {
                    await player.stations.loadRadioBrowserStations()
                }
            }
    }
}
