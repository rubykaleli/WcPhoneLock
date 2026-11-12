import FamilyControls
import Foundation

struct PendingCalibrationScan {
    let isBathroom: Bool
    let roomLabel: String
}

@MainActor
final class ProtectionController: ObservableObject {
    @Published var settings: AppSettings
    @Published var calibration: CalibrationProfile
    @Published var unlockUntil: Date?
    @Published var lastMessage = "Protection is ready."
    @Published var recentEvents: [VerificationEvent]
    @Published var unlockHistory: [UnlockSessionRecord]
    @Published var pendingVerificationRequest: Bool
    @Published var shortcutWifiReading: ShortcutWiFiReading?
    @Published var calibrationScanCompletedSignal = 0
    @Published var pendingCalibrationScan: PendingCalibrationScan?
    @Published var pendingVerificationScan = false

    let screenTimeManager: ScreenTimeManager
    let homeLocationManager: HomeLocationManager
    let verificationManager: RoomVerificationManager

    private let shieldController: any ShieldControlling
    private let store: any ProtectionStoring
    private let unlockScheduleManager: any UnlockSessionScheduling
    private let notificationManager: any NotificationScheduling

    init(
        screenTimeManager: ScreenTimeManager = ScreenTimeManager(),
        homeLocationManager: HomeLocationManager = HomeLocationManager(),
        verificationManager: RoomVerificationManager = RoomVerificationManager(),
        shieldController: (any ShieldControlling)? = nil,
        store: (any ProtectionStoring)? = nil,
        unlockScheduleManager: (any UnlockSessionScheduling)? = nil,
        notificationManager: (any NotificationScheduling)? = nil
    ) {
        let resolvedStore = store ?? AppGroupProtectionStore()
        self.screenTimeManager = screenTimeManager
        self.homeLocationManager = homeLocationManager
        self.verificationManager = verificationManager
        self.shieldController = shieldController ?? ShieldControllerFactory.makeDefault()
        self.store = resolvedStore
        self.unlockScheduleManager = unlockScheduleManager ?? UnlockScheduleManager()
        self.notificationManager = notificationManager ?? NotificationManager()

        let loadedSettings = resolvedStore.loadSettings()
        self.settings = loadedSettings
        self.calibration = resolvedStore.loadCalibration()
        self.unlockUntil = resolvedStore.loadUnlockUntil()
        self.recentEvents = resolvedStore.loadEvents()
        self.unlockHistory = resolvedStore.loadUnlockHistory()
        self.pendingVerificationRequest = resolvedStore.loadPendingVerification()
        self.shortcutWifiReading = resolvedStore.loadShortcutWifiReading()

        homeLocationManager.onHomeStateChanged = { [weak self] _ in
            Task { @MainActor in
                self?.refreshProtectionState()
            }
        }

        resolvedStore.saveIsInsideHome(homeLocationManager.isInsideHome)
        homeLocationManager.startMonitoringHomeRegion(using: loadedSettings.homeCoordinate)
        refreshProtectionState()
    }

    var effectiveInsideHome: Bool {
        homeLocationManager.isInsideHome || (BuildFlavor.isLocalTesting && settings.localTestingForceHome)
    }

    var isUnlockActive: Bool {
        guard let unlockUntil else { return false }
        return unlockUntil > .now
    }

    var statusSummary: String {
        if !settings.protectionEnabled {
            return "Protection is disabled."
        }
        if !effectiveInsideHome {
            return "Protection is idle until you get home."
        }
        if isUnlockActive, let unlockUntil {
            return "Apps are temporarily unlocked until \(unlockUntil.formatted(date: .omitted, time: .shortened))."
        }
        if BuildFlavor.isLocalTesting {
            return "Local testing mode is armed. Shielding is simulated, but sensors and unlock timing still work."
        }
        return "Home protection is active. Shielded apps stay blocked until you verify the room."
    }

    func requestPermissions() {
        homeLocationManager.requestPermissions()
        homeLocationManager.requestCurrentLocation()
        notificationManager.requestAuthorization()
        SystemPermissionPriming.primeOnFirstLaunchIfNeeded()

        if BuildFlavor.isLocalTesting {
            updateMessage("Local testing build: sensor, geofence, notifications, and unlock timing are active. Screen Time shielding is simulated.")
            return
        }

        Task {
            await screenTimeManager.requestAuthorization()
        }
    }

