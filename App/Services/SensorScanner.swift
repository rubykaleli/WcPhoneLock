import CoreMotion
import Foundation

/// Owns CoreMotion hardware. Lives outside any actor so CoreMotion's internal dispatch
/// queues never conflict with Swift's `@MainActor` runtime assertions.
final class SensorScanner: @unchecked Sendable {
    private let motionManager = CMMotionManager()
    private let altimeter = CMAltimeter()
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.name = "SensorScanner.sensors"
        q.qualityOfService = .userInitiated
        q.maxConcurrentOperationCount = 1
        return q
    }()

    init() {
        motionManager.deviceMotionUpdateInterval = 0.2
        motionManager.magnetometerUpdateInterval = 0.2
    }

    var isDeviceCapable: Bool {
        motionManager.isDeviceMotionAvailable && motionManager.isMagnetometerAvailable
    }

    var hasBarometer: Bool {
        CMAltimeter.isRelativeAltitudeAvailable()
    }

    func startUpdates(into buffer: SensorReadingsBuffer) {
        motionManager.startMagnetometerUpdates(to: queue) { data, _ in
            guard let field = data?.magneticField else { return }
            let magnitude = sqrt(pow(field.x, 2) + pow(field.y, 2) + pow(field.z, 2))
            buffer.appendMagnetic(magnitude)
        }

        motionManager.startDeviceMotionUpdates(to: queue) { data, _ in
            guard let pitch = data?.attitude.pitch else { return }
            buffer.appendPitch(pitch * 180 / .pi)
        }

        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: queue) { data, _ in
                guard let pressure = data?.pressure.doubleValue else { return }
                buffer.appendPressure(pressure)
            }
        }
    }

    func stopUpdates() {
        motionManager.stopMagnetometerUpdates()
        motionManager.stopDeviceMotionUpdates()
        altimeter.stopRelativeAltitudeUpdates()
    }
}
