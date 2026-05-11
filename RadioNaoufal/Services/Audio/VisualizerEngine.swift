import Foundation
import Accelerate
import Observation

/// Verwerkt rauwe audio-samples tot waarden die VU-meters en EQ-bars kunnen tekenen.
@MainActor
@Observable
public final class VisualizerEngine {

    public static let barCount: Int = 16

    public private(set) var leftLevel: Float = 0
    public private(set) var rightLevel: Float = 0
    public private(set) var peak: Float = 0
    public private(set) var bars: [Float] = Array(repeating: 0, count: VisualizerEngine.barCount)

    private let fftSize: Int
    private let fftSetup: vDSP.FFT<DSPSplitComplex>?
    private let log2Size: vDSP_Length

    private var smoothedBars: [Float] = Array(repeating: 0, count: VisualizerEngine.barCount)
    private let barSmoothing: Float = 0.55
    private let levelSmoothing: Float = 0.4
    private var window: [Float] = []

    public init(fftSize: Int = 1024) {
        self.fftSize = fftSize
        self.log2Size = vDSP_Length(log2(Double(fftSize)).rounded())
        self.fftSetup = vDSP.FFT(log2n: log2Size, radix: .radix2, ofType: DSPSplitComplex.self)
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        self.window = window
    }

    public func reset() {
        leftLevel = 0
        rightLevel = 0
        peak = 0
        bars = Array(repeating: 0, count: VisualizerEngine.barCount)
        smoothedBars = bars
    }

    public func ingest(frame: AudioTap.AudioFrame) {
        let normalizedLeft = min(1.0, frame.leftRMS * 1.6)
        let normalizedRight = min(1.0, frame.rightRMS * 1.6)
        let normalizedPeak = min(1.0, frame.peak * 1.2)

        leftLevel = lerp(leftLevel, target: normalizedLeft, alpha: levelSmoothing)
        rightLevel = lerp(rightLevel, target: normalizedRight, alpha: levelSmoothing)
        peak = lerp(peak, target: normalizedPeak, alpha: levelSmoothing)

        let computedBars = computeBars(from: frame.samples, sampleRate: frame.sampleRate)
        for i in 0..<smoothedBars.count {
            smoothedBars[i] = lerp(smoothedBars[i], target: computedBars[i], alpha: barSmoothing)
        }
        bars = smoothedBars
    }

    private func computeBars(from samples: [Float], sampleRate: Double) -> [Float] {
        let zeroBars = [Float](repeating: 0, count: VisualizerEngine.barCount)
        guard let fftSetup else { return zeroBars }
        guard samples.count >= fftSize else { return zeroBars }

        var windowed = [Float](repeating: 0, count: fftSize)
        samples.withUnsafeBufferPointer { samplesPtr in
            window.withUnsafeBufferPointer { windowPtr in
                vDSP_vmul(samplesPtr.baseAddress!, 1, windowPtr.baseAddress!, 1, &windowed, 1, vDSP_Length(fftSize))
            }
        }

        let halfSize = fftSize / 2
        var realParts = [Float](repeating: 0, count: halfSize)
        var imagParts = [Float](repeating: 0, count: halfSize)
        var magnitudes = [Float](repeating: 0, count: halfSize)

        realParts.withUnsafeMutableBufferPointer { realPtr in
            imagParts.withUnsafeMutableBufferPointer { imagPtr in
                guard let realBase = realPtr.baseAddress, let imagBase = imagPtr.baseAddress else { return }
                var splitComplex = DSPSplitComplex(realp: realBase, imagp: imagBase)
                windowed.withUnsafeBytes { rawBuffer in
                    let typedPtr = rawBuffer.bindMemory(to: DSPComplex.self)
                    vDSP_ctoz(typedPtr.baseAddress!, 2, &splitComplex, 1, vDSP_Length(halfSize))
                }
                fftSetup.forward(input: splitComplex, output: &splitComplex)
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfSize))
            }
        }

        var scaledMagnitudes = magnitudes.map { sqrt($0 / Float(fftSize)) }

        // Logarithmic bucketing across audible band
        let minFreq: Float = 60
        let maxFreq: Float = 16_000
        let nyquist = Float(sampleRate) / 2
        let binCount = scaledMagnitudes.count
        let binWidth = nyquist / Float(binCount)

        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)

        var output = [Float](repeating: 0, count: VisualizerEngine.barCount)
        for barIndex in 0..<VisualizerEngine.barCount {
            let logLow = logMin + (logMax - logMin) * (Float(barIndex) / Float(VisualizerEngine.barCount))
            let logHigh = logMin + (logMax - logMin) * (Float(barIndex + 1) / Float(VisualizerEngine.barCount))
            let low = pow(10, logLow)
            let high = pow(10, logHigh)
            let lowBin = max(0, Int(low / binWidth))
            let highBin = min(binCount - 1, Int(high / binWidth))
            guard highBin >= lowBin else {
                output[barIndex] = 0
                continue
            }
            var maxValue: Float = 0
            scaledMagnitudes.withUnsafeMutableBufferPointer { ptr in
                vDSP_maxv(ptr.baseAddress! + lowBin, 1, &maxValue, vDSP_Length(highBin - lowBin + 1))
            }
            // Compress dynamic range
            let db = 20 * log10f(max(maxValue, 0.0001))
            let normalized = max(0, min(1, (db + 60) / 60))
            output[barIndex] = normalized
        }

        return output
    }

    private func lerp(_ current: Float, target: Float, alpha: Float) -> Float {
        current + (target - current) * alpha
    }
}
