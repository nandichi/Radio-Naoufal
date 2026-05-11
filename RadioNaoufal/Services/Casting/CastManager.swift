import Foundation
import Observation
import Network
import os

#if canImport(ChromecastKit)
import ChromecastKit
#endif

public struct CastDevice: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let modelName: String?
    public let ipAddress: String?
    public let port: Int?

    public init(id: String, name: String, modelName: String? = nil, ipAddress: String? = nil, port: Int? = nil) {
        self.id = id
        self.name = name
        self.modelName = modelName
        self.ipAddress = ipAddress
        self.port = port
    }
}

public enum CastConnectionState: Equatable, Sendable {
    case disconnected
    case discovering
    case connecting(deviceName: String)
    case connected(deviceName: String)
    case playing(deviceName: String)
    case error(String)
}

/// Beheert Chromecast device discovery en cast-sessies via `ChromecastKit`.
///
/// Wanneer `ChromecastKit` niet beschikbaar is wordt de Manager teruggevallen op een
/// Bonjour-only discovery via `Network.framework`, zonder media-playback.
@MainActor
@Observable
public final class CastManager {

    public private(set) var devices: [CastDevice] = []
    public private(set) var state: CastConnectionState = .disconnected
    public private(set) var activeDevice: CastDevice?

    private let logger = Logger(subsystem: "nl.naoufal.radio-naoufal", category: "CastManager")

    #if canImport(ChromecastKit)
    private var discovery: CastDiscovery?
    private var session: CastSession?
    private var discoveryEventsTask: Task<Void, Never>?
    private var rawDevices: [String: CastDeviceDescriptor] = [:]
    #else
    private var browser: NWBrowser?
    #endif

    public init() {}

    // MARK: - Discovery

