import DeviceActivity
import Foundation

@MainActor
final class UnlockScheduleManager: UnlockSessionScheduling {
    private let center = DeviceActivityCenter()
    private let calendar = Calendar.current

    func scheduleUnlockSession(until unlockUntil: Date) {
        guard !BuildFlavor.isLocalTesting else {
            return
        }

        let startDate = Date()
        let adjustedEndDate = max(unlockUntil, startDate.addingTimeInterval(60))

        let startComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: startDate
        )
        let endComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: adjustedEndDate
        )

        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false
        )

        do {
            center.stopMonitoring([ProtectionIdentifiers.unlockMonitorName()])
            try center.startMonitoring(
                ProtectionIdentifiers.unlockMonitorName(),
                during: schedule
            )
        } catch {
            AppGroupStore.appendEvent(
                VerificationEvent(
                    title: "Unlock scheduling failed",
                    detail: error.localizedDescription
                )
            )
        }
    }

    func clearUnlockSession() {
        guard !BuildFlavor.isLocalTesting else {
            return
        }

        center.stopMonitoring([ProtectionIdentifiers.unlockMonitorName()])
    }
}
