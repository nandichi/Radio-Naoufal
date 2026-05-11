import Foundation

/// PCM ringbuffer die de laatste ~30 seconden aan stereo float-samples vasthoudt.
/// Wordt vanuit de audio-thread geschreven; reads gebeuren incidenteel vanuit de main-thread bij rewind.
public final class TimeShiftBuffer: @unchecked Sendable {

    public let capacityFrames: Int
    public let sampleRate: Double
    public let channelCount: Int

    private let leftStorage: UnsafeMutableBufferPointer<Float>
    private let rightStorage: UnsafeMutableBufferPointer<Float>
    private var writeIndex: Int = 0
    private var totalFramesWritten: Int = 0

    private let lock = NSLock()

    public init(capacitySeconds: TimeInterval = 35, sampleRate: Double = 44_100) {
        self.sampleRate = sampleRate
        self.channelCount = 2
        let frames = Int(capacitySeconds * sampleRate)
        self.capacityFrames = frames
        let left = UnsafeMutableBufferPointer<Float>.allocate(capacity: frames)
        left.initialize(repeating: 0)
        let right = UnsafeMutableBufferPointer<Float>.allocate(capacity: frames)
        right.initialize(repeating: 0)
        self.leftStorage = left
        self.rightStorage = right
    }

    deinit {
        leftStorage.deallocate()
        rightStorage.deallocate()
    }

    public func append(left: UnsafePointer<Float>, right: UnsafePointer<Float>, frameCount: Int) {
        guard frameCount > 0, frameCount < capacityFrames else { return }
        lock.lock()
        defer { lock.unlock() }
        for i in 0..<frameCount {
            let pos = (writeIndex + i) % capacityFrames
            leftStorage[pos] = left[i]
            rightStorage[pos] = right[i]
        }
        writeIndex = (writeIndex + frameCount) % capacityFrames
        totalFramesWritten += frameCount
    }

    /// Pakt de laatste `seconds` aan samples uit de buffer in chronologische volgorde.
    /// Returns (left, right) Float-arrays. Beide hebben dezelfde frameCount.
    public func snapshot(seconds: TimeInterval) -> (left: [Float], right: [Float])? {
        let requestedFrames = min(Int(seconds * sampleRate), capacityFrames)
        lock.lock()
        defer { lock.unlock() }
        let available = min(totalFramesWritten, requestedFrames)
        guard available > 0 else { return nil }
        var left = [Float](repeating: 0, count: available)
        var right = [Float](repeating: 0, count: available)
        // Lees vanaf writeIndex - available (modulo capaciteit)
        let startIndex = ((writeIndex - available) % capacityFrames + capacityFrames) % capacityFrames
        for i in 0..<available {
            let pos = (startIndex + i) % capacityFrames
            left[i] = leftStorage[pos]
            right[i] = rightStorage[pos]
        }
        return (left, right)
    }

    /// Heeft de buffer voldoende historisch materiaal voor een nuttige rewind.
    public func hasSufficientHistory(seconds: TimeInterval = 10) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return Double(totalFramesWritten) >= seconds * sampleRate
    }
}
