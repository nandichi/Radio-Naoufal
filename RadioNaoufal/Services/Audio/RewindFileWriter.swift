import Foundation
import AVFoundation

/// Schrijft een (left, right) Float-samples paar naar een tmp .m4a (AAC) bestand
/// dat door `AVPlayer` opnieuw afgespeeld kan worden voor time-shift rewind.
public enum RewindFileWriter {

    public enum WriterError: Error {
        case bufferAllocationFailed
        case writeFailed(String)
    }

    /// Tmp-directory waar rewind-files worden opgeslagen. Apart zodat cleanup eenvoudig is.
    public static var directory: URL {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("RadioNaoufal-TimeShift", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    public static func makeURL() -> URL {
        let name = "timeshift-\(Int(Date().timeIntervalSince1970)).m4a"
        return directory.appendingPathComponent(name)
    }

    /// Schrijft naar `url` en returnt zodra het bestand klaar is.
    public static func write(left: [Float], right: [Float], sampleRate: Double, to url: URL) async throws {
        precondition(left.count == right.count, "Left and right must have equal length")
        let frameCount = left.count
        guard frameCount > 0 else { throw WriterError.writeFailed("Empty sample arrays") }

        try? FileManager.default.removeItem(at: url)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: sampleRate,
            AVEncoderBitRateKey: 128_000
        ]

        let file: AVAudioFile
        do {
            file = try AVAudioFile(forWriting: url, settings: settings)
        } catch {
            throw WriterError.writeFailed(error.localizedDescription)
        }

        let processingFormat = file.processingFormat
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
            throw WriterError.bufferAllocationFailed
        }
        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)

        if processingFormat.isInterleaved {
            guard let dest = pcmBuffer.floatChannelData?[0] else {
                throw WriterError.bufferAllocationFailed
            }
            for i in 0..<frameCount {
                dest[i * 2] = left[i]
                dest[i * 2 + 1] = right[i]
            }
        } else {
            guard let channels = pcmBuffer.floatChannelData else {
                throw WriterError.bufferAllocationFailed
            }
            left.withUnsafeBufferPointer { leftPtr in
                memcpy(channels[0], leftPtr.baseAddress!, frameCount * MemoryLayout<Float>.size)
            }
            right.withUnsafeBufferPointer { rightPtr in
                memcpy(channels[1], rightPtr.baseAddress!, frameCount * MemoryLayout<Float>.size)
            }
        }

        do {
            try file.write(from: pcmBuffer)
        } catch {
            throw WriterError.writeFailed(error.localizedDescription)
        }
    }

    /// Verwijdert rewind-tmp files die ouder zijn dan `olderThan` seconden (default: 1 dag).
    public static func cleanup(olderThan seconds: TimeInterval = 86400) {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }
        let cutoff = Date().addingTimeInterval(-seconds)
        for url in urls where url.lastPathComponent.hasPrefix("timeshift-") && url.pathExtension == "m4a" {
            if let attrs = try? fm.attributesOfItem(atPath: url.path),
               let modDate = attrs[.modificationDate] as? Date,
               modDate < cutoff {
                try? fm.removeItem(at: url)
            }
        }
    }
}
