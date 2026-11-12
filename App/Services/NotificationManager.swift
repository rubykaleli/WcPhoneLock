import Foundation
import UserNotifications

@MainActor
final class NotificationManager: NotificationScheduling {
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func scheduleUnlockExpiryNotification(at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Bathroom protection is back on"
        content.body = "Your temporary unlock window has ended."
        content.sound = .default

        let interval = max(date.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: "unlock-expiry",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["unlock-expiry"])
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleVerificationPromptNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Verify room to unlock"
        content.body = "Open Restroom Restriction and run a room scan to unlock your apps."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "verification-prompt",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["verification-prompt"])
        UNUserNotificationCenter.current().add(request)
    }

    func cancelScheduledNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["unlock-expiry", "verification-prompt"]
        )
    }
}
