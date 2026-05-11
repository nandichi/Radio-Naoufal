# Radio Naoufal

Een native macOS radio-app met een schoon-skeuomorfische 1980s boombox als hart van de interface. Speelt ~35 curated Nederlandse zenders, plus alle zenders uit Radio-Browser. Native AirPlay-ondersteuning en Chromecast via ChromecastKit.

## Highlights

- **1980s boombox UI** met twee speakers, analoge VU-meters, cassette-deck als Now Playing display, FM tuner-dial en chrome draaiknoppen
- **35+ Nederlandse zenders** (NPO Radio 1-5, FunX, Sky, 538, Qmusic, Radio 10, Veronica, 100% NL, SLAM!, BNR, Sublime, RadioNL, en alle regionale omroepen)
- **Live audio-reactieve visualizers** (vDSP FFT EQ-bars + analoge VU-meters via `MTAudioProcessingTap`)
- **ICY metadata** parsen uit Shoutcast/Icecast streams
- **AirPlay-ondersteuning** via `AVRoutePickerView`
- **Chromecast-ondersteuning** via ChromecastKit
- **Favorieten** (9 presets met `cmd+1..9` shortcuts) + recent geluisterd + zoeken
- **Sleep timer** met fade-out
- **Menubar mini-player** met play/pause, volume slider en station-info
- **macOS Now Playing widget** en media-key support via `MPNowPlayingInfoCenter`
- **Nederlands + Engels** localization

## Vereisten

- **macOS 15.0+** (Sequoia of nieuwer)
- **Xcode 16.0+** voor het bouwen van een echte `.app` (volledige Xcode, niet alleen Command Line Tools)
- **Swift 6.0+**
- **xcodegen** (optioneel, voor het regenereren van het Xcode project): `brew install xcodegen`

> Het project bouwt ook met enkel Command Line Tools via `swift build`, maar voor een redistributable `.app` bundle is volledige Xcode nodig.

## Project openen in Xcode

### Optie 1 - via XcodeGen (aanbevolen)

```bash
brew install xcodegen
xcodegen generate
open RadioNaoufal.xcodeproj
```

### Optie 2 - via Swift Package Manager

```bash
open Package.swift
```

Xcode opent dan een workspace gebaseerd op de SPM-configuratie.

## Bouwen vanaf de command line

### Snelle compile-check (alleen Command Line Tools)

```bash
swift build
```

### Volledige .app + .dmg

```bash
./Scripts/build-app.sh Release
./Scripts/make-dmg.sh
```

De `.dmg` belandt in `dist/RadioNaoufal-1.0.0.dmg`.

## Repo structuur

```
Radio-Naoufal/
  project.yml                   # XcodeGen config voor .xcodeproj generatie
  Package.swift                 # SPM fallback voor CLI builds
  RadioNaoufal/                 # alle Swift source files
    App/                        # @main App + ContentView
    Domain/                     # Models + ViewModels
    Services/                   # Audio, Stations, Casting, NowPlaying, Persistence
    Features/                   # SwiftUI views per feature
      Boombox/                  # de boombox-hero
      BrowseDrawer/             # uitklapbare drawer met 4 tabs
      Menubar/                  # MenuBarExtra mini-player
      Casting/                  # Chromecast device picker
      SleepTimer/               # popover
    Resources/
      Assets.xcassets/          # app icon + accent color
      curated-stations.json     # de 35 zenders
      Localizable.xcstrings     # nl + en strings
    Info.plist
    RadioNaoufal.entitlements
  RadioNaoufalTests/
  Scripts/
    generate-app-icon.swift     # genereert de boombox-icoon
    build-app.sh                # bouwt .app via xcodebuild
    make-dmg.sh                 # bouwt .dmg installer
  .github/workflows/release.yml # automatische DMG bouwen bij tag
```

## Architectuur

- **`AudioEngine`** wikkelt `AVPlayer` + `MTAudioProcessingTap` voor live audio buffers. Voert play/pause/stop, volume en fade-out uit. Publiceert `PlayerState` via `@Observable`.
- **`AudioTap`** is een Swift-wrapper rond `MTAudioProcessingTap` die per audio-frame RMS-waarden en sample-arrays levert.
- **`VisualizerEngine`** verwerkt die frames met `vDSP_FFT` tot VU-niveau (per kanaal) en 16 logaritmisch gesplitste EQ-bars.
- **`ICYMetadataParser`** opent een parallelle URLSession-bytestream met `Icy-MetaData: 1` header en parsed inline ICY metadata uit Shoutcast/Icecast streams (titel/artiest).
- **`StationsRepository`** laadt curated stations uit `Resources/curated-stations.json` en haalt extra zenders op uit `https://api.radio-browser.info`.
- **`CastManager`** beheert Chromecast device discovery + cast-sessies via ChromecastKit. Fallt terug op Bonjour-only discovery wanneer ChromecastKit niet beschikbaar is.
- **`NowPlayingCenter`** integreert met `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter` voor de macOS Now Playing widget en media keys.
- **`DataStore`** is een eenvoudige JSON-gebaseerde persistence in `~/Library/Application Support/RadioNaoufal/` voor favorieten + recent (geen SwiftData nodig).

## Keyboard shortcuts

| Shortcut         | Actie                          |
| ---------------- | ------------------------------ |
| `Space`          | Afspelen / pauzeren            |
| `Cmd+1` ... `9`  | Speel preset 1-9               |
| `Cmd+Right`      | Volgende zender                |
| `Cmd+Left`       | Vorige zender                  |
| `Cmd+F`          | Open zoek-sheet                |
| `Cmd+Q`          | Stop Radio Naoufal             |
| Media keys       | Play/pause via fn-toetsen      |

## Code signing & notarization

Bij de standaard `Scripts/make-dmg.sh` wordt de app **niet** gecodesigned. macOS Gatekeeper zal de DMG blokkeren. Twee opties:

1. **Eerste keer openen via right-click**: rechtsklik op `Radio Naoufal.app` -> `Open` -> bevestig.
2. **Properly signen + notarizen** (vereist Apple Developer-account, ~99 USD/jaar):

   ```bash
   codesign --deep --force --options runtime \
     --sign "Developer ID Application: Naoufal Andichi (TEAMID)" \
     "build/Radio Naoufal.app"

   xcrun notarytool submit dist/RadioNaoufal-1.0.0.dmg \
     --apple-id "you@example.com" \
     --team-id TEAMID \
     --password "@keychain:notary-password" \
     --wait

   xcrun stapler staple dist/RadioNaoufal-1.0.0.dmg
   ```

## Bekende limitaties

- **Stream URLs** kunnen veranderen. Update `RadioNaoufal/Resources/curated-stations.json` als een zender stopt met werken.
- **Live audio-reactieve visualizer werkt niet tijdens Chromecast** - de Chromecast speelt zelfstandig en de Mac heeft geen toegang tot de audio buffer. We tonen dan een 'Casting naar [device]' state.
- **AVPlayer audio format** wordt aangenomen 44.1 kHz Float32. Sommige streams kunnen er anders uitzien; de visualizer blijft werken maar het frequentiebereik kan iets afwijken.
- **DAB+ zenders** alleen via online streams (Mac heeft geen DAB+ hardware).
- **ChromecastKit is nieuw** (2026 release) - kan API-wijzigingen krijgen. Pin een specifieke versie als je een release maakt.

## License

MIT - zie [LICENSE](LICENSE) (TODO toevoegen).
