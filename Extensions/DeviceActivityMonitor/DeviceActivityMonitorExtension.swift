import DeviceActivity
import ManagedSettings

final class RestroomDeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let managedSettingsStore = ManagedSettingsStore(named: ProtectionIdentifiers.managedSettingsStoreName())

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        synchronizeShield(for: activity, source: "Unlock session started")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        AppGroup.sharedDefaults.removeObject(forKey: SharedKeys.unlockUntil)
        _ = AppGroupStore.finishActiveUnlockSession(reason: .expired)
        synchronizeShield(for: activity, source: "Unlock session ended")
    }

    private func synchronizeShield(for activity: DeviceActivityName, source: String) {
        guard activity.rawValue == ProtectionIdentifiers.unlockMonitorNameRawValue else {
            return
        }

        let snapshot = ProtectionSnapshotLoader.load()

        if snapshot.shouldShieldNow {
            let selection = AppGroupStore.loadSelection()
            managedSettingsStore.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
            managedSettingsStore.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
            AppGroupStore.appendEvent(
                VerificationEvent(
                    title: source,
                    detail: "Home protection reapplied by DeviceActivity."
                )
            )
        } else {
            managedSettingsStore.clearAllSettings()
            AppGroupStore.appendEvent(
                VerificationEvent(
                    title: source,
                    detail: "No relock needed because protection is off or the user is not home."
                )
            )
        }
    }
}
