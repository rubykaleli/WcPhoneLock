import CoreBluetooth
import Foundation
import Network

/// Surfaces WiFiman-style system prompts: Local Network (short Bonjour browse) and Bluetooth (CoreBluetooth; first use triggers the privacy sheet).
enum SystemPermissionPriming {
    private static let automaticPrimingDefaultsKey = "didRunAutomaticSystemPermissionPriming"

    /// Runs once per install from `requestPermissions()` so first launch can show the dialogs.
    static func primeOnFirstLaunchIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: automaticPrimingDefaultsKey) else { return }
        UserDefaults.standard.set(true, forKey: automaticPrimingDefaultsKey)
        primeLocalNetwork()
        primeBluetooth()
    }

    /// Re-runnable from Settings (e.g. user previously tapped Don’t Allow).
    static func primeLocalNetwork() {
        DispatchQueue.main.async {
            let parameters = NWParameters.tcp
            let browser = NWBrowser(for: .bonjour(type: "_http._tcp", domain: nil), using: parameters)
            browser.stateUpdateHandler = { _ in }
            browser.browseResultsChangedHandler = { _, _ in }
            browser.start(queue: .main)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                browser.cancel()
            }
        }
    }

    static func primeBluetooth() {
        DispatchQueue.main.async {
            BluetoothPrimer.runPrime()
        }
    }
}

private final class BluetoothPrimer: NSObject, CBCentralManagerDelegate {
    nonisolated(unsafe) private static var retained: BluetoothPrimer?

    fileprivate static func runPrime() {
        let primer = BluetoothPrimer()
        retained = primer
        primer.start()
    }

    private static func clearStored() {
        retained = nil
    }

    private var central: CBCentralManager?

    private func start() {
        central = CBCentralManager(delegate: self, queue: .main, options: [
            CBCentralManagerOptionShowPowerAlertKey: false
        ])
    }

    /// Creating `CBCentralManager` triggers the Bluetooth permission flow; tear down after the first callback so we never retain a long‑lived scan (avoids Swift 6 `Sendable` issues with `scanForPeripherals`).
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.central = nil
        BluetoothPrimer.clearStored()
    }
}
