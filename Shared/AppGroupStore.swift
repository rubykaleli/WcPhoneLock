import Foundation

#if canImport(FamilyControls)
import FamilyControls
#endif

enum AppGroup {
    #if LOCAL_TESTING
    /// Personal/free Apple Developer accounts cannot provision App Groups. Local test builds use standard defaults.
    static var sharedDefaults: UserDefaults { .standard }
    #else
    static let suiteName = "group.com.rubykaleli.RestroomRestriction"
    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
    #endif
}

enum SharedKeys {
    static let settings = "settings"
    static let calibration = "calibration"
    static let selection = "selection"
    static let unlockUntil = "unlockUntil"
    static let isInsideHome = "isInsideHome"
    static let pendingVerification = "pendingVerification"
    static let recentEvents = "recentEvents"
    static let activeUnlockSession = "activeUnlockSession"
    static let unlockSessionHistory = "unlockSessionHistory"
    /// Last Wi‑Fi reading imported via Shortcuts (`pooplock://wifi?...`).
    static let shortcutWifiReading = "shortcutWifiReading"
}

struct VerificationEvent: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let title: String
    let detail: String

    init(id: UUID = UUID(), timestamp: Date = .now, title: String, detail: String) {
        self.id = id
        self.timestamp = timestamp
        self.title = title
        self.detail = detail
    }
}

enum UnlockSessionEndReason: String, Codable {
    case expired
    case leftHome
    case protectionDisabled
    case replaced
    case cancelled

    var label: String {
        switch self {
        case .expired:
            "Expired"
        case .leftHome:
            "Left Home"
        case .protectionDisabled:
            "Protection Disabled"
        case .replaced:
            "Replaced"
        case .cancelled:
            "Cancelled"
        }
    }
}

struct UnlockSessionRecord: Codable, Identifiable {
    let id: UUID
    let startedAt: Date
    var endedAt: Date?
    let unlockUntil: Date
    let magneticMagnitude: Double
    let strictMode: Bool
    var endReason: UnlockSessionEndReason?

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil,
        unlockUntil: Date,
        magneticMagnitude: Double,
        strictMode: Bool,
        endReason: UnlockSessionEndReason? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.unlockUntil = unlockUntil
        self.magneticMagnitude = magneticMagnitude
        self.strictMode = strictMode
        self.endReason = endReason
    }
}

enum AppGroupStore {
    private static let encoder = PropertyListEncoder()
    private static let decoder = PropertyListDecoder()

    static func loadValue<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = AppGroup.sharedDefaults.data(forKey: key) else {
            return nil
        }

        return try? decoder.decode(T.self, from: data)
    }

    static func saveValue<T: Codable>(_ value: T, forKey key: String) {
        guard let data = try? encoder.encode(value) else {
            return
        }

        AppGroup.sharedDefaults.set(data, forKey: key)
    }

    static func removeValue(forKey key: String) {
        AppGroup.sharedDefaults.removeObject(forKey: key)
    }

    static func loadEvents() -> [VerificationEvent] {
        loadValue([VerificationEvent].self, forKey: SharedKeys.recentEvents) ?? []
    }

    static func appendEvent(_ event: VerificationEvent) {
        var events = loadEvents()
        events.insert(event, at: 0)
        events = Array(events.prefix(30))
        saveValue(events, forKey: SharedKeys.recentEvents)
    }

    static func loadUnlockHistory() -> [UnlockSessionRecord] {
        loadValue([UnlockSessionRecord].self, forKey: SharedKeys.unlockSessionHistory) ?? []
    }

    static func loadActiveUnlockSession() -> UnlockSessionRecord? {
        loadValue(UnlockSessionRecord.self, forKey: SharedKeys.activeUnlockSession)
    }

    static func beginUnlockSession(until unlockUntil: Date, magneticMagnitude: Double, strictMode: Bool) {
        if loadActiveUnlockSession() != nil {
            _ = finishActiveUnlockSession(reason: .replaced)
        }

        let record = UnlockSessionRecord(
            unlockUntil: unlockUntil,
            magneticMagnitude: magneticMagnitude,
            strictMode: strictMode
        )

        saveValue(record, forKey: SharedKeys.activeUnlockSession)
    }

    @discardableResult
    static func finishActiveUnlockSession(
        reason: UnlockSessionEndReason,
        endedAt: Date = .now
    ) -> UnlockSessionRecord? {
        guard var record = loadActiveUnlockSession() else {
            return nil
        }

        record.endedAt = endedAt
        record.endReason = reason

        var history = loadUnlockHistory()
        history.insert(record, at: 0)
        history = Array(history.prefix(50))
        saveValue(history, forKey: SharedKeys.unlockSessionHistory)
        removeValue(forKey: SharedKeys.activeUnlockSession)

        return record
    }

    #if canImport(FamilyControls)
    static func loadSelection() -> FamilyActivitySelection {
        loadValue(FamilyActivitySelection.self, forKey: SharedKeys.selection) ?? FamilyActivitySelection()
    }

    static func saveSelection(_ selection: FamilyActivitySelection) {
        saveValue(selection, forKey: SharedKeys.selection)
    }
    #endif
}
