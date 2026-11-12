import Foundation

#if canImport(ManagedSettings)
import ManagedSettings
#endif

#if canImport(DeviceActivity)
import DeviceActivity
#endif

enum ProtectionIdentifiers {
    static let managedSettingsStoreNameRawValue = "restroom-restriction"
    static let unlockMonitorNameRawValue = "restroom-unlock-session"

    #if canImport(ManagedSettings)
    static func managedSettingsStoreName() -> ManagedSettingsStore.Name {
        ManagedSettingsStore.Name(managedSettingsStoreNameRawValue)
    }
    #endif

    #if canImport(DeviceActivity)
    static func unlockMonitorName() -> DeviceActivityName {
        DeviceActivityName(unlockMonitorNameRawValue)
    }
    #endif
}
