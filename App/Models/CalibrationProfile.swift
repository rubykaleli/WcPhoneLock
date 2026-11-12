import Foundation

struct VerificationSnapshot: Codable {
    let capturedAt: Date
    let magneticMagnitude: Double
    let pitchDegrees: Double
    let pressureHectopascals: Double?
    let wifiDbm: Double?
    let wifiReading: ShortcutWiFiReading?
    let nativeWifi: NativeWiFiSnapshot?
    let roomLabel: String?

    init(
        capturedAt: Date = .now,
        magneticMagnitude: Double,
        pitchDegrees: Double,
        pressureHectopascals: Double?,
        wifiDbm: Double? = nil,
        wifiReading: ShortcutWiFiReading? = nil,
        nativeWifi: NativeWiFiSnapshot? = nil,
        roomLabel: String? = nil
    ) {
        self.capturedAt = capturedAt
        self.magneticMagnitude = magneticMagnitude
        self.pitchDegrees = pitchDegrees
        self.pressureHectopascals = pressureHectopascals
        self.wifiDbm = wifiDbm
        self.wifiReading = wifiReading
        self.nativeWifi = nativeWifi
        self.roomLabel = roomLabel
    }

    /// Prefer Shortcuts (dBm / Mbps) when present — that is what you care about for room signal.
    var wifiSummary: String {
        if let wifiReading {
            return wifiReading.shortSummary
        }
        if let nativeWifi {
            return nativeWifi.shortSummary
        }
        return "No Wi-Fi"
    }

    /// Merges the latest Shortcuts import into this scan so bathroom matching can use dBm / BSSID.
    func mergingShortcutWifi(_ reading: ShortcutWiFiReading?, roomLabel: String? = nil) -> VerificationSnapshot {
        let resolvedLabel = roomLabel ?? self.roomLabel
        guard let reading else {
            return VerificationSnapshot(
                capturedAt: capturedAt,
                magneticMagnitude: magneticMagnitude,
                pitchDegrees: pitchDegrees,
                pressureHectopascals: pressureHectopascals,
                wifiDbm: wifiDbm,
                wifiReading: nil,
                nativeWifi: nativeWifi,
                roomLabel: resolvedLabel
            )
        }
        return VerificationSnapshot(
            capturedAt: capturedAt,
            magneticMagnitude: magneticMagnitude,
            pitchDegrees: pitchDegrees,
            pressureHectopascals: pressureHectopascals,
            wifiDbm: reading.dbm,
            wifiReading: reading,
            nativeWifi: nativeWifi,
            roomLabel: resolvedLabel
        )
    }
}

struct CalibrationProfile: Codable {
    var safeZoneSamples: [VerificationSnapshot] = []
    var bathroomSamples: [VerificationSnapshot] = []
    var magneticTolerance: Double = 5
    /// Shortcuts RSSI / dBm comparison (e.g. −58 vs −60). Optional for older saved profiles.
    var wifiDbmTolerance: Double?
    /// `NEHotspotNetwork` normalized strength 0…1.
    var wifiSignalTolerance: Double = 0.15
    var minimumPressureDelta: Double = 0.02

    static let `default` = CalibrationProfile()

    var isReady: Bool {
        !safeZoneSamples.isEmpty && !bathroomSamples.isEmpty
    }

    /// True if bathroom samples were saved with Shortcuts Wi‑Fi — verification must merge a fresh `pooplock://wifi` import.
    var bathroomRequiresShortcutWifi: Bool {
        bathroomSamples.contains { $0.wifiReading != nil }
    }

    func matchesBathroom(snapshot: VerificationSnapshot) -> Bool {
        guard !bathroomSamples.isEmpty else {
            return false
        }

        let magneticMatch = bathroomSamples.contains { sample in
            abs(snapshot.magneticMagnitude - sample.magneticMagnitude) <= magneticTolerance
        }

        let wifiMatch = evaluateWifiMatch(snapshot: snapshot)

        let validSafePressures = safeZoneSamples.compactMap(\.pressureHectopascals)
        let baselinePressure = validSafePressures.isEmpty ? nil : validSafePressures.reduce(0, +) / Double(validSafePressures.count)

        let pressureMatch: Bool? = {
            guard let baseline = baselinePressure,
                  let measured = snapshot.pressureHectopascals
            else { return nil }
            return (measured - baseline) >= minimumPressureDelta
        }()

        switch wifiMatch {
        case .matched:
            if let pressureMatch {
                return magneticMatch && pressureMatch
            }
            return magneticMatch
        case .noMatch:
            return false
        case .unavailable:
            if let pressureMatch {
                return magneticMatch && pressureMatch
            }
            return magneticMatch
        }
    }

    private enum WifiMatchResult {
        case matched, noMatch, unavailable
    }

    /// Uses Shortcuts Wi‑Fi when bathroom was calibrated with it; otherwise on‑device `NEHotspotNetwork` snapshot.
    private func evaluateWifiMatch(snapshot: VerificationSnapshot) -> WifiMatchResult {
        let bathroomShortcut = bathroomSamples.compactMap(\.wifiReading)
        if !bathroomShortcut.isEmpty {
            guard let live = snapshot.wifiReading else {
                return .unavailable
            }
            return evaluateShortcutWifiMatch(live: live, bathroomSamples: bathroomShortcut)
        }

        let bathroomNative = bathroomSamples.compactMap(\.nativeWifi)
        if !bathroomNative.isEmpty {
            guard let live = snapshot.nativeWifi else {
                return .unavailable
            }
            return evaluateNativeWifiStrengthMatch(live: live, bathroomSamples: bathroomNative)
        }

        return .unavailable
    }

    private func evaluateShortcutWifiMatch(live: ShortcutWiFiReading, bathroomSamples: [ShortcutWiFiReading]) -> WifiMatchResult {
        let tol = wifiDbmTolerance ?? 12
        let dbmMatch = bathroomSamples.contains { sample in
            abs(live.dbm - sample.dbm) <= tol
        }
        guard dbmMatch else { return .noMatch }

        let bathroomBSSIDs = Set(bathroomSamples.compactMap { $0.bssid?.lowercased() })
        if let liveBSSID = live.bssid?.lowercased(), !bathroomBSSIDs.isEmpty {
            if !bathroomBSSIDs.contains(liveBSSID) {
                return .noMatch
            }
        }

        return .matched
    }

    private func evaluateNativeWifiStrengthMatch(live: NativeWiFiSnapshot, bathroomSamples: [NativeWiFiSnapshot]) -> WifiMatchResult {
        let signalMatch = bathroomSamples.contains { sample in
            abs(live.signalStrength - sample.signalStrength) <= wifiSignalTolerance
        }
        guard signalMatch else { return .noMatch }

        let bathroomBSSIDs = Set(bathroomSamples.compactMap { $0.bssid?.lowercased() })
        if let liveBSSID = live.bssid?.lowercased(), !bathroomBSSIDs.isEmpty {
            if !bathroomBSSIDs.contains(liveBSSID) {
                return .noMatch
            }
        }

        return .matched
    }
}