    public func startDiscovery() {
        state = .discovering
        devices = []

        #if canImport(ChromecastKit)
        let discovery = CastDiscovery(configuration: .init(includeGroups: true))
        self.discovery = discovery
        discoveryEventsTask?.cancel()
        discoveryEventsTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await discovery.start()
                let stream = await discovery.events()
                for await event in stream {
                    await self.handleDiscoveryEvent(event)
                }
            } catch {
                await MainActor.run {
                    self.logger.error("Discovery start failed: \(error.localizedDescription, privacy: .public)")
                    self.state = .error(error.localizedDescription)
                }
            }
        }
        #else
        startBonjourDiscovery()
        #endif
    }

    public func stopDiscovery() {
        #if canImport(ChromecastKit)
        discoveryEventsTask?.cancel()
        discoveryEventsTask = nil
        if let discovery {
            Task { await discovery.stop() }
        }
        discovery = nil
        rawDevices.removeAll()
        #else
        browser?.cancel()
        browser = nil
        #endif
        if case .discovering = state {
            state = .disconnected
        }
    }

    // MARK: - Connection

    public func connect(to device: CastDevice) {
        state = .connecting(deviceName: device.name)
        #if canImport(ChromecastKit)
        guard let descriptor = rawDevices[device.id] else {
            state = .error(String(localized: "Apparaat niet meer beschikbaar"))
            return
        }
        logger.info("Cast connect → \(device.name, privacy: .public) host=\(descriptor.host, privacy: .public) port=\(descriptor.port) model=\(descriptor.modelName ?? "?", privacy: .public)")
        Task { [weak self] in
            guard let self else { return }
            do {
                let session = CastSession(
                    device: descriptor,
                    configuration: .init(
                        connectTimeout: 12,
                        commandTimeout: 10,
                        heartbeatInterval: 5,
                        autoReconnect: true,
                        logLevel: .debug
                    )
                )
                try await session.connect()
                _ = try await session.launchDefaultMediaReceiver()
                await MainActor.run {
                    self.session = session
                    self.activeDevice = device
                    self.state = .connected(deviceName: device.name)
                }
            } catch {
                let readable = Self.readableMessage(for: error)
                await MainActor.run {
                    self.logger.error("Cast connect failed: \(readable, privacy: .public)")
                    self.state = .error(readable)
                }
            }
        }
        #else
        activeDevice = device
        state = .error(String(localized: "ChromecastKit niet gevonden - cast werkt niet"))
        #endif
    }

    public func disconnect() {
        #if canImport(ChromecastKit)
        if let session {
            Task { await session.disconnect() }
        }
        session = nil
        #endif
        activeDevice = nil
        state = .disconnected
    }

    // MARK: - Media

    public func play(station: Station) async {
        guard let device = activeDevice else { return }
        #if canImport(ChromecastKit)
        guard let session else { return }
        do {
            let images: [CastImage] = station.logoURL.map { [CastImage(url: $0)] } ?? []
            let metadata: CastMediaMetadata = .generic(
                title: station.name,
                subtitle: station.genre.localizedLabel,
                images: images
            )
            let item = CastMediaItem(
                contentURL: station.streamURL,
                contentType: contentType(for: station),
                streamType: .live,
                metadata: metadata
            )
            _ = try await session.media.load(item)
            await MainActor.run {
                self.state = .playing(deviceName: device.name)
            }
        } catch {
            let readable = Self.readableMessage(for: error)
            await MainActor.run {
                self.logger.error("Cast play failed: \(readable, privacy: .public)")
                self.state = .error(readable)
            }
        }
        #else
        _ = station
        state = .error(String(localized: "ChromecastKit niet gevonden - cast werkt niet"))
        #endif
    }

    public func pause() async {
        #if canImport(ChromecastKit)
        guard let session else { return }
        _ = try? await session.media.pause()
        if case .playing(let name) = state {
            state = .connected(deviceName: name)
        }
        #endif
    }

    public func resume() async {
        #if canImport(ChromecastKit)
        guard let session else { return }
        _ = try? await session.media.play()
        if case .connected(let name) = state {
            state = .playing(deviceName: name)
        }
        #endif
    }

    public func setVolume(_ value: Float) async {
        #if canImport(ChromecastKit)
        guard let session else { return }
        _ = try? await session.media.setVolume(level: Double(min(1, max(0, value))))
        #endif
    }

    // MARK: - Private

    /// Vertaalt een Swift error (in het bijzonder `CastError`) naar een leesbare
    /// Nederlandse boodschap. Foundation's NSError bridge verbergt de associated
    /// values waardoor de UI alleen "fout 10" zou tonen.
    static func readableMessage(for error: any Error) -> String {
        #if canImport(ChromecastKit)
        if let castError = error as? CastError {
            switch castError {
            case .discoveryFailed(let msg):
                return String(localized: "Apparaten zoeken mislukt: \(msg)")
            case .connectionFailed(let msg):
                return String(localized: "Verbinden mislukt: \(msg)")
            case .disconnected:
                return String(localized: "Verbinding verbroken")
            case .timeout(let op):
                return String(localized: "Timeout bij \(op)")
            case .unsupportedNamespace(let ns):
                return String(localized: "Apparaat ondersteunt protocol niet: \(ns)")
            case .unsupportedFeature(let feature):
                return String(localized: "Apparaat ondersteunt functie niet: \(feature)")
            case .invalidResponse(let msg):
                return String(localized: "Onverwacht antwoord: \(msg)")
            case .requestFailed(let code, let msg):
                let codePart = code.map { " (\($0))" } ?? ""
                return String(localized: "Verzoek mislukt\(codePart): \(msg)")
            case .loadFailed(let code, let msg):
                let codePart = code.map { " (\($0))" } ?? ""
                return String(localized: "Laden mislukt\(codePart): \(msg)")
            case .noActiveMediaSession:
                return String(localized: "Geen actieve mediasessie")
            case .invalidArgument(let msg):
                return String(localized: "Ongeldig argument: \(msg)")
            }
        }
        #endif
        return error.localizedDescription
    }

    private func contentType(for station: Station) -> String {
        switch station.codec {
        case .mp3: return "audio/mpeg"
        case .aac, .heAac: return "audio/aac"
        case .ogg: return "audio/ogg"
        case .hls: return "application/vnd.apple.mpegurl"
        case .unknown: return "audio/mpeg"
        }
    }

    #if canImport(ChromecastKit)
    private func handleDiscoveryEvent(_ event: CastDiscovery.Event) async {
        switch event {
        case .deviceUpserted(let descriptor, _):
            await MainActor.run {
                self.rawDevices[descriptor.id.rawValue] = descriptor
                let device = CastDevice(
                    id: descriptor.id.rawValue,
                    name: descriptor.friendlyName,
                    modelName: descriptor.modelName,
                    ipAddress: descriptor.host,
                    port: descriptor.port
                )
                if let index = self.devices.firstIndex(where: { $0.id == device.id }) {
                    self.devices[index] = device
                } else {
                    self.devices.append(device)
                }
            }
        case .deviceRemoved(let id):
            await MainActor.run {
                self.rawDevices[id.rawValue] = nil
                self.devices.removeAll { $0.id == id.rawValue }
            }
        case .started, .stopped:
            break
        case .error(let castError):
            let readable = Self.readableMessage(for: castError)
            await MainActor.run {
                self.state = .error(readable)
            }
        }
    }
    #else
    private func startBonjourDiscovery() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: "_googlecast._tcp", domain: nil), using: parameters)
        self.browser = browser
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                var found: [CastDevice] = []
                for result in results {
                    if case .service(let name, _, _, _) = result.endpoint {
                        found.append(CastDevice(id: name, name: name, modelName: nil, ipAddress: nil, port: nil))
                    }
                }
                self.devices = found
            }
        }
        browser.start(queue: .main)
    }
    #endif
}
