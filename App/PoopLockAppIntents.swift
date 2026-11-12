import AppIntents
import CoreLocation
import Foundation

/// WiFiman-style **App Intent**: Shortcuts can run PoopLock’s own code (here, `NEHotspotNetwork`) instead of relying only on “Get Network Details” + URLs.
/// Users add this action from Shortcuts → Add Action → search “PoopLock” (after installing the app).
struct GetPoopLockWiFiSnapshotIntent: AppIntent {
    static let title: LocalizedStringResource = "Get PoopLock Wi‑Fi snapshot"
    static let description = IntentDescription("Reads SSID, BSSID, and normalized signal using PoopLock’s native Wi‑Fi APIs.")
    /// Opening the app once after install registers App Intents; keeping this false avoids forcing a foreground launch on every shortcut run.
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // Apple treats Wi‑Fi identifiers as sensitive; NEHotspotNetwork often returns nil until Location is authorized.
        let locationOK: Bool = {
            switch CLLocationManager().authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                return true
            default:
                return false
            }
        }()
        guard locationOK else {
            return .result(
                value: "Location permission is required for Wi‑Fi network details. Open PoopLock once, allow Location, then run this action again."
            )
        }

        guard let snap = await NativeWiFiReader.fetchCurrent() else {
            return .result(value: "No Wi‑Fi data (not connected, denied, simulator, or Precise Location off — check Settings → Privacy → Location → PoopLock.)")
        }
        let ssid = snap.ssid ?? "—"
        let bssid = snap.bssid ?? "—"
        let pct = String(format: "%.0f%%", snap.signalStrength * 100)
        return .result(value: "SSID: \(ssid) | BSSID: \(bssid) | signal: \(pct)")
    }
}

enum PoopLockAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetPoopLockWiFiSnapshotIntent(),
            phrases: [
                "Wi‑Fi snapshot in \(.applicationName)",
                "Read Wi‑Fi with \(.applicationName)"
            ],
            shortTitle: "Wi‑Fi snapshot",
            systemImageName: "wifi"
        )
    }
}
