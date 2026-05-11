import AVFoundation
import Accelerate

/// Wrapper rond `MTAudioProcessingTap` om live audio buffers uit een `AVPlayerItem` te tappen.
/// De tap publiceert geluidsdata via een callback voor VU-meter en FFT-visualizer.
public final class AudioTap: @unchecked Sendable {

    public struct AudioFrame: Sendable {
        public let leftRMS: Float
        public let rightRMS: Float
        public let peak: Float
        public let samples: [Float]
        public let sampleRate: Double
        public let channelCount: Int
    }

    public typealias FrameHandler = @Sendable (AudioFrame) -> Void

    private let handler: FrameHandler
    private var tap: MTAudioProcessingTap?

    /// EQ-processor die in de audio-thread in-place op de samples wordt toegepast.
    /// Een nil-waarde of `.flat` preset betekent geen filtering.
    public let eqProcessor: EQProcessor

    /// Ringbuffer voor time-shift rewind. Wordt door `AudioEngine` ingesteld voor live streams.
    public var timeShiftBuffer: TimeShiftBuffer?

    public init(handler: @escaping FrameHandler, eqProcessor: EQProcessor = EQProcessor()) {
        self.handler = handler
        self.eqProcessor = eqProcessor
    }

    /// Installeer de tap op een `AVPlayerItem`.
    /// Roep dit aan na het maken van het PlayerItem maar voor `replaceCurrentItem(with:)`.
    @MainActor
    public func install(on playerItem: AVPlayerItem) async {
        let asset = playerItem.asset
        let tracks: [AVAssetTrack]
        do {
            tracks = try await asset.loadTracks(withMediaType: .audio)
        } catch {
            return
        }
        guard let assetTrack = tracks.first else {
            return
        }

        let unmanagedSelf = Unmanaged.passUnretained(self)

        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: UnsafeMutableRawPointer(unmanagedSelf.toOpaque()),
            init: tapInit,
            finalize: tapFinalize,
            prepare: tapPrepare,
            unprepare: tapUnprepare,
            process: tapProcess
        )

        var createdTap: MTAudioProcessingTap?
        let status = withUnsafeMutablePointer(to: &callbacks) { callbacksPtr -> OSStatus in
            MTAudioProcessingTapCreate(
                kCFAllocatorDefault,
                callbacksPtr,
                kMTAudioProcessingTapCreationFlag_PostEffects,
                &createdTap
            )
        }

        guard status == noErr, let audioTap = createdTap else {
            return
        }

        self.tap = audioTap

        let audioMix = AVMutableAudioMix()
        let params = AVMutableAudioMixInputParameters(track: assetTrack)
        params.audioTapProcessor = audioTap
        audioMix.inputParameters = [params]
        playerItem.audioMix = audioMix
    }

    @MainActor
    public func detach(from playerItem: AVPlayerItem) {
        playerItem.audioMix = nil
        tap = nil
    }

    fileprivate func deliver(frame: AudioFrame) {
        handler(frame)
    }
}

// MARK: - Tap callbacks (C-style)

private func tapInit(
    tap: MTAudioProcessingTap,
    clientInfo: UnsafeMutableRawPointer?,
    tapStorageOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>
) {
    tapStorageOut.pointee = clientInfo
}

private func tapFinalize(tap: MTAudioProcessingTap) {
    // niets te doen; AudioTap zelf wordt door Swift beheerd
}

private func tapPrepare(
    tap: MTAudioProcessingTap,
    maxFrames: CMItemCount,
    processingFormat: UnsafePointer<AudioStreamBasicDescription>
) {
    // we hoeven hier geen buffers vooraf te alloceren
}

private func tapUnprepare(tap: MTAudioProcessingTap) {
    // niets te doen
}