    func syncSharedState() {
        unlockUntil = store.loadUnlockUntil()
        pendingVerificationRequest = store.loadPendingVerification()
        recentEvents = store.loadEvents()
        unlockHistory = store.loadUnlockHistory()
        shortcutWifiReading = store.loadShortcutWifiReading()
        refreshProtectionState()
    }

    func handleIncomingShortcutURL(_ url: URL) {
        guard let reading = PoopLockURLHandler.parseWiFiImport(url) else { return }

        shortcutWifiReading = reading
        store.saveShortcutWifiReading(reading)
        logEvent(title: "Wi‑Fi from Shortcuts", detail: wifiEventDetail(for: reading))

        if let pending = pendingCalibrationScan {
            pendingCalibrationScan = nil
            updateMessage("Wi‑Fi captured: \(reading.shortSummary). Scanning…")
            Task {
                await captureCalibrationSample(isBathroom: pending.isBathroom, roomLabel: pending.roomLabel)
            }
        } else if pendingVerificationScan {
            pendingVerificationScan = false
            updateMessage("Wi‑Fi captured: \(reading.shortSummary). Checking room…")
            Task {
                await verifyRoomAndMaybeUnlock()
            }
        } else {
            updateMessage("Imported Wi‑Fi details: \(reading.shortSummary).")
        }
    }

    func saveHomeFromCurrentLocation() {
        guard let coordinate = homeLocationManager.currentLocation?.coordinate else {
            updateMessage("Move outside or wait for a location fix before saving home.")
            return
        }

        settings.homeCoordinate = StoredCoordinate(coordinate: coordinate)
        persistSettings()
        homeLocationManager.startMonitoringHomeRegion(using: settings.homeCoordinate)
        updateMessage("Home geofence saved.")
    }

    func updateSelection(_ selection: FamilyActivitySelection) {
        screenTimeManager.updateSelection(selection)
        refreshProtectionState()
    }

    func setProtectionEnabled(_ enabled: Bool) {
        settings.protectionEnabled = enabled
        persistSettings()
        refreshProtectionState()
    }

    func setStrictMode(_ enabled: Bool) {
        settings.strictMode = enabled
        persistSettings()
    }

    func updateUnlockDuration(minutes: Int) {
        settings.unlockDurationMinutes = max(5, minutes)
        persistSettings()
    }

    func setLocalTestingForceHome(_ enabled: Bool) {
        settings.localTestingForceHome = enabled
        persistSettings()
        refreshProtectionState()
    }

    func setWifiShortcutName(_ name: String) {
        settings.wifiShortcutName = ShortcutOpener.normalizedShortcutDisplayName(name)
        persistSettings()
    }

    func setUseNativeWifiFallbackWhenShortcutMissing(_ value: Bool) {
        settings.useNativeWifiFallbackWhenShortcutMissing = value
        persistSettings()
    }

    func setOpenShortcutsBeforeWifiScans(_ value: Bool) {
        settings.openShortcutsBeforeWifiScans = value
        persistSettings()
    }

    func runConfiguredWifiShortcut() {
        let raw = settings.wifiShortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
        ShortcutOpener.runShortcut(named: raw.isEmpty ? PoopLockWifiShortcut.defaultName : raw)
    }

    func setWifiShortcutImportURL(_ url: String) {
        settings.wifiShortcutImportURL = url
        persistSettings()
    }

    func importWifiShortcutFromConfiguredLink() {
        ShortcutOpener.importShortcut(fromSharedLink: settings.wifiShortcutImportURL)
    }

    func openShortcutsApp() {
        ShortcutOpener.openShortcutsApp()
    }

    func promptLocalNetworkAndBluetoothPermissions() {
        SystemPermissionPriming.primeLocalNetwork()
        SystemPermissionPriming.primeBluetooth()
    }

    func triggerVerificationPromptForTesting() {
        pendingVerificationRequest = true
        store.savePendingVerification(true)
        notificationManager.scheduleVerificationPromptNotification()
        logEvent(title: "Verification prompt", detail: "Triggered a local test verification prompt.")
    }

