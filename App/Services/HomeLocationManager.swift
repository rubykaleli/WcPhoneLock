import CoreLocation
import Foundation

@MainActor
final class HomeLocationManager: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var isInsideHome = false

    var onHomeStateChanged: ((Bool) -> Void)?

    private let locationManager = CLLocationManager()
    private let regionIdentifier = "restroom-restriction-home"

    override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPermissions() {
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            locationManager.requestAlwaysAuthorization()
        }
    }

    func requestCurrentLocation() {
        locationManager.requestLocation()
    }

    func startMonitoringHomeRegion(using coordinate: StoredCoordinate?) {
        locationManager.monitoredRegions.forEach { region in
            locationManager.stopMonitoring(for: region)
        }

        guard let coordinate else {
            isInsideHome = false
            onHomeStateChanged?(false)
            return
        }

        let region = CLCircularRegion(center: coordinate.coordinate, radius: 50, identifier: regionIdentifier)
        region.notifyOnEntry = true
        region.notifyOnExit = true

        locationManager.startMonitoring(for: region)
        locationManager.requestState(for: region)
    }
}

extension HomeLocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        Task { @MainActor in
            authorizationStatus = status
            if status == .authorizedWhenInUse {
                locationManager.requestAlwaysAuthorization()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latestLocation = locations.last

        Task { @MainActor in
            currentLocation = latestLocation
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        AppGroupStore.appendEvent(
            VerificationEvent(
                title: "Location update failed",
                detail: error.localizedDescription
            )
        )
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            isInsideHome = true
            onHomeStateChanged?(true)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in
            isInsideHome = false
            onHomeStateChanged?(false)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        Task { @MainActor in
            let insideHome = state == .inside
            isInsideHome = insideHome
            onHomeStateChanged?(insideHome)
        }
    }
}
