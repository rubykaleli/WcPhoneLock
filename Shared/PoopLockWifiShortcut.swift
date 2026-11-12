import Foundation

/// WiFiMan-style: the app runs `shortcuts://run-shortcut?name=…` — that name must exist in the Shortcuts app.
enum PoopLockWifiShortcut {
    /// Must match Shortcuts **exactly** (iOS treats `PoopLockWIFI` and `PoopLockWiFi` as different names). No spaces.
    static let defaultName = "PoopLockWIFI"

    /// **WiFiman-style one-tap install:** an **https://** URL to a `.shortcut` file or an iCloud Shortcuts share link.
    ///
    /// Examples (maintainer sets **one** of these approaches):
    /// - iCloud: Shortcuts → your shortcut → ••• → Share → Copy Link (`https://www.icloud.com/shortcuts/...`)
    /// - GitHub Raw: push `Shortcuts/PoopLockWIFI.shortcut` to the repo, then use the **Raw** file URL, e.g.
    ///   `https://raw.githubusercontent.com/OWNER/REPO/BRANCH/Shortcuts/PoopLockWIFI.shortcut`
    ///
    /// Leave empty to rely on a **bundled** `PoopLockWIFI.shortcut` in the app (see `bundledShortcutResourceName`) or manual recipe.
    static let officialImportURL = ""

    /// If you add `PoopLockWIFI.shortcut` to the Xcode target (Copy Bundle Resources), the Install sheet can import or share it.
    static let bundledShortcutResourceName = "PoopLockWIFI"
    static let bundledShortcutExtension = "shortcut"

    /// `Bundle.main` URL when the `.shortcut` file is packaged with the app.
    static var bundledShortcutFileURL: URL? {
        Bundle.main.url(forResource: bundledShortcutResourceName, withExtension: bundledShortcutExtension)
    }

    /// WiFiman’s App Store flow installs a shortcut usually titled **WiFiman**. PoopLock can call `run-shortcut?name=…` for debugging only — that shortcut does **not** send `pooplock://wifi?…` (it targets WiFiman).
    static let wifimanShortcutNameForTesting = "WiFiman"

    /// Some devices show **Wifiman** (different capitalization). Must match Shortcuts ••• → Name exactly.
    static let wifimanShortcutAlternateNameForTesting = "Wifiman"
}
