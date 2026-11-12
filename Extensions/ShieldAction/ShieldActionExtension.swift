import ManagedSettings
import UserNotifications

final class RestroomShieldActionExtension: ShieldActionDelegate {
    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handleAction(action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handleAction(action, completionHandler: completionHandler)
    }

    private func handleAction(
        _ action: ShieldAction,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            AppGroup.sharedDefaults.set(true, forKey: SharedKeys.pendingVerification)
            AppGroupStore.appendEvent(
                VerificationEvent(
                    title: "Shield button pressed",
                    detail: "User asked to verify room from the shield."
                )
            )
            scheduleVerificationPromptNotification()
            completionHandler(.close)

        case .secondaryButtonPressed:
            completionHandler(.close)

        case .firstSecondarySubmenuItemPressed,
             .secondSecondarySubmenuItemPressed,
             .thirdSecondarySubmenuItemPressed:
            completionHandler(.close)

        @unknown default:
            completionHandler(.none)
        }
    }

    private func scheduleVerificationPromptNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Verify room to unlock"
        content.body = "Open Restroom Restriction and run a room scan."
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
}
