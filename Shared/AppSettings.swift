import CoreLocation
import Foundation

struct StoredCoordinate: Codable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct AppSettings: Codable {
    var protectionEnabled = true
    var strictMode = false
    var unlockDurationMinutes = 20
    var homeCoordinate: StoredCoordinate?
    var localTestingForceHome = false
    /// Fixed default like WiFiMan — user never has to name anything unless they rename the shortcut.
    var wifiShortcutName = PoopLockWifiShortcut.defaultName
    /// iCloud **Share link** to import the shortcut (Shortcuts → … → Share → Copy Link). Same idea as WIFIman’s “get shortcut” button.
    var wifiShortcutImportURL = ""
    /// If the Wi‑Fi shortcut never calls `pooplock://wifi?…`, build a comparable reading from on-device Wi‑Fi (less accurate than Shortcuts).
    var useNativeWifiFallbackWhenShortcutMissing = true
    /// `true` = legacy flow: open Shortcuts before each calibration/verification scan. `nil`/`false` = skip Shortcuts; scans use on‑device Wi‑Fi only (no shortcut file needed).
    var openShortcutsBeforeWifiScans: Bool?

    static let `default` = AppSettings()

    /// Only explicit `true` opens Shortcuts first. Default is off so PoopLock works without any shortcut.
    var shouldOpenShortcutsBeforeScan: Bool {
        openShortcutsBeforeWifiScans == true
    }

    /// Migrates older stored names to the current default `PoopLockWIFI` so Settings matches the recipe and `run-shortcut`.
    mutating func migrateLegacyWifiShortcutNameIfNeeded() -> Bool {
        let trimmed = wifiShortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
        let legacy: Set<String> = ["PoopLock WiFi", "PoopLockWiFi"]
        guard legacy.contains(trimmed) else { return false }
        wifiShortcutName = PoopLockWifiShortcut.defaultName
        return true
    }
}