private func tapProcess(
    tap: MTAudioProcessingTap,
    numberFrames: CMItemCount,
    flags: MTAudioProcessingTapFlags,
    bufferListInOut: UnsafeMutablePointer<AudioBufferList>,
    numberFramesOut: UnsafeMutablePointer<CMItemCount>,
    flagsOut: UnsafeMutablePointer<MTAudioProcessingTapFlags>
) {
    var timeRange = CMTimeRange.zero
    MTAudioProcessingTapGetSourceAudio(
        tap,
        numberFrames,
        bufferListInOut,
        flagsOut,
        &timeRange,
        numberFramesOut
    )
    _ = MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferListInOut, flagsOut, &timeRange, numberFramesOut)

    let storage = MTAudioProcessingTapGetStorage(tap)
    let audioTap = Unmanaged<AudioTap>.fromOpaque(storage).takeUnretainedValue()

    let buffers = UnsafeMutableAudioBufferListPointer(bufferListInOut)
    guard let first = buffers.first else { return }

    let frameCount = Int(numberFramesOut.pointee)
    let channelCount = Int(first.mNumberChannels)

    guard let rawPointer = first.mData else { return }

    // AVPlayer output is typically 44.1 kHz Float32; we approximate when no format info is provided.
    let sampleRate: Double = 44_100

    let floats = rawPointer.bindMemory(to: Float.self, capacity: frameCount * channelCount)
    let eqProcessor = audioTap.eqProcessor

    // For interleaved or planar data, compute RMS and peak
    var leftSum: Float = 0
    var rightSum: Float = 0
    var peak: Float = 0
    var mono = [Float](repeating: 0, count: frameCount)

    if buffers.count >= 2 {
        // planar
        if let leftPtr = buffers[0].mData?.bindMemory(to: Float.self, capacity: frameCount),
           let rightPtr = buffers[1].mData?.bindMemory(to: Float.self, capacity: frameCount) {
            // EQ in-place per kanaal voordat we metrics meten (post-EQ visualisatie)
            eqProcessor.process(channel: 0, samples: leftPtr, count: frameCount, sampleRate: sampleRate)
            eqProcessor.process(channel: 1, samples: rightPtr, count: frameCount, sampleRate: sampleRate)

            // Capture naar time-shift ringbuffer (na EQ zodat de rewind dezelfde EQ-output bevat)
            audioTap.timeShiftBuffer?.append(left: leftPtr, right: rightPtr, frameCount: frameCount)

            var leftSquares: Float = 0
            var rightSquares: Float = 0
            vDSP_svesq(leftPtr, 1, &leftSquares, vDSP_Length(frameCount))
            vDSP_svesq(rightPtr, 1, &rightSquares, vDSP_Length(frameCount))
            leftSum = leftSquares
            rightSum = rightSquares

            var leftMax: Float = 0
            var rightMax: Float = 0
            vDSP_maxmgv(leftPtr, 1, &leftMax, vDSP_Length(frameCount))
            vDSP_maxmgv(rightPtr, 1, &rightMax, vDSP_Length(frameCount))
            peak = max(leftMax, rightMax)

            // mono mix for FFT
            for i in 0..<frameCount {
                mono[i] = (leftPtr[i] + rightPtr[i]) * 0.5
            }
        }
    } else if channelCount == 2 {
        // interleaved stereo: deinterleave -> EQ -> reinterleave
        var leftBuffer = [Float](repeating: 0, count: frameCount)
        var rightBuffer = [Float](repeating: 0, count: frameCount)
        for i in 0..<frameCount {
            leftBuffer[i] = floats[i * 2]
            rightBuffer[i] = floats[i * 2 + 1]
        }
        leftBuffer.withUnsafeMutableBufferPointer { leftPtr in
            rightBuffer.withUnsafeMutableBufferPointer { rightPtr in
                guard let lBase = leftPtr.baseAddress, let rBase = rightPtr.baseAddress else { return }
                eqProcessor.process(channel: 0, samples: lBase, count: frameCount, sampleRate: sampleRate)
                eqProcessor.process(channel: 1, samples: rBase, count: frameCount, sampleRate: sampleRate)
                audioTap.timeShiftBuffer?.append(left: lBase, right: rBase, frameCount: frameCount)
            }
        }
        // Re-interleave terug naar de output-buffer
        for i in 0..<frameCount {
            floats[i * 2] = leftBuffer[i]
            floats[i * 2 + 1] = rightBuffer[i]
        }

        leftBuffer.withUnsafeBufferPointer { left in
            rightBuffer.withUnsafeBufferPointer { right in
                if let lBase = left.baseAddress, let rBase = right.baseAddress {
                    var leftSquares: Float = 0
                    var rightSquares: Float = 0
                    vDSP_svesq(lBase, 1, &leftSquares, vDSP_Length(frameCount))
                    vDSP_svesq(rBase, 1, &rightSquares, vDSP_Length(frameCount))
                    leftSum = leftSquares
                    rightSum = rightSquares
                }
            }
        }
        var maxValue: Float = 0
        floats.withMemoryRebound(to: Float.self, capacity: frameCount * 2) { ptr in
            vDSP_maxmgv(ptr, 1, &maxValue, vDSP_Length(frameCount * 2))
        }
        peak = maxValue
        for i in 0..<frameCount {
            mono[i] = (leftBuffer[i] + rightBuffer[i]) * 0.5
        }
    } else {
        // mono
        eqProcessor.process(channel: 0, samples: floats, count: frameCount, sampleRate: sampleRate)

        var squares: Float = 0
        vDSP_svesq(floats, 1, &squares, vDSP_Length(frameCount))
        leftSum = squares
        rightSum = squares
        var maxValue: Float = 0
        vDSP_maxmgv(floats, 1, &maxValue, vDSP_Length(frameCount))
        peak = maxValue
        for i in 0..<frameCount {
            mono[i] = floats[i]
        }
    }

    let leftRMS = frameCount > 0 ? sqrtf(leftSum / Float(frameCount)) : 0
    let rightRMS = frameCount > 0 ? sqrtf(rightSum / Float(frameCount)) : 0

    let frame = AudioTap.AudioFrame(
        leftRMS: leftRMS,
        rightRMS: rightRMS,
        peak: peak,
        samples: mono,
        sampleRate: sampleRate,
        channelCount: channelCount
    )
    audioTap.deliver(frame: frame)
}
