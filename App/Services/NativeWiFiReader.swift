import Foundation
import NetworkExtension

struct NativeWiFiSnapshot: Codable, Equatable {
    let ssid: String?
    let bssid: String?
    /// Normalized signal strength 0.0 (weakest) to 1.0 (strongest).
    let signalStrength: Double
    let capturedAt: Date

    var shortSummary: String {
        let signal = String(format: "%.0f%%", signalStrength * 100)
        if let ssid, !ssid.isEmpty {
            return "\(signal) · \(ssid)"
        }
        return signal
    }
}

enum NativeWiFiReader {
    static func fetchCurrent() async -> NativeWiFiSnapshot? {
        await withCheckedContinuation { continuation in
            NEHotspotNetwork.fetchCurrent { network in
                guard let network else {
                    continuation.resume(returning: nil)
                    return
                }
                let snapshot = NativeWiFiSnapshot(
                    ssid: network.ssid,
                    bssid: network.bssid,
                    signalStrength: network.signalStrength,
                    capturedAt: .now
                )
                continuation.resume(returning: snapshot)
            }
        }
    }
}
