import Foundation
import Network

final class NetworkPathStatus: @unchecked Sendable {
    private let lock = NSLock()
    private var _summary: String = "…"
    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "com.rubykaleli.pooplock.networkpath")

    var summary: String {
        lock.lock()
        defer { lock.unlock() }
        return _summary
    }

    func start() {
        lock.lock()
        monitor?.cancel()
        let newMonitor = NWPathMonitor()
        monitor = newMonitor
        lock.unlock()

        newMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let text = Self.describe(path)
            self.lock.lock()
            self._summary = text
            self.lock.unlock()
        }
        newMonitor.start(queue: queue)
    }

    func stop() {
        lock.lock()
        monitor?.cancel()
        monitor = nil
        lock.unlock()
    }

    private static func describe(_ path: NWPath) -> String {
        guard path.status == .satisfied else {
            return "No network"
        }
        if path.usesInterfaceType(.wifi) {
            return "Wi‑Fi (on)"
        }
        if path.usesInterfaceType(.cellular) {
            return "Cellular"
        }
        if path.usesInterfaceType(.wiredEthernet) {
            return "Ethernet"
        }
        return "Connected"
    }
}
