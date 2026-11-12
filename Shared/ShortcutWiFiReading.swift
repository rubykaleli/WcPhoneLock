import Foundation

/// Wi‑Fi signal data passed into PoopLock from the Shortcuts app (or any app that opens our URL).
/// PoopLock also reads basic Wi‑Fi on-device via `NEHotspotNetwork`; Shortcuts can add dBm / Mbps and other fields.
struct ShortcutWiFiReading: Codable, Equatable {
    var dbm: Double
    var ssid: String?
    var bssid: String?
    var rxMbps: Double?
    var txMbps: Double?
    var noiseDbm: Double?
    var channel: String?
    var standard: String?
    var receivedAt: Date

    init(
        dbm: Double,
        ssid: String? = nil,
        bssid: String? = nil,
        rxMbps: Double? = nil,
        txMbps: Double? = nil,
        noiseDbm: Double? = nil,
        channel: String? = nil,
        standard: String? = nil,
        receivedAt: Date = .now
    ) {
        self.dbm = dbm
        self.ssid = ssid
        self.bssid = bssid
        self.rxMbps = rxMbps
        self.txMbps = txMbps
        self.noiseDbm = noiseDbm
        self.channel = channel
        self.standard = standard
        self.receivedAt = receivedAt
    }

    var shortSummary: String {
        var parts = [String(format: "%.0f dBm", dbm)]
        if let ssid, !ssid.isEmpty {
            parts.append(ssid)
        }
        return parts.joined(separator: " · ")
    }

    var metricsSummary: String? {
        var parts: [String] = []
        if let rxMbps {
            parts.append(String(format: "RX %.0f", rxMbps))
        }
        if let txMbps {
            parts.append(String(format: "TX %.0f", txMbps))
        }
        if let noiseDbm {
            parts.append(String(format: "Noise %.0f", noiseDbm))
        }
        if let channel, !channel.isEmpty {
            parts.append("Ch \(channel)")
        }
        if let standard, !standard.isEmpty {
            parts.append(standard)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var identitySummary: String? {
        var parts: [String] = []
        if let ssid, !ssid.isEmpty {
            parts.append(ssid)
        }
        if let bssid, !bssid.isEmpty {
            parts.append(bssid)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

enum PoopLockURLHandler {
    /// Expects:
    /// `pooplock://wifi?dbm=-59`
    /// `pooplock://wifi?rssi=-59&ssid=Home`
    /// `pooplock://wifi?dbm=-59&ssid=Home&bssid=aa:bb:cc:dd:ee:ff&rxMbps=866&txMbps=780&noise=-92&channel=44&standard=Wi-Fi%206`
    static func parseWiFiImport(_ url: URL) -> ShortcutWiFiReading? {
        guard url.scheme?.lowercased() == "pooplock" else { return nil }
        guard let host = url.host?.lowercased(), host == "wifi" else { return nil }

        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
            return nil
        }

        let dbmValue = doubleValue(in: items, names: ["dbm", "rssi"])

        guard let dbm = dbmValue else { return nil }

        return ShortcutWiFiReading(
            dbm: dbm,
            ssid: stringValue(in: items, names: ["ssid", "networkname", "network_name"]),
            bssid: stringValue(in: items, names: ["bssid"]),
            rxMbps: doubleValue(in: items, names: ["rxmbps", "rx", "rxrate", "rx_rate", "receiverate", "receive_rate"]),
            txMbps: doubleValue(in: items, names: ["txmbps", "tx", "txrate", "tx_rate", "transmitrate", "transmit_rate"]),
            noiseDbm: doubleValue(in: items, names: ["noise", "noisedbm", "noise_dbm"]),
            channel: stringValue(in: items, names: ["channel", "channelnumber", "channel_number"]),
            standard: stringValue(in: items, names: ["standard", "wifistandard", "wifi_standard"])
        )
    }

    private static func doubleValue(in items: [URLQueryItem], names: [String]) -> Double? {
        for name in names {
            if let value = stringValue(in: items, names: [name]), let number = Double(value) {
                return number
            }
        }
        return nil
    }

    private static func stringValue(in items: [URLQueryItem], names: [String]) -> String? {
        for name in names {
            if let rawValue = items.first(where: { $0.name.lowercased() == name })?.value
            {
                let decodedValue = rawValue.removingPercentEncoding?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !decodedValue.isEmpty {
                    return decodedValue
                }
            }
        }
        return nil
    }
}
