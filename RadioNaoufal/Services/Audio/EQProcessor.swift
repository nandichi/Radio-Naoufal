import Foundation
import Accelerate
import os

/// Vier-band peaking equalizer als cascade van biquad-filters.
/// Veilig om vanaf de real-time audio-thread aan te roepen (geen MainActor isolatie, geen allocaties tijdens process).
public final class EQProcessor: @unchecked Sendable {

    public enum Preset: String, CaseIterable, Sendable {
        case flat
        case rock
        case classical
        case vocal

        /// 4-band gains in dB voor center-frequenties 60, 250, 4000, 12000 Hz.
        var gainsDB: [Float] {
            switch self {
            case .flat: return [0, 0, 0, 0]
            case .rock: return [5, 2, 3, 4]
            case .classical: return [1, -1, -1, 3]
            case .vocal: return [-2, 2, 5, 1]
            }
        }
    }

    /// Vaste center-frequenties + Q.
    private static let bandFrequencies: [Float] = [60, 250, 4_000, 12_000]
    private static let bandQ: Float = 0.71

    /// Per-preset, per-band, 5 normalized coefficients: b0, b1, b2, a1, a2.
    /// Index: presetIndex * bandCount * 5 + bandIndex * 5 + coefIndex.
    private var coefficients: [Float]

    /// Per-channel-state per band: x1, x2, y1, y2. Up to 2 channels (stereo).
    private var states: [[BiquadState]]

    /// Lock around `activePresetIndex` reads/writes (audio-thread leest, main-thread schrijft).
    private let lock = OSAllocatedUnfairLock<Int>(initialState: 0)

    /// Sample-rate waarop de coefficients zijn gegenereerd. Bij verandering opnieuw bereken.
    private var currentSampleRate: Double = 44_100

    public init(sampleRate: Double = 44_100) {
        self.currentSampleRate = sampleRate
        self.coefficients = []
        self.states = [
            Array(repeating: BiquadState(), count: Self.bandFrequencies.count),
            Array(repeating: BiquadState(), count: Self.bandFrequencies.count)
        ]
        recalculateCoefficients(sampleRate: sampleRate)
    }

    public func setPreset(_ preset: Preset) {
        let index = Self.indexFor(preset)
        lock.withLock { $0 = index }
    }

    public func setPresetByName(_ name: String) {
        let preset = Preset(rawValue: name) ?? .flat
        setPreset(preset)
    }

    /// Werkt in-place op een audio-buffer voor een specifiek kanaal (0 of 1).
    /// Sample-rate is doorgegeven zodat we coefficients kunnen herberekenen bij format-change.
    public func process(channel: Int, samples: UnsafeMutablePointer<Float>, count: Int, sampleRate: Double) {
        guard channel < states.count else { return }

        let preset = currentPresetIndex()
        if preset == Self.indexFor(.flat) {
            // No-op voor flat preset; spaart cycles
            return
        }

        if abs(sampleRate - currentSampleRate) > 1.0 {
            currentSampleRate = sampleRate
            recalculateCoefficients(sampleRate: sampleRate)
        }

        let bandCount = Self.bandFrequencies.count
        let baseIndex = preset * bandCount * 5

        for band in 0..<bandCount {
            let coefBase = baseIndex + band * 5
            let b0 = coefficients[coefBase]
            let b1 = coefficients[coefBase + 1]
            let b2 = coefficients[coefBase + 2]
            let a1 = coefficients[coefBase + 3]
            let a2 = coefficients[coefBase + 4]

            var state = states[channel][band]
            var x1 = state.x1
            var x2 = state.x2
            var y1 = state.y1
            var y2 = state.y2

            for i in 0..<count {
                let x0 = samples[i]
                let y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
                x2 = x1
                x1 = x0
                y2 = y1
                y1 = y0
                samples[i] = y0
            }

            state.x1 = x1
            state.x2 = x2
            state.y1 = y1
            state.y2 = y2
            states[channel][band] = state
        }
    }

    /// Reset state buffers (bij station-switch of pause).
    public func resetState() {
        for channel in 0..<states.count {
            for band in 0..<states[channel].count {
                states[channel][band] = BiquadState()
            }
        }
    }

    // MARK: - Internals

    private struct BiquadState {
        var x1: Float = 0
        var x2: Float = 0
        var y1: Float = 0
        var y2: Float = 0
    }

    private func currentPresetIndex() -> Int {
        lock.withLock { $0 }
    }

    private static func indexFor(_ preset: Preset) -> Int {
        Preset.allCases.firstIndex(of: preset) ?? 0
    }

    private func recalculateCoefficients(sampleRate: Double) {
        let presetCount = Preset.allCases.count
        let bandCount = Self.bandFrequencies.count
        var result = [Float](repeating: 0, count: presetCount * bandCount * 5)

        for (presetIdx, preset) in Preset.allCases.enumerated() {
            let gains = preset.gainsDB
            for bandIdx in 0..<bandCount {
                let freq = Self.bandFrequencies[bandIdx]
                let gainDB = gains[bandIdx]
                let coefs = peakingEQCoefficients(freq: freq, gainDB: gainDB, q: Self.bandQ, sampleRate: Float(sampleRate))
                let base = presetIdx * bandCount * 5 + bandIdx * 5
                result[base] = coefs.b0
                result[base + 1] = coefs.b1
                result[base + 2] = coefs.b2
                result[base + 3] = coefs.a1
                result[base + 4] = coefs.a2
            }
        }

        coefficients = result
    }

    private func peakingEQCoefficients(freq: Float, gainDB: Float, q: Float, sampleRate: Float) -> (b0: Float, b1: Float, b2: Float, a1: Float, a2: Float) {
        // Robert Bristow-Johnson Audio EQ Cookbook - peaking EQ
        let A = powf(10, gainDB / 40)
        let omega = 2 * .pi * freq / sampleRate
        let sinOmega = sinf(omega)
        let cosOmega = cosf(omega)
        let alpha = sinOmega / (2 * q)

        let a0 = 1 + alpha / A
        let b0 = (1 + alpha * A) / a0
        let b1 = (-2 * cosOmega) / a0
        let b2 = (1 - alpha * A) / a0
        let a1 = (-2 * cosOmega) / a0
        let a2 = (1 - alpha / A) / a0

        return (b0, b1, b2, a1, a2)
    }
}
