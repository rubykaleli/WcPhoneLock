import ManagedSettings
import ManagedSettingsUI
import UIKit

final class RestroomShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        baseConfiguration(
            title: "Home Protection Is On",
            subtitle: "Open Restroom Restriction to verify that you are not in the bathroom, then unlock this app for a short session."
        )
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        baseConfiguration(
            title: "Website Blocked At Home",
            subtitle: "Verify your room in Restroom Restriction before this site can be used."
        )
    }

    private func baseConfiguration(title: String, subtitle: String) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemThinMaterialDark,
            backgroundColor: UIColor.systemIndigo.withAlphaComponent(0.9),
            icon: UIImage(systemName: "toilet.fill"),
            title: ShieldConfiguration.Label(text: title, color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: .white),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Keep Blocked", color: .white),
            primaryButtonBackgroundColor: UIColor.systemRed,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Dismiss", color: .white)
        )
    }
}
