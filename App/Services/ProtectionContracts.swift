import FamilyControls
import Foundation
import ManagedSettings

@MainActor
protocol ShieldControlling {
    /// Applies shields for the supplied selection and returns an updated status message.
    func applyShield(selection: FamilyActivitySelection) -> String
    func clearShield()
}

enum ShieldControllerFactory {
    @MainActor
    static func makeDefault() -> any ShieldControlling {
        #if LOCAL_TESTING
        return SimulatedShieldController()
        #else
        return ManagedSettingsShieldController()
        #endif
    }
}

#if !LOCAL_TESTING
@MainActor
final class ManagedSettingsShieldController: ShieldControlling {
    private let store = ManagedSettingsStore(named: ProtectionIdentifiers.managedSettingsStoreName())

    func applyShield(selection: FamilyActivitySelection) -> String {
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        return "Home protection is armed."
    }

    func clearShield() {
        store.clearAllSettings()
    }
}
#endif

@MainActor
final class SimulatedShieldController: ShieldControlling {
    func applyShield(selection: FamilyActivitySelection) -> String {
        "Local testing build: simulated home shield is armed."
    }

    func clearShield() {}
}

@MainActor
protocol NotificationScheduling {
    func requestAuthorization()
    func scheduleUnlockExpiryNotification(at date: Date)
    func scheduleVerificationPromptNotification()
    func cancelScheduledNotifications()
}

@MainActor
protocol UnlockSessionScheduling {
    func scheduleUnlockSession(until unlockUntil: Date)
    func clearUnlockSession()
}

@MainActor
protocol ProtectionStoring {
    func loadSettings() -> AppSettings
    func saveSettings(_ settings: AppSettings)
    func loadCalibration() -> CalibrationProfile
    func saveCalibration(_ calibration: CalibrationProfile)
    func loadUnlockUntil() -> Date?
    func saveUnlockUntil(_ date: Date?)
    func loadPendingVerification() -> Bool
    func savePendingVerification(_ pending: Bool)
    func saveIsInsideHome(_ isInsideHome: Bool)
    func loadShortcutWifiReading() -> ShortcutWiFiReading?
    func saveShortcutWifiReading(_ reading: ShortcutWiFiReading)
    func loadEvents() -> [VerificationEvent]
    func appendEvent(_ event: VerificationEvent)
    func loadUnlockHistory() -> [UnlockSessionRecord]
    func beginUnlockSession(until unlockUntil: Date, magneticMagnitude: Double, strictMode: Bool)
    @discardableResult
    func finishActiveUnlockSession(reason: UnlockSessionEndReason) -> UnlockSessionRecord?
}

@MainActor
struct AppGroupProtectionStore: ProtectionStoring {
    func loadSettings() -> AppSettings {
        var settings = AppGroupStore.loadValue(AppSettings.self, forKey: SharedKeys.settings) ?? .default
        if settings.migrateLegacyWifiShortcutNameIfNeeded() {
            AppGroupStore.saveValue(settings, forKey: SharedKeys.settings)
        }
        return settings
    }

    func saveSettings(_ settings: AppSettings) {
        AppGroupStore.saveValue(settings, forKey: SharedKeys.settings)
    }

    func loadCalibration() -> CalibrationProfile {
        AppGroupStore.loadValue(CalibrationProfile.self, forKey: SharedKeys.calibration) ?? .default
    }

    func saveCalibration(_ calibration: CalibrationProfile) {
        AppGroupStore.saveValue(calibration, forKey: SharedKeys.calibration)
    }

    func loadUnlockUntil() -> Date? {
        AppGroup.sharedDefaults.object(forKey: SharedKeys.unlockUntil) as? Date
    }

    func saveUnlockUntil(_ date: Date?) {
        if let date {
            AppGroup.sharedDefaults.set(date, forKey: SharedKeys.unlockUntil)
        } else {
            AppGroup.sharedDefaults.removeObject(forKey: SharedKeys.unlockUntil)
        }
    }

    func loadPendingVerification() -> Bool {
        AppGroup.sharedDefaults.bool(forKey: SharedKeys.pendingVerification)
    }

    func savePendingVerification(_ pending: Bool) {
        AppGroup.sharedDefaults.set(pending, forKey: SharedKeys.pendingVerification)
    }

    func saveIsInsideHome(_ isInsideHome: Bool) {
        AppGroup.sharedDefaults.set(isInsideHome, forKey: SharedKeys.isInsideHome)
    }

    func loadShortcutWifiReading() -> ShortcutWiFiReading? {
        AppGroupStore.loadValue(ShortcutWiFiReading.self, forKey: SharedKeys.shortcutWifiReading)
    }

    func saveShortcutWifiReading(_ reading: ShortcutWiFiReading) {
        AppGroupStore.saveValue(reading, forKey: SharedKeys.shortcutWifiReading)
    }

    func loadEvents() -> [VerificationEvent] {
        AppGroupStore.loadEvents()
    }

    func appendEvent(_ event: VerificationEvent) {
        AppGroupStore.appendEvent(event)
    }

    func loadUnlockHistory() -> [UnlockSessionRecord] {
        AppGroupStore.loadUnlockHistory()
    }

    func beginUnlockSession(until unlockUntil: Date, magneticMagnitude: Double, strictMode: Bool) {
        AppGroupStore.beginUnlockSession(
            until: unlockUntil,
            magneticMagnitude: magneticMagnitude,
            strictMode: strictMode
        )
    }

    @discardableResult
    func finishActiveUnlockSession(reason: UnlockSessionEndReason) -> UnlockSessionRecord? {
        AppGroupStore.finishActiveUnlockSession(reason: reason)
    }
}

