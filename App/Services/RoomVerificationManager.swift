import CoreMotion
import Foundation

enum VerificationOutcome {
    case passed(VerificationSnapshot)
    case failed(VerificationSnapshot, reason: String)
    case unavailable(String)
}

struct ScanLiveDebug: Equatable {
    var secondsElapsed: Double = 0
    var magnetometerMicroteslas: Double?
    var pitchDegrees: Double?
    var pressureHectopascals: Double?
    var networkPathSummary: String = "…"
    var nativeWifiSummary: String = "…"
    var sampleCountMag: Int = 0
    var sampleCountPressure: Int = 0
}

@MainActor
final class RoomVerificationManager: ObservableObject {
    @Published private(set) var isScanning = false
    @Published private(set) var scanProgress: Double = 0
    @Published private(set) var liveDebug = ScanLiveDebug()

    private let scanner = SensorScanner()
    private let readingsBuffer = SensorReadingsBuffer()
    private let networkPath = NetworkPathStatus()

    // MARK: - 10-second calibration scan

    func capture10SecondSnapshot() async -> VerificationOutcome {
        #if targetEnvironment(simulator)
        if BuildFlavor.isLocalTesting, !scanner.isDeviceCapable {
            return await mockSnapshotForSimulatorTesting()
        }
        #endif

        guard scanner.isDeviceCapable else {
            return .unavailable("This device does not support the required motion sensors.")
        }

        isScanning = true
        scanProgress = 0

        let buffer = readingsBuffer
        let net = networkPath

        buffer.reset()
        net.start()

        liveDebug = ScanLiveDebug(networkPathSummary: net.summary)

        scanner.startUpdates(into: buffer)

        defer {
            scanner.stopUpdates()
            net.stop()
            isScanning = false
            scanProgress = 0
        }

        let steps = 100
        for step in 1 ... steps {
            try? await Task.sleep(for: .milliseconds(100))
            scanProgress = Double(step) / Double(steps)

            let p = buffer.peekForLiveUI()
            liveDebug.secondsElapsed = Double(step) / 10.0
            liveDebug.magnetometerMicroteslas = p.lastMag
            liveDebug.sampleCountMag = p.magCount
            liveDebug.pitchDegrees = p.lastPitch
            liveDebug.pressureHectopascals = p.lastPressure
            liveDebug.sampleCountPressure = p.pressureCount
            liveDebug.networkPathSummary = net.summary
        }

        let (magCopy, pitchCopy, pressureCopy) = buffer.snapshotForAverages()

        guard !magCopy.isEmpty, !pitchCopy.isEmpty else {
            return .unavailable("Room verification could not capture the required sensor data. Try again.")
        }

        let avgMagnetic = magCopy.reduce(0, +) / Double(magCopy.count)
        let avgPitch = pitchCopy.reduce(0, +) / Double(pitchCopy.count)
        let avgPressure = pressureCopy.isEmpty ? nil : pressureCopy.reduce(0, +) / Double(pressureCopy.count)

        let nativeWifi = await fetchNativeWifiForSnapshot()
        liveDebug.nativeWifiSummary = nativeWifi?.shortSummary ?? "Unavailable"

        return .passed(VerificationSnapshot(
            magneticMagnitude: avgMagnetic,
            pitchDegrees: avgPitch,
            pressureHectopascals: avgPressure,
            nativeWifi: nativeWifi
        ))
    }

    // MARK: - Quick 1.2s verification scan

    func captureSnapshot() async -> VerificationOutcome {
        guard scanner.isDeviceCapable else {
            return .unavailable("This device does not support the required motion sensors.")
        }

        isScanning = true

        let quickBuffer = SensorReadingsBuffer()
        scanner.startUpdates(into: quickBuffer)

        defer {
            scanner.stopUpdates()
            isScanning = false
        }

        try? await Task.sleep(for: .seconds(1.2))

        let (magCopy, pitchCopy, pressureCopy) = quickBuffer.snapshotForAverages()

        guard let lastMag = magCopy.last, let lastPitch = pitchCopy.last else {
            return .unavailable("Room verification could not capture the required sensor data.")
        }

        let nativeWifi = await fetchNativeWifiForSnapshot()

        return .passed(VerificationSnapshot(
            magneticMagnitude: lastMag,
            pitchDegrees: lastPitch,
            pressureHectopascals: pressureCopy.last,
            nativeWifi: nativeWifi
        ))
    }

    func verify(using calibration: CalibrationProfile, shortcutWifi: ShortcutWiFiReading?) async -> VerificationOutcome {
        let snapshotResult = await captureSnapshot()

        switch snapshotResult {
        case let .passed(snapshot):
            let merged = snapshot.mergingShortcutWifi(shortcutWifi)
            if calibration.matchesBathroom(snapshot: merged) {
                return .failed(merged, reason: "Bathroom signature matched. The shield should stay on.")
            }
            return .passed(merged)

        case .failed, .unavailable:
            return snapshotResult
        }
    }

    private func fetchNativeWifiForSnapshot() async -> NativeWiFiSnapshot? {
        #if targetEnvironment(simulator)
        return NativeWiFiSnapshot(
            ssid: "SimulatorWiFi",
            bssid: "aa:bb:cc:dd:ee:ff",
            signalStrength: 0.72,
            capturedAt: .now
        )
        #else
        await NativeWiFiReader.fetchCurrent()
        #endif
    }

    // MARK: - Simulator mock

    #if targetEnvironment(simulator)
    private func mockSnapshotForSimulatorTesting() async -> VerificationOutcome {
        isScanning = true
        scanProgress = 0
        liveDebug = ScanLiveDebug(networkPathSummary: "Simulator (mock sensors)", nativeWifiSummary: "72% · SimulatorWiFi")
        defer {
            isScanning = false
            scanProgress = 0
        }
        for step in 1 ... 100 {
            try? await Task.sleep(for: .milliseconds(100))
            scanProgress = Double(step) / 100.0
            liveDebug.secondsElapsed = Double(step) / 10.0
            liveDebug.magnetometerMicroteslas = 48 + Double(step % 5)
            liveDebug.pitchDegrees = 42
            liveDebug.pressureHectopascals = 1013.2 + Double(step) * 0.001
            liveDebug.sampleCountMag = step
            liveDebug.sampleCountPressure = step
        }
        let nativeWifi = NativeWiFiSnapshot(
            ssid: "SimulatorWiFi",
            bssid: "aa:bb:cc:dd:ee:ff",
            signalStrength: 0.72,
            capturedAt: .now
        )
        return .passed(VerificationSnapshot(
            magneticMagnitude: 50,
            pitchDegrees: 42,
            pressureHectopascals: 1013.25,
            nativeWifi: nativeWifi
        ))
    }
    #endif
}
