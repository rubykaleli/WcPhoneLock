import UIKit

/// Opens the Shortcuts app. PoopLock cannot install shortcuts silently; Apple always shows a confirmation.
@MainActor
enum ShortcutOpener {
    /// Opens the main Shortcuts screen so you can create/rename a shortcut.
    static func openShortcutsApp() {
        guard let url = URL(string: "shortcuts://") else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    /// Exact URL PoopLock will open (for debugging / support). Uses `URLComponents` so `name` is encoded correctly.
    static func runShortcutURLString(forShortcutName name: String) -> String? {
        let trimmed = normalizedShortcutDisplayName(name)
        guard !trimmed.isEmpty else { return nil }
        return runShortcutComponents(for: trimmed)?.url?.absoluteString
    }

    /// Runs an existing shortcut: `shortcuts://run-shortcut?name=...`
    static func runShortcut(named name: String) {
        let normalized = normalizedShortcutDisplayName(name)
        guard !normalized.isEmpty else { return }
        guard let url = runShortcutComponents(for: normalized)?.url else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    /// Strips whitespace and invisible characters that break name matching in Shortcuts.
    static func normalizedShortcutDisplayName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{200B}", with: "")
            .replacingOccurrences(of: "\u{FEFF}", with: "")
    }

    private static func runShortcutComponents(for trimmedName: String) -> URLComponents? {
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "run-shortcut"
        components.queryItems = [
            URLQueryItem(name: "name", value: trimmedName)
        ]
        return components
    }

    /// Copies a **bundled** `PoopLockWIFI.shortcut` from the app bundle to Caches and opens `shortcuts://import-shortcut?url=file://…`.
    /// If Shortcuts rejects `file://` on your iOS version, use **Share** (see Install sheet) instead.
    @discardableResult
    static func importBundledShortcutFromAppBundle() -> Bool {
        guard let src = PoopLockWifiShortcut.bundledShortcutFileURL else { return false }
        let dest = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PoopLockWIFI-import.shortcut", isDirectory: false)
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: src, to: dest)
        } catch {
            return false
        }
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?#")
        guard let encoded = dest.absoluteString.addingPercentEncoding(withAllowedCharacters: allowed) else { return false }
        guard let importURL = URL(string: "shortcuts://import-shortcut?url=\(encoded)") else { return false }
        UIApplication.shared.open(importURL, options: [:], completionHandler: nil)
        return true
    }

    /// Same pattern as WIFIman: opens Shortcuts to **import** a shared shortcut from the web.
    /// Pass the **iCloud link** you get in Shortcuts → shortcut → Share → **Copy Link**
    /// (looks like `https://www.icloud.com/shortcuts/...`).
    ///
    /// The user taps **Add Shortcut** once — they do not build steps by hand.
    static func importShortcut(fromSharedLink urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Prefer Apple’s import flow (works for iCloud shortcut links and HTTPS-hosted `.shortcut` files).
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?#")
        guard let encodedParam = trimmed.addingPercentEncoding(withAllowedCharacters: allowed) else { return }
        guard let importURL = URL(string: "shortcuts://import-shortcut?url=\(encodedParam)") else { return }

        UIApplication.shared.open(importURL, options: [:], completionHandler: nil)
    }

    /// If the import scheme fails, you can fall back to opening the link in Safari (user taps Add on Apple’s page).
    static func openInSafari(urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme == "http" || url.scheme == "https" else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
