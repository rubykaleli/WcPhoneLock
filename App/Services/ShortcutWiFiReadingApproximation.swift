import Foundation

extension ShortcutWiFiReading {
    /// When Shortcuts never opens `pooplock://wifi?…`, map `NEHotspotNetwork` data into the same shape as a URL import so verification can still run.
    /// dBm is **approximate** (signal strength is normalized 0…1 on-device).
    static func approximated(from native: NativeWiFiSnapshot) -> ShortcutWiFiReading {
        let dbm = -30.0 - (1.0 - native.signalStrength) * 55.0
        return ShortcutWiFiReading(dbm: dbm, ssid: native.ssid, bssid: native.bssid)
    }
}