    func requestCalibrationScan(isBathroom: Bool, roomLabel: String) {
        #if targetEnvironment(simulator)
        Task {
            await captureCalibrationSample(isBathroom: isBathroom, roomLabel: roomLabel)
        }
        #else
        if settings.shouldOpenShortcutsBeforeScan {
            pendingCalibrationScan = PendingCalibrationScan(isBathroom: isBathroom, roomLabel: roomLabel)
            shortcutWifiReading = nil
            updateMessage("Opening Wi‑Fi shortcut…")
            runConfiguredWifiShortcut()
        } else {
            pendingCalibrationScan = nil
            shortcutWifiReading = nil
            updateMessage("Starting scan (on‑device Wi‑Fi, no Shortcuts required)…")
            Task {
                await captureCalibrationSample(isBathroom: isBathroom, roomLabel: roomLabel)
            }
        }
        #endif
    }

    func requestVerificationScan() {
        #if targetEnvironment(simulator)
        Task {
            await verifyRoomAndMaybeUnlock()
        }
        #else
        guard calibration.isReady else {
            updateMessage("Finish bathroom calibration before using verification.")
            return
        }
        if settings.shouldOpenShortcutsBeforeScan {
            pendingVerificationScan = true
            shortcutWifiReading = nil
            updateMessage("Opening Wi‑Fi shortcut…")
            runConfiguredWifiShortcut()
        } else {
            pendingVerificationScan = false
            shortcutWifiReading = nil
            updateMessage("Checking room (on‑device Wi‑Fi, no Shortcuts required)…")
            Task {
                await verifyRoomAndMaybeUnlock()
            }
        }
        #endif
    }

    func captureCalibrationSample(isBathroom: Bool, roomLabel: String) async {
        let result = await verificationManager.capture10SecondSnapshot()
        let label = roomLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedLabel = label.isEmpty ? (isBathroom ? "Bathroom" : "Home") : label
        handleCalibrationResult(result, isBathroom: isBathroom, roomLabel: resolvedLabel)
    }

    func clearCalibration() {
        calibration = .default
        store.saveCalibration(calibration)
        refreshProtectionState()
        updateMessage("Calibration cleared. Ready to start over.")
    }

    func verifyRoomAndMaybeUnlock() async {
        clearPendingVerificationRequest()

        guard calibration.isReady else {
            updateMessage("Finish bathroom calibration before using verification.")
            return
        }

        var effectiveShortcutWifi = shortcutWifiReading
        if effectiveShortcutWifi == nil,
           calibration.bathroomRequiresShortcutWifi,
           settings.useNativeWifiFallbackWhenShortcutMissing,
           let native = await NativeWiFiReader.fetchCurrent() {
            effectiveShortcutWifi = ShortcutWiFiReading.approximated(from: native)
            updateMessage("Shortcuts didn’t open PoopLock — using on‑device Wi‑Fi for this check.")
        }

        if calibration.bathroomRequiresShortcutWifi, effectiveShortcutWifi == nil {
            updateMessage("Wi‑Fi shortcut did not return data. Use a shortcut that ends with pooplock://wifi?dbm=… or enable fallback in Settings.")
            return
        }

        let result = await verificationManager.verify(using: calibration, shortcutWifi: effectiveShortcutWifi)

        switch result {
        case let .passed(snapshot):
            let wifiSummary = " Wi‑Fi: \(snapshot.wifiSummary)."
            let unlockMinutes = settings.strictMode ? min(settings.unlockDurationMinutes, 10) : settings.unlockDurationMinutes
            let expiry = Calendar.current.date(byAdding: .minute, value: unlockMinutes, to: .now)
            unlockUntil = expiry
            store.saveUnlockUntil(expiry)

            if let expiry {
                store.beginUnlockSession(
                    until: expiry,
                    magneticMagnitude: snapshot.magneticMagnitude,
                    strictMode: settings.strictMode
                )
                unlockHistory = store.loadUnlockHistory()
                notificationManager.scheduleUnlockExpiryNotification(at: expiry)
                unlockScheduleManager.scheduleUnlockSession(until: expiry)
            }

            refreshProtectionState()
            logEvent(
                title: "Verification passed",
                detail: "Unlocked after magnetic reading \(snapshot.magneticMagnitude.formatted(.number.precision(.fractionLength(1)))) microteslas.\(wifiSummary)"
            )
            updateMessage("Room check passed. Apps are unlocked for \(unlockMinutes) minutes.\(wifiSummary)")

        case let .failed(snapshot, reason):
            refreshProtectionState()
            logEvent(
                title: "Bathroom detected",
                detail: "Blocked at \(snapshot.magneticMagnitude.formatted(.number.precision(.fractionLength(1)))) microteslas. \(reason) Wi‑Fi: \(snapshot.wifiSummary)."
            )
            updateMessage(reason)

        case let .unavailable(reason):
            updateMessage(reason)
        }
    }

