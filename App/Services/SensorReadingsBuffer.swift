import Foundation

/// Collects sensor samples on the motion operation queue without spamming `MainActor` with per-sample `Task`s
/// (that pattern can freeze the UI and trigger watchdog / `EXC_BREAKPOINT` under the debugger).
final class SensorReadingsBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var magneticReadings: [Double] = []
    private var pitchReadings: [Double] = []
    private var pressureReadings: [Double] = []

    func reset() {
        lock.lock()
        magneticReadings = []
        pitchReadings = []
        pressureReadings = []
        lock.unlock()
    }

    func appendMagnetic(_ value: Double) {
        lock.lock()
        magneticReadings.append(value)
        lock.unlock()
    }

    func appendPitch(_ value: Double) {
        lock.lock()
        pitchReadings.append(value)
        lock.unlock()
    }

    func appendPressure(_ value: Double) {
        lock.lock()
        pressureReadings.append(value)
        lock.unlock()
    }

    /// Latest values for live UI (called from main run loop timer).
    func peekForLiveUI() -> (
        lastMag: Double?,
        magCount: Int,
        lastPitch: Double?,
        pitchCount: Int,
        lastPressure: Double?,
        pressureCount: Int
    ) {
        lock.lock()
        defer { lock.unlock() }
        return (
            magneticReadings.last,
            magneticReadings.count,
            pitchReadings.last,
            pitchReadings.count,
            pressureReadings.last,
            pressureReadings.count
        )
    }

    func snapshotForAverages() -> (mag: [Double], pitch: [Double], pressure: [Double]) {
        lock.lock()
        defer { lock.unlock() }
        return (magneticReadings, pitchReadings, pressureReadings)
    }
}
