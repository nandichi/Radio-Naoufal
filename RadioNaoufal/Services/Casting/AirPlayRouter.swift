import Foundation
import AVKit
import AVFoundation
import AppKit
import SwiftUI

/// Wrapper rond `AVRoutePickerView` voor SwiftUI.
public struct AirPlayPickerView: NSViewRepresentable {
    public let player: AVPlayer
    public let tint: NSColor

    public init(player: AVPlayer, tint: NSColor = .labelColor) {
        self.player = player
        self.tint = tint
    }

    public func makeNSView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.player = player
        picker.isRoutePickerButtonBordered = false
        picker.setRoutePickerButtonColor(tint, for: .normal)
        picker.setRoutePickerButtonColor(tint.withAlphaComponent(0.5), for: .normalHighlighted)
        picker.setRoutePickerButtonColor(.systemBlue, for: .active)
        return picker
    }

    public func updateNSView(_ nsView: AVRoutePickerView, context: Context) {
        nsView.player = player
        nsView.setRoutePickerButtonColor(tint, for: .normal)
    }
}

/// Helper voor het bepalen van de huidige actieve audio-route (AirPlay-detectie).
@MainActor
public final class AirPlayRouter {
    public static let shared = AirPlayRouter()

    public private(set) var currentRouteName: String?
    public private(set) var isAirPlayActive: Bool = false

    private init() {}

    public func refreshFromPlayer(_ player: AVPlayer) {
        guard let item = player.currentItem else {
            currentRouteName = nil
            isAirPlayActive = false
            return
        }
        // Externe playback indicator op AVPlayer
        if player.isExternalPlaybackActive {
            isAirPlayActive = true
            currentRouteName = "AirPlay"
        } else {
            isAirPlayActive = false
            currentRouteName = nil
        }
        _ = item
    }
}