    func refreshProtectionState() {
        store.saveIsInsideHome(effectiveInsideHome)

        if !settings.protectionEnabled {
            shieldController.clearShield()
            clearUnlock(reason: .protectionDisabled)
            return
        }
        if !effectiveInsideHome {
            shieldController.clearShield()
            clearUnlock(reason: .leftHome)
            return
        }
        if isUnlockActive {
            shieldController.clearShield()
            return
        }

        let status = shieldController.applyShield(selection: screenTimeManager.selection)
        updateMessage(status)
    }

    func clearPendingVerificationRequest() {
        pendingVerificationRequest = false
        store.savePendingVerification(false)
    }

    private func handleCalibrationResult(_ result: VerificationOutcome, isBathroom: Bool, roomLabel: String) {
        switch result {
        case let .passed(snapshot):
            let reading = shortcutWifiReading
            let enriched = snapshot.mergingShortcutWifi(reading, roomLabel: roomLabel)

            if isBathroom {
                calibration.bathroomSamples.append(enriched)
            } else {
                calibration.safeZoneSamples.append(enriched)
            }

            let formattedMag = enriched.magneticMagnitude.formatted(.number.precision(.fractionLength(1)))
            updateMessage("Saved \(roomLabel): magnet \(formattedMag) µT" + wifiCaptureSuffix(enriched: enriched, shortcutReading: reading))
            logEvent(
                title: isBathroom ? "Bathroom sample" : "Home sample",
                detail: "\(roomLabel): \(formattedMag) µT" + wifiCaptureSuffix(enriched: enriched, shortcutReading: reading, includeLabel: false)
            )

            store.saveCalibration(calibration)
            calibrationScanCompletedSignal += 1

        case let .failed(_, reason), let .unavailable(reason):
            updateMessage(reason)
        }
    }

    private func clearUnlock(reason: UnlockSessionEndReason = .cancelled) {
        unlockUntil = nil
        store.saveUnlockUntil(nil)
        unlockScheduleManager.clearUnlockSession()
        notificationManager.cancelScheduledNotifications()
        if store.finishActiveUnlockSession(reason: reason) != nil {
            unlockHistory = store.loadUnlockHistory()
        }
    }

    private func persistSettings() {
        store.saveSettings(settings)
    }

    private func updateMessage(_ message: String) {
        lastMessage = message
        recentEvents = store.loadEvents()
        unlockHistory = store.loadUnlockHistory()
    }

    private func logEvent(title: String, detail: String) {
        store.appendEvent(VerificationEvent(title: title, detail: detail))
        recentEvents = store.loadEvents()
    }

    private func wifiEventDetail(for reading: ShortcutWiFiReading) -> String {
        [reading.shortSummary, reading.metricsSummary, reading.bssid]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func wifiCaptureSuffix(enriched: VerificationSnapshot, shortcutReading: ShortcutWiFiReading?, includeLabel: Bool = true) -> String {
        let nativePart = enriched.nativeWifi.map { ", Wi‑Fi \($0.shortSummary)" } ?? ""
        guard let reading = shortcutReading else {
            return nativePart.isEmpty ? ", no on-device Wi‑Fi sample" : nativePart
        }
        let prefix = includeLabel ? ", Shortcuts " : ", "
        if let metrics = reading.metricsSummary {
            return "\(nativePart)\(prefix)\(reading.shortSummary) · \(metrics)"
        }
        return "\(nativePart)\(prefix)\(reading.shortSummary)"
    }
}
