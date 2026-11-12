import Foundation

#if canImport(FamilyControls)
import FamilyControls
#endif

struct ProtectionSnapshot {
    let settings: AppSettings
    let isInsideHome: Bool
    let unlockUntil: Date?

    var shouldShieldNow: Bool {
        guard settings.protectionEnabled else {
            return false
        }

        guard isInsideHome else {
            return false
        }

        guard let unlockUntil else {
            return true
        }

        return unlockUntil <= .now
    }
}

enum ProtectionSnapshotLoader {
    static func load() -> ProtectionSnapshot {
        var settings = AppGroupStore.loadValue(AppSettings.self, forKey: SharedKeys.settings) ?? .default
        if settings.migrateLegacyWifiShortcutNameIfNeeded() {
            AppGroupStore.saveValue(settings, forKey: SharedKeys.settings)
        }
        let isInsideHome = AppGroup.sharedDefaults.bool(forKey: SharedKeys.isInsideHome)
        let unlockUntil = AppGroup.sharedDefaults.object(forKey: SharedKeys.unlockUntil) as? Date

        return ProtectionSnapshot(
            settings: settings,
            isInsideHome: isInsideHome,
            unlockUntil: unlockUntil
        )
    }
}
